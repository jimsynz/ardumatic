local DynamicGaits = require("gait.patterns.dynamic_gaits")

describe("DynamicGaits", function()
  describe("DynamicTrot", function()
    local dynamic_trot
    
    before_each(function()
      dynamic_trot = DynamicGaits.DynamicTrot.new()
    end)
    
    it("should create a dynamic trot with correct parameters", function()
      assert.equals("dynamic_trot", dynamic_trot:get_name())
      assert.equals(0.6, dynamic_trot:get_duty_factor())
    end)
    
    it("should have diagonal pairs moving together", function()
      -- Diagonal pair 1
      assert.equals(0.0, dynamic_trot:get_leg_phase_offset("front_right"))
      assert.equals(0.0, dynamic_trot:get_leg_phase_offset("rear_left"))
      
      -- Diagonal pair 2
      assert.equals(0.5, dynamic_trot:get_leg_phase_offset("front_left"))
      assert.equals(0.5, dynamic_trot:get_leg_phase_offset("rear_right"))
    end)
    
    it("should calculate correct leg phases", function()
      local global_phase = 0.0
      
      -- At global phase 0.0, diagonal pair 1 should be in stance
      local phase1, stance1 = dynamic_trot:calculate_leg_phase("front_right", global_phase)
      local phase2, stance2 = dynamic_trot:calculate_leg_phase("rear_left", global_phase)
      
      assert.equals(0.0, phase1)
      assert.equals(0.0, phase2)
      assert.is_true(stance1)
      assert.is_true(stance2)
    end)
  end)
  
  describe("BoundGait", function()
    local bound_gait
    
    before_each(function()
      bound_gait = DynamicGaits.BoundGait.new()
    end)
    
    it("should create a bound gait with correct parameters", function()
      assert.equals("bound", bound_gait:get_name())
      assert.equals(0.35, bound_gait:get_duty_factor())
    end)
    
    it("should have front and rear pairs moving together", function()
      -- Front pair
      assert.equals(0.0, bound_gait:get_leg_phase_offset("front_right"))
      assert.equals(0.0, bound_gait:get_leg_phase_offset("front_left"))
      
      -- Rear pair
      assert.equals(0.5, bound_gait:get_leg_phase_offset("rear_right"))
      assert.equals(0.5, bound_gait:get_leg_phase_offset("rear_left"))
    end)
  end)
  
  describe("GallopGait", function()
    local gallop_gait
    
    before_each(function()
      gallop_gait = DynamicGaits.GallopGait.new()
    end)
    
    it("should create a gallop gait with correct parameters", function()
      assert.equals("gallop", gallop_gait:get_name())
      assert.equals(0.25, gallop_gait:get_duty_factor())
    end)
    
    it("should have asymmetric timing pattern", function()
      -- Right lead gallop sequence
      assert.equals(0.0, gallop_gait:get_leg_phase_offset("front_right"))
      assert.equals(0.125, gallop_gait:get_leg_phase_offset("front_left"))
      assert.equals(0.25, gallop_gait:get_leg_phase_offset("rear_right"))
      assert.equals(0.375, gallop_gait:get_leg_phase_offset("rear_left"))
    end)
  end)
  
  describe("PronkGait", function()
    local pronk_gait
    
    before_each(function()
      pronk_gait = DynamicGaits.PronkGait.new()
    end)
    
    it("should create a pronk gait with correct parameters", function()
      assert.equals("pronk", pronk_gait:get_name())
      assert.equals(0.3, pronk_gait:get_duty_factor())
    end)
    
    it("should have all legs moving together", function()
      assert.equals(0.0, pronk_gait:get_leg_phase_offset("front_right"))
      assert.equals(0.0, pronk_gait:get_leg_phase_offset("front_left"))
      assert.equals(0.0, pronk_gait:get_leg_phase_offset("rear_right"))
      assert.equals(0.0, pronk_gait:get_leg_phase_offset("rear_left"))
    end)
  end)
  
  describe("FastTripodGait", function()
    local fast_tripod
    
    before_each(function()
      fast_tripod = DynamicGaits.FastTripodGait.new()
    end)
    
    it("should create a fast tripod with correct parameters", function()
      assert.equals("fast_tripod", fast_tripod:get_name())
      assert.equals(0.35, fast_tripod:get_duty_factor())
    end)
    
    it("should maintain tripod pattern with lower duty factor", function()
      -- Group 1 legs
      assert.equals(0.0, fast_tripod:get_leg_phase_offset("front_right"))
      assert.equals(0.0, fast_tripod:get_leg_phase_offset("middle_left"))
      assert.equals(0.0, fast_tripod:get_leg_phase_offset("rear_right"))
      
      -- Group 2 legs
      assert.equals(0.5, fast_tripod:get_leg_phase_offset("front_left"))
      assert.equals(0.5, fast_tripod:get_leg_phase_offset("middle_right"))
      assert.equals(0.5, fast_tripod:get_leg_phase_offset("rear_left"))
    end)
  end)
  
  describe("DynamicWaveGait", function()
    local dynamic_wave
    
    before_each(function()
      dynamic_wave = DynamicGaits.DynamicWaveGait.new(6)
    end)
    
    it("should create a dynamic wave with correct parameters", function()
      assert.equals("dynamic_wave", dynamic_wave:get_name())
      assert.equals(0.6, dynamic_wave:get_duty_factor())
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
        local actual_offset = dynamic_wave:get_leg_phase_offset(leg_name)
        assert.is_true(math.abs(actual_offset - expected_offset) < 0.001, 
                      "Offset for " .. leg_name .. " should be " .. expected_offset .. " but was " .. actual_offset)
      end
    end)
  end)
  
  describe("aerial phase detection", function()
    it("should detect aerial phases in dynamic gaits", function()
      local leg_names = {"front_right", "front_left", "rear_right", "rear_left"}
      
      local pronk = DynamicGaits.PronkGait.new()
      local has_aerial = DynamicGaits.has_aerial_phase(pronk, leg_names)
      
      assert.is_true(has_aerial)
    end)
    
    it("should not detect aerial phases in conservative gaits", function()
      local leg_names = {"front_right", "front_left", "rear_right", "rear_left"}
      
      local dynamic_trot = DynamicGaits.DynamicTrot.new()
      local has_aerial = DynamicGaits.has_aerial_phase(dynamic_trot, leg_names)
      
      -- Dynamic trot with 40% duty factor should still maintain some ground contact
      assert.is_false(has_aerial)
    end)
  end)
  
  describe("minimum stance legs", function()
    it("should calculate minimum stance legs correctly", function()
      local leg_names = {"front_right", "front_left", "rear_right", "rear_left"}
      
      local dynamic_trot = DynamicGaits.DynamicTrot.new()
      local min_stance = DynamicGaits.get_min_stance_legs(dynamic_trot, leg_names)
      
      -- Dynamic trot should have at least 2 legs in stance (diagonal pairs)
      assert.is_true(min_stance >= 2)
    end)
    
    it("should handle pronk gait correctly", function()
      local leg_names = {"front_right", "front_left", "rear_right", "rear_left"}
      
      local pronk = DynamicGaits.PronkGait.new()
      local min_stance = DynamicGaits.get_min_stance_legs(pronk, leg_names)
      
      -- Pronk can have 0 legs in stance during aerial phase
      assert.equals(0, min_stance)
    end)
  end)
  
  describe("velocity requirements", function()
    it("should return velocity requirements for dynamic gaits", function()
      local trot_req = DynamicGaits.get_velocity_requirements("dynamic_trot")
      assert.is_not_nil(trot_req.min_velocity)
      assert.is_not_nil(trot_req.recommended_velocity)
      assert.is_true(trot_req.recommended_velocity > trot_req.min_velocity)
      
      local gallop_req = DynamicGaits.get_velocity_requirements("gallop")
      assert.is_true(gallop_req.min_velocity > trot_req.min_velocity)
    end)
    
    it("should return default requirements for unknown gaits", function()
      local unknown_req = DynamicGaits.get_velocity_requirements("unknown_gait")
      assert.equals(50, unknown_req.min_velocity)
      assert.equals(100, unknown_req.recommended_velocity)
    end)
  end)
  
  describe("factory functions", function()
    describe("create", function()
      it("should create dynamic trot", function()
        local gait = DynamicGaits.create("dynamic_trot")
        assert.equals("dynamic_trot", gait:get_name())
      end)
      
      it("should create bound gait", function()
        local gait = DynamicGaits.create("bound")
        assert.equals("bound", gait:get_name())
      end)
      
      it("should create gallop gait", function()
        local gait = DynamicGaits.create("gallop")
        assert.equals("gallop", gait:get_name())
      end)
      
      it("should create pronk gait", function()
        local gait = DynamicGaits.create("pronk")
        assert.equals("pronk", gait:get_name())
      end)
      
      it("should create fast tripod", function()
        local gait = DynamicGaits.create("fast_tripod")
        assert.equals("fast_tripod", gait:get_name())
      end)
      
      it("should create dynamic wave with leg count", function()
        local gait = DynamicGaits.create("dynamic_wave", 6)
        assert.equals("dynamic_wave", gait:get_name())
      end)
      
      it("should reject unknown gait names", function()
        assert.has_error(function() DynamicGaits.create("unknown_gait") end)
      end)
    end)
    
    describe("get_available_gaits", function()
      it("should return list of available dynamic gaits", function()
        local gaits = DynamicGaits.get_available_gaits()
        assert.is_true(#gaits >= 6)
        
        local expected_gaits = {"dynamic_trot", "bound", "gallop", "pronk", "fast_tripod", "dynamic_wave"}
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
      it("should validate quadruped gaits for 4 legs", function()
        assert.is_true(DynamicGaits.is_suitable_for_legs("dynamic_trot", 4))
        assert.is_true(DynamicGaits.is_suitable_for_legs("bound", 4))
        assert.is_true(DynamicGaits.is_suitable_for_legs("gallop", 4))
        assert.is_true(DynamicGaits.is_suitable_for_legs("pronk", 4))
        
        assert.is_false(DynamicGaits.is_suitable_for_legs("dynamic_trot", 6))
        assert.is_false(DynamicGaits.is_suitable_for_legs("bound", 6))
      end)
      
      it("should validate hexapod gaits for 6 legs", function()
        assert.is_true(DynamicGaits.is_suitable_for_legs("fast_tripod", 6))
        assert.is_false(DynamicGaits.is_suitable_for_legs("fast_tripod", 4))
      end)
      
      it("should validate dynamic wave for 4+ legs", function()
        assert.is_false(DynamicGaits.is_suitable_for_legs("dynamic_wave", 2))
        assert.is_true(DynamicGaits.is_suitable_for_legs("dynamic_wave", 4))
        assert.is_true(DynamicGaits.is_suitable_for_legs("dynamic_wave", 6))
        assert.is_true(DynamicGaits.is_suitable_for_legs("dynamic_wave", 8))
      end)
      
      it("should reject unknown gait names", function()
        assert.is_false(DynamicGaits.is_suitable_for_legs("unknown_gait", 4))
      end)
    end)
    
    describe("requires_dynamic_stability", function()
      it("should identify gaits requiring dynamic stability", function()
        assert.is_true(DynamicGaits.requires_dynamic_stability("dynamic_trot"))
        assert.is_true(DynamicGaits.requires_dynamic_stability("bound"))
        assert.is_true(DynamicGaits.requires_dynamic_stability("gallop"))
        assert.is_true(DynamicGaits.requires_dynamic_stability("pronk"))
      end)
      
      it("should identify gaits not requiring dynamic stability", function()
        assert.is_false(DynamicGaits.requires_dynamic_stability("fast_tripod"))
        assert.is_false(DynamicGaits.requires_dynamic_stability("dynamic_wave"))
      end)
      
      it("should return false for unknown gaits", function()
        assert.is_false(DynamicGaits.requires_dynamic_stability("unknown_gait"))
      end)
    end)
  end)
end)