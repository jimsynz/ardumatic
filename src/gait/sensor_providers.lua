local Object = require("object")

local SensorProviders = {}

SensorProviders.RangefinderProvider = Object.new("RangefinderProvider")

function SensorProviders.RangefinderProvider.new(orientation)
  if orientation ~= nil then
    assert(type(orientation) == "number", "orientation must be a number")
  end
  orientation = orientation or 25  -- 25 = downward facing
  
  return Object.instance({
    _orientation = orientation,
    _last_data = nil,
    _last_update = 0
  }, SensorProviders.RangefinderProvider)
end

function SensorProviders.RangefinderProvider:is_healthy()
  if not _G.rangefinder then
    return false
  end
  
  return _G.rangefinder:has_data_orient(self._orientation) and
         _G.rangefinder:status_orient(self._orientation) == 1
end

function SensorProviders.RangefinderProvider:get_data()
  if not self:is_healthy() then
    return nil
  end
  
  local distance = _G.rangefinder:distance_orient(self._orientation)
  local signal_quality = _G.rangefinder:signal_quality_pct_orient(self._orientation)
  local ground_clearance = _G.rangefinder:ground_clearance_orient(self._orientation)
  
  local data = {
    distance = distance * 1000,  -- Convert to mm
    signal_quality = signal_quality,
    ground_clearance = ground_clearance * 1000,  -- Convert to mm
    orientation = self._orientation,
    timestamp = _G.millis and _G.millis() or 0
  }
  
  if _G.ahrs then
    local location = _G.ahrs:get_location()
    if location then
      data.vehicle_altitude = location:alt() * 0.01  -- Convert to mm
    end
  end
  
  self._last_data = data
  self._last_update = data.timestamp
  
  return data
end

SensorProviders.TerrainProvider = Object.new("TerrainProvider")

function SensorProviders.TerrainProvider.new()
  return Object.instance({
    _last_data = nil,
    _last_update = 0
  }, SensorProviders.TerrainProvider)
end

function SensorProviders.TerrainProvider:is_healthy()
  if not _G.terrain then
    return false
  end
  
  return _G.terrain:enabled() and _G.terrain:status() == 0  -- TerrainStatusOK
end

function SensorProviders.TerrainProvider:get_data()
  if not self:is_healthy() then
    return nil
  end
  
  local height_above_terrain = _G.terrain:height_above_terrain(true)  -- extrapolate
  if not height_above_terrain then
    return nil
  end
  
  local data = {
    height_above_terrain = height_above_terrain * 1000,  -- Convert to mm
    timestamp = _G.millis and _G.millis() or 0
  }
  
  if _G.ahrs then
    local location = _G.ahrs:get_location()
    if location then
      data.vehicle_altitude = location:alt() * 0.01  -- Convert to mm
      
      local terrain_height = _G.terrain:height_amsl(location, true)
      if terrain_height then
        data.terrain_height_amsl = terrain_height * 1000  -- Convert to mm
      end
    end
  end
  
  self._last_data = data
  self._last_update = data.timestamp
  
  return data
end

SensorProviders.IMUProvider = Object.new("IMUProvider")

function SensorProviders.IMUProvider.new(instance)
  if instance ~= nil then
    assert(type(instance) == "number", "instance must be a number")
  end
  instance = instance or 0  -- Primary IMU
  
  return Object.instance({
    _instance = instance,
    _last_data = nil,
    _last_update = 0
  }, SensorProviders.IMUProvider)
end

function SensorProviders.IMUProvider:is_healthy()
  if not _G.ins then
    return false
  end
  
  return _G.ins:get_gyro_health(self._instance) and _G.ins:get_accel_health(self._instance)
end

function SensorProviders.IMUProvider:get_data()
  if not self:is_healthy() then
    return nil
  end
  
  local gyro = _G.ins:get_gyro(self._instance)
  local accel = _G.ins:get_accel(self._instance)
  
  if not gyro or not accel then
    return nil
  end
  
  local data = {
    gyro = {
      x = gyro:x(),
      y = gyro:y(),
      z = gyro:z()
    },
    accel = {
      x = accel:x(),
      y = accel:y(),
      z = accel:z()
    },
    instance = self._instance,
    timestamp = _G.millis and _G.millis() or 0
  }
  
  local temp = _G.ins:get_temperature(self._instance)
  if temp then
    data.temperature = temp
  end
  
  self._last_data = data
  self._last_update = data.timestamp
  
  return data
end

SensorProviders.AHRSProvider = Object.new("AHRSProvider")

function SensorProviders.AHRSProvider.new()
  return Object.instance({
    _last_data = nil,
    _last_update = 0
  }, SensorProviders.AHRSProvider)
end

function SensorProviders.AHRSProvider:is_healthy()
  return _G.ahrs ~= nil
end

function SensorProviders.AHRSProvider:get_data()
  if not self:is_healthy() then
    return nil
  end
  
  local data = {
    attitude = {
      roll = _G.ahrs:get_roll_rad(),
      pitch = _G.ahrs:get_pitch_rad(),
      yaw = _G.ahrs:get_yaw_rad()
    },
    timestamp = _G.millis and _G.millis() or 0
  }
  
  local location = _G.ahrs:get_location()
  if location then
    data.location = {
      lat = location:lat(),
      lng = location:lng(),
      alt = location:alt() * 0.01  -- Convert to mm
    }
  end
  
  local velocity = _G.ahrs:get_velocity_NED()
  if velocity then
    data.velocity = {
      north = velocity:x() * 1000,  -- Convert to mm/s
      east = velocity:y() * 1000,   -- Convert to mm/s
      down = velocity:z() * 1000    -- Convert to mm/s
    }
  end
  
  local hagl = _G.ahrs:get_hagl()
  if hagl then
    data.height_above_ground = hagl * 1000  -- Convert to mm
  end
  
  self._last_data = data
  self._last_update = data.timestamp
  
  return data
end

SensorProviders.BarometerProvider = Object.new("BarometerProvider")

function SensorProviders.BarometerProvider.new(instance)
  if instance ~= nil then
    assert(type(instance) == "number", "instance must be a number")
  end
  instance = instance or 0  -- Primary barometer
  
  return Object.instance({
    _instance = instance,
    _last_data = nil,
    _last_update = 0
  }, SensorProviders.BarometerProvider)
end

function SensorProviders.BarometerProvider:is_healthy()
  if not _G.baro then
    return false
  end
  
  return _G.baro:healthy(self._instance)
end

function SensorProviders.BarometerProvider:get_data()
  if not self:is_healthy() then
    return nil
  end
  
  local pressure = _G.baro:get_pressure()
  local temperature = _G.baro:get_temperature()
  local altitude = _G.baro:get_altitude()
  
  local data = {
    pressure = pressure,  -- Pascal
    temperature = temperature,  -- Celsius
    altitude = altitude * 1000,  -- Convert to mm
    instance = self._instance,
    timestamp = _G.millis and _G.millis() or 0
  }
  
  self._last_data = data
  self._last_update = data.timestamp
  
  return data
end

SensorProviders.GPSProvider = Object.new("GPSProvider")

function SensorProviders.GPSProvider.new(instance)
  if instance ~= nil then
    assert(type(instance) == "number", "instance must be a number")
  end
  instance = instance or 0  -- Primary GPS
  
  return Object.instance({
    _instance = instance,
    _last_data = nil,
    _last_update = 0
  }, SensorProviders.GPSProvider)
end

function SensorProviders.GPSProvider:is_healthy()
  if not _G.gps then
    return false
  end
  
  local status = _G.gps:status(self._instance)
  return status >= 3  -- GPS_OK_FIX_3D or better
end

function SensorProviders.GPSProvider:get_data()
  if not self:is_healthy() then
    return nil
  end
  
  local location = _G.gps:location(self._instance)
  local velocity = _G.gps:velocity(self._instance)
  
  if not location then
    return nil
  end
  
  local data = {
    location = {
      lat = location:lat(),
      lng = location:lng(),
      alt = location:alt() * 0.01  -- Convert to mm
    },
    status = _G.gps:status(self._instance),
    num_sats = _G.gps:num_sats(self._instance),
    hdop = _G.gps:get_hdop(self._instance),
    instance = self._instance,
    timestamp = _G.millis and _G.millis() or 0
  }
  
  if velocity then
    data.velocity = {
      north = velocity:x() * 1000,  -- Convert to mm/s
      east = velocity:y() * 1000,   -- Convert to mm/s
      down = velocity:z() * 1000    -- Convert to mm/s
    }
  end
  
  local ground_speed = _G.gps:ground_speed(self._instance)
  if ground_speed then
    data.ground_speed = ground_speed * 1000  -- Convert to mm/s
  end
  
  local horizontal_accuracy = _G.gps:horizontal_accuracy(self._instance)
  if horizontal_accuracy then
    data.horizontal_accuracy = horizontal_accuracy * 1000  -- Convert to mm
  end
  
  local vertical_accuracy = _G.gps:vertical_accuracy(self._instance)
  if vertical_accuracy then
    data.vertical_accuracy = vertical_accuracy * 1000  -- Convert to mm
  end
  
  self._last_data = data
  self._last_update = data.timestamp
  
  return data
end

SensorProviders.MockProvider = Object.new("MockProvider")

function SensorProviders.MockProvider.new(mock_data, healthy)
  if mock_data ~= nil then
    assert(type(mock_data) == "table", "mock_data must be a table")
  end
  if healthy ~= nil then
    assert(type(healthy) == "boolean", "healthy must be a boolean")
  end
  
  return Object.instance({
    _mock_data = mock_data or {},
    _healthy = healthy ~= false,  -- Default to healthy
    _call_count = 0
  }, SensorProviders.MockProvider)
end

function SensorProviders.MockProvider:is_healthy()
  return self._healthy
end

function SensorProviders.MockProvider:get_data()
  self._call_count = self._call_count + 1
  
  if not self._healthy then
    return nil
  end
  
  local data = {}
  for k, v in pairs(self._mock_data) do
    data[k] = v
  end
  
  data.timestamp = _G.millis and _G.millis() or self._call_count * 50
  data.call_count = self._call_count
  
  return data
end

function SensorProviders.MockProvider:set_healthy(healthy)
  assert(type(healthy) == "boolean", "healthy must be a boolean")
  self._healthy = healthy
end

function SensorProviders.MockProvider:set_mock_data(data)
  assert(type(data) == "table", "data must be a table")
  self._mock_data = data
end

return SensorProviders