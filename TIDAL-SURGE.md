# Tide Engine — Tidal Surge

A walkthrough of the mechanic added on 2026-08-13, written for someone who
wants to understand and tweak it rather than just run it.

## What it does

Three times per fight — the moment the Tide Engine's health drops past
**75%, 50% and 25%** — the boss stops what it's doing and:

1. **Inhales for 2 seconds.** The room's water level visibly drains, the
   screen rattles harder and harder, spray gets dragged toward the machine,
   the boss switches to a "shutters open, core white-hot" sprite, and a
   glowing bar lights up on whichever wall the blast will come from.
2. **Fires.** A wall of water spawns off-screen at that wall and crosses the
   entire room, floor to ceiling, at 340 pixels per second.
3. **Anything the wall touches takes heavy damage** — 4 / 6 / 8 on
   Story / Normal / Veteran — *unless* that body is inside an active dome.
   Then Lu's shield eats it instead, at a cost of 5 energy per person
   sheltered.

There is no other cover. You cannot jump it, you cannot hide behind the
valves, you cannot duck under the water. The dome is the answer.

## The three files that changed

### 1. `game/src/entities/bosses.lua` — the behaviour

This is where all the actual logic lives. Everything is inside the
`Tideengine` section (search the file for `3. TIDE ENGINE`).

**Six tuning knobs at the top.** These are the numbers to change if the
fight feels wrong:

```lua
local SURGE_AT = { 0.75, 0.5, 0.25 }  -- health fractions that trigger it
local SURGE_CHARGE = 2.0              -- seconds of telegraph before it fires
local SURGE_SPEED = 340               -- pixels/second the wall travels
local SURGE_HALFW = 16                -- half-thickness of the killing edge
local SURGE_DMG = { 4, 6, 8 }         -- Story / Normal / Veteran
local SURGE_DOME_COST = 5             -- energy bite for sheltering one body
```

Want four surges instead of three? Add a number to `SURGE_AT`. Too hard to
react to? Raise `SURGE_CHARGE` to 2.5. Too easy to outrun? Raise
`SURGE_SPEED`. That's the whole balance surface.

**`Tideengine:init`** gained two lines. `surgeIdx` remembers which health
line the boss is waiting to cross next (1, then 2, then 3). `surgeDir`
remembers which side the last blast came from, so they alternate
left-right-left instead of always coming from the same wall.

**`Tideengine:beginSurge`** is the new "start the attack" function. It flips
the direction, parks the wall just outside the room on the correct side,
starts the charge-up sound, and posts the on-screen warning. Note that it
sets the state to `"surge"` — this game's bosses are state machines, where
`self.state` is a string naming what the boss is currently doing, and
`self.phaseT` counts seconds since the state began. Everything after this
is driven by that clock.

**`Tideengine:surgeDamage`** is the new "did the wall hit anybody" function.
For each player, it checks whether they're horizontally within `SURGE_HALFW`
of the wall. If so, it then loops over *every* player asking "is anyone's
dome up, and is this body inside its radius?" If yes, the dome owner pays
energy via `domeAbsorb` and the hit is cancelled. If no, `takeDamage` fires.
`self.surgeHit` is a lookup table that guarantees each player is only hit
once per surge, so standing still inside the wall doesn't shred you frame
by frame.

This dome-check pattern is copied deliberately from the Mender's sweeping
beam further down the same file — same shape, so the two attacks feel
consistent and there's only one idea to maintain.

**`Tideengine:update`** got four changes:

- Added `self.phaseT = self.phaseT + dt` at the top. The Tide Engine never
  used its phase clock before; the surge needs it.
- The water-level code now knows about surges: during the charge it drives
  the water *down* (the machine is drinking the room), and once the blast
  fires it slams the level back up.
- A new trigger block after the intro check. It compares current health to
  the next threshold and calls `beginSurge`. The `while` loop inside it
  handles one edge case: if you land a huge hit that crosses two thresholds
  at once, you get one surge, not two back to back.
- A new `if self.state == "surge"` branch that runs the three beats —
  charge, fire, sweep — and hands control back to the normal `bubbles`
  attack pattern when the wall leaves the room.

**`Tideengine:draw`** got the visuals: collapsing intake rings around the
core and the pulsing wall-warning bar during the charge, then the wall
itself once it fires — a wide translucent body of water, a darker core, and
the animated foam crest tiled from ceiling to floor.

**`Tideengine:onDeath`** now clears the surge fields, so killing the boss
mid-blast doesn't leave anything behind.

### 2. `game/src/assets/sprites/bosses.lua` — the art

This project has no image files. Every sprite is ASCII art in a Lua table,
compiled into a texture atlas at startup by `src/assets/spritegen.lua`. Each
letter maps to a named palette colour; `.` means transparent.

Two additions:

- **`boss_tideengine` frame 3** — the charging pose. Same 16×22 grid as the
  existing two frames. The intake shutters across the middle are open wider,
  the core window is filled with white (`w`) instead of cyan, and the top
  pipes and bottom vents are lit sky-blue (`s`) instead of grey. `draw()`
  switches to this frame for the whole 2-second charge, which is the main
  visual tell that a surge is coming.
- **`fx_surgecrest`** — a new 12×16 sprite, 3 frames, that draws the foam at
  the leading edge of the wall. It's a single tile drawn repeatedly down the
  room's height, cycling through its 3 frames as it goes so the edge looks
  like it's churning rather than a solid bar. It's flipped horizontally when
  the wall travels right-to-left.

**Rule to remember if you edit these:** every row of every frame of one
sprite must be exactly the same length, and every frame must have the same
number of rows. The compiler throws a hard error at startup if not, which is
good — you'll know immediately.

### 3. `game/src/audio/sfx.lua` — the sound

Same story as the art: no audio files. Every sound is generated
mathematically at startup. The file gives you building blocks — `sq` (square
wave), `tri` (triangle wave), `sin`, `noise`, and `env` (a volume envelope
that fades in then out).

Two new sounds, added next to `S.splash`:

- **`S.surgecharge`** — 1.9 seconds. Three layers: a triangle-wave whine
  that climbs from 70 Hz to about 690 Hz (and gets louder as it climbs, so
  it reads as "building"), a slow square-wave pump rumble underneath, and
  filtered noise that swells to suggest a lot of water moving. Plays the
  instant the surge begins, so its length is deliberately about the same as
  `SURGE_CHARGE` — **if you change `SURGE_CHARGE`, change the `render(1.9, ...)`
  duration to match**, or the telegraph will feel out of sync.
- **`S.surgeblast`** — 1.1 seconds. A hard noise crash, a heavily
  low-pass-filtered copy of that same noise for low-end weight, and a
  triangle wave sliding from 300 Hz downward. Sharp attack, long decay.

Both were rendered and level-checked offline: peaks 0.54 and 0.70, no
clipping.

## How to test it

**Fast loop — the Test Chamber.** Title screen → TEST CHAMBER. Set BOSS to
TIDE ENGINE, leave ARENA on MATCH BOSS, and set BOTS to CO-OP (2P) if you
have a second controller, or SOLO (1P) otherwise. ENTER THE CHAMBER. Test
Chamber runs never write to a save slot, so you can do this as often as you
like without touching your real game.

What to check, in order:

1. Damage the boss to just under 75% health. The announcement should appear,
   the boss should switch to the white-core sprite, the water should drop,
   and a glowing bar should light one wall.
2. Stand in the open and let the wall hit you. You should take a solid chunk
   of damage and see blue particles.
3. Trigger the next surge and this time get inside Lu's dome before it
   lands. You should take zero damage, see cyan sparks, hear the dome-hit
   sound, and watch Lu's energy drop.
4. Confirm the second surge comes from the *opposite* wall to the first.
5. Kill the boss during a charge-up. Nothing should linger on screen and the
   water level should return to normal.

**Solo note:** the parked bot keeps its dome up if you set it before
swapping. So solo play is: put the dome up as Lu, swap to Vess, and stand
near her when the surge comes.

**Regression suites** (from `emberdeep/game/`, per `TESTING.md`):

```sh
python3 ../scripts/checkrooms.py
python3 ../scripts/checkdoors.py
PYTHONPATH=../scripts python3 ../scripts/checkprogress.py
```

All three should print `0 issues` — none of them touch boss behaviour, so
this is just proving nothing was knocked over. Then the headless scenarios
that involve this boss or the dome:

```sh
for s in bossspawn bossdrops bossflow bossreenter linkvent; do
  rm -rf ~/.local/share/love/emberdeep
  EMBERDEEP_TEST=$s xvfb-run -a love . || echo "FAILED: $s"
done
```

`linkvent` is the one that specifically exercises Lu's dome as cover, so
it's the closest existing coverage for the new interaction.

## Where save data lives

Set by `game/conf.lua`: `t.identity = "emberdeep"` with
`t.appendidentity = false`. On a Mac that means:

```
~/Library/Application Support/LOVE/emberdeep/
```

with four files: `settings.dat` (volume, bindings, difficulty default) and
`slot1.sav`, `slot2.sav`, `slot3.sav`.

They are **plain text Lua**, not binary — `src/core/ser.lua` writes each save
as a literal `return { ... }` table. You can open one in any text editor and
read it. (Editing by hand works, but keep it well-formed; a syntax error
makes the slot silently unreadable and the game treats it as empty.)

**Porting between packages:** the save location is keyed to the *identity
string*, not to the `.love` file or the app bundle. So any build that keeps
`t.identity = "emberdeep"` reads and writes the same folder — a fresh
package on the same Mac picks up your existing saves automatically, with
nothing to copy. To move saves to a different machine, copy that whole
folder across. To move them into a differently-named build, copy the folder
to that build's identity name instead.

## One thing worth fixing separately

`Save.writeSlot` sets `data.version = 1` on every write, but `Save.migrate`
treats anything below version 2 as a v1 save needing conversion — and
`migrate` itself sets `version = 2`. The result: every save you write is
stamped v1, so the v1→v2 migration re-runs on every single load. It's
currently harmless because the migration is idempotent (it uses
`data.forge = data.forge or forge`, so it won't clobber real data), but it's
a live trap — any future migration that *isn't* idempotent will corrupt
saves. The fix is a one-word change: `writeSlot` should stamp `2`.
