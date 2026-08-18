-- THE SPAN. The light bridge stays exactly as it was -- two plates, one
-- of you stays behind -- and above it the zone teaches its second verb.
--
-- A curtain falls from the emitter at col 53, straight down across the
-- corridor, and the floor is the only way east. The REFLECTOR PANEL
-- answers to one thing in this game and one thing only: Vess's CHARGE.
-- Its rail runs along the CATWALK at head height, cols 49 to 53, and
-- the catwalk is why the puzzle works: a panel parked on the floor can
-- only ever catch the beam at the bottom of its fall, which moves the
-- hazard rather than clearing it. Caught at row 8 instead, the beam is
-- turned east along the catwalk into the node at col 56 -- and the
-- whole corridor below is clean.
--
-- Four slots, not three. The panel starts at col 49 and the beam falls
-- at col 53; a three-slot rail stops one tile short of it, and a
-- circuit that cannot be closed is indistinguishable from one the
-- player has not solved yet. tools/checkbeams.py traces every emitter
-- through every legal panel position now, so that cannot recur.
return {
  zone = "crystal", music = "crystal",
  mapPos = { x = 6, y = 1, w = 3, h = 1 },
  gates = { G = "!bridge_c3", H = "crys_bus3" },
  gateStyle = { H = "curtain" },
  map = [[
##############################################################
##############################################################
#####.......................................#######........H##
###..........w................................##...........H##
##.........................................................H##
##....w.....................................w..............H##
##......................w...........w............#...e.....H##
##.........................................................H##
##..........w.....................w..........2...p......o..H##
##.........................................===============.H##
AA.........................................................HBB
AA..1...x................................4....y............HBB
##############GGGGGGGGGGGGGGG##GGGGGGGGGGGGGGG################
##############...............##...............################
##############...............##...............################
###############..............##..............#################
###############^^^^^^^^^^^^^^##^^^^^^^^^^^^^^#################
##############################################################
]],
  key = {
    ["x"] = "plate:bridge_c3",
    ["y"] = "plate:bridge_c3",
    ["1"] = "sign:sign_bridge",
    ["w"] = "prismwisp",
    ["4"] = "tank:tank_crys",
    ["e"] = "emitter:down",
    ["p"] = "panel:h:b:4",
    ["o"] = "node:crys_bus3",
    ["2"] = "sign:sign_panel",
  },
  links = {
    A = { "crys_2", "B" },
    B = { "crys_4", "A" },
  },
}
