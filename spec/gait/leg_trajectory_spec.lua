local LegTrajectory = require("gait.leg_trajectory")
local Vec3 = require("vec3")

describe("LegTrajectory", function()
  local trajectory
  local step_height = 30.0
  local ground_clearance = 5.0
  
  before_each(function()
    trajectory = LegTrajectory.new(step_height, ground_clearance)
  end)
  
  describe("new", function()
    it("should create a new trajectory generator with valid parameters", function()
      assert.is_not_nil(trajectory)
      assert.equals(step_height, trajectory:get_step_height())
      assert.equals(ground_clearance, trajectory:get_ground_clearance())
    end)
    
    it("should use default parameters when not provided", function()
      local default_trajectory = LegTrajectory.new()
      assert.equals(30.0, default_trajectory:get_step_height())
      assert.equals(5.0, default_trajectory:get_ground_clearance())
    end)
    
    it("should reject invalid parameters", function()
      assert.has_error(function() LegTrajectory.new(-1, 5) end)
      assert.has_error(function() LegTrajectory.new(30, -1) end)
    end)
  end)
  
  describe("stance_trajectory", function()
    it("should interpolate linearly between start and end positions", function()
      local start_pos = Vec3.new(0, 0, 0)
      local end_pos = Vec3.new(100, 0, 0)
      
      local pos_0 = trajectory:stance_trajectory(start_pos, end_pos, 0.0)
      local pos_half = trajectory:stance_trajectory(start_pos, end_pos, 0.5)
      local pos_1 = trajectory:stance_trajectory(start_pos, end_pos, 1.0)
      
      assert.equals(start_pos, pos_0)
      assert.equals(Vec3.new(50, 0, 0), pos_half)
      assert.equals(end_pos, pos_1)
    end)
    
    it("should handle vertical movement", function()
      local start_pos = Vec3.new(0, 0, 100)
      local end_pos = Vec3.new(0, 0, 50)
      
      local pos_quarter = trajectory:stance_trajectory(start_pos, end_pos, 0.25)
      assert.equals(Vec3.new(0, 0, 87.5), pos_quarter)
    end)
    
    it("should reject invalid phase values", function()
      local start_pos = Vec3.zero()
      local end_pos = Vec3.new(100, 0, 0)
      
      assert.has_error(function() trajectory:stance_trajectory(start_pos, end_pos, -0.1) end)
      assert.has_error(function() trajectory:stance_trajectory(start_pos, end_pos, 1.1) end)
    end)
  end)
  
  describe("swing_trajectory", function()
    it("should create an arc trajectory", function()
      local lift_off = Vec3.new(0, 0, 0)
      local touch_down = Vec3.new(100, 0, 0)
      
      local pos_0 = trajectory:swing_trajectory(lift_off, touch_down, 0.0)
      local pos_half = trajectory:swing_trajectory(lift_off, touch_down, 0.5)
      local pos_1 = trajectory:swing_trajectory(lift_off, touch_down, 1.0)
      
      -- Should start and end at specified positions horizontally
      assert.equals(lift_off:x(), pos_0:x())
      assert.equals(touch_down:x(), pos_1:x())
      
      -- Should be at midpoint horizontally at phase 0.5
      assert.equals(50, pos_half:x())
      
      -- Should lift above both start and end positions
      assert.is_true(pos_half:z() > lift_off:z())
      assert.is_true(pos_half:z() > touch_down:z())
    end)
    
    it("should respect step height", function()
      local lift_off = Vec3.new(0, 0, 0)
      local touch_down = Vec3.new(100, 0, 0)
      
      local max_height = -math.huge
      for phase = 0, 1, 0.1 do
        local pos = trajectory:swing_trajectory(lift_off, touch_down, phase)
        max_height = math.max(max_height, pos:z())
      end
      
      -- Maximum height should be approximately step_height above ground
      assert.is_true(max_height >= step_height - 1)  -- Allow small tolerance
    end)
    
    it("should respect ground clearance", function()
      local lift_off = Vec3.new(0, 0, 0)
      local touch_down = Vec3.new(100, 0, 0)
      local ground_height = 10.0
      
      -- Test that the peak of the trajectory respects ground clearance
      local peak_pos = trajectory:swing_trajectory(lift_off, touch_down, 0.5, ground_height)
      local required_min = ground_height + ground_clearance
      
      -- Peak should be at least at ground clearance height
      assert.is_true(peak_pos:z() >= required_min, 
        "Peak height " .. peak_pos:z() .. " should be >= " .. required_min)
      
      -- Also test that the trajectory doesn't go below ground level
      local min_height = math.huge
      for phase = 0, 1, 0.1 do
        local pos = trajectory:swing_trajectory(lift_off, touch_down, phase, ground_height)
        min_height = math.min(min_height, pos:z())
      end
      
      -- Should not go below ground level
      assert.is_true(min_height >= 0, "Trajectory should not go below ground level")
    end)
    
    it("should handle different lift-off and touch-down heights", function()
      local lift_off = Vec3.new(0, 0, 10)
      local touch_down = Vec3.new(100, 0, 20)
      
      local pos_0 = trajectory:swing_trajectory(lift_off, touch_down, 0.0)
      local pos_1 = trajectory:swing_trajectory(lift_off, touch_down, 1.0)
      
      assert.equals(lift_off:z(), pos_0:z())
      assert.equals(touch_down:z(), pos_1:z())
    end)
  end)
  
  describe("collision_aware_trajectory", function()
    it("should return basic trajectory when no body bounds provided", function()
      local lift_off = Vec3.new(0, 0, 0)
      local touch_down = Vec3.new(100, 0, 0)
      
      local basic_pos = trajectory:swing_trajectory(lift_off, touch_down, 0.5)
      local collision_pos = trajectory:collision_aware_trajectory(lift_off, touch_down, 0.5)
      
      assert.equals(basic_pos, collision_pos)
    end)
    
    it("should increase height when too close to body", function()
      local lift_off = Vec3.new(0, 0, 0)
      local touch_down = Vec3.new(100, 0, 0)
      
      local body_bounds = {
        center = Vec3.new(50, 0, 0),
        radius = 60,
        clearance = 20
      }
      
      local basic_pos = trajectory:swing_trajectory(lift_off, touch_down, 0.5)
      local collision_pos = trajectory:collision_aware_trajectory(lift_off, touch_down, 0.5, body_bounds)
      
      -- Should be higher to avoid collision
      assert.is_true(collision_pos:z() > basic_pos:z())
    end)
    
    it("should not modify trajectory when far from body", function()
      local lift_off = Vec3.new(0, 0, 0)
      local touch_down = Vec3.new(200, 0, 0)  -- Far from body
      
      local body_bounds = {
        center = Vec3.new(50, 0, 0),
        radius = 30,
        clearance = 10
      }
      
      local basic_pos = trajectory:swing_trajectory(lift_off, touch_down, 0.5)
      local collision_pos = trajectory:collision_aware_trajectory(lift_off, touch_down, 0.5, body_bounds)
      
      assert.equals(basic_pos, collision_pos)
    end)
  end)
  
  describe("get_trajectory_velocity", function()
    it("should calculate velocity vector", function()
      local lift_off = Vec3.new(0, 0, 0)
      local touch_down = Vec3.new(100, 0, 0)
      
      local velocity = trajectory:get_trajectory_velocity(lift_off, touch_down, 0.5)
      
      -- Should have positive x velocity (moving forward)
      assert.is_true(velocity:x() > 0)
      
      -- Velocity should be a Vec3
      assert.is_not_nil(velocity.class)
    end)
    
    it("should use custom dt for differentiation", function()
      local lift_off = Vec3.new(0, 0, 0)
      local touch_down = Vec3.new(100, 0, 0)
      
      local velocity1 = trajectory:get_trajectory_velocity(lift_off, touch_down, 0.5, 0.01)
      local velocity2 = trajectory:get_trajectory_velocity(lift_off, touch_down, 0.5, 0.001)
      
      -- Different dt should give similar but not identical results
      assert.is_true(math.abs(velocity1:x() - velocity2:x()) < 10)  -- Should be close
    end)
  end)
  
  describe("parameter management", function()
    it("should set and get step height", function()
      trajectory:set_step_height(50.0)
      assert.equals(50.0, trajectory:get_step_height())
    end)
    
    it("should set and get ground clearance", function()
      trajectory:set_ground_clearance(10.0)
      assert.equals(10.0, trajectory:get_ground_clearance())
    end)
    
    it("should reject invalid step height", function()
      assert.has_error(function() trajectory:set_step_height(0) end)
      assert.has_error(function() trajectory:set_step_height(-5) end)
    end)
    
    it("should reject invalid ground clearance", function()
      assert.has_error(function() trajectory:set_ground_clearance(-1) end)
    end)
  end)
end)