local Chain = require("chain")
local Object = require("object")
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
  min_travel = 0.01
}

-- performs a simple reverse-merge preferring the passed in configuration to the
-- defaults, if present.
local merge_defaults = function(config)
  config = config or {}
  for key, value in pairs(FABRIK.DEFAULT_CONFIGURATION) do
    config[key] = config[key] or value
  end

  return config
end

-- recursively traverse the chain backwards and update the directions and
-- end_locations according to the solve.
local solve_backwards
solve_backwards = function(index, current_state, target)
  local link_state = current_state[index]

  -- the inboard location is the end location of the inboard link, or zero.
  local inboard_location
  if index > 1 then
    inboard_location = current_state[index - 1].end_location
  else
    inboard_location = Vec3.zero()
  end

  -- calculate the direction from the target towards the inboard link.
  local outer_to_inner_direction = target:direction(inboard_location)

  -- calculate the new end position of the inboard link.
  local link_reverse_vector = outer_to_inner_direction * link_state.length
  local new_inboard_location = target + link_reverse_vector

  -- update this joint's direction and end location.
  -- the direction is set to the inverse of the outer_to_inner_direction because
  -- the joint is at the link root.
  local joint_direction = outer_to_inner_direction:invert()
  link_state.joint:direction(joint_direction)
  link_state.end_location = target

  if index == 1 then
    -- we've finished
    return current_state
  else
    -- once more into the breach
    return solve_backwards(index - 1, current_state, new_inboard_location)
  end
end

local solve_forwards
solve_forwards = function(index, current_state, start_location, link_count)
  local link_state = current_state[index]

  -- calculate the direction from the new start location towards the end location.
  local inner_to_outer_direction = start_location:direction(link_state.end_location)

  -- calculate the new end position of this link.
  local link_vector = inner_to_outer_direction * link_state.length
  local new_end_location = start_location + link_vector

  -- update the joint's direction and the new end location.
  link_state.joint:direction(inner_to_outer_direction)
  link_state.end_location = new_end_location

  if index == link_count then
    return current_state
  else
    return solve_forwards(index + 1, current_state, new_end_location, link_count)
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
  local current_state = chain:chain_state(chain)

  --
  if start_location:distance(target) > chain:reach() then
    local direction = start_location:direction(target)

    for _, link_state in ipairs(current_state) do
      local new_end_location =  start_location + (direction * link_state.length)
      link_state.joint:direction(direction)
      link_state.end_location = new_end_location
      start_location = new_end_location
    end

    return 0
  end

  local link_count = #current_state
  local end_location = current_state[link_count].end_location
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

    current_state = solve_backwards(link_count, current_state, target)
    current_state = solve_forwards(1, current_state, start_location, link_count)

    last_delta = current_delta
    end_location = current_state[link_count].end_location
    current_delta = target:distance(end_location)
    delta_change = math.abs(current_delta - last_delta)

  until (current_delta < config.tolerance)
    or (delta_change < config.min_travel)
    or (count == config.max_interations)

  return count
end

return FABRIK
