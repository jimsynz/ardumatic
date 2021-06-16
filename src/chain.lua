local Joint = require("joint")
local Object = require("object")
local Link = require("link")
local Scalar = require("scalar")
local string = require("string")
local Vec3 = require "vec3"

local LastPart = {
  LINK = 0,
  JOINT = 1
}

--- The Chain class
--
-- Defines a chain of Joint and Link instances which define a robot limb.
local Chain = Object.new("Chain", {
  __tostring = function(self)
    if self._name then
      return string.format("Chain{origin=%s,name=%s,length=%d}", self._origin, self._name, #self._chain)
    else
      return string.format("Chain{origin=%s,length=%d}", self._origin, #self._chain)
    end
  end
})

--- Create an instance of Chain
--
-- @param name an optional name to aid with debugging.
function Chain.new(origin, name)
  Object.assert_type(origin, Vec3, true)
  Scalar.assert_type(name, "string", true)

  return Object.instance({
    _chain = {},
    _last_part = LastPart.LINK,
    _name = name,
    _origin = origin or Vec3.zero()
  }, Chain)
end

--- Add a part to the Chain
--
-- This is the main interface for building your chain.  Use it to add Joints and
-- Links to the end of the chain.
--
-- Note that your chain should always start with a Joint and alternate between
-- Joints and Links from then on.
function Chain:add(part)
  if self._last_part == LastPart.JOINT then
    Object.assert_type(part, Link)
    table.insert(self._chain, part)
    self._last_part = LastPart.LINK

  elseif self._last_part == LastPart.LINK then
    Object.assert_type(part, Joint)
    table.insert(self._chain, part)
    self._last_part = LastPart.JOINT
  end

  return self
end

--- The number of parts in the chain
--
-- Do not confuse this for the chain's reach.
function Chain:length()
  return #self._chain
end

--- The reach of the chain
--
-- The maximum distance this chain can reach if all the links were colinear
-- ignoring joint constraints (ie the sum of all link lengths).
--
-- @return a positive integer.
function Chain:reach()
  local reach = 0
  for _joint, part in self:forward_pairs() do
    reach = reach + part:length()
  end
  return reach
end

--- The end-effector position.
--
-- Calculates the position of the end effector given the current configuration
-- of the joints.
function Chain:end_location()
  local end_location = self:origin()

  for joint, link in self:forward_pairs() do
    local link_vector = joint:direction() * link:length()
    end_location = end_location + link_vector
  end

  return end_location
end

--- Position at link end
--
-- Calculates the end position of link number provided.
-- @param link_number a positive integer explaining which part we're calculating
-- to.
function Chain:link_location(link_number)
  Scalar.assert_type(link_number, "integer")
  assert(link_number > 0, "The part number must be greater than zero")
  local link_count = math.floor(#self._chain / 2)
  assert(link_number <= link_count, "The link number must be <= the number of links in the chain")

  local link_location = Vec3.zero()
  local count = 0
  local iter = self:forward_pairs()

  while count < link_number do
    count = count + 1
    local joint, link = iter()
    local link_vector = joint:direction() * link:length()
    link_location = link_location + link_vector
  end

  return link_location
end

--- Return the chain state for solving
--
-- @return a list of tables containing each joint, link length and current end position.
function Chain:chain_state()
  local current_location = self:origin()
  local results = {}

  -- FIXME change this into an iterator so that we don't cause a
  -- double-iteration

  for joint, link in self:forward_pairs() do
    local length = link:length()
    local link_vector = joint:direction() * link:length()
    local new_location = current_location + link_vector
    table.insert(results, {
      joint_location = current_location,
      joint = joint,
      length = length,
      end_location = new_location
    })
    current_location = new_location
  end

  return results
end

--- Iterate the chain parts from the root to the end
--
-- @return an iterator.
function Chain:forwards()
  local i = 0
  return function()
    i = i + 1
    return self._chain[i]
  end
end

--- Iterate the chain parts from the end to the root
--
-- @return an iterator.
function Chain:backwards()
  local i = #self._chain
  return function()
    local value = self._chain[i]
    i = i - 1
    return value
  end
end

function Chain:forward_pairs()
  local i = 0
  return function()
    i = i + 1
    local joint = self._chain[i]
    i = i + 1
    local link = self._chain[i]
    return joint, link
  end
end

function Chain:backward_pairs()
  local i = #self._chain
  return function()
    local link = self._chain[i]
    i = i - 1
    local joint = self._chain[i]
    i = i - 1
    return joint, link
  end
end

function Chain:get(index)
  return self._chain[index]
end

--- The name of the chain (if set)
Chain.name = Object.reader("name")

Chain.origin = Object.reader("origin")

return Chain
