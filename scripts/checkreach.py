#!/usr/bin/env python3
"""Movement-model calibration for the OPENABLE tiles: '%' break, 'c' crumble.

    PYTHONPATH=../scripts python3 ../scripts/checkreach.py

WHAT THIS IS FOR.  "I hid a chest behind destructible blocks and the
reachability check failed it" is a bug report about a MODEL, and the only
honest way to answer it is to state, as executable cases, exactly which
shapes the model admits and which it refuses. Guessing produced two wrong
diagnoses before this file existed: a probe with a one-tile barrier
(crossed by a plain jump, so it passed with the bug present) and a probe
whose chest cell had air underneath (so the fall landed past it).

THE ENGINE'S TRUTH.  Neither openable tile is ability-gated. Vess's dash
breaks tiles directly ahead of him -- player.lua, in the dashT branch --
and it is available from the first room of the game; every player
projectile sets breaksTiles; crumble falls away 0.45s after anything
stands on it. So the model may assume the player removes them.

THE MODEL'S SIDE.  passable() already lets a body move through one, and
moves() already has a break-and-drop rule for one directly underfoot. The
gap was standable(): it excluded '%c', so nothing could ever STAND in one
-- which does not matter while a jump can arc across, and matters
entirely once the wall is wider than a dash. Measured: the two rules
agree up to 7 tiles of thickness and diverge at 8.

Adding a case here is cheaper than rediscovering it. Every entry states
the shape and what must happen to it.
"""

import os
import sys
import tempfile

import roommodel as RM

ROOM = """return {
  zone = "mosswood", music = "mosswood",
  mapPos = { x = 0, y = 0, w = 1, h = 1 },
  gates = { G = "never_set" },
  key = { ["K"] = "chest:probe:scrap:1", ["f"] = "finfish", [":"] = "gnat" },
  links = { A = { "elsewhere", "B" } },
  map = [[
%(rows)s]],
}
"""

# Each room is 20 wide. Door A is on the left wall; K is the chest.
CASES = [
    ("breakable wall, 8 thick", True, [
        "####################",
        "#..................#",
        "A..................#",
        "A........###########",
        "A%%%%%%%%K##########",
        "####################",
        "####################",
        "####################"]),
    ("crumble wall, 8 thick", True, [
        "####################",
        "#..................#",
        "A..................#",
        "A........###########",
        "Acccccccc K#########".replace(" ", "c"),
        "####################",
        "####################",
        "####################"]),
    ("pit under a % lid", True, [
        "####################",
        "#..................#",
        "A..................#",
        "A.........%%%......#",
        "##########.K.#######",
        "####################",
        "####################",
        "####################"]),
    ("alcove behind a % wall", True, [
        "####################",
        "#..................#",
        "A..................#",
        "A........###########",
        "A........%%K########",
        "####################",
        "####################",
        "####################"]),
    ("shaft up through a %", True, [
        "####################",
        "#######.K.##########",
        "#######.#.##########",
        "#######.%.##########",
        "A..................#",
        "####################",
        "####################",
        "####################"]),
    # --- controls: widening the rule must not open these ---
    ("rock lid (control)", False, [
        "####################",
        "#..................#",
        "A..................#",
        "A.........###......#",
        "##########.K.#######",
        "####################",
        "####################",
        "####################"]),
    ("rock wall (control)", False, [
        "####################",
        "#..................#",
        "A..................#",
        "A........###########",
        "A########K##########",
        "####################",
        "####################",
        "####################"]),
    ("closed gate (control)", False, [
        "####################",
        "#..................#",
        "A..................#",
        "A........###########",
        "AGGGGGGGGK##########",
        "####################",
        "####################",
        "####################"]),
    ("lava (control)", False, [
        "####################",
        "#..................#",
        "A..................#",
        "A........###########",
        "ALLLLLLLLK##########",
        "####################",
        "####################",
        "####################"]),
]


def build(rows):
    fd, path = tempfile.mkstemp(suffix=".lua", prefix="reachprobe_")
    os.write(fd, (ROOM % {"rows": "\n".join(rows) + "\n"}).encode())
    os.close(fd)
    try:
        return RM.parse_room(path)
    finally:
        os.unlink(path)


# ------------------------------------------------------------------
# LIQUID SETTLE: the model's grid must agree with the engine's tiles.
# ------------------------------------------------------------------
# world.lua floods any cell whose TILE is AIR -- a plain '.' as much as an
# entity spawn character. roommodel settled spawn characters only, so a
# '.' with water on every side stayed air in the model and checkrooms
# reported the water above it as floating over nothing. Rock above still
# has to stop it, or the fix is just a bigger flood.
SETTLE = [
    # (name, rows, (x, y), expected character after parsing)
    ("air inside water floods", [
        "####################",
        "#..................#",
        "A~~~~~~~~~~~~~~~~~~#",
        "A~~~~~~~~~.~~~~~~~~#",
        "A~~~~~~~~~~~~~~~~~~#",
        "####################",
        "####################",
        "####################"], (10, 3), "~"),
    ("a spawn char floods too", [
        "####################",
        "#..................#",
        "A~~~~~~~~~~~~~~~~~~#",
        "A~~~~~~~~~f~~~~~~~~#",
        "A~~~~~~~~~~~~~~~~~~#",
        "####################",
        "####################",
        "####################"], (10, 3), "~"),
    # The rule is `above is water, OR both sides are` -- so rock overhead
    # alone does NOT stop it, and asserting that it did was this file
    # being wrong about the engine rather than the engine being wrong.
    # It takes rock above AND rock to one side.
    ("rock above and beside stops it", [
        "####################",
        "#..................#",
        "A~~~~~~~~~#~~~~~~~~#",
        "A~~~~~~~~#.~~~~~~~~#",
        "A~~~~~~~~~#~~~~~~~~#",
        "####################",
        "####################",
        "####################"], (10, 3), "."),
    ("rock above alone does NOT stop it", [
        "####################",
        "#..................#",
        "A~~~~~~~~~#~~~~~~~~#",
        "A~~~~~~~~~.~~~~~~~~#",
        "A~~~~~~~~~#~~~~~~~~#",
        "####################",
        "####################",
        "####################"], (10, 3), "~"),
    ("a dry cave under rock stays dry", [
        "####################",
        "A~~~~~~~~~~~~~~~~~~#",
        "A##################.",
        "A.........:........#",
        "####################",
        "####################",
        "####################",
        "####################"], (10, 3), ":"),
]


def settle_cases():
    fails = []
    for name, rows, (x, y), want in SETTLE:
        bad = [i for i, r in enumerate(rows) if len(r) != 20]
        if bad:
            fails.append("%s: rows %s are not 20 wide" % (name, bad))
            continue
        room = build(rows)
        got = room.g[y][x]
        print("  %s %-32s (%d,%d) parses as '%s' (want '%s')"
              % ("ok  " if got == want else "FAIL", name, x, y, got, want))
        if got != want:
            fails.append(name)
    return fails


def main():
    fails = []
    for name, want, rows in CASES:
        bad = [i for i, r in enumerate(rows) if len(r) != 20]
        if bad:
            fails.append("%s: rows %s are not 20 wide" % (name, bad))
            continue
        target = None
        for y, r in enumerate(rows):
            x = r.find("K")
            if x >= 0:
                target = (x, y)
        nav = RM.Nav(build(rows), flags=set())
        # A probe whose chest cell is not itself a place you can stand is
        # not testing reachability, it is testing nothing.
        if not nav.standable(*target) and rows[target[1]][target[0]] == "K":
            fails.append("%s: the chest cell is not standable -- bad probe" % name)
            continue
        got = target in nav.reach_from_door("A")
        print("  %s %-24s reachable=%-5s (want %s)"
              % ("ok  " if got == want else "FAIL", name, got, want))
        if got != want:
            fails.append(name)

    print()
    fails += settle_cases()

    print()
    if fails:
        print("FAIL %d movement-model case(s): %s" % (len(fails), "; ".join(fails)))
        return 1
    print("%d movement-model cases hold" % (len(CASES) + len(SETTLE)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
