local Object = require("object")
local RotationLimit = require("limit.rotation")
local RevoluteJoint

local generate_logical = function(operation)
  return function(self, other)
    Object.check_type(other, RevoluteJoint)

    return operation(self.rotation_limit, other.rotation_limit)
  end
end

RevoluteJoint = Object.new("Joint.Revolute", {}, {
  __eq = generate_logical(function(a, b) return a == b end),
  __lt = generate_logical(function(a, b) return a < b end),
  __le = generate_logical(function(a, b) return a <= b end),
  __tostring = function(self)
    if self.rotation_limit then
      return string.format("RevoluteJoint{rotation_limit=%s}", self.rotation_limit)

    else
      return "RevoluteJoint{}"
    end
  end
})

function RevoluteJoint.new(rotation_limit)
  Object.assert_type(rotation_limit, RotationLimit, true)

  return Object.instance({
    rotation_limit = rotation_limit,
    dof = 1
  }, RevoluteJoint)
end

return RevoluteJoint
