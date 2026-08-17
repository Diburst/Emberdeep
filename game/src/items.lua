-- Item / reward granting.
local Items = {}

Items.MODULES = {
  sparkjump = { name = "SPARK JUMP MODULE", desc = "Lu's original leg actuators, home at last. She jumps a full block higher! Vess can WARP to her after she climbs." },
  grapple = { name = "MAGNE-GRAPPLE", desc = "Vess's factory grapple, back where it belongs. Press DASH near an anchor ring to zip to it!" },
  heatplating = { name = "HEAT PLATING", desc = "Original caretaker furnace plating, refitted. Both bots endure the deep heat!" },
  hydroseals = { name = "HYDRO SEALS", desc = "Original hull seals, good as new. Both bots can dive underwater indefinitely!" },
  telenet = { name = "TELEPORTER KEY", desc = "The old teleporter network is yours to use!" },
  corekey1 = { name = "CORE KEY FRAGMENT (1/3)", desc = "A piece of the seal on the heart of Emberdeep." },
  corekey2 = { name = "CORE KEY FRAGMENT (2/3)", desc = "A piece of the seal on the heart of Emberdeep." },
  corekey3 = { name = "CORE KEY FRAGMENT (3/3)", desc = "A piece of the seal on the heart of Emberdeep." },
  musicbox = { name = "RUSTED MUSIC BOX", desc = "Tikka's treasure. It still plinks faintly." },
  moldcap = { name = "GIANT MOLDCAP", desc = "A mushroom the size of a hat. Root will love it." },
  lumecore = { name = "LUME CORE", desc = "Lu's original light assembly! She radiates in the dark, and the Undergrove's deep doors will open to her." },
  ferrocoil = { name = "FERRO'S COIL", desc = "A salvaged induction coil. Ferro has been looking for this." },
  cryocoils = { name = "CRYO COILS", desc = "Original thermal regulators, restored. Both bots endure the deep-freeze -- the Coldstore will open to you." },
  arcplate1 = { name = "ARCHIVE PLATE: THE GREEN WING", desc = "A catalog plate, mis-shelved a century ago. Curator Lock wants it home." },
  arcplate2 = { name = "ARCHIVE PLATE: THE DROWNED WING", desc = "A catalog plate, mis-shelved a century ago. Curator Lock wants it home." },
  arcplate3 = { name = "ARCHIVE PLATE: THE BURNING WING", desc = "A catalog plate, mis-shelved a century ago. Curator Lock wants it home." },
  arcplate4 = { name = "ARCHIVE PLATE: THE SINGING WING", desc = "A catalog plate, mis-shelved a century ago. Curator Lock wants it home." },
  bulwark = { name = "BULWARK PLATE", desc = "Vess's own forward plate. His CHARGE now carries a shield." },
  driftvanes = { name = "DRIFT VANES", desc = "Lu's original attitude assembly, recovered from the Sentinel's nest. Hold JUMP while falling and she falls slowly, with full control, for a long way. She can also ride thermal columns upward. Vess can WARP to her across the gaps he cannot jump." },
  cinderram = { name = "CINDER RAM", desc = "Recovered from VESSEL-8. The CHARGE is an attack now. It damages what it hits, shatters a raised guard outright, and burns a chevron through the dark." },
}

-- spec: "scrap:15" | "weapon:scatterhex" | "module:grapple" | "heal:full"
--       | "bigshard:5"
function Items.grant(spec, player)
  local U = require "src.core.util"
  local parts = U.split(spec, ":")
  local kind = parts[1]
  local World = require "src.world"

  if kind == "scrap" then
    local n = tonumber(parts[2]) or 1
    G.run.scrap = G.run.scrap + n
    G.game:announce("Found " .. n .. " scrap!", 2)
  elseif kind == "weapon" then
    local id = parts[2]
    local Weapons = require "src.weapons"
    local def = Weapons.get(id)
    local target = G.run.players[def.user]
    for _, w in ipairs(target.weapons) do
      if w.id == id then return end -- already owned
    end
    target.weapons[#target.weapons + 1] = { id = id, xp = 0 }
    G.run.flags["weapon_" .. id] = true
    G.game:announce("NEW WEAPON: " .. def.name .. "! (swap with WEAPON SWAP)", 3.5)
    if G.Audio then G.Audio.sfx("capsule") end
  elseif kind == "module" then
    local id = parts[2]
    G.run.flags[id] = true
    local m = Items.MODULES[id]
    if m then
      G.game:announce("GOT " .. m.name .. " - " .. m.desc, 4.5)
    end
    if G.Audio then G.Audio.sfx("capsule") end
  elseif kind == "heal" then
    for _, pl in ipairs(World.players) do
      if not pl.dead then pl.hp = pl.maxhp end
    end
  elseif kind == "bigshard" then
    local n = tonumber(parts[2]) or 3
    local Pickup = require "src.entities.pickup"
    player = player or World.players[1]
    if player then
      Pickup.drop(World, player.x + 5, player.y, "bigshard", n)
    end
  end
end

return Items
