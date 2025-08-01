local Object = require("object")
local Scalar = require("scalar")
local Vec3 = require("vec3")

--- Gait State
--
-- Tracks the current state of gait execution including phase, leg positions,
-- and timing information for smooth gait progression.
local GaitState = Object.new("GaitState")

--- Create a new gait state
--
-- @param leg_names array of leg names from robot configuration
-- @param cycle_time total time for one complete gait cycle (seconds)
function GaitState.new(leg_names, cycle_time)
  assert(type(leg_names) == "table", "leg_names must be an array")
  Scalar.assert_type(cycle_time, "number")
  assert(cycle_time > 0, "cycle_time must be positive")
  
  local leg_states = {}
  for _, leg_name in ipairs(leg_names) do
    leg_states[leg_name] = {
      phase = 0.0,              -- Current phase (0.0-1.0)
      is_stance = true,         -- True if leg is in stance phase
      current_position = Vec3.zero(),  -- Current foot position
      target_position = Vec3.zero(),   -- Target foot position
      lift_off_position = Vec3.zero(), -- Position when leg lifted
      touch_down_position = Vec3.zero() -- Position when leg touches down
    }
  end
  
  return Object.instance({
    _leg_names = leg_names,
    _leg_states = leg_states,
    _cycle_time = cycle_time,
    _global_phase = 0.0,
    _elapsed_time = 0.0,
    _is_active = false
  }, GaitState)
end

--- Update the gait state with elapsed time
--
-- @param dt time delta in seconds
function GaitState:update(dt)
  Scalar.assert_type(dt, "number")
  assert(dt >= 0, "dt must be non-negative")
  
  if not self._is_active then
    return
  end
  
  self._elapsed_time = self._elapsed_time + dt
  self._global_phase = (self._elapsed_time / self._cycle_time) % 1.0
end

--- Start gait execution
function GaitState:start()
  self._is_active = true
  self._elapsed_time = 0.0
  self._global_phase = 0.0
end

--- Stop gait execution
function GaitState:stop()
  self._is_active = false
end

--- Reset gait state to beginning of cycle
function GaitState:reset()
  self._elapsed_time = 0.0
  self._global_phase = 0.0
  
  for _, leg_state in pairs(self._leg_states) do
    leg_state.phase = 0.0
    leg_state.is_stance = true
  end
end

--- Set the phase for a specific leg
--
-- @param leg_name name of the leg
-- @param phase phase value (0.0-1.0)
-- @param is_stance true if leg is in stance phase
function GaitState:set_leg_phase(leg_name, phase, is_stance)
  Scalar.assert_type(leg_name, "string")
  Scalar.assert_type(phase, "number")
  assert(phase >= 0.0 and phase <= 1.0, "phase must be between 0.0 and 1.0")
  assert(self._leg_states[leg_name], "Unknown leg name: " .. leg_name)
  
  local leg_state = self._leg_states[leg_name]
  leg_state.phase = phase
  leg_state.is_stance = is_stance or false
end

--- Get the phase for a specific leg
--
-- @param leg_name name of the leg
-- @return phase value (0.0-1.0)
function GaitState:get_leg_phase(leg_name)
  Scalar.assert_type(leg_name, "string")
  assert(self._leg_states[leg_name], "Unknown leg name: " .. leg_name)
  
  return self._leg_states[leg_name].phase
end

--- Check if a leg is in stance phase
--
-- @param leg_name name of the leg
-- @return true if leg is in stance phase
function GaitState:is_leg_stance(leg_name)
  Scalar.assert_type(leg_name, "string")
  assert(self._leg_states[leg_name], "Unknown leg name: " .. leg_name)
  
  return self._leg_states[leg_name].is_stance
end

--- Set current position for a leg
--
-- @param leg_name name of the leg
-- @param position Vec3 position
function GaitState:set_leg_position(leg_name, position)
  Scalar.assert_type(leg_name, "string")
  Object.assert_type(position, Vec3)
  assert(self._leg_states[leg_name], "Unknown leg name: " .. leg_name)
  
  self._leg_states[leg_name].current_position = position
end

--- Get current position for a leg
--
-- @param leg_name name of the leg
-- @return Vec3 position
function GaitState:get_leg_position(leg_name)
  Scalar.assert_type(leg_name, "string")
  assert(self._leg_states[leg_name], "Unknown leg name: " .. leg_name)
  
  return self._leg_states[leg_name].current_position
end

--- Set target position for a leg
--
-- @param leg_name name of the leg
-- @param position Vec3 position
function GaitState:set_leg_target(leg_name, position)
  Scalar.assert_type(leg_name, "string")
  Object.assert_type(position, Vec3)
  assert(self._leg_states[leg_name], "Unknown leg name: " .. leg_name)
  
  self._leg_states[leg_name].target_position = position
end

--- Get target position for a leg
--
-- @param leg_name name of the leg
-- @return Vec3 position
function GaitState:get_leg_target(leg_name)
  Scalar.assert_type(leg_name, "string")
  assert(self._leg_states[leg_name], "Unknown leg name: " .. leg_name)
  
  return self._leg_states[leg_name].target_position
end

--- Set lift-off position for a leg (when swing phase starts)
--
-- @param leg_name name of the leg
-- @param position Vec3 position
function GaitState:set_leg_lift_off(leg_name, position)
  Scalar.assert_type(leg_name, "string")
  Object.assert_type(position, Vec3)
  assert(self._leg_states[leg_name], "Unknown leg name: " .. leg_name)
  
  self._leg_states[leg_name].lift_off_position = position
end

--- Set touch-down position for a leg (when swing phase ends)
--
-- @param leg_name name of the leg
-- @param position Vec3 position
function GaitState:set_leg_touch_down(leg_name, position)
  Scalar.assert_type(leg_name, "string")
  Object.assert_type(position, Vec3)
  assert(self._leg_states[leg_name], "Unknown leg name: " .. leg_name)
  
  self._leg_states[leg_name].touch_down_position = position
end

--- Get all leg names
--
-- @return array of leg names
function GaitState:get_leg_names()
  return self._leg_names
end

--- Get complete state for a leg
--
-- @param leg_name name of the leg
-- @return table with all leg state information
function GaitState:get_leg_state(leg_name)
  Scalar.assert_type(leg_name, "string")
  assert(self._leg_states[leg_name], "Unknown leg name: " .. leg_name)
  
  return self._leg_states[leg_name]
end

--- Get global gait phase (0.0-1.0)
function GaitState:get_global_phase()
  return self._global_phase
end

--- Get elapsed time since gait started
function GaitState:get_elapsed_time()
  return self._elapsed_time
end

--- Get cycle time
function GaitState:get_cycle_time()
  return self._cycle_time
end

--- Set cycle time
--
-- @param cycle_time new cycle time in seconds
function GaitState:set_cycle_time(cycle_time)
  Scalar.assert_type(cycle_time, "number")
  assert(cycle_time > 0, "cycle_time must be positive")
  
  self._cycle_time = cycle_time
end

--- Check if gait is active
function GaitState:is_active()
  return self._is_active
end

return GaitState