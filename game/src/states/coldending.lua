-- THE COLD ACCOUNTING: the easter-egg bad ending. Take the Ember before
-- you understand what it is, and the game shows you exactly what that
-- costs -- then refuses to keep it. Reloads the last save; nothing is
-- ever written to disk on this path.
local P = require "src.assets.palette"

local S = { name = "coldending" }

local CARDS = {
  { "The Ember came loose like a tooth.",
    "The lanterns of Ember Camp went out all at once --",
    "and the cold walked in like it had been waiting",
    "a century for the invitation." },
  { "They did not run. There was nowhere warm enough",
    "to run to.",
    "", "Maro. Brassa. Sol. Jun. Root. Inks. Pell. Nima.",
    "Tikka." },
  { "The Deep did not need the Ember returned.",
    "It needed it returned by someone who understood",
    "what it cost.",
    "", "You understood nothing." },
  { "THE COLD ACCOUNTING",
    "", "The deep refuses this ending. It reaches back for",
    "the last moment the world was still warm..." },
}

function S:enter(prev, coop)
  self.coop = coop or (G.game and G.game.coop)
  self.card = 1
  self.t = 0
  if G.Audio then G.Audio.stopMusic() end
end

function S:update(dt)
  self.t = self.t + dt
end

function S:finish()
  -- reload the last save; this timeline never happened
  local slot, coop = G.run and G.run.slot, self.coop
  local data = slot and G.Save.readSlot(slot)
  if data then
    G.run = data
    G.run.slot = slot
    G.State.switch(require "src.states.game", { coop = coop })
  else
    G.State.switch(require "src.states.title")
  end
end

function S:menu(action)
  if action == "confirm" or action == "start" then
    if self.t < 0.8 then return end
    self.card = self.card + 1
    self.t = 0
    if G.Audio then G.Audio.sfx("talk") end
    if self.card > #CARDS then self:finish() end
  end
end

function S:draw()
  local g = love.graphics
  g.clear(0.03, 0.05, 0.09)
  g.setFont(G.fonts.main)
  local lines = CARDS[self.card]
  if not lines then return end
  local y = 88
  for i, line in ipairs(lines) do
    local lineAlpha = math.min(1, math.max(0, self.t * 2 - i * 0.4))
    if self.card == #CARDS and i == 1 then
      g.setColor(P.ice[1], P.ice[2], P.ice[3], lineAlpha)
    else
      g.setColor(P.silver[1], P.silver[2], P.silver[3], lineAlpha)
    end
    g.printf(line, 40, y, G.SW - 80, "center")
    y = y + 14
  end
  -- falling frost
  for i = 1, 24 do
    local fx = (i * 83 + G.time * (8 + i % 5 * 4)) % G.SW
    local fy = (i * 47 + G.time * (14 + i % 3 * 6)) % G.SH
    g.setColor(P.ice[1], P.ice[2], P.ice[3], 0.25)
    g.rectangle("fill", fx, fy, 1, 1)
  end
  g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.5)
  g.printf(G.fmtButtons("[CONFIRM]: continue"), 0, G.SH - 18, G.SW, "center")
  g.setColor(1, 1, 1, 1)
end

return S
