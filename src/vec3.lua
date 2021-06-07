--[[
  A wrapper around ArduPilot's Vector3f vector which provides some extra functionality.
]]
local string = require("string")
local Object = require("object")
local Quat
local Vector3f = _G["Vector3f"] or require("ardupilot.vector3f")
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

Vec3 = Object.new("Vec3", {}, {
  __add = generate_operation("add"),
  __sub = generate_operation("sub"),
  __mul = generate_operation("mul"),
  __div = generate_operation("div"),
  __eq = generate_logical(function(a, b) return a == b end),
  __lt = generate_logical(function(a, b) return a < b end),
  __le = generate_logical(function(a, b) return a <= b end),
  __tostring = function(self)
    return string.format("Vec3{x=%q,y=%q,z=%q}", self:x(), self:y(), self:z())
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

function Vec3:x()
  return self._vector3f:x()
end

function Vec3:y()
  return self._vector3f:y()
end

function Vec3:z()
  return self._vector3f:z()
end

function Vec3:add_number(other)
  if type(other) == "number" then
    return Vec3.new(self:x() + other, self:y() + other, self:z() + other)
  else
    return nil, "Expected argument to be a number"
  end
end

function Vec3:add_vec3(other)
  if other.class == Vec3 then
    return Vec3.from_vector3f(self._vector3f + other._vector3f)
  else
    return nil, "Expected argument to be Vec3"
  end
end

function Vec3:sub_number(other)
  if type(other) == "number" then
    return Vec3.new(self:x() - other, self:y() - other, self:z() - other)
  else
    return nil, "Expected argument to be a number"
  end
end

function Vec3:sub_vec3(other)
  if other.class == Vec3 then
    return Vec3.from_vector3f(self._vector3f - other._vector3f)
  else
    return nil, "Expected argument to be Vec3"
  end
end

function Vec3:mul_number(other)
  if type(other) == "number" then
    return Vec3.new(self:x() * other, self:y() * other, self:z() * other)
  else
    return nil, "Expected argument to be a number"
  end
end

function Vec3:mul_vec3(other)
  if other.class == Vec3 then
    return Vec3.new(self:x() * other:x(), self:y() * other:y(), self:z() * other:z())
  else
    return nil, "Expected argument to be Vec3"
  end
end


function Vec3:div_number(other)
  if type(other) == "number" then
    return Vec3.new(self:x() / other, self:y() / other, self:z() / other)
  else
    return nil, "Expected argument to be a number"
  end
end

function Vec3:div_vec3(other)
  if other.class == Vec3 then
    return Vec3.new(self:x() / other:x(), self:y() / other:y(), self:z() / other:z())
  else
    return nil, "Expected argument to be Vec3"
  end
end

function Vec3:normalize()
  return Vec3.from_vector3f(self._vector3f:normalize())
end

function Vec3:dot(other)
  if other.class == Vec3 then
    return self:x() * other:x() + self:y() * other:y() + self:z() * other:z()
  end
  return nil, "Argument is not a Vec3"
end

function Vec3:cross(other)
  if other.class == Vec3 then
    local x = self:y() * other:z() - self:z() * other:y()
    local y = self:z() * other:x() - self:x() * other:z()
    local z = self:x() * other:y() - self:y() * other:x()
    return Vec3.new(x, y, z)
  end
  return nil, "Argument is not a Vec3"
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
  Object.assert_type(quat, Quat)
  local point = Quat.new(self:x(), self:y(), self:z(), 0.0)
  local conj = quat:conj()

  return quat:multiply_without_normalize(point):multiply_without_normalize(conj)
end

return Vec3
