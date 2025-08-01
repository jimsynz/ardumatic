local GaitState = require("gait.gait_state")
local Vec3 = require("vec3")

describe("GaitState", function()
  local gait_state
  local leg_names = {"front_right", "front_left", "rear_right", "rear_left"}
  local cycle_time = 2.0
  
  before_each(function()
    gait_state = GaitState.new(leg_names, cycle_time)
  end)
  
  describe("new", function()
    it("should create a new gait state with valid parameters", function()
      assert.is_not_nil(gait_state)
      assert.equals(cycle_time, gait_state:get_cycle_time())
      assert.equals(0.0, gait_state:get_global_phase())
      assert.equals(0.0, gait_state:get_elapsed_time())
      assert.is_false(gait_state:is_active())
    end)
    
    it("should initialize all legs with default state", function()
      for _, leg_name in ipairs(leg_names) do
        assert.equals(0.0, gait_state:get_leg_phase(leg_name))
        assert.is_true(gait_state:is_leg_stance(leg_name))
        assert.equals(Vec3.zero(), gait_state:get_leg_position(leg_name))
      end
    end)
    
    it("should reject invalid parameters", function()
      assert.has_error(function() GaitState.new(nil, 2.0) end)
      assert.has_error(function() GaitState.new(leg_names, 0) end)
      assert.has_error(function() GaitState.new(leg_names, -1) end)
    end)
  end)
  
  describe("start and stop", function()
    it("should start and stop gait execution", function()
      assert.is_false(gait_state:is_active())
      
      gait_state:start()
      assert.is_true(gait_state:is_active())
      assert.equals(0.0, gait_state:get_elapsed_time())
      assert.equals(0.0, gait_state:get_global_phase())
      
      gait_state:stop()
      assert.is_false(gait_state:is_active())
    end)
  end)
  
  describe("update", function()
    it("should update global phase when active", function()
      gait_state:start()
      
      gait_state:update(0.5)  -- 0.5 seconds
      assert.equals(0.5, gait_state:get_elapsed_time())
      assert.equals(0.25, gait_state:get_global_phase())  -- 0.5 / 2.0 = 0.25
      
      gait_state:update(1.0)  -- Another 1.0 seconds
      assert.equals(1.5, gait_state:get_elapsed_time())
      assert.equals(0.75, gait_state:get_global_phase())  -- 1.5 / 2.0 = 0.75
    end)
    
    it("should wrap global phase at 1.0", function()
      gait_state:start()
      
      gait_state:update(2.5)  -- 2.5 seconds (more than cycle time)
      assert.equals(2.5, gait_state:get_elapsed_time())
      assert.equals(0.25, gait_state:get_global_phase())  -- (2.5 % 2.0) / 2.0 = 0.25
    end)
    
    it("should not update when inactive", function()
      gait_state:update(1.0)
      assert.equals(0.0, gait_state:get_elapsed_time())
      assert.equals(0.0, gait_state:get_global_phase())
    end)
    
    it("should reject negative dt", function()
      gait_state:start()
      assert.has_error(function() gait_state:update(-0.1) end)
    end)
  end)
  
  describe("reset", function()
    it("should reset gait state to beginning", function()
      gait_state:start()
      gait_state:update(1.0)
      gait_state:set_leg_phase("front_right", 0.5, false)
      
      gait_state:reset()
      
      assert.equals(0.0, gait_state:get_elapsed_time())
      assert.equals(0.0, gait_state:get_global_phase())
      assert.equals(0.0, gait_state:get_leg_phase("front_right"))
      assert.is_true(gait_state:is_leg_stance("front_right"))
    end)
  end)
  
  describe("leg phase management", function()
    it("should set and get leg phase", function()
      gait_state:set_leg_phase("front_right", 0.3, false)
      
      assert.equals(0.3, gait_state:get_leg_phase("front_right"))
      assert.is_false(gait_state:is_leg_stance("front_right"))
    end)
    
    it("should reject invalid phase values", function()
      assert.has_error(function() gait_state:set_leg_phase("front_right", -0.1, true) end)
      assert.has_error(function() gait_state:set_leg_phase("front_right", 1.1, true) end)
    end)
    
    it("should reject unknown leg names", function()
      assert.has_error(function() gait_state:set_leg_phase("unknown_leg", 0.5, true) end)
      assert.has_error(function() gait_state:get_leg_phase("unknown_leg") end)
    end)
  end)
  
  describe("leg position management", function()
    it("should set and get leg positions", function()
      local position = Vec3.new(10, 20, 30)
      gait_state:set_leg_position("front_right", position)
      
      assert.equals(position, gait_state:get_leg_position("front_right"))
    end)
    
    it("should set and get leg targets", function()
      local target = Vec3.new(15, 25, 35)
      gait_state:set_leg_target("front_right", target)
      
      assert.equals(target, gait_state:get_leg_target("front_right"))
    end)
    
    it("should set lift-off and touch-down positions", function()
      local lift_off = Vec3.new(5, 10, 15)
      local touch_down = Vec3.new(25, 30, 35)
      
      gait_state:set_leg_lift_off("front_right", lift_off)
      gait_state:set_leg_touch_down("front_right", touch_down)
      
      local leg_state = gait_state:get_leg_state("front_right")
      assert.equals(lift_off, leg_state.lift_off_position)
      assert.equals(touch_down, leg_state.touch_down_position)
    end)
  end)
  
  describe("cycle time management", function()
    it("should set and get cycle time", function()
      gait_state:set_cycle_time(3.0)
      assert.equals(3.0, gait_state:get_cycle_time())
    end)
    
    it("should reject invalid cycle times", function()
      assert.has_error(function() gait_state:set_cycle_time(0) end)
      assert.has_error(function() gait_state:set_cycle_time(-1) end)
    end)
  end)
  
  describe("leg names", function()
    it("should return all leg names", function()
      local names = gait_state:get_leg_names()
      assert.equals(#leg_names, #names)
      
      for _, name in ipairs(leg_names) do
        local found = false
        for _, returned_name in ipairs(names) do
          if name == returned_name then
            found = true
            break
          end
        end
        assert.is_true(found, "Leg name " .. name .. " not found in returned names")
      end
    end)
  end)
end)