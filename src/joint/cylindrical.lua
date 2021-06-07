local Object = require("object")
local RotationLimit = require("limit.rotation")
local TranslationLimit = require("limit.translation")
local CylindricalJoint

local generate_logical = function(operation)
  return function(self, other)
    Object.check_type(other, CylindricalJoint)

    return operation(self.rotation_limit, other.rotation_limit) and
      operation(self.translation_limit, other.translation_limit)
  end
end

CylindricalJoint = Object.new("Joint.Cylindrical", {}, {
  __eq = generate_logical(function(a, b) return a == b end),
  __lt = generate_logical(function(a, b) return a < b end),
  __le = generate_logical(function(a, b) return a <= b end),
  __tostring = function(self)
    if self.rotation_limit and self.translation_limit then
      return string.format("CylindricalJoint{rotation_limit=%s,translation_limit=%s}",  self.rotation_limit, self.translation_limit)

    elseif self.rotation_limit then
      return string.format("CylindricalJoint{rotation_limit=%s}", self.rotation_limit)

    elseif self.translation_limit then
      return string.format("CylindricalJoint{translation_limit=%s}", self.translation_limit)

    else
      return "CylindricalJoint{}"
    end
  end
})

function CylindricalJoint.new(rotation_limit, translation_limit)
  Object.assert_type(rotation_limit, RotationLimit, true)
  Object.assert_type(translation_limit, TranslationLimit, true)

  return Object.instance({
    rotation_limit = rotation_limit,
    translation_limit = translation_limit,
    dof = 2
  }, CylindricalJoint)
end

return CylindricalJoint
