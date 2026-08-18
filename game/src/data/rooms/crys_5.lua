-- THE JUNCTION. The zone's exam, and the one circuit that needs both
-- of them.
--
-- The node wants TWO beams. One falls straight down the shaft from the
-- emitter above it. The other falls at col 14, six slots away from
-- where the reflector panel is parked -- and only Vess's charge moves a
-- panel. Set the panel first, then wake both emitters.
--
-- The last span before the arena is a vane lock: the Hollows are built
-- upward and the city expected its caretakers to be able to hold a
-- glide. Take the Spire first.
--
-- Note what is NOT required: nothing has to happen at the same instant.
-- The panel stays where it is shoved, so one bot can do all of this by
-- swapping, slowly. Co-op just means nobody has to walk back.
return {
  zone = "crystal", music = "crystal",
  mapPos = { x = 9, y = 0, w = 3, h = 1 },
  map = [[
############################################################
############################################################
##...............................H..................I.....##
##......5........................H..................I.....##
##.n....%%.......................H..................I.....##
##....#######.............w....w.H..................I.....##
##.............w.........w..u....H..........u.......I.....##
##..........w.e...............f..H..................I.....##
##........=======.......=======..H......=======.....I.....##
##...............................H..................I.....##
##...............................H..................I.....BB
##.........pd..d....1......d.do..H..w...............I.....BB
######...#################################%#################
######...###############################.....###############
######...###############################..8..###############
######AAA###################################################
######AAA###################################################
]],
  gates = { H = "crys_bus5", I = "driftvanes" },
  gateStyle = { H = "curtain" },
  key = {
    ["8"] = "chest:chest_crys5b:scrap:25",

    ["n"] = "anchor",
    ["d"] = "shardling",
    ["u"] = "cryoturret",
    ["w"] = "prismwisp",
    ["5"] = "capsule:cap_crys",
    ["e"] = "emitter:down:dormant:9",
    ["f"] = "emitter:down:dormant:9",
    ["p"] = "panel:h:b:3",
    ["o"] = "node:crys_bus5:2",
    ["1"] = "sign:sign_resonance",
  },
  links = {
    A = { "crys_4", "B" },
    B = { "crys_boss", "A" },
  },
}
