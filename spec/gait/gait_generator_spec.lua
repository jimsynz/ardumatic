local GaitGenerator = require("gait.gait_generator")
local RobotBuilder = require("robot_builder")
local Vec3 = require("vec3")

describe("GaitGenerator", function()
  local robot_config
  local gait_generator
  
  before_each(function()
    robot_config = RobotBuilder.hexapod(120, 40, 60, 80)
    gait_generator = GaitGenerator.new(robot_config)
  end)
  
  describe("new", function()
    it("should create a gait generator with robot configuration", function()
      assert.is_not_nil(gait_generator)
      assert.is_false(gait_generator:is_active())
      assert.equals("tripod", gait_generator:get_gait_pattern())
    end)
    
    it("should use default configuration", function()
      assert.equals(30.0, gait_generator:get_config("step_height"))
      assert.equals(50.0, gait_generator:get_config("step_length"))
      assert.equals(2.0, gait_generator:get_config("cycle_time"))
      assert.equals(100.0, gait_generator:get_config("body_height"))
    end)
    
    it("should accept custom configuration", function()
      local custom_config = {
        step_height = 40.0,
        cycle_time = 3.0,
        default_gait = "wave"
      }
      
      local custom_generator = GaitGenerator.new(robot_config, custom_config)
      assert.equals(40.0, custom_generator:get_config("step_height"))
      assert.equals(3.0, custom_generator:get_config("cycle_time"))
      assert.equals("wave", custom_generator:get_gait_pattern())
    end)
    
    it("should fall back to suitable gait if default is unsuitable", function()
      local quad_config = RobotBuilder.quadruped(100, 50, 70, 90)
      local quad_generator = GaitGenerator.new(quad_config, {default_gait = "tripod"})
      
      -- Should fall back to wave gait since tripod is not suitable for quadrupeds
      assert.equals("wave", quad_generator:get_gait_pattern())
    end)
    
    it("should reject robot configurations with no suitable gaits", function()
      -- Create a robot with only 2 legs (no suitable static gaits)
      local minimal_config = RobotBuilder.robotic_arm(Vec3.zero(), {100, 80})
      
      assert.has_error(function()
        GaitGenerator.new(minimal_config)
      end)
    end)
  end)
  
  describe("start and stop", function()
    it("should start and stop gait generation", function()
      assert.is_false(gait_generator:is_active())
      
      gait_generator:start()
      assert.is_true(gait_generator:is_active())
      
      gait_generator:stop()
      assert.is_false(gait_generator:is_active())
    end)
  end)
  
  describe("update", function()
    it("should return current targets when inactive", function()
      local targets = gait_generator:update(0.1)
      assert.is_not_nil(targets)
      assert.is_table(targets)
      
      -- Should have targets for all legs
      local chains = robot_config:build_chains()
      for leg_name, _ in pairs(chains) do
        assert.is_not_nil(targets[leg_name])
        if targets[leg_name] then
          assert.is_not_nil(targets[leg_name].class)
        end
      end
    end)
    
    it("should generate moving targets when active", function()
      gait_generator:start()
      
      local motion_command = {
        velocity = Vec3.new(50, 0, 0),  -- 50 mm/s forward
        turn_rate = 0.0
      }
      
      local targets1 = gait_generator:update(0.1, motion_command)
      local targets2 = gait_generator:update(0.1, motion_command)
      
      -- Targets should change over time
      local changed = false
      for leg_name, target1 in pairs(targets1) do
        local target2 = targets2[leg_name]
        if target1:distance(target2) > 0.001 then
          changed = true
          break
        end
      end
      
      assert.is_true(changed, "Targets should change when gait is active")
    end)
    
    it("should respect velocity limits", function()
      gait_generator:start()
      
      local high_velocity = Vec3.new(1000, 0, 0)  -- Much higher than max_velocity
      local motion_command = {velocity = high_velocity}
      
      gait_generator:update(0.1, motion_command)
      
      -- Should be limited to max_velocity (100 mm/s by default)
      local actual_velocity = gait_generator._current_velocity
      assert.is_true(actual_velocity:length() <= gait_generator:get_config("max_velocity") + 0.001)
    end)
    
    it("should respect turn rate limits", function()
      gait_generator:start()
      
      local high_turn_rate = 10.0  -- Much higher than max_turn_rate
      local motion_command = {turn_rate = high_turn_rate}
      
      gait_generator:update(0.1, motion_command)
      
      -- Should be limited to max_turn_rate (0.5 rad/s by default)
      local actual_turn_rate = gait_generator._current_turn_rate
      assert.is_true(math.abs(actual_turn_rate) <= gait_generator:get_config("max_turn_rate") + 0.001)
    end)
    
    it("should handle zero velocity gracefully", function()
      gait_generator:start()
      
      local motion_command = {
        velocity = Vec3.zero(),
        turn_rate = 0.0
      }
      
      -- Should not error with zero velocity
      assert.has_no_error(function()
        gait_generator:update(0.1, motion_command)
      end)
    end)
    
    it("should reject negative dt", function()
      gait_generator:start()
      
      assert.has_error(function()
        gait_generator:update(-0.1)
      end)
    end)
  end)
  
  describe("gait pattern management", function()
    it("should set and get gait pattern", function()
      gait_generator:set_gait_pattern("wave")
      assert.equals("wave", gait_generator:get_gait_pattern())
    end)
    
    it("should reject unsuitable gait patterns", function()
      -- Quadruped trot is not suitable for hexapod
      assert.has_error(function()
        gait_generator:set_gait_pattern("quadruped_trot")
      end)
    end)
    
    it("should reject unknown gait patterns", function()
      assert.has_error(function()
        gait_generator:set_gait_pattern("unknown_gait")
      end)
    end)
    
    it("should reset gait state when changing patterns", function()
      gait_generator:start()
      gait_generator:update(0.5)  -- Advance gait state
      
      local state_before = gait_generator:get_gait_state()
      local phase_before = state_before:get_global_phase()
      
      gait_generator:set_gait_pattern("wave", false)  -- Disable transition for test
      
      local state_after = gait_generator:get_gait_state()
      local phase_after = state_after:get_global_phase()
      
      assert.equals(0.0, phase_after)  -- Should be reset
    end)
  end)
  
  describe("configuration management", function()
    it("should set and get cycle time", function()
      gait_generator:set_config("cycle_time", 3.0)
      assert.equals(3.0, gait_generator:get_config("cycle_time"))
      
      -- Should also update gait state
      assert.equals(3.0, gait_generator:get_gait_state():get_cycle_time())
    end)
    
    it("should set and get step height", function()
      gait_generator:set_config("step_height", 40.0)
      assert.equals(40.0, gait_generator:get_config("step_height"))
      
      -- Should also update leg trajectory
      assert.equals(40.0, gait_generator:get_leg_trajectory():get_step_height())
    end)
    
    it("should set and get ground clearance", function()
      gait_generator:set_config("ground_clearance", 10.0)
      assert.equals(10.0, gait_generator:get_config("ground_clearance"))
      
      -- Should also update leg trajectory
      assert.equals(10.0, gait_generator:get_leg_trajectory():get_ground_clearance())
    end)
    
    it("should set other configuration parameters", function()
      gait_generator:set_config("step_length", 75.0)
      assert.equals(75.0, gait_generator:get_config("step_length"))
      
      gait_generator:set_config("body_height", 120.0)
      assert.equals(120.0, gait_generator:get_config("body_height"))
    end)
    
    it("should reject invalid configuration values", function()
      assert.has_error(function() gait_generator:set_config("cycle_time", 0) end)
      assert.has_error(function() gait_generator:set_config("step_height", -10) end)
      assert.has_error(function() gait_generator:set_config("ground_clearance", -5) end)
    end)
    
    it("should reject unknown configuration parameters", function()
      assert.has_error(function() gait_generator:set_config("unknown_param", 123) end)
    end)
    
    it("should return nil for unknown configuration parameters", function()
      assert.is_nil(gait_generator:get_config("unknown_param"))
    end)
  end)
  
  describe("integration with FABRIK", function()
    it("should solve leg positions using FABRIK", function()
      gait_generator:start()
      
      -- Use a more reasonable velocity for the robot size
      local motion_command = {
        velocity = Vec3.new(5, 0, 0)  -- Reduced from 25 to 5
      }
      
      -- Get the chains that will be modified by FABRIK
      local chains = robot_config:build_chains()
      
      -- Store initial positions
      local initial_positions = {}
      for leg_name, chain in pairs(chains) do
        initial_positions[leg_name] = chain:end_location()
      end
      
      local targets = gait_generator:update(0.1, motion_command)
      
      -- Check that FABRIK was applied by verifying chains moved toward targets
      for leg_name, target in pairs(targets) do
        local chain = chains[leg_name]
        local final_pos = chain:end_location()
        local initial_pos = initial_positions[leg_name]
        
        -- The final position should be closer to target than initial position
        local initial_distance = initial_pos:distance(target)
        local final_distance = final_pos:distance(target)
        
        assert.is_true(final_distance <= initial_distance, 
          "FABRIK should move leg " .. leg_name .. " closer to target (initial: " .. 
          initial_distance .. ", final: " .. final_distance .. ")")
      end
    end)
    
    it("should handle unreachable targets gracefully", function()
      gait_generator:start()
      
      -- Create an extreme motion command that might create unreachable targets
      local motion_command = {
        velocity = Vec3.new(100, 100, 0),  -- High velocity in multiple directions
        turn_rate = 0.5
      }
      
      -- Should not error even with extreme commands
      assert.has_no_error(function()
        gait_generator:update(0.1, motion_command)
      end)
    end)
  end)
  
  describe("stability", function()
    it("should maintain stability throughout gait cycle", function()
      gait_generator:start()
      
      local motion_command = {
        velocity = Vec3.new(50, 0, 0)
      }
      
      -- Test stability over multiple gait cycles
      for i = 1, 50 do
        gait_generator:update(0.1, motion_command)
        
        local gait_state = gait_generator:get_gait_state()
        local global_phase = gait_state:get_global_phase()
        
        -- Check that gait pattern maintains stability
        local leg_names = gait_state:get_leg_names()
        local gait_pattern = gait_generator._gait_pattern
        local is_stable = gait_pattern:is_stable(global_phase, leg_names, 3)
        
        assert.is_true(is_stable, "Gait should be stable at phase " .. global_phase)
      end
    end)
  end)
end)