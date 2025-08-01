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
    ["gait.gait_generator"] = "src/gait/gait_generator.lua",
    ["gait.gait_state"] = "src/gait/gait_state.lua",
    ["gait.gait_transition"] = "src/gait/gait_transition.lua",
    ["gait.leg_trajectory"] = "src/gait/leg_trajectory.lua",
    ["gait.stability_analyzer"] = "src/gait/stability_analyzer.lua",
    ["gait.patterns.dynamic_gaits"] = "src/gait/patterns/dynamic_gaits.lua",
    ["gait.patterns.gait_pattern"] = "src/gait/patterns/gait_pattern.lua",
    ["gait.patterns.static_gaits"] = "src/gait/patterns/static_gaits.lua",
    ["angle"] = "src/angle.lua",
    ["body"] = "src/body.lua",
    ["chain"] = "src/chain.lua",
    ["config_validator"] = "src/config_validator.lua",
    ["fabrik"] = "src/fabrik.lua",
    ["frame"] = "src/frame.lua",
    ["joint"] = "src/joint.lua",
    ["link"] = "src/link.lua",
    ["mat3"] = "src/mat3.lua",
    ["object"] = "src/object.lua",
    ["robot_builder"] = "src/robot_builder.lua",
    ["robot_config"] = "src/robot_config.lua",
    ["scalar"] = "src/scalar.lua",
    ["servo_mapper"] = "src/servo_mapper.lua",
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
