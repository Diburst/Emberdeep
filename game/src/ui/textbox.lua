-- Cave Story-style dialogue textbox with portraits, typewriter text,
-- and yes/no choices.
local class = require "src.core.class"
local P = require "src.assets.palette"
local U = require "src.core.util"

local NAMES = {
  vess = "VESS", lu = "LU", elder = "Elder Maro", brassa = "Brassa",
  tikka = "Tikka", jun = "Jun", sol = "Doc Sol", inks = "Inks",
  root = "Root", vill = "Pell", vill2 = "Nima", sys = "",
  mender = "The Mender", ferro = "Ferro", mote = "Mote",
  lock = "Curator Lock", archivist = "The Archivist",
}
local PORT_COLOR = {
  vess = "vessred", lu = "lublue", elder = "violet", brassa = "ember",
  tikka = "leaf", jun = "cyan", sol = "light", inks = "sky", root = "brown",
  vill = "slate", vill2 = "orchid", mender = "blood",
  ferro = "gold", mote = "spark", lock = "ice", archivist = "ice",
}

local Textbox = class()
Textbox.NAMES = NAMES
Textbox.PORT_COLOR = PORT_COLOR

-- the run's dialogue log: everything the player has been told
local function logLine(who, text)
  if not G.run then return end
  G.run.log = G.run.log or {}
  local L = G.run.log
  local last = L[#L]
  if last and last.who == (who or "") and last.text == text then return end
  L[#L + 1] = { who = who or "", text = text }
  if #L > 250 then table.remove(L, 1) end
end
Textbox.logLine = logLine

-- script: list of entries:
--  { who="elder", text="..." }
--  { set="flagname" } / { give="scrap:10" } / { fn=function() end }
--  { choice="Take the job?", yes={...}, no={...} }
function Textbox:init(script)
  self.script = script
  self.i = 0
  self.done = false
  self.charT = 0
  self.chars = 0
  self.entry = nil
  self.choiceSel = 1
  self.inChoice = false
  self:nextEntry()
end

function Textbox:nextEntry()
  self.i = self.i + 1
  local e = self.script[self.i]
  if not e then
    self.done = true
    return
  end
  -- side-effect entries
  if e.set then
    G.run.flags[e.set] = e.value == nil and true or e.value
    return self:nextEntry()
  end
  if e.give then
    local Items = require "src.items"
    local World = require "src.world"
    Items.grant(e.give, World.players[1])
    return self:nextEntry()
  end
  if e.fn then
    e.fn()
    return self:nextEntry()
  end
  if e.choice then
    self.entry = e
    self.inChoice = true
    self.choiceSel = 1
    self.chars = #e.choice
    return
  end
  self.entry = e
  self.text = G.fmtButtons(e.text or "")
  logLine(e.who, self.text)
  self.chars = 0
  self.charT = 0
  self.inChoice = false
end

function Textbox:update(dt)
  if self.done or not self.entry then return end
  -- advance on any player's jump/fire/interact press
  for slot = 1, 2 do
    if G.Input.pressed(slot, "jump") or G.Input.pressed(slot, "fire")
      or G.Input.pressed(slot, "interact") then
      self:advance()
      return
    end
  end
  if self.inChoice then
    -- navigate with any player's input
    for slot = 1, 2 do
      if G.Input.pressed(slot, "up") or G.Input.pressed(slot, "down") then
        self.choiceSel = self.choiceSel == 1 and 2 or 1
        if G.Audio then G.Audio.sfx("menumove") end
      end
    end
    return
  end
  local full = #(self.text or "")
  if self.chars < full then
    self.charT = self.charT + dt * 45
    local newChars = math.floor(self.charT)
    if newChars > self.chars then
      self.chars = math.min(full, newChars)
      if self.chars % 3 == 0 and G.Audio then G.Audio.sfx("talk") end
    end
  end
end

function Textbox:advance()
  if self.done or not self.entry then return end
  if self.inChoice then
    local e = self.entry
    if G.Audio then G.Audio.sfx("menusel") end
    local branch = self.choiceSel == 1 and e.yes or e.no
    if branch then
      -- splice branch into script after current position
      for j = #branch, 1, -1 do
        table.insert(self.script, self.i + 1, branch[j])
      end
    end
    self:nextEntry()
    return
  end
  local full = #(self.text or "")
  if self.chars < full then
    self.chars = full
    self.charT = full
  else
    self:nextEntry()
  end
end

function Textbox:draw()
  if self.done or not self.entry then return end
  local g = love.graphics
  local font = G.fonts.main
  g.setFont(font)

  local bx, bh = 20, 62
  local by = G.SH - bh - 8
  local bw = G.SW - 40
  g.setColor(P.black[1], P.black[2], P.black[3], 0.92)
  g.rectangle("fill", bx, by, bw, bh, 4, 4)
  g.setColor(P.slate)
  g.rectangle("line", bx + 1, by + 1, bw - 2, bh - 2, 4, 4)

  local who = self.entry.who
  local tx = bx + 10
  if who and who ~= "sys" then
    -- portrait
    local px, py = bx + 8, by + 8
    local pcol = P[PORT_COLOR[who] or "slate"]
    if G.spriteExists("port_" .. who) then
      g.setColor(P.dark)
      g.rectangle("fill", px - 2, py - 2, 24, 24)
      G.drawSprite("port_" .. who, 1, px + 10, py + 20, {})
      g.setColor(pcol)
      g.rectangle("line", px - 2, py - 2, 24, 24)
    else
      g.setColor(pcol)
      g.rectangle("fill", px, py, 20, 20)
    end
    tx = bx + 40
    -- name
    g.setColor(pcol)
    g.print(NAMES[who] or who, tx, by + 6)
  end

  if self.inChoice then
    g.setColor(P.cream)
    g.print(self.entry.choice, tx, by + 8)
    local opts = { self.entry.yesLabel or "Yes", self.entry.noLabel or "No" }
    for i, o in ipairs(opts) do
      local oy = by + 24 + (i - 1) * 13
      if self.choiceSel == i then
        g.setColor(P.gold)
        g.print(">", tx + 2, oy)
      end
      g.setColor(self.choiceSel == i and P.white or P.silver)
      g.print(o, tx + 12, oy)
    end
  else
    local text = (self.text or ""):sub(1, self.chars)
    g.setColor(P.light)
    g.printf(text, tx, by + (who and who ~= "sys" and 17 or 10), bw - (tx - bx) - 12)
    -- advance arrow
    if self.chars >= #(self.text or "") and math.floor(G.time * 2.5) % 2 == 0 then
      g.setColor(P.gold)
      g.polygon("fill", bx + bw - 14, by + bh - 10, bx + bw - 8, by + bh - 10,
        bx + bw - 11, by + bh - 6)
    end
  end
  g.setColor(1, 1, 1, 1)
end

return Textbox
