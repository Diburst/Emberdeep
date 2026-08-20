-- Options menu (reachable from title and pause).
local P = require "src.assets.palette"
local U = require "src.core.util"
local Menu = require "src.ui.menu"

local S = { name = "options", translucent = true }

local function volRow(label, key)
  return {
    label = function()
      local v = math.floor(G.settings[key] * 10 + 0.5)
      return string.format("%s  < %s >", label, string.rep("|", v) .. string.rep(".", 10 - v))
    end,
    onLeft = function()
      G.settings[key] = U.clamp(G.settings[key] - 0.1, 0, 1)
    end,
    onRight = function()
      G.settings[key] = U.clamp(G.settings[key] + 0.1, 0, 1)
      if key == "volSfx" and G.Audio then G.Audio.sfx("shard") end
    end,
  }
end

local function toggleRow(label, key)
  return {
    label = function()
      return label .. "  < " .. (G.settings[key] and "ON" or "OFF") .. " >"
    end,
    onLeft = function() G.settings[key] = not G.settings[key] end,
    onRight = function() G.settings[key] = not G.settings[key] end,
    onConfirm = function() G.settings[key] = not G.settings[key] end,
  }
end

function S:enter()
  local items = {
    volRow("MASTER VOLUME", "volMaster"),
    volRow("MUSIC VOLUME", "volMusic"),
    volRow("SFX VOLUME", "volSfx"),
    {
      label = function()
        return "DISPLAY  < " .. (G.settings.fullscreen and "FULLSCREEN"
          or ("WINDOW x" .. (G.settings.windowscale or 2))) .. " >"
      end,
      onLeft = function() self:cycleDisplay(-1) end,
      onRight = function() self:cycleDisplay(1) end,
      hint = "F11 also toggles fullscreen any time",
    },
    toggleRow("SCREEN SHAKE", "shake"),
    toggleRow("CONTROLLER RUMBLE", "rumble"),
    toggleRow("BRIGHT FLASHES", "flashes"),
    {
      label = function()
        return "TEST MODE  < " .. (G.settings.testmode and "ON" or "OFF") .. " >"
      end,
      onLeft = function() G.settings.testmode = not G.settings.testmode end,
      onRight = function() G.settings.testmode = not G.settings.testmode end,
      onConfirm = function() G.settings.testmode = not G.settings.testmode end,
      hint = "Play-testing tools: PROGRESS panel (F1) shows what is reachable",
    },
  }
  if G.run and G.game then
    items[#items + 1] = {
      label = function()
        return "DIFFICULTY (this save)  < " ..
          ({ "STORY", "NORMAL", "VETERAN" })[G.run.difficulty] .. " >"
      end,
      onLeft = function() G.run.difficulty = math.max(1, G.run.difficulty - 1) end,
      onRight = function() G.run.difficulty = math.min(3, G.run.difficulty + 1) end,
      hint = "Applies immediately. No shame, no bonus - just fun.",
    }
  end
  items[#items + 1] = { label = "CONTROLS...", onConfirm = function()
    G.State.push(require "src.states.controls")
  end }
  items[#items + 1] = { label = "BACK", onConfirm = function()
    G.Save.saveSettings()
    G.State.pop()
  end }
  self.list = Menu.new(items, { y = 74, spacing = 15 })
end

function S:cycleDisplay(dir)
  -- window x2 -> x3 -> x4 -> fullscreen -> window x2
  local modes = { "w2", "w3", "w4", "fs" }
  local cur = G.settings.fullscreen and 4 or (G.settings.windowscale or 2) - 1
  cur = ((cur - 1 + dir) % 4) + 1
  if modes[cur] == "fs" then
    G.settings.fullscreen = true
  else
    G.settings.fullscreen = false
    G.settings.windowscale = cur + 1
  end
  G.applyVideo()
end

function S:menu(action)
  if action == "cancel" then
    G.Save.saveSettings()
    G.State.pop()
    if G.Audio then G.Audio.sfx("menuback") end
    return
  end
  self.list:menuEvent(action)
end

function S:draw()
  local g = love.graphics
  g.setColor(P.black[1], P.black[2], P.black[3], 0.88)
  g.rectangle("fill", 0, 0, G.SW, G.SH)
  g.setFont(G.fonts.main)
  g.setColor(P.ember)
  g.printf("OPTIONS", 0, 46, G.SW, "center")
  self.list:draw()
  g.setColor(1, 1, 1, 1)
end

return S
