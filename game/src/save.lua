-- Settings + save slot IO. Save files live in the LÖVE save directory
-- (%APPDATA%\LOVE\emberdeep on Windows).
local Ser = require "src.core.ser"
local U = require "src.core.util"

local Save = {}
Save.SLOTS = 3
-- Current save-file format. Bump this in the same commit as any new
-- Save.migrate step: writeSlot stamps it, migrate upgrades anything older.
Save.VERSION = 3

function Save.defaultSettings()
  return {
    volMaster = 0.8,
    volMusic = 0.7,
    volSfx = 0.9,
    fullscreen = false,
    windowscale = 2,
    -- RENDER SCALE. How many canvas pixels per world unit. 1 is the
    -- shipped look; 4 makes the canvas exactly 1920x1080. It does NOT
    -- widen the lens -- see FOUNDATION-PLAN.md section 1.
    -- RENDER SCALE: canvas pixels per logical unit. 4 makes the canvas
    -- exactly 1920x1080. The procedural pixel art is unchanged by it --
    -- nearest-filtered tiles at 4x are identical to upscaling -- so what
    -- it buys is everything drawn as vectors rather than sprites: the
    -- light buffer's gradients, rounded HUD corners, particles, and
    -- camera and sprite motion snapping to a quarter of a world unit
    -- instead of a whole one. It is the only setting here with a real
    -- runtime cost; EMBERDEEP_RS=1 backs it out.
    renderscale = 4,
    -- LIGHTING MODEL for dark rooms.
    --
    -- "buffer" is the shipped look: coloured light accumulated into its
    -- own canvas and multiplied over the scene. "mask" is the model the
    -- game shipped with before -- flat black with soft holes punched in
    -- it -- kept because it is cheaper and because a look that replaced
    -- another should leave a way back to it for a while.
    --
    -- Verified before the switch: mask against the pre-Phase-4 baseline
    -- was 0 differing across 31 rooms, and buffer against mask differs in
    -- exactly the 4 dark rooms and nowhere else.
    lighting = "buffer",
    -- How much of the light buffer is added back over the scene: a cheap
    -- bloom that lets a lamp bleed past what it lights. 0 disables it.
    glow = 0.18,
    -- Bumped when a DEFAULT changes in a way existing players should
    -- receive. See the migration in loadSettings. 0 means "written
    -- before this existed", which is why the default is 0 and not the
    -- current version.
    -- VERTICAL PARALLAX strength: a multiplier on each layer's fy. 0 is
    -- the shipped look (backdrops welded to the screen). It is anchored
    -- at each room's floor, so it can only ever act in a room taller than
    -- the viewport -- 20 of 83 -- and is a no-op in the rest.
    parallaxY = 1,
    -- ROCK TEXTURE strength over enclosed solid tiles. 0 is the old flat
    -- tile grid. See World:drawStrata.
    strata = 1,
    -- EDGE SOFTENING + foreground overgrowth strength. 0 is the bare
    -- 16px tile outline. See World:drawEdges.
    -- 0.7 rather than 1: at full strength the hanging growth reads as a
    -- curtain in motion rather than as a cave. The corner rounding is
    -- unaffected by this -- only the density of what hangs off the rock.
    edges = 0.7,
    settingsVersion = 0,
    vsync = true,
    shake = true,
    rumble = true,
    flashes = true,
    difficulty = 2, -- 1 Story, 2 Normal, 3 Veteran (per-save override at new game)
    testmode = true, -- play-testing tools (Progress panel on F1, etc.)
    bindings = nil,
  }
end

function Save.loadSettings()
  local s = Save.defaultSettings()
  local info = love.filesystem.getInfo("settings.dat")
  if info then
    local raw = love.filesystem.read("settings.dat")
    local ok = raw and Ser.unpack(raw)
    if ok then
      for k, v in pairs(ok) do s[k] = v end
    end
  end
  -- ----------------------------------------------------------------
  -- SETTINGS MIGRATION
  --
  -- A saved settings.dat overrides every default. That is right for
  -- anything the player chose and wrong for a default that has since
  -- moved: `lighting` shipped as "mask" and is now "buffer", and a file
  -- written in between holds "mask" not because anyone picked it but
  -- because the file got written at all -- one press of F11 does it.
  --
  -- After the fact the two are indistinguishable, so the version stamp
  -- is the only way to tell them apart. Migrate the specific keys that
  -- moved; never wipe the file, because everything else in it -- volume,
  -- bindings, difficulty -- the player really did choose.
  -- ----------------------------------------------------------------
  -- One entry per version, naming only the keys whose DEFAULT moved.
  -- Everything not listed is left exactly as the player left it.
  local MIGRATIONS = {
    { "lighting" },                      -- v1: mask -> buffer
    { "renderscale", "parallaxY" },      -- v2: the foundation dials come on
  }
  local V = #MIGRATIONS
  local have = s.settingsVersion or 0
  if have < V then
    local d = Save.defaultSettings()
    for v = have + 1, V do
      for _, k in ipairs(MIGRATIONS[v]) do s[k] = d[k] end
    end
    s.settingsVersion = V
  end

  -- validate bindings shape
  if s.bindings then
    local valid = type(s.bindings) == "table" and #s.bindings == 2
    if valid then
      for i = 1, 2 do
        local b = s.bindings[i]
        if type(b) ~= "table" or type(b.pad) ~= "table" or type(b.kb) ~= "table" then
          valid = false
        end
      end
    end
    if not valid then s.bindings = nil end
  end
  return s
end

function Save.saveSettings()
  local s = U.copy(G.settings)
  -- An environment override is for LOOKING at something, not for changing
  -- what the player owns. EMBERDEEP_LIGHTING=buffer followed by any
  -- settings write -- toggling fullscreen with F11 would do it -- would
  -- otherwise bake the override into settings.dat, where it outlives the
  -- session that asked for it and cannot be traced back to anything the
  -- player did. Put the real values back before writing.
  for k, v in pairs(G.settingsEnv or {}) do s[k] = v end
  love.filesystem.write("settings.dat", Ser.pack(s))
end

-- ==================================================================
-- THE SEAL
--
-- From the moment the Ember comes loose until an ending is written, the
-- run stops being something you can put down. Nothing writes to disk,
-- no checkpoint moves, no lantern lights.
--
-- The reason is not flavour. A save made after the theft is a save the
-- player can reload to un-take it, and that turns the one irreversible
-- decision in the game into a menu option. It has to cost something to
-- have done it.
--
-- Everything that could persist or rewind the run asks this ONE
-- function. It used to be the same three-part condition copy-pasted into
-- four files, which is how the checkpoint lantern kept quietly lighting
-- after the theft while everything around it had been sealed.
-- ==================================================================
function Save.sealed()
  if not G.run then return false end
  local f = G.run.flags or {}
  return (f.ember_taken or G.run.emberBad
    or (f.reckoning and not f.ending_done)) and true or false
end

function Save.newRun(slot, difficulty, coop)
  local Up = require "src.upgrades"
  return {
    slot = slot, difficulty = difficulty or 2, coop = coop or false,
    playtime = 0, scrap = 0, capsules = 0, tanks = 0,
    forge = { boltdriver = 1, scatterhex = 1, arclance = 1, sparkshot = 1,
              dome = 1, repairPulse = 1, hpTier = 0, energyTier = 0 },
    flags = {}, visited = {}, mech = {},
    room = "camp_awake", door = "A",
    checkpoint = { room = "camp_awake", door = "A" },
    players = {
      { maxhp = Up.maxHp(0), hp = Up.maxHp(0),
        weapons = { { id = "boltdriver", xp = 0 } }, curWeapon = 1 },
      { maxhp = Up.maxHp(0), hp = Up.maxHp(0),
        weapons = { { id = "sparkshot", xp = 0 } }, curWeapon = 1,
        maxenergy = Up.maxEnergy(0) },
    },
  }
end

-- v1 saves used shard-XP weapon leveling and instant capsule/tank stat
-- grants. Convert earned progress into forge tiers so nothing is lost.
function Save.migrate(data)
  if data.version and data.version >= Save.VERSION then return data end
  local W = require "src.weapons"
  local Up = require "src.upgrades"
  local forge = { boltdriver = 1, scatterhex = 1, arclance = 1,
                  sparkshot = 1, dome = 1, repairPulse = 1,
                  hpTier = 0, energyTier = 0 }
  for _, pl in ipairs(data.players or {}) do
    for _, ws in ipairs(pl.weapons or {}) do
      local def = W.defs[ws.id]
      if def and ws.xp then
        local tier = 1
        if ws.xp >= def.thresholds[1] then tier = 2 end
        if ws.xp >= def.thresholds[2] then tier = 3 end
        forge[ws.id] = math.max(forge[ws.id] or 1, tier)
      end
    end
  end
  local p1 = data.players and data.players[1]
  local p2 = data.players and data.players[2]
  -- Derive the old save's tiers with the ORIGINAL v1 constants (+4 hp,
  -- +20 energy), not the current ones -- the numbers in that save were
  -- written under the old economy and re-reading them under the new one
  -- would silently hand every returning player extra tiers.
  forge.hpTier = math.max(0, math.floor((((p1 and p1.maxhp) or 12) - 12) / 4))
  forge.energyTier = math.max(0,
    math.floor((((p2 and p2.maxenergy) or 100) - 100) / 20))
  forge.hpTier = math.min(forge.hpTier, Up.MAX.hp)
  forge.energyTier = math.min(forge.energyTier, Up.MAX.energy)
  data.forge = data.forge or forge
  data.capsules = math.max(data.capsules or 0, forge.hpTier)
  data.tanks = math.max(data.tanks or 0, forge.energyTier)
  -- v3: hover moved out of SPARK JUMP and into the DRIFT VANES. Anyone who
  -- already held spark jump already had the full 1.3s hover, so granting
  -- the vanes alongside it is the only migration that changes nothing.
  if data.flags and data.flags.sparkjump then
    data.flags.driftvanes = true
  end
  data.version = Save.VERSION
  return data
end

local function slotPath(i) return "slot" .. i .. ".sav" end

function Save.readSlot(i)
  local info = love.filesystem.getInfo(slotPath(i))
  if not info then return nil end
  local raw = love.filesystem.read(slotPath(i))
  if not raw then return nil end
  local data = Ser.unpack(raw)
  if not data or data.version == nil then return nil end
  return Save.migrate(data)
end

function Save.writeSlot(i, data)
  if not i or (data and data.testChamber) then return false end
  data.version = Save.VERSION
  data.savedAt = os.time()
  local ok, packed = pcall(Ser.pack, data)
  if not ok then return false end
  -- write-then-rename for safety
  love.filesystem.write(slotPath(i) .. ".tmp", packed)
  local raw = love.filesystem.read(slotPath(i) .. ".tmp")
  if raw ~= packed then return false end
  love.filesystem.write(slotPath(i), packed)
  love.filesystem.remove(slotPath(i) .. ".tmp")
  return true
end

function Save.deleteSlot(i)
  love.filesystem.remove(slotPath(i))
end

return Save
