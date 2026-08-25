-- Item / reward granting.
local Items = {}

-- `ability = true` marks a module that changes what a bot can DO, as
-- opposed to a key, a quest item or a collectible. It is not decoration:
-- the Test Chamber builds its module toggles from this field, so a new
-- ability that forgets it is a new ability the chamber cannot switch on.
--
-- That is not hypothetical. BULWARK and DRIFT VANES were both missing
-- from every ability set, which meant the Test Chamber could drop you
-- into the Conductor's arena -- where the panels need a plated charge
-- and the outer emitters need a thermal column -- with no way to turn
-- either on, and no way to win. `short` is the name the chamber shows.
Items.MODULES = {
  sparkjump = { ability = true, short = "SPARK JUMP", name = "SPARK JUMP MODULE", desc = "Increases LUMEN robot jumping capability." },
  grapple = { ability = true, short = "GRAPPLE", name = "MAGNE-GRAPPLE", desc = "VESSEL robot grapple apparatus. JUMP again in mid-air near an anchor ring: the hook takes you to it and throws you up past it." },
  heatplating = { ability = true, short = "HEAT SHIELDING", name = "HEAT SHIELDING", desc = "Ceramic heat shields. Compatible with both robots." },
  hydroseals = { ability = true, short = "HYDRO SEALS", name = "HYDRO SEALS", desc = "Original hull seals, good as new. Both bots can dive underwater indefinitely!" },
  telenet = { ability = true, short = "TELEPORTER KEY", name = "TELEPORTER KEY", desc = "The old teleporter network is yours to use!" },
  -- THE NUMBER WAS THE FRAGMENT'S IDENTITY, NOT YOUR COUNT.
  --
  -- corekey3 is the Spire fragment, so killing the Aerie Sentinel FIRST
  -- announced "CORE KEY FRAGMENT (3/3)" and read as "you have all three"
  -- when it was your first. There is no ordering between them -- the
  -- three zones can be done in any order -- so any counter in the name
  -- is a lie in five of the six possible orders.
  --
  -- Named for where they come from instead, which is what Maro and the
  -- Core terminal already call them and which cannot be wrong. The real
  -- tally lives on the pause screen, where it counts what you HAVE.
  corekey1 = { name = "CORE KEY FRAGMENT -- FURNACE", desc = "A piece of the seal on the heart of Emberdeep." },
  corekey2 = { name = "CORE KEY FRAGMENT -- HOLLOWS", desc = "A piece of the seal on the heart of Emberdeep." },
  corekey3 = { name = "CORE KEY FRAGMENT -- SPIRE", desc = "A piece of the seal on the heart of Emberdeep." },
  musicbox = { name = "RUSTED MUSIC BOX", desc = "Tikka's treasure. It still plinks faintly." },
  moldcap = { name = "GIANT MOLDCAP", desc = "A mushroom the size of a hat. Root will love it." },
  lumecore = { ability = true, short = "LUME CORE", name = "LUME CORE", desc = "Lu's original light assembly! She radiates in the dark, and the Undergrove's deep doors will open to her." },
  ferrocoil = { name = "FERRO'S COIL", desc = "A salvaged induction coil. Ferro has been looking for this." },
  cryocoils = { ability = true, short = "CRYO COILS", name = "CRYO COILS", desc = "Original thermal regulators, restored. Both bots endure the deep-freeze -- the Coldstore will open to you." },
  arcplate1 = { name = "ARCHIVE PLATE: THE GREEN WING", desc = "A catalog plate, mis-shelved a century ago. Curator Lock wants it home." },
  arcplate2 = { name = "ARCHIVE PLATE: THE DROWNED WING", desc = "A catalog plate, mis-shelved a century ago. Curator Lock wants it home." },
  arcplate3 = { name = "ARCHIVE PLATE: THE BURNING WING", desc = "A catalog plate, mis-shelved a century ago. Curator Lock wants it home." },
  arcplate4 = { name = "ARCHIVE PLATE: THE SINGING WING", desc = "A catalog plate, mis-shelved a century ago. Curator Lock wants it home." },
  bulwark = { ability = true, short = "BULWARK PLATE", name = "BULWARK PLATE", desc = "Vess's own forward plate. His CHARGE now carries a shield." },
  driftvanes = { ability = true, short = "DRIFT VANES", name = "DRIFT VANES", desc = "Lu's original attitude assembly, recovered from the Sentinel's nest. Hold JUMP while falling and she falls slowly, with full control, for a long way. She can also ride thermal columns upward. Vess cannot follow her across them -- find him another way round." },
  cinderram = { ability = true, short = "CINDER RAM", name = "CINDER RAM", desc = "Recovered from VESSEL-8. The CHARGE is an attack now. It damages what it hits, shatters a raised guard outright, and burns a chevron through the dark." },
}

-- The ability modules in a fixed display order. Anything marked
-- `ability = true` belongs here; deriving it means the pause screen and
-- the Test Chamber cannot fall out of step with the table again.
Items.ABILITY_ORDER = {
  "sparkjump", "grapple", "driftvanes", "bulwark", "cinderram",
  "hydroseals", "heatplating", "cryocoils", "lumecore", "telenet",
}

-- STOP THE WORLD AND EXPLAIN THE THING.
--
-- One door for every "you now have a new verb" moment, so a new grant
-- site cannot quietly go back to shouting a line across a moving room.
-- The state freezes the game underneath, dims it, and waits for a press.
function Items.explain(title, body)
  G.State.push(require "src.states.acquire", { title = title, body = body })
end

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
    -- the overlay plays the pickup sound itself; playing it here too
    -- fired it twice on the same frame
    Items.explain("NEW WEAPON: " .. def.name,
      (def.blurb or "A new way to make a hole in something.")
      .. "\n\nSwap to it with WEAPON SWAP.")
  elseif kind == "module" then
    local id = parts[2]
    G.run.flags[id] = true
    local m = Items.MODULES[id]
    -- MODULES GET THE OVERLAY TOO -- they are the whole reason it
    -- exists. This branch used to announce() the description across the
    -- top of a room that was still moving, which is the exact failure
    -- the overlay was built to fix; the weapon branch above was wired up
    -- and this one was left behind.
    Items.explain(m and m.name or string.upper(id),
      m and m.desc or "A new module. Its use will become clear.")
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
