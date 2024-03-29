rockspec_format = "3.0"
package = "ardumatic"
version = "dev-1"
source = {
  url = "https://harton.dev/james/ardumatic"
}
description = {
  homepage = "https://harton.dev/james/ardumatic",
  license = "HL3-FULL <https://firstdonoharm.dev/version/3/0/full.html/>"
}
build = {
  type = "builtin",
  modules = {
    ["ardupilot.vector3f"] = "src/ardupilot/vector3f.lua",
    ["chain.link_state"] = "src/chain/link_state.lua",
    ["angle"] = "src/angle.lua",
    ["body"] = "src/body.lua",
    ["chain"] = "src/chain.lua",
    ["fabrik"] = "src/fabrik.lua",
    ["joint"] = "src/joint.lua",
    ["link"] = "src/link.lua",
    ["mat3"] = "src/mat3.lua",
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
