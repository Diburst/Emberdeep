-- Root Hollow: the Undergrove waystation. The deep doors are sealed to the lightless.
return {
  zone = "undergrove", music = "undergrove",
  mapPos = { x = 3, y = 0, w = 1, h = 1 },
  dark = 0.7,
  hasSave = true,
  hasTeleporter = true,
  gates = { H = "lumecore" },
  map = [[
##############################
##############################
##.......................H..##
##.......................H..##
##.......................H..##
##.......................H..##
##.......................H..##
##.......................H..##
##.......................H..##
##.......................H..##
AA.......................H..BB
AA..................1....H..BB
##...t..s...........#....H..##
##############...#############
##############...#############
##############DDD#############
##############DDD#############
]],
  key = {
    ["t"] = "teleporter:undergrove",
    ["s"] = "save",
    ["1"] = "sign:sign_roothollow",
  },
  links = {
    A = { "ug_2", "B" },
    B = { "ug_4", "A" },
    D = { "ug_rescue", "A" },
  },
}
