-- THE JUNCTION. The middle landing of the city's service stairwell, and
-- from here on the hub of the whole map.
--
-- The Deep Stairs used to be entered from moss_5, four rooms into
-- Mosswood, which meant the vertical column that reaches almost every
-- zone was hidden behind the first zone. It is one room from Embercamp
-- now, and the road to Mosswood runs straight through it -- so the
-- stairwell is a place you know about long before you can use most of
-- it.
--
-- Four ways out:
--   A  west   Embercamp
--   B  east   Mosswood
--   C  down   the Deep Stairs, and through them the rest of the city
--   D  up     the Upper Stair, and the Skyroot arena at the top of it
--
-- D is a THERMAL COLUMN and nothing else. Without the Drift Vanes the
-- ceiling is simply a ceiling; with them the shaft above opens up, which
-- is why the way home from the Aerie Sentinel lands here.
return {
  zone = "camp", music = "camp",
  arena = "deepstair",
  mapPos = { x = 6, y = 2, w = 2, h = 1 },
  map = [[
#####################DDD################
#####################DDD################
##....................................##
##....................................##
##.......................=====........##
##....................................##
##....................................##
##...........=====....................##
##....................................##
###...................................##
####......................======......##
###...................................##
##....................................##
##..........=====.....................##
##....................................##
##....................................##
##......................======........##
A......................................B
A......1..............U..........z.....B
##########.........#####################
###########...C...######################
#############.C.########################
########################################
]],
  key = {
    ["U"] = "updraft:17",
    ["z"] = "checkpoint",
    ["1"] = "sign:sign_junction",
  },
  links = {
    A = { "camp_main", "B" },
    B = { "moss_1", "A" },
    -- SEALED UNTIL THE MAW IS DOWN. Without this the Junction hands the
    -- whole city over on the first walk out of camp: the reachability
    -- model goes camp -> Junction -> Deep Stairs -> furn_1 and kills the
    -- CRUCIBLE before it has picked up the Spark Jump. Moving the
    -- stairwell next to camp was the point; opening it there was not.
    -- One line, and the intended order is back.
    C = { "deep_stair_1", "A", req = "boss_bramblemaw" },
    D = { "upper_stair", "B" },
  },
}
