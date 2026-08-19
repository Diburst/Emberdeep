-- A hoard pocket under the roots. Somebody cached supplies here long ago,
-- and the well water has been adding to the pile ever since -- Tikka's
-- music box among the rest.
return {
  zone = "undergrove", music = "undergrove",
  mapPos = { x = 7, y = 3, w = 1, h = 1 },
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
##........................%%BB
##.b.8..b...........x...9.%%BB
##############################
##############################
##############################
]],
  key = {
    ["x"] = "frostpatch:6",
    ["1"] = "chest:musicbox_chest:module:musicbox",
    ["8"] = "chest:chest_ugsec:scrap:40",
    ["9"] = "chest:chest_ugsec2:bigshard:6",
    ["b"] = "sporebulb",
  },
  links = {
    A = { "ug_6", "D" },
    -- THE WAY INTO THE COLDSTORE. Behind two courses of shootable wall,
    -- with rime spilling out from under them onto floor that has no
    -- business being cold. ug_secret is already a room you only stand in
    -- if you went looking, so a player who gets this far has proved they
    -- explore -- which is exactly who the archive is written for.
    B = { "cold_1", "A" },
  },
}
