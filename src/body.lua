local Chain = require("chain")
local Frame = require("frame")
local Object = require("object")
local Limb = require("body.limb")
local Scalar = require("scalar")
local Vec3 = require("vec3")

local Body = Object.new("Body")

--- Initialise a new Robot body.
--
-- The body is the root container of the robot.  It contains each chain (ie
-- limb) and can optionally have a name to aid in debugging.
--
-- @param origin a Frame which defines the root coordinate of the body.
-- @param name an optional string name, to aid in debugging.
function Body.new(origin, name)
  Object.assert_type(origin, Frame)
  Scalar.assert_type(name, "string", true)

  return Object.instance({
    _origin = origin,
    _name = name,
    _limbs = {}
  }, Body)
end

Body.name = Object.reader("name")
Body.origin = Object.reader("origin")
Body.Limb = Limb

--- Attach a chain to the body.
--
-- @param offset the coordinates of the chain's root joint relative to the Body root.
-- @param chain an instance of Chain
-- @return an instance of Body.Limb
function Body:attach_chain(offset, chain)
  Object.assert_type(offset, Vec3)
  Object.assert_type(chain, Chain)

  local limb = Limb.new(offset, chain)
  table.insert(self._limbs, limb)

  return limb
end

--- Chain end locations
--
-- Return the end locations of all limbs attached to the body
--
-- @return list of Vec3.
function Body:end_locations()
  local end_locations = {}

  for _, limb in ipairs(self._limbs) do
    table.insert(end_locations, limb:end_location())
  end

  return end_locations
end

return Body
