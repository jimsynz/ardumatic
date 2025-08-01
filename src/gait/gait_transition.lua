local Object = require("object")
local Scalar = require("scalar")
local Vec3 = require("vec3")

--- Gait Transition Manager
--
-- Manages smooth transitions between different gait patterns while maintaining
-- stability and avoiding abrupt changes in leg trajectories.
local GaitTransition = Object.new("GaitTransition")

--- Transition states
local TransitionState = {
  IDLE = "idle",
  TRANSITIONING = "transitioning",
  COMPLETE = "complete"
}

--- Create a new gait transition manager
--
-- @param config optional configuration table
function GaitTransition.new(config)
  config = config or {}
  
  local default_config = {
    transition_time = 1.0,        -- seconds for transition
    phase_sync_tolerance = 0.1,   -- phase difference tolerance for sync
    stability_check = true,       -- validate stability during transition
    smooth_interpolation = true   -- use smooth interpolation between gaits
  }
  
  -- Merge with defaults
  local merged_config = {}
  for key, value in pairs(default_config) do
    if config[key] ~= nil then
      merged_config[key] = config[key]
    else
      merged_config[key] = value
    end
  end
  
  return Object.instance({
    _config = merged_config,
    _state = TransitionState.IDLE,
    _from_gait = nil,
    _to_gait = nil,
    _transition_start_time = 0.0,
    _transition_progress = 0.0,
    _sync_phase = nil
  }, GaitTransition)
end

--- Start transition from one gait pattern to another
--
-- @param from_gait current GaitPattern
-- @param to_gait target GaitPattern
-- @param current_time current time in seconds
-- @param current_phase current global phase (0.0-1.0)
-- @return true if transition started, false if not possible
function GaitTransition:start_transition(from_gait, to_gait, current_time, current_phase)
  assert(from_gait, "from_gait is required")
  assert(to_gait, "to_gait is required")
  Scalar.assert_type(current_time, "number")
  Scalar.assert_type(current_phase, "number")
  
  if self._state == TransitionState.TRANSITIONING then
    return false  -- Already transitioning
  end
  
  if from_gait:get_name() == to_gait:get_name() then
    return false  -- Same gait, no transition needed
  end
  
  -- Find optimal sync phase for transition
  local sync_phase = self:_find_sync_phase(from_gait, to_gait, current_phase)
  
  self._state = TransitionState.TRANSITIONING
  self._from_gait = from_gait
  self._to_gait = to_gait
  self._transition_start_time = current_time
  self._transition_progress = 0.0
  self._sync_phase = sync_phase
  
  return true
end

--- Update transition state
--
-- @param current_time current time in seconds
-- @return transition_progress (0.0-1.0), is_complete (boolean)
function GaitTransition:update(current_time)
  Scalar.assert_type(current_time, "number")
  
  if self._state ~= TransitionState.TRANSITIONING then
    return 1.0, true
  end
  
  local elapsed = current_time - self._transition_start_time
  self._transition_progress = math.min(elapsed / self._config.transition_time, 1.0)
  
  if self._transition_progress >= 1.0 then
    self._state = TransitionState.COMPLETE
    return 1.0, true
  end
  
  return self._transition_progress, false
end

--- Calculate blended leg phase during transition
--
-- @param leg_name name of the leg
-- @param global_phase current global phase (0.0-1.0)
-- @return leg_phase (0.0-1.0), is_stance (boolean)
function GaitTransition:calculate_transition_phase(leg_name, global_phase)
  Scalar.assert_type(leg_name, "string")
  Scalar.assert_type(global_phase, "number")
  
  if self._state ~= TransitionState.TRANSITIONING then
    error("Not currently transitioning")
  end
  
  -- Get phases from both gaits
  local from_phase, from_stance = self._from_gait:calculate_leg_phase(leg_name, global_phase)
  local to_phase, to_stance = self._to_gait:calculate_leg_phase(leg_name, global_phase)
  
  if self._config.smooth_interpolation then
    -- Smooth interpolation between gait patterns
    local blend_factor = self:_smooth_step(self._transition_progress)
    
    -- Interpolate phases
    local blended_phase = self:_interpolate_phase(from_phase, to_phase, blend_factor)
    
    -- Ensure phase is in valid range
    blended_phase = math.max(0.0, math.min(1.0, blended_phase))
    
    -- Determine stance based on blended phase and target gait duty factor
    local target_duty = self._to_gait:get_duty_factor()
    local blended_stance = blended_phase <= target_duty
    
    return blended_phase, blended_stance
  else
    -- Simple switching at sync phase
    if global_phase >= self._sync_phase then
      return to_phase, to_stance
    else
      return from_phase, from_stance
    end
  end
end

--- Check if transition is safe at current state
--
-- @param leg_positions table of Vec3 positions keyed by leg name
-- @param stance_legs array of leg names currently in stance
-- @param stability_analyzer StabilityAnalyzer instance (optional)
-- @return true if transition is safe
function GaitTransition:is_transition_safe(leg_positions, stance_legs, stability_analyzer)
  assert(type(leg_positions) == "table", "leg_positions must be a table")
  assert(type(stance_legs) == "table", "stance_legs must be an array")
  
  if not self._config.stability_check then
    return true  -- Skip stability check if disabled
  end
  
  if not stability_analyzer then
    -- Basic check: ensure minimum stance legs
    return #stance_legs >= 3
  end
  
  -- Full stability analysis
  local is_stable, margin, _ = stability_analyzer:validate_stability(leg_positions, stance_legs)
  return is_stable and margin > 10  -- Require some safety margin
end

--- Get recommended transition timing
--
-- @param from_gait current GaitPattern
-- @param to_gait target GaitPattern
-- @param current_velocity current robot velocity in mm/s
-- @return recommended transition time in seconds
function GaitTransition:get_recommended_timing(from_gait, to_gait, current_velocity)
  assert(from_gait, "from_gait is required")
  assert(to_gait, "target_gait is required")
  Scalar.assert_type(current_velocity, "number", true)
  
  current_velocity = current_velocity or 0
  
  -- Base transition time
  local base_time = self._config.transition_time
  
  -- Adjust based on gait complexity difference
  local from_duty = from_gait:get_duty_factor()
  local to_duty = to_gait:get_duty_factor()
  local duty_diff = math.abs(to_duty - from_duty)
  
  -- More complex transitions need more time
  local complexity_factor = 1.0 + duty_diff
  
  -- Higher velocities need more careful transitions
  local velocity_factor = 1.0 + (current_velocity / 200.0) * 0.5
  
  return base_time * complexity_factor * velocity_factor
end

--- Complete current transition
function GaitTransition:complete_transition()
  self._state = TransitionState.IDLE
  self._from_gait = nil
  self._to_gait = nil
  self._transition_progress = 0.0
  self._sync_phase = nil
end

--- Check if currently transitioning
--
-- @return true if transition is in progress
function GaitTransition:is_transitioning()
  return self._state == TransitionState.TRANSITIONING
end

--- Get current transition progress
--
-- @return progress (0.0-1.0)
function GaitTransition:get_progress()
  return self._transition_progress
end

--- Get target gait pattern
--
-- @return target GaitPattern or nil if not transitioning
function GaitTransition:get_target_gait()
  return self._to_gait
end

--- Find optimal phase to synchronize gait transition
--
-- @param from_gait current GaitPattern
-- @param to_gait target GaitPattern
-- @param current_phase current global phase
-- @return optimal sync phase (0.0-1.0)
function GaitTransition:_find_sync_phase(from_gait, to_gait, current_phase)
  -- Look for phase where both gaits have similar leg states
  local best_phase = current_phase
  local best_score = -math.huge
  
  -- Sample phases around current phase
  for offset = 0, 1, 0.05 do
    local test_phase = (current_phase + offset) % 1.0
    local score = self:_calculate_sync_score(from_gait, to_gait, test_phase)
    
    if score > best_score then
      best_score = score
      best_phase = test_phase
    end
  end
  
  return best_phase
end

--- Calculate how well two gaits synchronize at a given phase
--
-- @param from_gait current GaitPattern
-- @param to_gait target GaitPattern
-- @param phase test phase
-- @return synchronization score (higher is better)
function GaitTransition:_calculate_sync_score(from_gait, to_gait, phase)
  -- Dummy leg names for scoring (would use actual leg names in practice)
  local test_legs = {"front_right", "front_left", "rear_right", "rear_left"}
  
  local score = 0
  for _, leg_name in ipairs(test_legs) do
    local from_phase, from_stance = from_gait:calculate_leg_phase(leg_name, phase)
    local to_phase, to_stance = to_gait:calculate_leg_phase(leg_name, phase)
    
    -- Prefer phases where stance states match
    if from_stance == to_stance then
      score = score + 1
    end
    
    -- Prefer phases where leg phases are similar
    local phase_diff = math.abs(from_phase - to_phase)
    phase_diff = math.min(phase_diff, 1.0 - phase_diff)  -- Handle wrap-around
    score = score + (1.0 - phase_diff)
  end
  
  return score
end

--- Smooth step function for interpolation
--
-- @param t input value (0.0-1.0)
-- @return smoothed value (0.0-1.0)
function GaitTransition:_smooth_step(t)
  -- Hermite interpolation: 3t² - 2t³
  return t * t * (3 - 2 * t)
end

--- Interpolate between two phase values handling wrap-around
--
-- @param from_phase starting phase (0.0-1.0)
-- @param to_phase ending phase (0.0-1.0)
-- @param t interpolation factor (0.0-1.0)
-- @return interpolated phase (0.0-1.0)
function GaitTransition:_interpolate_phase(from_phase, to_phase, t)
  -- For phase interpolation, we want the shortest path around the unit circle
  local direct_diff = to_phase - from_phase
  local wrap_forward_diff = direct_diff - 1.0  -- Going backwards through 0
  local wrap_backward_diff = direct_diff + 1.0  -- Going forwards through 1
  
  -- Choose the shortest path
  local diff = direct_diff
  if math.abs(wrap_forward_diff) < math.abs(diff) then
    diff = wrap_forward_diff
  end
  if math.abs(wrap_backward_diff) < math.abs(diff) then
    diff = wrap_backward_diff
  end
  
  local result = from_phase + diff * t
  
  -- Normalize to 0.0-1.0 range
  if result < 0 then
    result = result + 1.0
  elseif result >= 1.0 then
    result = result - 1.0
  end
  
  return result
end

--- Set configuration parameter
--
-- @param key parameter name
-- @param value parameter value
function GaitTransition:set_config(key, value)
  Scalar.assert_type(key, "string")
  
  if self._config[key] ~= nil then
    self._config[key] = value
  else
    error("Unknown configuration parameter: " .. key)
  end
end

--- Get configuration parameter
--
-- @param key parameter name
-- @return parameter value
function GaitTransition:get_config(key)
  Scalar.assert_type(key, "string")
  return self._config[key]
end

GaitTransition.TransitionState = TransitionState

return GaitTransition