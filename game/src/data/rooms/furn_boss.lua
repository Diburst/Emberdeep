-- THE CRUCIBLE's foundry floor.
--
-- floodRow = 16 is the standing row; row 17 below it is the GRATE the
-- pouring pots' lava sits on for six seconds and then drains back
-- through. The two pots (p, q) hang directly over the two big refuge
-- platforms on purpose: players can only aim straight up, so "climb to
-- the safe place and shoot the thing above you" is one motion.
--
-- The three tiles at row 14 cols 29-31 are the centre perch -- the only
-- refuge under the boss, level with the two existing stubs so a plain
-- 3-row jump reaches it with no modules, and small enough that two bots
-- and a slagling tide cannot all share it. It is also the only refuge you
-- can shoot the boss from, so a flood is pressure rather than downtime.
return {
  zone = "furnace", music = "furnace",
  arena = "crucible",
  mapPos = { x = 12, y = 0, w = 3, h = 1 },
  floodRow = 16,
  map = [[
######AAA###################################################
######AAA###################################################
##........................................................##
##.......p...................................q............##
##........................................................##
##..=====.................................................##
##........................................................##
##........................................................##
##..=====.................................................##
##........................................................##
##........................................................##
##..=====.................................................##
##........................................................##
##....==========............................==========....##
##...............===.........===.........===..............##
##............B...........................................##
##....1.......B.....t.....................................##
############################################################
############################################################
############################################################
############################################################
############################################################
]],
  key = {
    ["t"] = "boss:crucible",
    ["1"] = "sign:sign_link2",
    ["p"] = "cruciblepot:left",
    ["q"] = "cruciblepot:right",
  },
  links = {
    B = { "deep_stair_1", "E", req = "boss_crucible" },
    A = { "furn_6", "B" },
  },
}
