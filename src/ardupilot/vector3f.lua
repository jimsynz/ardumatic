--[[
  This module is a drop-in replacement for ArduPilot's Vector3f userdata in test
  mode.
]]
local math = require("math")
local string = require("string")
local Object = require("object")
local Vector3f

Vector3f = Object.new("Vector3f", {
  __add = function(self, other)
    Object.assert_type(other, Vector3f)
    return Vector3f.new(self:x() + other:x(), self:y() + other:y(), self:z() + other:z())
  end,
  __sub = function(self, other)
    Object.assert_type(other, Vector3f)
    return Vector3f.new(self:x() - other:x(), self:y() - other:y(), self:z() - other:z())
  end,
  __tostring = function(self)
    return string.format("Vector3f{x = %f, y = %f, z = %f}", self:x(), self:y(), self:z())
  end
})


local is_nan = function(n)
  return type(n) == "number" and n ~= n
end

local is_inf = function(n)
  return type(n) == "number" and (n == math.huge or n == -math.huge)
end

function Vector3f.new(x, y, z)
  return Object.instance({_x = x, _y = y, _z = z}, Vector3f)
end

function Vector3f:length()
  return math.sqrt((self:x() ^ 2) + (self:y() ^ 2) + (self:z() ^ 2))
end

function Vector3f:normalise()
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

Vector3f.x = Object.accessor("x")
Vector3f.y = Object.accessor("y")
Vector3f.z = Object.accessor("z")

return function()
  return Vector3f.new()
end
