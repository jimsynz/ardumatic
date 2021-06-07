local Object = require("object")
local Body = require("body")
local Frame = require("frame")
local Joint = require("joint")
local Chain = Object.new("Chain")

-- Each chain has it's basis in the world's coordinate frame.
function Chain.new(frame)
  Object.assert_type(frame, Frame)

  return Object.instance({
    _frame = frame,
    _chain = {}
  }, Chain)
end

function Chain:add(joint_or_body)
  local length = #self._chain

  if length == 0 then
    Object.assert_type(joint_or_body, Body)
    assert(joint_or_body, "Chain root must be a body")
    table.insert(self._chain, joint_or_body)

  elseif math.fmod(length, 2) == 0 then
    Object.assert_type(joint_or_body, Body)
    assert(joint_or_body, "Expected next item in chain to be a body")
    table.insert(self._chain, joint_or_body)

  else
    Object.assert_type(joint_or_body, Joint)
    assert(joint_or_body, "Expected next item in chain to be a joint")
    table.insert(self._chain, joint_or_body)
  end

  return self
end

function Chain:maximum_reach()
  local length = 0
  for _, part in ipairs(self._chain) do
    length = length + part:length()
  end
  return length
end


return Chain
