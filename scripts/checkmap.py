#!/usr/bin/env python3
"""World-map layout auditor.

The map screen draws each room as a box at
    (ZONE_OFFSETS[zone] + mapPos) * CELL
and marks each door link between them. Three ways that stops being a map:

  1. Two rooms drawn on the same cells. One hides the other.
  2. A room with no mapPos at all -- it simply never appears. moss_boss
     sat like that from the day it was written.
  3. A SIDE door whose two rooms are not drawn side by side. The door
     goes right; the map draws the other room up and to the left, eleven
     cells away, joined by a diagonal. Every such link is a line across
     the atlas, and enough of them turn the map into a cat's cradle --
     which is what it was before scripts/maplayout.py solved the layout.

Fault 3 is not always fixable: a one-cell-tall room with two doors on
its right-hand wall has one cell of wall and two rooms wanting it, so
one of them must be drawn as a shaft instead. Those are reported as
NOTE, with the pair that lost, rather than pretended away.

  python3 checkmap.py            audit
  python3 maplayout.py --solve   fix (a separate script; this one only judges)

Run from game/ with PYTHONPATH=../scripts.
"""
import collections
import sys

import maplayout as ML


def same_wall_conflicts(rooms, links):
    """room -> set of walls that more than one door wants."""
    side = collections.defaultdict(list)
    for kind, A, B, al, bl in links:
        if kind == "P":
            continue
        if kind == "H":
            side[(A, "right")].append(B); side[(B, "left")].append(A)
        else:
            side[(A, "bottom")].append(B); side[(B, "top")].append(A)
    out = {}
    for (n, s), partners in side.items():
        cap = rooms[n].h if s in ("left", "right") else rooms[n].w
        if len(partners) > cap:
            out[(n, s)] = (sorted(partners), cap)
    return out


def ideal_cells(L, kind, a, b):
    """The cells room b would have to sit on for this door to draw
    touching, given where a is."""
    for _k, _a, _b, al, bl, _wg in L.links:
        if _a == a and _b == b and _k == kind:
            break
    else:
        return []
    if kind == "H":
        bx = L.x[a] + L.w[a]
        by = L.y[a] + int(round(L.h[a] * al - L.h[b] * bl))
    else:
        bx = L.x[a] + int(round(L.w[a] * al - L.w[b] * bl))
        by = L.y[a] + L.h[a]
    return [(bx + dx, by + dy)
            for dx in range(L.w[b]) for dy in range(L.h[b])]


def main():
    off, rooms = ML.load()
    links = ML.build_links(rooms)
    L = ML.Layout(rooms, links)
    rows = L.link_rows()
    conflicts = same_wall_conflicts(rooms, links)
    crowded = set()
    for (n, s), (partners, cap) in conflicts.items():
        for p in partners:
            crowded.add(tuple(sorted((n, p))))

    fails, notes = [], []

    for n, r in sorted(rooms.items()):
        if not r.haspos:
            fails.append("%s has no mapPos -- it never draws on the map" % n)

    if L.over:
        # name the offenders, not just the area
        for i in range(len(L.ids)):
            for j in range(i + 1, len(L.ids)):
                ox = min(L.x[i] + L.w[i], L.x[j] + L.w[j]) - max(L.x[i], L.x[j])
                oy = min(L.y[i] + L.h[i], L.y[j] + L.h[j]) - max(L.y[i], L.y[j])
                if ox > 0 and oy > 0:
                    fails.append("%s and %s are drawn on the same %d cell(s)"
                                 % (L.ids[i], L.ids[j], ox * oy))

    # which room sits on each cell, so "why is it not touching" can be
    # answered with a name instead of a shrug
    occ = {}
    for i in range(len(L.ids)):
        for dx in range(L.w[i]):
            for dy in range(L.h[i]):
                occ[(L.x[i] + dx, L.y[i] + dy)] = L.ids[i]

    for c, kind, a, b, gap, face, mis in rows:
        if kind == "P" or (gap == 0 and face > 0):
            continue
        A, B = L.ids[a], L.ids[b]
        msg = ("%s -- %s is a %s door but they are drawn %s"
               % (A, B, "side" if kind == "H" else "floor/ceiling",
                  ("%d cells apart" % abs(gap)) if gap else "past each other"))
        if tuple(sorted((A, B))) in crowded:
            notes.append(msg + " (that wall is already spoken for)")
            continue
        # the map is flat and the world is not: a shaft can run behind a
        # room that a side view has to draw somewhere. If the cells B
        # would have to occupy are already someone else's, this pair is
        # blocked, not misplaced -- no amount of solving moves it.
        blockers = set()
        for (bx, by) in ideal_cells(L, kind, a, b):
            who = occ.get((bx, by))
            if who and who not in (A, B):
                blockers.add(who)
        if blockers:
            notes.append("%s (%s is in the way)"
                         % (msg, ", ".join(sorted(blockers))))
        else:
            fails.append(msg)

    portal = [r for r in rows if r[1] == "P"]
    print("== MAP LAYOUT ==")
    for m in fails:
        print("  FAIL %s" % m)
    for m in notes:
        print("  NOTE %s" % m)
    for (n, s), (partners, cap) in sorted(conflicts.items()):
        print("  NOTE %s has %d doors on its %s wall (%s) but is only %d cell(s) "
              "tall there" % (n, len(partners), s, ", ".join(partners), cap))
    x0, y0 = min(L.x), min(L.y)
    x1 = max(L.x[i] + L.w[i] for i in range(len(L.ids)))
    y1 = max(L.y[i] + L.h[i] for i in range(len(L.ids)))
    print("  atlas %d x %d cells, %d rooms, %d door links (%d shafts, "
          "total line %.0f cells)"
          % (x1 - x0, y1 - y0, len(L.ids), len(rows), len(portal),
             sum(r[6] for r in portal)))
    print("%d layout failures, %d accepted" % (len(fails), len(notes)))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
