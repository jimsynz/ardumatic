local Object = require( "object")
local Limb = Object.new("Limb")

function Limb.new(offset, chain)
  return Object.instance({
    offset = offset,
    chain = chain
  }, Limb)
end

function Limb:end_location()
  return self.offset + self.chain:end_location()
end

return Limb
