describe("ConfigValidator", function()
  local ConfigValidator = require("config_validator")
  local RobotBuilder = require("robot_builder")
  local RobotConfig = require("robot_config")
  local Vec3 = require("vec3")
  local Angle = require("angle")
  
  describe("initialization", function()
    it("should create validator with default settings", function()
      local validator = ConfigValidator.new()
      assert.is_not_nil(validator._servo_mapper)
      assert.are.equal("PIXHAWK", validator._servo_mapper._platform)
    end)
    
    it("should create validator with custom platform", function()
      local validator = ConfigValidator.new("GENERIC_F4")
      assert.are.equal("GENERIC_F4", validator._servo_mapper._platform)
      assert.are.equal(8, validator._servo_mapper._max_channels)
    end)
    
    it("should create validator with reserved channels", function()
      local reserved = {
        motors = {1, 2, 3, 4},
        gimbal = {5, 6}
      }
      local validator = ConfigValidator.new("PIXHAWK", nil, reserved)
      
      assert.are.equal("motors", validator._servo_mapper._reserved_channels[1])
      assert.are.equal("gimbal", validator._servo_mapper._reserved_channels[5])
    end)
  end)
  
  describe("basic structure validation", function()
    local validator
    
    before_each(function()
      validator = ConfigValidator.new()
    end)
    
    it("should reject nil configuration", function()
      assert.is_false(validator:validate(nil))
      
      local errors = validator:get_errors()
      assert.are.equal(1, #errors)
      assert.are.equal("Configuration is nil", errors[1])
    end)
    
    it("should reject configuration without chains", function()
      local bad_config = {_name = "test"}  -- Missing _chains
      assert.is_false(validator:validate(bad_config))
      
      local errors = validator:get_errors()
      assert.is_true(#errors > 0)
      assert.are.equal("Configuration missing chains", errors[1])
    end)
    
    it("should reject empty configuration", function()
      local empty_config = RobotConfig.new("empty")
      assert.is_false(validator:validate(empty_config))
      
      local errors = validator:get_errors()
      assert.is_true(#errors > 0)
      assert.are.equal("Configuration has no chains defined", errors[1])
    end)
    
    it("should warn about too many chains", function()
      local config = RobotConfig.new("many_chains")
      
      -- Add 15 chains (more than typical servo limit)
      for i = 1, 15 do
        config:add_chain("chain_" .. i, Vec3.zero())
          :hinge_joint(Vec3.up(), Vec3.forward())
          :link(100, "link")
      end
      
      validator:validate(config)
      
      local warnings = validator:get_warnings()
      local found_warning = false
      for _, warning in ipairs(warnings) do
        if string.find(warning, "15 chains") then
          found_warning = true
          break
        end
      end
      assert.is_true(found_warning, "Should warn about too many chains")
    end)
  end)
  
  describe("chain validation", function()
    local validator
    
    before_each(function()
      validator = ConfigValidator.new()
    end)
    
    it("should reject chains with empty names", function()
      local config = RobotConfig.new("test")
      config._chains[""] = {
        name = "",
        origin = Vec3.zero(),
        segments = {}
      }
      
      assert.is_false(validator:validate(config))
      
      local errors = validator:get_errors()
      local found_error = false
      for _, error in ipairs(errors) do
        if string.find(error, "Chain name cannot be empty") then
          found_error = true
          break
        end
      end
      assert.is_true(found_error)
    end)
    
    it("should reject chains without segments", function()
      local config = RobotConfig.new("test")
      config._chains.test_chain = {
        name = "test_chain",
        origin = Vec3.zero()
        -- Missing segments
      }
      
      assert.is_false(validator:validate(config))
      
      local errors = validator:get_errors()
      local found_error = false
      for _, error in ipairs(errors) do
        if string.find(error, "Missing segments") then
          found_error = true
          break
        end
      end
      assert.is_true(found_error)
    end)
    
    it("should reject chains with no segments", function()
      local config = RobotConfig.new("test")
      config._chains.test_chain = {
        name = "test_chain",
        origin = Vec3.zero(),
        segments = {}
      }
      
      assert.is_false(validator:validate(config))
      
      local errors = validator:get_errors()
      local found_error = false
      for _, error in ipairs(errors) do
        if string.find(error, "Chain has no segments") then
          found_error = true
          break
        end
      end
      assert.is_true(found_error)
    end)
    
    it("should warn about chains with many segments", function()
      local config = RobotConfig.new("test")
      config._chains.long_chain = {
        name = "long_chain",
        origin = Vec3.zero(),
        segments = {}
      }
      
      -- Add 8 segments (more than typical)
      for i = 1, 8 do
        table.insert(config._chains.long_chain.segments, {
          joint_config = {
            type = "hinge",
            rotation_axis = Vec3.up(),
            reference_axis = Vec3.forward()
          },
          link_length = 100,
          link_name = "segment_" .. i
        })
      end
      
      validator:validate(config)
      
      local warnings = validator:get_warnings()
      local found_warning = false
      for _, warning in ipairs(warnings) do
        if string.find(warning, "8 segments") then
          found_warning = true
          break
        end
      end
      assert.is_true(found_warning)
    end)
  end)
  
  describe("joint validation", function()
    local validator
    
    before_each(function()
      validator = ConfigValidator.new()
    end)
    
    it("should reject segments without joint configuration", function()
      local config = RobotConfig.new("test")
      config._chains.test_chain = {
        name = "test_chain",
        origin = Vec3.zero(),
        segments = {
          {
            -- Missing joint_config
            link_length = 100,
            link_name = "test_link"
          }
        }
      }
      
      assert.is_false(validator:validate(config))
      
      local errors = validator:get_errors()
      local found_error = false
      for _, error in ipairs(errors) do
        if string.find(error, "Missing joint configuration") then
          found_error = true
          break
        end
      end
      assert.is_true(found_error)
    end)
    
    it("should reject unknown joint types", function()
      local config = RobotConfig.new("test")
      config._chains.test_chain = {
        name = "test_chain",
        origin = Vec3.zero(),
        segments = {
          {
            joint_config = {
              type = "unknown_joint_type"
            },
            link_length = 100
          }
        }
      }
      
      assert.is_false(validator:validate(config))
      
      local errors = validator:get_errors()
      local found_error = false
      for _, error in ipairs(errors) do
        if string.find(error, "Unknown joint type") then
          found_error = true
          break
        end
      end
      assert.is_true(found_error)
    end)
    
    it("should validate ball joint configuration", function()
      local config = RobotConfig.new("test")
      config._chains.test_chain = {
        name = "test_chain",
        origin = Vec3.zero(),
        segments = {
          {
            joint_config = {
              type = "ball",
              reference_axis = Vec3.zero()  -- Invalid: zero vector
            },
            link_length = 100
          }
        }
      }
      
      assert.is_false(validator:validate(config))
      
      local errors = validator:get_errors()
      local found_error = false
      for _, error in ipairs(errors) do
        if string.find(error, "cannot be zero vector") then
          found_error = true
          break
        end
      end
      assert.is_true(found_error)
    end)
    
    it("should validate hinge joint axis perpendicularity", function()
      local config = RobotConfig.new("test")
      config._chains.test_chain = {
        name = "test_chain",
        origin = Vec3.zero(),
        segments = {
          {
            joint_config = {
              type = "hinge",
              rotation_axis = Vec3.forward(),
              reference_axis = Vec3.forward()  -- Same as rotation axis - not perpendicular
            },
            link_length = 100
          }
        }
      }
      
      assert.is_false(validator:validate(config))
      
      local errors = validator:get_errors()
      local found_error = false
      for _, error in ipairs(errors) do
        if string.find(error, "must be perpendicular") then
          found_error = true
          break
        end
      end
      assert.is_true(found_error)
    end)
    
    it("should validate joint constraint angles", function()
      local config = RobotConfig.new("test")
      config._chains.test_chain = {
        name = "test_chain",
        origin = Vec3.zero(),
        segments = {
          {
            joint_config = {
              type = "ball",
              reference_axis = Vec3.forward(),
              max_constraint = Angle.from_degrees(200)  -- Invalid: > 180 degrees
            },
            link_length = 100
          }
        }
      }
      
      assert.is_false(validator:validate(config))
      
      local errors = validator:get_errors()
      local found_error = false
      for _, error in ipairs(errors) do
        if string.find(error, "between 0 and 180 degrees") then
          found_error = true
          break
        end
      end
      assert.is_true(found_error)
    end)
  end)
  
  describe("link validation", function()
    local validator
    
    before_each(function()
      validator = ConfigValidator.new()
    end)
    
    it("should reject segments without link length", function()
      local config = RobotConfig.new("test")
      config._chains.test_chain = {
        name = "test_chain",
        origin = Vec3.zero(),
        segments = {
          {
            joint_config = {
              type = "hinge",
              rotation_axis = Vec3.up(),
              reference_axis = Vec3.forward()
            }
            -- Missing link_length
          }
        }
      }
      
      assert.is_false(validator:validate(config))
      
      local errors = validator:get_errors()
      local found_error = false
      for _, error in ipairs(errors) do
        if string.find(error, "Missing link length") then
          found_error = true
          break
        end
      end
      assert.is_true(found_error)
    end)
    
    it("should reject non-numeric link lengths", function()
      local config = RobotConfig.new("test")
      config._chains.test_chain = {
        name = "test_chain",
        origin = Vec3.zero(),
        segments = {
          {
            joint_config = {
              type = "hinge",
              rotation_axis = Vec3.up(),
              reference_axis = Vec3.forward()
            },
            link_length = "not_a_number"
          }
        }
      }
      
      assert.is_false(validator:validate(config))
      
      local errors = validator:get_errors()
      local found_error = false
      for _, error in ipairs(errors) do
        if string.find(error, "must be a number") then
          found_error = true
          break
        end
      end
      assert.is_true(found_error)
    end)
    
    it("should reject negative link lengths", function()
      local config = RobotConfig.new("test")
      config._chains.test_chain = {
        name = "test_chain",
        origin = Vec3.zero(),
        segments = {
          {
            joint_config = {
              type = "hinge",
              rotation_axis = Vec3.up(),
              reference_axis = Vec3.forward()
            },
            link_length = -50
          }
        }
      }
      
      assert.is_false(validator:validate(config))
      
      local errors = validator:get_errors()
      local found_error = false
      for _, error in ipairs(errors) do
        if string.find(error, "must be positive") then
          found_error = true
          break
        end
      end
      assert.is_true(found_error)
    end)
    
    it("should warn about very large link lengths", function()
      local config = RobotConfig.new("test")
      config._chains.test_chain = {
        name = "test_chain",
        origin = Vec3.zero(),
        segments = {
          {
            joint_config = {
              type = "hinge",
              rotation_axis = Vec3.up(),
              reference_axis = Vec3.forward()
            },
            link_length = 1500  -- Very large
          }
        }
      }
      
      validator:validate(config)
      
      local warnings = validator:get_warnings()
      local found_warning = false
      for _, warning in ipairs(warnings) do
        if string.find(warning, "seems very large") then
          found_warning = true
          break
        end
      end
      assert.is_true(found_warning)
    end)
  end)
  
  describe("servo validation integration", function()
    it("should validate servo requirements for valid robots", function()
      local quadruped = RobotBuilder.quadruped(100, 40, 60, 80)
      local validator = ConfigValidator.new("PIXHAWK")
      
      assert.is_true(validator:validate(quadruped))
      
      local mapping = validator:get_servo_mapping(quadruped)
      assert.is_not_nil(mapping)
      assert.are.equal(12, mapping.channels_used)
      
      local parameters = validator:get_servo_parameters(quadruped)
      assert.is_not_nil(parameters)
      assert.is_not_nil(parameters["SERVO1_FUNCTION"])
    end)
    
    it("should fail validation for robots exceeding servo limits", function()
      local hexapod = RobotBuilder.hexapod(100, 40, 60, 80)  -- 18 joints
      local validator = ConfigValidator.new("GENERIC_F4", 8)  -- Only 8 channels
      
      assert.is_false(validator:validate(hexapod))
      
      local errors = validator:get_errors()
      local found_servo_error = false
      for _, error in ipairs(errors) do
        if string.find(error, "Servo channel constraint") then
          found_servo_error = true
          break
        end
      end
      assert.is_true(found_servo_error)
    end)
    
    it("should return nil mapping for invalid configurations", function()
      local invalid_config = RobotConfig.new("invalid")
      local validator = ConfigValidator.new()
      
      assert.is_false(validator:validate(invalid_config))
      
      local mapping = validator:get_servo_mapping(invalid_config)
      assert.is_nil(mapping)
      
      local parameters = validator:get_servo_parameters(invalid_config)
      assert.is_nil(parameters)
    end)
  end)
  
  describe("physical constraints validation", function()
    local validator
    
    before_each(function()
      validator = ConfigValidator.new()
    end)
    
    it("should warn about zero total reach", function()
      local config = RobotConfig.new("test")
      config._chains.zero_reach = {
        name = "zero_reach",
        origin = Vec3.zero(),
        segments = {
          {
            joint_config = {
              type = "hinge",
              rotation_axis = Vec3.up(),
              reference_axis = Vec3.forward()
            },
            link_length = 0
          }
        }
      }
      
      validator:validate(config)
      
      local warnings = validator:get_warnings()
      local found_warning = false
      for _, warning in ipairs(warnings) do
        if string.find(warning, "zero total reach") then
          found_warning = true
          break
        end
      end
      assert.is_true(found_warning)
    end)
    
    it("should warn about very large total reach", function()
      local config = RobotConfig.new("test")
      config._chains.huge_reach = {
        name = "huge_reach",
        origin = Vec3.zero(),
        segments = {
          {
            joint_config = {
              type = "hinge",
              rotation_axis = Vec3.up(),
              reference_axis = Vec3.forward()
            },
            link_length = 2500  -- Very large
          }
        }
      }
      
      validator:validate(config)
      
      local warnings = validator:get_warnings()
      local found_warning = false
      for _, warning in ipairs(warnings) do
        if string.find(warning, "very large total reach") then
          found_warning = true
          break
        end
      end
      assert.is_true(found_warning)
    end)
  end)
end)