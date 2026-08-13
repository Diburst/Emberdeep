-- Ember Camp: the hub. Lantern light, NPCs, save statue.
return {
  zone = "camp", music = "camp",
  mapPos = { x = 2, y = 1, w = 4, h = 1 },
  hasSave = true,
  onEnter = function(World)
    local f = G.run.flags
    if f.corekey1 and f.corekey2 and f.corekey3 and not f.coredoor then
      f.coredoor = true
      G.game:announce("The great hatch to the Core rumbles open below the camp!", 4)
      if G.Audio then G.Audio.sfx("quake") end
    end
  end,
  map = [[
################################################################################
################################################################################
###............................................................................#
##.............................................................................#
##.............................................................................#
##....................######...................................................#
##............................................====....===......................#
##..............................3.....................................######...#
##.....................====..=====........................=====...............%#
##...........................................................................%%#
A...DD...........................................................CC.........%%%B
A...DD1.Y.eK.dM....s.....bN.2..wO.tP....rQ...xR..f...iU...5..4...CC........%%%%B
################################################################################
################################################################################
################################################################################
################################################################################
################################################################################
]],
  key = {
    ["Y"] = "emberlantern",
    ["K"] = "frozenkeeper:elder",
    ["M"] = "frozenkeeper:sol",
    ["N"] = "frozenkeeper:brassa",
    ["O"] = "frozenkeeper:tikka",
    ["P"] = "frozenkeeper:root",
    ["Q"] = "frozenkeeper:inks",
    ["R"] = "frozenkeeper:vill",
    ["U"] = "frozenkeeper:vill2",
    ["1"] = "sign:sign_camp_west",
    ["2"] = "sign:sign_camp_east",
    ["3"] = "capsule:cap_camp",
    ["4"] = "sign:sign_core",
    ["5"] = "checkpoint",
    ["e"] = "npc:elder:until:reckoning",
    ["d"] = "npc:sol:until:camp_frozen",
    ["b"] = "npc:brassa:until:reckoning",
    ["w"] = "npc:tikka:until:camp_frozen",
    ["t"] = "npc:root:until:camp_frozen",
    ["r"] = "npc:inks:until:camp_frozen",
    ["x"] = "npc:vill:until:camp_frozen",
    ["i"] = "npc:vill2:until:camp_frozen",
    ["s"] = "save",
    ["f"] = "npc:ferro:need:ferro_rescued:until:reckoning",
  },
  links = {
    A = { "camp_tele", "B" },
    D = { "camp_awake", "B" },
    B = { "moss_1", "A" },
    C = { "core_1", "A" },
  },
}
