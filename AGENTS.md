# Agent Guidelines for Ardumatic

## Build/Test/Lint Commands
- **Run all tests**: `busted`
- **Run single test**: `busted spec/filename_spec.lua`
- **Lint code**: `luacheck src/` or `luacheck filename.lua`
- **Install dependencies**: `luarocks install --deps-only`

## Code Style & Conventions
- **Language**: Lua 5.1+ (ArduPilot compatible)
- **Imports**: Use `require()` at top of file, assign to local variables
- **Naming**: snake_case for functions/variables, PascalCase for classes/modules
- **Functions**: Public functions first, then private functions
- **Type checking**: Use `Object.assert_type()` for parameter validation
- **Error handling**: Use `assert()` for critical failures, return nil+error for recoverable errors
- **Comments**: Use `--[[]]` for multi-line, `--` for single-line documentation
- **Formatting**: 2-space indentation, no trailing whitespace

## Architecture Patterns
- **OOP**: Use `Object.new()` and `Object.instance()` for class creation
- **Modules**: Return module table at end of file
- **Testing**: Use Busted framework with `describe`/`it` structure
- **Dependencies**: ArduPilot Vector3f integration via wrapper pattern