#!/usr/bin/env python3
"""Shared traversal model for Emberdeep rooms.

Mirrors the engine's movement rules so validators (checkrooms.py,
genprogress.py) reason about the same world the player experiences:

  - '#' solid; '%' breakable and 'c' crumble are openable (passable,
    and support while intact); '=' oneway supports from above only.
  - Gates 'G'-'J' resolve through the room's gates table against a flag
    set: a normal gate is SOLID until its flag is held; an inverted
    '!flag' energy bridge is SOLID only while its flag is held.
  - Water '~' is swimmable. Lava 'L' KILLS: it is never a node and any
    fall that would end in lava is an invalid move.
  - Spikes '^v<>' are never stood on and never landed on (jumping over
    them is allowed, as in the engine).
  - Magne-grapple anchors 'n' work only with the 'grapple' flag, radius
    GRAPPLE_R (Chebyshev tiles, matching the engine's 110px rope).
  - Jump height is JUMP_H tiles (JUMP_H_SPARK with 'sparkjump'), gap
    clearance GAP_W tiles -- GAP_W_HOVER with 'driftvanes', because Lu's
    hover more than doubles her reach (engine measures 12.1 tiles).
  - Updraft columns ('updraft:<tiles>' entities) are ladder-like: with
    'driftvanes' Lu rides them upward one cell at a time and steps off to
    either side. Without the vanes they are ordinary air.

Physics constants are verified against the real engine by the
`calibrate` test scenario -- if the engine changes, that test fails and
these numbers must be re-measured.
"""
import re
from collections import deque

# ------------------------------------------------------------------
# THE ROOM ALPHABET HAS EXACTLY ONE OWNER: src/world.lua.
#
# These sets used to be typed out here, and in checkkeys.py, and in
# genscrap.py, and in load_test.lua. Four copies of one fact, each
# correct right up until the engine gains a tile char -- at which point
# they go stale silently and the guards stop guarding the newest
# character. `c` (crumble), `C` (a door letter) and `L` (lava) have each
# been keyed to an entity that then never spawned.
#
# So they are read out of the engine now, and checkchars.py enforces
# that nobody writes a second copy.
# ------------------------------------------------------------------
def _alphabet(path="src/world.lua"):
    src = open(path).read()
    m = re.search(r"local CHAR_TILE = \{(.*?)\n\}", src, re.S)
    tiles = dict(re.findall(r'\["(.)"\]\s*=\s*(\w+)', m.group(1)))

    def cs(var):
        mm = re.search(r"local %s = \{(.*?)\}" % var, src, re.S)
        return set(re.findall(r"(\w)\s*=\s*true", mm.group(1)))

    return tiles, cs("DOOR_CHARS"), cs("GATE_CHARS")


# ------------------------------------------------------------------
# THE VIEWPORT HAS EXACTLY ONE OWNER TOO: game/main.lua.
#
# Same failure mode as the alphabet, one floor down. checksight.py,
# checkcoop.py and genvanes.py each typed out `VW, VH = 480, 270` with a
# `# main.lua` comment beside it -- three copies of a number that three
# different tools use to decide whether a boss is on screen, whether
# co-op splits, and where a vane platform may go. Correct today; silently
# wrong the moment the viewport moves, and wrong in the direction that
# reports a working game as broken.
#
# Comments are stripped before searching, because prose describing a
# value looks exactly like the value to a regex, and this project has
# been bitten by that three times.
# ------------------------------------------------------------------
def viewport(path="main.lua"):
    """(VW, VH, TILE) read out of the engine. Run from game/."""
    src = re.sub(r"--[^\n]*", "", open(path).read())
    m = re.search(r"\bVW\s*=\s*(\d+)\s*,\s*VH\s*=\s*(\d+)", src)
    t = re.search(r"\bTILE\s*=\s*(\d+)", src)
    if not m or not t:
        raise SystemExit(
            "roommodel.viewport: no VW/VH/TILE in %s -- run from game/" % path)
    return int(m.group(1)), int(m.group(2)), int(t.group(1))


TILE_KIND, DOORS, GATES = _alphabet()
TILES = set(TILE_KIND)
LIQ = set(c for c, k in TILE_KIND.items() if k in ("WATER", "LAVA"))
SPIKES = set(c for c, k in TILE_KIND.items() if k.startswith("SPIKE"))
OPENABLE = set(c for c, k in TILE_KIND.items() if k in ("BREAK", "CRUMBLE"))
# every character a room map may hold that is NOT free for an entity
RESERVED = TILES | DOORS | GATES
JUMP_H = 3
JUMP_H_SPARK = 4
GAP_W = 4
# Lu with the DRIFT VANES. The engine measures 12.1 tiles of level gap
# (hoversim: 1.3s of hover at 26px/s fall against 112px/s run); we model
# 10 for two tiles of margin, because a hover gap is a long commitment
# and the player is holding a button for the whole of it.
GAP_W_HOVER = 10
GRAPPLE_R = 6  # 110px rope / 16px tiles

# VESS'S CHARGE, MID-AIR. He has no better jump -- SPARK JUMP and DRIFT
# VANES are both Lu's -- but he can charge once per airtime, and the
# charge SUSPENDS GRAVITY: DASH_SPEED 265px/s for dashT 0.2s is 53px of
# dead-level travel in the middle of a fall.
#
# MEASURED, by driving the real Player over a real gap and widening it
# until he stops landing (tools/dash_test.lua): the charge is worth
# FOUR extra tiles of level gap over a plain running jump. We model
# three, following the same convention as GAP_W_HOVER -- which models 10
# against 12.1 measured -- because a mid-air charge is a commitment and
# a model that assumes a perfect one will call a room passable that
# nobody can actually pass.
#
# It costs nothing to own: every run has Vess from the first room, so
# this is baseline reach, not an ability gate.
DASH_GAP = GAP_W + 3

ALL_ABILITIES = frozenset({"sparkjump", "grapple", "hydroseals",
                           "heatplating", "telenet", "driftvanes"})


class Room:
    def __init__(self, name, g, gates, key, links, hot=False, cold=False,
                 door_req=None):
        self.name = name
        self.g = g
        self.H, self.W = len(g), len(g[0])
        self.gates = gates      # char -> flag ('!' prefix = bridge)
        self.key = key          # char -> spec string
        self.links = links      # char -> (room, door)
        # A door sealed until a flag is held: `req = "boss_crucible"` on the
        # link. Tile gates cannot express this -- the traversal model counts
        # a jump ARC over a door as using it, so a two-tile pocket around a
        # doorway is not sealable no matter how it is built. The requirement
        # rides on the door itself instead, and genprogress folds it into
        # that door's edge requirements.
        self.door_req = door_req or {}
        self.hot = hot
        self.cold = cold
        self.doors = {}
        self.spawns = {}        # entity char -> [(x, y)]
        self.updraft = {}       # (x, y) -> column base y, for every cell
        tile = RESERVED
        for y in range(self.H):
            for x in range(self.W):
                ch = g[y][x]
                if ch in DOORS:
                    self.doors.setdefault(ch, []).append((x, y))
                elif ch not in tile:
                    self.spawns.setdefault(ch, []).append((x, y))

    def build_updrafts(self):
        """Thermal columns. The map char marks the BASE cell; the column
        rises `n` tiles from there, inclusive, exactly as the entity does."""
        self.updraft = {}
        for ch, spec in self.key.items():
            if not spec.startswith("updraft:"):
                continue
            try:
                n = int(spec.split(":")[1])
            except (IndexError, ValueError):
                n = 1
            for (x, y) in self.spawns.get(ch, []):
                for k in range(n):
                    yy = y - k
                    if 0 <= yy < self.H:
                        self.updraft[(x, yy)] = y

    def door_side(self, ch):
        cells = self.doors[ch]
        xs = [c[0] for c in cells]
        ys = [c[1] for c in cells]
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        if x0 == 0:
            return "left"
        if x1 == self.W - 1:
            return "right"
        if y0 == 0:
            return "top"
        if y1 == self.H - 1:
            return "bottom"
        return "portal"


def parse_room(fname):
    src = open(fname).read()
    name = fname.split("/")[-1][:-4]
    m = re.search(r"map = \[\[\n(.*?)\]\]", src, re.S)
    rows = [list(r) for r in m.group(1).split("\n") if r.strip()]
    H, W = len(rows), len(rows[0])
    # record entity spawn positions BEFORE the liquid-settle pass: the
    # engine collects spawns first too (an underwater chest still spawns)
    tile = RESERVED
    pre_spawns = {}
    for y in range(H):
        for x in range(W):
            ch = rows[y][x]
            if ch not in tile:
                pre_spawns.setdefault(ch, []).append((x, y))
    # engine's liquid-settle pass: spawn chars inside a liquid body count
    # as that liquid (for TILE purposes only)
    for _ in range(3):
        for y in range(H):
            for x in range(W):
                ch = rows[y][x]
                if ch not in tile:
                    above = rows[y - 1][x] if y > 0 else "#"
                    left = rows[y][x - 1] if x > 0 else "#"
                    right = rows[y][x + 1] if x < W - 1 else "#"
                    if above == "~" or (left == "~" and right == "~"):
                        rows[y][x] = "~"
                    elif above == "L" or (left == "L" and right == "L"):
                        rows[y][x] = "L"
    g = ["".join(r) for r in rows]

    gates = {}
    gm = re.search(r"gates = \{(.*?)\}", src, re.S)
    if gm:
        for em in re.finditer(r'([A-J])\s*=\s*"([^"]+)"', gm.group(1)):
            gates[em.group(1)] = em.group(2)
    key = {}
    km = re.search(r"key = \{(.*?)\n  \}", src, re.S)
    if km:
        for em in re.finditer(r'\["(.)"\]\s*=\s*"([^"]+)"', km.group(1)):
            key[em.group(1)] = em.group(2)
    links, door_req = {}, {}
    lm = re.search(r"links = \{(.*?)\n  \}", src, re.S)
    if lm:
        for em in re.finditer(
                r'([A-F])\s*=\s*\{\s*"(\w+)"\s*,\s*"([A-F])"\s*'
                r'(?:,\s*req\s*=\s*"([^"]+)"\s*)?,?\s*\}', lm.group(1)):
            links[em.group(1)] = (em.group(2), em.group(3))
            if em.group(4):
                door_req[em.group(1)] = em.group(4)
    hot = "hot = true" in src
    cold = "cold = true" in src
    room = Room(name, g, gates, key, links, hot, cold, door_req)
    # THE COLDSTORE'S FALSE WALL. A gate that opens to the zone's own
    # work rather than to a flag fetched somewhere else:
    #   braziergate = { flag = "cradle_found", need = { "c5a", "c5b" } }
    room.braziergate = None
    bg = re.search(r'braziergate\s*=\s*\{(.*?)\}\s*,?\s*\n', src, re.S)
    if bg:
        body = bg.group(1)
        fm = re.search(r'flag\s*=\s*"([^"]+)"', body)
        need = re.findall(r'"([^"]+)"', body.split("need", 1)[1]) \
            if "need" in body else []
        if fm:
            room.braziergate = (fm.group(1), need)
    room.spawns = pre_spawns
    room.build_updrafts()
    return room


class Nav:
    """Traversal queries for one room under one flag set."""

    def __init__(self, room, flags):
        self.r = room
        self.flags = frozenset(flags)
        self.jump_h = JUMP_H_SPARK if "sparkjump" in self.flags else JUMP_H
        # the DRIFT VANES roughly double Lu's reach across a hole
        self.gap_w = GAP_W_HOVER if "driftvanes" in self.flags else GAP_W
        self.transit = set()  # cells the body passes through mid-fall/jump

    def riding(self, x, y):
        """Is (x, y) a thermal column cell this body can ride?"""
        return ("driftvanes" in self.flags
                and (x, y) in self.r.updraft
                and self.passable(x, y))

    def gate_solid(self, ch):
        flag = self.r.gates.get(ch)
        if flag is None:
            return True  # unmapped gate: engine treats as solid
        if flag.startswith("!"):
            return flag[1:] in self.flags   # bridge: solid while powered
        return flag not in self.flags        # gate: solid until opened

    def solid(self, x, y):
        if x < 0 or y < 0 or x >= self.r.W or y >= self.r.H:
            return True
        ch = self.r.g[y][x]
        if ch == "#":
            return True
        if ch in GATES:
            return self.gate_solid(ch)
        return False

    def passable(self, x, y):
        # can the player's body occupy / move through this cell
        # ('%'/'c' are openable, spikes hurt but the engine lets you cross;
        # we forbid ENDING moves on spikes via land()/is_node instead)
        if self.solid(x, y):
            return False
        return self.r.g[y][x] != "L"  # never path through lava

    def support(self, x, y):
        if self.solid(x, y):
            return True
        ch = self.r.g[y][x] if 0 <= x < self.r.W and 0 <= y < self.r.H else "#"
        return ch in "%c="

    def standable(self, x, y):
        ch = self.r.g[y][x]
        if self.solid(x, y) or ch in LIQ or ch in "%c" or ch in SPIKES:
            return False
        return self.support(x, y + 1)

    def is_node(self, x, y):
        ch = self.r.g[y][x]
        if ch == "L" or ch in SPIKES:
            return False
        if ch in GATES and self.gate_solid(ch):
            return False
        return (self.standable(x, y) or ch == "~" or ch in DOORS
                or ch == "n" or ch in GATES or self.riding(x, y))

    def land(self, nx, ny):
        """Fall from (nx, ny); returns landing node or None (lava/void)."""
        g = self.r.g
        path = []
        while True:
            if ny >= self.r.H:
                return None
            ch = g[ny][nx]
            if ch == "L":
                return None            # fell into lava: death, not a move
            if ch in SPIKES:
                return None            # landing on spikes: rejected
            path.append((nx, ny))
            if ch == "~" or ch in DOORS:
                self.transit.update(path)
                return (nx, ny)
            if self.support(nx, ny + 1):
                self.transit.update(path)
                return (nx, ny)
            ny += 1

    def moves(self, x, y):
        out = set()
        g = self.r.g
        W, H = self.r.W, self.r.H
        ch = g[y][x]
        if ch == "~":
            # swim: any adjacent passable
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and self.passable(nx, ny) \
                        and g[ny][nx] not in SPIKES:
                    out.add((nx, ny))
            # surface hop onto nearby ledges
            above = g[y - 1][x] if y > 0 else "#"
            if above != "~":
                for dy2 in (1, 2):
                    for dx2 in (-2, -1, 0, 1, 2):
                        nx, ny = x + dx2, y - dy2
                        if 0 <= nx < W and 0 <= ny < H and self.is_node(nx, ny):
                            out.add((nx, ny))
            # break-and-sink: shoot out a breakable floor tile below and
            # drop through the hole
            if y + 1 < H and g[y + 1][x] in "%c" and y + 2 < H:
                n = self.land(x, y + 2)
                if n:
                    out.add(n)
            return out
        # THERMAL COLUMN. Ride it a cell at a time while the vanes hold,
        # and step off sideways onto whatever is beside you at that height.
        # The column's declared height is the only limit -- riding costs no
        # vane charge in the engine, so the model must not invent one.
        if self.riding(x, y):
            if self.riding(x, y - 1):
                out.add((x, y - 1))
            for dx in (-1, 1):
                nx = x + dx
                if 0 <= nx < W and self.passable(nx, y) and g[y][nx] not in SPIKES:
                    if self.is_node(nx, y):
                        out.add((nx, y))
                    else:
                        n = self.land(nx, y)
                        if n:
                            out.add(n)

        # fall straight down (standing in an open gate shaft etc.)
        n0 = self.land(x, y)
        if n0 and n0 != (x, y):
            out.add(n0)
        # jumping in place sweeps the body through the cells above the
        # head (floating pickups are collected at the apex)
        for k in range(1, self.jump_h + 1):
            if y - k < 0 or not self.passable(x, y - k):
                break
            self.transit.add((x, y - k))
        # walk left/right, falling to landing
        for dx in (-1, 1):
            nx = x + dx
            if 0 <= nx < W and self.passable(nx, y):
                n = self.land(nx, y)
                if n:
                    out.add(n)
        reach = max(self.gap_w, DASH_GAP)
        # jump up onto ledges within jump_h, horizontal reach GAP_W.
        # BONK-HONEST arcs: the engine rises IMMEDIATELY on jump, so the
        # rise must happen in the launch column (path A) or, at most, the
        # first drift column (path C: jump while walking). "Drift far
        # sideways at ground level, then rise at the target" is a lie the
        # ceiling will refute (sky_4's boss door taught us).
        # ...and the charge extends the horizontal half of a CLIMBING
        # jump too, not only a level one: rise in the launch column, then
        # charge dead level onto a ledge much further across than a plain
        # jump reaches. The rise still has to happen first, which is why
        # dy is unchanged -- the charge buys distance, never height.
        for dy in range(1, self.jump_h + 1):
            for dx in range(-reach, reach + 1):
                nx, ny = x + dx, y - dy
                if not (0 <= nx < W and 0 <= ny < H and self.is_node(nx, ny)):
                    continue
                s = 1 if dx > 0 else -1
                adx = abs(dx)
                pathA = ([(x, y - k) for k in range(1, dy + 1)]
                         + [(x + i * s, ny) for i in range(1, adx + 1)])
                paths = [pathA]
                if adx >= 1:
                    pathC = ([(x + s, y - k) for k in range(0, dy + 1)]
                             + [(x + i * s, ny) for i in range(2, adx + 1)])
                    paths.append(pathC)
                for path in paths:
                    if all(0 <= px < W and 0 <= py < H
                           and self.passable(px, py) for (px, py) in path):
                        out.add((nx, ny))
                        self.transit.update(path)
                        break
        # jump across gaps at same height: the arc passes just above the
        # start row, so each crossed cell must be open at y or y-1.
        #
        # DASH_GAP rather than gap_w: Vess charges mid-air, the charge
        # holds him level for a fifth of a second, and he is in every
        # run from the first room. A model that stops at a plain running
        # jump calls rooms unreachable that are crossed this way daily.
        for dx in range(-reach, reach + 1):
            if dx == 0:
                continue
            nx = x + dx
            if not (0 <= nx < W and self.passable(nx, y)):
                continue
            s = 1 if dx > 0 else -1
            crossed = [(x + i * s, y) for i in range(1, abs(dx) + 1)]
            if all(self.passable(px, py)
                   or (py - 1 >= 0 and self.passable(px, py - 1))
                   for (px, py) in crossed):
                n = self.land(nx, y)
                if n:
                    out.add(n)
                    self.transit.update(crossed)
        # drop through one-way underfoot
        if y + 1 < H and g[y + 1][x] == "=" and y + 2 < H:
            n = self.land(x, y + 2)
            if n:
                out.add(n)
        # break-and-drop: a breakable/crumble tile underfoot can be shot
        # out (or crumbles) and fallen through
        if y + 1 < H and g[y + 1][x] in "%c" and y + 2 < H:
            n = self.land(x, y + 2)
            if n:
                out.add(n)
        # magne-grapple (needs the grapple module); the rope is 110px --
        # EUCLIDEAN 6.8 tiles, not a square -- and needs line of sight
        if "grapple" in self.flags:
            R = GRAPPLE_R
            R2 = (110.0 / 16.0) ** 2  # squared rope length in tiles
            for dy2 in range(-R, R + 1):
                for dx2 in range(-R, R + 1):
                    if dx2 * dx2 + dy2 * dy2 > R2:
                        continue
                    nx, ny = x + dx2, y + dy2
                    if 0 <= nx < W and 0 <= ny < H:
                        if (g[ny][nx] == "n" or (g[y][x] == "n"
                                                 and self.is_node(nx, ny))) \
                                and self.line_clear(x, y, nx, ny):
                            out.add((nx, ny))
        return out

    def line_clear(self, x0, y0, x1, y1):
        """Bresenham line of sight: every crossed cell must be passable."""
        dx, dy = abs(x1 - x0), abs(y1 - y0)
        sx = 1 if x1 > x0 else -1
        sy = 1 if y1 > y0 else -1
        err = dx - dy
        x, y = x0, y0
        while (x, y) != (x1, y1):
            e2 = 2 * err
            if e2 > -dy:
                err -= dy
                x += sx
            if e2 < dx:
                err += dx
                y += sy
            if (x, y) != (x1, y1) and not self.passable(x, y):
                return False
        return True

    def arrivals(self, ch):
        """Cells where the engine sets a player down when arriving at door
        ch (mirrors world.lua door placement)."""
        cells = self.r.doors[ch]
        xs = [c[0] for c in cells]
        ys = [c[1] for c in cells]
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        side = self.r.door_side(ch)
        out = []
        if side == "left":
            n = self.land(x1 + 1, y1)
            if n:
                out.append(n)
        elif side == "right":
            n = self.land(x0 - 1, y1)
            if n:
                out.append(n)
        elif side == "top":
            n = self.land((x0 + x1) // 2, y1 + 1)
            if n:
                out.append(n)
        elif side == "bottom":
            g = self.r.g
            for row in range(y0 - 1, max(1, y0 - 10), -1):
                for off in range(0, 5):
                    for tx in (x0 - 1 - off, x1 + 1 + off):
                        if not (1 <= tx < self.r.W - 1):
                            continue
                        # walk-back corridor toward the shaft must be
                        # open (mirrors the engine: no arrivals inside
                        # sealed pockets behind walls or closed gates)
                        edge = x0 - 1 if tx < x0 else x1 + 1
                        step = 1 if tx < x0 else -1
                        corridor = all(not self.solid(cx, row)
                                       for cx in range(tx + step, edge + step, step))
                        if corridor and self.passable(tx, row) \
                           and g[row][tx] not in LIQ \
                           and g[row][tx] not in SPIKES \
                           and self.support(tx, row + 1) \
                           and self.passable(tx, row - 1):
                            out.append((tx, row))
                    if out:
                        break
                if out:
                    break
        else:
            n = self.land((x0 + x1) // 2, y1)
            if n:
                out.append(n)
        return out or cells

    def reach_from(self, starts):
        """BFS over nodes from an iterable of start cells. Resets transit
        so touches() reflects only this traversal."""
        self.transit = set()
        starts = [s for s in starts if self.is_node(*s) or self.r.g[s[1]][s[0]] in DOORS]
        seen = set(starts)
        q = deque(starts)
        while q:
            x, y = q.popleft()
            for n in self.moves(x, y):
                if n not in seen and self.is_node(*n):
                    seen.add(n)
                    q.append(n)
        return seen

    def reach_from_door(self, ch):
        cells = self.r.doors[ch]
        start = set(self.arrivals(ch)) | set(cells)
        return self.reach_from(start)

    def touches(self, reach, cells, radius=1):
        """Does the reach set (or any mid-air transit cell) include or sit
        adjacent to a target cell? Entities are collected by body overlap,
        including while falling past them."""
        hit = reach | self.transit
        for (cx, cy) in cells:
            for dy in range(-radius, radius + 1):
                for dx in range(-radius, radius + 1):
                    if (cx + dx, cy + dy) in hit:
                        return True
        return False
