local Object = require("object")
local Joint = require("joint")
local Link = require("link")
local Vec3 = require("vec3")

local LinkState = Object.new("Chain.LinkState")

function LinkState.new(joint, link, root_location, tip_location)
  Object.assert_type(joint, Joint)
  Object.assert_type(link, Link)
  Object.assert_type(root_location, Vec3)
  Object.assert_type(tip_location, Vec3)

  return Object.instance({
    joint = joint,
    link = link,
    root_location = root_location,
    tip_location = tip_location
  }, LinkState)
end

return LinkState
