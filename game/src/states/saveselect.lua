-- Save slot selection -> (new game: difficulty + player count) -> game.
local P = require "src.assets.palette"
local U = require "src.core.util"
local Menu = require "src.ui.menu"

local S = { name = "saveselect" }

local DIFF_NAMES = { "STORY", "NORMAL", "VETERAN" }

function S:enter()
  self.mode = "slots" -- slots | confirm-delete | newgame | players
  self.slotInfo = {}
  for i = 1, 3 do
    self.slotInfo[i] = G.Save.readSlot(i)
  end
  self.sel = 1
  self.newDifficulty = 2
  self.pendingSlot = nil
  self:buildMenu()
end

function S:buildMenu()
  local items = {}
  for i = 1, 3 do
    local info = self.slotInfo[i]
    items[#items + 1] = {
      label = function()
        if self.slotInfo[i] then
          local d = self.slotInfo[i]
          local zone = "Ember Camp"
          local ok, roomDef = pcall(function()
            return require("src.world").getRoomDef(d.room)
          end)
          if ok and roomDef then
            zone = ({ camp = "Ember Camp", mosswood = "Mosswood",
              flooded = "Flooded Works", furnace = "Furnace Depths",
              crystal = "Crystal Hollows", skyroot = "Skyroot Spire",
              core = "The Core" })[roomDef.zone] or roomDef.zone
          end
          return string.format("SLOT %d  %s  %s  %s", i,
            U.formatTime(d.playtime or 0), zone,
            DIFF_NAMES[d.difficulty or 2])
        end
        return "SLOT " .. i .. "  - empty -"
      end,
      onConfirm = function() self:pickSlot(i) end,
      hint = self.slotInfo[i] and G.fmtButtons("[CONFIRM]: continue    [ALT]: erase")
        or G.fmtButtons("[CONFIRM]: new game"),
    }
  end
  items[#items + 1] = { label = "BACK", onConfirm = function()
    G.State.switch(require "src.states.title")
  end }
  self.list = Menu.new(items, { y = 120, spacing = 18 })
end

function S:pickSlot(i)
  self.pendingSlot = i
  if self.slotInfo[i] then
    -- continue existing
    G.run = self.slotInfo[i]
    G.run.slot = i
    self.mode = "players"
    self:buildPlayersMenu()
  else
    self.mode = "newgame"
    self:buildNewGameMenu()
  end
end

function S:buildNewGameMenu()
  self.list = Menu.new({
    { label = function() return "< " .. DIFF_NAMES[self.newDifficulty] .. " >" end,
      onLeft = function() self.newDifficulty = math.max(1, self.newDifficulty - 1) end,
      onRight = function() self.newDifficulty = math.min(3, self.newDifficulty + 1) end,
      onConfirm = function()
        G.run = G.Save.newRun(self.pendingSlot, self.newDifficulty, false)
        self.mode = "players"
        self:buildPlayersMenu()
      end,
      hint = ({ "Gentler enemies, no weapon energy loss, long revive timers",
        "The intended Emberdeep experience",
        "Tougher enemies, short revive timers. For duo veterans" })[self.newDifficulty],
    },
    { label = "BACK", onConfirm = function()
      self.mode = "slots"
      self:buildMenu()
    end },
  }, { y = 140, spacing = 18 })
end

function S:buildPlayersMenu()
  self.list = Menu.new({
    { label = "1 PLAYER  (swap between both bots)",
      onConfirm = function() self:startGame(false) end },
    { label = "2 PLAYERS  (pad 1 = Vess, pad 2 = Lu)",
      onConfirm = function() self:startGame(true) end,
      hint = (G.Input.pads[2] == nil and G.Input.pads[1] == nil)
        and "No pads detected - keyboard: P1 WASD+JKL, P2 arrows+numpad"
        or (G.Input.pads[2] == nil and "Only one pad found - P2 can use keyboard (arrows+numpad)" or nil) },
    { label = "BACK", onConfirm = function()
      self.mode = "slots"
      self:buildMenu()
    end },
  }, { y = 140, spacing = 18 })
end

function S:startGame(coop)
  local isNew = self.slotInfo[self.pendingSlot] == nil
  G.run.coop = coop
  if isNew then
    G.Save.writeSlot(self.pendingSlot, G.run)
    G.State.switch(require "src.states.intro", coop)
  else
    G.State.switch(require "src.states.game", { coop = coop })
  end
end

function S:menu(action, ev)
  if action == "cancel" then
    if self.mode == "slots" then
      G.State.switch(require "src.states.title")
    else
      self.mode = "slots"
      self:buildMenu()
    end
    if G.Audio then G.Audio.sfx("menuback") end
    return
  end
  if action == "alt" and self.mode == "slots" then
    -- erase
    local i = self.list.sel
    if i <= 3 and self.slotInfo[i] then
      if self.confirmErase == i then
        G.Save.deleteSlot(i)
        self.slotInfo[i] = nil
        self.confirmErase = nil
        if G.Audio then G.Audio.sfx("break") end
      else
        self.confirmErase = i
        if G.Audio then G.Audio.sfx("deny") end
      end
    end
    return
  end
  self.confirmErase = nil
  self.list:menuEvent(action)
end

function S:update(dt) end

function S:draw()
  local g = love.graphics
  g.clear(P.black)
  g.setFont(G.fonts.main)
  g.setColor(P.ember)
  local title = self.mode == "slots" and "SELECT SAVE"
    or self.mode == "newgame" and "DIFFICULTY"
    or "HOW MANY PLAYERS?"
  g.printf(title, 0, 70, G.SW, "center")
  if self.confirmErase then
    g.setColor(P.blood)
    g.printf(G.fmtButtons("Press [ALT] again to erase slot ") .. self.confirmErase .. "!", 0, 90, G.SW, "center")
  end
  self.list:draw()
  g.setColor(P.slate)
  g.printf(G.fmtButtons("[CONFIRM]: select   [CANCEL]: back"), 0, G.SH - 12, G.SW, "center")
  g.setColor(1, 1, 1, 1)
end

return S
