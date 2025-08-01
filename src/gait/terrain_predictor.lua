local Object = require("object")
local Vec3 = require("vec3")
local Scalar = require("scalar")

local TerrainPredictor = Object.new("TerrainPredictor")

local DEFAULT_CONFIG = {
  prediction_distance = 200.0,    -- mm ahead to predict terrain
  ground_clearance_margin = 10.0, -- mm extra clearance for safety
  max_step_height_increase = 50.0, -- mm maximum adaptive step height increase
  terrain_smoothing_factor = 0.3,  -- 0.0-1.0 smoothing for terrain height changes
  sensor_timeout = 500,            -- ms before sensor data considered stale
  fallback_ground_height = 0.0,    -- mm fallback when no sensor data available
  attitude_compensation = true,     -- enable body attitude compensation
  max_attitude_angle = 0.52,       -- rad (30 degrees) maximum attitude correction
}

function TerrainPredictor.new(config)
  if config ~= nil then
    assert(type(config) == "table", "config must be a table")
  end
  
  local merged_config = {}
  for k, v in pairs(DEFAULT_CONFIG) do
    merged_config[k] = config and config[k] or v
  end
  
  Scalar.assert_type(merged_config.prediction_distance, "number")
  Scalar.assert_type(merged_config.ground_clearance_margin, "number")
  Scalar.assert_type(merged_config.max_step_height_increase, "number")
  Scalar.assert_type(merged_config.terrain_smoothing_factor, "number")
  Scalar.assert_type(merged_config.sensor_timeout, "number")
  Scalar.assert_type(merged_config.fallback_ground_height, "number")
  Scalar.assert_type(merged_config.max_attitude_angle, "number")
  
  assert(merged_config.prediction_distance > 0, "prediction_distance must be positive")
  assert(merged_config.ground_clearance_margin >= 0, "ground_clearance_margin must be non-negative")
  assert(merged_config.max_step_height_increase >= 0, "max_step_height_increase must be non-negative")
  assert(merged_config.terrain_smoothing_factor >= 0 and merged_config.terrain_smoothing_factor <= 1, 
         "terrain_smoothing_factor must be between 0 and 1")
  assert(merged_config.sensor_timeout > 0, "sensor_timeout must be positive")
  assert(merged_config.max_attitude_angle > 0, "max_attitude_angle must be positive")
  
  return Object.instance({
    _config = merged_config,
    _sensor_providers = {},
    _terrain_cache = {},
    _last_update_time = 0,
    _current_attitude = {roll = 0, pitch = 0, yaw = 0},
    _ground_height_history = {},
    _history_size = 10
  }, TerrainPredictor)
end

function TerrainPredictor:register_sensor_provider(name, provider)
  assert(type(name) == "string", "name must be a string")
  assert(type(provider) == "table", "provider must be a table")
  
  assert(type(provider.get_data) == "function", "Sensor provider must have get_data function")
  assert(type(provider.is_healthy) == "function", "Sensor provider must have is_healthy function")
  
  self._sensor_providers[name] = provider
end

function TerrainPredictor:update(current_time, robot_position, velocity)
  assert(type(current_time) == "number", "current_time must be a number")
  Object.assert_type(robot_position, Vec3)
  if velocity ~= nil then
    Object.assert_type(velocity, Vec3)
  end
  
  self._last_update_time = current_time
  velocity = velocity or Vec3.new(0, 0, 0)
  
  local sensor_data = self:_collect_sensor_data()
  
  if sensor_data.attitude then
    self._current_attitude = sensor_data.attitude
  end
  
  local ground_height = self:_estimate_ground_height(robot_position, sensor_data)
  self:_update_ground_height_history(ground_height)
  
  local predicted_terrain = self:_predict_terrain_ahead(robot_position, velocity, sensor_data)
  
  return {
    current_ground_height = ground_height,
    predicted_terrain = predicted_terrain,
    attitude = self._current_attitude,
    sensor_health = self:_assess_sensor_health(sensor_data),
    adaptive_clearance = self:_calculate_adaptive_clearance(predicted_terrain)
  }
end

function TerrainPredictor:get_ground_height_at_position(position)
  Object.assert_type(position, Vec3)
  
  local cache_key = string.format("%.1f_%.1f", position:x(), position:y())
  local cached = self._terrain_cache[cache_key]
  
  if cached and (self._last_update_time - cached.timestamp) < self._config.sensor_timeout then
    return cached.height
  end
  
  local sensor_data = self:_collect_sensor_data()
  local height = self:_estimate_ground_height(position, sensor_data)
  
  self._terrain_cache[cache_key] = {
    height = height,
    timestamp = self._last_update_time
  }
  
  return height
end

function TerrainPredictor:get_adaptive_step_height(base_step_height, leg_position, target_position)
  Scalar.assert_type(base_step_height, "number")
  Object.assert_type(leg_position, Vec3)
  Object.assert_type(target_position, Vec3)
  
  local current_ground = self:get_ground_height_at_position(leg_position)
  local target_ground = self:get_ground_height_at_position(target_position)
  
  local height_difference = math.abs(target_ground - current_ground)
  local terrain_roughness = self:_calculate_terrain_roughness()
  
  local adaptive_increase = math.min(
    height_difference + terrain_roughness + self._config.ground_clearance_margin,
    self._config.max_step_height_increase
  )
  
  return base_step_height + adaptive_increase
end

function TerrainPredictor:get_body_attitude_compensation()
  if not self._config.attitude_compensation then
    return {roll = 0, pitch = 0, yaw = 0}
  end
  
  local roll = math.max(-self._config.max_attitude_angle, 
                       math.min(self._config.max_attitude_angle, self._current_attitude.roll))
  local pitch = math.max(-self._config.max_attitude_angle, 
                        math.min(self._config.max_attitude_angle, self._current_attitude.pitch))
  
  return {
    roll = roll,
    pitch = pitch,
    yaw = self._current_attitude.yaw
  }
end

function TerrainPredictor:_collect_sensor_data()
  local sensor_data = {}
  
  for name, provider in pairs(self._sensor_providers) do
    if provider:is_healthy() then
      local data = provider:get_data()
      if data then
        sensor_data[name] = data
      end
    end
  end
  
  return sensor_data
end

function TerrainPredictor:_estimate_ground_height(position, sensor_data)
  local height_estimates = {}
  
  if sensor_data.rangefinder and sensor_data.rangefinder.distance then
    local vehicle_height = sensor_data.rangefinder.vehicle_altitude or 0
    table.insert(height_estimates, vehicle_height - sensor_data.rangefinder.distance)
  end
  
  if sensor_data.terrain and sensor_data.terrain.height_above_terrain then
    local vehicle_height = sensor_data.terrain.vehicle_altitude or 0
    table.insert(height_estimates, vehicle_height - sensor_data.terrain.height_above_terrain)
  end
  
  if sensor_data.barometer and sensor_data.barometer.altitude then
    table.insert(height_estimates, sensor_data.barometer.altitude)
  end
  
  if #height_estimates == 0 then
    return self._config.fallback_ground_height
  end
  
  local sum = 0
  for _, height in ipairs(height_estimates) do
    sum = sum + height
  end
  local average_height = sum / #height_estimates
  
  local smoothed_height = self:_apply_terrain_smoothing(average_height)
  
  return smoothed_height
end

function TerrainPredictor:_predict_terrain_ahead(position, velocity, sensor_data)
  local prediction_time = 1.0
  local speed = velocity:length()
  
  if speed < 1.0 then
    return {
      distance_ahead = 0,
      predicted_height = self:get_ground_height_at_position(position),
      confidence = 1.0
    }
  end
  
  local direction = velocity:normalise()
  local prediction_distance = math.min(speed * prediction_time, self._config.prediction_distance)
  local predicted_position = position + (direction * prediction_distance)
  
  local predicted_height = self:get_ground_height_at_position(predicted_position)
  local confidence = self:_calculate_prediction_confidence(sensor_data)
  
  return {
    distance_ahead = prediction_distance,
    predicted_height = predicted_height,
    predicted_position = predicted_position,
    confidence = confidence
  }
end

function TerrainPredictor:_update_ground_height_history(height)
  table.insert(self._ground_height_history, height)
  
  if #self._ground_height_history > self._history_size then
    table.remove(self._ground_height_history, 1)
  end
end

function TerrainPredictor:_apply_terrain_smoothing(new_height)
  if #self._ground_height_history == 0 then
    return new_height
  end
  
  local last_height = self._ground_height_history[#self._ground_height_history]
  local smoothing = self._config.terrain_smoothing_factor
  
  return last_height * (1 - smoothing) + new_height * smoothing
end

function TerrainPredictor:_calculate_terrain_roughness()
  if #self._ground_height_history < 3 then
    return 0
  end
  
  local variance = 0
  local mean = 0
  
  for _, height in ipairs(self._ground_height_history) do
    mean = mean + height
  end
  mean = mean / #self._ground_height_history
  
  for _, height in ipairs(self._ground_height_history) do
    variance = variance + (height - mean) ^ 2
  end
  variance = variance / #self._ground_height_history
  
  return math.sqrt(variance)
end

function TerrainPredictor:_assess_sensor_health(sensor_data)
  local health = {}
  
  for name, provider in pairs(self._sensor_providers) do
    health[name] = {
      healthy = provider:is_healthy(),
      has_data = sensor_data[name] ~= nil
    }
  end
  
  return health
end

function TerrainPredictor:_calculate_adaptive_clearance(predicted_terrain)
  local base_clearance = self._config.ground_clearance_margin
  local terrain_roughness = self:_calculate_terrain_roughness()
  local confidence_factor = predicted_terrain.confidence or 1.0
  
  local adaptive_clearance = base_clearance + (terrain_roughness * (2 - confidence_factor))
  
  return math.min(adaptive_clearance, self._config.max_step_height_increase)
end

function TerrainPredictor:_calculate_prediction_confidence(sensor_data)
  local confidence_factors = {}
  
  if sensor_data.rangefinder then
    local quality = sensor_data.rangefinder.signal_quality or 50
    table.insert(confidence_factors, quality / 100.0)
  end
  
  if sensor_data.terrain then
    table.insert(confidence_factors, 0.8)
  end
  
  if sensor_data.gps then
    local hdop = sensor_data.gps.hdop or 2.0
    local gps_confidence = math.max(0.1, 1.0 / hdop)
    table.insert(confidence_factors, math.min(1.0, gps_confidence))
  end
  
  if #confidence_factors == 0 then
    return 0.1
  end
  
  local sum = 0
  for _, factor in ipairs(confidence_factors) do
    sum = sum + factor
  end
  
  return sum / #confidence_factors
end

function TerrainPredictor:get_config(key)
  assert(type(key) == "string", "key must be a string")
  return self._config[key]
end

function TerrainPredictor:set_config(key, value)
  assert(type(key) == "string", "key must be a string")
  
  if key == "prediction_distance" then
    Scalar.assert_type(value, "number")
    assert(value > 0, "prediction_distance must be positive")
  elseif key == "ground_clearance_margin" then
    Scalar.assert_type(value, "number")
    assert(value >= 0, "ground_clearance_margin must be non-negative")
  elseif key == "max_step_height_increase" then
    Scalar.assert_type(value, "number")
    assert(value >= 0, "max_step_height_increase must be non-negative")
  elseif key == "terrain_smoothing_factor" then
    Scalar.assert_type(value, "number")
    assert(value >= 0 and value <= 1, "terrain_smoothing_factor must be between 0 and 1")
  elseif key == "sensor_timeout" then
    Scalar.assert_type(value, "number")
    assert(value > 0, "sensor_timeout must be positive")
  elseif key == "fallback_ground_height" then
    Scalar.assert_type(value, "number")
  elseif key == "attitude_compensation" then
    assert(type(value) == "boolean", "attitude_compensation must be a boolean")
  elseif key == "max_attitude_angle" then
    Scalar.assert_type(value, "number")
    assert(value > 0, "max_attitude_angle must be positive")
  else
    error("Unknown configuration key: " .. key)
  end
  
  self._config[key] = value
end

return TerrainPredictor