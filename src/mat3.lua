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

function Mat3.zero()
  return Object.instance({
    m00 = 0.0,
    m01 = 0.0,
    m02 = 0.0,
    m10 = 0.0,
    m11 = 0.0,
    m12 = 0.0,
    m20 = 0.0,
    m21 = 0.0,
    m22 = 0.0,
  }, Mat3)
end

function Mat3.rotation_matrix(reference_direction)
  Object.assert_type(reference_direction, Vec3)
  reference_direction = reference_direction:normalise()

  local rm = Mat3.zero()

  -- set Z basis
  rm.m20 = reference_direction.x()
  rm.m21 = reference_direction.y()
  rm.m22 = reference_direction.z()

  -- set X basis
  if math.abs(reference_direction.y > 0.9999) then
    rm.m00 = 1.0
    rm.m01 = 0
    rm.m02 = 0
  else
    local x_basis = reference_direction:cross(Vec3.new(0.0, 1.0, 0.0):normalise())
    rm.m00 = x_basis.x()
    rm.m01 = x_basis.y()
    rm.m02 = x_basis.z()
  end

  -- set Y basis
  local x_basis = Vec3.new(rm.m00, rm.m01, rm.m02)
  local z_basis = Vec3.new(rm.m20, rm.m21, rm.m22)
  local y_basis = x_basis:cross(z_basis):normalise()
  rm.m10 = y_basis.x()
  rm.m11 = y_basis.y()
  rm.m12 = y_basis.z()

  return rm
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
