-- World structure: room registry, map layout, teleporter network.
local WM = {}

WM.ROOMS = {
  "camp_awake", "camp_main", "camp_tele",
  "moss_1", "moss_2", "moss_3", "moss_4", "moss_5", "moss_well",
  "moss_boss", "moss_secret", "moss_grotto",
  "ug_1", "ug_2", "ug_3", "ug_rescue", "ug_4", "ug_5", "ug_6",
  "ug_secret", "ug_7", "ug_boss",
  "flood_1", "flood_2", "flood_3", "flood_warden", "flood_4", "flood_hub",
  "flood_5", "flood_boss", "flood_deep1",
  "furn_1", "furn_2", "furn_3", "furn_golem", "furn_4", "furn_5", "furn_6",
  "furn_boss", "furn_cache",
  "crys_1", "crys_2", "crys_3", "crys_4", "crys_5", "crys_boss", "crys_secret",
  "cold_1", "cold_2", "cold_3", "cold_4", "cold_5", "cold_secret",
  "cold_boss", "cradle_1",
  "sky_1", "sky_2", "sky_3", "sky_4", "sky_boss", "sky_secret",
  "core_1", "core_2", "core_3", "core_4", "core_boss",
}

WM.ZONE_NAMES = {
  camp = "EMBER CAMP", mosswood = "MOSSWOOD", flooded = "FLOODED WORKS",
  furnace = "FURNACE DEPTHS", crystal = "CRYSTAL HOLLOWS",
  skyroot = "SKYROOT SPIRE", core = "THE CORE",
  undergrove = "THE UNDERGROVE",
  coldstore = "THE COLDSTORE", cradle = "THE CRADLE",
}

-- map-canvas offsets (in map cells)
WM.ZONE_OFFSETS = {
  camp = { x = 10, y = 8 },
  mosswood = { x = 16, y = 8 },
  skyroot = { x = 20, y = 1 },
  flooded = { x = 26, y = 9 },
  furnace = { x = 27, y = 15 },
  crystal = { x = 17, y = 15 },
  core = { x = 2, y = 10 },
  undergrove = { x = 18, y = 11 },
  coldstore = { x = 9, y = 15 },
  cradle = { x = 9, y = 19 },
}

WM.TELEPADS = {
  { id = "camp", room = "camp_tele", door = "B", label = "EMBER CAMP - old hub" },
  { id = "flooded", room = "flood_hub", door = "A", label = "FLOODED WORKS - dry deck" },
  { id = "furnace", room = "furn_3", door = "C", label = "FURNACE DEPTHS - cooling station" },
  { id = "crystal", room = "crys_2", door = "C", label = "CRYSTAL HOLLOWS - song chamber" },
  { id = "skyroot", room = "sky_2", door = "C", label = "SKYROOT SPIRE - branch landing" },
  { id = "core", room = "core_2", door = "C", label = "THE CORE - antechamber" },
  { id = "undergrove", room = "ug_3", door = "C", label = "THE UNDERGROVE - root hollow" },
  { id = "coldstore", room = "cold_2", door = "A", label = "THE COLDSTORE - reading room" },
}

return WM
