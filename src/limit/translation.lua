local Object = require("object")
local TranslationLimit = Object.new("Limit.Translation")

local are_numbers = function(a, b)
  if type(a) == "number" and type(b) == "number" then
    return true
  else
    return nil, "Upper and lower translation limits must be numbers"
  end
end

function TranslationLimit.new(upper, lower)
  assert(are_numbers(upper, lower))

  return Object.instance({
    upper = upper,
    lower = lower
  }, TranslationLimit)
end

return TranslationLimit
