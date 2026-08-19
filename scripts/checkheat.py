#!/usr/bin/env python3
"""checkheat -- the Coldstore's chain validator.

THE BUG THIS EXISTS TO MAKE IMPOSSIBLE.

    Fire spreads exactly one way in the Coldstore: somebody carries it,
    from a brazier that is already lit, before the spark burns out. So
    the zone is a chain, and a chain with one gap a tile too wide is
    not a hard puzzle -- it is an unreachable half of a zone. And it is
    completely invisible in a room file. Nothing about

        ["c"] = "brazier:c5b",

    tells you whether a bot carrying fire at 0.85 speed can get there
    from the last one before the flame dies in its hands.

    This walks the chain outward from the hearth exactly as a player
    would -- through doors, up ledges, across gaps, at the real carry
    speed against the real spark timer -- and fails naming the first
    brazier that cannot be reached.

It reads its numbers out of src/cold.lua and src/entities/player.lua
rather than keeping copies. A validator that owns its own copy of the
constant it is validating passes forever.

Run from game/:  python3 ../scripts/checkheat.py
"""
import heapq
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import roommodel as RM                                    # noqa: E402

T = 16
ROOMS = "src/data/rooms"

# ------------------------------------------------------------------
# Constants, read from the source of truth
# ------------------------------------------------------------------
def lua_num(src, name):
    m = re.search(r"^\s*%s\s*=\s*([-\d./*+ ]+?)\s*(?:--.*)?$"
                  % re.escape(name), src, re.M)
    if not m:
        sys.exit("checkheat: could not read %s" % name)
    return eval(m.group(1).strip())          # "1 / 2.2" and "10.0" both


COLD = open("src/cold.lua").read()
PLAYER = open("src/entities/player.lua").read()

SPARK_BURN = lua_num(COLD, "Cold.SPARK_BURN")
CARRY_SLOW = lua_num(COLD, "Cold.CARRY_SLOW")
SPARK_R = lua_num(COLD, "Cold.SPARK_R")
FILL_COILED = lua_num(COLD, "Cold.FILL_COILED")
FILL_BARE = lua_num(COLD, "Cold.FILL_BARE")
BITE_TICK = lua_num(COLD, "Cold.BITE_TICK")
BITE_FRAC = lua_num(COLD, "Cold.BITE_FRAC")

RUN_SPEED = float(re.search(r"runSpeed\s*=\s*([\d.]+)", PLAYER).group(1))
CARRY_SPEED = RUN_SPEED * CARRY_SLOW      # px/s

# Time model. Horizontal is the honest one; the vertical numbers are
# deliberately generous to the LEVEL (they under-count climbing time),
# so a chain this tool passes is a chain with margin in hand.
RISE_SPEED = 180.0        # px/s averaged over a jump's rise
FALL_SPEED = 300.0        # BASE.maxFall
JUMP_SETUP = 0.14         # per jump, for the crouch-and-go
DOOR_TIME = 0.55          # room transition fade, during which the spark burns


def move_cost(x, y, nx, ny):
    dx = abs(nx - x) * T / CARRY_SPEED
    if ny < y:
        dy = (y - ny) * T / RISE_SPEED + JUMP_SETUP
    elif ny > y:
        dy = (ny - y) * T / FALL_SPEED
    else:
        dy = 0.0
    return dx + dy


# ------------------------------------------------------------------
# Load the zone
# ------------------------------------------------------------------
def load_zone(zone):
    rooms = {}
    for fn in sorted(os.listdir(ROOMS)):
        if not fn.endswith(".lua"):
            continue
        src = open(os.path.join(ROOMS, fn)).read()
        m = re.search(r'zone\s*=\s*"(\w+)"', src)
        if m and m.group(1) == zone:
            r = RM.parse_room(os.path.join(ROOMS, fn))
            rooms[r.name] = r
    return rooms


ZONE = "coldstore"
rooms = load_zone(ZONE)
if not rooms:
    sys.exit("checkheat: no %s rooms found (run me from game/)" % ZONE)

# The chain is walked with the zone's own gates open: a thawplate inside
# the Coldstore is solvable from inside the Coldstore, and a chain that
# looked broken because of one is a false alarm. Anything genuinely
# unreachable is checkprogress's job, not this one.
flags = set(RM.ALL_ABILITIES) | {"cryocoils", "bulwark", "cinderram"}
for r in rooms.values():
    for f in r.gates.values():
        flags.add(f[1:] if f.startswith("!") else f)
    for f in getattr(r, "door_req", {}).values():
        flags.add(f)

# ------------------------------------------------------------------
# Braziers
# ------------------------------------------------------------------
braziers = {}       # id -> (room, x, y, is_hearth)
dupes = []
for r in rooms.values():
    for ch, spec in r.key.items():
        if not spec.startswith("brazier"):
            continue
        parts = spec.split(":")
        bid = parts[1] if len(parts) > 1 else "?"
        hearth = len(parts) > 2 and parts[2] == "hearth"
        for (x, y) in r.spawns.get(ch, []):
            if bid in braziers:
                dupes.append(bid)
            braziers[bid] = (r.name, x, y, hearth)

fails = []
if not braziers:
    fails.append("no braziers in the %s at all" % ZONE)
for d in dupes:
    fails.append("two braziers share the id %r -- they would light "
                 "each other from across the zone" % d)

hearths = [b for b, v in braziers.items() if v[3]]
if len(hearths) != 1:
    fails.append("expected exactly one hearth, found %d (%s). The chain "
                 "has to start somewhere and only somewhere."
                 % (len(hearths), ", ".join(sorted(hearths)) or "none"))

# ------------------------------------------------------------------
# The traversal graph: every standable cell in every room, plus doors
# ------------------------------------------------------------------
navs = {name: RM.Nav(r, flags) for name, r in rooms.items()}


def neighbours(node):
    room, x, y = node
    nav = navs[room]
    out = []
    for (nx, ny) in nav.moves(x, y):
        out.append(((room, nx, ny), move_cost(x, y, nx, ny)))
    # standing in a door cell: step through to the partner room
    ch = rooms[room].g[y][x]
    if ch in RM.DOORS and ch in rooms[room].links:
        dst, ddoor = rooms[room].links[ch]
        if dst in rooms:
            for (dx, dy) in navs[dst].arrivals(ddoor):
                out.append(((dst, dx, dy), DOOR_TIME))
    return out


def dijkstra(sources):
    """Seconds of carry time from the nearest source to every cell."""
    dist = {}
    pq = []
    for s in sources:
        dist[s] = 0.0
        heapq.heappush(pq, (0.0, s))
    while pq:
        d, node = heapq.heappop(pq)
        if d > dist.get(node, 1e18) + 1e-9:
            continue
        for nxt, w in neighbours(node):
            nd = d + w
            if nd < dist.get(nxt, 1e18) - 1e-9:
                dist[nxt] = nd
                heapq.heappush(pq, (nd, nxt))
    return dist


def cells_of(bid):
    """Every cell from which this brazier can be lit by walking into it."""
    room, x, y, _ = braziers[bid]
    r = rooms[room]
    reach = int(SPARK_R // T) + 1
    out = []
    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            nx, ny = x + dx, y + dy
            if 0 <= nx < r.W and 0 <= ny < r.H and navs[room].is_node(nx, ny):
                out.append((room, nx, ny))
    return out


# ------------------------------------------------------------------
# Walk the chain outward from the hearth
# ------------------------------------------------------------------
print("== the chain ==")
print("   spark %.1fs   carry %.0f px/s (%.2f x %.0f)   reach %.0f px"
      % (SPARK_BURN, CARRY_SPEED, CARRY_SLOW, RUN_SPEED, SPARK_R))
print("")

lit = set(hearths)
order = []
progress = True
while progress:
    progress = False
    sources = []
    for b in lit:
        sources.extend(cells_of(b))
    dist = dijkstra(sources)
    best = None
    for bid in braziers:
        if bid in lit:
            continue
        d = min((dist[c] for c in cells_of(bid) if c in dist), default=None)
        if d is None:
            continue
        if d <= SPARK_BURN and (best is None or d < best[1]):
            best = (bid, d)
    if best:
        bid, d = best
        lit.add(bid)
        order.append((bid, d))
        progress = True

for bid, d in order:
    room = braziers[bid][0]
    margin = SPARK_BURN - d
    flag = "  " if margin >= 1.5 else "!!"
    print("%s %-8s %-12s %5.2fs carry   %+5.2fs margin"
          % (flag, bid, room, d, margin))

unreached = [b for b in braziers if b not in lit]
if unreached:
    # name the FIRST one, with the distance it actually needs, so the fix
    # is "move it four tiles" rather than "something is wrong somewhere"
    sources = []
    for b in lit:
        sources.extend(cells_of(b))
    dist = dijkstra(sources)
    for bid in sorted(unreached):
        d = min((dist[c] for c in cells_of(bid) if c in dist), default=None)
        room = braziers[bid][0]
        if d is None:
            fails.append("brazier %r in %s cannot be REACHED at all from "
                         "the lit chain -- not slowly, not ever" % (bid, room))
        else:
            fails.append("brazier %r in %s is %.2fs of carry from the "
                         "nearest lit one; a spark lasts %.1fs. Short by "
                         "%.2fs." % (bid, room, d, SPARK_BURN, d - SPARK_BURN))

tight = [(b, d) for b, d in order if SPARK_BURN - d < 1.0]
if tight:
    print("")
    print("   NOTE: %d crossing(s) land with under a second in hand: %s"
          % (len(tight), ", ".join("%s (%.2fs)" % (b, SPARK_BURN - d)
                                   for b, d in tight)))

# ------------------------------------------------------------------
# Every cold room must have fire in it, or be a room you only cross
# ------------------------------------------------------------------
print("")
print("== the air ==")
import math
bites = max(1, math.ceil(1.0 / BITE_FRAC) - 1)
bare_down = 1.0 / FILL_BARE + BITE_TICK * bites
coil_down = 1.0 / FILL_COILED + BITE_TICK * bites
# an ESTIMATE. coldstore_test.lua drives the real player and measures it;
# these two lines exist so the chain numbers above have a scale next to
# them, not as a second source of truth.
print("   without Cryo Coils: ~%.1fs to down (est)" % bare_down)
print("   with them:          ~%.1fs (est)" % coil_down)
print("   ...a coiled bot covers %.0f tiles of open floor before the "
      "meter fills" % (1.0 / FILL_COILED * RUN_SPEED / T))

for name in sorted(rooms):
    r = rooms[name]
    if not r.cold:
        continue
    here = [b for b, v in braziers.items() if v[0] == name]
    if not here:
        fails.append("%s is cold and has no brazier in it: there is nowhere "
                     "in that room to stop" % name)
    else:
        print("   %-12s cold, %d brazier(s): %s"
              % (name, len(here), ", ".join(sorted(here))))
for name in sorted(rooms):
    if not rooms[name].cold:
        here = [b for b, v in braziers.items() if v[0] == name]
        print("   %-12s warm%s" % (name, ", hearth" if any(
            braziers[b][3] for b in here) else ""))

# ------------------------------------------------------------------
# The carrier cannot shoot. A route that needs a wall broken is not a
# route the carrier can take.
# ------------------------------------------------------------------
for name in sorted(rooms):
    r = rooms[name]
    if any("%" in row for row in r.g):
        fails.append("%s has breakable '%%' tiles. The spark carrier "
                     "cannot shoot, so any crossing that needs one broken "
                     "must be broken BEFORE the carry -- check it by hand "
                     "or teach this tool about it" % name)

print("")
if fails:
    for f in fails:
        print("FAIL " + f)
    print("%d problem(s)" % len(fails))
    sys.exit(1)
print("OK  %d braziers, chain complete from %s" % (len(braziers), hearths[0]))
