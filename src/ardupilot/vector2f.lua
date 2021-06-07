--[[
  This module is a drop-in replacement for ArduPilot's Vector2f userdata in test
  mode.
]]
local math = require("math")
local string = require("string")
local Object = require("object")
local Vector2f

Vector2f = Object.new("Vector2f", {
  x = Object.accessor("x"),
  y = Object.accessor("y")
}, {
  __add = function(self, other)
    Object.assert_type(other, Vector2f)
    return Vector2f.new(self._x + other._x, self._y + other._y)
  end,
  __sub = function(self, other)
    Object.assert_type(other, Vector2f)
    return Vector2f.new(self._x - other._x, self._y - other._y)
  end,
  __tostring = function(self)
    return string.format("Vector2f{x=%q,y=%q}", self._x, self._y)
  end
})

local is_nan = function(n)
  return type(n) == "number" and n ~= n
end

local is_inf = function(n)
  return n == math.huge or n == -math.huge
end

function Vector2f.new(x, y)
  return Object.instance({_x = x, _y = y}, Vector2f)
end

function Vector2f:length()
  return math.sqrt((self._x ^ 2) + (self._y ^ 2))
end

function Vector2f:normalize()
  local length = self:length()
  return Vector2f.new(self._x / length, self._y / length)
end

function Vector2f:is_nan()
  return is_nan(self._x) or is_nan(self._y)
end

function Vector2f:is_inf()
  return is_inf(self._x) or is_inf(self._y)
end

function Vector2f:is_zero()
  return self._x == 0 and self._y == 0
end

return function()
  return Vector2f.new()
end
