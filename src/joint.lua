local Angle = require("angle")
local Object = require("object")
local Scalar = require("scalar")
local Vec3 = require("vec3")
local string = require("string")

local JointType = {
  BALL = 0,
  HINGE = 1
}

local MIN_CONSTRAINT = Angle.zero()
local MAX_CONSTRAINT = Angle.from_degrees(180)

local Joint = Object.new("Joint", {
  __tostring = function(self)
    if self._type == JointType.BALL then
      return string.format("Joint{type=BALL,clockwise_constraint=%s}", self._clockwise_constraint)
    else
      return string.format("Join{type=HINGE,anticlockwise_constraint=%s,clockwise_constraint=%s}", self._anticlockwise_constraint, self._clockwise_constraint)
    end
  end
})

local assert_valid_constraint = function(angle, allow_nil)
  if allow_nil and angle == nil then
    return true
  else
    assert(angle >= MIN_CONSTRAINT, string.format("Angle %s is smaller than the minimum constraint of %s", angle, MIN_CONSTRAINT))
    assert(angle <= MAX_CONSTRAINT, string.format("Angle %s is larger than the maximum constraint of %s", angle, MAX_CONSTRAINT))
    return true
  end
end

local assert_non_zero_vec = function(vec, allow_nil)
  if allow_nil and vec == nil then
    return true
  else
    assert(vec:length() > 0, "Vector has a zero length")
    return true
  end
end

--- Create a ball joint (ie. ball and socket).  A ball joint can deflect away
--  from the axis of the link it is attached to.  You can optionally provide an
--  angle which defines the maximum deflection.
--
-- @param reference_axis a non-zero Vec3 defining the initial direction of the
-- axis - relative to the joint's parent.
-- @param max_constraint an Angle describing a cone around the Joint's location.
-- Defaults to 180º.
function Joint.ball(reference_axis, max_constraint)
  Object.assert_type(reference_axis, Vec3)
  assert_non_zero_vec(reference_axis)
  Object.assert_type(max_constraint, Angle, true)
  assert_valid_constraint(max_constraint, true)

  return Object.instance({
    _type = JointType.BALL,
    _anticlockwise_constraint = MIN_CONSTRAINT,
    _clockwise_constraint = max_constraint or MAX_CONSTRAINT,
    _reference_axis = reference_axis:normalize()
  }, Joint)
end

--- Create a hinge joint.
-- A hinge joint defines a joint which can rotate around a specific axis
-- relative to the direction of the link it is attached to.
-- A local hinge in the human body would be analogous to elbow or knee joints,
-- which are constrained about the perpendicular axis of the arm or leg they're
-- attached to. However, unlike an elbow or knee joint, a local hinge may
-- rotate up to a maximum of 180 degrees in both clockwise and anti-clockwise
-- directions unless the clockwise_constraint or the anticlockwise_constraint
-- arguments have been set to lower values.
-- @param rotation_axis a non-zero length Vec3.
-- @param reference_axis a non-zero length Vec3. The initial axis around the
--   rotation_axis which we will enforce rotational constraints.
-- @param clockwise_constraint an Angle between 0 and 180º. Defaults to 180º
--   if not provided.
-- @param anticlockwise_constraint an Angle between 0 and 180º. Defaults to the
--   value of clockwise_constraint if not provided.
function Joint.hinge(rotation_axis, reference_axis, clockwise_constraint, anticlockwise_constraint)
  Object.assert_type(rotation_axis, Vec3)
  Object.assert_type(reference_axis, Vec3)
  assert_non_zero_vec(rotation_axis)
  assert_non_zero_vec(reference_axis)
  Object.assert_type(clockwise_constraint, Angle, true)
  assert_valid_constraint(clockwise_constraint, true)
  Object.assert_type(anticlockwise_constraint, Angle, true)
  assert_valid_constraint(anticlockwise_constraint, true)

  clockwise_constraint = clockwise_constraint or MAX_CONSTRAINT
  anticlockwise_constraint = anticlockwise_constraint or clockwise_constraint

  -- Ensure the reference axis falls within the plane of the rotation axis (i.e.
  -- they are perpendicular, so their dot product is zero)
  assert(rotation_axis:dot(reference_axis) < Scalar.FLOAT_EPSILON,
    "The reference axis must be in the plane of the rotation axis")

  return Object.instance({
    _type = JointType.HINGE,
    _anticlockwise_constraint = anticlockwise_constraint,
    _clockwise_constraint = clockwise_constraint,
    _rotation_axis = rotation_axis:normalize(),
    _reference_axis = reference_axis:normalize()
  }, Joint)
end

--- The maximum amount this joint is allowed to rotate anticlockwise.
-- For ball joints, this is always zero.
Joint.anticlockwise_constraint = Object.reader("anticlockwise_constraint")

--- The maximum this joint is allowed to rotate in the clockwise direction.
-- For ball joints this angle effectively constrains it to a cone around the
-- direction of the link it is attached to, starting at the attachment point.
-- For hinge joints, it defines the maximum deflection around the rotation axis
-- from the direction of the link it is attached to.  This is an absolute
-- value, so 180º means full rotation in either direction.
Joint.clockwise_constraint = Object.reader("clockwise_constraint")

Joint.JointType = JointType

--- The type of hinge.
-- Returns a value which can be compared with the JointType enum.
Joint.type = Object.reader("type")

--- The unit vector defining the joint's current direction.
function Joint:direction()
  return self._reference_axis
end

return Joint
