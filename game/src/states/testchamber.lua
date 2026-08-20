-- Test Chamber: dev/playtest mode reachable from the title screen.
-- Pick a player setup (bots, difficulty, weapons, tiers, abilities), a
-- boss, and an arena -- then drop straight into the fight. Runs are
-- ephemeral: no save slot is ever written.
local P = require "src.assets.palette"
local U = require "src.core.util"
local Menu = require "src.ui.menu"

local S = { name = "testchamber", translucent = true }

local BOSSES = {
  { id = "bramblemaw",    name = "BRAMBLE MAW",    arena = "moss_boss" },
  { id = "rustwarden",    name = "RUSTED WARDEN",  arena = "flood_warden" },
  { id = "tideengine",    name = "TIDE ENGINE",    arena = "flood_boss" },
  { id = "slaggolem",     name = "SLAG GOLEM",     arena = "furn_golem" },
  { id = "crucible",      name = "THE CRUCIBLE",   arena = "furn_boss" },
  { id = "prismtyrant",   name = "THE CONDUCTOR",  arena = "crys_boss" },
  { id = "aeriesentinel", name = "AERIE SENTINEL", arena = "sky_boss" },
  { id = "mycelchoir",    name = "THE MYCEL CHOIR", arena = "ug_boss" },
  { id = "archivist",     name = "THE ARCHIVIST",  arena = "cold_boss" },
  { id = "motherengine",  name = "MOTHER ENGINE",  arena = "core_boss" },
  { id = nil,             name = "NONE (roam)",    arena = "test_arena" },
}

local ARENAS = {
  "MATCH BOSS", "moss_boss", "flood_warden", "flood_boss", "furn_golem",
  "furn_boss", "crys_boss", "sky_boss", "ug_boss", "cold_boss", "core_boss",
  "test_arena",
}

-- ------------------------------------------------------------------
-- MODULES
--
-- Built from Items.MODULES, never listed by hand. The hand-written list
-- that used to live here had gone stale in the worst possible way: it
-- was missing BULWARK and DRIFT VANES, so the chamber could drop you
-- into the Conductor's arena -- where the reflector panels answer only
-- to a plated charge and the outer emitters are up a thermal column --
-- with no way to switch either on, and therefore no way to win.
--
-- Deriving the list means the failure mode is now impossible: a module
-- marked `ability = true` appears here the moment it exists, and one
-- that forgets the mark fails tools/testchamber_test.lua.
-- ------------------------------------------------------------------
local Items = require "src.items"
local Up = require "src.upgrades"

local MODULES = {}
for id, def in pairs(Items.MODULES) do
  if def.ability then
    MODULES[#MODULES + 1] = { id = id, name = def.short or def.name }
  end
end
table.sort(MODULES, function(a, b) return a.name < b.name end)

-- Presets, so the common cases stay one keypress. ALL is computed, not
-- enumerated, which is the whole point.
local PRESETS = {
  { name = "ALL", has = function() return true end },
  { name = "NONE", has = function() return false end },
  { name = "MOBILITY", has = function(id)
      return id == "sparkjump" or id == "grapple" or id == "driftvanes"
    end },
  { name = "CRYSTAL ZONE", has = function(id)
      -- exactly what the Hollows and the Conductor require
      return id == "sparkjump" or id == "grapple" or id == "bulwark"
        or id == "driftvanes"
    end },
}

-- The LINK BLAST is not a module -- Maro grants it in camp -- but it is
-- the verb half this game's bosses are built around, and the Crucible is
-- its exam: nothing else on earth opens that lattice. Its own row.
local LINK_STATES = { { name = "ON", on = true }, { name = "OFF", on = false } }

-- persistent between visits within one app session
local cfg = {
  coop = false, difficulty = 2,
  boss = 2,            -- default: Rusted Warden
  arena = 1,           -- MATCH BOSS
  scatterhex = true, arclance = true, pulsebloom = true,
  weaponTier = 2, domeTier = 2, repairTier = 1, hpTier = 2, energyTier = 1,
  preset = 1, link = 1,
  mods = {},           -- id -> true; filled from the ALL preset below
}

local function applyPreset(i)
  cfg.preset = i
  for _, m in ipairs(MODULES) do
    cfg.mods[m.id] = PRESETS[i].has(m.id) or nil
  end
end
applyPreset(1)

local function cycle(v, lo, hi, dir) -- wraps
  v = v + dir
  if v < lo then v = hi elseif v > hi then v = lo end
  return v
end

local function optRow(label, get, set, hint)
  return {
    label = function() return label .. "  < " .. get() .. " >" end,
    onLeft = function() set(-1) end,
    onRight = function() set(1) end,
    onConfirm = function() set(1) end,
    hint = hint,
  }
end

function S:enter()
  local items = {
    optRow("BOTS", function() return cfg.coop and "CO-OP (2P)" or "SOLO (1P)" end,
      function() cfg.coop = not cfg.coop end,
      "Solo: LB swaps bots, hold LB recalls"),
    optRow("DIFFICULTY",
      function() return ({ "STORY", "NORMAL", "VETERAN" })[cfg.difficulty] end,
      function(d) cfg.difficulty = U.clamp(cfg.difficulty + d, 1, 3) end),
    optRow("BOSS", function() return BOSSES[cfg.boss].name end,
      function(d) cfg.boss = cycle(cfg.boss, 1, #BOSSES, d) end,
      "NONE = just roam the arena"),
    optRow("ARENA", function()
        local a = ARENAS[cfg.arena]
        if a == "MATCH BOSS" then
          return "MATCH BOSS (" .. BOSSES[cfg.boss].arena .. ")"
        end
        return a
      end,
      function(d) cfg.arena = cycle(cfg.arena, 1, #ARENAS, d) end,
      "Any boss can be fought in any arena"),
    optRow("VESS: SCATTER HEX", function() return cfg.scatterhex and "ON" or "OFF" end,
      function() cfg.scatterhex = not cfg.scatterhex end),
    optRow("VESS: ARC LANCE", function() return cfg.arclance and "ON" or "OFF" end,
      function() cfg.arclance = not cfg.arclance end),
    optRow("LU: PULSE BLOOM", function() return cfg.pulsebloom and "ON" or "OFF" end,
      function() cfg.pulsebloom = not cfg.pulsebloom end,
      "Bolt Driver and Spark Shot are always equipped"),
    optRow("WEAPON TIER", function() return "Lv" .. cfg.weaponTier end,
      function(d) cfg.weaponTier = U.clamp(cfg.weaponTier + d, 1, 3) end,
      "Forge level applied to every equipped weapon"),
    optRow("DOME TIER", function() return "Lv" .. cfg.domeTier end,
      function(d) cfg.domeTier = U.clamp(cfg.domeTier + d, 1, Up.MAX.dome) end),
    optRow("LU: REPAIR PULSE", function()
        return "Lv" .. cfg.repairTier .. "  (" .. Up.repair(cfg.repairTier).heal .. " hp)"
      end,
      function(d)
        cfg.repairTier = U.clamp(cfg.repairTier + d, 1, Up.MAX.repairPulse)
      end),
    optRow("HP TIER", function()
        return cfg.hpTier .. "  (" .. Up.maxHp(cfg.hpTier) .. " hp)"
      end,
      function(d) cfg.hpTier = U.clamp(cfg.hpTier + d, 0, Up.MAX.hp) end),
    optRow("ENERGY TIER", function()
        return cfg.energyTier .. "  (" .. Up.maxEnergy(cfg.energyTier) .. " en)"
      end,
      function(d) cfg.energyTier = U.clamp(cfg.energyTier + d, 0, Up.MAX.energy) end),
    optRow("LINK BLAST", function() return LINK_STATES[cfg.link].name end,
      function(d) cfg.link = cycle(cfg.link, 1, #LINK_STATES, d) end,
      "The Crucible's lattice opens to nothing else"),
    optRow("MODULE PRESET", function() return PRESETS[cfg.preset].name end,
      function(d)
        applyPreset(cycle(cfg.preset, 1, #PRESETS, d))
      end,
      "CRYSTAL ZONE = spark jump, grapple, bulwark, drift vanes"),
  }
  -- one row per ability module, generated
  for _, m in ipairs(MODULES) do
    items[#items + 1] = optRow("  " .. m.name,
      function() return cfg.mods[m.id] and "ON" or "OFF" end,
      function() cfg.mods[m.id] = (not cfg.mods[m.id]) or nil end,
      Items.MODULES[m.id].desc)
  end
  items[#items + 1] = { label = "ENTER THE CHAMBER", onConfirm = function() S:launch() end }
  items[#items + 1] = { label = "BACK", onConfirm = function() G.State.pop() end }
  self.list = Menu.new(items, { y = 44, spacing = 11, maxVisible = 16 })
end

function S:launch()
  local bossDef = BOSSES[cfg.boss]
  local arena = ARENAS[cfg.arena]
  if arena == "MATCH BOSS" then arena = bossDef.arena end

  local run = G.Save.newRun(nil, cfg.difficulty, cfg.coop)
  run.slot = nil            -- ephemeral: autosave is disabled without a slot
  run.testChamber = true
  run.room, run.door = arena, "A"
  run.checkpoint = { room = arena, door = "A" }

  -- gear
  local v, l = run.players[1], run.players[2]
  if cfg.scatterhex then
    v.weapons[#v.weapons + 1] = { id = "scatterhex", xp = 0 }
    run.flags.weapon_scatterhex = true
  end
  if cfg.arclance then
    v.weapons[#v.weapons + 1] = { id = "arclance", xp = 0 }
    run.flags.weapon_arclance = true
  end
  if cfg.pulsebloom then
    l.weapons[#l.weapons + 1] = { id = "pulsebloom", xp = 0 }
    run.flags.weapon_pulsebloom = true
  end
  local wt = cfg.weaponTier
  run.forge = {
    boltdriver = wt, scatterhex = wt, arclance = wt,
    sparkshot = wt, pulsebloom = wt,
    dome = cfg.domeTier, repairPulse = cfg.repairTier,
    hpTier = cfg.hpTier, energyTier = cfg.energyTier,
  }
  for _, pd in ipairs(run.players) do
    pd.maxhp = Up.maxHp(cfg.hpTier)
    pd.hp = pd.maxhp
  end
  l.maxenergy = Up.maxEnergy(cfg.energyTier)

  -- abilities
  for _, m in ipairs(MODULES) do
    if cfg.mods[m.id] then run.flags[m.id] = true end
  end
  run.flags.linkblast = LINK_STATES[cfg.link].on or nil

  G.run = run
  if G.Audio then G.Audio.sfx("teleport") end
  G.State.switch(require "src.states.game",
    { coop = cfg.coop, testBoss = bossDef.id, testBossRoom = arena })
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
  g.setColor(P.black[1], P.black[2], P.black[3], 0.92)
  g.rectangle("fill", 0, 0, G.SW, G.SH)
  g.setFont(G.fonts.main)
  g.setColor(P.spark)
  g.printf("TEST CHAMBER", 0, 22, G.SW, "center")
  g.setColor(P.slate)
  g.printf("weapons - bosses - mechanics", 0, 32, G.SW, "center")
  self.list:draw()
  g.setColor(1, 1, 1, 1)
end

S.cfg = cfg
S.BOSSES = BOSSES
S.ARENAS = ARENAS
S.MODULES = MODULES
S.PRESETS = PRESETS

return S
