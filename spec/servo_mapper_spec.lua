describe("ServoMapper", function()
  local ServoMapper = require("servo_mapper")
  local RobotBuilder = require("robot_builder")
  local RobotConfig = require("robot_config")
  local Vec3 = require("vec3")
  local Angle = require("angle")
  
  describe("initialization", function()
    it("should create a mapper with default platform", function()
      local mapper = ServoMapper.new()
      assert.are.equal("PIXHAWK", mapper._platform)
      assert.are.equal(16, mapper._max_channels)
    end)
    
    it("should create a mapper with specified platform", function()
      local mapper = ServoMapper.new("GENERIC_F4")
      assert.are.equal("GENERIC_F4", mapper._platform)
      assert.are.equal(8, mapper._max_channels)
    end)
    
    it("should create a mapper with custom channel count", function()
      local mapper = ServoMapper.new("CUSTOM", 24)
      assert.are.equal("CUSTOM", mapper._platform)
      assert.are.equal(24, mapper._max_channels)
    end)
    
    it("should handle unknown platform with default", function()
      local mapper = ServoMapper.new("UNKNOWN_PLATFORM")
      assert.are.equal("UNKNOWN_PLATFORM", mapper._platform)
      assert.are.equal(16, mapper._max_channels)  -- Default to Pixhawk
    end)
  end)
  
  describe("channel reservation", function()
    local mapper
    
    before_each(function()
      mapper = ServoMapper.new("PIXHAWK", 16)
    end)
    
    it("should reserve channels successfully", function()
      mapper:reserve_channels({1, 2, 3, 4}, "flight_control")
      
      assert.are.equal("flight_control", mapper._reserved_channels[1])
      assert.are.equal("flight_control", mapper._reserved_channels[2])
      assert.are.equal("flight_control", mapper._reserved_channels[3])
      assert.are.equal("flight_control", mapper._reserved_channels[4])
    end)
    
    it("should prevent double reservation of channels", function()
      mapper:reserve_channels({1, 2}, "motors")
      
      assert.has_error(function()
        mapper:reserve_channels({2, 3}, "gimbal")
      end, "Channel 2 is already reserved for motors")
    end)
    
    it("should validate channel numbers", function()
      assert.has_error(function()
        mapper:reserve_channels({0}, "invalid")
      end, "Channel 0 is outside valid range 1-16")
      
      assert.has_error(function()
        mapper:reserve_channels({17}, "invalid")
      end, "Channel 17 is outside valid range 1-16")
    end)
    
    it("should handle non-array input", function()
      assert.has_error(function()
        mapper:reserve_channels("not_an_array", "invalid")
      end, "Channels must be an array")
    end)
  end)
  
  describe("robot mapping", function()
    local mapper
    
    before_each(function()
      mapper = ServoMapper.new("PIXHAWK", 16)
    end)
    
    it("should map a simple robotic arm", function()
      local arm = RobotBuilder.robotic_arm(Vec3.zero(), {100, 80, 60})
      local mapping = mapper:map_robot(arm)
      
      assert.are.equal(3, mapping.channels_used)
      assert.are.equal(16, mapping.channels_available)
      
      -- Check that joints are mapped to consecutive channels
      assert.is_not_nil(mapping.assignments[1])
      assert.is_not_nil(mapping.assignments[2])
      assert.is_not_nil(mapping.assignments[3])
      
      -- Check servo function assignments
      assert.are.equal(100, mapping.assignments[1].servo_function)  -- KINEMATIC_JOINT_1
      assert.are.equal(101, mapping.assignments[2].servo_function)  -- KINEMATIC_JOINT_2
      assert.are.equal(102, mapping.assignments[3].servo_function)  -- KINEMATIC_JOINT_3
    end)
    
    it("should map a quadruped with reserved channels", function()
      mapper:reserve_channels({1, 2, 3, 4}, "flight_control")
      
      local quadruped = RobotBuilder.quadruped(100, 40, 60, 80)
      local mapping = mapper:map_robot(quadruped)
      
      assert.are.equal(12, mapping.channels_used)  -- 4 legs × 3 joints
      assert.are.equal(12, mapping.channels_available)  -- 16 - 4 reserved
      
      -- First available channel should be 5 (after reserved 1-4)
      assert.is_not_nil(mapping.assignments[5])
      assert.is_nil(mapping.assignments[1])  -- Reserved channel
      assert.is_nil(mapping.assignments[4])  -- Reserved channel
    end)
    
    it("should handle ball joints appropriately", function()
      local config = RobotConfig.new("ball_joint_test")
      config:add_chain("test_chain", Vec3.zero())
        :ball_joint(Vec3.forward(), Angle.from_degrees(45))
        :link(100, "test_link")
      
      local mapping = mapper:map_robot(config)
      
      -- Ball joints should be noted but not assigned channels
      assert.are.equal(0, mapping.channels_used)
      assert.is_not_nil(mapping.joints["test_chain_ball_joint_1"])
      assert.is_nil(mapping.joints["test_chain_ball_joint_1"].servo_channel)
      assert.is_not_nil(mapping.joints["test_chain_ball_joint_1"].note)
    end)
    
    it("should fail when insufficient channels available", function()
      mapper:reserve_channels({1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16}, "all_reserved")
      
      local arm = RobotBuilder.robotic_arm(Vec3.zero(), {100})
      
      assert.has_error(function()
        mapper:map_robot(arm)
      end, "Insufficient servo channels: need more than 16 channels")
    end)
  end)
  
  describe("parameter generation", function()
    local mapper
    
    before_each(function()
      mapper = ServoMapper.new("PIXHAWK", 16)
    end)
    
    it("should generate ArduPilot parameters", function()
      local arm = RobotBuilder.robotic_arm(Vec3.zero(), {100, 80})
      local mapping = mapper:map_robot(arm)
      local parameters = mapper:generate_parameters(mapping)
      
      -- Check servo function parameters
      assert.are.equal(100, parameters["SERVO1_FUNCTION"])
      assert.are.equal(101, parameters["SERVO2_FUNCTION"])
      
      -- Check default servo parameters
      assert.are.equal(1000, parameters["SERVO1_MIN"])
      assert.are.equal(2000, parameters["SERVO1_MAX"])
      assert.are.equal(1500, parameters["SERVO1_TRIM"])
      assert.are.equal(0, parameters["SERVO1_REVERSED"])
      
      assert.are.equal(1000, parameters["SERVO2_MIN"])
      assert.are.equal(2000, parameters["SERVO2_MAX"])
      assert.are.equal(1500, parameters["SERVO2_TRIM"])
      assert.are.equal(0, parameters["SERVO2_REVERSED"])
    end)
    
    it("should not generate parameters for unassigned channels", function()
      local arm = RobotBuilder.robotic_arm(Vec3.zero(), {100})
      local mapping = mapper:map_robot(arm)
      local parameters = mapper:generate_parameters(mapping)
      
      assert.is_not_nil(parameters["SERVO1_FUNCTION"])
      assert.is_nil(parameters["SERVO2_FUNCTION"])
      assert.is_nil(parameters["SERVO3_FUNCTION"])
    end)
  end)
  
  describe("validation", function()
    local mapper
    
    before_each(function()
      mapper = ServoMapper.new("GENERIC_F4", 8)
    end)
    
    it("should validate robot fits on platform", function()
      local small_arm = RobotBuilder.robotic_arm(Vec3.zero(), {100, 80})
      local success, error_msg = mapper:validate_robot_fit(small_arm)
      
      assert.is_true(success)
      assert.is_nil(error_msg)
    end)
    
    it("should detect when robot exceeds platform capacity", function()
      local large_hexapod = RobotBuilder.hexapod(100, 40, 60, 80)  -- 18 joints
      local success, error_msg = mapper:validate_robot_fit(large_hexapod)
      
      assert.is_false(success)
      assert.is_not_nil(error_msg)
      assert.is_true(string.find(error_msg, "18 servo channels") ~= nil)
      assert.is_true(string.find(error_msg, "8 available") ~= nil)
    end)
    
    it("should account for reserved channels in validation", function()
      mapper:reserve_channels({1, 2, 3, 4}, "motors")
      
      local arm = RobotBuilder.robotic_arm(Vec3.zero(), {100, 80, 60, 40, 20})  -- 5 joints
      local success, error_msg = mapper:validate_robot_fit(arm)
      
      assert.is_false(success)  -- 5 joints + 4 reserved = 9 > 8 available
      assert.is_not_nil(error_msg)
      assert.is_true(string.find(error_msg, "4 reserved") ~= nil)
    end)
  end)
  
  describe("mapping summary", function()
    it("should generate readable summary", function()
      local mapper = ServoMapper.new("CUBE_ORANGE", 16)
      mapper:reserve_channels({1, 2, 3, 4}, "motors")
      mapper:reserve_channels({5, 6}, "gimbal")
      
      local arm = RobotBuilder.robotic_arm(Vec3.zero(), {100, 80})
      local mapping = mapper:map_robot(arm)
      local summary = mapper:get_mapping_summary(mapping)
      
      assert.is_true(string.find(summary, "CUBE_ORANGE") ~= nil)
      assert.is_true(string.find(summary, "max 16 channels") ~= nil)
      assert.is_true(string.find(summary, "Channels used: 2") ~= nil)
      assert.is_true(string.find(summary, "Channel 1: motors") ~= nil)
      assert.is_true(string.find(summary, "Channel 5: gimbal") ~= nil)
      assert.is_true(string.find(summary, "arm_joint_1.*Channel 7") ~= nil)
    end)
  end)
  
  describe("platform limits", function()
    it("should have correct platform limits", function()
      assert.are.equal(16, ServoMapper.PLATFORM_LIMITS.PIXHAWK)
      assert.are.equal(16, ServoMapper.PLATFORM_LIMITS.CUBE_ORANGE)
      assert.are.equal(8, ServoMapper.PLATFORM_LIMITS.GENERIC_F4)
      assert.are.equal(16, ServoMapper.PLATFORM_LIMITS.GENERIC_H7)
    end)
    
    it("should use platform limits correctly", function()
      local f4_mapper = ServoMapper.new("GENERIC_F4")
      local h7_mapper = ServoMapper.new("GENERIC_H7")
      
      assert.are.equal(8, f4_mapper._max_channels)
      assert.are.equal(16, h7_mapper._max_channels)
    end)
  end)
end)