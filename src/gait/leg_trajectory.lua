local Object = require("object")
local Scalar = require("scalar")
local Vec3 = require("vec3")

--- Leg Trajectory Generator
--
-- Generates smooth trajectories for individual legs during swing and stance phases
-- using cubic spline interpolation for natural movement.
local LegTrajectory = Object.new("LegTrajectory")

--- Create a new leg trajectory generator
--
-- @param step_height maximum height of leg lift during swing phase (mm)
-- @param ground_clearance minimum clearance above ground during swing (mm)
function LegTrajectory.new(step_height, ground_clearance)
  Scalar.assert_type(step_height, "number", true)
  Scalar.assert_type(ground_clearance, "number", true)
  
  step_height = step_height or 30.0
  ground_clearance = ground_clearance or 5.0
  
  assert(step_height > 0, "step_height must be positive")
  assert(ground_clearance >= 0, "ground_clearance must be non-negative")
  
  return Object.instance({
    _step_height = step_height,
    _ground_clearance = ground_clearance
  }, LegTrajectory)
end

--- Generate stance phase trajectory
--
-- During stance phase, the leg moves linearly from start to end position
-- while maintaining ground contact.
--
-- @param start_pos Vec3 starting position
-- @param end_pos Vec3 ending position
-- @param phase phase within stance (0.0-1.0)
-- @return Vec3 interpolated position
function LegTrajectory:stance_trajectory(start_pos, end_pos, phase)
  Object.assert_type(start_pos, Vec3)
  Object.assert_type(end_pos, Vec3)
  Scalar.assert_type(phase, "number")
  assert(phase >= 0.0 and phase <= 1.0, "phase must be between 0.0 and 1.0")
  
  -- Linear interpolation for stance phase
  return start_pos + ((end_pos - start_pos) * phase)
end

--- Generate swing phase trajectory
--
-- During swing phase, the leg follows a smooth arc from lift-off to touch-down
-- position using cubic spline interpolation for natural movement.
--
-- @param lift_off_pos Vec3 position where leg lifts off
-- @param touch_down_pos Vec3 position where leg touches down
-- @param phase phase within swing (0.0-1.0)
-- @param ground_height height of ground at current position (optional)
-- @return Vec3 interpolated position
function LegTrajectory:swing_trajectory(lift_off_pos, touch_down_pos, phase, ground_height)
  Object.assert_type(lift_off_pos, Vec3)
  Object.assert_type(touch_down_pos, Vec3)
  Scalar.assert_type(phase, "number")
  Scalar.assert_type(ground_height, "number", true)
  assert(phase >= 0.0 and phase <= 1.0, "phase must be between 0.0 and 1.0")
  
  ground_height = ground_height or 0.0
  
  -- Horizontal interpolation (linear)
  local horizontal_pos = lift_off_pos + ((touch_down_pos - lift_off_pos) * phase)
  
  -- Vertical trajectory using cubic spline for smooth arc
  local lift_height = lift_off_pos:z()
  local land_height = touch_down_pos:z()
  local max_height = math.max(lift_height, land_height) + self._step_height
  
  -- Ensure minimum ground clearance
  local min_safe_height = ground_height + self._ground_clearance
  max_height = math.max(max_height, min_safe_height)
  
  -- Cubic spline parameters for smooth arc
  -- f(t) = at³ + bt² + ct + d where t = phase
  local start_height = lift_height
  local end_height = land_height
  local mid_height = max_height
  
  local vertical_pos
  if phase <= 0.5 then
    -- First half: lift-off to peak
    local t = phase * 2.0  -- Scale to 0-1 for first half
    vertical_pos = self:_cubic_interpolate(start_height, mid_height, t, 0.0, 0.0)
  else
    -- Second half: peak to touch-down
    local t = (phase - 0.5) * 2.0  -- Scale to 0-1 for second half
    vertical_pos = self:_cubic_interpolate(mid_height, end_height, t, 0.0, 0.0)
  end
  
  return Vec3.new(horizontal_pos:x(), horizontal_pos:y(), vertical_pos)
end

--- Generate collision-aware trajectory
--
-- Modifies swing trajectory to avoid collisions with robot body or obstacles.
--
-- @param lift_off_pos Vec3 position where leg lifts off
-- @param touch_down_pos Vec3 position where leg touches down
-- @param phase phase within swing (0.0-1.0)
-- @param body_bounds table with body collision bounds (optional)
-- @param ground_height height of ground at current position (optional)
-- @param step_height override step height for this trajectory (optional)
-- @return Vec3 collision-free position
function LegTrajectory:collision_aware_trajectory(lift_off_pos, touch_down_pos, phase, body_bounds, ground_height, step_height)
  Object.assert_type(lift_off_pos, Vec3)
  Object.assert_type(touch_down_pos, Vec3)
  Scalar.assert_type(phase, "number")
  assert(phase >= 0.0 and phase <= 1.0, "phase must be between 0.0 and 1.0")
  
  -- Start with basic swing trajectory, using adaptive step height if provided
  local original_step_height = self._step_height
  if step_height then
    self._step_height = step_height
  end
  
  local base_pos = self:swing_trajectory(lift_off_pos, touch_down_pos, phase, ground_height)
  
  -- Restore original step height
  if step_height then
    self._step_height = original_step_height
  end
  
  -- If no body bounds provided, return basic trajectory
  if not body_bounds then
    return base_pos
  end
  
  -- Check for collision with body bounds
  local collision_clearance = body_bounds.clearance or 20.0  -- mm
  local body_center = body_bounds.center or Vec3.zero()
  local body_radius = body_bounds.radius or 100.0  -- mm
  
  -- Calculate distance from body center
  local horizontal_distance = Vec3.new(base_pos:x(), base_pos:y(), 0):distance(
    Vec3.new(body_center:x(), body_center:y(), 0)
  )
  
  -- If too close to body, increase height
  if horizontal_distance < (body_radius + collision_clearance) then
    local additional_height = (body_radius + collision_clearance - horizontal_distance) * 0.5
    base_pos = Vec3.new(base_pos:x(), base_pos:y(), base_pos:z() + additional_height)
  end
  
  return base_pos
end

--- Cubic interpolation between two points with specified derivatives
--
-- @param start_val starting value
-- @param end_val ending value
-- @param t interpolation parameter (0.0-1.0)
-- @param start_deriv derivative at start (default 0)
-- @param end_deriv derivative at end (default 0)
-- @return interpolated value
function LegTrajectory:_cubic_interpolate(start_val, end_val, t, start_deriv, end_deriv)
  start_deriv = start_deriv or 0.0
  end_deriv = end_deriv or 0.0
  
  local t2 = t * t
  local t3 = t2 * t
  
  -- Cubic Hermite spline coefficients
  local h00 = 2*t3 - 3*t2 + 1
  local h10 = t3 - 2*t2 + t
  local h01 = -2*t3 + 3*t2
  local h11 = t3 - t2
  
  return h00 * start_val + h10 * start_deriv + h01 * end_val + h11 * end_deriv
end

--- Calculate trajectory velocity at given phase
--
-- @param lift_off_pos Vec3 position where leg lifts off
-- @param touch_down_pos Vec3 position where leg touches down
-- @param phase phase within swing (0.0-1.0)
-- @param dt small time delta for numerical differentiation
-- @return Vec3 velocity vector
function LegTrajectory:get_trajectory_velocity(lift_off_pos, touch_down_pos, phase, dt)
  Object.assert_type(lift_off_pos, Vec3)
  Object.assert_type(touch_down_pos, Vec3)
  Scalar.assert_type(phase, "number")
  Scalar.assert_type(dt, "number", true)
  
  dt = dt or 0.001
  
  -- Numerical differentiation
  local current_pos = self:swing_trajectory(lift_off_pos, touch_down_pos, phase)
  local next_phase = math.min(phase + dt, 1.0)
  local next_pos = self:swing_trajectory(lift_off_pos, touch_down_pos, next_phase)
  
  return (next_pos - current_pos) * (1.0 / dt)
end

--- Set step height
--
-- @param height new step height in mm
function LegTrajectory:set_step_height(height)
  Scalar.assert_type(height, "number")
  assert(height > 0, "step_height must be positive")
  
  self._step_height = height
end

--- Get step height
--
-- @return step height in mm
function LegTrajectory:get_step_height()
  return self._step_height
end

--- Set ground clearance
--
-- @param clearance new ground clearance in mm
function LegTrajectory:set_ground_clearance(clearance)
  Scalar.assert_type(clearance, "number")
  assert(clearance >= 0, "ground_clearance must be non-negative")
  
  self._ground_clearance = clearance
end

--- Get ground clearance
--
-- @return ground clearance in mm
function LegTrajectory:get_ground_clearance()
  return self._ground_clearance
end

return LegTrajectory