--[[
  This module is a drop-in replacement for ArduPilot's Vector2f userdata in test
  mode.
]]
local math = require("math")
local string = require("string")
local Vector2f = {}

local mt = {
  __add = function(self, other)
    return Vector2f.new(self:x() + other:x(), self:y() + other:y())
  end,
  __sub = function(self, other)
    return Vector2f.new(self:x() - other:x(), self:y() - other:y())
  end,
  __index = Vector2f,
  __tostring = function(self)
    return string.format("Vector2f{x = %f, y = %f}", self:x(), self:y())
  end
}

local is_nan = function(n)
  return type(n) == "number" and n ~= n
end

local is_inf = function(n)
  return type(n) == "number" and (n == math.huge or n == -math.huge)
end

function Vector2f.new(x, y)
  local vec = {_x = x or 0, _y = y or 0}
  setmetatable(vec, mt)
  return vec
end

function Vector2f:x(new_value)
  if new_value then
    return Vector2f.new(new_value, self._y)
  else
    return self._x
  end
end

function Vector2f:y(new_value)
  if new_value then
    return Vector2f.new(self._x, new_value)
  else
    return self._y
  end
end

function Vector2f:length()
  local x, y = self:x(), self:y()
  return math.sqrt((x ^ 2) + (y ^ 2))
end

function Vector2f:normalize()
  local length = self:length()
  local x, y = self:x(), self:y()

  return Vector2f.new(x / length, y / length)
end

function Vector2f:is_nan()
  return is_nan(self:x()) or is_nan(self:y())
end

function Vector2f:is_inf()
  return is_inf(self:x()) or is_inf(self:y())
end

function Vector2f:is_zero()
  return self:x() == 0 and self:y() == 0
end

return function()
  return Vector2f.new()
end
