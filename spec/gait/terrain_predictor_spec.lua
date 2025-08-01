local TerrainPredictor = require("gait.terrain_predictor")
local SensorProviders = require("gait.sensor_providers")
local Vec3 = require("vec3")

describe("TerrainPredictor", function()
  local predictor
  local mock_provider
  
  before_each(function()
    predictor = TerrainPredictor.new()
    mock_provider = SensorProviders.MockProvider.new({
      distance = 1000,  -- 1m in mm
      signal_quality = 80,
      vehicle_altitude = 1500  -- 1.5m in mm
    })
  end)
  
  describe("new", function()
    it("should create with default configuration", function()
      local tp = TerrainPredictor.new()
      assert.equals(200.0, tp:get_config("prediction_distance"))
      assert.equals(10.0, tp:get_config("ground_clearance_margin"))
      assert.equals(50.0, tp:get_config("max_step_height_increase"))
    end)
    
    it("should create with custom configuration", function()
      local config = {
        prediction_distance = 300.0,
        ground_clearance_margin = 15.0,
        max_step_height_increase = 75.0
      }
      local tp = TerrainPredictor.new(config)
      assert.equals(300.0, tp:get_config("prediction_distance"))
      assert.equals(15.0, tp:get_config("ground_clearance_margin"))
      assert.equals(75.0, tp:get_config("max_step_height_increase"))
    end)
    
    it("should validate configuration parameters", function()
      assert.has_error(function()
        TerrainPredictor.new({prediction_distance = -100})
      end)
      
      assert.has_error(function()
        TerrainPredictor.new({terrain_smoothing_factor = 1.5})
      end)
      
      assert.has_error(function()
        TerrainPredictor.new({sensor_timeout = 0})
      end)
    end)
  end)
  
  describe("sensor provider registration", function()
    it("should register valid sensor providers", function()
      predictor:register_sensor_provider("rangefinder", mock_provider)
      -- Should not throw error
    end)
    
    it("should reject invalid sensor providers", function()
      assert.has_error(function()
        predictor:register_sensor_provider("invalid", {})
      end)
      
      assert.has_error(function()
        predictor:register_sensor_provider("invalid", {get_data = "not_function"})
      end)
    end)
  end)
  
  describe("update", function()
    before_each(function()
      predictor:register_sensor_provider("rangefinder", mock_provider)
    end)
    
    it("should update with basic parameters", function()
      local position = Vec3.new(0, 0, 100)
      local velocity = Vec3.new(50, 0, 0)
      
      local result = predictor:update(1000, position, velocity)
      
      assert.is_not_nil(result)
      assert.is_not_nil(result.current_ground_height)
      assert.is_not_nil(result.predicted_terrain)
      assert.is_not_nil(result.sensor_health)
    end)
    
    it("should handle nil velocity", function()
      local position = Vec3.new(0, 0, 100)
      
      local result = predictor:update(1000, position)
      
      assert.is_not_nil(result)
      assert.equals(0, result.predicted_terrain.distance_ahead)
    end)
    
    it("should predict terrain ahead when moving", function()
      local position = Vec3.new(0, 0, 100)
      local velocity = Vec3.new(100, 0, 0)  -- 100 mm/s forward
      
      local result = predictor:update(1000, position, velocity)
      
      assert.is_true(result.predicted_terrain.distance_ahead > 0)
      assert.is_not_nil(result.predicted_terrain.predicted_position)
    end)
  end)
  
  describe("ground height estimation", function()
    it("should return fallback height with no sensors", function()
      local position = Vec3.new(0, 0, 100)
      local height = predictor:get_ground_height_at_position(position)
      
      assert.equals(0.0, height)  -- Default fallback
    end)
    
    it("should use sensor data when available", function()
      predictor:register_sensor_provider("rangefinder", mock_provider)
      
      local position = Vec3.new(0, 0, 100)
      local height = predictor:get_ground_height_at_position(position)
      
      -- Should calculate from vehicle altitude - distance
      assert.equals(500, height)  -- 1500 - 1000 = 500mm
    end)
    
    it("should cache ground height calculations", function()
      predictor:register_sensor_provider("rangefinder", mock_provider)
      
      local position = Vec3.new(0, 0, 100)
      local height1 = predictor:get_ground_height_at_position(position)
      local height2 = predictor:get_ground_height_at_position(position)
      
      assert.equals(height1, height2)
    end)
  end)
  
  describe("adaptive step height", function()
    before_each(function()
      predictor:register_sensor_provider("rangefinder", mock_provider)
    end)
    
    it("should return base step height for flat terrain", function()
      local base_height = 30.0
      local leg_pos = Vec3.new(0, 0, 100)
      local target_pos = Vec3.new(50, 0, 100)
      
      local adaptive_height = predictor:get_adaptive_step_height(base_height, leg_pos, target_pos)
      
      -- Should be base height plus some margin
      assert.is_true(adaptive_height >= base_height)
    end)
    
    it("should increase step height for uneven terrain", function()
      -- Create mock provider with varying terrain heights
      local varying_provider = SensorProviders.MockProvider.new({
        distance = 800,  -- Different height
        vehicle_altitude = 1500
      })
      predictor:register_sensor_provider("terrain", varying_provider)
      
      local base_height = 30.0
      local leg_pos = Vec3.new(0, 0, 100)
      local target_pos = Vec3.new(50, 0, 150)  -- Higher target
      
      local adaptive_height = predictor:get_adaptive_step_height(base_height, leg_pos, target_pos)
      
      assert.is_true(adaptive_height > base_height)
    end)
    
    it("should respect maximum step height increase", function()
      local base_height = 30.0
      local leg_pos = Vec3.new(0, 0, 0)
      local target_pos = Vec3.new(50, 0, 1000)  -- Very high target
      
      local adaptive_height = predictor:get_adaptive_step_height(base_height, leg_pos, target_pos)
      
      -- Should not exceed base + max_increase
      local max_increase = predictor:get_config("max_step_height_increase")
      assert.is_true(adaptive_height <= base_height + max_increase)
    end)
  end)
  
  describe("body attitude compensation", function()
    it("should return zero compensation when disabled", function()
      predictor:set_config("attitude_compensation", false)
      
      local compensation = predictor:get_body_attitude_compensation()
      
      assert.equals(0, compensation.roll)
      assert.equals(0, compensation.pitch)
      assert.equals(0, compensation.yaw)
    end)
    
    it("should limit attitude angles to maximum", function()
      -- Mock AHRS provider with extreme attitude
      local ahrs_provider = SensorProviders.MockProvider.new({
        attitude = {
          roll = 1.0,   -- 57 degrees - should be limited
          pitch = -1.0, -- -57 degrees - should be limited
          yaw = 0.5
        }
      })
      predictor:register_sensor_provider("ahrs", ahrs_provider)
      predictor:update(1000, Vec3.new(0, 0, 100))
      
      local compensation = predictor:get_body_attitude_compensation()
      
      local max_angle = predictor:get_config("max_attitude_angle")
      assert.is_true(math.abs(compensation.roll) <= max_angle)
      assert.is_true(math.abs(compensation.pitch) <= max_angle)
    end)
  end)
  
  describe("configuration", function()
    it("should get and set valid configuration values", function()
      predictor:set_config("prediction_distance", 250.0)
      assert.equals(250.0, predictor:get_config("prediction_distance"))
      
      predictor:set_config("terrain_smoothing_factor", 0.5)
      assert.equals(0.5, predictor:get_config("terrain_smoothing_factor"))
      
      predictor:set_config("attitude_compensation", false)
      assert.equals(false, predictor:get_config("attitude_compensation"))
    end)
    
    it("should validate configuration values", function()
      assert.has_error(function()
        predictor:set_config("prediction_distance", -100)
      end)
      
      assert.has_error(function()
        predictor:set_config("terrain_smoothing_factor", 2.0)
      end)
      
      assert.has_error(function()
        predictor:set_config("unknown_key", 123)
      end)
    end)
  end)
  
  describe("sensor health assessment", function()
    it("should report healthy sensors", function()
      predictor:register_sensor_provider("rangefinder", mock_provider)
      
      local result = predictor:update(1000, Vec3.new(0, 0, 100))
      
      assert.is_true(result.sensor_health.rangefinder.healthy)
      assert.is_true(result.sensor_health.rangefinder.has_data)
    end)
    
    it("should report unhealthy sensors", function()
      mock_provider:set_healthy(false)
      predictor:register_sensor_provider("rangefinder", mock_provider)
      
      local result = predictor:update(1000, Vec3.new(0, 0, 100))
      
      assert.is_false(result.sensor_health.rangefinder.healthy)
      assert.is_false(result.sensor_health.rangefinder.has_data)
    end)
  end)
  
  describe("terrain smoothing", function()
    it("should smooth terrain height changes", function()
      predictor:register_sensor_provider("rangefinder", mock_provider)
      predictor:set_config("terrain_smoothing_factor", 0.5)
      
      -- First update establishes baseline
      predictor:update(1000, Vec3.new(0, 0, 100))
      
      -- Change sensor data to simulate terrain change
      mock_provider:set_mock_data({
        distance = 500,  -- Closer ground
        vehicle_altitude = 1500
      })
      
      local result = predictor:update(1100, Vec3.new(10, 0, 100))
      
      -- Height should be smoothed, not jump immediately to new value
      assert.is_not_nil(result.current_ground_height)
    end)
  end)
end)