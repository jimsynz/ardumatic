local Object = require("object")
local Scalar = require("scalar")
local Vec3 = require("vec3")

--- Abstract Gait Pattern Base Class
--
-- Defines the interface that all gait patterns must implement.
-- Provides common functionality for phase calculation and leg coordination.
local GaitPattern = Object.new("GaitPattern")

--- Create a new gait pattern
--
-- @param name string name of the gait pattern
-- @param duty_factor fraction of cycle spent in stance (0.0-1.0)
function GaitPattern.new(name, duty_factor)
  Scalar.assert_type(name, "string")
  Scalar.assert_type(duty_factor, "number", true)
  
  duty_factor = duty_factor or 0.5
  assert(duty_factor > 0.0 and duty_factor < 1.0, "duty_factor must be between 0.0 and 1.0")
  
  return Object.instance({
    _name = name,
    _duty_factor = duty_factor,
    _leg_phase_offsets = {}
  }, GaitPattern)
end

--- Calculate leg phase and stance state for given global phase
--
-- Default implementation that uses the leg phase offsets.
-- Specific gait patterns can override this if needed.
--
-- @param leg_name name of the leg
-- @param global_phase current global gait phase (0.0-1.0)
-- @return leg_phase (0.0-1.0), is_stance (boolean)
function GaitPattern:calculate_leg_phase(leg_name, global_phase)
  Scalar.assert_type(leg_name, "string")
  Scalar.assert_type(global_phase, "number")
  
  local offset = self:get_leg_phase_offset(leg_name)
  local leg_phase = self:normalize_phase(global_phase + offset)
  local is_stance = self:is_stance_phase(leg_phase)
  
  return leg_phase, is_stance
end

--- Get the phase offset for a specific leg
--
-- @param leg_name name of the leg
-- @return phase offset (0.0-1.0)
function GaitPattern:get_leg_phase_offset(leg_name)
  Scalar.assert_type(leg_name, "string")
  return self._leg_phase_offsets[leg_name] or 0.0
end

--- Set the phase offset for a specific leg
--
-- @param leg_name name of the leg
-- @param offset phase offset (0.0-1.0)
function GaitPattern:set_leg_phase_offset(leg_name, offset)
  Scalar.assert_type(leg_name, "string")
  Scalar.assert_type(offset, "number")
  assert(offset >= 0.0 and offset <= 1.0, "offset must be between 0.0 and 1.0")
  
  self._leg_phase_offsets[leg_name] = offset
end

--- Calculate stance phase for a leg
--
-- @param leg_phase current leg phase (0.0-1.0)
-- @return stance_phase (0.0-1.0) or nil if in swing
function GaitPattern:get_stance_phase(leg_phase)
  Scalar.assert_type(leg_phase, "number")
  
  if leg_phase <= self._duty_factor then
    return leg_phase / self._duty_factor
  else
    return nil  -- In swing phase
  end
end

--- Calculate swing phase for a leg
--
-- @param leg_phase current leg phase (0.0-1.0)
-- @return swing_phase (0.0-1.0) or nil if in stance
function GaitPattern:get_swing_phase(leg_phase)
  Scalar.assert_type(leg_phase, "number")
  
  if leg_phase > self._duty_factor then
    return (leg_phase - self._duty_factor) / (1.0 - self._duty_factor)
  else
    return nil  -- In stance phase
  end
end

--- Check if leg is in stance phase
--
-- @param leg_phase current leg phase (0.0-1.0)
-- @return true if in stance phase
function GaitPattern:is_stance_phase(leg_phase)
  Scalar.assert_type(leg_phase, "number")
  -- Handle boundary condition: phase exactly at duty_factor should be start of swing
  return leg_phase < self._duty_factor
end

--- Get all legs that should be in stance at given global phase
--
-- @param global_phase current global gait phase (0.0-1.0)
-- @param leg_names array of all leg names
-- @return array of leg names in stance
function GaitPattern:get_stance_legs(global_phase, leg_names)
  Scalar.assert_type(global_phase, "number")
  assert(type(leg_names) == "table", "leg_names must be an array")
  
  local stance_legs = {}
  for _, leg_name in ipairs(leg_names) do
    local leg_phase, is_stance = self:calculate_leg_phase(leg_name, global_phase)
    if is_stance then
      table.insert(stance_legs, leg_name)
    end
  end
  
  return stance_legs
end

--- Get all legs that should be in swing at given global phase
--
-- @param global_phase current global gait phase (0.0-1.0)
-- @param leg_names array of all leg names
-- @return array of leg names in swing
function GaitPattern:get_swing_legs(global_phase, leg_names)
  Scalar.assert_type(global_phase, "number")
  assert(type(leg_names) == "table", "leg_names must be an array")
  
  local swing_legs = {}
  for _, leg_name in ipairs(leg_names) do
    local leg_phase, is_stance = self:calculate_leg_phase(leg_name, global_phase)
    if not is_stance then
      table.insert(swing_legs, leg_name)
    end
  end
  
  return swing_legs
end

--- Validate gait stability at given phase
--
-- Checks that sufficient legs are in stance phase for stability.
-- For static stability, at least 3 legs should be in stance.
--
-- @param global_phase current global gait phase (0.0-1.0)
-- @param leg_names array of all leg names
-- @param min_stance_legs minimum legs required in stance (default 3)
-- @return true if stable, false otherwise
function GaitPattern:is_stable(global_phase, leg_names, min_stance_legs)
  Scalar.assert_type(global_phase, "number")
  assert(type(leg_names) == "table", "leg_names must be an array")
  Scalar.assert_type(min_stance_legs, "number", true)
  
  min_stance_legs = min_stance_legs or 3
  
  local stance_legs = self:get_stance_legs(global_phase, leg_names)
  return #stance_legs >= min_stance_legs
end

--- Get gait pattern name
function GaitPattern:get_name()
  return self._name
end

--- Get duty factor (fraction of cycle in stance)
function GaitPattern:get_duty_factor()
  return self._duty_factor
end

--- Set duty factor
--
-- @param duty_factor new duty factor (0.0-1.0)
function GaitPattern:set_duty_factor(duty_factor)
  Scalar.assert_type(duty_factor, "number")
  assert(duty_factor > 0.0 and duty_factor < 1.0, "duty_factor must be between 0.0 and 1.0")
  
  self._duty_factor = duty_factor
end

--- Get maximum number of legs that can be in swing simultaneously
--
-- @param leg_count total number of legs
-- @return maximum swing legs for stability
function GaitPattern:get_max_swing_legs(leg_count)
  Scalar.assert_type(leg_count, "number")
  
  -- For static stability, keep at least 3 legs in stance
  local min_stance = math.min(3, leg_count - 1)
  return leg_count - min_stance
end

--- Normalize phase to 0.0-1.0 range
--
-- @param phase input phase (any value)
-- @return normalized phase (0.0-1.0)
function GaitPattern:normalize_phase(phase)
  Scalar.assert_type(phase, "number")
  return phase - math.floor(phase)
end

return GaitPattern