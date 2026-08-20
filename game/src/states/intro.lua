-- Opening story cards, then into the game.
local P = require "src.assets.palette"

local S = { name = "intro" }

local CARDS = {
  { "Deep beneath the world there was a city,",
    "EMBERDEEP -- named for the ember at its heart.",
    "The Core warmed the caverns, lit the lanterns,",
    "and kept the dark at bay." },
  { "Then came the Long Dark. The Core sickened.",
    "The city sealed itself. The survivors built",
    "Ember Camp around the last warm lantern." },
  { "One hundred years later, in a small maintenance",
    "shop, two caretaker units boot up." },
  { "VESSEL-9: heavy chassis. Gunner. Stubborn.",
    "LUMEN-3: light chassis. Operator. Mobile.",
    "", "The deep is sick. You were built to mend it.",
    "Better late than never." },
}

function S:enter(prev, coop)
  self.coop = coop
  self.card = 1
  self.t = 0
end

function S:update(dt)
  self.t = self.t + dt
end

function S:advance()
  self.card = self.card + 1
  self.t = 0
  if G.Audio then G.Audio.sfx("talk") end
  if self.card > #CARDS then
    G.State.switch(require "src.states.game", { coop = self.coop })
  end
end

function S:menu(action)
  if action == "confirm" or action == "start" then self:advance() end
  if action == "cancel" then
    G.State.switch(require "src.states.game", { coop = self.coop })
  end
end

function S:draw()
  local g = love.graphics
  g.clear(P.black)
  g.setFont(G.fonts.main)
  local lines = CARDS[self.card]
  if not lines then return end
  local alpha = math.min(1, self.t * 2)
  local y = 90
  for i, line in ipairs(lines) do
    local lineAlpha = math.min(1, math.max(0, self.t * 2 - i * 0.4))
    g.setColor(P.light[1], P.light[2], P.light[3], lineAlpha)
    g.printf(line, 40, y, G.SW - 80, "center")
    y = y + 14
  end
  g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.6 + math.sin(G.time * 2) * 0.3)
  g.printf(G.fmtButtons("[CONFIRM]: continue    [CANCEL]: skip"), 0, G.SH - 20, G.SW, "center")
  g.setColor(1, 1, 1, 1)
end

return S
