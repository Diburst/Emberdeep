-- In-game map: visited rooms drawn as boxes, zone-colored, with markers.
local P = require "src.assets.palette"

local S = { name = "mapscreen", translucent = true }

local CELL = 10 -- pixels per map grid cell

function S:enter()
  self.WM = require "src.data.worldmap"
end

function S:menu(action)
  if action == "cancel" or action == "backbtn" or action == "start" or action == "confirm" then
    G.State.pop()
    if G.Audio then G.Audio.sfx("menuback") end
  end
end

function S:update(dt)
  for slot = 1, 2 do
    if G.Input.pressed(slot, "map") or G.Input.pressed(slot, "pause")
      or G.Input.pressed(slot, "special") then
      G.State.pop()
      if G.Audio then G.Audio.sfx("menuback") end
      return
    end
  end
end

function S:draw()
  local g = love.graphics
  local WM = self.WM
  g.setColor(P.black[1], P.black[2], P.black[3], 0.92)
  g.rectangle("fill", 0, 0, G.VW, G.VH)
  g.setFont(G.fonts.main)
  g.setColor(P.ember)
  g.printf("MAP OF THE DEEP", 0, 8, G.VW, "center")

  local World = require "src.world"
  local currentRoom = World.room and World.room.id

  for _, id in ipairs(WM.ROOMS) do
    local ok, def = pcall(World.getRoomDef, id)
    if ok and def and def.mapPos then
      local zoneOff = WM.ZONE_OFFSETS[def.zone]
      if zoneOff and (G.run.visited[id] or G.DEBUG) then
        local mp = def.mapPos
        local x = 24 + (zoneOff.x + mp.x) * CELL
        local y = 24 + (zoneOff.y + mp.y) * CELL
        local w = (mp.w or 1) * CELL - 1
        local h = (mp.h or 1) * CELL - 1
        local accent = P.zoneAccent[def.zone] or P.slate
        g.setColor(accent[1] * 0.35, accent[2] * 0.35, accent[3] * 0.35, 1)
        g.rectangle("fill", x, y, w, h)
        g.setColor(accent[1], accent[2], accent[3], 0.9)
        g.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
        -- markers
        if def.hasSave then
          g.setColor(P.gold)
          g.rectangle("fill", x + 2, y + 2, 2, 2)
        end
        if def.hasTeleporter and G.run.flags.telenet then
          g.setColor(P.cyan)
          g.rectangle("fill", x + w - 4, y + 2, 2, 2)
        end
        if id == currentRoom then
          local blink = math.floor(G.time * 3) % 2 == 0
          if blink then
            g.setColor(P.white)
            g.rectangle("fill", x + w / 2 - 2, y + h / 2 - 2, 4, 4)
          end
        end
      end
    end
  end

  -- zone labels for zones with any visited room
  for zone, off in pairs(self.WM.ZONE_OFFSETS) do
    local any = false
    for _, id in ipairs(WM.ROOMS) do
      local ok, def = pcall(World.getRoomDef, id)
      if ok and def and def.zone == zone and G.run.visited[id] then any = true break end
    end
    if any then
      local accent = P.zoneAccent[zone] or P.slate
      g.setColor(accent[1], accent[2], accent[3], 0.8)
      g.print(WM.ZONE_NAMES[zone] or zone, 24 + off.x * CELL, 24 + off.y * CELL - 10)
    end
  end

  g.setColor(P.slate)
  g.printf("gold dot: save   cyan dot: teleporter   you are the blinking square",
    0, G.VH - 22, G.VW, "center")
  g.printf(G.fmtButtons("[CANCEL] / [MAP]: close"), 0, G.VH - 12, G.VW, "center")
  g.setColor(1, 1, 1, 1)
end

return S
