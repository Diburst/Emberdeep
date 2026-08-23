#!/usr/bin/env python3
"""Author backdrop / scenery / foreground / lights for a whole zone.

    PYTHONPATH=../scripts python3 ../scripts/genzoneart.py scrapyard
    PYTHONPATH=../scripts python3 ../scripts/genzoneart.py scrapyard --write

Hand-writing four art tables for 33 rooms is how you get 33 rooms that
do not look like one place. A generator per ZONE, sized per ROOM, is how
the ten authored-by-hand rooms already work in spirit -- this just makes
the spirit explicit and repeatable, the same way genscrap.py and
gen_coldstore.py generate geometry.

The entries it emits are ordinary art-layer data, so every one of them
remains hand-editable afterwards and remains upgradable to a drawn
sprite later by changing `kind` (see ASSET-PLAN.md section 3).

Layer semantics, which is the whole craft:
  backdrop  drawn BEFORE terrain, py 0.15-0.45  -- behind the rock
  scenery   drawn after terrain,  py 0          -- welded to the world
  foreground drawn last, py NEGATIVE            -- overtakes you
  lights    additive, world coordinates
"""

import argparse
import glob
import os
import random
import re
import sys

DIR = "src/data/rooms"
T = 16

# ------------------------------------------------------------------
# per-zone style
# ------------------------------------------------------------------
# Each style returns the four lists for one room, given its pixel size
# and a seeded RNG. Keep every entry inside 0..W and 0..H or it is just
# invisible work.
STYLES = {}


def scrapyard(W, H, r):
    """The Bulwark Line: a yard of crushed hulls under crane gantries.
    Deep silhouettes of stacked wrecks, a haze that eats the distance,
    near gantries that sweep past, and the orange bite of welding."""
    back, scen, fore, lit = [], [], [], []

    # DEPTH HAZE first, so everything after sits in front of it
    back.append(dict(kind="band", x=0, y=0, w=W, h=H, col="umber",
                     a=0.30, a2=0.06, py=0.05))

    # stacked hulls: broad flat-topped silhouettes at two depths
    x = -20
    while x < W:
        w = r.randint(46, 96)
        h = r.randint(40, 110)
        back.append(dict(kind="rect", x=x, y=H - h - r.randint(0, 24),
                         w=w, h=h, col="black", a=0.42, py=0.22))
        x += w + r.randint(8, 30)
    x = -30
    while x < W:
        w = r.randint(60, 130)
        h = r.randint(70, 150)
        back.append(dict(kind="rect", x=x, y=H - h, w=w, h=h,
                         col="black", a=0.26, py=0.12))
        x += w + r.randint(20, 60)

    # crane gantries across the back, two courses
    for i, (yy, a, py) in enumerate(((int(H * 0.18), 0.42, 0.30),
                                     (int(H * 0.40), 0.34, 0.24))):
        back.append(dict(kind="girder", x=-16, y=yy, w=W + 32, h=14,
                         col="black", a=a, py=py, step=r.choice((26, 30, 34))))
    # hanging hooks off the upper gantry
    for _ in range(max(2, W // 220)):
        hx = r.randint(20, max(21, W - 20))
        back.append(dict(kind="hang", x=hx, y=int(H * 0.18) + 14,
                         w=2, h=r.randint(26, 60), col="black", a=0.5,
                         py=0.30, lw=2, sway=4, rate=0.4, bob=True))

    # SCENERY: rust weeping down the walls, and warning lamps
    for _ in range(max(3, W // 90)):
        sx = r.randint(4, max(5, W - 8))
        sy = r.randint(int(H * 0.15), int(H * 0.7))
        scen.append(dict(kind="rect", x=sx, y=sy, w=r.randint(2, 5),
                         h=r.randint(14, 44), col="rust", a=0.30))
    lamps = []
    for _ in range(max(2, W // 200)):
        lx = r.randint(24, max(25, W - 24))
        ly = r.randint(int(H * 0.20), int(H * 0.55))
        scen.append(dict(kind="rect", x=lx, y=ly, w=7, h=9, col="rust", a=0.9))
        scen.append(dict(kind="rect", x=lx + 2, y=ly + 2, w=3, h=5,
                         col="ember", a=1))
        lamps.append((lx + 3, ly + 4))

    # FOREGROUND: the near gantry, and cable runs that overtake you
    fore.append(dict(kind="girder", x=-24, y=int(H * 0.06), w=W + 48, h=16,
                     col="black", a=0.90, py=-0.12, step=34))
    for _ in range(max(2, W // 150)):
        hx = r.randint(10, max(11, W - 10))
        fore.append(dict(kind="hang", x=hx, y=int(H * 0.06) + 16, w=2,
                         h=r.randint(30, 70), col="black", a=0.85, py=-0.12,
                         lw=2, sway=5, rate=0.5, bob=True))
    # the near lip, left and right, so the yard reads as a cut
    fore.append(dict(kind="band", x=0, y=0, w=26, h=H, col="black",
                     a=0.55, a2=0.55, py=-0.06))
    fore.append(dict(kind="band", x=W - 26, y=0, w=26, h=H, col="black",
                     a=0.55, a2=0.55, py=-0.06))

    # LIGHTS: the lamps, plus a welding arc that flickers hard
    for (lx, ly) in lamps:
        lit.append(dict(x=lx, y=ly, r=r.randint(40, 62),
                        col=(1.00, 0.62, 0.28), flicker=r.uniform(5.0, 8.5)))
    wx = r.randint(30, max(31, W - 30))
    wy = r.randint(int(H * 0.45), int(H * 0.8))
    lit.append(dict(x=wx, y=wy, r=r.randint(50, 74),
                    col=(1.00, 0.86, 0.55), flicker=r.uniform(11.0, 16.0)))
    return back, scen, fore, lit


STYLES["scrapyard"] = scrapyard


def coldstore(W, H, r):
    """The Coldstore: a warehouse the ice took back.

    The brief is icicles, dripping water and blue ice, so the layers are
    built around those and not around the racking -- the racking is what
    the ice is growing ON. Depth still goes PALE here, the inverse of the
    Scrapyard, because cold haze scatters light instead of eating it."""
    back, scen, fore, lit = [], [], [], []

    back.append(dict(kind="band", x=0, y=0, w=W, h=H, col="ice",
                     a=0.06, a2=0.30, py=0.05))

    # aisles of racking, receding, already half-glazed
    for depth, (a, py, step) in enumerate(((0.32, 0.26, 32), (0.18, 0.14, 44))):
        x = -10 + depth * 19
        while x < W:
            h = int(H * (0.60 if depth == 0 else 0.74))
            back.append(dict(kind="column", x=x, y=H - h, w=9, h=h,
                             col="navy", a=a, py=py, step=step, acc="ice"))
            x += step + r.randint(12, 30)
    for yy in (int(H * 0.32), int(H * 0.52), int(H * 0.72)):
        back.append(dict(kind="rail", x=-12, y=yy, w=W + 24, h=4,
                         col="navy", a=0.26, py=0.26))
    # cold daylight down the aisles
    for _ in range(max(2, W // 260)):
        sx = r.randint(20, max(21, W - 60))
        back.append(dict(kind="shaft", x=sx, y=0, w=r.randint(40, 66),
                         h=int(H * 0.82), col="ice", a=0.15, py=0.16,
                         skew=r.randint(-16, 16), ph=r.uniform(0, 6.2)))
    # ICICLE RANKS in the back, so the whole depth reads frozen and not
    # just the near plane
    for _ in range(max(6, W // 60)):
        ix = r.randint(4, max(5, W - 6))
        iy = r.randint(int(H * 0.06), int(H * 0.34))
        back.append(dict(kind="hang", x=ix, y=iy, w=2,
                         h=r.randint(10, 30), col="ice", a=0.34, py=0.20,
                         lw=r.choice((2, 3)), sway=0, rate=0.1))

    # ---- scenery: welded to the world ----
    # ICICLES, in clusters, hanging where a ceiling would be
    for _ in range(max(7, W // 45)):
        cx = r.randint(5, max(6, W - 10))
        cy = r.randint(int(H * 0.08), int(H * 0.62))
        for k in range(r.randint(2, 5)):
            scen.append(dict(kind="hang", x=cx + k * r.randint(3, 6), y=cy,
                             w=2, h=r.randint(7, 26), col="ice",
                             a=r.uniform(0.55, 0.85), lw=r.choice((2, 3)),
                             sway=0, rate=0.1))
    # DRIPS: a thin line with a bob on it, on its own phase, slow
    for _ in range(max(4, W // 90)):
        dx = r.randint(6, max(7, W - 8))
        dy = r.randint(int(H * 0.12), int(H * 0.58))
        scen.append(dict(kind="hang", x=dx, y=dy, w=1,
                         h=r.randint(14, 40), col="water",
                         a=r.uniform(0.30, 0.55), lw=1, sway=1,
                         rate=r.uniform(0.15, 0.4), bob=True))
    # BLUE-ICE SHEETS glazing the walls: wide, low, unmistakably blue
    for _ in range(max(5, W // 55)):
        sx = r.randint(3, max(4, W - 20))
        sy = r.randint(int(H * 0.10), int(H * 0.80))
        scen.append(dict(kind="band", x=sx, y=sy, w=r.randint(24, 70),
                         h=r.randint(8, 22), col="ice",
                         a=r.uniform(0.22, 0.40), a2=0.04))
    # frost bloom, small and bright, on top of the sheets
    for _ in range(max(5, W // 60)):
        scen.append(dict(kind="rect", x=r.randint(4, max(5, W - 10)),
                         y=r.randint(int(H * 0.10), int(H * 0.82)),
                         w=r.randint(5, 14), h=r.randint(2, 3),
                         col="cream", a=r.uniform(0.10, 0.22)))

    # ---- foreground ----
    fore.append(dict(kind="column", x=int(W * 0.17), y=0, w=13, h=H,
                     col="black", a=0.70, py=-0.14, step=26, acc="navy"))
    fore.append(dict(kind="column", x=int(W * 0.75), y=0, w=13, h=H,
                     col="black", a=0.70, py=-0.14, step=26, acc="navy"))
    # near icicles, big, sweeping past the camera
    for _ in range(max(2, W // 190)):
        fx = r.randint(6, max(7, W - 10))
        fore.append(dict(kind="hang", x=fx, y=0, w=3,
                         h=r.randint(26, 54), col="ice", a=0.80,
                         py=-0.16, lw=4, sway=0, rate=0.1))
    fore.append(dict(kind="band", x=0, y=0, w=24, h=H, col="ice",
                     a=0.22, a2=0.22, py=-0.05))
    fore.append(dict(kind="band", x=W - 24, y=0, w=24, h=H, col="ice",
                     a=0.22, a2=0.22, py=-0.05))

    # ---- lights: cold, wide, steady ----
    n = max(2, W // 240)
    for i in range(n):
        lit.append(dict(x=int(W * (i + 0.5) / n), y=int(H * 0.16),
                        r=r.randint(74, 100), col=(0.60, 0.80, 1.00),
                        flicker=r.uniform(0.5, 1.4)))
    return back, scen, fore, lit


STYLES["coldstore"] = coldstore


def crystal(W, H, r):
    """Crystal Hollows: a lattice growing through the rock. Shards at
    every depth catching the light, refraction haze, and prism beams that
    are the zone's own mechanic made visible in the backdrop."""
    back, scen, fore, lit = [], [], [], []
    back.append(dict(kind="band", x=0, y=0, w=W, h=H, col="plum",
                     a=0.34, a2=0.08, py=0.05))
    # shard forests at two depths -- tall thin columns, leaning
    for depth, (a, py, wid) in enumerate(((0.40, 0.24, 11), (0.24, 0.13, 17))):
        x = -14 + depth * 21
        while x < W:
            h = r.randint(int(H * 0.35), int(H * 0.85))
            back.append(dict(kind="column", x=x, y=H - h, w=wid, h=h,
                             col="black", a=a, py=py,
                             step=r.randint(22, 40), acc="orchid"))
            x += wid + r.randint(14, 44)
    # refracted light, thrown at angles a cave could not make
    for _ in range(max(3, W // 200)):
        back.append(dict(kind="shaft", x=r.randint(10, max(11, W - 60)), y=0,
                         w=r.randint(30, 58), h=int(H * 0.9), col="orchid",
                         a=0.16, py=0.20, skew=r.randint(-34, 34),
                         ph=r.uniform(0, 6.2)))
    # ---- scenery ----
    for _ in range(max(8, W // 40)):
        sx, sy = r.randint(4, max(5, W - 8)), r.randint(int(H * .08), int(H * .84))
        n = r.randint(2, 4)
        for k in range(n):
            scen.append(dict(kind="rect", x=sx + k * r.randint(2, 5), y=sy,
                             w=r.randint(2, 4), h=r.randint(6, 20),
                             col=r.choice(("orchid", "violet", "plum")),
                             a=r.uniform(0.35, 0.75)))
    for _ in range(max(4, W // 100)):
        scen.append(dict(kind="rect", x=r.randint(4, max(5, W - 8)),
                         y=r.randint(int(H * .1), int(H * .8)),
                         w=r.randint(3, 6), h=r.randint(3, 6),
                         col="cream", a=r.uniform(0.30, 0.6)))
    # ---- foreground ----
    for _ in range(max(2, W // 200)):
        fx = r.randint(4, max(5, W - 16))
        fore.append(dict(kind="column", x=fx, y=0, w=r.randint(10, 18), h=H,
                         col="black", a=0.80, py=-0.15, step=30, acc="violet"))
    fore.append(dict(kind="band", x=0, y=0, w=24, h=H, col="plum",
                     a=0.45, a2=0.45, py=-0.06))
    fore.append(dict(kind="band", x=W - 24, y=0, w=24, h=H, col="plum",
                     a=0.45, a2=0.45, py=-0.06))
    n = max(2, W // 210)
    for i in range(n):
        lit.append(dict(x=int(W * (i + 0.5) / n),
                        y=r.randint(int(H * .2), int(H * .7)),
                        r=r.randint(52, 84), col=(0.78, 0.48, 1.00),
                        flicker=r.uniform(2.0, 4.5)))
    return back, scen, fore, lit


STYLES["crystal"] = crystal


def skyroot(W, H, r):
    """Skyroot Spire: you are ABOVE the world. Open sky, cloud decks
    lagging far behind, a canopy of roots overhead, and nothing under the
    gaps -- the danger here is air."""
    back, scen, fore, lit = [], [], [], []
    back.append(dict(kind="band", x=0, y=0, w=W, h=H, col="navy",
                     a=0.05, a2=0.34, py=0.03))
    # cloud decks: very slow, very wide, very faint
    for py, a, yy in ((0.06, 0.20, 0.22), (0.11, 0.15, 0.44), (0.16, 0.11, 0.62)):
        x = -40
        while x < W + 40:
            wid = r.randint(90, 220)
            back.append(dict(kind="band", x=x, y=int(H * yy),
                             w=wid, h=r.randint(14, 30), col="sky",
                             a=a, a2=0.0, py=py))
            x += wid + r.randint(30, 120)
    # the trunk and its boughs, receding
    for depth, (a, py, wid) in enumerate(((0.42, 0.26, 26), (0.24, 0.15, 40))):
        x = -20 + depth * 33
        while x < W:
            back.append(dict(kind="column", x=x, y=0, w=wid, h=H,
                             col="black", a=a, py=py,
                             step=r.randint(30, 52), acc="pine"))
            x += wid + r.randint(60, 150)
    for yy in (int(H * 0.30), int(H * 0.58)):
        back.append(dict(kind="girder", x=-16, y=yy, w=W + 32, h=12,
                         col="black", a=0.30, py=0.22, step=r.randint(30, 44)))
    # ---- scenery: hanging roots and leaf drift ----
    for _ in range(max(6, W // 55)):
        scen.append(dict(kind="hang", x=r.randint(4, max(5, W - 6)),
                         y=r.randint(0, int(H * 0.5)), w=2,
                         h=r.randint(16, 54), col="pine",
                         a=r.uniform(0.35, 0.65), lw=2,
                         sway=r.randint(3, 8), rate=r.uniform(0.25, 0.6),
                         bob=True))
    for _ in range(max(5, W // 70)):
        scen.append(dict(kind="rect", x=r.randint(4, max(5, W - 8)),
                         y=r.randint(int(H * .1), int(H * .85)),
                         w=r.randint(3, 8), h=r.randint(2, 4),
                         col="leaf", a=r.uniform(0.18, 0.4)))
    # ---- foreground: near boughs sweeping past, and wind ----
    fore.append(dict(kind="girder", x=-24, y=int(H * 0.04), w=W + 48, h=15,
                     col="black", a=0.88, py=-0.13, step=40))
    for _ in range(max(3, W // 120)):
        fore.append(dict(kind="hang", x=r.randint(6, max(7, W - 8)),
                         y=int(H * 0.04) + 15, w=2, h=r.randint(28, 74),
                         col="black", a=0.80, py=-0.13, lw=2,
                         sway=r.randint(5, 11), rate=r.uniform(0.4, 0.8),
                         bob=True))
    fore.append(dict(kind="band", x=0, y=0, w=20, h=H, col="black",
                     a=0.42, a2=0.42, py=-0.05))
    fore.append(dict(kind="band", x=W - 20, y=0, w=20, h=H, col="black",
                     a=0.42, a2=0.42, py=-0.05))
    n = max(1, W // 300)
    for i in range(n):
        lit.append(dict(x=int(W * (i + 0.5) / n), y=int(H * 0.12),
                        r=r.randint(80, 120), col=(0.72, 0.86, 1.00),
                        flicker=r.uniform(0.4, 1.1)))
    return back, scen, fore, lit


STYLES["skyroot"] = skyroot


def mosswood(W, H, r):
    """Mosswood: the first zone, and the only warm green one. Sunlight
    through a canopy, hanging growth, a soft floor of ferns."""
    back, scen, fore, lit = [], [], [], []
    back.append(dict(kind="band", x=0, y=0, w=W, h=H, col="pine",
                     a=0.30, a2=0.07, py=0.05))
    x = -16
    while x < W:
        wid = r.randint(20, 40)
        back.append(dict(kind="column", x=x, y=0, w=wid, h=H, col="black",
                         a=r.uniform(0.24, 0.40), py=r.uniform(0.14, 0.28),
                         step=r.randint(26, 46), acc="moss"))
        x += wid + r.randint(24, 70)
    for _ in range(max(3, W // 190)):
        back.append(dict(kind="shaft", x=r.randint(10, max(11, W - 60)), y=0,
                         w=r.randint(40, 74), h=int(H * 0.85), col="lime",
                         a=0.15, py=0.18, skew=r.randint(-22, 22),
                         ph=r.uniform(0, 6.2)))
    for _ in range(max(7, W // 45)):
        scen.append(dict(kind="hang", x=r.randint(4, max(5, W - 6)),
                         y=r.randint(0, int(H * 0.45)), w=2,
                         h=r.randint(10, 40), col="moss",
                         a=r.uniform(0.4, 0.75), lw=2,
                         sway=r.randint(2, 6), rate=r.uniform(0.2, 0.5),
                         bob=True))
    for _ in range(max(6, W // 55)):
        scen.append(dict(kind="rect", x=r.randint(4, max(5, W - 10)),
                         y=r.randint(int(H * .12), int(H * .86)),
                         w=r.randint(6, 18), h=r.randint(2, 5),
                         col=r.choice(("moss", "fern", "lime")),
                         a=r.uniform(0.2, 0.45)))
    fore.append(dict(kind="girder", x=-24, y=int(H * 0.05), w=W + 48, h=13,
                     col="black", a=0.82, py=-0.12, step=44))
    for _ in range(max(3, W // 130)):
        fore.append(dict(kind="hang", x=r.randint(6, max(7, W - 8)),
                         y=int(H * 0.05) + 13, w=2, h=r.randint(24, 64),
                         col="black", a=0.78, py=-0.12, lw=3,
                         sway=r.randint(4, 9), rate=r.uniform(0.3, 0.7),
                         bob=True))
    fore.append(dict(kind="band", x=0, y=0, w=22, h=H, col="black",
                     a=0.40, a2=0.40, py=-0.05))
    fore.append(dict(kind="band", x=W - 22, y=0, w=22, h=H, col="black",
                     a=0.40, a2=0.40, py=-0.05))
    n = max(1, W // 280)
    for i in range(n):
        lit.append(dict(x=int(W * (i + 0.5) / n), y=int(H * 0.16),
                        r=r.randint(66, 96), col=(0.80, 1.00, 0.66),
                        flicker=r.uniform(1.0, 2.4)))
    return back, scen, fore, lit


STYLES["mosswood"] = mosswood


def flooded(W, H, r):
    """The Flooded Works: machinery drowned. Silt haze, sunk gantries,
    columns of rising bubbles, and a green-blue light from nowhere."""
    back, scen, fore, lit = [], [], [], []
    back.append(dict(kind="band", x=0, y=0, w=W, h=H, col="deepsea",
                     a=0.10, a2=0.40, py=0.04))
    for i, (yy, a, py) in enumerate(((0.20, 0.36, 0.28), (0.44, 0.28, 0.20),
                                     (0.68, 0.20, 0.13))):
        back.append(dict(kind="girder", x=-16, y=int(H * yy), w=W + 32, h=13,
                         col="black", a=a, py=py, step=r.randint(26, 40)))
    x = -12
    while x < W:
        wid = r.randint(12, 26)
        back.append(dict(kind="column", x=x, y=int(H * 0.2), w=wid,
                         h=int(H * 0.8), col="navy", a=0.26,
                         py=0.17, step=r.randint(24, 40), acc="teal"))
        x += wid + r.randint(40, 100)
    for _ in range(max(6, W // 60)):
        bx = r.randint(5, max(6, W - 6))
        scen.append(dict(kind="hang", x=bx, y=r.randint(int(H * .3), int(H * .9)),
                         w=1, h=r.randint(20, 60), col="sky",
                         a=r.uniform(0.2, 0.42), lw=1,
                         sway=r.randint(2, 5), rate=r.uniform(0.5, 1.1),
                         bob=True))
    for _ in range(max(5, W // 70)):
        scen.append(dict(kind="rect", x=r.randint(4, max(5, W - 10)),
                         y=r.randint(int(H * .15), int(H * .9)),
                         w=r.randint(5, 16), h=r.randint(2, 4),
                         col=r.choice(("teal", "rust")), a=r.uniform(0.2, 0.45)))
    fore.append(dict(kind="girder", x=-24, y=int(H * 0.03), w=W + 48, h=16,
                     col="black", a=0.86, py=-0.12, step=34))
    fore.append(dict(kind="band", x=0, y=0, w=26, h=H, col="navy",
                     a=0.45, a2=0.45, py=-0.06))
    fore.append(dict(kind="band", x=W - 26, y=0, w=26, h=H, col="navy",
                     a=0.45, a2=0.45, py=-0.06))
    n = max(1, W // 260)
    for i in range(n):
        lit.append(dict(x=int(W * (i + 0.5) / n), y=int(H * 0.14),
                        r=r.randint(70, 104), col=(0.50, 0.90, 0.92),
                        flicker=r.uniform(0.8, 2.0)))
    return back, scen, fore, lit


STYLES["flooded"] = flooded


def furnace(W, H, r):
    """Furnace Depths: heat you can see. Magma glow from below, soot
    haze above, and the black bones of a foundry between."""
    back, scen, fore, lit = [], [], [], []
    back.append(dict(kind="band", x=0, y=0, w=W, h=H, col="maroon",
                     a=0.10, a2=0.42, py=0.05))
    x = -18
    while x < W:
        wid = r.randint(30, 60)
        h = r.randint(int(H * .3), int(H * .75))
        back.append(dict(kind="rect", x=x, y=H - h, w=wid, h=h,
                         col="black", a=0.40, py=0.22))
        x += wid + r.randint(18, 56)
    for yy in (int(H * 0.16), int(H * 0.40)):
        back.append(dict(kind="girder", x=-16, y=yy, w=W + 32, h=14,
                         col="black", a=0.42, py=0.28, step=r.randint(26, 36)))
    for _ in range(max(3, W // 170)):
        back.append(dict(kind="shaft", x=r.randint(10, max(11, W - 50)),
                         y=int(H * 0.35), w=r.randint(28, 54),
                         h=int(H * 0.6), col="magma", a=0.20, py=0.14,
                         skew=r.randint(-14, 14), ph=r.uniform(0, 6.2)))
    for _ in range(max(5, W // 70)):
        scen.append(dict(kind="rect", x=r.randint(4, max(5, W - 8)),
                         y=r.randint(int(H * .2), int(H * .9)),
                         w=r.randint(3, 7), h=r.randint(10, 34),
                         col="rust", a=r.uniform(0.25, 0.5)))
    lamps = []
    for _ in range(max(2, W // 180)):
        lx = r.randint(20, max(21, W - 20)); ly = r.randint(int(H * .2), int(H * .6))
        scen.append(dict(kind="rect", x=lx, y=ly, w=8, h=10, col="rust", a=0.9))
        scen.append(dict(kind="rect", x=lx + 2, y=ly + 2, w=4, h=6,
                         col="magma", a=1))
        lamps.append((lx + 4, ly + 5))
    fore.append(dict(kind="girder", x=-24, y=int(H * 0.05), w=W + 48, h=16,
                     col="black", a=0.90, py=-0.13, step=32))
    for _ in range(max(2, W // 150)):
        fore.append(dict(kind="hang", x=r.randint(8, max(9, W - 10)),
                         y=int(H * 0.05) + 16, w=2, h=r.randint(26, 60),
                         col="black", a=0.85, py=-0.13, lw=2,
                         sway=4, rate=0.45, bob=True))
    fore.append(dict(kind="band", x=0, y=0, w=24, h=H, col="black",
                     a=0.50, a2=0.50, py=-0.06))
    fore.append(dict(kind="band", x=W - 24, y=0, w=24, h=H, col="black",
                     a=0.50, a2=0.50, py=-0.06))
    for (lx, ly) in lamps:
        lit.append(dict(x=lx, y=ly, r=r.randint(46, 70),
                        col=(1.00, 0.52, 0.20), flicker=r.uniform(4.0, 7.0)))
    lit.append(dict(x=r.randint(30, max(31, W - 30)), y=int(H * 0.88),
                    r=r.randint(80, 118), col=(1.00, 0.40, 0.14),
                    flicker=r.uniform(2.0, 3.6)))
    return back, scen, fore, lit


STYLES["furnace"] = furnace


def undergrove(W, H, r):
    """The Undergrove: a fungal dark. Almost nothing to see, and what
    there is glows. The zone is DARK, so the art must not compete with
    the light buffer -- it sets the shape and the spores do the rest."""
    back, scen, fore, lit = [], [], [], []
    back.append(dict(kind="band", x=0, y=0, w=W, h=H, col="black",
                     a=0.50, a2=0.16, py=0.05))
    x = -14
    while x < W:
        wid = r.randint(18, 38)
        back.append(dict(kind="column", x=x, y=0, w=wid, h=H, col="black",
                         a=0.44, py=r.uniform(0.16, 0.30),
                         step=r.randint(24, 44), acc="violet"))
        x += wid + r.randint(34, 90)
    for _ in range(max(8, W // 40)):
        scen.append(dict(kind="rect", x=r.randint(4, max(5, W - 8)),
                         y=r.randint(int(H * .1), int(H * .9)),
                         w=r.randint(2, 5), h=r.randint(2, 5),
                         col=r.choice(("violet", "orchid", "lime")),
                         a=r.uniform(0.4, 0.85)))
    for _ in range(max(4, W // 90)):
        scen.append(dict(kind="hang", x=r.randint(4, max(5, W - 6)),
                         y=r.randint(0, int(H * .5)), w=2,
                         h=r.randint(12, 40), col="plum",
                         a=r.uniform(0.3, 0.6), lw=2,
                         sway=r.randint(2, 5), rate=r.uniform(0.2, 0.5),
                         bob=True))
    fore.append(dict(kind="band", x=0, y=0, w=30, h=H, col="black",
                     a=0.66, a2=0.66, py=-0.05))
    fore.append(dict(kind="band", x=W - 30, y=0, w=30, h=H, col="black",
                     a=0.66, a2=0.66, py=-0.05))
    for _ in range(max(2, W // 200)):
        fore.append(dict(kind="column", x=r.randint(6, max(7, W - 14)), y=0,
                         w=r.randint(10, 16), h=H, col="black", a=0.80,
                         py=-0.14, step=28, acc="plum"))
    for _ in range(max(2, W // 200)):
        lit.append(dict(x=r.randint(20, max(21, W - 20)),
                        y=r.randint(int(H * .25), int(H * .8)),
                        r=r.randint(38, 60), col=(0.70, 0.45, 1.00),
                        flicker=r.uniform(2.5, 5.0)))
    return back, scen, fore, lit


STYLES["undergrove"] = undergrove


def core(W, H, r):
    """The Core: a machine that never stopped. Circuit runs, cyan glow,
    hard geometry -- the one zone with no rock in its language."""
    back, scen, fore, lit = [], [], [], []
    back.append(dict(kind="band", x=0, y=0, w=W, h=H, col="black",
                     a=0.42, a2=0.12, py=0.05))
    for yy in [int(H * f) for f in (0.14, 0.32, 0.50, 0.68, 0.86)]:
        back.append(dict(kind="rail", x=-12, y=yy, w=W + 24, h=3,
                         col="cyan", a=0.16, py=0.24))
    x = -10
    while x < W:
        wid = r.randint(14, 30)
        back.append(dict(kind="column", x=x, y=0, w=wid, h=H, col="black",
                         a=0.40, py=r.uniform(0.16, 0.30),
                         step=r.randint(18, 30), acc="cyan"))
        x += wid + r.randint(26, 72)
    for _ in range(max(6, W // 60)):
        scen.append(dict(kind="rect", x=r.randint(4, max(5, W - 10)),
                         y=r.randint(int(H * .1), int(H * .9)),
                         w=r.randint(8, 26), h=2, col="cyan",
                         a=r.uniform(0.25, 0.55)))
    for _ in range(max(4, W // 90)):
        scen.append(dict(kind="rect", x=r.randint(4, max(5, W - 8)),
                         y=r.randint(int(H * .1), int(H * .9)),
                         w=3, h=3, col="teal", a=r.uniform(0.5, 0.9)))
    fore.append(dict(kind="girder", x=-24, y=int(H * 0.04), w=W + 48, h=14,
                     col="black", a=0.88, py=-0.14, step=26))
    fore.append(dict(kind="band", x=0, y=0, w=24, h=H, col="black",
                     a=0.52, a2=0.52, py=-0.06))
    fore.append(dict(kind="band", x=W - 24, y=0, w=24, h=H, col="black",
                     a=0.52, a2=0.52, py=-0.06))
    n = max(2, W // 230)
    for i in range(n):
        lit.append(dict(x=int(W * (i + 0.5) / n),
                        y=r.randint(int(H * .2), int(H * .7)),
                        r=r.randint(54, 82), col=(0.36, 0.94, 0.90),
                        flicker=r.uniform(6.0, 11.0)))
    return back, scen, fore, lit


STYLES["core"] = core
STYLES["cradle"] = undergrove


def camp(W, H, r):
    """Ember Camp: the one place that is not trying to kill you. Warm
    where every other zone is cold, DOMESTIC where the Furnace is
    industrial -- timber, canvas, strung lamps and a hearth glow from
    below. Sparse on purpose: the camp should feel like somewhere you can
    put something down."""
    back, scen, fore, lit = [], [], [], []
    back.append(dict(kind="band", x=0, y=0, w=W, h=H, col="umber",
                     a=0.34, a2=0.10, py=0.06))
    x = -12
    while x < W:
        wid = r.randint(10, 18)
        back.append(dict(kind="column", x=x, y=int(H * 0.18), w=wid,
                         h=int(H * 0.82), col="brown", a=0.34,
                         py=0.22, step=r.randint(30, 50), acc="ember"))
        x += wid + r.randint(50, 130)
    back.append(dict(kind="rail", x=-12, y=int(H * 0.22), w=W + 24, h=4,
                     col="brown", a=0.34, py=0.24))
    # strung lamps along the rail, and the light they throw
    lamps = []
    n = max(2, W // 150)
    for i in range(n):
        lx = int(W * (i + 0.6) / (n + 0.2))
        ly = int(H * 0.22) + r.randint(6, 16)
        scen.append(dict(kind="hang", x=lx, y=int(H * 0.22), w=1,
                         h=ly - int(H * 0.22), col="brown", a=0.7, lw=1,
                         sway=2, rate=0.3, bob=True))
        scen.append(dict(kind="rect", x=lx - 2, y=ly, w=5, h=6,
                         col="ember", a=0.95))
        lamps.append((lx, ly + 3))
    for _ in range(max(3, W // 120)):
        scen.append(dict(kind="rect", x=r.randint(4, max(5, W - 12)),
                         y=r.randint(int(H * .3), int(H * .88)),
                         w=r.randint(8, 22), h=r.randint(3, 6),
                         col="brown", a=r.uniform(0.3, 0.55)))
    fore.append(dict(kind="band", x=0, y=0, w=18, h=H, col="black",
                     a=0.34, a2=0.34, py=-0.05))
    fore.append(dict(kind="band", x=W - 18, y=0, w=18, h=H, col="black",
                     a=0.34, a2=0.34, py=-0.05))
    for (lx, ly) in lamps:
        lit.append(dict(x=lx, y=ly, r=r.randint(56, 84),
                        col=(1.00, 0.74, 0.42), flicker=r.uniform(2.5, 5.0)))
    lit.append(dict(x=int(W * 0.5), y=int(H * 0.86), r=r.randint(80, 110),
                    col=(1.00, 0.60, 0.28), flicker=r.uniform(3.0, 5.5)))
    return back, scen, fore, lit


STYLES["camp"] = camp


# ------------------------------------------------------------------
# emit
# ------------------------------------------------------------------
def num(v):
    if isinstance(v, float):
        s = "%.2f" % v
        return s.rstrip("0").rstrip(".") or "0"
    return str(v)


def entry(d):
    parts = []
    for k in ("kind", "x", "y", "w", "h", "col", "a", "a2", "py", "px",
              "step", "lw", "sway", "rate", "bob", "skew", "ph", "acc",
              "name", "frame", "r", "flicker"):
        if k not in d:
            continue
        v = d[k]
        if k == "col" and isinstance(v, tuple):
            parts.append("col = { %s }" % ", ".join("%.2f" % c for c in v))
        elif isinstance(v, str):
            parts.append('%s = "%s"' % (k, v))
        elif isinstance(v, bool):
            parts.append("%s = %s" % (k, "true" if v else "false"))
        else:
            parts.append("%s = %s" % (k, num(v)))
    return "    { " + ", ".join(parts) + " },"


def block(name, items, note):
    if not items:
        return ""
    out = ["  -- %s" % note, "  %s = {" % name]
    out += [entry(d) for d in items]
    out.append("  },")
    return "\n".join(out) + "\n"


FIELDS = ("backdrop", "scenery", "foreground", "lights")

# ROOMS AUTHORED BY HAND, WHICH THIS MUST NOT TOUCH.
#
# strip_existing() removes art blocks and writes new ones, which is
# exactly right for a room the generator owns and catastrophic for one a
# person composed line by line. These ten predate the generator and their
# layers are tuned to their specific geometry -- deep_stair_1's girders
# are on the half-beat of its stairwell, and no seeded RNG is going to
# rediscover that. --force overrides, deliberately awkwardly.
HANDMADE = {
    "deep_stair_1", "deep_stair_2",
    "furn_1", "furn_golem", "furn_boss",
    "sky_1", "sky_boss",
    "ug_1", "ug_5", "ug_boss",
}


def strip_existing(src):
    """Remove any art blocks already present, brace-matched."""
    for f in FIELDS:
        m = re.search(r"\n(?:  --[^\n]*\n)*  %s = \{" % f, src)
        if not m:
            continue
        i = src.index("{", m.start())
        depth, j, q = 0, i, None
        while j < len(src):
            ch = src[j]
            if q:
                if ch == "\\":
                    j += 1
                elif ch == q:
                    q = None
            elif ch in "\"'":
                q = ch
            elif ch == "-" and src[j:j + 2] == "--":
                j = src.index("\n", j) - 1
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        end = src.index("\n", j) + 1
        src = src[:m.start() + 1] + src[end:]
    return src


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("zone")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--force", action="store_true",
                    help="also regenerate the hand-authored rooms (destroys "
                         "art nobody can get back)")
    ap.add_argument("--seed", type=int, default=7)
    a = ap.parse_args()

    if a.zone not in STYLES:
        sys.exit("FAIL no style for zone '%s' (have: %s)"
                 % (a.zone, ", ".join(sorted(STYLES))))

    n = 0
    for path in sorted(glob.glob(os.path.join(DIR, "*.lua"))):
        src = open(path).read()
        z = re.search(r'zone = "(\w+)"', src)
        if not z or z.group(1) != a.zone:
            continue
        name = os.path.basename(path)[:-4]
        if name in HANDMADE and not a.force:
            print("  KEEP %-14s hand-authored; --force to overwrite" % name)
            continue
        m = re.search(r"map = \[\[\n(.*?)\]\]", src, re.S)
        rows = [r for r in m.group(1).split("\n") if r]
        W, H = len(rows[0]) * T, len(rows) * T

        r = random.Random(a.seed * 1009 + sum(ord(c) for c in name) * 31)
        back, scen, fore, lit = STYLES[a.zone](W, H, r)

        out = strip_existing(src)
        art = (block("backdrop", back, "BEHIND the rock: stacked wrecks, gantries, haze")
               + block("scenery", scen, "welded to the world: rust runs and lamps")
               + block("foreground", fore, "NEARER than the world -- it overtakes you")
               + block("lights", lit, "additive; the lamps and one welding arc"))
        anchor = re.search(r"\n  mapPos = ", out)
        if not anchor:
            print("  SKIP %s has no mapPos to anchor to" % name)
            continue
        out = out[:anchor.start() + 1] + art + out[anchor.start() + 1:]

        print("  %-14s %4dx%-4d  %2d backdrop  %2d scenery  %2d foreground  %d lights"
              % (name, W, H, len(back), len(scen), len(fore), len(lit)))
        if a.write:
            open(path, "w").write(out)
        n += 1
    print("  %d room(s)%s" % (n, "" if a.write else "  (dry run -- pass --write)"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
