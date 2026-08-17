-- Pause menu overlay.
local P = require "src.assets.palette"
local Menu = require "src.ui.menu"
local Items = require "src.items"

local S = { name = "pause", translucent = true }

function S:enter()
  local game = G.game
  local items = {
    { label = "RESUME", onConfirm = function() G.State.pop() end },
    { label = "MAP", onConfirm = function()
      G.State.pop()
      G.State.push(require "src.states.mapscreen")
    end },
    { label = "LOG", onConfirm = function()
      G.State.pop()
      G.State.push(require "src.states.log")
    end,
      hint = "Everything anyone has said to you, and everything the deep announced." },
    { label = "OPTIONS", onConfirm = function()
      G.State.push(require "src.states.options")
    end },
  }
  if G.settings.testmode then
    items[#items + 1] = { label = "PROGRESS (TEST)", onConfirm = function()
      G.State.pop()
      G.State.push(require "src.states.progress")
    end,
      hint = "Also on F1. What can you reach right now? Is the run completable?" }
    items[#items + 1] = { label = "WARP (TEST)", onConfirm = function()
      G.State.pop()
      G.State.push(require "src.states.warp")
    end,
      hint = "Jump to any room. For when a gate is somewhere awkward and you do not fancy the walk." }
  end
  local more = {
    { label = function()
      return game.coop and "PLAYER 2: DROP OUT"
        or G.fmtButtons("PLAYER 2: JOIN (or press [PAUSE2])")
    end,
      onConfirm = function()
        if game.coop then game:dropOut() else game:dropIn() end
        G.State.pop()
      end },
    G.run.testChamber and {
      label = "EXIT TEST (TO TITLE)", onConfirm = function()
        if G.Audio then G.Audio.stopMusic() end
        G.State.switch(require "src.states.title")
      end,
      hint = "Test chamber runs are never saved.",
    } or {
      label = "SAVE + QUIT TO TITLE", onConfirm = function()
        game:syncRun()
        G.Save.writeSlot(G.run.slot, G.run)
        if G.Audio then G.Audio.stopMusic() end
        G.State.switch(require "src.states.title")
      end,
      hint = "Progress is saved to your slot. Resume any time.",
    },
  }
  for _, it in ipairs(more) do items[#items + 1] = it end
  self.list = Menu.new(items, { y = 96, spacing = 16 })
end

function S:menu(action)
  if action == "cancel" or action == "start" then
    G.State.pop()
    if G.Audio then G.Audio.sfx("menuback") end
    return
  end
  self.list:menuEvent(action)
end

function S:update(dt)
  for slot = 1, 2 do
    if G.Input.pressed(slot, "pause") then
      G.State.pop()
      return
    end
  end
end

function S:draw()
  local g = love.graphics
  g.setColor(P.black[1], P.black[2], P.black[3], 0.82)
  g.rectangle("fill", 0, 0, G.VW, G.VH)
  g.setFont(G.fonts.main)
  g.setColor(P.ember)
  g.printf("PAUSED", 0, 60, G.VW, "center")

  self.list:draw()

  -- status readout
  local y = 190
  g.setColor(P.slate)
  g.printf("MODULES", 0, y, G.VW, "center")
  local mods = {}
  for _, id in ipairs({ "sparkjump", "grapple", "hydroseals", "heatplating", "telenet" }) do
    if G.run.flags[id] then mods[#mods + 1] = Items.MODULES[id].name end
  end
  local keys = 0
  for i = 1, 3 do if G.run.flags["corekey" .. i] then keys = keys + 1 end end
  g.setColor(P.cyan)
  g.printf(#mods > 0 and table.concat(mods, "  .  ") or "none yet", 20, y + 11, G.VW - 40, "center")
  g.setColor(P.gold)
  g.printf(string.format("CORE KEYS: %d/3     LIFE CAPSULES: %d     SCRAP: %d",
    keys, G.run.capsules or 0, G.run.scrap or 0), 0, y + 30, G.VW, "center")
  g.setColor(P.slate)
  g.printf("playtime " .. require("src.core.util").formatTime(G.run.playtime or 0)
    .. "   .   " .. ({ "STORY", "NORMAL", "VETERAN" })[G.run.difficulty], 0, y + 44, G.VW, "center")
  g.setColor(1, 1, 1, 1)
end

return S
