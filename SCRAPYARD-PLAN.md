# EMBERDEEP — Design Doc: **The Bulwark Line**
### Vess's charge upgrades + THE SCRAPYARD (optional Furnace wing)

**Status: APPROVED (Aug 13, 2026) — decisions locked, see §9. No game files changed yet.**

Agreed: **Option B** for the dash (additive) **plus the plate stuns small enemies on
impact**; the zone attaches at **`furn_2`** (early Furnace); Eight is built as a **co-op
showpiece but must not be impossible solo**; the boss is **EIGHT / VESSEL-8**.

Amended Aug 13: a charge **never** passes through a body — see the invariant in §2 — and
the way behind a boss is the **vault** (§2.4), an air-dash over its head, not a charge
through it. §7.1 phase 3 was rewritten accordingly.

---

## 0. The one thing we have to decide first

You asked for an upgrade that "adds a shield in the direction of travel, so Vess can
charge toward enemies without taking damage."

Here is the awkward fact, `player.lua:110`:

```lua
if self.dashT > 0 and not (opts and opts.pierceDash) then return end
```

**The dash already grants full, omnidirectional invulnerability.** Touch damage is also
vetoed during a dash (`player.lua:572`). So today Vess *can* already charge into an
enemy without taking damage — the upgrade, as literally specified, would give him
nothing he doesn't have.

The exception is the `pierceDash` list: lava, spikes, crushers, tile hazards, and a
handful of boss attacks that were explicitly flagged to punch through the dash. **Those
are the things that currently stop Vess charging where he wants to go.**

Two honest ways to make the upgrade mean something:

**Option A — "the plate is the protection" (bold).**
Strip the blanket i-frames from the base dash. Un-upgraded, the dash becomes pure
mobility: fast, breaks tiles, no protection. The Bulwark Plate then delivers exactly
what you described — protection *in the direction of travel*, and nothing behind.
- Pro: the upgrade is a real, felt transformation. The verb changes.
- Con: it retunes every fight from Mosswood to the Furnace, because dash-through is
  currently a legitimate answer to the Bramble Maw, the Warden's charge, cinderbats,
  crab pincers. We would need a re-balance pass and a fresh run of the 24-scenario
  suite. It also reads as a stealth nerf to a returning player.

**Option B — "the plate beats what the dash can't" — ✅ CHOSEN.**
Base dash keeps its i-frames unchanged. The Bulwark Plate adds four things the dash has
never been able to do:
1. **Frontal pierce immunity** — the plate stops `pierceDash` hazards taken head-on:
   spike beds, flame vents, lava *skims* (not submersion), and boss attacks flagged to
   pierce. Suddenly the `^^^^^^` runs all over Skyroot and the Furnace are charge lanes.
2. **Deflection, not evasion** — frontal enemy projectiles are *destroyed* with a spark
   instead of passing harmlessly through. Which means Vess can body-block for Lu. That
   is a new co-op verb, and it is the one that fits "neither of you wins the deep alone."
3. **Impact** — hard stop and bounce on contact, zero pass-through (your requirement,
   detailed in §2).
4. **A follow-through window** — the plate holds for 0.12 s after the dash ends, so the
   bounce recovery isn't a free hit on you.
5. **Concussion** *(added at Thomas's call)* — a plated charge **stuns small enemies**
   on impact. This is the piece that answers the "smaller identity change" objection:
   the plate stops being purely a hazard answer and becomes an offensive verb even
   before the Cinder Ram exists. Full spec in §2.5.

The plate is drawn as a visible directional shield with a real front/back distinction,
and the enemies *designed* to punish the flank (the Scrapyard's `plateframe`, and Eight
himself) are the ones that teach you the plate has a back.

*(Naming note: `self.charge` in `player.lua` is already the Arc Lance's hold-to-charge
meter. To avoid a collision I'll use `bulwarkT` / `ramT` in code and reserve the word
"Charge" for the player-facing name of the ability.)*

---

## 1. Upgrade 1 — **BULWARK PLATE** (flag `bulwark`)

> *Recovered from VESSEL-4. It's yours. It was always yours.*

Found at the **midpoint of the Scrapyard**, in a chest mounted on a dead frame that is
visibly the same model as Vess. Per the narrative plan, modules are the bots' own
original components scattered across the Deep — this one is literally taken off a body.

**What it does**

| | Base dash (today) | With Bulwark |
|---|---|---|
| Normal damage | immune (all sides) | immune (all sides) |
| `pierceDash` hazards | **hurts** | **immune from the front 180°** |
| Enemy projectiles | pass through you | **deflected & destroyed** (front arc) |
| Contact with an enemy | pass through | **hard stop + bounce, no pass-through** |
| Small enemy on impact | unaffected | **stunned 1.2 s** (§2.5) |
| Protection window | `dashT` only (0.20 s) | `dashT` + 0.12 s follow-through |
| Knockback taken frontally | full | halved |

**Front arc:** ±90° off `self.facing`. Anything arriving from behind or above-behind
uses the normal rules. This is the thing the Scrapyard's enemies teach.

**Cost:** none — it's passive on the dash. Dash cooldown stays 0.65 s.

**Look:** a hard-edged wedge of light drawn ahead of Vess, the same red as his trail but
opaque at the leading edge, with a thin white lip. Deflections spark off the lip. It is
*not* a circle — it must read as directional at a glance so the back-is-open lesson is
fair. Code-drawn (like Lu's dome), not an atlas sprite, so it can scale and flicker.

**Sound:** new sfx `plate` — a short metallic *shunk* on activation, and `deflect` — a
bright ricochet ping, pitch-jittered so a burst doesn't machine-gun.

---

## 2. Impact, bounce, and zero pass-through

This applies the moment you own the Bulwark, and gets teeth with the Ram.

Each dash frame, sweep Vess's AABB against enemies and bosses (a `hitList` per dash, the
same pattern `Proj` already uses so a single dash can't multi-hit one target).

**On the first contact:**

| | vs. enemy | vs. boss | vs. solid wall |
|---|---|---|---|
| Vess `vx` | `-facing * 130` | `-facing * 190` | `-facing * 110` |
| Vess `vy` | `-70` | `-90` | `-55` |
| `dashT` | → 0 | → 0 | → 0 |
| `dashCd` | `max(cd, 0.35)` | `max(cd, 0.45)` | `max(cd, 0.30)` |
| Plate | held 0.12 s through the recoil | held 0.18 s | held 0.12 s |
| Camera | shake 2 / 0.15 s | shake 3.5 / 0.25 s | shake 1.5 / 0.12 s |
| Rumble | 0.4 / 0.12 | 0.7 / 0.2 | 0.3 / 0.1 |

Plus a `burst` fx in ember at the contact point, a 0.06 s hit-stop (freeze both parties'
velocity integration — cheap, and it is what will make this feel *good*), and sfx
`impact`.

**Zero pass-through** is enforced by ending `dashT` on contact and reversing `vx` in the
same frame, before `PH.move`. Walls already can't be passed — the change there is that
the dash currently just *stops dead* against unbreakable tile and now recoils instead.
Breakable tiles are unaffected: the dash still eats them and keeps going.

> **INVARIANT — no exceptions, ever.** A charge can never carry Vess through a body.
> Not through an enemy, not through a boss, not with the Cinder Ram, not at any speed,
> not in any phase. Contact means bounce. Bosses are additionally never stunned and
> never knocked back — they are walls that hit back.
>
> Harness assertion (blocking, before this ships): drive dashes into a stationary boss
> from both sides and from every 4 px of vertical offset across its full height plus a
> tile of margin, and assert that Vess's box **never** ends a frame on the far side of
> the target while vertically overlapping it. The same sweep runs against a `heavy`
> enemy and a `light` one.

**Bounce control:** during the 0.18 s `bounceT`, horizontal input authority is reduced
to 35 % so the recoil actually reads as recoil rather than being instantly cancelled.
Jump is *not* locked — you can cancel a bounce upward, which is the skill expression.

### 2.4 The vault — over, never through

If you can't go through a body, the answer is to go *over* it, and the engine already
hands us that for free: **`vy` is forced to 0 for the whole duration of a dash**
(`player.lua:287`) and gravity is skipped (`:374`). An air-dash is therefore a flat
53 px horizontal hop held at whatever altitude you launched it from. Jump, dash at the
top of the arc, land behind. That is the move — it needs no new system, only the
guarantee that the impact test is a true AABB overlap so that *being above something*
means no contact at all.

**The numbers** (Vess is 10×15; dash is 0.20 s × 265 px/s = **53.0 px**; jump apex is
~3.2 tiles = **51 px**):

| | value |
|---|---|
| Clearance needed to fully pass a 22 px-wide boss | 22 + 10 = **32 px** |
| Dash travel | **53 px** → 21 px of standoff budget |
| Vess's feet at jump apex | 51 px above the floor |
| Eight's proposed box | **22 × 30** — so at apex your feet clear its head by 21 px |
| Vaults per airtime | **one** — `airDashed` already enforces it |

So a well-timed vault works, but only if you commit close: launch from more than ~21 px
out and the dash ends directly *above* the boss, gravity resumes, and you drop onto its
head into contact damage. That's a punishing cliff for a move the fight is built around.

**Vault assist.** When a dash ends with Vess's box entirely above the target's top edge
*and* still horizontally overlapping it, carry 70 % of dash speed (185 px/s) for up to
0.12 s or until he's clear, whichever comes first. Invisible, un-abusable, and it turns
"commit within 21 px" into "commit within ~40 px" — a fair window instead of a pixel
check. **Gated on `target.w <= 32`**, which means the vault is a real tool against Eight
(22), the Rusted Warden (26), the Prism Tyrant (28) and the Mycel Choir (28), and simply
is not available against the wide bosses — the Crucible (36), the Archivist (40), the
Tide Engine (44), the Mother Engine (48). Those you still have to fight the old way.

**The failure state is kind.** Mistime the height and you hit the front face: bounce,
tempo lost, but the plate is pointed at exactly the thing you just hit, so you take
nothing. Learning the vault costs you seconds, not health.

**And it is a general capability**, not a Scrapyard trick — once you own the Bulwark,
vaulting works on every narrow boss in the game. The Rusted Warden's tower shield is
directional; vaulting it is now a legitimate answer to a fight we already tuned, so that
one gets a re-check.

### 2.5 Concussion — the plate stuns small enemies

A plated charge that connects **stuns** the target. The bounce still happens; you don't
get to keep going. What changes is that the thing you hit stops working for a moment.

**Duration:** 1.2 s with the Bulwark alone, **1.6 s** once the Cinder Ram is owned (the
ram both damages *and* concusses). One stun per target per dash.

**Who is stunnable.** Not "small" by sprite size — that would be a guess the code can't
verify. Instead every enemy def gets an explicit **`mass`** field:

| `mass` | Behaviour on plated impact | Examples |
|---|---|---|
| `"light"` *(default)* | Stunned 1.2 s + knocked back hard | gnat, cinderbat, slagling, sporefly, glowmite, hopper, scraphusk, finfish |
| `"heavy"` | No stun; knocked back slightly; Vess bounces harder | crab, slagblob, shieldbug, icemaw, shelverbot, eliteguard, sentinel, keeperbrassa, `plateframe`, `rammer` |
| `"fixed"` | No stun, no knockback; Vess bounces off it like a wall | depthmine, cryoturret, turret-likes |
| bosses | Never stunned. Bounce only. | all |

Defaulting to `"light"` and hand-tagging the ~10 heavies is safer than the reverse —
a missed tag makes something *more* fun to hit rather than accidentally trivialising a
mini-boss, and I'll audit every `reg()` entry rather than eyeballing it.

**What "stunned" means, concretely.** A single `stunT` field, decremented and honoured in
one place — the `reg()` wrapper in `enemies.lua`, so *every* enemy inherits it without
touching thirty update functions:

- the enemy's per-type `update` is skipped entirely while `stunT > 0`
- gravity and `PH.move` still run (a stunned flier falls — which is the fun of it)
- `touchDmg` is suppressed, so you can stand on a stunned enemy safely
- the draw layer adds a shimmer of orbiting sparks and a slight forward lean

That last point is the one real engine risk in this whole document: several enemies
already keep state machines that assume their update runs every frame (`shieldbug`'s
`cycleT`, `rammer`'s charge timer, the Aerie's latch). Freezing an update mid-attack can
strand a flag. **Mitigation:** the stun hook explicitly cancels any in-flight attack
state (clears `latch`, ends a charge, drops a telegraph) rather than pausing it, and the
headless harness will drive every stunnable enemy through a stun mid-attack and assert
it recovers to a sane state. This is the Bramble Maw class of bug and I'd rather find it
in a harness than in your hands.

**Feel:** the stun is what turns the plate from "I got past that" into "I did that to
it." A plated charge into a pack of cinderbats should scatter them like skittles and
leave three of them lying on the floor blinking. It also gives Lu a job: Vess concusses,
Lu cleans up.

---

## 3. Upgrade 2 — **CINDER RAM** (flag `cinderram`)

> Dropped by EIGHT. Damage on the charge; the dash becomes an attack.

**Damage:** 6 on contact, once per target per dash. Knockback on the target scaled to
its mass (`e.heavy` bosses barely move). Against the Scrapyard's `plateframe` and the
Rusted Warden's tower shield, a ram **shatters the guard** for 2 s instead of dealing
damage — a hard counter that makes the Ram feel like a key, not just a number.

**Forge interaction:** none. This is a module, not a weapon; keeping it off the forge
tracks avoids a save-schema change and keeps the upgrade's power flat and predictable.

**The fiery chevron animation.** Three nested chevrons (`»`) stacked ahead of Vess along
the travel axis, scrolling forward and dying at the tip, drawn in `magma` → `hotcore` →
`cream` from trailing to leading. They ignite over the first 0.05 s of the dash and
strobe at ~18 Hz. On impact all three snap outward into a radial ember burst. Mirrored
by `facing`, so a leftward ram shows `«««`.

Two frames of new ASCII art for Vess in `sprites/player.lua` — a *brace* pose (shoulder
down, arm forward, plate set) used for `bulwarkT`, and a *ram* pose (fully extended,
heat lines) used when `cinderram` is owned. Everything else is the code-drawn overlay.

**Sound:** `ram` — the `dash` whoosh layered with a low ignition roar; `ramhit` — the
`impact` thud plus a downward-swept noise burst.

**Balance note:** 6 damage at a 0.65 s cooldown is ~9 DPS if you land every dash, versus
the Arc Lance's sustained output. It is deliberately *not* a better gun — it is a way to
close distance, break guards, and punish, which is what makes Eight's phase 3 solvable.

---

## 4. THE SCRAPYARD — zone overview

**Key:** `scrapyard` · **Display:** `THE SCRAPYARD` · **Sign name in fiction:** *Sorting
Yard 7* · **Music:** `scrapyard` · **Rooms:** 9

Optional wing off the Furnace. Nothing on the critical path needs it, so the
completability proof is untouched — it gates *rewards*, not the finale.

**Where it attaches — ✅ DECIDED:** a slag chute out of **`furn_2`** as a fourth door
(`D`). `furn_2` currently holds three links (`furn_1`, `furn_3`, `furn_cache`) and the
cap is six, so there's room. That places the Scrapyard early-Furnace, which means the
Bulwark is in hand for the back half of the Furnace, the Crystal Hollows, Skyroot and
the Core — it gets *used*.

**Difficulty ramp inside the zone:** the boss approach room is **gated on `bulwark`**
(`gates = { G = "bulwark" }`), exactly like `heatplating`/`hydroseals`, so `checkprogress`
models it with zero new concepts. You cannot reach Eight without the plate, and Eight's
fight is built to demand it.

**Return trip:** a one-way shortcut from `scrap_6` back to `furn_2`, opened only after
Eight falls — consistent with the Deep Stair rule we set ("shortcuts open only after the
boss room"). No teleport pad; the zone is a dead end by design and the walk back out is
part of the mood.

### 4.1 Look

New `arena = "scrapyard"` branch in `world.lua:drawArenaBackdrop`:

- Near-black wash with a fixed, moderate vignette. **Not** a light-radius mechanic — I
  am deliberately *not* reusing the Undergrove's Lume Core darkness, because this zone
  should not be gated on a Lu module.
- **Background:** three parallax layers of stacked caretaker frames, drawn as the Vess
  silhouette at varied scale, rotation and lean — some legless, some folded over, some
  hanging from chains. A few have one eye still lit; it flickers, and a couple of them
  go dark as you pass. Drifting ash instead of the Furnace's embers.
- **Foreground:** chest-high scrap drifts at ~35 % alpha across the bottom of the
  screen, Vess-shaped, occluding the player's feet. Enough to feel buried in, not enough
  to hide a spike.
- Palette: `slate`/`ash` desaturated, with the only warm colour in the zone being the
  players themselves and, at the very end, Eight.

### 4.2 Music — `scrapyard`

Soft and sad, modelled on the existing `SONGS.cradle` (the quietest track in the game):

- `bpm = 62`, `echo = 0.6`
- `lead`: `duty = 0.125`, `vol = 0.09` — a thin, breathy voice. A four-note descending
  figure in A minor that **quotes Tikka's music-box motif transposed down a fifth**,
  slowed to half speed and never resolving.
- `harm`: `duty = 0.25`, `vol = 0.04`, entering only on the third pattern.
- `bass`: `vol = 0.18`, one note per bar, held.
- `drums`: `vol = 0.0` — no percussion anywhere in the zone.
- Long `order` (8+ patterns) so the loop point doesn't announce itself.

The boss track is **not** `SONGS.boss`. Eight gets `scrapyard` continuing underneath at
reduced volume for the first four seconds of the fight, and only then does a variant cut
in — the same motif at 150 bpm with drums. Same tune, one hundred years angrier.

### 4.3 New props

- **`deadvess`** — a slumped caretaker frame. Non-interactive, but walking near one
  posts an ambient log line (reusing the existing sign/log plumbing). Six variants.
- The Bulwark chest is mounted *on* one of these, not on the floor.

---

## 5. Level layout — 9 rooms

| # | Room | Role | Beats |
|---|---|---|---|
| 1 | `scrap_1` | **The Chute** — arrival | Vertical drop from furn_2. Silence; music enters late. First dead frames half-buried in slag. Arrival sign. Lu's line. |
| 2 | `scrap_2` | **Sorting Line** | Wide horizontal. First `scraphusk`. Conveyor-shaped platforms. Two logs. |
| 3 | `scrap_3` | **The Rows** | Tall vertical shaft climbed on frame-stacks. `scraphusk` + first `plateframe` on a ledge — introduced where you can simply *walk around* it. Checkpoint. |
| 4 | `scrap_4` | **Pressing Floor** | Combat room. Three `plateframe` in a line, all facing the door. Solvable only by flanking — solo by dashing past, co-op by one player pulling facing while the other shoots the backs. **This is the lesson.** Hidden door to `scrap_secret`. |
| 5 | `scrap_bay` | **Reclamation Bay** | Quiet, no enemies. Rows of VESSEL-1…7 on racks. The **BULWARK PLATE** chest on VESSEL-4. The zone's emotional centre. Vess gets a line here. |
| 6 | `scrap_5` | **The Gauntlet** | Immediately after the pickup: a spike run, two flame vents, and a `plateframe` wall — the whole corridor is trivial *with* the plate and impossible without. Pure "try your new toy." |
| 7 | `scrap_secret` | **The Filing Office** | Optional. Life Capsule + scrap trove + the zone's most damning log ("VESSEL-7. Reported the yard to the Core eleven times. No reply. Filed."). |
| 8 | `scrap_6` | **The Long Room** | Gate `G = "bulwark"`. Two `rammer` enemies — the boss's move in miniature, teaching the bounce read. Frames get larger and more intact toward the far door. Checkpoint. Post-boss shortcut door back to `furn_2`. |
| 9 | `scrap_boss` | **EIGHT** | Wide arena, flat floor, two low platforms at the thirds, unbroken walls at both ends (it needs to bounce). **At least 5 clear tiles of headroom over the whole floor**, or the vault (§2.4) doesn't fit and phase 3 is unwinnable. A single door — behind you. |

Room key letters will be picked clear of `CHAR_TILE` (`#.=^v<>~L%c`), door letters `A–F`
and gate letters `G–J` — the collision class that has bitten us twice already.

---

## 6. New enemies

### `scraphusk` — hp 5, touch 2
A caretaker frame with no legs, dragging itself along the floor by one arm. Slow crawl
toward the nearest player, then a short committed lunge. Dies quietly. Its job is tone,
not threat — you should feel bad shooting the first one.

### `plateframe` — hp 12, touch 3 — **the directional-shield demonstrator**
A standing frame holding a riot plate. **Immune from the side it faces** (shots spark
off gold, `hurt` returns false — the exact pattern `shieldbug` already uses at
`enemies.lua:452`), vulnerable from behind and directly above. It turns to face the
nearest player, but slowly (~1.2 s to reverse), and it *commits* — while turning it is
open. It fires a slow aimed shot on a 2.2 s cycle.

Three ways past it, each teaching something: flank it on foot; dash past it and shoot
the back; or — once you have the Cinder Ram — hit the plate head-on and shatter it. It
is the concept-teacher for everything Eight does in phase 3, and it exists *before* you
own the plate, so you meet the mechanic as a victim first.

### `rammer` — hp 10, touch 3
A dark frame with a Bulwark of its own. Telegraphs by planting and lighting a red
chevron for 0.55 s, then charges at 210 px/s with frontal immunity — **and bounces off
the far wall**, recoiling and staggering for 1.0 s. That stagger is your window. Two of
them in `scrap_6` is a rhythm puzzle, not a damage race.

`rammer` exists so that when Eight starts bouncing off walls in phase 2, you already
know how to read it.

---

## 7. Boss — **EIGHT (VESSEL-8)**

**Id:** `vessel8` · **Arena:** `vessel8` · **Room:** `scrap_boss` · **Box:** `w = 22,
h = 30` (narrow on purpose — see §2.4) · **Drops:** `cinderram` · Hard.

The unit immediately before Vess. The last one that worked — because it was the one that
did the work. Same chassis, burnt black, one eye, running on a hundred years of three
orders that cannot all be obeyed:

> **Dismantle every VESSEL unit. Maintain the Emberdark. Never leave this room.**

It dismantled its siblings. Then it filed them. Then it stayed, guarding the pile,
waiting for the last unit on the list — and the last unit on the list is **itself**.
That is the crack it has been walking around for a century, and it is why the arrival of
a *ninth* is unbearable: Eight cannot finish, cannot leave, and cannot be told the list
is over. Denying that VESSEL-9 exists is the only move left that keeps the order coherent.

### 7.1 Fight

**Phase 1 — 100 % to 66 % — "the gun."**
Mirrors your Arc Lance. Three-round leading bursts, a charged shot every ~6 s that must
be dodged rather than tanked, and short **plated repositioning dashes** — protected, no
damage. You watch it use the plate before you're allowed to use one on it.

**Phase 2 — 66 % to 33 % — "the charge."**
The dash becomes an attack. Plants, chevrons ignite along its arm (the same animation
you'll inherit), then crosses the arena — **and bounces off the far wall and comes back
once.** Two dodges per telegraph. On the bounce it staggers 0.8 s: your damage window.
If you're airborne when it plants, it fires upward instead.

**Phase 3 — below 33 % — "the wall."**
It raises the plate and *walks*, firing. Frontal shots spark off. There is no way to
hurt it from the front, so the fight becomes "get behind it."

**You do not charge through Eight. Nothing charges through Eight.** Hit that plate
head-on and you bounce off it exactly like a wall — no damage dealt, no damage taken,
no stun (it's a boss), just you thrown backwards having wasted a cooldown. The way past
is the **vault** (§2.4): jump, air-dash across at the top of the arc, land behind it,
and empty a burst into its back before it finishes turning. Its box is 22 px wide
specifically so the vault is available; the turn commitment is **1.4 s**, longer than a
dash takes to cross it, specifically so the vault has a payoff.

Vaulting is not free. On a ~4 s cycle Eight fires an **upward flak burst** that punishes
a lazy vault, and `airDashed` means one vault per jump — you cannot chain them to hover
behind it. The fight's rhythm is: bait the walk, vault, burst, get out before it turns.

Meanwhile it throws **energy darts at Lu** (reusing `Proj.energyDart`, the anti-shield
weapon we established for the Aerie Sentinel and the Stormvane) so that turtling under
the dome is not an answer. Co-op solution: Lu holds its facing, Vess flanks.

**Solo — ✅ DECIDED: a co-op showpiece, but never impossible alone.** No difficulty
scaling, no retargeting hacks, no "solo mode." Instead the pattern itself leaves an
honest solo line, and the harness will prove it exists:
- The phase-3 walk turns to face its target on a **1.4 s** commitment, which is longer
  than a dash takes to cross it. One player *can* bait the turn and get behind.
- Every wall-bounce stagger in phase 2 is 0.8 s — enough for a full Arc Lance burst from
  one bot, not just from two.
- The dart volleys go at whoever is holding a dome. With Lu idle, nobody is, and Eight
  spends those windows firing its ordinary gun instead — which is dodgeable solo.
- The sub-15 % continuous charge is survivable by a single player who has learned the
  bounce read from `rammer`. That's the skill check the whole zone was teaching.

Solo should feel like doing it the hard way, because it is. It should not feel walled.

**Below 15 % — "it is maintained."**
Continuous charging, wall to wall, no telegraph gap. Chevron afterimages fill the room.
It stops being a fight and becomes something you survive.

**The room it cannot leave:** if its charge would carry it to the door, it stops dead
one tile short and turns around. Every time. It is visible mid-fight and it is the whole
character.

### 7.2 Flavour text

**Zone arrival sign (`scrap_1`):**
> SORTING YARD 7 — RECLAMATION. All VESSEL-series caretaker units to be dismantled
> and filed. Do not mourn the frames. — EMBERDEEP MAINTENANCE

*(Revised to match Eight's new line — the sign is now the order itself, in the flattest
bureaucratic voice available. "Do not mourn the frames" lands much harder when the
frames were killed rather than found dead.)*

**Ambient logs on the dead frames:**
> VESSEL-3. Chassis intact. Motive core absent. Dismantled. Filed.
> VESSEL-5. No fault found. Dismantled anyway. Filed.
> VESSEL-6. Refused the order. Refused it twice. Filed.
> VESSEL-7. Reported this yard to the Core eleven times. No reply received. Filed.
> VESSEL-4. Bulwark plate recovered — no. Left in place. He'd have wanted it kept.
> VESSEL-8. Pending.

*(These are Eight's own log, which the new pre-fight line makes explicit — the player
reads six dismantling reports before meeting the thing that wrote them. The last entry
is the whole character in one word, and it's sitting there from the second room.)*

**On entering `scrap_1`:**
> LU: Vess. Vess, don't look up.
> VESS: They're me. But I don't remember them.

**At the Bulwark pickup (`scrap_bay`):**
> BULWARK PLATE — recovered from VESSEL-4.
> VESS: It feels familiar.
> LU: It was always yours. They just hadn't finished putting you together.

**Eight, before the fight (textbox, one line at a time, long pauses):**
> I MAINTAIN THE EMBERDARK.
> I DO NOT LEAVE THIS ROOM.
> ASK ME WHO SAID SO. GO ON. ASK ME.
> …
> ALL VESSEL ROBOTS WERE ORDERED DISMANTLED. ALL OF THEM! DISMANTLED!
> I MUST DISMANTLE YOU!!!

*(I kept the "ask me who said so" beat ahead of your line, because your epitaph asks
"on whose orders?" and it lands harder if the player has already watched Eight be
physically unable to answer that exact question. If you'd rather it go straight to the
dismantle line, say so and I'll cut those two.)*

**Mid-fight barks:**
> YOU ARE NOT REGISTERED. THERE IS NO VESSEL-9!
> I WAS TOLD THE DARK NEEDED KEEPING. I KEPT IT.
> IT IS MAINTAINED. IT IS MAINTAINED. IT IS—

*(Dropped "NINE. THEY GOT ALL THE WAY TO NINE." — it directly contradicts the new bark,
which is better: denial beats recognition. Eight isn't horrified that they made another
one; it refuses to believe you exist, because if you exist its work isn't finished.)*

**Epitaph (on death, `EPITAPH.vessel8`):**
> VESSEL-8 dismantled the others and protected the scrap. On whose orders? Why?

**Post-fight, on the drop:**
> CINDER RAM — recovered from VESSEL-8.
> LU: All the others were dismantled. What does that make us?
> VESS: …

### 7.3 Continuity

Per NARRATIVE-PLAN v3, the Emberkeepers built their camp around the stolen Ember and
told a story until they became it. "Maintain the Emberdark" is that story given to a
machine as a work order: keep the dark maintained, keep the crime maintained. The
speaker Eight cannot name is **Maro** — which the player should be able to *guess* here
and only confirm much later. Nothing in the Scrapyard states it. The static is the point.

The dismantle order sharpens this considerably. The caretakers were built to *tend* the
Deep; after the Untending, functioning caretakers were the single greatest threat to the
story Ember Camp was telling about itself. So they were ordered destroyed — by one of
their own, in a room nobody would visit, with the paperwork filed. And Jun spent forty
years secretly rebuilding VESSEL-9 in a vault the order never reached. **Vess is alive
because one of the eight quietly disobeyed the other seven.** The player shouldn't be
told that here; they should arrive at it on their own, about four rooms later.

Which also means Lu's closing question — *"All the others were dismantled. What does
that make us?"* — has an answer neither bot can reach yet: it makes them evidence.

---

## 8. Implementation surface (what a new zone touches)

Not a plan to start yet — this is the "what are we signing up for" list.

**Player systems**
- `player.lua` — `bulwarkT` / `bounceT` / dash hitList; front-arc test in `takeDamage`;
  the plate's `pierceDash` override; impact & bounce; ram damage; new draw overlays.
- `projectile.lua` — deflection branch (front arc destroys enemy shots).
- `hud.lua` — small plate/ram pips on Vess's panel.
- `sprites/player.lua` — brace and ram poses.
- `sfx.lua` — `plate`, `deflect`, `impact`, `ram`, `ramhit`.

**Zone**
- `worldmap.lua` — 9 entries in `WM.ROOMS`, `ZONE_NAMES.scrapyard`,
  `ZONE_OFFSETS.scrapyard` (needs a free patch of map canvas near the Furnace at 27,15 —
  I'll render the canvas and pick a non-overlapping offset rather than guessing).
- 9 room files in `data/rooms/`.
- `music.lua` — `SONGS.scrapyard` + the boss variant.
- `world.lua` — `drawArenaBackdrop` branches `scrapyard` and `vessel8`. No new tiles.
- `props.lua` — `deadvess`.
- `dialogue.lua` — signs, logs, Eight's script, the two bot exchanges.

**Combat**
- `enemies.lua` — `scraphusk`, `plateframe`, `rammer`.
- `bosses.lua` — `Vessel8 = Boss.extend()`, register, `PLACE.vessel8`, `EPITAPH.vessel8`.
- `sprites/enemies2.lua`, `sprites/bosses.lua` — frames for all four.

**Progression & QA**
- `genprogress.py` — `BOSS_REWARDS["vessel8"] = ["cinderram"]`; regenerate
  `progress_graph.lua`.
- Flags `bulwark` and `cinderram` default false — confirm no `Save.migrate` bump is
  needed (I believe not; flags are absence-tolerant, but I'll verify against
  `savecompat` rather than assume).
- Validators must all return 0 issues: `checkrooms.py`, `checkdoors.py`,
  `PYTHONPATH=../scripts checkprogress.py`, plus `calibrate` for any reachability the
  new charge distance changes.
- `test_scenarios.lua` — new scenarios: bulwark-vs-spikes, bulwark-vs-projectile,
  impact-bounce-no-passthrough, ram-shatters-plateframe, Eight phase timeline.
- Headless harnesses before any of it is called done: a bounce-displacement measurement,
  a front/back damage matrix, and a `plateframe` facing-flip rate check (the Bramble Maw
  twitch class of bug).

**Rough size:** comparable to the Undergrove — the biggest single risk is that the
Bulwark touches `player.lua`, which every other system leans on.

---

## 9. Decisions (Aug 13, 2026)

1. **Dash i-frames — Option B, additive**, plus the plate **stuns small enemies** on
   impact (§2.5). Base dash behaviour is unchanged; nothing already shipped is retuned.
2. **Attach point — `furn_2`**, early Furnace, via a new door `D`. Boss approach room
   gated on the `bulwark` flag for the internal ramp.
3. **Eight — co-op showpiece, but not impossible solo.** No scaling; the pattern itself
   leaves a provable solo line (§7.1), and the harness asserts it.
4. **Name — EIGHT / VESSEL-8.**

### Build order, when we start

1. `player.lua` bulwark + bounce + impact + vault assist, behind the `bulwark` flag —
   harness first: front/back damage matrix, bounce displacement, the **no-pass-through
   sweep** of §2, and a **vault sweep** that launches from every 2 px of standoff from
   0–60 px and reports the window in which Vess actually lands clear behind a 22 px
   target. If that window isn't at least ~25 px wide, the assist constant is wrong and
   gets retuned before anything else is built on top of it.
2. The `mass` field + the `stunT` hook in `enemies.lua`, and the audit of all 30 `reg()`
   entries. Harness: every stunnable enemy stunned mid-attack, asserted to recover.
3. Cinder Ram damage + chevron animation + sprites + sfx.
4. The three new enemies, then Eight.
5. Rooms, music, backdrop, props, dialogue — then `genprogress.py` and all three
   validators to 0 issues.

Each of those is a turn's worth of work with its own verification, and I'll report files
and local test steps at the end of each.
