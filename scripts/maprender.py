# Render the atlas to a PNG so the layout can be LOOKED at -- the one
# thing no validator can tell you. Draws it the way the map screen does:
# a doored pair that touches gets a notch in the shared wall, a pair that
# does not gets a dashed line, so the picture and the game agree about
# what is a neighbour and what is a shaft.
import sys
sys.path.insert(0, "../scripts")
import maplayout as ML
from PIL import Image, ImageDraw

COL = {"camp": (224, 138, 60), "mosswood": (96, 150, 80), "flooded": (70, 130, 180),
       "furnace": (200, 80, 50), "crystal": (150, 90, 200), "skyroot": (110, 170, 220),
       "core": (80, 210, 210), "scrapyard": (120, 128, 140), "undergrove": (150, 80, 150),
       "coldstore": (180, 220, 235), "cradle": (90, 180, 170)}

off, rooms = ML.load()
links = ML.build_links(rooms)
L = ML.Layout(rooms, links)

C, PAD = 34, 50
x0 = min(L.x); y0 = min(L.y)
x1 = max(L.x[i] + L.w[i] for i in range(len(L.ids)))
y1 = max(L.y[i] + L.h[i] for i in range(len(L.ids)))
W = (x1 - x0) * C + PAD * 2
H = (y1 - y0) * C + PAD * 2
img = Image.new("RGB", (W, H), (12, 12, 16))
d = ImageDraw.Draw(img)


def px(cx, cy):
    return (PAD + (cx - x0) * C, PAD + (cy - y0) * C)


def dash(p1, p2, col):
    import math
    dx, dy = p2[0] - p1[0], p2[1] - p1[1]
    n = max(1, int(math.hypot(dx, dy) / 7))
    for k in range(n):
        if k % 2:
            continue
        a = (p1[0] + dx * k / n, p1[1] + dy * k / n)
        b = (p1[0] + dx * (k + 1) / n, p1[1] + dy * (k + 1) / n)
        d.line([a, b], fill=col, width=2)


for kind, a, b, al, bl, _wg in L.links:
    ax, ay, aw, ah = L.x[a], L.y[a], L.w[a], L.h[a]
    bx, by, bw, bh = L.x[b], L.y[b], L.w[b], L.h[b]
    ov = min(ay + ah, by + bh) - max(ay, by)
    ox = min(ax + aw, bx + bw) - max(ax, bx)
    if ov > 0 and (bx == ax + aw or ax == bx + bw):
        sx = ax + aw if bx == ax + aw else bx + bw
        my = (max(ay, by) + min(ay + ah, by + bh)) / 2
        p = px(sx, my)
        d.rectangle([p[0] - 2, p[1] - C * 0.25, p[0] + 2, p[1] + C * 0.25],
                    fill=(230, 205, 130))
    elif ox > 0 and (by == ay + ah or ay == by + bh):
        sy = ay + ah if by == ay + ah else by + bh
        mx = (max(ax, bx) + min(ax + aw, bx + bw)) / 2
        p = px(mx, sy)
        d.rectangle([p[0] - C * 0.25, p[1] - 2, p[0] + C * 0.25, p[1] + 2],
                    fill=(230, 205, 130))
    else:
        p1 = px(ax + aw / 2, ay + ah / 2)
        p2 = px(bx + bw / 2, by + bh / 2)
        dash(p1, p2, (110, 100, 150) if kind == "P" else (200, 70, 70))

for i, n in enumerate(L.ids):
    z = rooms[n].zone
    p0 = px(L.x[i], L.y[i])
    p1 = px(L.x[i] + L.w[i], L.y[i] + L.h[i])
    c = COL.get(z, (120, 120, 120))
    d.rectangle([p0, (p1[0] - 3, p1[1] - 3)],
                fill=tuple(int(v * 0.3) for v in c), outline=c)
    d.text((p0[0] + 3, p0[1] + 3), n[:11], fill=(215, 215, 220))

bx0, by0, bx1, by1 = L.zone_boxes()
for zi, z in enumerate(L.znames):
    p = px((bx0[zi] + bx1[zi]) / 2, by0[zi])
    d.text((p[0] - 30, p[1] - 16), z.upper(), fill=COL.get(z, (150, 150, 150)))

out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/atlas.png"
img.save(out)
print("wrote %s  %dx%d  (%d rooms, %d links)" % (out, W, H, len(L.ids), len(L.links)))
