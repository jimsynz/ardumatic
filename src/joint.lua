local Object = require("object")
local CylindricalJoint = require("joint.cylindrical")
local PrismaticJoint = require("joint.prismatic")
local RevoluteJoint = require("joint.revolute")
local Joint = Object.new("Joint")

function Joint.cylindrical(rotation_limit, translation_limit)
  local joint = CylindricalJoint.new(rotation_limit, translation_limit)
  return Object.instance({_joint = joint}, Joint)
end

function Joint.prismatic(translation_limit)
  local joint = PrismaticJoint.new(translation_limit)
  return Object.instance({_joint = joint}, Joint)
end

function Joint.revolute(rotation_limit)
  local joint = RevoluteJoint.new(rotation_limit)
  return Object.instance({_joint = joint}, Joint)
end

function Joint.coerce_type(joint)
  if Object.check_type(joint, Joint) then
    return joint

  elseif Object.check_type(joint, CylindricalJoint) then
    return Object.instance({_joint = joint}, Joint)

  elseif Object.check_type(joint, PrismaticJoint) then
    return Object.instance({_joint = joint}, Joint)

  elseif Object.check_type(joint, RevoluteJoint) then
    return Object.instance({_joint = joint}, Joint)

  else
    return nil, "Argument is not a type of Joint"
  end
end

function Joint:dof()
  return self._joint.dof
end

-- Just here to make life easier for myself.
function Joint:length()
  return 0
end

return Joint
