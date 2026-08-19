-- Ember Camp: the hub. Lantern light, NPCs, save statue.
return {
  zone = "camp", music = "camp",
  arena = "embercamp",
  mapPos = { x = 2, y = 2, w = 4, h = 1 },
  gates = { G = "camp_barricade" },
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
##.....................====..=====........................=====...............G#
##...........................................................................GG#
....DD..........E................................................##.........GGGB
....DD1......dM.E........bN.2.OtPoQp.Y..eKRqSu..Vf...iU...5..4...##.....k..GGGGB
################################################################################
################################################################################
################################################################################
################################################################################
################################################################################
]],
  key = {
    ["Y"] = "emberlantern",
    ["k"] = "linkcore:camp_barricade",
    ["K"] = "frozenkeeper:elder",
    ["M"] = "frozenkeeper:sol",
    ["N"] = "frozenkeeper:brassa",
    ["U"] = "frozenkeeper:vill2",
    ["1"] = "sign:sign_camp_west",
    ["2"] = "sign:sign_camp_east",
    ["3"] = "capsule:cap_camp",
    ["4"] = "sign:sign_core",
    ["5"] = "checkpoint",
    ["e"] = "npc:elder:until:reckoning:until:camp_frozen",
    ["d"] = "npc:sol:until:camp_frozen",
    ["b"] = "npc:brassa:until:reckoning:until:camp_frozen",
    ["i"] = "npc:vill2:until:camp_frozen",
    ["f"] = "npc:ferro:need:ferro_rescued:until:reckoning:until:camp_frozen",
    -- THE WITNESSES. Everyone who lives in the side rooms comes here the
    -- moment the Ember comes loose, and stands in the dark watching it
    -- until the camp finally freezes. Their home-room copies switch off
    -- on the same flag, so nobody is ever in two places.
    ["t"] = "npc:tikka:need:camp_witness:until:camp_frozen",
    ["o"] = "npc:root:need:camp_witness:until:camp_frozen",
    ["p"] = "npc:inks:need:camp_witness:until:camp_frozen",
    ["q"] = "npc:vill:need:camp_witness:until:camp_frozen",
    ["u"] = "npc:jun:need:camp_witness:until:camp_frozen",
    -- ...and what is left of them afterwards. Every witness gets a body:
    -- without these five the visitors simply blinked out when the camp
    -- froze, which reads as a despawn bug rather than as an ending.
    ["O"] = "frozenkeeper:tikka",
    ["P"] = "frozenkeeper:root",
    ["Q"] = "frozenkeeper:inks",
    ["R"] = "frozenkeeper:vill",
    ["S"] = "frozenkeeper:jun",
    -- FROZEN_LINES has carried a line for Ferro since it was written and
    -- no room ever placed him. It is the best line in the set.
    ["V"] = "frozenkeeper:ferro",
  },
  links = {
    E = { "camp_hut", "A" },
    D = { "camp_awake", "B" },
    B = { "stair_junction", "A" },
  },
}
