-- THE CRUCIBLE's foundry floor.
--
-- floodRow = 17 is the BASIN: row 17 is open only between cols 10 and 48,
-- and solid either side, so the middle of the floor sits a tile lower
-- than its two ends. A pour opens two fronts at the spout that crawl one
-- tile every half second until they hit that higher ground -- which is
-- what makes the raised ends worth running to. Row 18 under the basin is
-- the GRATE the pool drains back down through.
--
-- The two pots (p, q) hang directly over the two big shelves on purpose:
-- players can only aim straight up, so "climb to the safe place and
-- shoot the thing above you" is one motion.
--
-- The three tiles at row 14 cols 29-31 are the centre perch -- the only
-- refuge under the boss, level with the two existing stubs so a plain
-- 3-row jump reaches it with no modules, and small enough that two bots
-- and a slagling tide cannot all share it. It is also the only refuge you
-- can shoot the boss from, so a flood is pressure rather than downtime.
return {
  zone = "furnace", music = "furnace",
  arena = "crucible",
  mapPos = { x = 14, y = 3, w = 3, h = 1 },
  floodRow = 17,
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
##............t...........................................##
##....==========............................==========....##
##........................................................##
##...............===.........===.........===.........B....##
##....1..............................................B....##
##########.......................................###########
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
