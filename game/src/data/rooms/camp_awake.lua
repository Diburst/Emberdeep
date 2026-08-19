-- Jun's maintenance shop: where Vess and Lu boot up. Cluttered with
-- benches, tools and cable runs (see drawArenaBackdrop 'campshop').
-- Jun teaches the basics here in person -- there is no signage any more.
return {
  zone = "camp", music = "camp",
  arena = "campshop",
  mapPos = { x = 4, y = 3, w = 2, h = 1 },
  map = [[
########################################
########################################
##....................................##
##....................................##
##....................................##
##.............................####...##
##......................9.............##
##...................====.............##
##....................................##
##.......======.......................##
##......A.....................====....##
##......A.........................BB..##
##..........j..W....t...1...2.....BB.z##
########################################
##....................................##
##....................................##
########################################
]],
  hasTeleporter = true,
  key = {
    -- THE EMBERCAMP PAD, moved out of the old hub room and into the
    -- shop you wake up in. A room whose only job was holding a
    -- teleporter was a room you walked through, never to.
    ["t"] = "teleporter:camp",
    ["1"] = "sign:sign_camp_west",
    ["2"] = "chest:chest_camptele:scrap:6",
    ["9"] = "chest:ch_shelf:scrap:15",
    ["j"] = "npc:jun:until:camp_witness",
    ["W"] = "frozenkeeper:jun",
    ["z"] = "checkpoint",
  },
  links = {
    B = { "camp_main", "D" },
  },
}
