-- Teleporter destination picker.
local P = require "src.assets.palette"
local Menu = require "src.ui.menu"

local S = { name = "teleport", translucent = true }

function S:enter(prev, fromId)
  local WM = require "src.data.worldmap"
  self.fromId = fromId
  local items = {}
  for _, pad in ipairs(WM.TELEPADS) do
    if G.run.flags["tp_" .. pad.id] and pad.id ~= fromId then
      items[#items + 1] = {
        label = pad.label,
        onConfirm = function() self:go(pad) end,
      }
    end
  end
  if #items == 0 then
    items[#items + 1] = { label = "(no other pads discovered yet)", disabled = true }
  end
  items[#items + 1] = { label = "CANCEL", onConfirm = function() G.State.pop() end }
  self.list = Menu.new(items, { y = 100, spacing = 15 })
end

function S:go(pad)
  if G.Audio then G.Audio.sfx("teleport") end
  local game = G.game
  G.State.pop()
  game.fadeDir = 1
  game.fadeCb = function()
    local World = require "src.world"
    World:load(pad.room, nil, true)
    -- arrive standing on the destination pad itself
    local dest
    World:each("teleporter", function(t)
      if t.id == pad.id then dest = t end
    end)
    if dest then
      for i, p in ipairs(World.players) do
        p.x = dest.x + 6 + (i - 1) * 12
        p.y = dest.y + dest.h - p.h - 0.5
        p.vx, p.vy = 0, 0
        p.roomEnterProtect = 0.3
      end
      require("src.camera").jumpTo(dest.x + 12, dest.y)
      World:fx("burst", dest.x + 12, dest.y + 8, { color = "cyan", n = 12 })
    end
    -- A PAD IS TRANSPORT, NOT A SAVE.
    --
    -- It used to move the checkpoint and write the slot, which made the
    -- whole pad network a save network -- exactly the thing that got
    -- taken off the pause menu. Progress banks at a lantern you walked
    -- to, and nowhere else.
    --
    -- Moving the checkpoint WITHOUT writing would have been worse than
    -- either: death re-reads the slot, so the pad's respawn point would
    -- be silently thrown away the moment it mattered. So it does
    -- neither, and the pad you arrive at is a way back to the lantern
    -- rather than a substitute for it.
  end
end

function S:menu(action)
  if action == "cancel" then
    G.State.pop()
    if G.Audio then G.Audio.sfx("menuback") end
    return
  end
  self.list:menuEvent(action)
end

function S:draw()
  local g = love.graphics
  g.setColor(P.black[1], P.black[2], P.black[3], 0.85)
  g.rectangle("fill", 0, 0, G.SW, G.SH)
  g.setFont(G.fonts.main)
  g.setColor(P.cyan)
  g.printf("TELEPORT WHERE?", 0, 70, G.SW, "center")
  self.list:draw()
  g.setColor(1, 1, 1, 1)
end

return S
