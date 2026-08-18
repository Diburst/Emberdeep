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

local ABILITY_SETS = {
  { name = "NONE", flags = {} },
  { name = "MOBILITY", flags = { "sparkjump", "grapple" } },
  { name = "ALL", flags = { "sparkjump", "grapple", "hydroseals",
                            "heatplating", "lumecore", "cryocoils", "telenet" } },
}

-- The LINK BLAST is not an "ability" in the ABILITY_SETS sense -- it is
-- the verb half this game's bosses are built around, and the Crucible is
-- its exam: nothing else on earth opens that lattice. It was in no set at
-- all, so the Test Chamber could drop you into a fight that could not be
-- won and gave you no way to switch it on. Its own row, defaulting ON.
local LINK_STATES = { { name = "ON", on = true }, { name = "OFF", on = false } }

-- persistent between visits within one app session
local cfg = {
  coop = false, difficulty = 2,
  boss = 2,            -- default: Rusted Warden
  arena = 1,           -- MATCH BOSS
  scatterhex = true, arclance = true, pulsebloom = true,
  weaponTier = 2, domeTier = 2, hpTier = 2, energyTier = 1,
  abilities = 3, link = 1,
}

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
      function(d) cfg.domeTier = U.clamp(cfg.domeTier + d, 1, 3) end),
    optRow("HP TIER", function()
        return cfg.hpTier .. "  (" .. (12 + cfg.hpTier * 4) .. " hp)"
      end,
      function(d) cfg.hpTier = U.clamp(cfg.hpTier + d, 0, 8) end),
    optRow("ENERGY TIER", function()
        return cfg.energyTier .. "  (" .. (100 + cfg.energyTier * 20) .. " en)"
      end,
      function(d) cfg.energyTier = U.clamp(cfg.energyTier + d, 0, 4) end),
    optRow("LINK BLAST", function() return LINK_STATES[cfg.link].name end,
      function(d) cfg.link = cycle(cfg.link, 1, #LINK_STATES, d) end,
      "The Crucible's lattice opens to nothing else"),
    optRow("ABILITIES", function() return ABILITY_SETS[cfg.abilities].name end,
      function(d) cfg.abilities = cycle(cfg.abilities, 1, #ABILITY_SETS, d) end,
      "MOBILITY = spark jump + grapple; ALL adds seals, plating, lume"),
    { label = "ENTER THE CHAMBER", onConfirm = function() S:launch() end },
    { label = "BACK", onConfirm = function() G.State.pop() end },
  }
  self.list = Menu.new(items, { y = 44, spacing = 13 })
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
    dome = cfg.domeTier, hpTier = cfg.hpTier, energyTier = cfg.energyTier,
  }
  for _, pd in ipairs(run.players) do
    pd.maxhp = 12 + cfg.hpTier * 4
    pd.hp = pd.maxhp
  end
  l.maxenergy = 100 + cfg.energyTier * 20

  -- abilities
  for _, f in ipairs(ABILITY_SETS[cfg.abilities].flags) do
    run.flags[f] = true
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
  g.rectangle("fill", 0, 0, G.VW, G.VH)
  g.setFont(G.fonts.main)
  g.setColor(P.spark)
  g.printf("TEST CHAMBER", 0, 22, G.VW, "center")
  g.setColor(P.slate)
  g.printf("weapons - bosses - mechanics", 0, 32, G.VW, "center")
  self.list:draw()
  g.setColor(1, 1, 1, 1)
end

S.cfg = cfg
S.BOSSES = BOSSES
S.ARENAS = ARENAS

return S
