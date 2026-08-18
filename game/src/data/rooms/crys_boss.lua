-- THE SCHEDULER'S FLOOR.
--
-- The Conductor is SHIELDED by default and the beam circuit is the only
-- thing that opens it. Everything in this room exists to serve one
-- sequence: work out which of the three images is real, park the
-- reflector beneath it, get Lu to that station's emitter, and hold the
-- channel.
--
-- THREE INDEPENDENT RUNS. A mirror turns a beam ninety degrees, so it
-- can never send one back up the column it came down: the final leg
-- into the boss has to be vertical and upward, which means the beam has
-- to be travelling along the FLOOR before it gets there. Hence a
-- reflector beneath each station. One shared floor beam would not work
-- -- the panel nearest the emitter would always intercept it and the
-- other two stations could never be reached -- so each station has its
-- own emitter (row 4), its own fixed corner mirror (row 16), and its
-- own panel.
--
--   emitter   col 5 (updraft)    col 24 (climb)    col 54 (updraft)
--   mirror    col 5   b          col 24   b        col 54   f
--   panel     cols 9-15  f       cols 27-33  f     cols 45-51  b
--   station   col 12 +/-3T       col 30 +/-3T      col 48 +/-3T
--
-- THE TRACK AND THE JITTER ARE THE SAME WINDOW. Each station re-rolls
-- its exact column by up to three tiles every cycle, and each panel's
-- rail is exactly six slots wide. The jitter is not decoration: it is
-- the entire reason the rail exists. Fixed stations would mean solving
-- the aim once and never thinking about it again.
--
-- THE OUTER TWO PERCHES ARE VANE-ONLY. Thermal columns at cols 3 and 56
-- are the only way up to the left and right emitters. The centre one is
-- plain climbing -- row 13, row 11, row 9, row 7, row 5 -- so a third of
-- the time the answer is easy, and that is where the shape gets taught.
--
-- THE FLOOR LEG IS HOT. Every beam here is a real beam: it burns players
-- standing in it and it kills the wisps outright. The stretch of floor
-- between a mirror and its panel is genuinely dangerous ground, and a
-- badly aimed beam is a hazard you built yourself.
return {
  zone = "crystal", music = "crystal",
  arena = "prismtyrant",
  mapPos = { x = 12, y = 0, w = 3, h = 1 },
  map = [[
##############################################################
##############################################################
##..........................................................##
##..........................................................##
##...e..................e.............................e.....##
##===...............====...............................===..##
##..........................................................##
##..................===.....................................##
##..........................................................##
##.......................==========.........................##
##..........................................................##
##....................=====.................................##
##..........................................................##
##..........=========..................=========............##
##..........................................................##
AA.........................................................B.#
AA.U.m...p..............m..p..t..............q........k.U..B.#
##############################################################
##############################################################
##############################################################
##############################################################
##############################################################
]],
  key = {
    ["t"] = "boss:prismtyrant",
    ["e"] = "emitter:down:dormant:1",
    ["m"] = "mirror:b",
    ["k"] = "mirror:f",
    ["p"] = "panel:h:f:6",
    ["q"] = "panel:h:b:6",
    ["U"] = "updraft:12",
  },
  links = {
    B = { "deep_stair_1", "F", req = "boss_prismtyrant" },
    A = { "crys_5", "B" },
  },
}
