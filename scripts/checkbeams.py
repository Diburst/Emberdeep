#!/usr/bin/env python3
"""checkbeams -- the Crystal Hollows circuit validator.

Two rules, both of them invisible in a room file and both of them capable
of bricking a zone.

RULE 1 -- LU MUST BE ABLE TO STAND THERE.

    Waking a dormant emitter used to be instantaneous, so it was enough
    for Lu to BRUSH the emitter's radius: clipping the corner of it at
    the top of a jump woke the thing. It is a two-second channel now,
    and a channel that is interrupted unwinds -- so an emitter is only
    usable if there is somewhere Lu can STAND, still, for two seconds,
    with the emitter inside her dome.

    That is a much harder condition than the old one, and nothing in the
    room file shows it. This checks it: for every dormant emitter, some
    cell that is standable AND reachable from a door the run can arrive
    at must sit within the dome's reach of the emitter's centre.

RULE 2 -- NO EMITTER IS SCENERY.

    Every emitter in the game has to be able to do a job. A job is one
    of: it can put its beam on a node (in SOME legal configuration of
    the room's panels and rotors), or it burns something that is in the
    way -- an enemy on the beam's own line. An emitter that can do
    neither is decoration, and decoration that looks exactly like a
    mechanism is worse than no mechanism at all.

Run from game/:  python3 ../scripts/checkbeams.py
"""
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import roommodel as RM                                    # noqa: E402
import checkprogress as CP                                # noqa: E402
import genprogress as GP                                  # noqa: E402

T = 16
# Player.domeRadius = 36, and Player:update tests `< domeRadius + 8`.
DOME_REACH = 36 + 8

# beam directions, matching Props.BDX/BDY: 1 right, 2 down, 3 left, 4 up
DIRV = {"right": (1, 0), "down": (0, 1), "left": (-1, 0), "up": (0, -1)}
# a mirror maps an incoming direction to an outgoing one
MIRROR = {
    "f": {"right": "up", "down": "left", "left": "down", "up": "right"},
    "b": {"right": "down", "down": "right", "left": "up", "up": "left"},
}
BEAM_STEPS = 240

# things a beam is allowed to kill -- if an emitter's only job is burning
# one of these, that still counts as a job
ENEMY_KINDS = {
    "shardling", "prismwisp", "cryoturret", "finfish", "depthmine",
    "slagling", "glowmite", "husk", "drifter", "sentry",
}


# ------------------------------------------------------------------
# The arena's numbers are READ OUT of bosses.lua, never restated here.
# A validator that keeps its own copy of a constant stops validating the
# moment somebody tunes the real one.
# ------------------------------------------------------------------
_ARENA = {}


def arena_cfg():
    if _ARENA:
        return _ARENA.get("cfg")
    _ARENA["cfg"] = None
    try:
        src = open("src/entities/bosses.lua").read()
    except OSError:
        return None
    xs = re.search(r"Prismtyrant\.STATION_X\s*=\s*\{([^}]*)\}", src)
    y = re.search(r"Prismtyrant\.STATION_Y\s*=\s*(\d+)", src)
    j = re.search(r"Prismtyrant\.JITTER_T\s*=\s*(\d+)", src)
    if not (xs and y and j):
        return None
    cols = [int(v) for v in re.findall(r"\d+", xs.group(1))]
    _ARENA["cfg"] = {"x": cols, "y": int(y.group(1)), "jitter": int(j.group(1))}
    return _ARENA["cfg"]


def arena_boss(room):
    """The boss this room is the arena for, read off its own spawn table
    rather than from a `arena =` field the room model does not carry."""
    for spec in room.key.values():
        if spec.startswith("boss:"):
            return spec.split(":")[1]
    return None


def station_cells(room):
    """Every cell a boss station can occupy in this room, or empty."""
    if arena_boss(room) != "prismtyrant":
        return set()
    cfg = arena_cfg()
    if not cfg:
        return set()
    out = set()
    for sx in cfg["x"]:
        for col in range(sx - cfg["jitter"], sx + cfg["jitter"] + 1):
            out.add((col, cfg["y"]))
    return out


def parts_of(room):
    """spawn char -> dict(kind, spec, x, y) for every beam part."""
    out = {}
    for ch, spec in room.key.items():
        kind = spec.split(":")[0]
        for (x, y) in room.spawns.get(ch, []):
            out[(x, y)] = dict(kind=kind, spec=spec, ch=ch, x=x, y=y)
    return out


def solid_for_beam(room, x, y):
    if x < 0 or y < 0 or x >= room.W or y >= room.H:
        return True
    ch = room.g[y][x]
    # A closed gate stops a beam. That is deliberate and it is why a node
    # always sits on the near side of the curtain it opens: a circuit
    # whose beam has to pass through its own gate can never close.
    return ch == "#" or ch in RM.GATES or ch in "%c"


def trace(room, parts, start, direction, mirrors, panel_slots):
    """-> (set of node cells lit, set of cells burned) for one emitter."""
    occupy = {}
    for (x, y), p in parts.items():
        if p["kind"] == "panel":
            rail = p["spec"].split(":")[1]
            s = panel_slots.get((x, y), 0)
            px = x + (s if rail == "h" else 0)
            py = y + (s if rail == "v" else 0)
            occupy[(px, py)] = ("mirror", mirrors.get((x, y), p["spec"].split(":")[2]))
        elif p["kind"] == "mirror":
            # bolted down: one orientation, never in configs()
            occupy[(x, y)] = ("mirror", p["spec"].split(":")[1])
        elif p["kind"] == "rotor":
            m = p["spec"].split(":")[1] if ":" in p["spec"] else "f"
            occupy[(x, y)] = ("mirror", mirrors.get((x, y), m))
        elif p["kind"] == "node":
            occupy[(x, y)] = ("node", None)
        elif p["kind"] in ENEMY_KINDS:
            occupy[(x, y)] = ("enemy", None)

    lit, burned, seen, path = set(), set(), set(), set()
    x, y, d = start[0], start[1], direction
    for _ in range(BEAM_STEPS):
        dx, dy = DIRV[d]
        x, y = x + dx, y + dy
        if solid_for_beam(room, x, y):
            break
        if (x, y, d) in seen:
            break
        seen.add((x, y, d))
        path.add((x, y))
        cell = occupy.get((x, y))
        if cell:
            what, val = cell
            if what == "node":
                lit.add((x, y))
                break
            if what == "enemy":
                burned.add((x, y))
            elif what == "mirror":
                d = MIRROR[val][d]
    return lit, burned, path


def configs(parts):
    """Every legal (mirrors, panel_slots) pairing, capped so a room with
    four panels and two rotors does not explode. Panels and rotors are
    the only movable parts; an emitter's direction is fixed."""
    movers = []
    for (x, y), p in parts.items():
        if p["kind"] == "rotor":
            movers.append(((x, y), "mirror", ["f", "b"]))
        elif p["kind"] == "panel":
            bits = p["spec"].split(":")
            slots = int(bits[3]) if len(bits) > 3 else 3
            movers.append(((x, y), "slot", list(range(slots + 1))))
    total = 1
    for _, _, opts in movers:
        total *= len(opts)
        if total > 20000:
            movers = movers[:4]
            break

    def rec(i, mirrors, slots):
        if i == len(movers):
            yield dict(mirrors), dict(slots)
            return
        key, what, opts = movers[i]
        for o in opts:
            if what == "mirror":
                mirrors[key] = o
            else:
                slots[key] = o
            yield from rec(i + 1, mirrors, slots)

    yield from rec(0, {}, {})


def main():
    rooms = RM.load_rooms() if hasattr(RM, "load_rooms") else None
    if rooms is None:
        rooms = {}
        for fn in sorted(os.listdir("src/data/rooms")):
            if fn.endswith(".lua"):
                r = RM.parse_room("src/data/rooms/" + fn)
                if r:
                    rooms[r.name] = r

    # The flag set matters enormously here: without sparkjump a shelf four
    # rows up is unreachable and every emitter on one looks broken. Use the
    # flags the run actually holds when it first arrives at each door, which
    # is the same standard checkprogress holds the world to.
    graph = GP.build_graph()
    flags, first_reach, _ = CP.fixpoint(graph)

    bad = 0
    notes = 0

    print("== RULE 1: Lu can stand and hold a two-second channel ==")
    for name, room in sorted(rooms.items()):
        parts = parts_of(room)
        for (x, y), p in parts.items():
            if p["kind"] != "emitter" or "dormant" not in p["spec"]:
                continue
            # emitter body is inset +2,+2 and is 12x12, so its centre is
            # the tile centre
            ecx, ecy = x * T + 8, y * T + 8
            doors = sorted(room.doors)
            if first_reach:
                arrivable = [d for d in doors if (name, d) in first_reach]
                if arrivable:
                    doors = arrivable
            best = None
            for dch in doors:
                F = frozenset(flags) if flags else frozenset()
                if first_reach and (name, dch) in first_reach:
                    F = first_reach[(name, dch)]
                nav = RM.Nav(room, F)
                reach = nav.reach_from_door(dch)
                for (cx, cy) in reach:
                    if not nav.standable(cx, cy):
                        continue
                    # Lu's dome is centred on her body, a little above
                    # the tile she stands in
                    px, py = cx * T + 8, cy * T + 8 - 4
                    d = math.hypot(px - ecx, py - ecy)
                    if best is None or d < best[0]:
                        best = (d, cx, cy, dch)
            if best is None:
                print("  FAIL %-12s dormant emitter at (%d,%d): no reachable "
                      "cell at all" % (name, x, y))
                bad += 1
            elif best[0] > DOME_REACH:
                print("  FAIL %-12s dormant emitter at (%d,%d): nearest cell Lu "
                      "can STAND on is (%d,%d), %.0fpx away -- the dome reaches "
                      "%dpx, so the 2s channel can never be held"
                      % (name, x, y, best[1], best[2], best[0], DOME_REACH))
                bad += 1
            else:
                print("  ok   %-12s emitter (%d,%d): Lu stands at (%d,%d), "
                      "%.0fpx of %d" % (name, x, y, best[1], best[2],
                                        best[0], DOME_REACH))

    print("")
    print("== RULE 2: every emitter has a job ==")
    for name, room in sorted(rooms.items()):
        parts = parts_of(room)
        stations = station_cells(room)
        emitters = [(k, p) for k, p in parts.items() if p["kind"] == "emitter"]
        for (x, y), p in emitters:
            bits = p["spec"].split(":")
            d = bits[1] if len(bits) > 1 else "right"
            best_nodes, best_burn, hit_station = set(), set(), False
            for mirrors, slots in configs(parts):
                lit, burned, path = trace(room, parts, (x, y), d, mirrors, slots)
                if stations and (path & stations):
                    hit_station = True
                if len(lit) > len(best_nodes):
                    best_nodes = lit
                if len(burned) > len(best_burn):
                    best_burn = burned
                if best_nodes or hit_station:
                    break
            if hit_station:
                print("  ok   %-12s emitter (%d,%d) can reach a boss station"
                      % (name, x, y))
            elif best_nodes:
                print("  ok   %-12s emitter (%d,%d) -> node %s"
                      % (name, x, y, sorted(best_nodes)))
            elif best_burn:
                print("  ok   %-12s emitter (%d,%d) burns %d thing(s) on its "
                      "own line" % (name, x, y, len(best_burn)))
            else:
                print("  FAIL %-12s emitter (%d,%d) firing %s reaches no node "
                      "and burns nothing in any legal configuration -- it is "
                      "scenery" % (name, x, y, d))
                bad += 1

    # ------------------------------------------------------------------
    # RULE 3 -- AN ARENA'S RAILS MUST COVER ITS JITTER.
    #
    # The Conductor re-rolls each station's column by up to JITTER tiles
    # every cycle, and the panel beneath it has to be able to follow. A
    # rail one slot short is invisible in the room file and produces a
    # boss that is simply unkillable at some of its own positions --
    # exactly the class of bug that had crys_3's puzzle unsolvable since
    # the day it was written. Every station column is traced for real.
    # ------------------------------------------------------------------
    print("")
    print("== RULE 3: every arena station is reachable at every jitter ==")
    for name, room in sorted(rooms.items()):
        if arena_boss(room) != "prismtyrant":
            continue
        cfg = arena_cfg()
        if not cfg:
            continue
        parts = parts_of(room)
        emitters = [(k, p) for k, p in parts.items() if p["kind"] == "emitter"]
        panels = [(k, p) for k, p in parts.items() if p["kind"] == "panel"]
        if not emitters or not panels:
            continue
        sy = cfg["y"]
        for sx0 in cfg["x"]:
            missed = []
            for col in range(sx0 - cfg["jitter"], sx0 + cfg["jitter"] + 1):
                ok = False
                for (ex, ey), ep in emitters:
                    d = ep["spec"].split(":")[1]
                    for mirrors, slots in configs(parts):
                        _l, _b, path = trace(room, parts, (ex, ey), d,
                                             mirrors, slots)
                        if (col, sy) in path:
                            ok = True
                            break
                    if ok:
                        break
                if not ok:
                    missed.append(col)
            if missed:
                print("  FAIL %-12s station at col %d: no beam can reach "
                      "col(s) %s at row %d -- the boss is unkillable there"
                      % (name, sx0, missed, sy))
                bad += 1
            else:
                print("  ok   %-12s station col %d: all %d jitter columns "
                      "reachable" % (name, sx0, cfg["jitter"] * 2 + 1))

    print("")
    print("%d beam issues (%d notes)" % (bad, notes))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
