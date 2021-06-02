--[[
  A wrapper around ArduPilot's Vector3f vector which provides some extra functionality.
]]
local Quat
local Vector3f = Vector3f or require("ardupilot.vector3f")
local Vec3 = {}

local add = function(self, other)
  if type(other) == "number" then
    return Vec3.new(self:x() + other, self:y() + other, self:z() + other)
  else
    return Vec3.from_vector3f(self._vector3f + other._vector3f)
  end
end

local sub = function(self, other)
  if type(other) == "number" then
    return Vec3.new(self:x() - other, self:y() - other, self:z() - other)
  else
    return Vec3.from_vector3f(self._vector3f - other._vector3f)
  end
end

local mul = function(self, other)
  if type(other) == "number" then
    return Vec3.new(self:x() * other, self:y() * other, self:z() * other)
  elseif Vec3.is_vec3(other) then
    return Vec3.new(self:x() * other:x(), self:y() * other:y(), self:z() * other:z())
  else
    return nil, "Unable to multiply vector with unknown type"
  end
end

local div = function(self, other)
  if type(other) == "number" then
    local det = 1.0 / other

    return Vec3.new(self:x() * det, self:y() * det, self:z() * det)
  else
    return Vec3.new(self:x() / other:x(), self:y() / other:y(), self:z() / other:z())
  end
end

local mt = {
  __index = Vec3,
  __add = add,
  __sub = sub,
  __mul = mul,
  __div = div
}

function Vec3.from_vector3f(vector3f)
  local vec = {_vector3f = vector3f}
  setmetatable(vec, mt)
  return vec
end

function Vec3.new(x, y, z)
  return Vec3.from_vector3f(Vector3f():x(x):y(y):z(z))
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

function Vec3.is_vec3(v)
  if v._vector3f then
    return true
  else
    return false
  end
end

function Vec3.zero()
  return Vec3.new(0, 0, 0)
end

function Vec3:normalize()
  return Vec3.from_vector3f(self._vector3f:normalize())
end

function Vec3:dot(other)
  return self:x() * other:x() + self:y() * other:y() + self:z() * other:z()
end

function Vec3:cross(other)
  local x = self:y() * other:z() - self:z() * other:y()
  local y = self:z() * other:x() - self:x() * other:z()
  local z = self:x() * other:y() - self:y() * other:x()

  return Vec3.new(x, y, z)
end

function Vec3:length_squared()
  return self:dot(self)
end

function Vec3:length()
  -- return math.sqrt(self:length_squared())
  return self._vector3f:length()
end

function Vec3:rotate(quat)
  Quat = Quat or require "quat"
  local point = Quat.new(self:x(), self:y(), self:z(), 0.0)
  local conj = quat:conj()

  return quat:multiply_without_normalize(point):multiply_without_normalize(conj)
end

return Vec3
