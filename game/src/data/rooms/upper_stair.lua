-- THE UPPER STAIR. The half of the service column that goes up.
--
-- The Deep Stairs run from the Junction down through every zone the
-- city buried. This is the other direction: one shaft from the Junction
-- to the Skyroot arena at the top, and the way home from the Aerie
-- Sentinel.
--
-- It is a THERMAL COLUMN the whole way. Coming DOWN needs nothing --
-- you fall, and the landings catch you -- which is what makes it a
-- shortcut the moment the Sentinel is dead. Going UP needs the Drift
-- Vanes, and by the time you have them you have already been to the top
-- the long way. The shaft is the reward for that trip, not the route.
return {
  zone = "camp", music = "camp",
  arena = "deepstair",
  mapPos = { x = 7, y = 0, w = 1, h = 2 },
  map = [[
#############AAA##############
#############AAA##############
##..........................##
##..........................##
##..........................##
##...=======................##
##..........................##
##..........................##
##................========..##
##..........................##
##..........................##
##.======...................##
##..........................##
##..........................##
##...............=======....##
##..........................##
##..........................##
##..=======.................##
##..........................##
##..........................##
##................=======...##
##..........................##
##..........................##
##..======..................##
##..........................##
##....n.......U.............##
#############BBB##############
#############BBB##############
]],
  key = {
    ["U"] = "updraft:24",
    ["n"] = "anchor",
  },
  links = {
    A = { "sky_boss", "B", req = "boss_aeriesentinel" },
    B = { "stair_junction", "D" },
  },
}
