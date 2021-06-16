local Joint = require("joint")
local Link = require("link")
local LinkState = require("chain.link_state")
local Object = require("object")
local Scalar = require("scalar")
local string = require("string")
local Vec3 = require("vec3")

--- The Chain class
--
-- Defines a chain of joints and links which make a robot limb.
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
    _name = name,
    _origin = origin or Vec3.zero(),
    _reach = 0
  }, Chain)
end

--- Add a part to the Chain
--
-- This is the main interface for building your chain.  Use it to add Joints and
-- Links to the end of the chain.
--
-- @param joint an instance of Joint
-- @param link an instance of Link
function Chain:add(joint, link)
  Object.assert_type(joint, Joint)
  Object.assert_type(link, Link)

  local root_location
  if #self._chain > 0 then
    root_location = self._chain[#self._chain].tip_location
  else
    root_location = self._origin
  end
  local link_length = link:length()
  local tip_location = root_location + (joint:direction() * link_length)
  local link_state = LinkState.new(joint, link, root_location, tip_location)

  table.insert(self._chain, link_state)
  self._reach = self._reach + link_length
  return self
end

--- The number of links in the chain
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
  return self._reach
end

--- The end-effector position.
--
-- Calculates the position of the end effector given the current configuration
-- of the joints.
function Chain:end_location()
  local last_link = self._chain[#self._chain]
  if last_link then
    return last_link.tip_location
  else
    return self._origin
  end
end

--- Iterate the chain link states from the root to the end
--
-- @return an iterator.
function Chain:forwards()
  local i = 0
  return function()
    i = i + 1
    return self._chain[i]
  end
end

--- Iterate the chain link states from the end to the root
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

--- The name of the chain (if set)
Chain.name = Object.reader("name")

Chain.origin = Object.reader("origin")

return Chain
