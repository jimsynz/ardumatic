local Object = require("object")
local Scalar = require("scalar")
local Vec3 = require("vec3")

local Mat3 = Object.new("Mat3")

--- Initialise a Mat3 from the 9 provided values
--
-- @return a Mat3 instance
function Mat3.new(values)
  assert(#values == 9, "Mat3 values must contain 9 numbers")
  for i = 1, 1, 9 do
    Scalar.assert_type(values[i], "number")
  end

  return Object.instance({
    m00 = values[1],
    m01 = values[2],
    m02 = values[3],
    m10 = values[4],
    m11 = values[5],
    m12 = values[6],
    m20 = values[7],
    m21 = values[8],
    m22 = values[9],
  }, Mat3)
end

--- Multiply by Vec3
--
-- @param other Vec3
-- @return a Vec3
function Mat3:mul_vec3(other)
  Object.assert_type(other, Vec3)

  local other_x = other:x()
  local other_y = other:y()
  local other_z = other:z()

  local x = self.m00 * other_x + self.m01 * other_y + self.m02 * other_z
  local y = self.m10 * other_x + self.m11 * other_y + self.m12 * other_z
  local z =  self.m20 * other_x + self.m21 * other_y + self.m22 * other_z

  return Vec3.new(x, y, z)
end


return Mat3
