# Building & hacking on EMBERDEEP

The whole game is plain Lua on the [LÖVE 11.5](https://love2d.org) engine.
No compile step — the source *is* the game.

## Layout

    main.lua              engine bootstrap: fixed timestep, canvas, input wiring
    conf.lua              window/identity config
    src/core/             class, utils, serializer, state stack
    src/input.lua         2-player pad+keyboard input, rebinding
    src/physics.lua       tile AABB platformer physics
    src/world.lua         room loading, tiles, entities, particles, drawing
    src/camera.lua        co-op midpoint camera + shake
    src/weapons.lua       weapon definitions (damage/levels/XP thresholds)
    src/items.lua         item/module grant system
    src/save.lua          settings + 3 save slots (atomic writes)
    src/entities/         player (both bots), enemies (19), bosses (8),
                          projectiles, pickups, props, NPCs
    src/states/           title, save select, options, controls remap, game,
                          pause, map, teleport, intro, ending, loading
    src/ui/               menu widget, HUD, dialogue textbox
    src/audio/            SFX synthesizer + chiptune tracker (12 songs, all
                          rendered from note data at load — no audio files)
    src/assets/           palette, 5x7 bitmap font, ASCII pixel-art sprite
                          compiler, procedural tile/background generator
    src/data/rooms/       47 rooms as ASCII maps (see any file for the format)
    src/data/dialogue.lua all NPC/sign text, flag-gated
    src/data/worldmap.lua room registry, map layout, teleporter network
    src/test*.lua         headless test harness (see below)
    scripts/              room generator/validator (Python, dev-time only)

## Run from source

Install LÖVE 11.5, then from this directory:

    love .

## Tests

Headless scenarios (need a display or xvfb; they drive virtual input and
write logs to /tmp/emberdeep_test.log):

    EMBERDEEP_TEST=links love .     # door graph validation
    EMBERDEEP_TEST=sweep love .     # load + simulate every room
    EMBERDEEP_TEST=play love .      # co-op verbs (fire/dome/link/dash)
    EMBERDEEP_TEST=solo love .      # solo swap/recall
    EMBERDEEP_TEST=revive love .    # down/revive/wipe-respawn
    EMBERDEEP_TEST=saveload love .  # save slot + settings roundtrip
    EMBERDEEP_TEST=bossflow love .  # boss triggers, shields, rewards
    EMBERDEEP_TEST=mender love .    # final boss through ending+credits

## Packaging

1. Zip the source (main.lua at zip root!) as `emberdeep.love`:

       zip -9 -r emberdeep.love main.lua conf.lua src

2. **Windows**: with the LÖVE 11.5 win64 release:

       cat love.exe emberdeep.love > Emberdeep.exe

   Ship the exe next to all the DLLs from the LÖVE zip.

3. **macOS (Apple Silicon + Intel)**: with the LÖVE 11.5 macOS release
   (love.app is a universal binary):
   - copy `emberdeep.love` into `love.app/Contents/Resources/`
   - patch `Contents/Info.plist`: set CFBundleName/CFBundleIdentifier,
     remove UTExportedTypeDeclarations + CFBundleDocumentTypes
   - rename to `Emberdeep.app`, zip with `zip -9 -ry` (keeps symlinks)
   - unsigned: first launch needs right-click → Open (Gatekeeper)

4. **Linux**: just run the .love with LÖVE, or use an AppImage kit.

## Handy dev facts

- Room maps: `#` solid, `.` air, `=` one-way, `~` water, `L` lava,
  `%` breakable, `c` crumble, `^v<>` spikes, `A`-`F` doors (edge tiles
  auto-transition, interior ones are press-up portals), `G`-`J` gates
  (room `gates` table maps them to flags; `!flag` = inverted "energy
  bridge"), anything else spawns via the room's `key` table.
- All balance lives in obvious tables: `weapons.lua`, per-enemy defs in
  `enemies.lua`, boss HP in `bosses.lua`, difficulty multipliers in
  `player.lua` (damage) and `enemies.lua`/`bosses.lua` (HP).
- F11 fullscreen, F12 screenshot (to the save dir) at any time.
