-- ==================================================================
-- WHAT YOU JUST PICKED UP
-- ==================================================================
-- A new ability used to arrive as a 4.5-second announcement sliding
-- across the top of the screen while the room carried on around it --
-- so the one moment the game explains a verb was also the moment you
-- were least able to read. Every module in this game changes how you
-- move or fight, and none of them are re-explained anywhere.
--
-- So it stops. The world freezes underneath, dims, and the text sits in
-- the middle until you press something.
local P = require "src.assets.palette"

local S = {}
-- draw the frozen room underneath, then dim it
S.translucent = true

function S:enter(prev, info)
  self.title = (info and info.title) or "ACQUIRED"
  self.body = (info and info.body) or ""
  self.t = 0
  self.ready = false
  if G.Audio then G.Audio.sfx("capsule") end
end

function S:update(dt)
  self.t = self.t + dt
  -- a short beat before input counts, or the button that opened the
  -- chest closes the panel in the same frame and nobody reads anything
  if self.t > 0.35 then self.ready = true end
end

-- ANY button, from either bot, and any key. This is a "read this and
-- carry on" panel, not a menu, so it should not care which one.
function S:pressed(player, action)
  if self.ready then G.State.pop() end
end

function S:keypressed(key)
  if self.ready then G.State.pop() end
end

function S:draw()
  local g = love.graphics
  -- the room, dimmed rather than replaced: you can still see where you
  -- are standing, which matters when the panel closes
  g.setColor(0, 0, 0, 0.72)
  g.rectangle("fill", 0, 0, G.VW, G.VH)

  local w = 300
  local x = (G.VW - w) / 2
  g.setFont(G.fonts.main)
  local _, lines = G.fonts.main:getWrap(self.body, w - 24)
  local bodyH = #lines * 10
  local h = 54 + bodyH
  local y = (G.VH - h) / 2

  g.setColor(P.dark[1], P.dark[2], P.dark[3], 0.95)
  g.rectangle("fill", x, y, w, h, 4, 4)
  g.setColor(P.gold[1], P.gold[2], P.gold[3], 0.9)
  g.rectangle("line", x, y, w, h, 4, 4)

  g.setColor(P.gold)
  g.printf(self.title, x, y + 12, w, "center")
  g.setColor(P.cream)
  g.printf(self.body, x + 12, y + 30, w - 24, "center")

  if self.ready then
    local a = 0.5 + math.sin(G.time * 5) * 0.35
    g.setColor(P.cream[1], P.cream[2], P.cream[3], a)
    g.printf("press any key", x, y + h - 16, w, "center")
  end
  g.setColor(1, 1, 1, 1)
end

return S
