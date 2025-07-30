describe("RobotConfig", function()
  local RobotConfig = require("robot_config")
  local RobotBuilder = require("robot_builder")
  local ConfigValidator = require("config_validator")
  local Vec3 = require("vec3")
  local Angle = require("angle")
  
  describe("basic configuration", function()
    it("should create an empty robot configuration", function()
      local config = RobotConfig.new("test_robot")
      assert.are.equal("test_robot", config:name())
      assert.are.same({}, config._chains)
    end)
    
    it("should allow adding chains", function()
      local config = RobotConfig.new("test_robot")
      local chain_builder = config:add_chain("test_chain", Vec3.new(10, 20, 30))
      
      assert.is_not_nil(config._chains.test_chain)
      assert.are.equal("test_chain", config._chains.test_chain.name)
      assert.are.same({10, 20, 30}, {config._chains.test_chain.origin:x(), 
                                     config._chains.test_chain.origin:y(), 
                                     config._chains.test_chain.origin:z()})
    end)
  end)
  
  describe("chain building", function()
    it("should build a simple hinge joint chain", function()
      local config = RobotConfig.new("simple_arm")
      
      config:add_chain("arm", Vec3.zero())
        :hinge_joint(Vec3.up(), Vec3.forward(), Angle.from_degrees(90), Angle.from_degrees(90))
        :link(100, "segment1")
        :hinge_joint(Vec3.up(), Vec3.forward(), Angle.from_degrees(90), Angle.from_degrees(90))
        :link(80, "segment2")
      
      local chains = config:build_chains()
      local arm = chains.arm
      
      assert.is_not_nil(arm)
      assert.are.equal(2, arm:length())
      assert.are.equal(180, arm:reach())
    end)
    
    it("should build a ball joint chain", function()
      local config = RobotConfig.new("ball_joint_arm")
      
      config:add_chain("arm", Vec3.zero())
        :ball_joint(Vec3.forward(), Angle.from_degrees(45))
        :link(50, "segment1")
      
      local chains = config:build_chains()
      local arm = chains.arm
      
      assert.is_not_nil(arm)
      assert.are.equal(1, arm:length())
      assert.are.equal(50, arm:reach())
    end)
    
    it("should fail when adding link without joint", function()
      local config = RobotConfig.new("invalid_config")
      local chain_builder = config:add_chain("bad_chain", Vec3.zero())
      
      assert.has_error(function()
        chain_builder:link(100, "orphan_link")
      end, "Cannot add link without a joint. Call ball_joint() or hinge_joint() first.")
    end)
  end)
  
  describe("RobotBuilder", function()
    it("should create a valid hexapod configuration", function()
      local hexapod = RobotBuilder.hexapod(100, 40, 60, 80)
      local chains = hexapod:build_chains()
      
      -- Should have 6 legs
      local leg_count = 0
      for _ in pairs(chains) do
        leg_count = leg_count + 1
      end
      assert.are.equal(6, leg_count)
      
      -- Each leg should have 3 segments
      for name, chain in pairs(chains) do
        assert.are.equal(3, chain:length(), "Leg " .. name .. " should have 3 segments")
        assert.are.equal(180, chain:reach(), "Leg " .. name .. " should have reach of 180")
      end
    end)
    
    it("should create a valid quadruped configuration", function()
      local quadruped = RobotBuilder.quadruped(120, 50, 70, 90)
      local chains = quadruped:build_chains()
      
      -- Should have 4 legs
      local leg_count = 0
      for _ in pairs(chains) do
        leg_count = leg_count + 1
      end
      assert.are.equal(4, leg_count)
      
      -- Each leg should have 3 segments
      for name, chain in pairs(chains) do
        assert.are.equal(3, chain:length(), "Leg " .. name .. " should have 3 segments")
        assert.are.equal(210, chain:reach(), "Leg " .. name .. " should have reach of 210")
      end
    end)
    
    it("should create a robotic arm configuration", function()
      local arm = RobotBuilder.robotic_arm(Vec3.new(0, 0, 100), {80, 60, 40})
      local chains = arm:build_chains()
      
      assert.is_not_nil(chains.arm)
      assert.are.equal(3, chains.arm:length())
      assert.are.equal(180, chains.arm:reach())
    end)
  end)
  
  describe("ConfigValidator", function()
    it("should validate a correct configuration", function()
      local config = RobotBuilder.quadruped(100, 40, 60, 80)
      local validator = ConfigValidator.new()
      
      assert.is_true(validator:validate(config))
      assert.are.equal(0, #validator:get_errors())
    end)
    
    it("should detect empty configurations", function()
      local config = RobotConfig.new("empty")
      local validator = ConfigValidator.new()
      
      assert.is_false(validator:validate(config))
      assert.is_true(#validator:get_errors() > 0)
    end)
    
    it("should validate servo channel requirements", function()
      local quadruped = RobotBuilder.quadruped(100, 40, 60, 80)  -- 4 legs × 3 joints = 12 channels
      
      -- Should pass on Pixhawk (16 channels)
      local pixhawk_validator = ConfigValidator.new("PIXHAWK")
      assert.is_true(pixhawk_validator:validate(quadruped))
      
      -- Should fail on F4 with many reserved channels
      local f4_validator = ConfigValidator.new("GENERIC_F4", 8, {
        motors = {1, 2, 3, 4, 5, 6, 7, 8}  -- Reserve all channels
      })
      assert.is_false(f4_validator:validate(quadruped))
    end)
    
    it("should generate servo mappings", function()
      local quadruped = RobotBuilder.quadruped(100, 40, 60, 80)
      local validator = ConfigValidator.new("PIXHAWK", nil, {
        flight_control = {1, 2, 3, 4}
      })
      
      assert.is_true(validator:validate(quadruped))
      
      local mapping = validator:get_servo_mapping(quadruped)
      assert.is_not_nil(mapping)
      assert.are.equal(12, mapping.channels_used)  -- 4 legs * 3 joints each
      
      local parameters = validator:get_servo_parameters(quadruped)
      assert.is_not_nil(parameters)
      assert.is_not_nil(parameters["SERVO5_FUNCTION"])  -- First available channel after reserved
    end)
  end)
  
  describe("error handling", function()
    it("should handle invalid joint configurations", function()
      local config = RobotConfig.new("invalid_joints")
      
      -- This should fail during validation due to zero-length reference axis
      config:add_chain("bad_chain", Vec3.zero())
        :hinge_joint(Vec3.zero(), Vec3.forward())  -- Zero rotation axis
        :link(100, "segment")
      
      local validator = ConfigValidator.new()
      assert.is_false(validator:validate(config))
      
      local errors = validator:get_errors()
      assert.is_true(#errors > 0)
    end)
    
    it("should handle negative link lengths", function()
      local config = RobotConfig.new("negative_links")
      
      -- Manually create invalid configuration
      config._chains.bad_chain = {
        name = "bad_chain",
        origin = Vec3.zero(),
        segments = {
          {
            joint_config = {
              type = "hinge",
              rotation_axis = Vec3.up(),
              reference_axis = Vec3.forward()
            },
            link_length = -50,  -- Invalid negative length
            link_name = "bad_link"
          }
        }
      }
      
      local validator = ConfigValidator.new()
      assert.is_false(validator:validate(config))
      
      local errors = validator:get_errors()
      local found_negative_error = false
      for _, error in ipairs(errors) do
        if string.find(error, "must be positive") then
          found_negative_error = true
          break
        end
      end
      assert.is_true(found_negative_error)
    end)
  end)
end)