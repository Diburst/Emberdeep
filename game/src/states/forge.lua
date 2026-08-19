-- Brassa's forge: spend scrap on permanent upgrades.
--  * individual weapons (tier 1 -> 3)
--  * Lu's shield dome (cheaper energy drain per tier)
--  * max health, gated by LIFE CAPSULE cores found in the world
--  * energy capacity, gated by ENERGY TANK cells found in the world
local P = require "src.assets.palette"
local Menu = require "src.ui.menu"
local Weapons = require "src.weapons"
-- Every price and every benefit lives in src/upgrades.lua. Nothing in
-- this file may hard-code a number the player can feel.
local Up = require "src.upgrades"

local S = { name = "forge", translucent = true }

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
        if tier >= Up.MAX.weapon then return def.name .. "  Lv" .. Up.MAX.weapon .. " (MAX)" end
        return def.name .. "  Lv" .. tier .. " > Lv" .. (tier + 1)
          .. "   " .. Up.cost("weapon", tier + 1) .. " scrap"
      end,
      onConfirm = function()
        local tier = f[id] or 1
        if tier >= Up.MAX.weapon then return end
        if pay(Up.cost("weapon", tier + 1)) then
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
      if tier >= Up.MAX.dome then return "LU'S SHIELD DOME  Lv" .. Up.MAX.dome .. " (MAX)" end
      return "LU'S SHIELD DOME  Lv" .. tier .. " > Lv" .. (tier + 1)
        .. "   " .. Up.cost("dome", tier + 1) .. " scrap"
    end,
    onConfirm = function()
      local tier = f.dome or 1
      if tier >= Up.MAX.dome then return end
      if pay(Up.cost("dome", tier + 1)) then
        f.dome = tier + 1
        G.game:announce("Shield dome reinforced to Lv" .. f.dome .. "!", 2)
      end
    end,
    hint = "The dome drains far less energy per hit it soaks.",
  }

  items[#items + 1] = {
    label = function()
      local tier = f.hpTier or 0
      if tier >= Up.MAX.hp then return "MAX HEALTH  +" .. (tier * Up.HP_PER_TIER) .. " (MAX)" end
      local gated = (G.run.capsules or 0) <= tier
      local tag = gated and "  [needs a LIFE CAPSULE core]"
        or ("   " .. Up.cost("hp", tier + 1) .. " scrap")
      return "MAX HEALTH  +" .. tier * Up.HP_PER_TIER .. " > +"
        .. (tier + 1) * Up.HP_PER_TIER .. tag
    end,
    onConfirm = function()
      local tier = f.hpTier or 0
      if tier >= Up.MAX.hp then return end
      if (G.run.capsules or 0) <= tier then
        G.game:announce("Brassa needs another LIFE CAPSULE core to work with.", 2.5)
        if G.Audio then G.Audio.sfx("menuback") end
        return
      end
      if pay(Up.cost("hp", tier + 1)) then
        f.hpTier = tier + 1
        for i = 1, 2 do
          G.run.players[i].maxhp = Up.maxHp(f.hpTier)
        end
        local World = require "src.world"
        for _, pl in ipairs(World.players or {}) do
          pl.maxhp = G.run.players[pl.idx].maxhp
          pl.hp = pl.maxhp
        end
        G.game:announce("Chassis reinforced! Max HP +" .. Up.HP_PER_TIER
          .. " for both bots.", 2.5)
      end
    end,
    hint = "Each LIFE CAPSULE you find unlocks the next tier.",
  }

  items[#items + 1] = {
    label = function()
      local tier = f.energyTier or 0
      if tier >= Up.MAX.energy then return "LU'S ENERGY CELLS  (MAX)" end
      local gated = (G.run.tanks or 0) <= tier
      local tag = gated and "  [needs an ENERGY TANK cell]"
        or ("   " .. Up.cost("energy", tier + 1) .. " scrap")
      return "LU'S ENERGY CELLS  " .. Up.maxEnergy(tier) .. " > "
        .. Up.maxEnergy(tier + 1) .. tag
    end,
    onConfirm = function()
      local tier = f.energyTier or 0
      if tier >= Up.MAX.energy then return end
      if (G.run.tanks or 0) <= tier then
        G.game:announce("Brassa needs another ENERGY TANK cell to work with.", 2.5)
        if G.Audio then G.Audio.sfx("menuback") end
        return
      end
      if pay(Up.cost("energy", tier + 1)) then
        f.energyTier = tier + 1
        G.run.players[2].maxenergy = Up.maxEnergy(f.energyTier)
        local World = require "src.world"
        for _, pl in ipairs(World.players or {}) do
          if not pl.isVess then
            pl.maxenergy = G.run.players[2].maxenergy
            pl.energy = pl.maxenergy
          end
        end
        G.game:announce("Energy cells expanded! Lu's max energy +"
          .. Up.EN_PER_TIER .. ".", 2.5)
      end
    end,
    hint = "Each ENERGY TANK you find unlocks the next tier.",
  }

  -- LU'S REPAIR PULSE. The most expensive line in the forge, deliberately:
  -- a party heal on a short cooldown is the strongest thing scrap can
  -- buy, so it has to compete with two whole weapon trees rather than
  -- being picked up on the way past.
  items[#items + 1] = {
    label = function()
      local tier = f.repairPulse or 1
      local r = Up.repair(tier)
      if tier >= Up.MAX.repairPulse then
        return "LU'S REPAIR PULSE  Lv" .. tier .. " (MAX)  heals " .. r.heal
      end
      local nx = Up.repair(tier + 1)
      return "LU'S REPAIR PULSE  " .. r.heal .. " > " .. nx.heal .. " hp   "
        .. Up.cost("repairPulse", tier + 1) .. " scrap"
    end,
    onConfirm = function()
      local tier = f.repairPulse or 1
      if tier >= Up.MAX.repairPulse then return end
      if pay(Up.cost("repairPulse", tier + 1)) then
        f.repairPulse = tier + 1
        local r = Up.repair(f.repairPulse)
        G.game:announce("Repair pulse tuned! " .. r.heal .. " hp, "
          .. r.cost .. " energy.", 2.5)
      end
    end,
    hint = "Heals both bots at once. Bigger, cheaper, and faster to recharge.",
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
