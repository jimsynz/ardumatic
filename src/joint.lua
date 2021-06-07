local Object = require("object")
local CylindricalJoint = require("joint.cylindrical")
local Frame = require("frame")
local PrismaticJoint = require("joint.prismatic")
local RevoluteJoint = require("joint.revolute")
local Joint = Object.new("Joint")

function Joint.cylindrical(frame, rotation_limit, translation_limit)
  Object.assert_type(frame, Frame)
  local joint = CylindricalJoint.new(rotation_limit, translation_limit)
  return Object.instance({_joint = joint, _frame = frame}, Joint)
end

function Joint.prismatic(frame, translation_limit)
  Object.assert_type(frame, Frame)
  local joint = PrismaticJoint.new(translation_limit)
  return Object.instance({_joint = joint, _frame = frame}, Joint)
end

function Joint.revolute(frame, rotation_limit)
  Object.assert_type(frame, Frame)
  local joint = RevoluteJoint.new(rotation_limit)
  return Object.instance({_joint = joint, _frame = frame}, Joint)
end

function Joint:dof()
  return self._joint.dof
end

-- Just here to make life easier for myself.
function Joint:length()
  return 0
end

return Joint
