#!/usr/bin/env python3
"""checkenergy -- can Lu afford this room?

Energy stopped being free. player.lua regenerates her to a RESERVE and no
further (COOP-PLAN 2), so every point above that has to be picked up:
energy motes off kills, tuned PER SPAWN in the room file, or an energy
cell, which refreshes when you leave the ZONE rather than the room.

Which turns a design intention -- "Lu must have enough energy to survive
every encounter" -- into arithmetic somebody can check. This is that
check.

    afford = reserve + motes_in_room + cells_in_room  -  cost_of_room

THE MODEL, stated plainly so it can be argued with:

  cost    every enemy in the room lands ONE touch on a raised dome, at
          the UNUPGRADED drain rate. That is not a simulation of the
          fight -- it is a floor under it, and a floor is what a
          validator can honestly defend. A room that cannot pay even
          that is a room where the dome is decorative.
  supply  motes are what the room's own spawns declare, cells are worth
          their percentage of a base-tier tank.
  reserve what regen alone will give her, which is the derived floor in
          player.lua -- one repair plus one dome, or EN_RESERVE of the
          bar, whichever is larger.

EVERY NUMBER IS READ OUT OF THE ENGINE. Not one of them is typed here.
That is not tidiness: a validator holding its own copy of the constant it
validates passes forever, and this project has three post-mortems about
exactly that. If a constant moves and this file cannot find it, it says
so and exits rather than quietly scoring the game against a fossil.

Comments are stripped before every search. Prose describing a number
looks exactly like the number to a regex, and that has cost this project
three wrong diagnoses in a single sitting.

REPORT ONLY for now. Run it, read the spread, and set the threshold from
what the game actually contains -- the first version of checksight
demanded something reasonable and failed seven shipped arenas, which is a
wrong rule rather than sixty bugs.
"""
import glob
import re
import sys

import roommodel as RM


def code(path):
    return re.sub(r"--[^\n]*", "", open(path).read())


def need(pattern, text, what, where, group=1, cast=float):
    m = re.search(pattern, text, re.S)
    if not m:
        raise SystemExit(
            "checkenergy: could not find %s in %s.\n"
            "  Every number this tool scores with is read out of the engine,\n"
            "  so a missing one means the score would be a guess. Go and\n"
            "  read %s -- do not hand-type the value here." % (what, where, where))
    return cast(m.group(group))


# ---- the constants, read from the engine ---------------------------
UP = code("src/upgrades.lua")
PL = code("src/entities/player.lua")
PK = code("src/entities/pickup.lua")
EN = code("src/entities/enemies.lua")

BASE_ENERGY = need(r"Up\.BASE_ENERGY\s*=\s*([\d.]+)", UP, "Up.BASE_ENERGY", "upgrades.lua")
DOME_DRAIN = need(r"Up\.DOME_DRAIN\s*=\s*\{\s*([\d.]+)", UP, "Up.DOME_DRAIN[1]", "upgrades.lua")
REPAIR_COST = need(r"Up\.REPAIR\s*=\s*\{\s*\{[^}]*cost\s*=\s*([\d.]+)", UP,
                   "Up.REPAIR[1].cost", "upgrades.lua")
EN_RESERVE = need(r"local EN_RESERVE\s*=\s*([\d.]+)", PL, "EN_RESERVE", "player.lua")
DOME_MIN = need(r"local DOME_MIN\s*=\s*([\d.]+)", PL, "DOME_MIN", "player.lua")
EN_VALUE = need(r"Pickup\.EN_VALUE\s*=\s*([\d.]+)", PK, "Pickup.EN_VALUE", "pickup.lua")
CELL_PCT = need(r"Cell\.PERCENT\s*=\s*([\d.]+)", PK, "Cell.PERCENT", "pickup.lua")
PER_SHARD = need(r"Enemy\.ENERGY_PER_SHARD\s*=\s*([\d.]+)", EN,
                 "Enemy.ENERGY_PER_SHARD", "enemies.lua")
# The engine's fallback for a type that declares no `drops` at all. This
# is NOT the same as `drops = {}`, which declares "pays nothing" -- and
# reading it rather than assuming it is the difference between scoring
# most of the game as bankrupt and scoring it correctly.
FALLBACK_SHARDS = need(
    r"def\.drops\s*or\s*\{\s*shards\s*=\s*(\d+)", EN,
    "the fallback drop table (def.drops or { shards = N })", "enemies.lua")

DOME_UPKEEP = need(r"self\.energy\s*=\s*self\.energy\s*-\s*([\d.]+)\s*\*\s*dt",
                   PL, "the dome's upkeep (energy/sec)", "player.lua")
REGEN = need(r"local EN_REGEN\s*=\s*([\d.]+)", PL, "EN_REGEN", "player.lua")

# player.lua: reserveFor() is max(frac of bar, one repair + one dome)
RESERVE = max(BASE_ENERGY * EN_RESERVE, REPAIR_COST + DOME_MIN)

# ---- the enemy roster, read from the engine ------------------------
# name -> (touchDmg, declared shards or None)
ENEMIES = {}
_regs = [(m.start(), m.group(1)) for m in re.finditer(r'reg\("(\w+)"', EN)]
if not _regs:
    raise SystemExit("checkenergy: no reg(\"...\") enemies found in enemies.lua")
for i, (pos, name) in enumerate(_regs):
    end = _regs[i + 1][0] if i + 1 < len(_regs) else len(EN)
    body = EN[pos:end]
    td = re.search(r"touchDmg\s*=\s*(\d+)", body)
    dd = re.search(r"drops\s*=\s*\{([^}]*)\}", body)
    if dd is None:
        # no drops key: the engine substitutes its fallback table
        shards = FALLBACK_SHARDS
    else:
        # a declared table: `drops = {}` really does mean nothing
        s = re.search(r"shards\s*=\s*(\d+)", dd.group(1))
        shards = int(s.group(1)) if s else 0
        e = re.search(r"energy\s*=\s*(\d+)", dd.group(1))
        if e:
            shards = int(e.group(1)) / PER_SHARD
    ENEMIES[name] = (int(td.group(1)) if td else 2, shards)


def room_energy(room):
    """(supply, cost, n_enemies, n_cells) for one room."""
    supply = cost = 0.0
    n_en = n_cell = 0
    for ch, spec in (room.key or {}).items():
        cells = room.spawns.get(ch, [])
        if not cells:
            continue
        parts = spec.split(":")
        kind = parts[0]
        if kind == "cell":
            pct = CELL_PCT
            if len(parts) > 1:
                try:
                    pct = float(parts[1])
                except ValueError:
                    pass
            supply += len(cells) * pct * BASE_ENERGY
            n_cell += len(cells)
            continue
        if kind not in ENEMIES:
            continue
        touch, shards = ENEMIES[kind]
        motes = shards * PER_SHARD
        for p in parts[1:]:
            m = re.match(r"^(\w+)=(-?[\d.]+)$", p)
            if m and m.group(1) == "energy":
                motes = float(m.group(2))
            if m and m.group(1) == "shards" and shards is None:
                motes = float(m.group(2)) * PER_SHARD
        supply += len(cells) * motes * EN_VALUE
        cost += len(cells) * touch * DOME_DRAIN
        n_en += len(cells)
    return supply, cost, n_en, n_cell


def main():
    print("== checkenergy: can Lu afford the room? (report only) ==")
    print("   read from the engine: reserve %.0f (%.0f%% of %.0f, floor "
          "%.0f repair + %.0f dome), mote %.0f, cell %.0f%%, drain %.1f/dmg"
          % (RESERVE, EN_RESERVE * 100, BASE_ENERGY, REPAIR_COST, DOME_MIN,
             EN_VALUE, CELL_PCT * 100, DOME_DRAIN))
    print("   %d enemy types, %d rooms" % (len(ENEMIES),
                                           len(glob.glob("src/data/rooms/*.lua"))))
    rows = []
    for fname in sorted(glob.glob("src/data/rooms/*.lua")):
        if fname.endswith("test_arena.lua"):
            continue
        room = RM.parse_room(fname)
        supply, cost, n_en, n_cell = room_energy(room)
        if n_en == 0 and n_cell == 0:
            continue
        rows.append((RESERVE + supply - cost, room.name, supply, cost, n_en, n_cell))
    rows.sort()

    # ---- THE SURVIVABILITY FLOOR ------------------------------------
    # The interesting guarantee is not "this room contains enough". It is
    # that regen ALONE sustains a dome indefinitely at some duty cycle,
    # so Lu can never be left with no answer at all -- which is what
    # "sufficient energy to survive every encounter" actually has to mean
    # once the bar stops refilling itself. A boss arena has no motes in
    # it until the boss dies, so this is the only thing holding it up.
    dome_s = RESERVE / DOME_UPKEEP
    refill_s = RESERVE / REGEN
    duty = dome_s / (dome_s + refill_s)
    print()
    print("   SURVIVABILITY FLOOR (regen only, no pickups at all):")
    print("     %.1fs of dome from a full reserve, %.1fs to earn it back"
          " -> %.0f%% sustained duty cycle, forever"
          % (dome_s, refill_s, duty * 100))
    print("     %.0f absorbed damage per reserve at the unupgraded drain"
          % (RESERVE / DOME_DRAIN))
    if duty < 0.25:
        print("     ^ below 25%: the dome stops being a tool and becomes a "
              "coin flip. Raise EN_RESERVE in player.lua.")
    tight = [r for r in rows if r[0] < 0]
    print()
    print("   %-16s %7s %7s %7s %6s %5s" %
          ("room", "afford", "supply", "cost", "foes", "cells"))
    for afford, name, supply, cost, n_en, n_cell in rows[:18]:
        print("   %-16s %7.0f %7.0f %7.0f %6d %5d"
              % (name, afford, supply, cost, n_en, n_cell))
    print("   ... %d rooms with enemies in total" % len(rows))
    print()
    # ---- boss arenas, which have no motes until the boss dies -------
    allrooms = {}
    for fname in sorted(glob.glob("src/data/rooms/*.lua")):
        r = RM.parse_room(fname)
        allrooms[r.name] = r

    def has_cell(r):
        # A checkpoint deliberately does NOT count. It banks the run and
        # moves the respawn; it hands out no energy at all (props.lua).
        return any(s.split(":")[0] == "cell" for s in (r.key or {}).values())

    arenas = []
    for fname in sorted(glob.glob("src/data/rooms/*.lua")):
        room = RM.parse_room(fname)
        # `arena = "..."` is a BACKDROP selector, not a boss marker -- it is
        # set on Ember Camp and the whole Scrapyard. A room arms a boss when
        # it holds a `boss:` tripwire, which is the same thing checkprops
        # keys its no-checkpoint rule on.
        boss = None
        for spec in (room.key or {}).values():
            if spec.startswith("boss:"):
                boss = spec.split(":")[1]
        if not boss:
            continue
        _, _, n_en, _ = room_energy(room)
        # A cell belongs in the room BEFORE an arena, never inside one --
        # the same rule that keeps checkpoints out of boss rooms. So the
        # question is whether every APPROACH to this fight passes a cell.
        approaches = [n for n, r in allrooms.items()
                      if n != room.name
                      and any(d == room.name for d, _ in (r.links or {}).values())]
        stocked = [a for a in approaches if has_cell(allrooms[a])]
        arenas.append((room.name, boss, n_en, len(stocked), approaches, stocked))
    print()
    print("   BOSS ARENAS -- no motes until it dies, so the fight runs on the"
          " floor above")
    nocell = [a for a in arenas if a[3] == 0]
    print("     a cell belongs in the room BEFORE an arena, never inside one"
          " -- same rule as checkpoints, which hand out nothing themselves")
    for name, bid, _, nst, appr, stocked in arenas:
        mark = "ok  " if nst else "NONE"
        print("     %s %-13s %-14s approach via %-28s stocked: %s"
              % (mark, name, bid, ", ".join(sorted(appr)) or "-",
                 ", ".join(sorted(stocked)) or "none"))
    print("     %d of %d arenas have a cell on at least one approach"
          % (len(arenas) - len(nocell), len(arenas)))
    print()
    print("  %d room(s) cost Lu more than the reserve plus everything in "
          "them" % len(tight))
    for afford, name, supply, cost, n_en, n_cell in tight:
        print("     SHORT %-16s short by %.0f energy (%d foes cost %.0f, "
              "room supplies %.0f, reserve %.0f)"
              % (name, -afford, n_en, cost, supply, RESERVE))
    if not tight:
        print("     every room pays for the dome it demands")
    return 0


if __name__ == "__main__":
    sys.exit(main())
