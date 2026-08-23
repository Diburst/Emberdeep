#!/usr/bin/env python3
"""One page showing every room shot, grouped by zone.

    EMBERDEEP_SHOTS_ALL=1 EMBERDEEP_RS=1 EMBERDEEP_SHOTS=sweep love .
    python3 ../scripts/contactsheet.py sweep
    open ../_shots/sweep/index.html

WHY.  An art sweep across 74 rooms cannot be reviewed by launching the
game 74 times, and the person doing the reviewing is not the person who
wrote the rooms. This lays them all out at once, labelled, grouped by
zone, and marked with whether the room has authored art layers yet -- so
"which ones still look bare" is a glance instead of an audit.

It writes plain HTML next to the PNGs and references them relatively, so
it opens from the filesystem with no server and no copying.
"""

import argparse
import glob
import os
import re
import sys

ROOMS = "src/data/rooms"
SHOTDIR = os.environ.get("EMBERDEEP_SHOTDIR", "../_shots")

ART = re.compile(r"^\s*(backdrop|scenery|foreground|lights)\s*=", re.M)
ZONE = re.compile(r'zone\s*=\s*"(\w+)"')
DARK = re.compile(r"^\s*dark\s*=", re.M)


def room_facts(rooms_dir):
    facts = {}
    for f in glob.glob(os.path.join(rooms_dir, "*.lua")):
        name = os.path.basename(f)[:-4]
        src = open(f).read()
        z = ZONE.search(src)
        layers = sorted({m.group(1) for m in ART.finditer(src)})
        facts[name] = {
            "zone": z.group(1) if z else "?",
            "layers": layers,
            "dark": bool(DARK.search(src)),
        }
    return facts


HEAD = """<meta charset="utf-8"><title>%(tag)s &mdash; room contact sheet</title>
<style>
:root{--bg:#141118;--fg:#e8e4ef;--dim:#8a849b;--line:#2c2738;--warn:#ffb347}
body{margin:0;padding:24px;background:var(--bg);color:var(--fg);
 font:13px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace}
h1{font-size:16px;margin:0 0 4px}
.sub{color:var(--dim);margin-bottom:24px}
h2{font-size:13px;letter-spacing:.14em;text-transform:uppercase;color:var(--dim);
 border-bottom:1px solid var(--line);padding-bottom:6px;margin:28px 0 12px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:14px}
figure{margin:0}
img{width:100%%;display:block;border:1px solid var(--line);background:#000;
 image-rendering:pixelated}
figcaption{display:flex;justify-content:space-between;gap:8px;padding-top:5px}
.name{color:var(--fg)}
.tags{color:var(--dim);font-size:11px}
.bare{color:var(--warn)}
.missing{border:1px dashed var(--line);aspect-ratio:16/9;display:flex;
 align-items:center;justify-content:center;color:var(--dim);font-size:11px}
</style>
<h1>%(tag)s</h1>
<div class="sub">%(n)d shots &middot; %(art)d of %(total)d rooms have authored art
 &middot; <span class="bare">amber = no art layers yet</span></div>
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("tag")
    ap.add_argument("--rooms", default=ROOMS)
    a = ap.parse_args()

    d = os.path.join(SHOTDIR, a.tag)
    if not os.path.isdir(d):
        sys.exit("no such shot set: %s" % d)

    shots = {os.path.basename(f)[:-4]: os.path.basename(f)
             for f in sorted(glob.glob(os.path.join(d, "*.png")))}
    if not shots:
        sys.exit("no PNGs in %s" % d)

    facts = room_facts(a.rooms)
    # A shot with no room file is a stale PNG from an earlier tag; say so
    # rather than rendering it as though it were current.
    for name in shots:
        facts.setdefault(name, {"zone": "UNKNOWN", "layers": [], "dark": False})

    byzone = {}
    for name in sorted(facts):
        byzone.setdefault(facts[name]["zone"], []).append(name)

    total = len(facts)
    withart = sum(1 for f in facts.values() if f["layers"])
    parts = [HEAD % {"tag": a.tag, "n": len(shots), "art": withart, "total": total}]

    for zone in sorted(byzone):
        names = byzone[zone]
        bare = sum(1 for n in names if not facts[n]["layers"])
        parts.append('<h2>%s &mdash; %d rooms, %d bare</h2><div class="grid">'
                     % (zone, len(names), bare))
        for n in names:
            f = facts[n]
            tags = []
            if f["dark"]:
                tags.append("dark")
            tags += f["layers"] or []
            cls = "" if f["layers"] else ' class="bare"'
            if n in shots:
                img = '<img src="%s" loading="lazy" alt="%s">' % (shots[n], n)
            else:
                img = '<div class="missing">no shot</div>'
            parts.append(
                '<figure>%s<figcaption><span class="name"%s>%s</span>'
                '<span class="tags">%s</span></figcaption></figure>'
                % (img, cls, n, " ".join(tags) or "&mdash;"))
        parts.append("</div>")

    out = os.path.join(d, "index.html")
    open(out, "w").write("\n".join(parts))
    missing = [n for n in facts if n not in shots]
    print("wrote %s" % out)
    print("  %d rooms, %d with art, %d bare" % (total, withart, total - withart))
    if missing:
        print("  %d room(s) had no shot: %s" % (len(missing), ", ".join(sorted(missing)[:8])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
