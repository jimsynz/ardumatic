local SensorProviders = require("gait.sensor_providers")

describe("SensorProviders", function()
  
  describe("MockProvider", function()
    local mock_provider
    
    before_each(function()
      mock_provider = SensorProviders.MockProvider.new({
        test_value = 123,
        test_string = "hello"
      })
    end)
    
    it("should create with default healthy state", function()
      assert.is_true(mock_provider:is_healthy())
    end)
    
    it("should create with specified healthy state", function()
      local unhealthy_provider = SensorProviders.MockProvider.new({}, false)
      assert.is_false(unhealthy_provider:is_healthy())
    end)
    
    it("should return mock data when healthy", function()
      local data = mock_provider:get_data()
      
      assert.is_not_nil(data)
      assert.equals(123, data.test_value)
      assert.equals("hello", data.test_string)
      assert.is_not_nil(data.timestamp)
      assert.equals(1, data.call_count)
    end)
    
    it("should return nil when unhealthy", function()
      mock_provider:set_healthy(false)
      
      local data = mock_provider:get_data()
      
      assert.is_nil(data)
    end)
    
    it("should increment call count", function()
      mock_provider:get_data()
      local data = mock_provider:get_data()
      
      assert.equals(2, data.call_count)
    end)
    
    it("should update mock data", function()
      mock_provider:set_mock_data({new_value = 456})
      
      local data = mock_provider:get_data()
      
      assert.equals(456, data.new_value)
      assert.is_nil(data.test_value)  -- Old data should be gone
    end)
  end)
  
  describe("RangefinderProvider", function()
    local provider
    
    before_each(function()
      provider = SensorProviders.RangefinderProvider.new()
    end)
    
    it("should create with default downward orientation", function()
      -- Can't test actual functionality without ArduPilot globals
      -- Just verify it creates without error
      assert.is_not_nil(provider)
    end)
    
    it("should create with custom orientation", function()
      local custom_provider = SensorProviders.RangefinderProvider.new(0)  -- Forward facing
      assert.is_not_nil(custom_provider)
    end)
    
    it("should return false for is_healthy without ArduPilot", function()
      -- Without _G.rangefinder, should return false
      assert.is_false(provider:is_healthy())
    end)
    
    it("should return nil data when unhealthy", function()
      local data = provider:get_data()
      assert.is_nil(data)
    end)
  end)
  
  describe("TerrainProvider", function()
    local provider
    
    before_each(function()
      provider = SensorProviders.TerrainProvider.new()
    end)
    
    it("should create without error", function()
      assert.is_not_nil(provider)
    end)
    
    it("should return false for is_healthy without ArduPilot", function()
      assert.is_false(provider:is_healthy())
    end)
    
    it("should return nil data when unhealthy", function()
      local data = provider:get_data()
      assert.is_nil(data)
    end)
  end)
  
  describe("IMUProvider", function()
    local provider
    
    before_each(function()
      provider = SensorProviders.IMUProvider.new()
    end)
    
    it("should create with default instance 0", function()
      assert.is_not_nil(provider)
    end)
    
    it("should create with custom instance", function()
      local custom_provider = SensorProviders.IMUProvider.new(1)
      assert.is_not_nil(custom_provider)
    end)
    
    it("should return false for is_healthy without ArduPilot", function()
      assert.is_false(provider:is_healthy())
    end)
    
    it("should return nil data when unhealthy", function()
      local data = provider:get_data()
      assert.is_nil(data)
    end)
  end)
  
  describe("AHRSProvider", function()
    local provider
    
    before_each(function()
      provider = SensorProviders.AHRSProvider.new()
    end)
    
    it("should create without error", function()
      assert.is_not_nil(provider)
    end)
    
    it("should return false for is_healthy without ArduPilot", function()
      assert.is_false(provider:is_healthy())
    end)
    
    it("should return nil data when unhealthy", function()
      local data = provider:get_data()
      assert.is_nil(data)
    end)
  end)
  
  describe("BarometerProvider", function()
    local provider
    
    before_each(function()
      provider = SensorProviders.BarometerProvider.new()
    end)
    
    it("should create with default instance 0", function()
      assert.is_not_nil(provider)
    end)
    
    it("should create with custom instance", function()
      local custom_provider = SensorProviders.BarometerProvider.new(1)
      assert.is_not_nil(custom_provider)
    end)
    
    it("should return false for is_healthy without ArduPilot", function()
      assert.is_false(provider:is_healthy())
    end)
    
    it("should return nil data when unhealthy", function()
      local data = provider:get_data()
      assert.is_nil(data)
    end)
  end)
  
  describe("GPSProvider", function()
    local provider
    
    before_each(function()
      provider = SensorProviders.GPSProvider.new()
    end)
    
    it("should create with default instance 0", function()
      assert.is_not_nil(provider)
    end)
    
    it("should create with custom instance", function()
      local custom_provider = SensorProviders.GPSProvider.new(1)
      assert.is_not_nil(custom_provider)
    end)
    
    it("should return false for is_healthy without ArduPilot", function()
      assert.is_false(provider:is_healthy())
    end)
    
    it("should return nil data when unhealthy", function()
      local data = provider:get_data()
      assert.is_nil(data)
    end)
  end)
  
  -- Integration tests with mock ArduPilot globals
  describe("with mock ArduPilot globals", function()
    local original_rangefinder, original_ahrs
    
    before_each(function()
      -- Save original globals
      original_rangefinder = _G.rangefinder
      original_ahrs = _G.ahrs
      
      -- Mock ArduPilot rangefinder
      _G.rangefinder = {
        has_data_orient = function(self, orientation)
          return orientation == 25  -- Only downward facing has data
        end,
        status_orient = function(self, orientation)
          return orientation == 25 and 1 or 0  -- 1 = healthy
        end,
        distance_orient = function(self, orientation)
          return 1.5  -- 1.5 meters
        end,
        signal_quality_pct_orient = function(self, orientation)
          return 85  -- 85% quality
        end,
        ground_clearance_orient = function(self, orientation)
          return 1.4  -- 1.4 meters clearance
        end
      }
      
      -- Mock ArduPilot AHRS
      _G.ahrs = {
        get_roll_rad = function() return 0.1 end,
        get_pitch_rad = function() return -0.05 end,
        get_yaw_rad = function() return 1.57 end,
        get_location = function()
          return {
            lat = function() return -37.123456 end,
            lng = function() return 144.987654 end,
            alt = function() return 15000 end  -- cm
          }
        end,
        get_velocity_NED = function()
          return {
            x = function() return 2.5 end,  -- m/s north
            y = function() return 1.0 end,  -- m/s east
            z = function() return -0.1 end  -- m/s down
          }
        end,
        get_hagl = function() return 1.45 end  -- meters
      }
      
      -- Mock millis function
      _G.millis = function() return 12345 end
    end)
    
    after_each(function()
      -- Restore original globals
      _G.rangefinder = original_rangefinder
      _G.ahrs = original_ahrs
      _G.millis = nil
    end)
    
    it("should get rangefinder data when healthy", function()
      local provider = SensorProviders.RangefinderProvider.new(25)  -- Downward facing
      
      assert.is_true(provider:is_healthy())
      
      local data = provider:get_data()
      assert.is_not_nil(data)
      assert.equals(1500, data.distance)  -- 1.5m converted to mm
      assert.equals(85, data.signal_quality)
      assert.equals(1400, data.ground_clearance)  -- 1.4m converted to mm
      assert.equals(25, data.orientation)
      assert.equals(12345, data.timestamp)
    end)
    
    it("should not get rangefinder data for wrong orientation", function()
      local provider = SensorProviders.RangefinderProvider.new(0)  -- Forward facing
      
      assert.is_false(provider:is_healthy())
      assert.is_nil(provider:get_data())
    end)
    
    it("should get AHRS data when available", function()
      local provider = SensorProviders.AHRSProvider.new()
      
      assert.is_true(provider:is_healthy())
      
      local data = provider:get_data()
      assert.is_not_nil(data)
      assert.equals(0.1, data.attitude.roll)
      assert.equals(-0.05, data.attitude.pitch)
      assert.equals(1.57, data.attitude.yaw)
      assert.equals(-37.123456, data.location.lat)
      assert.equals(144.987654, data.location.lng)
      assert.equals(150, data.location.alt)  -- 15000cm converted to mm
      assert.equals(2500, data.velocity.north)  -- 2.5m/s converted to mm/s
      assert.equals(1000, data.velocity.east)   -- 1.0m/s converted to mm/s
      assert.equals(-100, data.velocity.down)   -- -0.1m/s converted to mm/s
      assert.equals(1450, data.height_above_ground)  -- 1.45m converted to mm
      assert.equals(12345, data.timestamp)
    end)
  end)
end)