local math = require("math")
local Object = require("object")
local Angle

local two_pi = math.pi * 2

local generate_infix = function(operation)
  return function(self, other)
    Object.assert_type(self, Angle)
    Object.assert_type(other, Angle)

    if self._rad then
      return Angle.from_radians(operation(self._rad, other:radians()))
    else
      return Angle.from_degrees(operation(self._deg, other:degrees()))
    end
  end
end

local generate_logical = function(operation)
  return function(self, other)
    Object.assert_type(self, Angle)
    Object.assert_type(other, Angle)

    if self._rad then
      return operation(self._rad, other:radians())
    else
      return operation(self._def, other:degrees())
    end
  end
end

Angle = Object.new("Angle", {}, {
  __add = generate_infix(function(a, b) return a + b end),
  __sub = generate_infix(function(a, b) return a - b end),
  __mul = generate_infix(function(a, b) return a * b end),
  __div = generate_infix(function(a, b) return a / b end),
  __eq = generate_logical(function(a, b) return a == b end),
  __lt = generate_logical(function(a, b) return a < b end),
  __le = generate_logical(function(a, b) return a <= b end),
  __tostring = function(self)
    if self._deg then
      return string.format("Angle<%f°>", self._deg)
    elseif self._rad then
      return string.format("Angle<%f㎭>", self._rad)
    else
      return "Angle<0>"
    end
  end
})

local normalize_rad = function(rad)
  local norm = math.fmod(rad, two_pi)
  if norm < 0 then
    return two_pi + norm
  else
    return norm
  end
end

local normalize_deg = function(deg)
  local norm = math.fmod(deg, 360)
  if norm < 0 then
    return 360 + norm
  else
    return norm
  end
end


function Angle.zero()
  return Object.instance({_rad = 0, _deg = 0}, Angle)
end

function Angle.from_radians(radians)
  return Object.instance({_rad = radians}, Angle)
end

function Angle.from_degrees(degrees)
  return Object.instance({_deg = degrees}, Angle)
end

function Angle:radians()
  if self._rad then
    return self._rad
  else
    self._rad = math.rad(self._deg)
    return self._rad
  end
end

function Angle:degrees()
  if self._deg then
    return self._deg
  else
    self._deg = math.deg(self._rad)
    return self._deg
  end
end

function Angle:normalize()
  local rad, deg
  if self._rad and self._deg then
    rad = normalize_rad(self._rad)
    deg = math.deg(rad)
  elseif self._rad then
    rad = normalize_rad(self._rad)
  elseif self._deg then
    deg = normalize_deg(self._deg)
  end
  return Object.instance({_rad = rad, _deg = deg}, Angle)
end

return Angle
