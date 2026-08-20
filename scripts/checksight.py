#!/usr/bin/env python3
"""checksight -- can you SEE the boss, and can you REACH the shelves?

Two failures that a room file cannot show you and that no other
validator looks for. Both were found by playing, not by any tool, which
is the definition of a gap.

CAN YOU SEE IT.

    The camera follows the players' midpoint and clamps to the room:

        camY = clamp(playerCentreY - VH/2, 0, roomH - VH)

    In a 22-row arena that ceiling is 352 - 270 = 82, so ANYTHING above
    y=82 is off-screen while you are standing on the floor. The
    Archivist rode a rail at y=44. The fight was unwinnable-feeling for
    a reason that had nothing to do with the fight: you could not see
    the boss.

    A vertical fight you climb toward is a different thing and is fine.
    So the rule is not "visible from the floor" -- it is **visible from
    somewhere you can stand**. If there is nowhere in the arena you can
    stand and see the boss's opening position, that is a failure. If it
    is visible but not from the main floor, that is reported, because it
    is correct for a tower and wrong for a rail.

CAN YOU REACH THE SHELVES.

    A `=` ledge on row R is stood on at row R-1. The Threshold's shelves
    were on row 13 -- stand row 12 -- and the floor's stand row is 16.
    Four tiles of rise, and Vess jumps three. They were decoration.

    MEASURED BEFORE RULED. The first version of this check demanded
    every arena shelf be reachable by base Vess and failed seven of the
    eleven arenas, including ones that have shipped for months. That is
    a wrong rule, not sixty bugs: Vess's mobility never improves --
    SPARK JUMP and DRIFT VANES are both Lu's -- so almost every arena
    shelf in this game is LU'S GROUND by construction.

    So there are two levels. A shelf no bot can reach with the full
    movement kit is broken geometry and FAILS. A shelf only Lu can reach
    is reported, because in a fight where either bot may need to get off
    the floor that asymmetry should be a decision rather than an
    accident -- and if you want a shelf Vess can use, the number to hit
    is three tiles of rise and four of gap from something he can already
    stand on.

Run from game/:  python3 ../scripts/checksight.py
"""
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import roommodel as RM                                    # noqa: E402

VW, VH, T = RM.viewport()  # read out of main.lua, never copied
BOSSES = "src/entities/bosses.lua"

src = open(BOSSES).read()

# where each boss opens, and how big it is
place = dict((m.group(1), (m.group(2), m.group(3))) for m in
             re.finditer(r"(\w+) = function\(World\) return (.+?), (.+?) end", src))
size = {}
for cls, body in re.findall(r"function (\w+):init\(x, y\)(.*?)\nend", src, re.S):
    i = re.search(r'id = "(\w+)"', body)
    h = re.search(r"h = (\d+)", body)
    w = re.search(r"w = (\d+)", body)
    if i:
        size[i.group(1)] = (int(w.group(1)) if w else 32,
                            int(h.group(1)) if h else 24)

# which room each boss is armed in -- a tripwire column, or a prop that
# wakes it (the Threshold's kept brazier)
arena = {}
for f in glob.glob("src/data/rooms/*.lua"):
    s = open(f).read()
    n = os.path.basename(f)[:-4]
    for b in re.findall(r'"boss:(\w+)', s):
        arena[b] = n
    for b in re.findall(r'"brazier:\w+:kept:(\w+)"', s):
        arena[b] = n

fails, notes = [], []


def cam_y(fy):
    """Camera top with a bot standing on tile row fy."""
    room_h = ROOM.H * T
    return min(max(0.0, (fy * T + 7) - VH / 2.0), max(0, room_h - VH))


print("== can you see the boss ==")
for b in sorted(arena):
    ROOM = RM.parse_room("src/data/rooms/%s.lua" % arena[b])
    nav = RM.Nav(ROOM, set(RM.ALL_ABILITIES))
    stand = [(x, y) for y in range(ROOM.H) for x in range(ROOM.W)
             if nav.standable(x, y)]
    if not stand:
        continue
    floor_row = max(y for _, y in stand)

    ex, ey = place.get(b, (None, None))
    if ey is None:
        notes.append("%s has no PLACE entry" % b)
        continue
    env = {"r": ROOM}
    try:
        by = eval(ey.replace("World.w", "r.W").replace("World.h", "r.H")
                    .replace("T", "16"), {}, env)
    except Exception:
        notes.append("%s: could not read its opening height (%r)" % (b, ey))
        continue
    bw, bh = size.get(b, (32, 24))

    # every standable cell from which the whole body is on screen
    seen_from = []
    for (x, y) in stand:
        cy = cam_y(y)
        if by >= cy and by + bh <= cy + VH:
            seen_from.append((x, y))
    from_floor = any(y == floor_row for _, y in seen_from)

    if not seen_from:
        fails.append(
            "%s in %s opens at y=%d (h=%d) and there is NOWHERE in the "
            "arena you can stand and see it. The camera clamps at y=%d in "
            "a %d-row room."
            % (b, arena[b], by, bh, max(0, ROOM.H * T - VH), ROOM.H))
        mark = "FAIL"
    elif not from_floor:
        mark = "climb"
        notes.append("%s in %s is only visible after climbing (%d of %d "
                     "standable cells see it). Correct for a tower fight, "
                     "wrong for one that rides a rail -- check which this is."
                     % (b, arena[b], len(seen_from), len(stand)))
    else:
        mark = "ok"
    print("   %-15s %-13s y=%-4d cam ceiling %-4d  %s"
          % (b, arena[b], by, max(0, ROOM.H * T - VH), mark))

# ------------------------------------------------------------------
print("")
print("== can both bots reach the arena's shelves ==")
# VESS is base jump plus the grapple, forever -- the SPARK JUMP and the
# DRIFT VANES are Lu's, and he never gets a better leg. LU is everything.
VESS = {"grapple"}
LU = {"grapple", "sparkjump", "driftvanes"}

for b in sorted(arena):
    name = arena[b]
    ROOM = RM.parse_room("src/data/rooms/%s.lua" % name)

    def reachable(kit):
        nav = RM.Nav(ROOM, kit)
        st = [(x, y) for y in range(ROOM.H) for x in range(ROOM.W)
              if nav.standable(x, y)]
        if not st:
            return None, None, None
        fr = max(y for _, y in st)
        rc = nav.reach_from([(x, fr) for (x, y) in st if y == fr])
        lg = [(x, y) for (x, y) in st
              if y < fr and ROOM.g[y + 1][x] == "="]
        return lg, rc, fr

    ledges, luReach, floor_row = reachable(LU)
    if ledges is None:
        continue
    if not ledges:
        print("   %-15s %-13s no shelves" % (b, name))
        continue
    _, vessReach, _ = reachable(VESS)
    dead = [c for c in ledges if c not in luReach]
    luOnly = [c for c in ledges if c in luReach and c not in vessReach]
    print("   %-15s %-13s %2d shelf cells: %2d Vess, %2d Lu-only, %2d dead"
          % (b, name, len(ledges), len(ledges) - len(luOnly) - len(dead),
             len(luOnly), len(dead)))
    if dead:
        rows = sorted(set(y for _, y in dead))
        fails.append(
            "%s: %d of %d shelf cells cannot be reached by ANY bot with "
            "the full movement kit (rows %s). That is broken geometry, "
            "not a design choice. A `=` on row R is stood on at R-1; the "
            "floor's stand row is %d."
            % (name, len(dead), len(ledges),
               ", ".join(str(r) for r in rows), floor_row))
    elif luOnly:
        notes.append("%s: %d of %d shelf cells are LU-ONLY -- Vess never "
                     "gets a better JUMP (spark jump and vanes are both "
                     "Lu's), though his mid-air charge does carry him %d "
                     "tiles across. Fine if intended; if he needs a shelf, "
                     "put it within %d tiles of RISE of ground he already "
                     "has -- the charge buys distance, never height."
                     % (name, len(luOnly), len(ledges), RM.DASH_GAP,
                        RM.JUMP_H))

print("")
for n in notes:
    print("  NOTE " + n)
if fails:
    print("")
    for f in fails:
        print("  FAIL " + f)
    print("%d problem(s)" % len(fails))
    sys.exit(1)
print("OK  every boss can be seen, and every arena shelf can be stood on")
