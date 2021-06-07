--[[
  Quaternions.
]]
local math = require("math")
local Object = require("object")
local Vec3
local Quat

local add = function(self, other)
  return Quat.new(self.x + other.x, self.y + other.y, self.z + other.z, self.w + other.w)
end

local sub = function(self, other)
  return Quat.new(self.x - other.x, self.y - other.y, self.z - other.z, self.w - other.w)
end

local mul = function(self, other)
  if type(other) == "number" then
    return Quat.new(self.x * other, self.y * other, self.z * other, self.w * other)
  else
    Object.assert_type(other, Quat)
    return self:multiply_without_normalize(other):normalize()
  end
end

local div = function(self, other)
  if type(other) == "number" then
    if other == 0.0 then
      return Quat.identity()
    else
      local rec = 1.0 / other
      return Quat.new(self.x * rec, self.y * rec, self.z * rec, self.w * rec)
    end
  else
    return nil, "Cannot divide quaternions by non-numbers"
  end
end

Quat = Object.new("Quat", {}, {
  __add = add,
  __sub = sub,
  __mul = mul,
  __div = div
})

function Quat.new(x, y, z, w)
  return Object.instance({x = x or 0, y = y or 0, z = z or 0, w = w or 0}, Quat)
end

function Quat.zero()
  return Quat.new(0, 0, 0, 0)
end

function Quat.identity()
  return Quat.new(0, 0, 0, 1)
end

function Quat:mag()
  return math.sqrt(self.w * self.w + self.z * self.z + self.y * self.y + self.x * self.x)
end

function Quat:conj()
  return Quat.new(-self.x, -self.y, -self.z, self.w)
end

function Quat:invert_sign()
  return Quat.new(-self.x, -self.y, -self.z, -self.w)
end

function Quat:normalize()
  local mag = self:mag()
  if mag ~= 0.0 then
    mag = 1.0 / mag
  end

  return Quat.new(self.x * mag, self.y * mag, self.z * mag, self.w * mag)
end

function Quat:multiply_without_normalize(other)
  Object.assert_type(other, Quat)

  Vec3 = Vec3 or require("vec3")
  local v1 = Vec3.new(self.x, self.y, self.z)
  local v1a = v1 * self.w
  local v2 = Vec3.new(other.x, other.y, other.z)
  local v2a = v2 * self.w
  local w = self.w * other.w - v1.dot(v2)
  local v3 = v1:cross(v2) + v1a + v2a
  return Quat.new(v3.x(), v3.y(), v3.z(), w)
end

function Quat:dot(other)
  Object.assert_type(other, Quat)

  return self.x * other.x + self.y * other.y + self.z * other.z + self.w * other.w
end

function Quat.unit()
  return Quat.new(0, 0, 0, 1)
end

function Quat:normalize_sign()
  local unit = Quat.unit()
  local dot = self:dot(unit)

  if dot < 0.0 then
    return self:invert_sign()
  else
    return self
  end
end

function Quat:angle(v1, v2)
  Vec3 = Vec3 or require("vec3")
  Object.assert_type(v1, Vec3)
  Object.assert_type(v2, Vec3)

  local denominator = 1.0 / v1:length() / v2:length()
  local cos_a = v1:dot(v2) * denominator

  if (cos_a >= -1.0 and cos_a <= 1.0) then
    local v3 = v1:cross(v2):normalize()
    local angle = math.acos(cos_a)
    local cos_a = math.cos(angle * 0.5)
    local sin_a = math.sin(angle * 0.5)
    v3 = v3 * sin_a
    return Quat.new(v3.x(), v3.y(), v3.z(), cos_a)
  else
    return Quat:identity()
  end
end

function Quat:angle_normalized_vectors(v1, v2)
  Vec3 = Vec3 or require("vec3")
  Object.assert_type(v1, Vec3)
  Object.assert_type(v2, Vec3)

  local cos_a = v1:dot(v2)
  if (cos_a >= -1.0 and cos_a <= 1.0) then
    local v3 = v1:cross(v2)
    local angle = math.acos(cos_a)
    local cos_a = math.cos(angle * 0.5)
    local sin_a = math.sin(angle * 0.5)
    v3 = v3 * sin_a

    return Quat.new(v3.x(), v3.y(), v3.z(), cos_a)
  else
    return Quat:identity()
  end
end

return Quat
