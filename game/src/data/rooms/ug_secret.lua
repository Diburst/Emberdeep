-- A hoard pocket under the roots. Somebody cached supplies here long ago,
-- and the well water has been adding to the pile ever since -- Tikka's
-- music box among the rest.
return {
  zone = "undergrove", music = "undergrove",
  mapPos = { x = 6, y = 3, w = 1, h = 1 },
  dark = 0.75,
  map = [[
##############AAA#############
##############AAA#############
##..........................##
##..........................##
##..........................##
##...........=====..........##
##..........................##
##..........................##
##.........=====............##
##..........................##
##.................1........##
##...............=====......##
##..........................##
##.b.8..b...............9...##
##############################
##############################
##############################
]],
  key = {
    ["1"] = "chest:musicbox_chest:module:musicbox",
    ["8"] = "chest:chest_ugsec:scrap:40",
    ["9"] = "chest:chest_ugsec2:bigshard:6",
    ["b"] = "sporebulb",
  },
  links = {
    A = { "ug_6", "D" },
  },
}
