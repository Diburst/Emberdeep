-- THE STACK. A climbing shaft, and the room where the beam stops being
-- a lock and becomes a weapon -- and then goes on being a lock anyway.
--
-- The emitter on the shelf is dormant and points along its own ledge,
-- straight through the cryoturret that owns that shelf and into a NODE
-- at the far end. So one two-second channel does both jobs at once:
-- the turret is gone, and the circuit that drops the curtain over the
-- way out is closed. Nothing here is decoration.
--
-- Deliberately no panel and no rotor: a hostile beam laid across a
-- vertical shaft has no fair answer, because a ROTOR can only ever
-- shorten a beam from the mirror onward -- it cannot protect anything
-- standing between the emitter and itself. Aiming is the rotor's job;
-- making a room safe is the panel's, and a panel wants a floor to run
-- along. This shaft has neither. The beam here is short, level, and
-- entirely on its own shelf, which is why it is allowed to exist.
return {
  zone = "crystal", music = "crystal",
  mapPos = { x = 9, y = 1, w = 1, h = 2 },
  map = [[
##############BBB#############
##############BBB#############
##############HHH#############
##..............9...........##
##............#######.......##
##.........===..............##
##..........................##
##...ou...e.................##
##..#######.................##
##..........................##
##..................n.......##
##............===...........##
##..........................##
##....................w.....##
##................#######...##
##..........................##
##........n.................##
##.............====.........##
##..........................##
##..........d...............##
##......#######.............##
##.............===..........##
##..........................##
##......................z...##
##..................#######.##
##..............===.........##
AA..........................##
AA..........................##
##############################
##############################
##############################
##############################
]],
  gates = { H = "crys_bus4" },
  gateStyle = { H = "curtain" },
  key = {
    ["9"] = "chest:chest_lance:weapon:arclance",
    ["n"] = "anchor",
    ["u"] = "cryoturret",
    ["w"] = "prismwisp",
    ["d"] = "shardling",
    ["z"] = "checkpoint",
    ["o"] = "node:crys_bus4",
    ["e"] = "emitter:left:dormant:14",
  },
  links = {
    A = { "crys_3", "B" },
    B = { "crys_5", "A" },
  },
}
