local string = require("string")
local Object = {}

local type_of = function(self, class)
  return self.class == class
end

function Object.new(name, table, mt)
  name = name or "Anonymous class"
  table = table or {}
  mt = mt or {}
  local metadata = {
    name = name,
    mt = mt,
    __tostring = function(self)
      return string.format("Class{name = %q, id = %p}", name, table)
    end
  }

  return setmetatable(table, metadata)
end

function Object.instance(table, class)
  local metadata = getmetatable(class)
  local mt = metadata.mt or {}
  local intertable = {
    type_of = type_of,
    class = class,
  }
  intertable = setmetatable(intertable, {__index = class})

  mt = mt or {}
  mt["__index"] = intertable

  return setmetatable(table, mt)
end

function Object.reader(name, attr_name)
  attr_name = attr_name or ("_" .. name)
  return function(self)
    return self[attr_name]
  end
end

function Object.writer(name, attr_name)
  attr_name = attr_name or ("_" .. name)
  return function(self, value)
    self[attr_name] = value
    return self
  end
end

function Object.accessor(name, attr_name)
  attr_name = attr_name or ("_" .. name)
  return function(self, value)
    if value then
      self[attr_name] = value
      return self
    else
      return self[attr_name]
    end
  end
end

function Object.check_type(value, class, allow_nil)
  if allow_nil and value == nil then
    return true
  elseif type(value) == "table" and value.class == class then
    return value
  elseif allow_nil then
    return nil, string.format("Expected value to be of type %s or nil, but got %s instead", class, value)
  else
    return nil, string.format("Expected value to be of type %s, but got %s instead", class, value)
  end
end

function Object.assert_type(value, class, allow_nil)
  assert(Object.check_type(value, class, allow_nil))
end

return Object
