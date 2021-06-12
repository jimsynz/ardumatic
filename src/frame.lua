local string = require("string")
local Object = require("object")
local Vec3 = require("vec3")

local Frame

Frame = Object.new("Frame", {
  __eq = function(self, other)
    Object.assert_type(other, Frame)

    return self.position == other.position and self.rotation == other.rotation
  end,
  __tostring = function(self)
    return string.format("Frame{position=%s,rotation=%s}", self.position, self.rotation)
  end
})

function Frame.new(rotation, position)
  Object.assert_type(position, Vec3, true)
  Object.assert_type(rotation, Vec3)
  assert(not rotation:is_zero(), "A frame rotation must be non-zero")

  return Object.instance({
    position = position or Vec3.zero(),
    rotation = rotation:normalize()
  }, Frame)
end

return Frame
