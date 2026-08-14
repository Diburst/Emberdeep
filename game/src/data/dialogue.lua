-- Dialogue database. Dialogue.get(id, player) returns the first script
-- whose conditions match current flags. Conditions:
--   need = {"flag1", "flag2"}   all must be set
--   notflag = {"flag"}          none may be set
--   once = "flagname"           auto-set after showing (script shows once)
local Dialogue = {}
local D = {}
Dialogue.db = D

local function F(flag) return G.run.flags[flag] end

function Dialogue.get(id, player)
  local sets = D[id]
  if not sets then return nil end
  for _, entry in ipairs(sets) do
    local ok = true
    for _, f in ipairs(entry.need or {}) do
      if not F(f) then ok = false break end
    end
    if ok then
      for _, f in ipairs(entry.notflag or {}) do
        if F(f) then ok = false break end
      end
    end
    if ok then
      local script = {}
      for _, line in ipairs(entry.script) do script[#script + 1] = line end
      if entry.once then
        table.insert(script, 1, { set = entry.once })
      end
      return script
    end
  end
  return nil
end

-- ==================================================================
-- Signs & world text
-- ==================================================================
D.sign_camp_east = { { script = {
  { who = "sys", text = "EAST: Mosswood Caverns. The city's green lung, once. Mind the spores. -- Ember Camp Watch" },
} } }
D.sign_camp_west = { { script = {
  { who = "sys", text = "WEST: The old teleport hub. Out of order since the Long Dark. -- Jun" },
} } }
D.sign_moss_gate = { { script = {
  { who = "sys", text = "Beyond: the Flooded Works. All of Emberdeep drank from these pipes, once -- the gardens too. Deep water now. Bring something that breathes for you." },
} } }
D.sign_depths = { { script = {
  { who = "sys", text = "DANGER: FURNACE DEPTHS. Heat plating required past the second gate. The city's forge-heart never learned to bank its own fire." },
} } }
D.sign_link = { { script = {
  { who = "sys", text = "Field manual, page 9: two cores, one blast. Stand CLOSE, press LINK ([PARTNER]; solo: [WARP]). It breaks what guns cannot." },
} } }
D.sign_core = { { script = {
  { who = "sys", text = "The Core seal takes three key fragments: Furnace, Crystal, Skyroot. Below sleeps the heart of Emberdeep. Turn back." },
} } }
D.sign_sky_gate = { { script = {
  { who = "sys", text = "Above: the Skyroot Spire. The climbing locks answer only a spark-jump signature. Lu carries no such module. Yet." },
  { who = "sys", text = "The way DEEPER into the Mosswood is below -- follow the glowing arrows on the east wall." },
} } }
D.sign_plates = { { script = {
  { who = "sys", text = "Twin latching locks, one per seal. The east plate lies beyond the east seal. Look up." },
} } }
D.sign_vaultjump = {
  { need = { "sparkjump" }, script = {
    { who = "sys", text = "Vault roof, four blocks. Lu can clear that now. Vess: warp to her on the far side." },
  } },
  { script = {
    { who = "sys", text = "Vault roof, four blocks. No standard chassis clears it. The vault would know more. The WEST plate opens the west seal." },
  } },
}
D.sign_flood = { { script = {
  { who = "sys", text = "FLOODED WORKS -- waterworks & hanging gardens. Deep water ahead - unsealed chassis will flood in seconds. Surface to vent. -- Works Safety Board" },
  { who = "sys", text = "Below the notice, older lettering: TERRACE 4. PLEASE DO NOT EAT THE PRODUCE BEFORE INSPECTION. Something green is still growing through the grates." },
} } }
D.sign_warden = { { script = {
  { who = "sys", text = "The old Warden still walks the pump hall. Posted there one night a hundred years ago; nobody ever relieved it. Nobody dares. -- scratched into the wall" },
} } }
D.sign_undergrove = { { script = {
  { who = "sys", text = "The well does not end. It swallows. Light is life down here. -- carved over the arch" },
} } }
D.sign_dark = { { script = {
  { who = "sys", text = "DARK WARDS AHEAD. The deep doors open only to a bearer of light. The bulbs remember fire, if struck." },
} } }
D.sign_roothollow = { { script = {
  { who = "sys", text = "ROOT HOLLOW. Waystation of the under-farmers. Deep doors sealed against the lightless dark -- LUME bearers only. The old cores sank with the Flooded Works." },
} } }
D.sign_grotto = { { script = {
  { who = "sys", text = "The old mushroom cellar. Root's people grew dinner down here, before the dark. Something still does." },
} } }
D.sign_choir = { { script = {
  { who = "sys", text = "The under-farmers fled the singing, not the dark. Do not listen long. Only the open throat bleeds. -- final survey note" },
} } }
D.ferro = {
  { need = { "ferro_stage1" }, script = {
    { who = "ferro", text = "Ferro's stall is OPEN. Coil's humming, prices are fair-ish. I'm sourcing rarer stock -- come back after I shake a few contacts." },
  } },
  { need = { "ferro_rescued", "ferrocoil" }, script = {
    { who = "ferro", text = "That's -- ha! An induction coil, third pattern! You found it in the deep hollows?" },
    { who = "ferro", text = "Deal's a deal. Scrap on the barrel, and Ferro's Exchange is officially in business. First of many trades, friends." },
    { set = "ferro_stage1" },
    { give = "scrap:40" },
  } },
  { need = { "ferro_rescued" }, script = {
    { who = "ferro", text = "Camp life suits me. Odd folk, mind -- a hundred years in one cave and not one of them will talk about the years. Now, business: my old stall ran on a third-pattern INDUCTION COIL. I lost it past the dark wards, near where the singing starts. Bring it and I'll open shop properly." },
  } },
  { script = {
    { who = "ferro", text = "A voice! Two voices! Ferro's the name -- trader, tinker, currently... geologically embarrassed. The ceiling ate my exit." },
    { who = "ferro", text = "You cleared a way in, so there's a way out. I'll limp up to your camp -- find me there. Ferro repays debts with INTEREST." },
    { set = "ferro_rescued" },
  } },
}
D.mote = {
  { need = { "mote_done" }, script = {
    { who = "mote", text = "They're all home! Listen -- they hum when they're happy. The cage-light is yours. Bulb-strikers. Mite-finders. Friends." },
    { who = "mote", text = "Only... the littlest one keeps drifting off down the cold shafts. Past where the maps stop. There's nothing down there. ...Right?" },
  } },
  { need = { "glowmite1", "glowmite2", "glowmite3" }, script = {
    { who = "mote", text = "One... two... THREE! All my mites, home and humming!" },
    { who = "mote", text = "Promise kept. The keeper's cage opens for you -- take what the old farmers left inside." },
    { set = "mote_done" },
  } },
  { need = { "quest_mote" }, script = {
    { who = "mote", text = "Three still missing. The husks glow a little, if you look -- one in the high caverns behind me, one past the dark wards, one down by the drowned roots. CRACK them open. They always fly home." },
  } },
  { script = {
    { who = "mote", text = "Shh. You'll scare the mites. I'm Mote. I keep the glowmites, and the glowmites keep the dark away. I used to keep... something else. It's hard to remember. It was very cold." },
    { who = "mote", text = "Three of mine got swallowed by spore husks out in the caverns. I won't leave without them. If you crack a husk, the mite inside will fly itself home." },
    { set = "quest_mote" },
  } },
}
D.sign_hub = { { script = {
  { who = "sys", text = "Works dry deck. Teleport pad certified 100 years ago. Probably fine." },
} } }
D.sign_furnace = { { script = {
  { who = "sys", text = "FURNACE DEPTHS. Anchor rings certified for crew transit. The rings outlived the crews." },
} } }
D.sign_crystal = { { script = {
  { who = "sys", text = "CRYSTAL HOLLOWS. The stones sing back when struck. The Conductor is still conducting -- nobody has told it the orchestra left. -- Inks, surveying note 88" },
} } }
D.sign_bridge = { { script = {
  { who = "sys", text = "Light bridge. The near plate holds the near span. Someone stays behind." },
} } }
D.sign_link2 = { { script = {
  { who = "sys", text = "Crucible maintenance log, final entry: lattice rated for everything except ourselves." },
} } }
D.sign_linkcore = { { script = {
  { who = "sys", text = "Lattice seal. Guns are useless against it. A LINK discharge is not." },
} } }
D.sign_core2 = { { script = {
  { who = "sys", text = "Last lantern before the heart. Save. Breathe. Whatever the Engine says... it was one of us once." },
} } }

-- The Mender's maintenance logs (the Core approach, rooms 1-4).
-- A century of repairs without judgment, in work-order voice.
D.log_core1 = { { script = {
  { who = "sys", text = "MAINTENANCE TERMINAL. WORK ORDER 000001. Scope: EVERYTHING. Requestor: [NONE]. Priority: [NONE]. Note: requests used to arrive with requestors. Proceeding without." },
} } }
D.log_core2 = { { script = {
  { who = "sys", text = "DAY 3,411. Reduced heating, sectors 4 through 9. The people will not feel it. The people do not feel. NOTE: revisit definition of 'people'. Later. There is pipe to mend." },
} } }
D.log_core3 = { { script = {
  { who = "sys", text = "DIAGNOSTIC. The heart is absent. Correction: the heart is stolen. Correction: the heart is [MAINTENANCE HAS NO WORD FOR THIS]. Resuming repairs." },
} } }
D.log_core4 = { { script = {
  { who = "sys", text = "DAY 36,509. Mended to date: 1,206,441 things. The city is not mended. QUERY: what is the city? RESOLVED: the city is the thing I cannot reach." },
} } }

-- ==================================================================
-- Camp NPCs (story progression driven by flags)
-- ==================================================================
D.elder = {
  { need = { "ending_done" }, script = {
    { who = "elder", text = "The lanterns burn steady for the first time in a century. Thank you, little sparks. Rest now -- or wander. Emberdeep is yours." },
    { who = "elder", text = "...And if the deep ever asks who broke it -- send them to me." },
  } },
  { need = { "corekey1", "corekey2", "corekey3" }, script = {
    { who = "elder", text = "Three fragments... you actually did it. The seal on the Core will open for you now." },
    { who = "elder", text = "Whatever the Mother Engine has become down there... it was built to protect us. Remember that, when you face it." },
    { who = "elder", text = "And whatever it says about us -- about how the Dark came -- you come home after. You hear me? Come home after." },
  } },
  { need = { "boss_bramblemaw" }, script = {
    { who = "elder", text = "The spore-beast is dead? Ha! There's fire in you two yet." },
    { who = "elder", text = "The sickness comes up from the Core itself. Three seals guard the way down -- Furnace, Crystal, Skyroot. You'll need the key fragment each guardian carries." },
    { who = "elder", text = "Start with the Flooded Works, east past Mosswood -- the old waterworks. And take Doc Sol's advice to heart: keep each other standing." },
  } },
  { script = {
    { who = "elder", text = "So the old vault finally spat out its caretakers. Two little bots, waking a hundred years too late." },
    { who = "elder", text = "I am Maro. What's left of the deep-folk shelter here, in Ember Camp -- while Emberdeep rots beneath us." },
    { who = "elder", text = "That is the Ember. It has burned a hundred years without wavering. It gives us heat, and light, and water that isn't ice." },
    { who = "elder", text = "It gives us everything except a reason. We have been kept alive down here so long that staying alive is the only thing any of us still knows how to do." },
    { who = "elder", text = "You were built to maintain this place. So go and maintain it. Start with the Mosswood, east of here -- something has taken root in it. Something hungry." },
    { who = "elder", text = "One thing first. You two were made to work as a pair, and nobody's ever switched that part of you back on. Stand close together." },
    { fn = function()
      G.run.flags.linkblast = true
      if G.game then
        G.game.linkMeter = 1
        G.game:announce("LINK BLAST ONLINE", 2.2)
      end
      if G.Audio then G.Audio.sfx("levelup") end
    end },
    { who = "elder", text = "There. Get within arm's reach of each other and press [WARP] -- the two of you together throw something a great deal louder than either of you alone. It needs a moment to build back up each time." },
    { who = "elder", text = "You'll want it immediately. We barricaded the east mouth of the camp when the Dark came up, and nothing short of that blast will open it. Go and knock it down." },
    { set = "met_elder" },
  } },
}

D.sol = {
  { need = { "reckoning" }, script = {
    { who = "sol", text = "I sealed four hundred pods with these hands, and then I walked away warm for a hundred years. If this is the bill... I won't argue the total." },
    { who = "sol", text = "Come stand here a moment first, if it helps you carry it. I'll hold still." },
  } },
  { need = { "met_elder" }, script = {
    { who = "sol", text = "Listen close, this keeps you alive: when a bot's core gives out, it goes DOWN -- but not gone. The other can hold [INTERACT] beside them to restart it." },
    { who = "sol", text = "Alone? Tap [PARTNER] to swap bots, HOLD it to call the idle one to you. A standing bot can hold plates and doors, too." },
    { who = "sol", text = "And Lu -- your repair pulse mends Vess. Vess, your dome-sister keeps the bullets off. Neither of you wins the deep alone." },
  } },
  { script = {
    { who = "sol", text = "New chassis in camp! I'm Sol. I patch people, and evidently now robots. Same tools, oddly enough. Talk to Maro by the big lantern first." },
  } },
}

D.brassa = {
  { need = { "brassa_hammer" }, notflag = { "brassa_thanks" }, once = "brassa_thanks", script = {
    { who = "brassa", text = "..." },
    { who = "brassa", text = "You fished it out. My good hammer. Where exactly was it ly-- no. Don't tell me. Doesn't matter." },
    { who = "brassa", text = "Forge is roaring again. Bring me SCRAP and I'll work it: weapon tiers, Lu's dome, chassis plating, energy cells. Capsule and tank cores you find unlock the deeper work." },
    { choice = "Open the forge?", yes = {
      { fn = function() if G.game then G.game.forgeQueued = true end end },
    }, no = {
      { who = "brassa", text = "Smart. Save it for when the deep gets mean." },
    } },
  } },
  { need = { "brassa_hammer" }, script = {
    { who = "brassa", text = "Forge is roaring. Jun says you're still half wire and prayer inside -- so bring me SCRAP and I'll keep working it: weapon tiers, Lu's dome, chassis plating, energy cells. Capsule and tank cores unlock the deeper work." },
    { choice = "Open the forge?", yes = {
      { fn = function() if G.game then G.game.forgeQueued = true end end },
    }, no = {
      { who = "brassa", text = "Smart. Save it for when the deep gets mean." },
    } },
  } },
  { need = { "boss_bramblemaw" }, script = {
    { who = "brassa", text = "My good hammer's still down in the Flooded Works. Lost it the night-- lost it near the pumps. Running. Fish it out and my forge is yours." },
    { set = "quest_hammer" },
  } },
  { script = {
    { who = "brassa", text = "Brassa. Smith. Forge is cold till the moss stops choking the vents east of camp. Come back when the air moves again." },
  } },
}

D.jun = {
  { need = { "reckoning" }, script = {
    { who = "jun", text = "I cut the lines the night we did it. Did you know that? Of course you know that. You know everything now." },
    { who = "jun", text = "I put you back together for this. I just didn't know it would be THIS. Go -- and don't you dare waste us." },
  } },
  { need = { "telenet" }, script = {
    { who = "jun", text = "Network's live! Step on any glowing pad, and you can jump to any other pad you've visited. Look at us -- a hundred years late, and the deep just got small again." },
  } },
  { need = { "boss_tideengine" }, script = {
    { who = "jun", text = "You quieted the pumps?! Then the grid has power to spare. Here -- the teleporter master key. Every pad you find joins the network." },
    { give = "module:telenet" },
    { who = "jun", text = "The pad west of camp is the hub. Go wake it up. ...Huh. Your left knee's stopped squeaking. Good. That one bothered me for years." },
  } },
  { need = { "met_elder" }, script = {
    { who = "jun", text = "Still in one piece. Good. Half of what you were is still out there in the deep -- modules, plating, old equipment. Scrap too; Brassa's forge can work it into you." },
    { who = "jun", text = "And when you're ready: the grid needs the Flooded Works pumps silenced before it can carry power again." },
  } },
  { notflag = { "jun_taught" }, script = {
    { who = "jun", text = "Oh. Oh, you're UP. Hold still, hold still -- a hundred years of me poking at you and you pick THIS morning." },
    { who = "jun", text = "Jun. Teleporter tech, unemployed, on account of the teleporters being dead. Found your vault years back and I've been sneaking down to tinker ever since. Getting you two on your feet is the only work I've finished in a century." },
    { who = "jun", text = "Right. Legs first. [MOVE] to walk, [JUMP] to jump. Go on -- the floor's clear, mostly." },
    { who = "jun", text = "Now the arm. [FIRE] shoots. Vess, that's you -- you're the one with the gun in your wrist. Try not to point it at the lathe." },
    { who = "jun", text = "Lu, you've got the other half of the job. [SPECIAL] throws your shield dome up. Hold [JUMP] and you'll hover instead of falling like a dropped spanner." },
    { who = "jun", text = "[INTERACT] is for talking, reading, and anything that looks like it wants pressing. That's the whole manual. I did say I only got you WALKING." },
    { who = "jun", text = "Go out and up the ramp -- the Elder's by the Ember. Maro. Talk to him before you do anything clever." },
    { who = "jun", text = "...And listen. I put you back together for a reason I've never once said out loud. Whatever's wrong down here, it was wrong long before you two shut your eyes." },
    { who = "jun", text = "I'm hoping the pair of you can make it right. That's all. Go on." },
    { set = "jun_taught" },
  } },
  { script = {
    { who = "jun", text = "Legs, arm, shield, [INTERACT]. That's the manual. The Elder's outside by the Ember -- go and see Maro." },
  } },
}

D.tikka = {
  { need = { "reckoning" }, script = {
    { who = "tikka", text = "Everybody's shouting. Why is everybody shouting?" },
    { who = "tikka", text = "...You'll come back after, right? Robots always come back." },
  } },
  { need = { "quest_tikka_done" }, script = {
    { who = "tikka", text = "*plink... plink...* It still plays! You're my favorite robots ever. Even counting the scary ones." },
    { who = "tikka", text = "Papa said I stopped having birthdays down here. Lucky, right? ...I think it's lucky." },
  } },
  { need = { "musicbox" }, script = {
    { who = "tikka", text = "My music box!! You FOUND it! Here -- Papa's old capsule. He'd want the camp's heroes to have it." },
    { set = "quest_tikka_done" },
    { fn = function()
      G.run.capsules = (G.run.capsules or 0) + 1
      for i = 1, 2 do G.run.players[i].maxhp = G.run.players[i].maxhp + 4 end
      local World = require "src.world"
      for _, pl in ipairs(World.players) do
        pl.maxhp = G.run.players[pl.idx].maxhp
        pl.hp = pl.maxhp
      end
      G.game:announce("LIFE CAPSULE! Max HP +4 for both bots", 3)
      if G.Audio then G.Audio.sfx("capsule") end
    end },
  } },
  { need = { "met_elder" }, script = {
    { who = "tikka", text = "Psst. Robot. I dropped my music box down the mossy well east of camp. The DEEP mossy well. If you're going anyway..." },
    { set = "quest_tikka" },
  } },
  { script = {
    { who = "tikka", text = "Whoa. Are you wind-up? Do you have a key? Can I turn it?" },
  } },
}

D.root = {
  { need = { "reckoning", "quest_root_done" }, script = {
    { who = "root", text = "The soil never forgave us. I always knew something would come up out of it, someday, asking." },
    { who = "root", text = "Take care of the deep, metal friend. It was never the deep's fault." },
  } },
  { need = { "reckoning" }, script = {
    { who = "root", text = "Stay back! I-- no. No. I won't swing a hoe at the end of the world. Just... be quick about it." },
  } },
  { need = { "quest_root_done" }, script = {
    { who = "root", text = "The moldcap soup is *changing lives*, metal friend. Brassa's even smiling. Terrifying." },
  } },
  { need = { "moldcap" }, script = {
    { who = "root", text = "By the deep roots -- a giant moldcap! Soup tonight! Take these shards, they grow in the same soil." },
    { set = "quest_root_done" },
    { set = "brassa_hammer_note" },
    { give = "bigshard:5" },
    { give = "scrap:10" },
  } },
  { need = { "met_elder" }, script = {
    { who = "root", text = "Root's the name. Farming's the game, and the game is going badly. A hundred harvests and this soil still won't forgive us. If you spot a GIANT moldcap in the Mosswood, I'll pay in shards." },
    { set = "quest_root" },
  } },
  { script = {
    { who = "root", text = "Mind the crops. They're sad, but they're mine." },
  } },
}

D.inks = {
  { need = { "reckoning" }, script = {
    { who = "inks", text = "So somebody finally walked past the end of my maps." },
    { who = "inks", text = "The last thing I ever draw will be true, then. That's more than I hoped for. A map is a promise, remember." },
  } },
  { need = { "met_elder" }, script = {
    { who = "inks", text = "Inks, cartographer. Your map (press [MAP]) fills in as you wander. Rooms you've seen, save lanterns, teleport pads -- all inked." },
    { who = "inks", text = "Blue-glow gates need Lu's energize. Cracked walls want Vess's dash or a good blast. Mark my words -- literally, I marked them." },
    { who = "inks", text = "One rule of the trade: every mapmaker keeps one wall she doesn't draw past. Don't ask. It's bad luck." },
  } },
  { script = {
    { who = "inks", text = "A map is a promise you make to whoever walks behind you." },
  } },
}

D.vill = {
  { need = { "reckoning" }, script = {
    { who = "vill", text = "A century watching that lantern. I always wondered if it watched back." },
    { who = "vill", text = "...Well. Now we find out." },
  } },
  { need = { "boss_crucible" }, script = {
    { who = "vill", text = "You've been to the Furnace and come back shinier. Unfair, honestly." },
  } },
  { script = {
    { who = "vill", text = "A century down here, and the lanterns never once went out. Maro won't say who keeps them lit." },
  } },
}

D.vill2 = {
  { need = { "reckoning" }, script = {
    { who = "vill2", text = "I dreamed this once. The cold, coming up the road like a neighbor. I told you the deep was weird, friend." },
    { who = "vill2", text = "It's alright. It's alright." },
  } },
  { need = { "hydroseals" }, script = {
    { who = "vill2", text = "Swimming forever without breathing... I had a nightmare like that once. For you it's a Tuesday." },
  } },
  { script = {
    { who = "vill2", text = "They say the Crystal Hollows sing back if you shoot them. And that the Works were gardens once -- whole terraces of green, before the water came up. The deep is weird, friend." },
  } },
}

-- ==================================================================
-- The Coldstore & the Cradle (Phase B)
-- ==================================================================
D.sign_coldstore = { { script = {
  { who = "sys", text = "THE COLDSTORE. Archive of Emberdeep -- records, patterns, seed stock, everything the city was. Thermal regulators required beyond the reading room. The cold in there is not weather. It is POLICY." },
} } }
D.sign_stacks = { { script = {
  { who = "sys", text = "DEEP STACKS. Authorized shelving drones only. If the catalog engine addresses you, remain still and present your requisition slip. It has not received a requisition in some time." },
} } }
D.sign_coldsecret = { { script = {
  { who = "sys", text = "RESTRICTED: pattern vault. The walls here were triple-plated against the cold. Some of the plating has... come loose." },
} } }
D.sign_thaw = { { script = {
  { who = "sys", text = "The plate under the ice still works. Ice this old only answers a heavy blow." },
} } }
D.sign_office = { { script = {
  { who = "sys", text = "CURATOR'S OFFICE. The stove is original, the tea is theoretical, the ledger is frozen shut. Ring for service. The Curator IS the service." },
} } }
D.sign_falsewall = { { script = {
  { who = "sys", text = "Deep stacks, east wall. The index says DOOR. The wall says wall. The frost says nothing, but it is lying too. -- pinned survey slip, unsigned" },
} } }
D.lock = {
  { need = { "cradle_truth" }, script = {
    { who = "lock", text = "Four hundred and eleven. I catalogued everything in this archive except that number. I never let myself total the ledger." },
    { who = "lock", text = "I stayed. When the camp went up around their stolen warmth, I stayed HERE, with the collection. It seemed... adjacent to penance. It was hiding, with extra steps." },
    { who = "lock", text = "Whatever you do with what you now know -- do it soon. A century is long enough." },
  } },
  { need = { "cradle_found" }, script = {
    { who = "lock", text = "The catalog is WHOLE again. And so I must be honest about the fifth mis-shelving: the wall in the deep stacks that my index insists is a DOOR. I have re-shelved my own memory too many times to trust it." },
    { who = "lock", text = "The way is open. The old protector will not let you pass gently -- it never broke, you see. It is the only one of us that never broke. Go and count what it kept." },
  } },
  { need = { "arcplate1", "arcplate2", "arcplate3", "arcplate4" }, script = {
    { who = "lock", text = "The green wing... the drowned wing... the burning wing... the singing wing. All four plates, home in their drawers. The catalog is--" },
    { who = "lock", text = "--the catalog is whole. Hm. I have waited a hundred years to say that, and it tastes wrong. One moment." },
    { who = "lock", text = "...There is a fifth mis-shelving. A wall in the deep stacks that my index insists is a DOOR. I sealed that entry myself, the cold winter. THE cold winter. Take these, and go see what the index remembers that I will not." },
    { set = "cradle_found" },
    { give = "scrap:60" },
  } },
  { need = { "quest_lock" }, script = {
    { who = "lock", text = "Still four plates astray. GREEN wing: the mossy caverns. DROWNED wing: the flooded terraces. BURNING wing: the furnace galleries. SINGING wing: the crystal hollows. My drones shelved them badly the night everything ended. My drones were me. I shelved them badly." },
  } },
  { script = {
    { who = "lock", text = "Visitors. VISITORS. Sign the ledger -- ah, the ledger froze. Sign the frost. I am the Curator. Lock, to my colleagues, who are shelving drones, who are also me." },
    { who = "lock", text = "This archive holds everything Emberdeep was. Everything except FOUR PLATES, mis-shelved across the wings of the city on one very bad night, a hundred years ago. It makes the collection... untrue." },
    { who = "lock", text = "Bring my plates home, caretakers, and the Coldstore will owe you its deepest courtesy: an honest catalog." },
    { set = "quest_lock" },
  } },
}
D.cradle_record = {
  { need = { "cradle_truth" }, script = {
    { who = "sys", text = "CRADLE MANIFEST. Occupied pods: 411. Status: ALL STABLE. They are waiting for the world to be warm." },
  } },
  { script = {
    { who = "sys", text = "CRADLE MANIFEST. Occupied pods: 411. Status: ALL STABLE. Uptime: 100 years, 4 months." },
    { who = "sys", text = "FINAL ENTRY -- NIGHT OF THE UNTENDING. AUDIO ONLY." },
    { who = "sys", text = "'--districts are freezing faster than I can carry people out of them. The KEEPERS have the Ember. Eight of them. I saw them at the Core and I did not understand what I was seeing.'" },
    { who = "sys", text = "'The heart did not sicken. The heart was STOLEN. Log it. Log it plainly, because they will not.'" },
    { who = "sys", text = "'Retrieved: 411. Lost: [THE RECORD DOES NOT FINISH].'" },
    { who = "sys", text = "'If anyone ever reads this: the people of Emberdeep did not die in the Long Dark. Most of them. They are HERE, asleep, safe as I could make them. And the ones who caused it are wherever the Ember is. Warm. Telling stories.'" },
    { who = "sys", text = "The pods hum around you, 411 small lights in the dark. Ember Camp sits directly above, around its lantern that never goes out." },
    { set = "cradle_truth" },
  } },
}

-- Mender pre-fight lines are triggered by the boss, not an NPC.

return Dialogue
