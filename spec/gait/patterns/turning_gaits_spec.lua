local TurningGaits = require("gait.patterns.turning_gaits")
local Vec3 = require("vec3")

describe("TurningGaits", function()
  
  describe("DifferentialTripod", function()
    it("should create differential tripod with default turn rate", function()
      local gait = TurningGaits.DifferentialTripod.new()
      
      assert.equals("differential_tripod", gait:get_name())
      assert.equals(0.5, gait:get_duty_factor())
      assert.equals(0.0, gait._turn_rate)
    end)
    
    it("should create differential tripod with custom turn rate", function()
      local turn_rate = 0.5  -- rad/s right turn
      local gait = TurningGaits.DifferentialTripod.new(turn_rate)
      
      assert.equals(turn_rate, gait._turn_rate)
    end)
    
    it("should calculate differential step length correctly", function()
      local gait = TurningGaits.DifferentialTripod.new()
      local base_step = 50.0
      local turn_rate = 0.3
      local leg_radius = 100.0
      
      -- Right turn - right legs should have shorter steps
      local right_step = gait:get_differential_step_length("front_right", base_step, turn_rate, leg_radius)
      local left_step = gait:get_differential_step_length("front_left", base_step, turn_rate, leg_radius)
      
      assert.is_true(right_step < base_step)  -- Inside leg shorter
      assert.is_true(left_step > base_step)   -- Outside leg longer
    end)
    
    it("should handle zero turn rate", function()
      local gait = TurningGaits.DifferentialTripod.new()
      local base_step = 50.0
      local turn_rate = 0.0
      local leg_radius = 100.0
      
      local step_length = gait:get_differential_step_length("front_right", base_step, turn_rate, leg_radius)
      
      assert.equals(base_step, step_length)
    end)
    
    it("should clamp differential factor to reasonable bounds", function()
      local gait = TurningGaits.DifferentialTripod.new()
      local base_step = 50.0
      local extreme_turn_rate = 10.0  -- Very high turn rate
      local leg_radius = 100.0
      
      local step_length = gait:get_differential_step_length("front_right", base_step, extreme_turn_rate, leg_radius)
      
      -- Should be clamped to minimum
      assert.is_true(step_length >= base_step * 0.1)
      assert.is_true(step_length <= base_step * 2.0)
    end)
  end)
  
  describe("DifferentialWave", function()
    it("should create differential wave with default parameters", function()
      local gait = TurningGaits.DifferentialWave.new()
      
      assert.equals("differential_wave", gait:get_name())
      assert.equals(5/6, gait:get_duty_factor())  -- 6 legs default
      assert.equals(0.0, gait._turn_rate)
      assert.equals(6, gait._leg_count)
    end)
    
    it("should create differential wave with custom parameters", function()
      local leg_count = 8
      local turn_rate = -0.2  -- Left turn
      local gait = TurningGaits.DifferentialWave.new(leg_count, turn_rate)
      
      assert.equals(7/8, gait:get_duty_factor())  -- (n-1)/n
      assert.equals(turn_rate, gait._turn_rate)
      assert.equals(leg_count, gait._leg_count)
    end)
    
    it("should adjust phase timing based on turn direction", function()
      local turn_rate = 0.5  -- Right turn
      local gait = TurningGaits.DifferentialWave.new(6, turn_rate)
      
      -- Check that phase offsets are set
      local front_right_phase = gait:get_leg_phase_offset("front_right")
      local front_left_phase = gait:get_leg_phase_offset("front_left")
      
      assert.is_not_nil(front_right_phase)
      assert.is_not_nil(front_left_phase)
      assert.is_true(front_right_phase ~= front_left_phase)
    end)
  end)
  
  describe("CrabWalk", function()
    it("should create crab walk with default direction", function()
      local gait = TurningGaits.CrabWalk.new()
      
      assert.equals("crab_walk", gait:get_name())
      assert.equals(0.5, gait:get_duty_factor())
      assert.equals(0.0, gait._crab_direction)
    end)
    
    it("should create crab walk with custom direction", function()
      local direction = math.pi / 2  -- 90 degrees
      local gait = TurningGaits.CrabWalk.new(direction)
      
      assert.equals(direction, gait._crab_direction)
    end)
    
    it("should calculate crab step vector correctly", function()
      local gait = TurningGaits.CrabWalk.new()
      local direction = 0.0  -- Right
      local step_length = 50.0
      
      local step_vector = gait:get_crab_step_vector(direction, step_length)
      
      assert.equals(step_length, step_vector:x())
      assert.equals(0.0, step_vector:y())
      assert.equals(0.0, step_vector:z())
    end)
    
    it("should handle different crab directions", function()
      local gait = TurningGaits.CrabWalk.new()
      local direction = math.pi / 2  -- Forward
      local step_length = 50.0
      
      local step_vector = gait:get_crab_step_vector(direction, step_length)
      
      -- Should be approximately forward (y-direction)
      assert.is_true(math.abs(step_vector:x()) < 0.1)
      assert.is_true(math.abs(step_vector:y() - step_length) < 0.1)
    end)
  end)
  
  describe("PivotTurn", function()
    it("should create pivot turn with default direction", function()
      local gait = TurningGaits.PivotTurn.new()
      
      assert.equals("pivot_turn", gait:get_name())
      assert.equals(0.5, gait:get_duty_factor())
      assert.equals(1.0, gait._turn_direction)  -- Clockwise
      assert.equals(0.0, gait._pivot_radius)
    end)
    
    it("should create pivot turn with custom direction", function()
      local turn_direction = -1.0  -- Counter-clockwise
      local gait = TurningGaits.PivotTurn.new(turn_direction)
      
      assert.equals(turn_direction, gait._turn_direction)
    end)
    
    it("should calculate pivot step positions correctly", function()
      local gait = TurningGaits.PivotTurn.new(1.0)  -- Clockwise
      local leg_position = Vec3.new(100, 0, -50)
      local body_center = Vec3.new(0, 0, -50)
      local turn_angle = math.pi / 4  -- 45 degrees
      
      local new_position = gait:get_pivot_step_position("front_right", leg_position, body_center, turn_angle)
      
      -- Should be rotated around body center
      assert.is_not_nil(new_position)
      assert.is_true(new_position:distance(body_center) > 0)
      
      -- Z should remain the same
      assert.equals(leg_position:z(), new_position:z())
    end)
    
    it("should handle counter-clockwise rotation", function()
      local gait = TurningGaits.PivotTurn.new(-1.0)  -- Counter-clockwise
      local leg_position = Vec3.new(100, 0, -50)
      local body_center = Vec3.new(0, 0, -50)
      local turn_angle = math.pi / 4
      
      local new_position = gait:get_pivot_step_position("front_right", leg_position, body_center, turn_angle)
      
      -- Should rotate in opposite direction compared to clockwise
      assert.is_not_nil(new_position)
      assert.is_true(new_position:x() ~= leg_position:x() or new_position:y() ~= leg_position:y())
    end)
  end)
  
  describe("factory functions", function()
    describe("create", function()
      it("should create differential tripod", function()
        local gait = TurningGaits.create("differential_tripod", {turn_rate = 0.3})
        
        assert.equals("differential_tripod", gait:get_name())
        assert.equals(0.3, gait._turn_rate)
      end)
      
      it("should create differential wave", function()
        local gait = TurningGaits.create("differential_wave", {leg_count = 8, turn_rate = -0.2})
        
        assert.equals("differential_wave", gait:get_name())
        assert.equals(-0.2, gait._turn_rate)
        assert.equals(8, gait._leg_count)
      end)
      
      it("should create crab walk", function()
        local gait = TurningGaits.create("crab_walk", {direction = math.pi})
        
        assert.equals("crab_walk", gait:get_name())
        assert.equals(math.pi, gait._crab_direction)
      end)
      
      it("should create pivot turn", function()
        local gait = TurningGaits.create("pivot_turn", {turn_direction = -1.0})
        
        assert.equals("pivot_turn", gait:get_name())
        assert.equals(-1.0, gait._turn_direction)
      end)
      
      it("should reject unknown gait names", function()
        assert.has_error(function()
          TurningGaits.create("unknown_gait", {})
        end)
      end)
      
      it("should handle missing parameters", function()
        local gait = TurningGaits.create("differential_tripod", {})
        
        assert.equals("differential_tripod", gait:get_name())
        assert.equals(0.0, gait._turn_rate)  -- Default value
      end)
    end)
    
    describe("get_available_gaits", function()
      it("should return list of available turning gaits", function()
        local gaits = TurningGaits.get_available_gaits()
        
        assert.is_true(#gaits >= 4)
        assert.is_true(table.concat(gaits, ","):find("differential_tripod"))
        assert.is_true(table.concat(gaits, ","):find("differential_wave"))
        assert.is_true(table.concat(gaits, ","):find("crab_walk"))
        assert.is_true(table.concat(gaits, ","):find("pivot_turn"))
      end)
    end)
    
    describe("is_suitable_for_legs", function()
      it("should check differential tripod suitability", function()
        assert.is_true(TurningGaits.is_suitable_for_legs("differential_tripod", 6))
        assert.is_false(TurningGaits.is_suitable_for_legs("differential_tripod", 4))
        assert.is_false(TurningGaits.is_suitable_for_legs("differential_tripod", 8))
      end)
      
      it("should check differential wave suitability", function()
        assert.is_true(TurningGaits.is_suitable_for_legs("differential_wave", 4))
        assert.is_true(TurningGaits.is_suitable_for_legs("differential_wave", 6))
        assert.is_true(TurningGaits.is_suitable_for_legs("differential_wave", 8))
        assert.is_false(TurningGaits.is_suitable_for_legs("differential_wave", 2))
      end)
      
      it("should check crab walk suitability", function()
        assert.is_true(TurningGaits.is_suitable_for_legs("crab_walk", 4))
        assert.is_true(TurningGaits.is_suitable_for_legs("crab_walk", 6))
        assert.is_false(TurningGaits.is_suitable_for_legs("crab_walk", 2))
      end)
      
      it("should check pivot turn suitability", function()
        assert.is_true(TurningGaits.is_suitable_for_legs("pivot_turn", 4))
        assert.is_true(TurningGaits.is_suitable_for_legs("pivot_turn", 6))
        assert.is_false(TurningGaits.is_suitable_for_legs("pivot_turn", 2))
      end)
      
      it("should reject unknown gait names", function()
        assert.is_false(TurningGaits.is_suitable_for_legs("unknown_gait", 6))
      end)
    end)
  end)
  
  describe("integration with gait pattern base", function()
    it("should inherit from GaitPattern", function()
      local gait = TurningGaits.create("differential_tripod", {})
      
      -- Should have GaitPattern methods
      assert.is_function(gait.get_name)
      assert.is_function(gait.get_duty_factor)
      assert.is_function(gait.calculate_leg_phase)
      assert.is_function(gait.set_leg_phase_offset)
      assert.is_function(gait.get_leg_phase_offset)
    end)
    
    it("should calculate leg phases correctly", function()
      local gait = TurningGaits.create("differential_tripod", {})
      local global_phase = 0.25
      
      local leg_phase, is_stance = gait:calculate_leg_phase("front_right", global_phase)
      
      assert.is_number(leg_phase)
      assert.is_boolean(is_stance)
      assert.is_true(leg_phase >= 0.0 and leg_phase <= 1.0)
    end)
    
    it("should maintain tripod pattern timing", function()
      local gait = TurningGaits.create("differential_tripod", {})
      
      -- Check that opposite groups have 0.5 phase offset
      local front_right_offset = gait:get_leg_phase_offset("front_right")
      local front_left_offset = gait:get_leg_phase_offset("front_left")
      
      assert.equals(0.5, math.abs(front_right_offset - front_left_offset))
    end)
  end)
end)