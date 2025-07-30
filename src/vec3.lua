--[[
  A wrapper around ArduPilot's Vector3f vector which provides some extra functionality.
]]
local string = require("string")
local math = require("math")
local Angle = require("angle")
local Object = require("object")
local Scalar = require("scalar")
local Vector3f = _G["Vector3f"] or require("ardupilot.vector3f")
local Mat3
local Vec3

local generate_operation = function(operation)
  return function(self, other)
    if type(other) == "number" then
      return self[operation .. "_number"](self, other)
    else
      Object.assert_type(other, Vec3)
      return self[operation .. "_vec3"](self, other)
    end
  end
end

local generate_logical = function(operation)
  return function(self, other)
    Object.assert_type(other, Vec3)

    return operation(self:x(), other:x()) and
      operation(self:y(), other:y()) and
      operation(self:z(), other:z())
  end
end

Vec3 = Object.new("Vec3", {
  __add = generate_operation("add"),
  __sub = generate_operation("sub"),
  __mul = generate_operation("mul"),
  __div = generate_operation("div"),
  __eq = generate_logical(function(a, b) return a == b end),
  __lt = generate_logical(function(a, b) return a < b end),
  __le = generate_logical(function(a, b) return a <= b end),
  __tostring = function(self)
    local self_x = self:x()
    local self_y = self:y()
    local self_z = self:z()

    local format = "Vec3{x="

    if Scalar.check_type(self_x, "integer") then
      format = format .. "%d"
    else
      format = format .. "%f"
    end

    format = format .. ",y="

    if Scalar.check_type(self_y, "integer") then
      format = format .. "%d"
    else
      format = format .. "%f"
    end

    format = format .. ",z="

    if Scalar.check_type(self_z, "integer") then
      format = format .. "%d"
    else
      format = format .. "%f"
    end

    format = format .. "}"

    return string.format(format, self_x, self_y, self_z)
  end
})

function Vec3.from_vector3f(vector3f)
  return Object.instance({_vector3f = vector3f}, Vec3)
end

function Vec3.new(x, y, z)
  local v3f = Vector3f()
  v3f:x(x)
  v3f:y(y)
  v3f:z(z)

  return Vec3.from_vector3f(v3f)
end

function Vec3.zero()
  return Vec3.new(0, 0, 0)
end

--- Create a unit vector pointing up (positive Z)
function Vec3.up()
  return Vec3.new(0, 0, 1)
end

--- Create a unit vector pointing down (negative Z)
function Vec3.down()
  return Vec3.new(0, 0, -1)
end

--- Create a unit vector pointing forward (positive X)
function Vec3.forward()
  return Vec3.new(1, 0, 0)
end

--- Create a unit vector pointing backward (negative X)
function Vec3.backward()
  return Vec3.new(-1, 0, 0)
end

--- Create a unit vector pointing right (positive Y)
function Vec3.right()
  return Vec3.new(0, 1, 0)
end

--- Create a unit vector pointing left (negative Y)
function Vec3.left()
  return Vec3.new(0, -1, 0)
end

function Vec3:x()
  return self._vector3f:x()
end

function Vec3:y()
  return self._vector3f:y()
end

function Vec3:z()
  return self._vector3f:z()
end

function Vec3:is_zero()
  return self._vector3f:is_zero()
end

function Vec3:add_number(other)
  Scalar.assert_type(other, "number")
  return Vec3.new(self:x() + other, self:y() + other, self:z() + other)
end

function Vec3:add_vec3(other)
  Object.assert_type(other, Vec3)
  return Vec3.from_vector3f(self._vector3f + other._vector3f)
end

function Vec3:sub_number(other)
  Scalar.assert_type(other, "number")
  return Vec3.new(self:x() - other, self:y() - other, self:z() - other)
end

function Vec3:sub_vec3(other)
  Object.assert_type(other, Vec3)
  return Vec3.from_vector3f(self._vector3f - other._vector3f)
end

function Vec3:mul_number(other)
  Scalar.assert_type(other, "number")
  return Vec3.new(self:x() * other, self:y() * other, self:z() * other)
end

function Vec3:mul_vec3(other)
  Object.assert_type(other, Vec3)
  return Vec3.new(self:x() * other:x(), self:y() * other:y(), self:z() * other:z())
end


function Vec3:div_number(other)
  Scalar.assert_type(other, "number")
  return Vec3.new(self:x() / other, self:y() / other, self:z() / other)
end

function Vec3:div_vec3(other)
  Object.assert_type(other, Vec3)
  return Vec3.new(self:x() / other:x(), self:y() / other:y(), self:z() / other:z())
end

function Vec3:normalise()
  return Vec3.from_vector3f(self._vector3f:normalise())
end

function Vec3:dot(other)
  Object.assert_type(other, Vec3)

  return self:x() * other:x() + self:y() * other:y() + self:z() * other:z()
end

function Vec3:cross(other)
  Object.assert_type(other, Vec3)

  local self_x = self:x()
  local self_y = self:y()
  local self_z = self:z()

  local other_x = other:x()
  local other_y = other:y()
  local other_z = other:z()

  local x = self_y * other_z - self_z * other_y
  local y = self_z * other_x - self_x * other_z
  local z = self_x * other_y - self_y * other_x
  return Vec3.new(x, y, z)
end

function Vec3:length_squared()
  return self:dot(self)
end

function Vec3:length()
  -- return math.sqrt(self:length_squared())
  return self._vector3f:length()
end

--- The (absolute) distance between self and other.
function Vec3:distance(other)
  Object.assert_type(other, Vec3)

  return math.abs((self - other):length())
end

--- The direction from self towards other.
--
-- @return a unit vector
function Vec3:direction(other)
  Object.assert_type(other, Vec3)

  return (other - self):normalise()
end

--- Invert the vector.
function Vec3:invert()
  return self * -1
end

--- The angle between two vectors
--
-- In order to calculate this both vectors have to be normalised into unit
-- vectors.  If the vectors are not normalised before calling this you will get
-- an invalid result.
--
-- @return an instance of Angle.
function Vec3:angle_to(other)
  Object.assert_type(other, Vec3)

  local dot_product = self:dot(other)
  -- Clamp dot product to [-1, 1] to avoid NaN from acos
  dot_product = math.max(-1, math.min(1, dot_product))
  local rads = math.acos(dot_product)
  return Angle.from_radians(rads)
end

--- Constrained rotation
--
-- Calculate a vector that rotates self towards other without exceeding the
-- constraint angle.  Particularly useful in ball joints.
--
-- In order to calculate this both vectors have to be normalised into unit
-- vectors.  If the vectors are not normalised before calling this you will get
-- an invalid result.
--
-- @param other direction to rotate towards (Vec3)
-- @param constraint the maximum angle to rotate by
-- @return a vector describing the target direction
function Vec3:constrained_rotation_towards(other, constraint)
  Object.assert_type(other, Vec3)
  Object.assert_type(constraint, Angle)

  local target_angle = self:angle_to(other)
  if target_angle < constraint then
    -- the target angle is within our constrained range of motion
    return other

  else
    -- rotate towards other while applying a maximum angle constraint
    local correction_axis = other:cross(self)
    
    -- Handle the case where vectors are opposite (cross product is zero)
    if correction_axis:length() < Scalar.FLOAT_EPSILON then
      -- Find an arbitrary perpendicular axis
      local arbitrary_axis
      if math.abs(self:x()) < 0.9 then
        arbitrary_axis = Vec3.new(1, 0, 0)
      else
        arbitrary_axis = Vec3.new(0, 1, 0)
      end
      correction_axis = self:cross(arbitrary_axis):normalise()
    else
      correction_axis = correction_axis:normalise()
    end
    
    return self:rotate_about_axis(correction_axis, constraint)
  end
end

--- Rotate about axis
--
-- In order to calculate this both vectors have to be normalised into unit
-- vectors.  If the vectors are not normalised before calling this you will get
-- an invalid result.
--
-- @param axis the axis around which to rotate
-- @param rotation the clockwise angle to rotate
function Vec3:rotate_about_axis(axis, rotation)
  Object.assert_type(axis, Vec3)
  Object.assert_type(rotation, Angle)

  Mat3 = Mat3 or require("mat3")

  -- precalculate a bunch of values to speed things up.
  local axis_x = axis:x()
  local axis_y = axis:y()
  local axis_z = axis:z()
  local theta = rotation:radians()
  local sin_theta = math.sin(theta)
  local cos_theta = math.cos(theta)
  local one_minus_cos_theta = 1.0 - cos_theta
  local xx_omcs = axis_x * axis_x * one_minus_cos_theta
  local xy_omcs = axis_x * axis_y * one_minus_cos_theta
  local xz_omcs = axis_x * axis_z * one_minus_cos_theta
  local yy_omcs = axis_y * axis_y * one_minus_cos_theta
  local yz_omcs = axis_y * axis_z * one_minus_cos_theta
  local zz_omcs = axis_z * axis_z * one_minus_cos_theta

  -- build a rotation matrix for our target angle
  local rotation_matrix = Mat3.new({
    -- rotated X axis
    xx_omcs + cos_theta,
    xy_omcs + axis_z * sin_theta,
    xz_omcs - axis_y * sin_theta,

    -- rotated Y axis
    xy_omcs - axis_z * sin_theta,
    yy_omcs + cos_theta,
    yz_omcs + axis_x * sin_theta,

    -- rotated Z axis
    xz_omcs + axis_y * sin_theta,
    yz_omcs - axis_x * sin_theta,
    zz_omcs + cos_theta
  })

  -- rotate self by the rotation matrix
  return rotation_matrix:mul_vec3(self)
end

--- Project self into the plane
function Vec3:project_on_plane(plane_normal)
  local b = self:normalise()
  local n = plane_normal:normalise()
  return b:sub_vec3(n:mul_number(b:dot(plane_normal))):normalise()
end

return Vec3
