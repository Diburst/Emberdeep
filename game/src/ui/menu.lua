-- Reusable vertical list menu.
-- items: { {label=string|fn, hint=, onConfirm=fn, onLeft=fn, onRight=fn,
--           disabled=fn|bool}, ... }
local class = require "src.core.class"
local P = require "src.assets.palette"

local Menu = class()

function Menu:init(items, opts)
  self.items = items
  self.sel = 1
  opts = opts or {}
  self.x = opts.x or G.VW / 2
  self.y = opts.y or 120
  self.spacing = opts.spacing or 14
  self.align = opts.align or "center"
  self.width = opts.width or 220
end

function Menu:labelOf(item)
  local l = item.label
  if type(l) == "function" then return l() end
  return l
end

function Menu:isDisabled(item)
  local d = item.disabled
  if type(d) == "function" then return d() end
  return d
end

function Menu:move(dir)
  local n = #self.items
  for _ = 1, n do
    self.sel = ((self.sel - 1 + dir) % n) + 1
    if not self:isDisabled(self.items[self.sel]) then break end
  end
  if G.Audio then G.Audio.sfx("menumove") end
end

-- returns true if handled
function Menu:menuEvent(action)
  local item = self.items[self.sel]
  if action == "up" then self:move(-1) return true end
  if action == "down" then self:move(1) return true end
  if action == "left" and item.onLeft then
    item.onLeft()
    if G.Audio then G.Audio.sfx("menumove") end
    return true
  end
  if action == "right" and item.onRight then
    item.onRight()
    if G.Audio then G.Audio.sfx("menumove") end
    return true
  end
  if action == "confirm" and item.onConfirm and not self:isDisabled(item) then
    if G.Audio then G.Audio.sfx("menusel") end
    item.onConfirm()
    return true
  end
  return false
end

function Menu:draw()
  local g = love.graphics
  g.setFont(G.fonts.main)
  for i, item in ipairs(self.items) do
    local y = self.y + (i - 1) * self.spacing
    local label = self:labelOf(item)
    local disabled = self:isDisabled(item)
    if i == self.sel then
      g.setColor(P.gold)
      local w = G.fonts.main:getWidth(label)
      if self.align == "center" then
        g.print(">", self.x - w / 2 - 12, y)
      else
        g.print(">", self.x - 12, y)
      end
    end
    g.setColor(disabled and P.gray or (i == self.sel and P.white or P.silver))
    if self.align == "center" then
      g.printf(label, 0, y, G.VW, "center")
    else
      g.print(label, self.x, y)
    end
    if i == self.sel and item.hint then
      g.setColor(P.slate)
      g.printf(item.hint, 30, G.VH - 24, G.VW - 60, "center")
    end
  end
  g.setColor(1, 1, 1, 1)
end

return Menu
