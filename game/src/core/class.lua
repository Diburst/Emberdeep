-- Minimal single-inheritance class system.
local function newclass(parent)
  local c = {}
  c.__index = c
  c.super = parent
  if parent then
    setmetatable(c, { __index = parent })
  end
  c.new = function(...)
    local obj = setmetatable({}, c)
    if obj.init then obj:init(...) end
    return obj
  end
  c.extend = function()
    return newclass(c)
  end
  return c
end

return newclass
