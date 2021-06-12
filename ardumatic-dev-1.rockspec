rockspec_format = "3.0"
package = "ardumatic"
version = "dev-1"
source = {
  url = "https://gitlab.com/jimsy/ardumatic"
}
description = {
  homepage = "https://gitlab.com/jimsy/ardumatic",
  license = "Hippocratic <https://firstdonoharm.dev/version/2/1/license/>"
}
build = {
  type = "builtin",
  modules = {
    ["angle"] = "src/angle.lua",
    ["body"] = "src/body.lua",
    ["body.limb"] = "src/body/limb.lua",
    ["ardupilot.vector3f"] = "src/ardupilot/vector3f.lua",
    ["joint"] = "src/joint.lua",
    ["link"] = "src/link.lua",
    ["object"] = "src/object.lua",
    ["scalar"] = "src/scalar.lua",
    ["vec3"] = "src/vec3.lua",
  }
}
test_dependencies = {
  "busted-htest"
}
dependencies = {
  "luacheck"
}
test = {
  type = "busted"
}
