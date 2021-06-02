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
    ["quat"] = "src/quat.lua",
    ["vec3"] = "src/vec3.lua",
    ["ardupilot.vector2f"] = "src/ardupilot/vector2f.lua",
    ["ardupilot.vector3f"] = "src/ardupilot/vector3f.lua"
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
