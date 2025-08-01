local StaticGaits = require("gait.patterns.static_gaits")

describe("StaticGaits", function()
  describe("TripodGait", function()
    local tripod_gait
    
    before_each(function()
      tripod_gait = StaticGaits.TripodGait.new()
    end)
    
    it("should create a tripod gait with correct parameters", function()
      assert.equals("tripod", tripod_gait:get_name())
      assert.equals(0.5, tripod_gait:get_duty_factor())
    end)
    
    it("should have correct phase offsets for tripod pattern", function()
      -- Group 1 legs (should move together)
      assert.equals(0.0, tripod_gait:get_leg_phase_offset("front_right"))
      assert.equals(0.0, tripod_gait:get_leg_phase_offset("middle_left"))
      assert.equals(0.0, tripod_gait:get_leg_phase_offset("rear_right"))
      
      -- Group 2 legs (should move together, offset by 0.5)
      assert.equals(0.5, tripod_gait:get_leg_phase_offset("front_left"))
      assert.equals(0.5, tripod_gait:get_leg_phase_offset("middle_right"))
      assert.equals(0.5, tripod_gait:get_leg_phase_offset("rear_left"))
    end)
    
    it("should calculate correct leg phases", function()
      local global_phase = 0.0
      
      -- At global phase 0.0, group 1 should be in stance, group 2 in swing
      local phase1, stance1 = tripod_gait:calculate_leg_phase("front_right", global_phase)
      local phase2, stance2 = tripod_gait:calculate_leg_phase("front_left", global_phase)
      
      assert.equals(0.0, phase1)
      assert.is_true(stance1)
      assert.equals(0.5, phase2)
      assert.is_false(stance2)
    end)
    
    it("should maintain stability throughout cycle", function()
      local leg_names = {"front_right", "middle_left", "rear_right", "front_left", "middle_right", "rear_left"}
      
      -- Test specific phases to avoid floating point precision issues
      local test_phases = {0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9}
      for _, phase in ipairs(test_phases) do
        local stance_legs = tripod_gait:get_stance_legs(phase, leg_names)
        local is_stable = tripod_gait:is_stable(phase, leg_names, 3)
        assert.is_true(is_stable, "Tripod gait should be stable at phase " .. phase .. " (stance legs: " .. #stance_legs .. ")")
      end
    end)
  end)
  
  describe("WaveGait", function()
    local wave_gait
    
    before_each(function()
      wave_gait = StaticGaits.WaveGait.new(6)
    end)
    
    it("should create a wave gait with correct parameters", function()
      assert.equals("wave", wave_gait:get_name())
      assert.equals(5/6, wave_gait:get_duty_factor())  -- (6-1)/6
    end)
    
    it("should have sequential phase offsets", function()
      local expected_offsets = {
        front_right = 0/6,
        middle_right = 1/6,
        rear_right = 2/6,
        rear_left = 3/6,
        middle_left = 4/6,
        front_left = 5/6
      }
      
      for leg_name, expected_offset in pairs(expected_offsets) do
        local actual_offset = wave_gait:get_leg_phase_offset(leg_name)
        assert.is_true(math.abs(actual_offset - expected_offset) < 0.001, 
                      "Offset for " .. leg_name .. " should be " .. expected_offset .. " but was " .. actual_offset)
      end
    end)
    
    it("should maintain high stability", function()
      local leg_names = {"front_right", "middle_right", "rear_right", "rear_left", "middle_left", "front_left"}
      
      for phase = 0, 1, 0.05 do
        local stance_legs = wave_gait:get_stance_legs(phase, leg_names)
        assert.is_true(#stance_legs >= 5, "Wave gait should have at least 5 legs in stance at phase " .. phase)
      end
    end)
  end)
  
  describe("RippleGait", function()
    local ripple_gait
    
    before_each(function()
      ripple_gait = StaticGaits.RippleGait.new(6)
    end)
    
    it("should create a ripple gait with correct parameters", function()
      assert.equals("ripple", ripple_gait:get_name())
      assert.equals(0.75, ripple_gait:get_duty_factor())
    end)
    
    it("should maintain stability with faster movement", function()
      local leg_names = {"front_right", "middle_right", "rear_right", "rear_left", "middle_left", "front_left"}
      
      for phase = 0, 1, 0.1 do
        local stance_legs = ripple_gait:get_stance_legs(phase, leg_names)
        assert.is_true(#stance_legs >= 3, "Ripple gait should maintain minimum stability at phase " .. phase)
      end
    end)
  end)
  
  describe("QuadrupedTrot", function()
    local quad_trot
    
    before_each(function()
      quad_trot = StaticGaits.QuadrupedTrot.new()
    end)
    
    it("should create a quadruped trot with correct parameters", function()
      assert.equals("quadruped_trot", quad_trot:get_name())
      assert.equals(0.6, quad_trot:get_duty_factor())
    end)
    
    it("should have diagonal pairs moving together", function()
      -- Diagonal pair 1
      assert.equals(0.0, quad_trot:get_leg_phase_offset("front_right"))
      assert.equals(0.0, quad_trot:get_leg_phase_offset("rear_left"))
      
      -- Diagonal pair 2
      assert.equals(0.5, quad_trot:get_leg_phase_offset("front_left"))
      assert.equals(0.5, quad_trot:get_leg_phase_offset("rear_right"))
    end)
    
    it("should maintain stability for quadruped", function()
      local leg_names = {"front_right", "front_left", "rear_right", "rear_left"}
      
      for phase = 0, 1, 0.1 do
        local stance_legs = quad_trot:get_stance_legs(phase, leg_names)
        assert.is_true(#stance_legs >= 2, "Quadruped trot should have at least 2 legs in stance at phase " .. phase)
      end
    end)
  end)
  
  describe("factory functions", function()
    describe("create", function()
      it("should create tripod gait", function()
        local gait = StaticGaits.create("tripod")
        assert.equals("tripod", gait:get_name())
      end)
      
      it("should create wave gait with leg count", function()
        local gait = StaticGaits.create("wave", 6)
        assert.equals("wave", gait:get_name())
      end)
      
      it("should create ripple gait with leg count", function()
        local gait = StaticGaits.create("ripple", 6)
        assert.equals("ripple", gait:get_name())
      end)
      
      it("should create quadruped trot", function()
        local gait = StaticGaits.create("quadruped_trot")
        assert.equals("quadruped_trot", gait:get_name())
      end)
      
      it("should reject unknown gait names", function()
        assert.has_error(function() StaticGaits.create("unknown_gait") end)
      end)
    end)
    
    describe("get_available_gaits", function()
      it("should return list of available gaits", function()
        local gaits = StaticGaits.get_available_gaits()
        assert.is_true(#gaits >= 4)
        
        local expected_gaits = {"tripod", "wave", "ripple", "quadruped_trot"}
        for _, expected in ipairs(expected_gaits) do
          local found = false
          for _, actual in ipairs(gaits) do
            if actual == expected then
              found = true
              break
            end
          end
          assert.is_true(found, "Expected gait " .. expected .. " not found in available gaits")
        end
      end)
    end)
    
    describe("is_suitable_for_legs", function()
      it("should validate tripod gait for hexapods only", function()
        assert.is_true(StaticGaits.is_suitable_for_legs("tripod", 6))
        assert.is_false(StaticGaits.is_suitable_for_legs("tripod", 4))
        assert.is_false(StaticGaits.is_suitable_for_legs("tripod", 8))
      end)
      
      it("should validate wave gait for 4+ legs", function()
        assert.is_false(StaticGaits.is_suitable_for_legs("wave", 2))
        assert.is_true(StaticGaits.is_suitable_for_legs("wave", 4))
        assert.is_true(StaticGaits.is_suitable_for_legs("wave", 6))
        assert.is_true(StaticGaits.is_suitable_for_legs("wave", 8))
      end)
      
      it("should validate ripple gait for 4+ legs", function()
        assert.is_false(StaticGaits.is_suitable_for_legs("ripple", 2))
        assert.is_true(StaticGaits.is_suitable_for_legs("ripple", 4))
        assert.is_true(StaticGaits.is_suitable_for_legs("ripple", 6))
        assert.is_true(StaticGaits.is_suitable_for_legs("ripple", 8))
      end)
      
      it("should validate quadruped trot for quadrupeds only", function()
        assert.is_false(StaticGaits.is_suitable_for_legs("quadruped_trot", 2))
        assert.is_true(StaticGaits.is_suitable_for_legs("quadruped_trot", 4))
        assert.is_false(StaticGaits.is_suitable_for_legs("quadruped_trot", 6))
      end)
      
      it("should reject unknown gait names", function()
        assert.is_false(StaticGaits.is_suitable_for_legs("unknown_gait", 6))
      end)
    end)
  end)
end)