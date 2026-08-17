#!/usr/bin/env python3
"""World-map layout solver: place rooms so the map tells the truth.

The map screen draws each room as a box at (ZONE_OFFSETS[zone] + mapPos)
and a line for every door link. That only reads as a map if a door that
goes RIGHT draws a room to the right, touching. Before this script 8 of
the 9 cross-zone edge doors failed that: deep_stair_1's right-hand door
to furn_1 drew furn_1 sixteen cells away, so the Furnace read as a
distant island connected by a long diagonal instead of the room next
door. Portal doors (shafts, shortcut lifts) have no side, so nothing at
all pinned core_1 near deep_stair_2 -- they sat 11 cells apart with a
line straight across the atlas.

What is solved for: an integer cell position per room.

  hard   no two room rects may overlap
  cost   edge links want gap 0 in the door's own direction, and want the
         two door mouths lined up across that seam
  cost   portal links want to be short -- they have no direction, so all
         they can express is "these two are near each other"
  cost   zone bounding boxes want to not overlap, so a zone label has
         somewhere to sit that is unambiguously its own
  cost   the whole atlas wants to stay small

Search is simulated annealing seeded from the CURRENT layout, so the
result stays the map you already know; it moves single rooms, whole
zones, and link-connected clusters.

  python3 maplayout.py            report the current layout's cost
  python3 maplayout.py --solve    search, print the diff, change nothing
  python3 maplayout.py --solve --write   also rewrite the room files

Run from game/ with PYTHONPATH=../scripts.
"""
import argparse
import collections
import glob
import math
import random
import re
import sys

WORLDMAP = "src/data/worldmap.lua"
DOORS = set("ABCDEF")

# cost weights -- gap dominates: a door that does not touch is the fault
# you actually see. Alignment is a polish term. Portals are deliberately
# weak so they never drag a real adjacency out of true.
W_GAP = 12.0
W_FACE = 30.0        # edge link whose rooms do not face each other at all
W_ALIGN = 2.5
W_PORTAL = 1.2
W_ZONEBOX = 1.5
W_AREA = 0.04
W_SPREAD = 0.5       # a zone scattered across the atlas: legible as a
                     # set of links, illegible as a place
W_OVER = 90.0        # two rooms in one cell: never acceptable in the
                     # answer, but passable on the way there


# ------------------------------------------------------------------
# load
# ------------------------------------------------------------------
class Room:
    __slots__ = ("id", "zone", "x", "y", "w", "h", "edges", "links", "haspos",
                 "arena")


def load():
    src = open(WORLDMAP).read()
    body = re.search(r"WM\.ZONE_OFFSETS = \{(.*?)\n\}", src, re.S).group(1)
    off = {}
    for m in re.finditer(r"(\w+)\s*=\s*\{\s*x\s*=\s*(-?\d+),\s*y\s*=\s*(-?\d+)\s*\}", body):
        off[m.group(1)] = (int(m.group(2)), int(m.group(3)))

    rooms = {}
    for fn in sorted(glob.glob("src/data/rooms/*.lua")):
        name = fn.split("/")[-1][:-4]
        if name == "test_arena":
            continue
        s = open(fn).read()
        z = re.search(r'zone = "(\w+)"', s)
        arena = bool(re.search(r'\n  arena = "', s))
        m = re.search(r"map = \[\[\n(.*?)\]\]", s, re.S)
        if not (z and m):
            continue
        grid = [r for r in m.group(1).split("\n") if r.strip()]
        H, W = len(grid), len(grid[0])
        cells = collections.defaultdict(list)
        for gy, row in enumerate(grid):
            for gx, ch in enumerate(row):
                if ch in DOORS:
                    cells[ch].append((gx, gy))
        edges = {}
        for ch, cs in cells.items():
            x0 = min(c[0] for c in cs); x1 = max(c[0] for c in cs)
            y0 = min(c[1] for c in cs); y1 = max(c[1] for c in cs)
            side = None
            if x0 == 0:
                side = "left"
            elif x1 == W - 1:
                side = "right"
            elif y0 == 0:
                side = "top"
            elif y1 == H - 1:
                side = "bottom"
            # where along the wall, 0..1
            edges[ch] = (side, (x0 + x1 + 1) / 2.0 / W, (y0 + y1 + 1) / 2.0 / H)
        lm = re.search(r"links = \{(.*?)\n  \}", s, re.S)
        links = {}
        if lm:
            for em in re.finditer(r'([A-F])\s*=\s*\{\s*"(\w+)",\s*"([A-F])"', lm.group(1)):
                links[em.group(1)] = (em.group(2), em.group(3))
        mp = re.search(r"mapPos = \{ x = (-?\d+), y = (-?\d+), w = (\d+), h = (\d+) \}", s)
        r = Room()
        r.id, r.zone = name, z.group(1)
        r.haspos = bool(mp)
        if mp:
            mx, my, r.w, r.h = (int(v) for v in mp.groups())
        else:
            # a room that never declared one: size it the way its
            # neighbours are sized, one cell per screen-ish
            mx, my = 0, 0
            r.w, r.h = max(1, round(W / 22.0)), max(1, round(H / 17.0))
        ox, oy = off.get(r.zone, (0, 0))
        r.x, r.y = ox + mx, oy + my
        r.edges, r.links = edges, links
        r.arena = arena
        rooms[name] = r
    seed_missing(rooms)
    return off, rooms


def seed_missing(rooms):
    """A room with no mapPos starts stacked on its zone origin, which is
    an overlap, and the solver's hard no-overlap rule would then reject
    every move forever. Park it on the nearest free cell first."""
    for name, r in sorted(rooms.items()):
        if r.haspos:
            continue
        others = [o for o in rooms.values() if o is not r]
        for rad in range(0, 40):
            spots = [(r.x + dx, r.y + dy)
                     for dx in range(-rad, rad + 1)
                     for dy in range(-rad, rad + 1)
                     if max(abs(dx), abs(dy)) == rad]
            for (x, y) in spots:
                if any(min(x + r.w, o.x + o.w) - max(x, o.x) > 0 and
                       min(y + r.h, o.y + o.h) - max(y, o.y) > 0 for o in others):
                    continue
                r.x, r.y = x, y
                break
            else:
                continue
            break


def build_links(rooms):
    """Undirected link list. Each entry:
         ('H'|'V', A, B, alignA, alignB)   A is left/above B
         ('P', A, B, None, None)           portal, no direction
    """
    out, seen = [], set()
    for name, r in sorted(rooms.items()):
        for ch, (o, och) in r.links.items():
            if o not in rooms:
                continue
            key = tuple(sorted(((name, ch), (o, och))))
            if key in seen:
                continue
            seen.add(key)
            side = r.edges.get(ch, (None, 0, 0))[0]
            oside = rooms[o].edges.get(och, (None, 0, 0))[0]
            if side is None and oside is None:
                out.append(("P", name, o, None, None))
                continue
            if side is None:
                side = {"left": "right", "right": "left",
                        "top": "bottom", "bottom": "top"}[oside]
            if side in ("right", "left"):
                A, cha, B, chb = ((name, ch, o, och) if side == "right"
                                  else (o, och, name, ch))
                out.append(("H", A, B,
                            rooms[A].edges[cha][2], rooms[B].edges[chb][2]))
            else:
                A, cha, B, chb = ((name, ch, o, och) if side == "bottom"
                                  else (o, och, name, ch))
                out.append(("V", A, B,
                            rooms[A].edges[cha][1], rooms[B].edges[chb][1]))
    return out


# ------------------------------------------------------------------
# cost
# ------------------------------------------------------------------
# Everything below works on parallel arrays indexed by room number, not
# on dicts of names. The search evaluates the whole cost function on the
# order of a million times; the dict version managed 3600 trials a second
# and kept parking in the first local minimum it found.
class Layout:
    def __init__(self, rooms, links):
        self.ids = sorted(rooms)
        self.idx = {n: i for i, n in enumerate(self.ids)}
        self.w = [rooms[n].w for n in self.ids]
        self.h = [rooms[n].h for n in self.ids]
        self.x = [rooms[n].x for n in self.ids]
        self.y = [rooms[n].y for n in self.ids]
        zn = sorted({rooms[n].zone for n in self.ids})
        self.zi = {z: i for i, z in enumerate(zn)}
        self.znames = zn
        self.zone = [self.zi[rooms[n].zone] for n in self.ids]
        self.zrooms = [[] for _ in zn]
        for i, z in enumerate(self.zone):
            self.zrooms[z].append(i)
        # Four rooms in this world have two doors on the SAME wall
        # (cold_2, furn_2, moss_1, deep_stair_1). A one-cell-tall room
        # has one cell of that wall, so only one of the two pairs can
        # ever draw touching; the other is a dashed line no matter what
        # the search does. Weighting each link by how connected its ends
        # are decides which one loses: the branch to a dead-end secret,
        # not the main corridor.
        deg = collections.Counter()
        for kind, A, B, _, _ in links:
            if kind != "P":
                deg[A] += 1; deg[B] += 1
        self.links = []
        for kind, A, B, al, bl in links:
            a, b = self.idx[A], self.idx[B]
            if kind == "P":
                # A shaft into a boss arena is a SHORTCUT home -- it is
                # supposed to span the zone, and pulling it short drags
                # the whole zone out of shape. A shaft that is a zone's
                # front door (core_1 off the Deep Stair) is the opposite:
                # being near is the only thing it can say.
                wgt = 0.5 if (rooms[A].arena or rooms[B].arena) else 2.4
            else:
                lo = min(deg[A], deg[B])
                wgt = 0.4 if lo <= 1 else 1.0 + 0.2 * (deg[A] + deg[B] - 4)
                wgt = max(0.4, min(2.5, wgt))
            self.links.append((kind, a, b,
                               0.0 if al is None else al,
                               0.0 if bl is None else bl, wgt))
        # occupancy: cell -> how many rooms cover it, plus a running
        # count of doubled-up cells. Overlap is priced, not forbidden:
        # an earlier version rejected any move that overlapped anything,
        # which walls the search into whatever pocket it started in --
        # a zone cannot cross the atlas without passing through another
        # zone on the way.
        self.occ = {}
        self.over = 0
        for i in range(len(self.ids)):
            self._fill(i)

    def _cells(self, i, x, y):
        return [(x + dx, y + dy)
                for dx in range(self.w[i]) for dy in range(self.h[i])]

    def _fill(self, i):
        occ = self.occ
        for c in self._cells(i, self.x[i], self.y[i]):
            k = occ.get(c, 0)
            if k:
                self.over += 1
            occ[c] = k + 1

    def _clear(self, i):
        occ = self.occ
        for c in self._cells(i, self.x[i], self.y[i]):
            k = occ[c]
            if k > 1:
                self.over -= 1
                occ[c] = k - 1
            else:
                del occ[c]

    def snapshot(self):
        return (list(self.x), list(self.y))

    def restore(self, snap):
        self.x, self.y = list(snap[0]), list(snap[1])
        self.occ = {}
        self.over = 0
        for i in range(len(self.ids)):
            self._fill(i)

    def move(self, moving, dx, dy):
        for i in moving:
            self._clear(i)
        for i in moving:
            self.x[i] += dx
            self.y[i] += dy
        for i in moving:
            self._fill(i)

    # --------------------------------------------------------------
    def link_rows(self):
        x, y, w, h = self.x, self.y, self.w, self.h
        rows = []
        for kind, a, b, al, bl, wg in self.links:
            if kind == "P":
                d = math.hypot((x[a] + w[a] / 2) - (x[b] + w[b] / 2),
                               (y[a] + h[a] / 2) - (y[b] + h[b] / 2))
                rows.append((wg * W_PORTAL * d, kind, a, b, None, None, d))
            elif kind == "H":
                gap = x[b] - (x[a] + w[a])
                face = min(y[a] + h[a], y[b] + h[b]) - max(y[a], y[b])
                mis = abs((y[a] + h[a] * al) - (y[b] + h[b] * bl))
                c = wg * (W_GAP * abs(gap) + W_ALIGN * mis + facepen(face))
                rows.append((c, kind, a, b, gap, face, mis))
            else:
                gap = y[b] - (y[a] + h[a])
                face = min(x[a] + w[a], x[b] + w[b]) - max(x[a], x[b])
                mis = abs((x[a] + w[a] * al) - (x[b] + w[b] * bl))
                c = wg * (W_GAP * abs(gap) + W_ALIGN * mis + facepen(face))
                rows.append((c, kind, a, b, gap, face, mis))
        return rows

    def zone_boxes(self):
        big = 10 ** 6
        bx0 = [big] * len(self.znames); by0 = [big] * len(self.znames)
        bx1 = [-big] * len(self.znames); by1 = [-big] * len(self.znames)
        for i, z in enumerate(self.zone):
            if self.x[i] < bx0[z]: bx0[z] = self.x[i]
            if self.y[i] < by0[z]: by0[z] = self.y[i]
            if self.x[i] + self.w[i] > bx1[z]: bx1[z] = self.x[i] + self.w[i]
            if self.y[i] + self.h[i] > by1[z]: by1[z] = self.y[i] + self.h[i]
        return bx0, by0, bx1, by1

    def cost(self):
        x, y, w, h = self.x, self.y, self.w, self.h
        c = 0.0
        for kind, a, b, al, bl, wg in self.links:
            if kind == "P":
                dx = (x[a] + w[a] * 0.5) - (x[b] + w[b] * 0.5)
                dy = (y[a] + h[a] * 0.5) - (y[b] + h[b] * 0.5)
                c += wg * W_PORTAL * math.sqrt(dx * dx + dy * dy)
            elif kind == "H":
                gap = x[b] - (x[a] + w[a])
                ay1, by1_ = y[a] + h[a], y[b] + h[b]
                face = (ay1 if ay1 < by1_ else by1_) - (y[a] if y[a] > y[b] else y[b])
                e = W_GAP * (gap if gap >= 0 else -gap)
                e += W_ALIGN * abs((y[a] + h[a] * al) - (y[b] + h[b] * bl))
                if face <= 0:
                    e += W_FACE * (1 - face)
                c += wg * e
            else:
                gap = y[b] - (y[a] + h[a])
                ax1, bx1_ = x[a] + w[a], x[b] + w[b]
                face = (ax1 if ax1 < bx1_ else bx1_) - (x[a] if x[a] > x[b] else x[b])
                e = W_GAP * (gap if gap >= 0 else -gap)
                e += W_ALIGN * abs((x[a] + w[a] * al) - (x[b] + w[b] * bl))
                if face <= 0:
                    e += W_FACE * (1 - face)
                c += wg * e
        bx0, by0, bx1, by1 = self.zone_boxes()
        n = len(self.znames)
        for i in range(n):
            for j in range(i + 1, n):
                ox = min(bx1[i], bx1[j]) - max(bx0[i], bx0[j])
                if ox <= 0:
                    continue
                oy = min(by1[i], by1[j]) - max(by0[i], by0[j])
                if oy > 0:
                    c += W_ZONEBOX * ox * oy
        c += W_AREA * (max(bx1) - min(bx0)) * (max(by1) - min(by0))
        # dead space inside each zone's own bounding box. Without this
        # the search happily flings three Scrapyard rooms to the bottom
        # of the map because their doors are shafts and shafts are cheap;
        # the links stay true and the zone stops being a place.
        for z in range(n):
            box = (bx1[z] - bx0[z]) * (by1[z] - by0[z])
            for i in self.zrooms[z]:
                box -= self.w[i] * self.h[i]
            if box > 0:
                c += W_SPREAD * box
        c += W_OVER * self.over
        return c


def facepen(face):
    """Two rooms joined by a side door must at least be beside each
    other. A flat penalty lets the search park a pair twenty cells apart
    and pay once; this scales, so drifting apart keeps costing."""
    return 0.0 if face > 0 else W_FACE * (1 - face)


# ------------------------------------------------------------------
# search
# ------------------------------------------------------------------
def clusters(L):
    """Link-connected groups, capped at 8. Used as a coarse move: drag a
    room and the handful of rooms it is doored to, so a corridor travels
    as a corridor instead of being torn apart one room at a time."""
    adj = collections.defaultdict(set)
    for kind, a, b, _, _, _ in L.links:
        adj[a].add(b); adj[b].add(a)
    out = {}
    for i in range(len(L.ids)):
        grp, frontier = {i}, [i]
        while frontier and len(grp) < 8:
            cur = frontier.pop()
            for m in adj[cur]:
                if m not in grp and len(grp) < 8:
                    grp.add(m); frontier.append(m)
        out[i] = sorted(grp)
    return out


def ideal_offset(kind, a, b, L, al, bl, rng):
    """Where b wants to sit relative to a's top-left, if this one link
    were the only thing in the world."""
    if kind == "P":
        r = rng.randint(1, 3)
        return (rng.randint(-r, r), rng.randint(-r, r))
    if kind == "H":
        return (L.w[a], int(round(L.h[a] * al - L.h[b] * bl)))
    return (int(round(L.w[a] * al - L.w[b] * bl)), L.h[a])


def anneal(L, iters=400000, seed=7, T0=8.0, T1=0.03):
    rng = random.Random(seed)
    n = len(L.ids)
    grpof = clusters(L)
    groups = list(grpof.values())
    cur = L.cost()
    best, bestsnap = cur, L.snapshot()
    links = L.links
    for it in range(iters):
        T = T0 * (T1 / T0) ** (it / iters)
        roll = rng.random()
        if roll < 0.22 and links:
            # directed move: snap one side of a link into true. Random
            # jitter alone will not walk a zone sixteen cells across the
            # atlas -- every step of that journey is uphill.
            kind, a, b, al, bl, _wg = links[rng.randrange(len(links))]
            if rng.random() < 0.5:
                if kind == "H":
                    want = (-L.w[b], int(round(L.h[a] * bl - L.h[b] * al)))
                elif kind == "V":
                    want = (int(round(L.w[a] * bl - L.w[b] * al)), -L.h[b])
                else:
                    want = ideal_offset(kind, a, b, L, al, bl, rng)
                a, b = b, a
            else:
                want = ideal_offset(kind, a, b, L, al, bl, rng)
            moving = grpof[b]
            dx = L.x[a] + want[0] - L.x[b]
            dy = L.y[a] + want[1] - L.y[b]
        elif roll < 0.66:
            moving = [rng.randrange(n)]
            rad = 1 if rng.random() < 0.7 else 3
            dx = rng.randint(-rad, rad); dy = rng.randint(-rad, rad)
        elif roll < 0.87:
            moving = groups[rng.randrange(n)]
            rad = 1 if rng.random() < 0.7 else 2
            dx = rng.randint(-rad, rad); dy = rng.randint(-rad, rad)
        else:
            moving = L.zrooms[rng.randrange(len(L.znames))]
            rad = 1 if rng.random() < 0.6 else 3
            dx = rng.randint(-rad, rad); dy = rng.randint(-rad, rad)
        if dx == 0 and dy == 0:
            continue
        L.move(moving, dx, dy)
        c = L.cost()
        if c <= cur or rng.random() < math.exp((cur - c) / T):
            cur = c
            if c < best - 1e-9 and L.over == 0:
                best, bestsnap = c, L.snapshot()
        else:
            L.move(moving, -dx, -dy)
    L.restore(bestsnap)
    return best


def seed_from_doors(L, rng):
    """Constructive seed: walk the door graph and place each room where
    its door says it belongs, relative to the room you came from. This
    is the map drawn the way you would draw it by hand, walking. It
    collides freely -- annealing untangles it -- but it starts from a
    layout that is TRUE, rather than from one that is merely tidy."""
    order = sorted(range(len(L.ids)), key=lambda i: -len(L.zrooms[L.zone[i]]))
    adj = collections.defaultdict(list)
    for kind, a, b, al, bl, _wg in L.links:
        adj[a].append((kind, b, al, bl, False))
        adj[b].append((kind, a, al, bl, True))
    placed = {}
    for root in order:
        if root in placed:
            continue
        placed[root] = (L.x[root], L.y[root])
        frontier = [root]
        while frontier:
            cur = frontier.pop(0)
            cx, cy = placed[cur]
            for kind, nb, al, bl, rev in adj[cur]:
                if nb in placed:
                    continue
                if kind == "P":
                    continue          # a shaft says nothing about direction
                if not rev:           # cur is A, nb is B
                    if kind == "H":
                        d = (L.w[cur], int(round(L.h[cur] * al - L.h[nb] * bl)))
                    else:
                        d = (int(round(L.w[cur] * al - L.w[nb] * bl)), L.h[cur])
                else:                 # cur is B, nb is A
                    if kind == "H":
                        d = (-L.w[nb], int(round(L.h[cur] * bl - L.h[nb] * al)))
                    else:
                        d = (int(round(L.w[cur] * bl - L.w[nb] * al)), -L.h[nb])
                placed[nb] = (cx + d[0], cy + d[1])
                frontier.append(nb)
    for i, (x, y) in placed.items():
        L.x[i], L.y[i] = x, y
    L.restore((L.x, L.y))


# ------------------------------------------------------------------
# report / write
# ------------------------------------------------------------------
def report(L, label):
    rows = L.link_rows()
    portal = [r for r in rows if r[1] == "P"]
    edge = [r for r in rows if r[1] != "P"]
    # only a gap or a non-facing pair is a real fault; sub-cell door
    # misalignment is polish and would drown the list
    bad = [r for r in edge if r[4] != 0 or r[5] <= 0]
    pl = sum(r[6] for r in portal)
    mis = sum(r[6] for r in edge)
    print("== %s ==" % label)
    print("  %d edge doors, %d not drawn touching" % (len(edge), len(bad)))
    print("  %d portal doors, total line length %.1f cells" % (len(portal), pl))
    print("  door misalignment %.1f cells total; layout cost %.1f"
          % (mis, L.cost()))
    for r in sorted(bad, key=lambda t: -t[0]):
        print("     %-14s %-14s %s  gap %-4d face %-4d"
              % (L.ids[r[2]], L.ids[r[3]], r[1], r[4], r[5]))
    return L.cost()


def longest_portals(L, k=6):
    rows = [r for r in L.link_rows() if r[1] == "P"]
    rows.sort(key=lambda r: -r[6])
    return [(L.ids[r[2]], L.ids[r[3]], r[6]) for r in rows[:k]]


def write_back(L, rooms):
    bx0, by0, _, _ = L.zone_boxes()
    off = {z: (bx0[i], by0[i]) for i, z in enumerate(L.znames)}
    n = 0
    for i, name in enumerate(L.ids):
        r = rooms[name]
        ox, oy = off[r.zone]
        line = "  mapPos = { x = %d, y = %d, w = %d, h = %d }," % (
            L.x[i] - ox, L.y[i] - oy, L.w[i], L.h[i])
        fn = "src/data/rooms/%s.lua" % name
        s = open(fn).read()
        if r.haspos:
            s2 = re.sub(r"  mapPos = \{ x = -?\d+, y = -?\d+, w = \d+, h = \d+ \},",
                        line, s, count=1)
        else:
            s2 = re.sub(r"(\n  zone = \"\w+\"[^\n]*\n)", r"\1" + line + "\n",
                        s, count=1)
        if s2 != s:
            open(fn, "w").write(s2)
            n += 1
    src = open(WORLDMAP).read()
    body = re.search(r"(WM\.ZONE_OFFSETS = \{)(.*?)(\n\})", src, re.S)
    lines = ["  %s = { x = %d, y = %d }," % (z, off[z][0], off[z][1])
             for z in sorted(off)]
    src = src[:body.start(2)] + "\n" + "\n".join(lines) + src[body.end(2):]
    open(WORLDMAP, "w").write(src)
    print("rewrote %d room files and %s" % (n, WORLDMAP))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--solve", action="store_true")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--iters", type=int, default=600000)
    ap.add_argument("--restarts", type=int, default=6)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--load", help="start from a saved position file")
    ap.add_argument("--save", help="write the winning positions here")
    ap.add_argument("--cool", type=float, default=None,
                    help="starting temperature for refine passes")
    a = ap.parse_args()
    off, rooms = load()
    links = build_links(rooms)
    missing = [n for n, r in rooms.items() if not r.haspos]
    if missing:
        print("  NOTE %s had no mapPos and never drew on the map; it is "
              "placed now" % ", ".join(sorted(missing)))
    L = Layout(rooms, links)
    if a.load:
        import json
        saved = json.load(open(a.load))
        L.restore(([saved[n][0] for n in L.ids], [saved[n][1] for n in L.ids]))
        print("  loaded positions from %s" % a.load)
    before = report(L, "CURRENT")
    if not a.solve:
        return 0

    print()
    start = L.snapshot()
    bestsnap, bestc = start, before
    for k in range(a.restarts):
        rng = random.Random(a.seed + k * 101)
        # half the passes refine what is already there, half rebuild the
        # map from the doors outward and then untangle it
        if k % 2 == 0:
            L.restore((list(bestsnap[0]), list(bestsnap[1])))
            hot = a.cool if a.cool is not None else 6.0
        else:
            L.restore((list(start[0]), list(start[1])))
            seed_from_doors(L, rng)
            hot = 14.0
        c = anneal(L, a.iters, a.seed + k * 101, T0=hot)
        tag = "  <- best" if c < bestc else ""
        print("  pass %d (%s): %.1f%s"
              % (k + 1, "refine" if k % 2 == 0 else "rebuild", c, tag))
        if c < bestc:
            bestc, bestsnap = c, L.snapshot()
    L.restore(bestsnap)
    print()
    after = report(L, "SOLVED")
    moved = sum(1 for i, n in enumerate(L.ids)
                if (L.x[i], L.y[i]) != (rooms[n].x, rooms[n].y))
    print()
    print("  longest portal lines now:")
    for A, B, d in longest_portals(L):
        print("     %-14s %-14s %.1f cells" % (A, B, d))
    print()
    print("  %d of %d rooms moved; layout cost %.1f -> %.1f"
          % (moved, len(L.ids), before, after))
    if a.save:
        import json
        json.dump({n: [L.x[i], L.y[i]] for i, n in enumerate(L.ids)},
                  open(a.save, "w"))
        print("  saved positions to %s" % a.save)
    if a.write:
        if after > before:
            print("  refusing to write: the search found nothing better")
            return 1
        write_back(L, rooms)
    return 0


if __name__ == "__main__":
    sys.exit(main())
