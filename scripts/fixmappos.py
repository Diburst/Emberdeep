#!/usr/bin/env python3
"""Bring a resized room's map-cell rectangle back in line -- and move as
little else as possible.

    PYTHONPATH=../scripts python3 ../scripts/fixmappos.py moss_3
    PYTHONPATH=../scripts python3 ../scripts/fixmappos.py --write moss_3

WHY NOT maplayout --solve.  maplayout is a simulated annealer over the
whole world: it takes any cost improvement it finds, so running it in its
gentlest refine mode against the map exactly as it stands today moves
TWELVE of 83 rooms and improves the cost by 5%.  That is the right tool
for "lay the world out again" and completely the wrong one for "I added a
row to one room."  An edit to moss_3 must not relocate cold_boss.

So this is a repair, not a solver.  It sets the named rooms' cells to the
formula, then pushes -- by the smallest distance that clears the overlap,
in the cheapest of the four directions -- only those rooms that are
genuinely in the way, and then only those in the way of THOSE.  A room
nothing collides with never moves, which means running this when nothing
is wrong is silent and writes nothing.

mapPos is stored relative to the room's ZONE ORIGIN but rooms from
different zones share one canvas, so every overlap test here is in
absolute cell space and the offset goes back on at write time.
"""

import argparse
import re
import sys

import maplayout as ML


def rects(rooms):
    """Cell rectangles, keyed by room id.

    ML.load() has ALREADY folded the zone offset into r.x/r.y -- these
    are absolute canvas cells, not the zone-relative numbers that sit in
    the room file. Adding the offset again here put moss_2 on top of
    upper_stair and made a clean map look broken.
    """
    return {n: [r.x, r.y, r.w, r.h] for n, r in rooms.items() if r.haspos}


def hit(a, b):
    return (a[0] < b[0] + b[2] and b[0] < a[0] + a[2]
            and a[1] < b[1] + b[3] and b[1] < a[1] + a[3])


def push(a, b):
    """Smallest translation of b that clears a. Ties break horizontally,
    because the map is wider than it is tall and a sideways nudge is
    less likely to hit something else."""
    cands = [
        (a[0] + a[2] - b[0], 0),          # right
        (a[0] - b[2] - b[0], 0),          # left
        (0, a[1] + a[3] - b[1]),          # down
        (0, a[1] - b[3] - b[1]),          # up
    ]
    return min(cands, key=lambda d: (abs(d[0]) + abs(d[1]), d[1] != 0))


def repair(R, targets):
    """Returns (moved, error). Mutates R."""
    ids = sorted(R)
    guard = 0
    moved = {}
    while True:
        guard += 1
        if guard > 4000:
            return moved, "could not settle the layout in 4000 pushes"
        pair = None
        for i in range(len(ids)):
            for j in range(i + 1, len(ids)):
                if hit(R[ids[i]], R[ids[j]]):
                    pair = (ids[i], ids[j])
                    break
            if pair:
                break
        if not pair:
            return moved, None
        a, b = pair
        # A room the user resized holds its ground; the other one yields.
        if a in targets and b in targets:
            return moved, "%s and %s were both resized into each other" % (a, b)
        if a in targets:
            mover, anchor = b, a
        elif b in targets:
            mover, anchor = a, b
        else:
            # neither was touched: this overlap predates us. Say so
            # rather than quietly shoving a room that was already wrong.
            return moved, ("%s and %s already overlapped before this edit"
                           % (a, b))
        dx, dy = push(R[anchor], R[mover])
        R[mover][0] += dx
        R[mover][1] += dy
        p = moved.setdefault(mover, [0, 0])
        p[0] += dx
        p[1] += dy
        targets = targets | {mover}      # what we moved, we now defend


LINE = re.compile(
    r"  mapPos = \{ x = -?\d+, y = -?\d+, w = \d+, h = \d+ \},")


def write(off, rooms, R):
    n = 0
    for name, rect in sorted(R.items()):
        r = rooms[name]
        ox, oy = off.get(r.zone, (0, 0))
        if [r.x + ox, r.y + oy, r.w, r.h] == rect:
            continue
        fn = "src/data/rooms/%s.lua" % name
        s = open(fn).read()
        line = "  mapPos = { x = %d, y = %d, w = %d, h = %d }," % (
            rect[0] - ox, rect[1] - oy, rect[2], rect[3])
        s2, k = LINE.subn(line, s, count=1)
        if k != 1:
            print("  FAIL %s: no mapPos line to rewrite" % name)
            return -1
        open(fn, "w").write(s2)
        n += 1
    return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("rooms", nargs="*", help="rooms whose size changed")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--shrink", action="store_true",
                    help="also give cells BACK when a room got smaller "
                         "(off by default: an oversized cell is harmless)")
    ap.add_argument("--all", action="store_true",
                    help="re-derive cells for EVERY room, not just the named "
                         "ones (respects the accepted undersizes)")
    a = ap.parse_args()

    off, rooms = ML.load()
    R = rects(rooms)
    targets = set()

    names = sorted(rooms) if a.all else a.rooms
    for n in names:
        if n not in rooms:
            print("FAIL no such room: %s" % n)
            return 1
        if n not in R:
            print("FAIL %s has no mapPos" % n)
            return 1
        r = rooms[n]
        if not getattr(r, "tw", None):
            continue
        ew, eh = ML.cells_for(r.tw, r.th)
        if n in ML.ACCEPTED_UNDERSIZE and (ew, eh) != (r.w, r.h):
            continue
        # GROW ONLY, unless asked. checkmap fails an undersized rect --
        # it hides corridors and steals the wall a door needs -- and only
        # NOTES an oversized one, which is white space. So a room that
        # shrank keeps its footprint by default: silently taking cells
        # back can only lose information from the map.
        if not a.shrink:
            ew, eh = max(ew, R[n][2]), max(eh, R[n][3])
        if (ew, eh) != (R[n][2], R[n][3]):
            print("  %s is %dx%d tiles -> %dx%d cells (was %dx%d)"
                  % (n, r.tw, r.th, ew, eh, R[n][2], R[n][3]))
            R[n][2], R[n][3] = ew, eh
        targets.add(n)

    moved, err = repair(R, targets)
    if err:
        print("FAIL %s" % err)
        return 1

    if moved:
        print("  displaced to make room:")
        for n in sorted(moved):
            print("    %-16s by %+d,%+d cells" % (n, moved[n][0], moved[n][1]))
    else:
        print("  nothing had to move")

    if a.write:
        k = write(off, rooms, R)
        if k < 0:
            return 1
        print("  rewrote %d room file(s)" % k)
    elif moved or targets:
        print("  (dry run -- pass --write to apply)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
