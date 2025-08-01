local GaitTransition = require("gait.gait_transition")
local StaticGaits = require("gait.patterns.static_gaits")
local DynamicGaits = require("gait.patterns.dynamic_gaits")

describe("GaitTransition", function()
  local gait_transition
  local tripod_gait
  local wave_gait
  
  before_each(function()
    gait_transition = GaitTransition.new()
    tripod_gait = StaticGaits.TripodGait.new()
    wave_gait = StaticGaits.WaveGait.new(6)
  end)
  
  describe("new", function()
    it("should create a gait transition manager", function()
      assert.is_not_nil(gait_transition)
      assert.is_false(gait_transition:is_transitioning())
      assert.equals(0.0, gait_transition:get_progress())
    end)
    
    it("should accept custom configuration", function()
      local custom_config = {
        transition_time = 2.0,
        stability_check = false
      }
      
      local custom_transition = GaitTransition.new(custom_config)
      assert.equals(2.0, custom_transition:get_config("transition_time"))
      assert.equals(false, custom_transition:get_config("stability_check"))
    end)
  end)
  
  describe("start_transition", function()
    it("should start transition between different gaits", function()
      local success = gait_transition:start_transition(tripod_gait, wave_gait, 0.0, 0.0)
      
      assert.is_true(success)
      assert.is_true(gait_transition:is_transitioning())
      assert.equals(wave_gait, gait_transition:get_target_gait())
    end)
    
    it("should not start transition between same gaits", function()
      local success = gait_transition:start_transition(tripod_gait, tripod_gait, 0.0, 0.0)
      
      assert.is_false(success)
      assert.is_false(gait_transition:is_transitioning())
    end)
    
    it("should not start transition when already transitioning", function()
      -- Start first transition
      gait_transition:start_transition(tripod_gait, wave_gait, 0.0, 0.0)
      
      -- Try to start second transition
      local dynamic_trot = DynamicGaits.DynamicTrot.new()
      local success = gait_transition:start_transition(wave_gait, dynamic_trot, 0.5, 0.25)
      
      assert.is_false(success)
      assert.equals(wave_gait, gait_transition:get_target_gait())  -- Should still be original target
    end)
  end)
  
  describe("update", function()
    it("should update transition progress", function()
      gait_transition:start_transition(tripod_gait, wave_gait, 0.0, 0.0)
      
      local transition_time = gait_transition:get_config("transition_time")
      local half_time = transition_time * 0.5
      
      local progress, is_complete = gait_transition:update(half_time)
      
      assert.equals(0.5, progress)
      assert.is_false(is_complete)
      assert.is_true(gait_transition:is_transitioning())
    end)
    
    it("should complete transition when time elapsed", function()
      gait_transition:start_transition(tripod_gait, wave_gait, 0.0, 0.0)
      
      local transition_time = gait_transition:get_config("transition_time")
      local progress, is_complete = gait_transition:update(transition_time)
      
      assert.equals(1.0, progress)
      assert.is_true(is_complete)
    end)
    
    it("should return complete when not transitioning", function()
      local progress, is_complete = gait_transition:update(1.0)
      
      assert.equals(1.0, progress)
      assert.is_true(is_complete)
    end)
  end)
  
  describe("calculate_transition_phase", function()
    it("should error when not transitioning", function()
      assert.has_error(function()
        gait_transition:calculate_transition_phase("front_right", 0.0)
      end)
    end)
    
    it("should blend phases during transition", function()
      gait_transition:start_transition(tripod_gait, wave_gait, 0.0, 0.0)
      gait_transition:update(0.5)  -- 50% through transition
      
      local blended_phase, blended_stance = gait_transition:calculate_transition_phase("front_right", 0.0)
      
      assert.is_number(blended_phase)
      assert.is_boolean(blended_stance)
      assert.is_true(blended_phase >= 0.0 and blended_phase <= 1.0)
    end)
    
    it("should handle smooth interpolation", function()
      local smooth_config = {smooth_interpolation = true}
      local smooth_transition = GaitTransition.new(smooth_config)
      
      smooth_transition:start_transition(tripod_gait, wave_gait, 0.0, 0.0)
      smooth_transition:update(0.5)
      
      -- Should not error with smooth interpolation
      assert.has_no_error(function()
        smooth_transition:calculate_transition_phase("front_right", 0.0)
      end)
    end)
  end)
  
  describe("is_transition_safe", function()
    it("should return true when stability check disabled", function()
      local no_check_config = {stability_check = false}
      local no_check_transition = GaitTransition.new(no_check_config)
      
      local leg_positions = {}
      local stance_legs = {"front_right"}  -- Only 1 leg - normally unsafe
      
      local is_safe = no_check_transition:is_transition_safe(leg_positions, stance_legs)
      
      assert.equals(true, is_safe)
    end)
    
    it("should check minimum stance legs when no analyzer provided", function()
      local leg_positions = {}
      local stance_legs = {"front_right", "front_left"}  -- Only 2 legs
      
      local is_safe = gait_transition:is_transition_safe(leg_positions, stance_legs)
      
      assert.is_false(is_safe)  -- Less than 3 legs
    end)
    
    it("should accept sufficient stance legs", function()
      local leg_positions = {}
      local stance_legs = {"front_right", "front_left", "rear_right"}  -- 3 legs
      
      local is_safe = gait_transition:is_transition_safe(leg_positions, stance_legs)
      
      assert.is_true(is_safe)  -- 3 or more legs
    end)
  end)
  
  describe("get_recommended_timing", function()
    it("should return recommended transition time", function()
      local timing = gait_transition:get_recommended_timing(tripod_gait, wave_gait, 50)
      
      assert.is_number(timing)
      assert.is_true(timing > 0)
    end)
    
    it("should adjust for gait complexity difference", function()
      local simple_timing = gait_transition:get_recommended_timing(tripod_gait, tripod_gait, 50)
      local complex_timing = gait_transition:get_recommended_timing(tripod_gait, wave_gait, 50)
      
      -- More complex transitions should take longer
      assert.is_true(complex_timing >= simple_timing)
    end)
    
    it("should adjust for velocity", function()
      local low_vel_timing = gait_transition:get_recommended_timing(tripod_gait, wave_gait, 25)
      local high_vel_timing = gait_transition:get_recommended_timing(tripod_gait, wave_gait, 100)
      
      -- Higher velocities should need more careful transitions
      assert.is_true(high_vel_timing >= low_vel_timing)
    end)
    
    it("should handle zero velocity", function()
      local timing = gait_transition:get_recommended_timing(tripod_gait, wave_gait, 0)
      
      assert.is_number(timing)
      assert.is_true(timing > 0)
    end)
  end)
  
  describe("complete_transition", function()
    it("should reset transition state", function()
      gait_transition:start_transition(tripod_gait, wave_gait, 0.0, 0.0)
      gait_transition:update(0.5)
      
      gait_transition:complete_transition()
      
      assert.is_false(gait_transition:is_transitioning())
      assert.equals(0.0, gait_transition:get_progress())
      assert.is_nil(gait_transition:get_target_gait())
    end)
  end)
  
  describe("configuration management", function()
    it("should set and get configuration parameters", function()
      gait_transition:set_config("transition_time", 2.5)
      assert.equals(2.5, gait_transition:get_config("transition_time"))
      
      gait_transition:set_config("stability_check", false)
      assert.is_false(gait_transition:get_config("stability_check"))
    end)
    
    it("should reject unknown configuration parameters", function()
      assert.has_error(function()
        gait_transition:set_config("unknown_param", 123)
      end)
    end)
  end)
  
  describe("internal methods", function()
    describe("_smooth_step", function()
      it("should provide smooth interpolation", function()
        -- Test boundary conditions
        assert.equals(0.0, gait_transition:_smooth_step(0.0))
        assert.equals(1.0, gait_transition:_smooth_step(1.0))
        
        -- Test smoothness at midpoint
        local mid_value = gait_transition:_smooth_step(0.5)
        assert.equals(0.5, mid_value)
        
        -- Test that it's smoother than linear
        local quarter_value = gait_transition:_smooth_step(0.25)
        assert.is_true(quarter_value < 0.25)  -- Should be below linear interpolation
      end)
    end)
    
    describe("_interpolate_phase", function()
      it("should handle normal phase interpolation", function()
        -- Test case where direct path is shorter than wrap-around
        local result = gait_transition:_interpolate_phase(0.2, 0.6, 0.5)
        assert.is_number(result)
        assert.near(0.4, result, 0.001)  -- 0.2 + (0.6-0.2)*0.5 = 0.4
      end)
      
      it("should handle phase wrap-around", function()
        -- Test wrapping from 0.9 to 0.1 (should go through 1.0/0.0)
        local result = gait_transition:_interpolate_phase(0.9, 0.1, 0.5)
        assert.is_true(result == 0.0 or result == 1.0)  -- Should be at wrap point
      end)
      
      it("should normalize results to 0.0-1.0 range", function()
        local result1 = gait_transition:_interpolate_phase(0.1, 0.9, 0.5)
        local result2 = gait_transition:_interpolate_phase(0.9, 0.1, 0.5)
        
        assert.is_true(result1 >= 0.0 and result1 <= 1.0)
        assert.is_true(result2 >= 0.0 and result2 <= 1.0)
      end)
    end)
  end)
end)