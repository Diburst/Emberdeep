-- Room warp (TEST MODE only): jump straight to any room in the world.
--
-- A playtest tool, not a game mechanic. Its whole reason to exist is that a
-- designer re-testing one fight should never have to re-walk six corridors
-- they cleared an hour ago -- and, when a gate or a sealed door turns out to
-- be somewhere awkward mid-playthrough, it is the way out that does not
-- involve editing a save file by hand.
--
-- Two levels so neither list runs off the bottom of a 270px screen: zone,
-- then room. Arriving sets a checkpoint, so the next autosave lands you
-- somewhere sane rather than back where you warped from.
local P = require "src.assets.palette"
local Menu = require "src.ui.menu"

local S = { name = "warp", translucent = true }

local ZONE_ORDER = {
  "camp", "mosswood", "undergrove", "flooded", "furnace", "scrapyard",
  "crystal", "skyroot", "coldstore", "cradle", "core",
}

local function byZone()
  local WM = require "src.data.worldmap"
  local World = require "src.world"
  local out = {}
  for _, id in ipairs(WM.ROOMS) do
    local ok, def = pcall(World.getRoomDef, id)
    if ok and def then
      local z = def.zone or "?"
      out[z] = out[z] or {}
      table.insert(out[z], id)
    end
  end
  return out
end

function S:enter()
  self.rooms = byZone()
  self:buildZones()
end

function S:buildZones()
  local WM = require "src.data.worldmap"
  self.title = "WARP TO WHICH ZONE?"
  local items = {}
  local seen = {}
  local function addZone(z)
    if seen[z] or not self.rooms[z] then return end
    seen[z] = true
    items[#items + 1] = {
      label = string.format("%-18s (%d)", WM.ZONE_NAMES[z] or z:upper(),
        #self.rooms[z]),
      onConfirm = function() self:buildRooms(z) end,
    }
  end
  for _, z in ipairs(ZONE_ORDER) do addZone(z) end
  for z in pairs(self.rooms) do addZone(z) end   -- anything not in the order
  items[#items + 1] = { label = "CANCEL", onConfirm = function() G.State.pop() end }
  self.list = Menu.new(items, { y = 58, spacing = 13 })
end

function S:buildRooms(z)
  local WM = require "src.data.worldmap"
  self.title = (WM.ZONE_NAMES[z] or z:upper()) .. " -- WARP WHERE?"
  local items = {}
  for _, id in ipairs(self.rooms[z]) do
    items[#items + 1] = {
      label = id,
      hint = "current room: " .. tostring(G.run.room),
      onConfirm = function() self:go(id) end,
    }
  end
  items[#items + 1] = { label = "< BACK", onConfirm = function() self:buildZones() end }
  self.list = Menu.new(items, { y = 58, spacing = 13 })
end

function S:go(id)
  local game = G.game
  if not game then G.State.pop() return end
  if G.Audio then G.Audio.sfx("warp") end
  G.State.pop()
  game.fadeDir = 1
  game.fadeCb = function()
    local World = require "src.world"
    World:load(id, "A", true)
    game:setCheckpoint(id, "A")
    game:announce("WARPED: " .. id, 1.6)
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
  g.setColor(P.black[1], P.black[2], P.black[3], 0.88)
  g.rectangle("fill", 0, 0, G.VW, G.VH)
  g.setFont(G.fonts.main)
  g.setColor(P.gold)
  g.printf(self.title or "WARP", 0, 34, G.VW, "center")
  g.setColor(P.slate)
  g.printf("test mode -- no fanfare, no ceremony", 0, 46, G.VW, "center")
  self.list:draw()
  g.setColor(1, 1, 1, 1)
end

return S
