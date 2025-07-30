describe("RobotBuilder", function()
  local RobotBuilder = require("robot_builder")
  local ConfigValidator = require("config_validator")
  local Vec3 = require("vec3")
  local Angle = require("angle")
  
  describe("hexapod builder", function()
    it("should create hexapod with default dimensions", function()
      local hexapod = RobotBuilder.hexapod()
      local chains = hexapod:build_chains()
      
      -- Should have 6 legs
      local leg_names = {"front_right", "middle_right", "rear_right", 
                        "rear_left", "middle_left", "front_left"}
      
      for _, name in ipairs(leg_names) do
        assert.is_not_nil(chains[name], "Missing leg: " .. name)
        assert.are.equal(3, chains[name]:length(), "Leg " .. name .. " should have 3 segments")
      end
    end)
    
    it("should create hexapod with custom dimensions", function()
      local hexapod = RobotBuilder.hexapod(200, 60, 80, 120)
      local chains = hexapod:build_chains()
      
      -- Check total reach (coxa + femur + tibia = 60 + 80 + 120 = 260)
      for name, chain in pairs(chains) do
        assert.are.equal(260, chain:reach(), "Leg " .. name .. " should have reach of 260")
      end
    end)
    
    it("should position legs correctly", function()
      local hexapod = RobotBuilder.hexapod(100)
      local chains = hexapod:build_chains()
      
      -- Check front right leg position (should be at 60 degrees)
      local front_right = chains.front_right
      local origin = front_right:origin()
      
      -- Expected position: (100 * cos(30°), 100 * sin(30°), 0) = (86.6, 50, 0)
      assert.is_true(math.abs(origin:x() - 86.6) < 0.1, "Front right X position incorrect")
      assert.is_true(math.abs(origin:y() - 50) < 0.1, "Front right Y position incorrect")
      assert.are.equal(0, origin:z(), "Front right Z position should be 0")
    end)
    
    it("should create valid hexapod configuration", function()
      local hexapod = RobotBuilder.hexapod(120, 40, 60, 80)
      local validator = ConfigValidator.new()
      
      -- Note: This will fail servo validation due to 18 joints > 16 channels
      -- but should pass structural validation
      validator:validate(hexapod)
      
      -- Check that we don't have structural errors
      local errors = validator:get_errors()
      local has_structural_error = false
      for _, error in ipairs(errors) do
        if not string.find(error, "Servo channel constraint") then
          has_structural_error = true
          break
        end
      end
      
      assert.is_false(has_structural_error, "Hexapod should not have structural errors")
    end)
  end)
  
  describe("quadruped builder", function()
    it("should create quadruped with default dimensions", function()
      local quadruped = RobotBuilder.quadruped()
      local chains = quadruped:build_chains()
      
      -- Should have 4 legs
      local leg_names = {"front_right", "front_left", "rear_right", "rear_left"}
      
      for _, name in ipairs(leg_names) do
        assert.is_not_nil(chains[name], "Missing leg: " .. name)
        assert.are.equal(3, chains[name]:length(), "Leg " .. name .. " should have 3 segments")
      end
    end)
    
    it("should create quadruped with custom dimensions", function()
      local quadruped = RobotBuilder.quadruped(150, 50, 70, 90)
      local chains = quadruped:build_chains()
      
      -- Check total reach (coxa + femur + tibia = 50 + 70 + 90 = 210)
      for name, chain in pairs(chains) do
        assert.are.equal(210, chain:reach(), "Leg " .. name .. " should have reach of 210")
      end
    end)
    
    it("should position legs in square formation", function()
      local quadruped = RobotBuilder.quadruped(100)
      local chains = quadruped:build_chains()
      
      -- Check leg positions form a square
      local front_right = chains.front_right:origin()
      local front_left = chains.front_left:origin()
      local rear_right = chains.rear_right:origin()
      local rear_left = chains.rear_left:origin()
      
      -- Front right: (50, 50, 0)
      assert.are.equal(50, front_right:x())
      assert.are.equal(50, front_right:y())
      
      -- Front left: (-50, 50, 0)
      assert.are.equal(-50, front_left:x())
      assert.are.equal(50, front_left:y())
      
      -- Rear right: (50, -50, 0)
      assert.are.equal(50, rear_right:x())
      assert.are.equal(-50, rear_right:y())
      
      -- Rear left: (-50, -50, 0)
      assert.are.equal(-50, rear_left:x())
      assert.are.equal(-50, rear_left:y())
    end)
    
    it("should create valid quadruped configuration", function()
      local quadruped = RobotBuilder.quadruped(100, 40, 60, 80)
      local validator = ConfigValidator.new("PIXHAWK")
      
      assert.is_true(validator:validate(quadruped), "Quadruped should be valid")
      assert.are.equal(0, #validator:get_errors(), "Should have no errors")
    end)
  end)
  
  describe("robotic arm builder", function()
    it("should create arm with default parameters", function()
      local arm = RobotBuilder.robotic_arm()
      local chains = arm:build_chains()
      
      assert.is_not_nil(chains.arm, "Should have arm chain")
      assert.are.equal(3, chains.arm:length(), "Should have 3 segments by default")
      assert.are.equal(240, chains.arm:reach(), "Should have reach of 240 (100+80+60)")
    end)
    
    it("should create arm with custom base position", function()
      local base_pos = Vec3.new(10, 20, 30)
      local arm = RobotBuilder.robotic_arm(base_pos, {50, 40})
      local chains = arm:build_chains()
      
      local arm_chain = chains.arm
      assert.are.equal(10, arm_chain:origin():x())
      assert.are.equal(20, arm_chain:origin():y())
      assert.are.equal(30, arm_chain:origin():z())
      assert.are.equal(90, arm_chain:reach())
    end)
    
    it("should create arm with custom segment lengths", function()
      local segments = {120, 100, 80, 60, 40}
      local arm = RobotBuilder.robotic_arm(Vec3.zero(), segments)
      local chains = arm:build_chains()
      
      assert.are.equal(5, chains.arm:length())
      assert.are.equal(400, chains.arm:reach())
    end)
    
    it("should apply custom joint constraints", function()
      local segments = {100, 80}
      local constraints = {Angle.from_degrees(45), Angle.from_degrees(120)}
      local arm = RobotBuilder.robotic_arm(Vec3.zero(), segments, constraints)
      
      -- This should build without errors
      local chains = arm:build_chains()
      assert.is_not_nil(chains.arm)
    end)
    
    it("should create valid arm configuration", function()
      local arm = RobotBuilder.robotic_arm(Vec3.new(0, 0, 100), {80, 60, 40})
      local validator = ConfigValidator.new("PIXHAWK")
      
      assert.is_true(validator:validate(arm), "Arm should be valid")
      assert.are.equal(0, #validator:get_errors(), "Should have no errors")
    end)
  end)
  
  describe("from_spec builder", function()
    it("should build robot from table specification", function()
      local spec = {
        name = "test_robot",
        chains = {
          test_chain = {
            origin = {10, 20, 30},
            segments = {
              {
                joint = {
                  type = "hinge",
                  rotation_axis = {0, 0, 1},
                  reference_axis = {1, 0, 0},
                  clockwise_constraint = 90,
                  anticlockwise_constraint = 90
                },
                link = {
                  length = 100,
                  name = "segment1"
                }
              },
              {
                joint = {
                  type = "ball",
                  reference_axis = {1, 0, 0},
                  max_constraint = 45
                },
                link = {
                  length = 80,
                  name = "segment2"
                }
              }
            }
          }
        }
      }
      
      local robot = RobotBuilder.from_spec(spec)
      assert.are.equal("test_robot", robot:name())
      
      local chains = robot:build_chains()
      assert.is_not_nil(chains.test_chain)
      assert.are.equal(2, chains.test_chain:length())
      assert.are.equal(180, chains.test_chain:reach())
      
      local origin = chains.test_chain:origin()
      assert.are.equal(10, origin:x())
      assert.are.equal(20, origin:y())
      assert.are.equal(30, origin:z())
    end)
    
    it("should handle missing origin in spec", function()
      local spec = {
        name = "simple_robot",
        chains = {
          simple_chain = {
            segments = {
              {
                joint = {
                  type = "hinge",
                  rotation_axis = {0, 0, 1},
                  reference_axis = {1, 0, 0}
                },
                link = {
                  length = 50
                }
              }
            }
          }
        }
      }
      
      local robot = RobotBuilder.from_spec(spec)
      local chains = robot:build_chains()
      
      local origin = chains.simple_chain:origin()
      assert.are.equal(0, origin:x())
      assert.are.equal(0, origin:y())
      assert.are.equal(0, origin:z())
    end)
    
    it("should validate spec requirements", function()
      assert.has_error(function()
        RobotBuilder.from_spec({name = "test"})  -- Missing chains
      end, "Robot specification must include chains")
      
      assert.has_error(function()
        RobotBuilder.from_spec({
          chains = {
            bad_chain = {
              segments = {
                {
                  joint = {type = "unknown_type"},
                  link = {length = 100}
                }
              }
            }
          }
        })
      end, "Unknown joint type: unknown_type")
    end)
    
    it("should create valid robot from spec", function()
      local spec = {
        name = "spec_robot",
        chains = {
          arm = {
            segments = {
              {
                joint = {
                  type = "hinge",
                  rotation_axis = {0, 0, 1},
                  reference_axis = {1, 0, 0},
                  clockwise_constraint = 90
                },
                link = {length = 100, name = "upper"}
              },
              {
                joint = {
                  type = "hinge",
                  rotation_axis = {0, 0, 1},
                  reference_axis = {1, 0, 0},
                  clockwise_constraint = 90
                },
                link = {length = 80, name = "lower"}
              }
            }
          }
        }
      }
      
      local robot = RobotBuilder.from_spec(spec)
      local validator = ConfigValidator.new("PIXHAWK")
      
      assert.is_true(validator:validate(robot), "Spec robot should be valid")
    end)
  end)
  
  describe("edge cases and error handling", function()
    it("should handle zero-length segments", function()
      local arm = RobotBuilder.robotic_arm(Vec3.zero(), {0, 100})
      local validator = ConfigValidator.new()
      
      assert.is_false(validator:validate(arm))
      
      local errors = validator:get_errors()
      local found_zero_error = false
      for _, error in ipairs(errors) do
        if string.find(error, "must be positive") then
          found_zero_error = true
          break
        end
      end
      assert.is_true(found_zero_error, "Should detect zero-length segment")
    end)
    
    it("should handle negative segment lengths", function()
      local arm = RobotBuilder.robotic_arm(Vec3.zero(), {100, -50})
      local validator = ConfigValidator.new()
      
      assert.is_false(validator:validate(arm))
      
      local errors = validator:get_errors()
      local found_negative_error = false
      for _, error in ipairs(errors) do
        if string.find(error, "must be positive") then
          found_negative_error = true
          break
        end
      end
      assert.is_true(found_negative_error, "Should detect negative segment length")
    end)
    
    it("should handle very large robots", function()
      local huge_segments = {}
      for i = 1, 20 do
        table.insert(huge_segments, 100)
      end
      
      local huge_arm = RobotBuilder.robotic_arm(Vec3.zero(), huge_segments)
      local validator = ConfigValidator.new("GENERIC_F4", 8)
      
      assert.is_false(validator:validate(huge_arm))
      
      local errors = validator:get_errors()
      local found_servo_error = false
      for _, error in ipairs(errors) do
        if string.find(error, "servo channels") then
          found_servo_error = true
          break
        end
      end
      assert.is_true(found_servo_error, "Should detect insufficient servo channels")
    end)
  end)
end)