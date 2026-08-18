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
  -- A scroll WINDOW, so a list can outgrow the screen without either
  -- clipping silently or forcing every caller to paginate by hand. Only
  -- maxVisible rows draw, and the window follows the selection.
  self.maxVisible = opts.maxVisible
  self.top = 1
end

-- keep the selection inside the visible window
function Menu:scrollTo()
  local n = self.maxVisible
  if not n or #self.items <= n then self.top = 1 return end
  if self.sel < self.top then self.top = self.sel end
  if self.sel > self.top + n - 1 then self.top = self.sel - n + 1 end
  self.top = math.max(1, math.min(self.top, #self.items - n + 1))
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
  self:scrollTo()
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
  local first, last = 1, #self.items
  if self.maxVisible and #self.items > self.maxVisible then
    self:scrollTo()
    first = self.top
    last = math.min(#self.items, self.top + self.maxVisible - 1)
    -- affordances, so a truncated list never looks like the whole list
    g.setColor(P.slate)
    if first > 1 then
      g.printf("^", 0, self.y - self.spacing, G.VW, "center")
    end
    if last < #self.items then
      g.printf("v", 0, self.y + (last - first + 1) * self.spacing, G.VW, "center")
    end
  end
  for i = first, last do
    local item = self.items[i]
    local y = self.y + (i - first) * self.spacing
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
