-- THE READING ROOM -- save, teleport pad, and the zone's third verb
-- taught where nothing can go wrong, and then required once.
--
-- The emitter on the shelf is DORMANT: dark, inert, and a century past
-- its last work order. Lu climbs the two steps, stands next to it and
-- holds a dome on it for two seconds; half her bar goes into the
-- machine and the machine wakes up. It fires the length of the hall,
-- well over the walking row, into the NODE at col 47.
--
-- That circuit is the curtain at col 48 -- floor to ceiling, the only
-- way out of this room. So the zone's third verb is not a demonstration
-- you can walk past: you learn it standing next to a save point, with a
-- sign at your feet and nothing in the room that can hurt you, and then
-- you use it. The crawl to the cache is behind the curtain too.
--
-- The two shelves are load-bearing in the literal sense: without the
-- step at row 9 the emitter shelf is five rows off the floor, and a
-- two-second channel cannot be held from the top of a jump.
return {
  zone = "crystal", music = "crystal",
  mapPos = { x = 3, y = 1, w = 3, h = 1 },
  hasTeleporter = true,
  gates = { H = "crys_bus2" },
  gateStyle = { H = "curtain" },
  map = [[
############################################################
############################################################
##..............................................H.........##
##..............................................H.........##
##..............................................H.........##
##..............................................H.........##
##....................e.w......................oH.........##
##....................=======................===H.........##
##..............................................H.........##
##................====..........................H...%.....##
AA..............................................H...%EE...BB
AA......s.....t.....1.........w.............u...H...%EE...BB
############################################################
############################################################
############################################################
############################################################
############################################################
]],
  key = {
    ["s"] = "checkpoint",
    ["t"] = "teleporter:crystal",
    ["w"] = "prismwisp",
    ["u"] = "cryoturret",
    ["e"] = "emitter:right:dormant:14",
    ["o"] = "node:crys_bus2",
    ["1"] = "sign:sign_dormant",
  },
  links = {
    A = { "crys_1", "B" },
    B = { "crys_3", "A" },
    E = { "crys_secret", "A" },
  },
}
