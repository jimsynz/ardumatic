local Object = require("object")
local Body

local generate_infix = function(operation)
  return function(self, other)
    if Object.check_type(other, Body) then
      return Body.new(operation(self.length, other.length))
    elseif type(other) == "number" then
      return Body.new(operation(self.length, other))
    else
      return nil, "Expected operand to be a Body or a number"
    end
  end
end

local generate_logical = function(operation)
  return function(self, other)
    if Object.check_type(other, Body) then
      return operation(self.length, other.length)
    elseif type(other) == "number" then
      return operation(self.length, other)
    else
      return nil, "Expected operand to be a Body or a number"
    end
  end
end

Body = Object.new("Body", {}, {
  __add = generate_infix(function(a, b) return a + b end),
  __sub = generate_infix(function(a, b) return a - b end),
  __mul = generate_infix(function(a, b) return a * b end),
  __div = generate_infix(function(a, b) return a / b end),
  __eq = generate_logical(function(a, b) return a == b end),
  __lt = generate_logical(function(a, b) return a < b end),
  __le = generate_logical(function(a, b) return a <= b end),
  __tostring = function(self)
    return string.format("Body{length = %f}", self.length)
  end
})

function Body.new(length)
  assert(type(length) == "number", "Must provide a body length")
  assert(length > 0, "Body must have a length of more than zero")
  return Object.instance({
    _length = length,
    length = Object.reader("length")
  }, Body)
end

return Body
