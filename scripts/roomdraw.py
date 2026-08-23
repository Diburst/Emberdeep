"""A tiny canvas for authoring room grids.

Rooms are written as drawing operations on a fixed-size canvas rather
than as typed rows, because a hand-typed 60-character row is one keystroke
away from a ragged map -- a room that still parses, still loads, and is
nonsense. Here the width cannot drift: the canvas is allocated once and
every operation is clipped to it.

    from roomdraw import Canvas
    c = Canvas(60, 17)          # starts solid
    c.box(2, 2, 57, 15, ".")    # hollow it out
    c.hline(12, 8, 21, "=")     # a deck
    print(c)
"""


class Canvas:
    def __init__(self, w, h, fill="#"):
        self.w, self.h = w, h
        self.g = [[fill] * w for _ in range(h)]

    def at(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.g[y][x]
        return "#"

    def put(self, x, y, ch):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.g[y][x] = ch
        return self

    def hline(self, y, x0, x1, ch):
        for x in range(min(x0, x1), max(x0, x1) + 1):
            self.put(x, y, ch)
        return self

    def vline(self, x, y0, y1, ch):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            self.put(x, y, ch)
        return self

    def box(self, x0, y0, x1, y1, ch):
        """Filled rectangle, inclusive."""
        for y in range(min(y0, y1), max(y0, y1) + 1):
            self.hline(y, x0, x1, ch)
        return self

    def door(self, ch, side, y0, height=2):
        """Place a door on a wall, so its side is derived correctly."""
        for i in range(height):
            if side == "left":
                self.put(0, y0 + i, ch)
                self.put(1, y0 + i, ch)
            elif side == "right":
                self.put(self.w - 1, y0 + i, ch)
                self.put(self.w - 2, y0 + i, ch)
            else:
                raise ValueError("top/bottom doors are placed by hand")
        return self

    def rows(self):
        return ["".join(r) for r in self.g]

    def __str__(self):
        return "\n".join(self.rows())

    # ------------------------------------------------------------------
    # CAVERN SHAPING
    # ------------------------------------------------------------------
    # A hollowed rectangle is still a rectangle. These carve an irregular
    # chamber instead -- which is not only a look: World:drawStrata only
    # touches rock at depth >= 2, so a uniform two-tile border is ALL rim
    # and the strata pass has never had a single tile to draw. Thick,
    # uneven rock is what turns it on.

    def profile(self, rng, n, lo, hi, step=1, smooth=1, max_slope=1,
                run=2):
        """A smoothed random walk of n integers within [lo, hi].

        `run` holds each value for a few columns before it may move and
        `max_slope` caps the step afterwards, because an unconstrained
        walk makes a floor that changes height every single column --
        which does not read as a cave, it reads as damage, and it is not
        walkable. Terrain wants plateaus with steps between them."""
        v = rng.randint(lo, hi)
        out, hold = [], 0
        for _ in range(n):
            if hold <= 0:
                v = max(lo, min(hi, v + rng.randint(-step, step)))
                hold = rng.randint(run, run * 3)
            hold -= 1
            out.append(v)
        for _ in range(smooth):
            out = [int(round((out[max(0, i - 1)] + out[i]
                              + out[min(n - 1, i + 1)]) / 3.0))
                   for i in range(n)]
        for i in range(1, n):
            out[i] = max(out[i - 1] - max_slope,
                         min(out[i - 1] + max_slope, out[i]))
        return out

    def cavern(self, rng, ceil=(2, 4), floor=(13, 15), margin=2, ch=".",
               head=6):
        """Carve a chamber between an uneven ceiling and an uneven floor.

        `head` is the minimum air between them, enforced by raising the
        ceiling rather than by hoping -- a cave that pinches shut is a
        room the traversal model refuses, and finding that out from
        checkrooms is slower than not doing it.

        Returns (ceiling, floor) so callers can hang things off the real
        rock instead of a row number they assumed."""
        ct = self.profile(rng, self.w, ceil[0], ceil[1])
        fl = self.profile(rng, self.w, floor[0], floor[1])
        for x in range(self.w):
            if fl[x] - ct[x] < head:
                ct[x] = max(1, fl[x] - head)
        for x in range(margin, self.w - margin):
            for y in range(ct[x], fl[x]):
                self.put(x, y, ch)
        return ct, fl

    def finger(self, rng, x, y, length, down=True, thick=2):
        """A tapering spur of rock off the ceiling or the floor."""
        for i in range(length):
            w = max(1, int(round(thick * (1 - i / float(max(1, length)))))) 
            yy = y + i if down else y - i
            for dx in range(-(w // 2), w - w // 2):
                self.put(x + dx, yy, "#")
        return self

    def pillar(self, x, y0, y1, w=2):
        self.box(x, y0, x + w - 1, y1, "#")
        return self

    def alcove(self, x, y, w, h):
        """A pocket bitten into the rock -- somewhere to put a thing."""
        self.box(x, y, x + w - 1, y + h - 1, ".")
        return self

    def teeth(self, rng, prof, n, down=True, lo=1, hi=3, thick=2, avoid=(),
              keep=4, other=None):
        """n stalactites (down) or stalagmites (up) hung off a profile.

        `keep` is the air that must survive between the tooth and the
        opposite profile. A stalactite that meets the floor is a wall,
        and a wall nobody meant is how a room stops being crossable."""
        placed = []
        for _ in range(n):
            for _try in range(16):
                x = rng.randint(3, self.w - 4)
                if any(abs(x - a) < 5 for a in placed + list(avoid)):
                    continue
                length = rng.randint(lo, hi)
                if other is not None:
                    gap = abs(other[x] - prof[x])
                    if length > gap - keep:
                        length = gap - keep
                if length < 1:
                    continue
                self.finger(rng, x, prof[x] - 1 if down else prof[x],
                            length, down=down, thick=thick)
                placed.append(x)
                break
        return self

    def landing(self, side, y0, height=2, ledge=6, drop=1):
        """Guarantee a door is arrivable: air in front of it, rock under
        it. Cavern shaping is free to eat either one, and a door you fall
        straight through is a room nobody can cross."""
        if side == "left":
            xs = range(2, 2 + ledge)
        else:
            xs = range(self.w - 2 - ledge, self.w - 2)
        for x in xs:
            for y in range(y0, y0 + height):
                self.put(x, y, ".")
            for y in range(y0 + height, y0 + height + drop):
                self.put(x, y, "#")
        return self

    # ------------------------------------------------------------------
    # FEATURES
    # ------------------------------------------------------------------
    # A random profile gives texture; it does not give character. These
    # are the deliberate forms -- a room composed of three or four of
    # them reads as designed, where the same room built from noise reads
    # as damage. Vocabulary first, dice second.

    def terrace(self, x0, x1, y_top, steps, down=True, run=None):
        """A stepped floor climbing (or falling) across a span. Each step
        rises ONE row, because Vess climbs three and a terrace you cannot
        walk up is scenery."""
        n = max(1, steps)
        run = run or max(2, (x1 - x0 + 1) // n)
        y = y_top
        for i in range(n):
            a = x0 + i * run
            b = min(x1, a + run - 1)
            self.box(a, y, b, self.h - 1, "#")
            y += 1 if down else -1
        return self

    def chasm(self, x0, x1, floor_y, depth):
        """A bite taken out of the floor. Deeper than a step, narrower
        than a room: somewhere to fall, and something to jump."""
        self.box(x0, floor_y, x1, min(self.h - 2, floor_y + depth), ".")
        return self

    def overhang(self, x0, x1, y, thick=2):
        """A shelf of rock jutting from the ceiling: it hides what is
        behind it until you are under it, which is the cheapest reveal
        there is."""
        self.box(x0, y, x1, y + thick - 1, "#")
        return self

    def hall(self, x0, x1, y0, y1, spacing=7, w=2, jitter=None):
        """A colonnade. Gaps between the pillars stay walkable."""
        x = x0
        while x <= x1 - w:
            top = y0 if jitter is None else max(0, y0 + jitter.randint(-1, 2))
            self.box(x, top, x + w - 1, y1, "#")
            x += spacing + w
        return self

    def dome(self, cx, rx, ry, y_base):
        """An arched ceiling: carve a half-ellipse upward."""
        for dx in range(-rx, rx + 1):
            k = 1.0 - (dx / float(rx)) ** 2
            if k <= 0:
                continue
            h = int(round(ry * (k ** 0.5)))
            for dy in range(h):
                self.put(cx + dx, y_base - dy, ".")
        return self

    def stand(self, x, ch=None, below=None):
        """The LOWEST cell in column x you could stand in.

        Scanned from the bottom up, not the top down: from the top the
        first solid thing is the ceiling, and the first version of this
        cheerfully placed the signs and the enemies in row 0, inside the
        rock. Entities are placed against the real ground because
        pillars, teeth and platforms all move it after the floor profile
        was computed."""
        lo = self.h - 1 if below is None else below
        for y in range(lo, 0, -1):
            if self.at(x, y) in "#%c=" and self.at(x, y - 1) == ".":
                if ch is not None:
                    self.put(x, y - 1, ch)
                return y - 1
        return None

    # ---- checks you want before writing, not after ----
    def assert_rect(self):
        w = len(self.g[0])
        for i, r in enumerate(self.g):
            assert len(r) == w, "row %d is %d wide, want %d" % (i, len(r), w)
        return self

    def count(self, ch):
        return sum(r.count(ch) for r in self.g)

    def stand_rows(self):
        """Every cell you could stand on: air with support underneath."""
        out = set()
        for y in range(self.h - 1):
            for x in range(self.w):
                if self.at(x, y) in ".=~" and self.at(x, y + 1) in "#=%c":
                    out.add((x, y))
        return out
