-- Brassa's forge: spend scrap on permanent upgrades.
--  * individual weapons (tier 1 -> 3)
--  * Lu's shield dome (cheaper energy drain per tier)
--  * max health, gated by LIFE CAPSULE cores found in the world
--  * energy capacity, gated by ENERGY TANK cells found in the world
local P = require "src.assets.palette"
local Menu = require "src.ui.menu"
local Weapons = require "src.weapons"

local S = { name = "forge", translucent = true }

local WEAPON_COST = { nil, 25, 60 }   -- cost to REACH tier 2 / 3
local DOME_COST = { nil, 30, 70 }
local HP_MAX_TIER = 8
local EN_MAX_TIER = 4
local function hpCost(tier) return 15 + (tier - 1) * 10 end
local function enCost(tier) return 20 + (tier - 1) * 15 end

local function pay(cost)
  if G.run.scrap < cost then
    if G.Audio then G.Audio.sfx("menuback") end
    G.game:announce("Not enough scrap (need " .. cost .. ").", 2)
    return false
  end
  G.run.scrap = G.run.scrap - cost
  if G.Audio then G.Audio.sfx("chest") end
  return true
end

local function ownedWeapons()
  local out = {}
  for _, pd in ipairs(G.run.players) do
    for _, ws in ipairs(pd.weapons or {}) do
      out[#out + 1] = ws.id
    end
  end
  return out
end

function S:enter()
  self:rebuild()
end

function S:rebuild()
  local f = Weapons.forge()
  local items = {}

  for _, id in ipairs(ownedWeapons()) do
    local def = Weapons.get(id)
    items[#items + 1] = {
      label = function()
        local tier = f[id] or 1
        if tier >= 3 then return def.name .. "  Lv3 (MAX)" end
        return def.name .. "  Lv" .. tier .. " > Lv" .. (tier + 1)
          .. "   " .. WEAPON_COST[tier + 1] .. " scrap"
      end,
      onConfirm = function()
        local tier = f[id] or 1
        if tier >= 3 then return end
        if pay(WEAPON_COST[tier + 1]) then
          f[id] = tier + 1
          G.game:announce(def.name .. " forged to Lv" .. f[id] .. "!", 2)
        end
      end,
      hint = "Stronger shots for this weapon.",
    }
  end

  items[#items + 1] = {
    label = function()
      local tier = f.dome or 1
      if tier >= 3 then return "LU'S SHIELD DOME  Lv3 (MAX)" end
      return "LU'S SHIELD DOME  Lv" .. tier .. " > Lv" .. (tier + 1)
        .. "   " .. DOME_COST[tier + 1] .. " scrap"
    end,
    onConfirm = function()
      local tier = f.dome or 1
      if tier >= 3 then return end
      if pay(DOME_COST[tier + 1]) then
        f.dome = tier + 1
        G.game:announce("Shield dome reinforced to Lv" .. f.dome .. "!", 2)
      end
    end,
    hint = "The dome drains far less energy per hit it soaks.",
  }

  items[#items + 1] = {
    label = function()
      local tier = f.hpTier or 0
      if tier >= HP_MAX_TIER then return "MAX HEALTH  +" .. (tier * 4) .. " (MAX)" end
      local gated = (G.run.capsules or 0) <= tier
      local tag = gated and "  [needs a LIFE CAPSULE core]"
        or ("   " .. hpCost(tier + 1) .. " scrap")
      return "MAX HEALTH  +" .. tier * 4 .. " > +" .. (tier + 1) * 4 .. tag
    end,
    onConfirm = function()
      local tier = f.hpTier or 0
      if tier >= HP_MAX_TIER then return end
      if (G.run.capsules or 0) <= tier then
        G.game:announce("Brassa needs another LIFE CAPSULE core to work with.", 2.5)
        if G.Audio then G.Audio.sfx("menuback") end
        return
      end
      if pay(hpCost(tier + 1)) then
        f.hpTier = tier + 1
        for i = 1, 2 do
          G.run.players[i].maxhp = G.run.players[i].maxhp + 4
        end
        local World = require "src.world"
        for _, pl in ipairs(World.players or {}) do
          pl.maxhp = G.run.players[pl.idx].maxhp
          pl.hp = pl.maxhp
        end
        G.game:announce("Chassis reinforced! Max HP +4 for both bots.", 2.5)
      end
    end,
    hint = "Each LIFE CAPSULE you find unlocks the next tier.",
  }

  items[#items + 1] = {
    label = function()
      local tier = f.energyTier or 0
      if tier >= EN_MAX_TIER then return "LU'S ENERGY CELLS  (MAX)" end
      local gated = (G.run.tanks or 0) <= tier
      local tag = gated and "  [needs an ENERGY TANK cell]"
        or ("   " .. enCost(tier + 1) .. " scrap")
      return "LU'S ENERGY CELLS  " .. (100 + tier * 20) .. " > "
        .. (100 + (tier + 1) * 20) .. tag
    end,
    onConfirm = function()
      local tier = f.energyTier or 0
      if tier >= EN_MAX_TIER then return end
      if (G.run.tanks or 0) <= tier then
        G.game:announce("Brassa needs another ENERGY TANK cell to work with.", 2.5)
        if G.Audio then G.Audio.sfx("menuback") end
        return
      end
      if pay(enCost(tier + 1)) then
        f.energyTier = tier + 1
        G.run.players[2].maxenergy = (G.run.players[2].maxenergy or 100) + 20
        local World = require "src.world"
        for _, pl in ipairs(World.players or {}) do
          if not pl.isVess then
            pl.maxenergy = G.run.players[2].maxenergy
            pl.energy = pl.maxenergy
          end
        end
        G.game:announce("Energy cells expanded! Lu's max energy +20.", 2.5)
      end
    end,
    hint = "Each ENERGY TANK you find unlocks the next tier.",
  }

  items[#items + 1] = { label = "LEAVE THE FORGE", onConfirm = function()
    G.State.pop()
  end }
  self.list = Menu.new(items, { y = 78, spacing = 15 })
end

function S:menu(action)
  if action == "cancel" or action == "start" then
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
  g.setColor(P.ember)
  g.printf("BRASSA'S FORGE", 0, 42, G.VW, "center")
  g.setColor(P.gold)
  g.printf("SCRAP: " .. (G.run.scrap or 0), 0, 56, G.VW, "center")
  g.setColor(P.slate)
  g.printf("cores found: " .. (G.run.capsules or 0)
    .. " capsule / " .. (G.run.tanks or 0) .. " tank",
    0, G.VH - 14, G.VW, "center")
  self.list:draw()
  g.setColor(1, 1, 1, 1)
end

return S
