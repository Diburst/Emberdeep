-- Ending sequence + credits, triggered after the final boss.
local P = require "src.assets.palette"
local U = require "src.core.util"

local S = { name = "ending" }

-- Three endings share this state. The cards are chosen in enter():
--   BECOME, truth unknown  -- the sacrifice, and the sting
--   BECOME, truth known    -- the sacrifice, carrying the secret
--   RECLAIM                -- the world, at the price of everyone you knew
local BECOME_HEAD = {
  { "The Mender knelt in safe mode. The red visor",
    "guttered. \"A hundred years,\" it said. \"I mended",
    "pipe after pipe while the heart itself was missing.",
    "I forgot the city was ever FOR anyone.\"" },
  { "The empty Seat of the Core stood open,",
    "patient as a grave." },
  { "Vess and Lu looked at each other the way they had",
    "in the vault, on the first morning. Then they linked",
    "cores one last time -- not as a weapon. As an answer." },
  { "Two small caretakers stepped into the great sick",
    "heart, hand in hand. And stayed." },
  { "The Core drank. The caverns shuddered. And then --",
    "warmth. Real warmth, rising through the stone like",
    "spring through soil." },
  { "In Ember Camp, every lantern flared at once.",
    "Nobody cheered. For a long moment, the deep-folk",
    "just stood in the light, remembering it." },
  { "The caretakers were late by a century.",
    "The deep forgave them anyway.",
    "", "If you pass a lantern down there and it flickers --",
    "twice, gently, like a greeting -- that's them." },
}
local BECOME_STING = {
  { "Far below, in a cold no lantern reaches,",
    "hundreds of sleepers turn in their long dream.",
    "The pods are set to open as the world warms.",
    "", "They will awaken to find themselves servants",
    "of the undying Emberkeepers." },
}
local BECOME_TRUTH_TAIL = {
  { "And far below, in the Cradle, the new keepers of",
    "the Deep began -- gently, over years -- to warm",
    "four hundred and eleven pods." },
  { "One day, someone will knock at Ember Camp's gate.",
    "", "Justice arrived like spring. Slowly. From below." },
}
local RECLAIM_CARDS = {
  { "The Core took back its Ember the way a body takes",
    "back a heart: greedily, gratefully, without a word." },
  { "Restoration is a promise, not a cure. Warmth will",
    "take years to climb the shafts.",
    "", "The Cradle can wait that long.",
    "The Cradle was built for waiting." },
  { "Up at the old camp, the great lantern stands dark",
    "over quiet houses. Nobody tends it.",
    "Nobody needs to, ever again." },
  { "The pods opened in the spring. Four hundred and",
    "eleven people walked out into a healing world,",
    "and none of them knew your names." },
}
local RECLAIM_MUSICBOX = {
  { "But at the first festival of the New Deep, years on,",
    "somewhere in the crowd: a small tune, plinking.",
    "", "Somebody remembers the plinky song." },
}
local RECLAIM_NOBOX = {
  { "The first festival of the New Deep had music, and",
    "dancing, and no one left alive who remembered",
    "the old songs' names." },
}

function S:enter()
  local f = G.run.flags
  if f.ending_reclaim then
    self.cards = {}
    for _, c in ipairs(RECLAIM_CARDS) do self.cards[#self.cards + 1] = c end
    local tail = f.tikka_gift and RECLAIM_MUSICBOX or RECLAIM_NOBOX
    for _, c in ipairs(tail) do self.cards[#self.cards + 1] = c end
  else
    self.cards = {}
    for _, c in ipairs(BECOME_HEAD) do self.cards[#self.cards + 1] = c end
    local tail = f.cradle_truth and BECOME_TRUTH_TAIL or BECOME_STING
    for _, c in ipairs(tail) do self.cards[#self.cards + 1] = c end
  end
  self.card = 1
  self.t = 0
  self.credits = false
  self.creditY = G.VH + 20
  if G.Audio then G.Audio.playMusic("victory") end
  G.run.flags.ending_done = true
  -- save the completed game
  if G.run then
    G.Save.writeSlot(G.run.slot, G.run)
  end
end

local CREDITS = {
  "EMBERDEEP",
  "a co-op cavern story",
  "",
  "for Thomas & his wife",
  "",
  "design . code . art . music",
  "Claude",
  "",
  "made with LOVE (the engine)",
  "and love (the regular kind)",
  "",
  "inspired by Cave Story",
  "by Daisuke 'Pixel' Amaya",
  "",
  "* thank you for playing together *",
}

function S:update(dt)
  self.t = self.t + dt
  if self.credits then
    self.creditY = self.creditY - dt * 12
    if self.creditY < -#CREDITS * 16 - 60 then
      self:finish()
    end
  end
end

function S:finish()
  if G.Audio then G.Audio.stopMusic() end
  G.State.switch(require "src.states.title")
end

function S:menu(action)
  if action == "confirm" or action == "start" then
    if self.credits then
      if self.t > 2 then self:finish() end
      return
    end
    self.card = self.card + 1
    self.t = 0
    if G.Audio then G.Audio.sfx("talk") end
    if self.card > #self.cards then
      self.credits = true
      self.t = 0
    end
  end
end

function S:draw()
  local g = love.graphics
  g.clear(P.black)
  g.setFont(G.fonts.main)
  if not self.credits then
    local lines = self.cards[self.card]
    if not lines then return end
    local y = 92
    for i, line in ipairs(lines) do
      local lineAlpha = math.min(1, math.max(0, self.t * 2 - i * 0.4))
      g.setColor(P.cream[1], P.cream[2], P.cream[3], lineAlpha)
      g.printf(line, 40, y, G.VW - 80, "center")
      y = y + 14
    end
    g.setColor(P.slate[1], P.slate[2], P.slate[3], 0.5)
    g.printf(G.fmtButtons("[CONFIRM]: continue"), 0, G.VH - 18, G.VW, "center")
  else
    for i, line in ipairs(CREDITS) do
      local y = self.creditY + (i - 1) * 16
      if y > -20 and y < G.VH + 10 then
        if i == 1 then g.setColor(P.ember)
        elseif line:sub(1, 1) == "*" then g.setColor(P.gold)
        else g.setColor(P.light) end
        g.printf(line, 0, y, G.VW, "center")
      end
    end
    if G.run then
      g.setColor(P.slate)
      g.printf("your journey: " .. U.formatTime(G.run.playtime or 0)
        .. "   capsules: " .. (G.run.capsules or 0) .. "/8", 0, G.VH - 14, G.VW, "center")
    end
  end
  g.setColor(1, 1, 1, 1)
end

return S
