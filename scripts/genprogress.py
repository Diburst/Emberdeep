#!/usr/bin/env python3
"""World-progression graph generator.

Computes, for every room, the flag requirements to travel from each door
to every other door and to every flag-granting entity (chests, capsules,
tanks, plates, machines, boss triggers, NPCs), using the shared traversal
model in roommodel.py. Emits src/data/progress_graph.lua for the in-game
Progress menu, and is imported by checkprogress.py for offline
completability validation.

Model assumptions (documented, verified by scenarios):
  - Bosses are winnable when reached (bossflow proves the kill chain).
  - Momentary pressure plates count as grantable when a player can stand
    on them (co-op partner or solo parked bot holds them).
  - Water is traversable without hydroseals (breath allows short swims;
    hydroseals-gated DOORS carry the explicit gate flag).
  - Hot rooms (room.hot) require heatplating for every move within them.
  - Teleporters are ignored (shortcuts only; completability must hold
    without them).
"""
import glob
import itertools
import sys
from collections import OrderedDict

import roommodel as RM

BOSS_REWARDS = {
    "rustwarden": ["hydroseals"],
    "tideengine": ["resonator"],
    "archivist": ["weapon_magnetmortar"],
    "crucible": ["corekey1"],
    "prismtyrant": ["corekey2"],
    "aeriesentinel": ["corekey3"],
    "motherengine": ["ending"],  # two-phase finale chains automatically
    "mycelchoir": ["weapon_pulsebloom"],
    "vessel8": ["cinderram"],
}

# flags granted through NPC dialogue rather than a world entity
NPC_GIVES = {
    # Maro switches the LINK blast on the first time you speak to him.
    # Nothing that needs the blast is reachable before that.
    "elder": [{"gives": ["linkblast", "met_elder"], "req": []}],
    "jun": [{"gives": ["telenet"], "req": ["boss_tideengine"]}],
    "ferro": [
        {"gives": ["ferro_rescued"], "req": []},
        {"gives": ["ferro_stage1"], "req": ["ferro_rescued", "ferrocoil"]},
    ],
    "mote": [
        {"gives": ["mote_done"],
         "req": ["glowmite1", "glowmite2", "glowmite3"]},
    ],
    "lock": [
        {"gives": ["cradle_found"],
         "req": ["arcplate1", "arcplate2", "arcplate3", "arcplate4"]},
    ],
}

# flags derived from other flags on visiting a room (camp_main onEnter)
DERIVED = {
    "coredoor": {"room": "camp_main", "req": ["corekey1", "corekey2", "corekey3"]},
}

SPAWN_DOOR = ("camp_awake", "A")


def target_gives(spec):
    """What flags does touching this entity grant? -> (gives, extra_req)"""
    parts = spec.split(":")
    kind = parts[0]
    if kind == "chest":
        gives = [parts[1]]
        if len(parts) >= 4 and parts[2] == "module":
            gives.append(parts[3])
        elif len(parts) >= 4 and parts[2] == "weapon":
            gives.append("weapon_" + parts[3])
        return gives, []
    if kind in ("capsule", "tank"):
        return [parts[1]], []
    if kind == "plate":
        return [parts[1]], []
    if kind == "machine":
        return [parts[1]], []
    if kind == "linkcore":
        # shattered ONLY by the LINK blast, which Maro grants in camp
        return [parts[1]], ["linkblast"]
    if kind == "boss":
        return ["boss_" + parts[1]] + BOSS_REWARDS.get(parts[1], []), []
    if kind == "thawplate":
        # latching plate under old ice; the LINK blast (always available)
        # or any heavy shot melts it free
        return [parts[1]], []
    if kind == "mitehusk":
        # shattered by any weapon fire; frees a glowmite (sets its flag)
        return [parts[1]], []
    if kind == "npc" and parts[1] in NPC_GIVES:
        stages = NPC_GIVES[parts[1]]
        return list(stages[0]["gives"]), list(stages[0]["req"])
    if kind == "teleporter":
        return ["tp_" + parts[1]], []
    if kind == "node":
        # A Crystal Hollows circuit node. It latches for good the first
        # time enough beams land on it, so it is a plain flag source --
        # but the beams have to be ROUTED there, and the router is a
        # reflector panel that only Vess's charge can shove. The caller
        # adds `bulwark` for any node in a room that has a panel in it;
        # see room_targets. A node fed straight from a fixed emitter
        # (crys_1) needs nothing but a shot to turn its rotor.
        return [parts[1]], []
    return [], []


def room_targets(room):
    """target key -> (cells, gives, extra_req, kind). Doors are 'door:X',
    entities 'ent:<char>' keyed with their granted flags."""
    out = OrderedDict()
    for ch in sorted(room.doors):
        out["door:" + ch] = (room.doors[ch], [], [], "door")
    for ch, spec in sorted(room.key.items()):
        parts = spec.split(":")
        if parts[0] == "npc" and parts[1] in NPC_GIVES:
            # one node per quest stage, so later stages' reqs never gate
            # earlier stages' gives
            for i, st in enumerate(NPC_GIVES[parts[1]]):
                if st["gives"] and ch in room.spawns:
                    k = "ent:" + ch + ("" if i == 0 else "*%d" % (i + 1))
                    out[k] = (room.spawns[ch], list(st["gives"]),
                              list(st["req"]), "npc")
            continue
        gives, extra = target_gives(spec)
        if parts[0] == "node" and any(
                v.split(":")[0] == "panel" for v in room.key.values()):
            # this circuit is routed by a reflector panel, and the only
            # thing in the game that shoves one is a plated charge
            extra = list(extra) + ["bulwark"]
        if gives and ch in room.spawns:
            out["ent:" + ch] = (room.spawns[ch], gives, extra, spec.split(":")[0])
    return out


def relevant_flags(room):
    # Movement flags whose presence can change what a room can reach.
    # driftvanes belongs here for EVERY room, not just ones with a vanes
    # gate: Lu's hover widens GAP_W from 4 to 10 tiles, so a ledge can be
    # hover-only anywhere in the world.
    flags = {"sparkjump", "grapple", "driftvanes"}
    for f in room.gates.values():
        flags.add(f[1:] if f.startswith("!") else f)
    return sorted(flags)


def minimal_reqs(sat_subsets):
    """Reduce satisfying flag subsets to a minimal antichain."""
    sat = sorted(sat_subsets, key=len)
    out = []
    for s in sat:
        if not any(m <= s for m in out):
            out.append(s)
    return out


def analyze_room(room):
    """-> edges: {(from_door, target_key): [minimal req sets]}"""
    rel = relevant_flags(room)
    targets = room_targets(room)
    edges = {}
    for r in range(len(rel) + 1):
        for combo in itertools.combinations(rel, r):
            flags = set(combo)
            nav = RM.Nav(room, flags)
            for dch in sorted(room.doors):
                reach = nav.reach_from_door(dch)
                for tkey, target in targets.items():
                    cells = target[0]
                    if nav.touches(reach, cells, radius=1):
                        edges.setdefault(("door:" + dch, tkey), []).append(
                            frozenset(combo))
    # a door sealed behind a flag needs that flag on every edge that USES it
    for k in list(edges.keys()):
        tkey = k[1]
        if tkey.startswith("door:"):
            need = getattr(room, "door_req", {}).get(tkey[5:])
            if need:
                edges[k] = [frozenset(set(c) | {need}) for c in edges[k]]

    hot_extra = frozenset({"heatplating"}) if room.hot else frozenset()
    cold_extra = frozenset({"cryocoils"}) if getattr(room, "cold", False) else frozenset()
    out = {}
    for k, subsets in edges.items():
        reqs = minimal_reqs([set(s) for s in subsets])
        if hot_extra:
            reqs = [r | hot_extra for r in reqs]
        if cold_extra:
            reqs = [r | cold_extra for r in reqs]
        out[k] = reqs
    return targets, out


def build_graph():
    graph = {}
    for fname in sorted(glob.glob("src/data/rooms/*.lua")):
        room = RM.parse_room(fname)
        if room.name == "test_arena":
            continue
        targets, edges = analyze_room(room)
        graph[room.name] = {"room": room, "targets": targets, "edges": edges}
    return graph


def lua_flagset(s):
    return "{ " + ", ".join('"%s"' % f for f in sorted(s)) + " }"


def emit_lua(graph, path):
    lines = []
    w = lines.append
    w("-- GENERATED by scripts/genprogress.py -- do not hand-edit.")
    w("-- Per-room door->target flag requirements + flag grants, used by")
    w("-- the in-game Progress menu (test mode) and offline validators.")
    w("return {")
    w('  start = { room = "%s", door = "%s" },' % SPAWN_DOOR)
    w("  derived = {")
    for flag, d in DERIVED.items():
        w('    %s = { room = "%s", req = %s },' % (flag, d["room"],
                                                   lua_flagset(d["req"])))
    w("  },")
    w("  rooms = {")
    for name in sorted(graph):
        info = graph[name]
        room = info["room"]
        w('    ["%s"] = {' % name)
        w("      doors = {")
        for dch in sorted(room.doors):
            link = room.links.get(dch)
            if link:
                w('        %s = { "%s", "%s" },' % (dch, link[0], link[1]))
            else:
                w("        %s = {}," % dch)
        w("      },")
        w("      gives = {")
        for tkey, (cells, gives, extra, kind) in info["targets"].items():
            if gives:
                w('        ["%s"] = { flags = %s, req = %s, kind = "%s" },'
                  % (tkey, lua_flagset(gives), lua_flagset(extra), kind))
        w("      },")
        w("      edges = {")
        for (fkey, tkey), reqs in sorted(info["edges"].items()):
            alts = ", ".join(lua_flagset(r) for r in reqs)
            w('        { from = "%s", to = "%s", reqs = { %s } },'
              % (fkey, tkey, alts))
        w("      },")
        w("    },")
    w("  },")
    w("}")
    open(path, "w").write("\n".join(lines) + "\n")


if __name__ == "__main__":
    graph = build_graph()
    out = sys.argv[1] if len(sys.argv) > 1 else "src/data/progress_graph.lua"
    emit_lua(graph, out)
    n_edges = sum(len(g["edges"]) for g in graph.values())
    print(f"progress graph: {len(graph)} rooms, {n_edges} door->target edges -> {out}")
