local math = require("math")
local string = require("string")
local Scalar = {}

function Scalar.check_type(value, type_name, allow_nil)
  if allow_nil and value == nil then
    return true
  elseif type(value) == type_name or math.type(value) == type_name then
    return true
  elseif allow_nil then
    return nil, string.format("TypeError: %q is not a %s or nil", value, type_name)
  else
    return nil, string.format("TypeError: %q is not a %s", value, type_name)
  end
end

function Scalar.assert_type(value, type_name, allow_nil)
  assert(Scalar.check_type(value, type_name, allow_nil))
end

Scalar.FLOAT_EPSILON = 0.001

return Scalar
