local Object = require("object")
local TranslationLimit = require("limit.translation")
local PrismaticJoint


local generate_logical = function(operation)
  return function(self, other)
    Object.check_type(other, PrismaticJoint)

    return operation(self.translation_limit, other.translation_limit)
  end
end

PrismaticJoint = Object.new("Joint.Prismatic", {}, {
  __eq = generate_logical(function(a, b) return a == b end),
  __lt = generate_logical(function(a, b) return a < b end),
  __le = generate_logical(function(a, b) return a <= b end),
  __tostring = function(self)
    if self.translation_limit then
      return string.format("PrismaticJoint{translation_limit=%s}", self.translation_limit)

    else
      return "PrismaticJoint{}"
    end
  end
})

function PrismaticJoint.new(translation_limit)
  Object.assert_type(translation_limit, TranslationLimit, true)

  return Object.instance({
    translation_limit = translation_limit,
    dof = 1
  }, PrismaticJoint)
end

return PrismaticJoint
