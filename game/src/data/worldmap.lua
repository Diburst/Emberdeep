-- World structure: room registry, map layout, teleporter network.
local WM = {}

WM.ROOMS = {
  "camp_awake", "camp_main", "camp_tele", "camp_hut",
  "stair_junction", "upper_stair",
  "deep_stair_1", "deep_stair_2",
  "moss_1", "moss_2", "moss_3", "moss_4", "moss_5", "moss_well",
  "moss_boss", "moss_secret", "moss_grotto",
  "ug_1", "ug_2", "ug_3", "ug_rescue", "ug_4", "ug_5", "ug_6",
  "ug_secret", "ug_7", "ug_boss",
  "flood_1", "flood_2", "flood_3", "flood_warden", "flood_4", "flood_hub",
  "flood_5", "flood_boss", "flood_deep1",
  "furn_1", "furn_2", "furn_3", "furn_golem", "furn_4", "furn_5", "furn_6",
  "furn_boss", "furn_cache",
  "scrap_1", "scrap_2", "scrap_3", "scrap_4", "scrap_bay", "scrap_5",
  "scrap_secret", "scrap_6", "scrap_boss",
  "crys_1", "crys_2", "crys_3", "crys_4", "crys_5", "crys_boss", "crys_secret",
  "cold_1", "cold_2", "cold_3", "cold_4", "cold_5", "cold_secret",
  "cold_boss", "cradle_1",
  "sky_1", "sky_2", "sky_3", "sky_4", "sky_boss", "sky_secret",
  "sky_nest", "gal_1", "gal_2", "gal_3",
  "core_1", "core_2", "core_3", "core_4", "core_boss",
}

WM.ZONE_NAMES = {
  camp = "EMBER CAMP", mosswood = "MOSSWOOD", flooded = "FLOODED WORKS",
  furnace = "FURNACE DEPTHS", crystal = "CRYSTAL HOLLOWS",
  skyroot = "SKYROOT SPIRE", core = "THE CORE",
  undergrove = "THE UNDERGROVE",
  coldstore = "THE COLDSTORE", cradle = "THE CRADLE",
  scrapyard = "THE SCRAPYARD",
}

-- map-canvas offsets (in map cells)
WM.ZONE_OFFSETS = {
  camp = { x = 8, y = 8 },
  -- The archive is behind ug_secret's east wall now, so it has to be
  -- DRAWN behind ug_secret's east wall: undergrove sits at (11,14) and
  -- ug_secret at (7,3) within it, which puts its right edge at 18,17.
  coldstore = { x = 19, y = 17 },
  core = { x = 29, y = 17 },
  -- ...and the Cradle sits immediately past the Threshold it is behind,
  -- instead of 12 cells away across the Core.
  cradle = { x = 39, y = 17 },
  crystal = { x = 30, y = 14 },
  flooded = { x = 23, y = 6 },
  furnace = { x = 31, y = 10 },
  mosswood = { x = 11, y = 7 },
  scrapyard = { x = 23, y = 12 },
  skyroot = { x = 12, y = 1 },
  undergrove = { x = 11, y = 14 },
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
