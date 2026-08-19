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
  love.filesystem.write("settings.dat", Ser.pack(s))
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
