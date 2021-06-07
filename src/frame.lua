local string = require("string")
local Object = require("object")
local Vec3 = require("vec3")

local Frame = Object.new("Frame", {}, {
  __tostring = function(self)
    return string.format("Frame{position=%s,rotation=%s}", self.position, self.rotation)
  end
})

function Frame.new(position, rotation)
  Object.assert_type(position, Vec3, true)
  Object.assert_type(rotation, Vec3, true)

  return Object.instance({
    position = position or Vec3.zero(),
    rotation = rotation or Vec3.zero()
  }, Frame)
end

return Frame
