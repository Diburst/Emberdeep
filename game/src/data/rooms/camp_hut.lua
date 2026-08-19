-- The long hut: the biggest shelter in Ember Camp, and the only one you
-- can walk into. Bunks, a stove, drying lines. Most of the keepers live
-- their indoor life here, which is why the camp outside is not a crowd.
return {
  zone = "camp", music = "camp",
  arena = "camphut",
  mapPos = { x = 3, y = 3, w = 1, h = 1 },
  map = [[
##############################
##############################
##############################
##############################
##..........................##
##..........................##
##..........................##
##.....====.........====....##
##..........................##
##..........................##
##.............AA...........##
##.w.O.t.P.r.Q.AA..x.R......##
##############################
##############################
##############################
##############################
##############################]],
  key = {
    ["w"] = "npc:tikka:until:camp_witness",
    ["O"] = "frozenkeeper:tikka",
    ["t"] = "npc:root:until:camp_witness",
    ["P"] = "frozenkeeper:root",
    ["r"] = "npc:inks:until:camp_witness",
    ["Q"] = "frozenkeeper:inks",
    ["x"] = "npc:vill:until:camp_witness",
    ["R"] = "frozenkeeper:vill",
  },
  links = {
    A = { "camp_main", "E" },
  },
}
