local Angle = require("angle")
local Chain = require("chain")
local Joint = require("joint")
local Object = require("object")
local Mat3 = require("mat3")
local Vec3 = require("vec3")

local FABRIK = Object.new("FABRIK")

--- The default configuration
--
-- @field tolerance how close should the end effector be to the target before we
-- consider the chain "solved enough".
--
-- @field max_interations the maximum number of iterations through the solving
-- algorithm before giving up.
--
-- @field min_travel the minimum amount that each successive solve should move
-- towards the target location before giving up.
FABRIK.DEFAULT_CONFIGURATION = {
  tolerance = 0.01,
  max_interations = 20,
  min_travel = 0.001,               -- Tighter min_travel for better convergence
  enforce_constraints = true,        -- Enable/disable constraint enforcement
  constraint_tolerance = 0.0001     -- Tighter constraint tolerance
}

-- performs a simple reverse-merge preferring the passed in configuration to the
-- defaults, if present.
local merge_defaults = function(config)
  config = config or {}
  for key, value in pairs(FABRIK.DEFAULT_CONFIGURATION) do
    if config[key] == nil then
      config[key] = value
    end
  end

  return config
end

--- Apply joint constraints to a target direction
--
-- Takes a joint and a desired target direction, and returns a direction that
-- respects the joint's constraints. For ball joints, this applies cone
-- constraints around the reference axis. For hinge joints, this applies
-- rotational limits around the rotation axis.
--
-- @param joint the Joint to apply constraints to
-- @param target_direction the desired direction (Vec3, should be normalised)
-- @return the constrained direction (Vec3, normalised)
local rotate_joint_with_constraints = function(joint, target_direction)
  Object.assert_type(joint, Joint)
  Object.assert_type(target_direction, Vec3)
  
  local reference_axis = joint:reference_axis()
  
  if joint:is_ball() then
    local constraint = joint:clockwise_constraint()
    local new_direction = reference_axis:constrained_rotation_towards(target_direction, constraint)
    return new_direction
    
  elseif joint:is_hinge() then
    local rotation_axis = joint:rotation_axis()
    local clockwise_constraint = joint:clockwise_constraint()
    local anticlockwise_constraint = joint:anticlockwise_constraint()
    
    -- Project the target direction onto the plane perpendicular to the rotation axis
    local projected_direction = target_direction:project_on_plane(rotation_axis)
    
    -- Calculate the angle between the reference axis and the projected direction
    local angle_to_target = reference_axis:angle_to(projected_direction)
    
    -- Determine if we're rotating clockwise or anticlockwise
    -- Use the cross product to determine rotation direction
    local cross = reference_axis:cross(projected_direction)
    local is_clockwise = cross:dot(rotation_axis) < 0
    
    local constraint = is_clockwise and clockwise_constraint or anticlockwise_constraint
    
    -- Apply the constraint
    if angle_to_target <= constraint then
      -- Target is within constraints, use projected direction
      return projected_direction
    else
      -- Target exceeds constraints, rotate to the constraint limit
      local constrained_angle = is_clockwise and constraint or (Angle.zero() - constraint)
      return reference_axis:rotate_about_axis(rotation_axis, constrained_angle)
    end
    
  else
    -- Unknown joint type, return target direction unchanged
    return target_direction
  end
end

-- recursively traverse the chain backwards and update the directions and
-- tip_locations according to the solve.
local solve_backwards = function(chain, target, config)
  local constraints_applied = false
  
  for link_state in chain:backwards() do
    -- calculate the direction from the target towards the inboard link.
    local tip_to_root_direction = target:direction(link_state.root_location)

    if config.enforce_constraints then
      -- the joint direction is the inverse of the tip_to_root_direction because
      -- the joint is at the link root.
      local desired_joint_direction = tip_to_root_direction:invert()
      local constrained_joint_direction = rotate_joint_with_constraints(link_state.joint, desired_joint_direction)
      
      -- Check if constraints were actually applied
      local direction_diff = constrained_joint_direction - desired_joint_direction
      if direction_diff:length() > 0.0001 then
        constraints_applied = true
      end
      
      -- calculate the new root location based on the constrained joint direction
      local root_direction = constrained_joint_direction:invert()
      local new_root_location = target + (root_direction * link_state.length)

      -- update this joint's direction and end location.
      link_state.joint:direction(constrained_joint_direction)
      link_state.tip_location = target
      link_state.root_location = new_root_location
      target = new_root_location
    else
      -- Original algorithm (unconstrained)
      local link_reverse_vector = tip_to_root_direction * link_state.length
      local new_root_location = target + link_reverse_vector
      local joint_direction = tip_to_root_direction:invert()
      link_state.joint:direction(joint_direction)
      link_state.tip_location = target
      link_state.root_location = new_root_location
      target = new_root_location
    end
  end
  
  return constraints_applied
end

local solve_forwards = function(chain, start_location, config)
  for link_state in chain:forwards() do
    if config.enforce_constraints then
      -- calculate the direction from the new start location towards the end location.
      local desired_direction = start_location:direction(link_state.tip_location)
      local constrained_direction = rotate_joint_with_constraints(link_state.joint, desired_direction)

      -- calculate the new tip position based on the constrained direction.
      local constrained_link_vector = constrained_direction * link_state.length
      local new_tip_location = start_location + constrained_link_vector

      -- update the joint's direction and the new tip location.
      link_state.joint:direction(constrained_direction)
      link_state.root_location = start_location
      link_state.tip_location = new_tip_location

      start_location = new_tip_location
    else
      -- Original algorithm (unconstrained)
      local root_to_tip_direction = start_location:direction(link_state.tip_location)
      local link_vector = root_to_tip_direction * link_state.length
      local new_tip_location = start_location + link_vector
      link_state.joint:direction(root_to_tip_direction)
      link_state.root_location = start_location
      link_state.tip_location = new_tip_location
      start_location = new_tip_location
    end
  end
end

--- Attempt to solve the chain to the new target location.
--
-- Here we apply the FABRIK algorithm in an attempt to solve the chain for a new
-- goal position.
--
-- The FABRIK algorithm is used here because it is:
--   1. Simple (it deals only in vector maths),
--   2. Fast (see 1),
--   3. Tunable (you can trade off computational expense for accuracy).
--
-- What you need to know about FABRIK:
--
-- Like Zeno's Paradox, FABRIK never actually achieves the goal position, but
-- will work it's way closer and closer the more iterations you give it.
--
-- Thus, the decision when using FABRIK is when to consider the system "solved
-- enough".  Here we use a combination of limits to decide when to stop
-- computation.  The defaults are chosen only to ease development and debugging.
-- You should tune these parameters to match the dynamics of the system.
--
-- Tunable configuration parameters:
--   1. tolerance (defaults to 0.01) - how close to get to the goal before we
--      consider it solved.
--   2. max_interations (defaults to 20) - how many times to iterate before
--      giving up if we never achieve a position within tolerance.
--   3. min_travel (defaults to 0.01) - stop iterating early if the distance
--      moved between iterations drops below this level.
--
-- Special cases:
--
-- There are some instances where we will stop early without iterating.
--
--   1. If the goal position is outside the maximum reach of the chain then we
--      attempt to configure the chain along a single vector poining towards the
--      target location.
--   2. If the goal position is within tolerance of the end effector when we
--      start, then we immediately stop.
--
-- Current limitations:
--
-- Ardumatic is still in heavy development, so for now the current limitations
-- are in place.
--
--   1. Currently the algoritm is ignoring joint constraints, so will likely
--      provide solutions which are not physically possible for your system.
--   2. There is no collision detection or keep-out areas.
--
-- @param chain the Chain to mutate.  @param target a Vec3 of the goal location.
-- @param config a table of configuration overrised (@see
-- FABRIK.DEFAULT_CONFIGURATION) @return the number of iterations used.
function FABRIK.solve(chain, target, config)
  Object.assert_type(chain, Chain)
  Object.assert_type(target, Vec3)
  config = merge_defaults(config)

  local start_location = chain:origin()
  -- local current_state = chain:chain_state(chain)

  -- Check if target is out of reach
  -- Skip this optimization if constraints are enabled and joints have meaningful constraints
  local has_meaningful_constraints = false
  if config.enforce_constraints then
    for link_state in chain:forwards() do
      local joint = link_state.joint
      if joint:is_ball() then
        local constraint_angle = joint:clockwise_constraint()
        -- Consider constraints meaningful if they're less than 120 degrees
        if constraint_angle and constraint_angle:degrees() < 120 then
          has_meaningful_constraints = true
          break
        end
      elseif joint:is_hinge() then
        -- Hinge joints always have meaningful constraints
        has_meaningful_constraints = true
        break
      end
    end
  end
  
  if not has_meaningful_constraints and start_location:distance(target) > chain:reach() then
    local direction = start_location:direction(target)

    for link_state in chain:forwards() do
      link_state.root_location = start_location
      link_state.tip_location = start_location + (direction * link_state.length)
      link_state.joint:direction(direction)
      start_location = link_state.tip_location
    end

    return 0
  end

  local link_count = chain:length()
  local end_location = chain:end_location()
  local current_delta = target:distance(end_location)

  -- if we're already close enough to the target then we're g2g.
  if current_delta < config.tolerance then
    return 0
  end

  local last_delta = 0.0
  local count = 0
  local delta_change = 0

  repeat
    count = count + 1

    local constraints_applied = solve_backwards(chain, target, config)
    
    -- Always use the original start location for backward compatibility
    -- The original FABRIK algorithm doesn't use the updated start location
    solve_forwards(chain, start_location, config)

    last_delta = current_delta
    end_location = chain:end_location()
    current_delta = target:distance(end_location)
    delta_change = math.abs(current_delta - last_delta)

  until (current_delta < config.tolerance)
    or (delta_change < config.min_travel)
    or (count == config.max_interations)
    or (config.enforce_constraints and delta_change < config.constraint_tolerance)

  return count
end

--- Check if a direction violates joint constraints
--
-- @param joint the Joint to check against
-- @param direction the direction to validate (Vec3, should be normalised)
-- @return true if direction is within constraints, false otherwise
function FABRIK.is_direction_valid(joint, direction)
  Object.assert_type(joint, Joint)
  Object.assert_type(direction, Vec3)
  
  local reference_axis = joint:reference_axis()
  
  if joint:is_ball() then
    local constraint = joint:clockwise_constraint()
    local angle_to_direction = reference_axis:angle_to(direction)
    return angle_to_direction <= constraint
    
  elseif joint:is_hinge() then
    local rotation_axis = joint:rotation_axis()
    local clockwise_constraint = joint:clockwise_constraint()
    local anticlockwise_constraint = joint:anticlockwise_constraint()
    
    -- Project direction onto the rotation plane
    local projected_direction = direction:project_on_plane(rotation_axis)
    local angle_to_direction = reference_axis:angle_to(projected_direction)
    
    -- Determine rotation direction
    local cross = reference_axis:cross(projected_direction)
    local is_clockwise = cross:dot(rotation_axis) < 0
    
    local constraint = is_clockwise and clockwise_constraint or anticlockwise_constraint
    return angle_to_direction <= constraint
    
  else
    -- Unknown joint type, assume valid
    return true
  end
end

--- Calculate the magnitude of constraint violation
--
-- @param joint the Joint to check against
-- @param direction the direction to check (Vec3, should be normalised)
-- @return the violation angle (Angle), zero if within constraints
function FABRIK.get_constraint_violation(joint, direction)
  Object.assert_type(joint, Joint)
  Object.assert_type(direction, Vec3)
  
  local reference_axis = joint:reference_axis()
  
  if joint:is_ball() then
    local constraint = joint:clockwise_constraint()
    local angle_to_direction = reference_axis:angle_to(direction)
    if angle_to_direction > constraint then
      return angle_to_direction - constraint
    else
      return Angle.zero()
    end
    
  elseif joint:is_hinge() then
    local rotation_axis = joint:rotation_axis()
    local clockwise_constraint = joint:clockwise_constraint()
    local anticlockwise_constraint = joint:anticlockwise_constraint()
    
    -- Project direction onto the rotation plane
    local projected_direction = direction:project_on_plane(rotation_axis)
    local angle_to_direction = reference_axis:angle_to(projected_direction)
    
    -- Determine rotation direction
    local cross = reference_axis:cross(projected_direction)
    local is_clockwise = cross:dot(rotation_axis) < 0
    
    local constraint = is_clockwise and clockwise_constraint or anticlockwise_constraint
    if angle_to_direction > constraint then
      return angle_to_direction - constraint
    else
      return Angle.zero()
    end
    
  else
    -- Unknown joint type, no violation
    return Angle.zero()
  end
end

--- Find the closest valid direction within joint constraints
--
-- This is an alias for apply_joint_constraints with a more descriptive name
-- @param joint the Joint to apply constraints to
-- @param target_direction the desired direction (Vec3, should be normalised)
-- @return the closest valid direction (Vec3, normalised)
function FABRIK.find_closest_valid_direction(joint, target_direction)
  return rotate_joint_with_constraints(joint, target_direction)
end

--- Apply joint constraints to a target direction (exposed for testing)
--
-- @param joint the Joint to apply constraints to
-- @param target_direction the desired direction (Vec3, should be normalised)
-- @return the constrained direction (Vec3, normalised)
function FABRIK.apply_joint_constraints(joint, target_direction)
  return rotate_joint_with_constraints(joint, target_direction)
end

return FABRIK
