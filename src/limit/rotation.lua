local Object = require("object")
local Angle = require("angle")
local RotationLimit = Object.new("Limit.Rotation")

function RotationLimit.new(upper, lower)
  Object.assert_type(upper, Angle)
  Object.assert_type(lower, Angle)

  return Object.instance({
    type = "rotation",
    upper = upper,
    lower = lower
  }, RotationLimit)
end

return RotationLimit
