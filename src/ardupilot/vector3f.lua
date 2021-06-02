--[[
  This module is a drop-in replacement for ArduPilot's Vector3f userdata in test
  mode.
]]
local math = require("math")
local string = require("string")
local Vector3f = {}

local mt = {
  __add = function(self, other)
    return Vector3f.new(self:x() + other:x(), self:y() + other:y(), self:z() + other:z())
  end,
  __sub = function(self, other)
    return Vector3f.new(self:x() - other:x(), self:y() - other:y(), self:z() - other:z())
  end,
  __index = Vector3f,
  __tostring = function(self)
    return string.format("Vector3f{x = %f, y = %f, z = %f}", self:x(), self:y(), self:z())
  end
}

local is_nan = function(n)
  return type(n) == "number" and n ~= n
end

local is_inf = function(n)
  return type(n) == "number" and (n == math.huge or n == -math.huge)
end

function Vector3f.new(x, y, z)
  local vec = {_x = x or 0, _y = y or 0, _z = z or 0}
  setmetatable(vec, mt)
  return vec
end

function Vector3f:x(x)
  if x then
    return Vector3f.new(x, self:y(), self:z())
  else
    return self._x
  end
end

function Vector3f:y(y)
  if y then
    return Vector3f.new(self:x(), y, self:z())
  else
    return self._y
  end
end

function Vector3f:z(z)
  if z then
    return Vector3f.new(self:x(), self:y(), z)
  else
    return self._z
  end
end

function Vector3f:length()
  return math.sqrt((self:x() ^ 2) + (self:y() ^ 2) + (self:z() ^ 2))
end

function Vector3f:normalize()
  local length = self:length()
  return Vector3f.new(self:x() / length, self:y() / length, self:z() / length)
end

function Vector3f:is_nan()
  return is_nan(self:x()) or is_nan(self:y()) or is_nan(self:z())
end

function Vector3f:is_inf()
  return is_inf(self:x()) or is_inf(self:y()) or is_inf(self:z())
end

function Vector3f:is_zero()
  return self:x() == 0 and self:y() == 0 and self:z() == 0
end

return function()
  return Vector3f.new()
end
