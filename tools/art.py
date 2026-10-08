"""Generate dramatic cartoon UI icons for the egg game.

Style: chunky dark outline, 3-stop gradient, cel shadow + rim light, glossy highlight,
sunburst / glow behind premium items, sparkles and a soft drop shadow.

Usage: python3 tools/art.py  ->  writes 512px PNGs to art/icons/ (+ art/icons_sheet.png preview)
"""
import math
import pathlib
import random

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "art" / "icons"
FONT = ROOT / "art" / "fonts" / "LuckiestGuy-Regular.ttf"
OUTPUT = 512
U = 4  # canvas pixels per design unit; icons are drawn on a 256-unit grid
S = 256 * U
INK = (22, 14, 34)


# ---------------------------------------------------------------- masks
def blank():
    return Image.new("L", (S, S), 0)


def draw_mask(fn):
    m = blank()
    fn(ImageDraw.Draw(m))
    return m


def sc(*v):
    return [x * U for x in v]


def ell(x0, y0, x1, y1):
    return draw_mask(lambda d: d.ellipse(sc(x0, y0, x1, y1), fill=255))


def rr(x0, y0, x1, y1, r):
    return draw_mask(lambda d: d.rounded_rectangle(sc(x0, y0, x1, y1), r * U, fill=255))


def poly(pts):
    return draw_mask(lambda d: d.polygon([(x * U, y * U) for x, y in pts], fill=255))


def star_pts(cx, cy, ro, ri, n=5, rot=-90):
    pts = []
    for k in range(n * 2):
        r = ro if k % 2 == 0 else ri
        a = math.radians(rot + k * 180 / n)
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def star(cx, cy, ro, ri, n=5, rot=-90):
    return poly(star_pts(cx, cy, ro, ri, n, rot))


def union(*ms):
    out = ms[0]
    for m in ms[1:]:
        out = ImageChops.lighter(out, m)
    return out


def minus(a, b):
    return ImageChops.subtract(a, b)


def inter(a, b):
    return ImageChops.multiply(a, b)


def rot(m, deg, cx=128, cy=128):
    return m.rotate(deg, center=(cx * U, cy * U), resample=Image.BICUBIC)


def shift(m, dx, dy):
    """Translate without wrapping around the canvas edges."""
    out = Image.new(m.mode, m.size, 0)
    out.paste(m, (int(dx * U), int(dy * U)))
    return out


def grow(m, r):
    return m.filter(ImageFilter.GaussianBlur(r * U * 0.55)).point(lambda v: 255 if v > 8 else 0)


def shrink(m, r):
    return m.filter(ImageFilter.GaussianBlur(r * U * 0.55)).point(lambda v: 255 if v > 247 else 0)


def soft(m, r):
    return m.filter(ImageFilter.GaussianBlur(r * U))


def text_mask(txt, cx, cy, size, angle=0):
    font = ImageFont.truetype(str(FONT), int(size * U))
    m = blank()
    d = ImageDraw.Draw(m)
    x0, y0, x1, y1 = d.textbbox((0, 0), txt, font=font)
    d.text((cx * U - (x0 + x1) / 2, cy * U - (y0 + y1) / 2), txt, font=font, fill=255)
    return rot(m, angle, cx, cy) if angle else m


# ---------------------------------------------------------------- paint
def solid(color, alpha=255):
    return Image.new("RGBA", (S, S), tuple(color[:3]) + (alpha,))


def vgrad(mask, stops):
    """Vertical gradient across the mask's own bounding box (so every shape gets full contrast)."""
    box = mask.getbbox() or (0, 0, S, S)
    y0, y1 = box[1], max(box[3], box[1] + 1)
    t = np.clip((np.arange(S) - y0) / (y1 - y0), 0, 1)
    stops = [np.array(c[:3], float) for c in stops]
    seg = len(stops) - 1
    idx = np.minimum((t * seg).astype(int), seg - 1)
    local = t * seg - idx
    rows = np.empty((S, 3))
    for i in range(seg):
        sel = idx == i
        rows[sel] = stops[i] + (stops[i + 1] - stops[i]) * local[sel, None]
    arr = np.empty((S, S, 4), np.uint8)
    arr[..., :3] = rows[:, None, :].astype(np.uint8)
    arr[..., 3] = 255
    return Image.fromarray(arr, "RGBA")


def darker(c, k):
    return tuple(int(v * k) for v in c[:3])


def lighter(c, k):
    return tuple(int(v + (255 - v) * k) for v in c[:3])


def paint(img, mask, color, alpha=1.0):
    if alpha < 1:
        mask = mask.point(lambda v: int(v * alpha))
    img.paste(solid(color), (0, 0), mask)


def shape(img, mask, base, outline=9, gloss=True, shade=True, stops=None):
    """Outlined, gradient-filled, cel-shaded, glossy shape."""
    if outline:
        paint(img, grow(mask, outline), INK)
    stops = stops or (lighter(base, 0.35), base, darker(base, 0.62))
    img.paste(vgrad(mask, stops), (0, 0), mask)
    if shade:
        # cel shadow hugging the bottom-right edges
        sh = inter(mask, ImageChops.invert(shift(mask, -7, -10)))
        paint(img, inter(soft(sh, 1.2), mask), darker(base, 0.45), 0.55)
        # rim light along the top-left edges
        rim = inter(mask, ImageChops.invert(shift(mask, 4, 5)))
        paint(img, inter(soft(rim, 0.8), mask), lighter(base, 0.7), 0.65)
    if gloss:
        box = mask.getbbox()
        if box:
            x0, y0, x1, y1 = (v / U for v in box)
            w, h = x1 - x0, y1 - y0
            blob = ell(x0 + w * 0.14, y0 + h * 0.08, x0 + w * 0.56, y0 + h * 0.34)
            blob = inter(blob, shrink(mask, 5))
            paint(img, soft(blob, 0.6), (255, 255, 255), 0.55)
            dot = ell(x0 + w * 0.62, y0 + h * 0.1, x0 + w * 0.62 + 9, y0 + h * 0.1 + 9)
            paint(img, inter(dot, shrink(mask, 5)), (255, 255, 255), 0.8)


def sparkle(img, cx, cy, r, color=(255, 255, 255)):
    m = poly(star_pts(cx, cy, r, r * 0.22, 4, -90))
    paint(img, soft(m, r * 0.12), color, 0.9)
    paint(img, m, color)
    paint(img, ell(cx - r * 0.18, cy - r * 0.18, cx + r * 0.18, cy + r * 0.18), (255, 255, 255))


def sparkles(img, spots):
    for x, y, r in spots:
        glow = ell(x - r * 0.9, y - r * 0.9, x + r * 0.9, y + r * 0.9)
        paint(img, soft(glow, r * 0.35), (255, 255, 230), 0.55)
        sparkle(img, x, y, r)


class Icon:
    def __init__(self, glow=None, burst=None, burst_n=14, glow_r=112):
        self.bg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        self.fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        self.top = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        if glow:
            paint(self.bg, soft(ell(128 - glow_r, 128 - glow_r, 128 + glow_r, 128 + glow_r), 22), glow, 0.85)
        if burst:
            rays = blank()
            d = ImageDraw.Draw(rays)
            for k in range(burst_n):
                a0 = math.radians(k * 360 / burst_n)
                a1 = math.radians(k * 360 / burst_n + 360 / burst_n * 0.45)
                d.polygon([(128 * U, 128 * U),
                           (128 * U + math.cos(a0) * 200 * U, 128 * U + math.sin(a0) * 200 * U),
                           (128 * U + math.cos(a1) * 200 * U, 128 * U + math.sin(a1) * 200 * U)], fill=255)
            fade = soft(ell(10, 10, 246, 246), 26)
            paint(self.bg, inter(soft(rays, 1), fade), burst, 0.75)

    def image(self):
        """Full-resolution composite: glow/burst, drop shadow, shapes, sparkles."""
        out = self.bg.copy()
        a = self.fg.getchannel("A")
        shadow = soft(shift(a, 0, 7), 3).point(lambda v: int(v * 0.5))
        out.paste(solid((0, 0, 0)), (0, 0), shadow)
        out.alpha_composite(self.fg)
        out.alpha_composite(self.top)
        return out

    def save(self, name):
        OUT.mkdir(parents=True, exist_ok=True)
        self.image().resize((OUTPUT, OUTPUT), Image.LANCZOS).save(OUT / f"{name}.png")


GOLD = (255, 196, 40)
GREEN = (70, 210, 90)
CASH = (90, 205, 110)


def coin(img, cx, cy, r, label="$", base=GOLD):
    shape(img, ell(cx - r, cy - r, cx + r, cy + r), base, outline=max(5, r * 0.22))
    inner = ell(cx - r * 0.72, cy - r * 0.72, cx + r * 0.72, cy + r * 0.72)
    paint(img, minus(inner, shrink(inner, max(2, r * 0.1))), darker(base, 0.7), 0.8)
    if label:
        shape(img, text_mask(label, cx, cy + r * 0.06, r * 1.15), lighter(base, 0.25), outline=max(3, r * 0.12),
              gloss=False, shade=False, stops=(lighter(base, 0.6), darker(base, 0.85)))


# ---------------------------------------------------------------- icons
def cash():
    ic = Icon(glow=(120, 255, 140))
    for i, (dx, dy, a) in enumerate(((8, 30, -16), (0, 12, -6), (-6, -8, 6))):
        bill = rot(rr(34 + dx, 78 + dy, 222 + dx, 168 + dy, 14), a)
        shape(ic.fg, bill, CASH, gloss=i == 2)
        inner = rot(rr(50 + dx, 92 + dy, 206 + dx, 154 + dy, 8), a)
        paint(ic.fg, minus(inner, shrink(inner, 3)), (40, 130, 60), 0.9)
    coin(ic.fg, 128, 112, 34)
    coin(ic.fg, 196, 186, 30)
    sparkles(ic.top, [(52, 54, 18), (214, 70, 13), (60, 200, 11)])
    ic.save("cash")


def bag():
    ic = Icon(glow=(255, 210, 90))
    body = union(ell(34, 82, 222, 244), poly([(92, 98), (164, 98), (186, 44), (70, 44)]))
    shape(ic.fg, body, (200, 150, 80))
    shape(ic.fg, rr(78, 84, 178, 106, 10), (230, 60, 70), outline=7)
    shape(ic.fg, text_mask("$", 128, 168, 92), (110, 230, 120), outline=8, stops=((170, 255, 170), (60, 180, 80)))
    coin(ic.fg, 52, 214, 24)
    coin(ic.fg, 206, 220, 22)
    coin(ic.fg, 184, 236, 16, label="")
    sparkles(ic.top, [(212, 66, 18), (44, 70, 12), (128, 30, 10)])
    ic.save("bag")


def vault():
    ic = Icon(glow=(255, 200, 70), burst=(255, 230, 120))
    shape(ic.fg, rr(28, 34, 228, 222, 28), (150, 165, 195))
    for y in (70, 186):
        shape(ic.fg, rr(14, y - 14, 34, y + 14, 6), (110, 120, 145), outline=6, gloss=False)
    shape(ic.fg, ell(62, 62, 194, 194), (215, 225, 240), outline=8)
    for a in range(0, 360, 45):
        x, y = 128 + math.cos(math.radians(a)) * 48, 128 + math.sin(math.radians(a)) * 48
        shape(ic.fg, ell(x - 9, y - 9, x + 9, y + 9), GOLD, outline=5, gloss=False, shade=False)
    shape(ic.fg, ell(100, 100, 156, 156), GOLD, outline=7)
    shape(ic.fg, text_mask("$", 128, 130, 48), (255, 240, 170), outline=5, gloss=False, shade=False,
          stops=((255, 255, 220), (230, 160, 30)))
    for x, y, a in ((44, 214, -10), (88, 226, 4), (196, 222, 12)):
        shape(ic.fg, rot(poly([(x - 30, y + 12), (x + 30, y + 12), (x + 20, y - 12), (x - 20, y - 12)]), a, x, y), GOLD,
              outline=6)
    coin(ic.fg, 150, 228, 20, label="")
    sparkles(ic.top, [(218, 40, 20), (36, 46, 13), (232, 166, 11)])
    ic.save("vault")


def shop():
    ic = Icon(glow=(255, 180, 70))
    shape(ic.fg, rr(40, 104, 216, 232, 14), (120, 190, 255))
    shape(ic.fg, rr(64, 132, 120, 232, 8), (90, 70, 60), outline=7, gloss=False)
    shape(ic.fg, rr(136, 132, 196, 182, 8), (200, 240, 255), outline=7)
    # striped awning with scalloped edge
    awning = union(rr(22, 44, 234, 104, 12), *[ell(22 + k * 35.3, 84, 22 + (k + 1) * 35.3, 122) for k in range(6)])
    shape(ic.fg, awning, (240, 60, 70), gloss=False)
    for k in range(1, 6, 2):
        stripe = inter(awning, rr(22 + k * 35.3, 30, 22 + (k + 1) * 35.3, 130, 0))
        img_stripe = Image.new("RGBA", (S, S))
        img_stripe.paste(vgrad(stripe, ((255, 255, 255), (225, 225, 235))), (0, 0), stripe)
        ic.fg.alpha_composite(img_stripe)
    gl = inter(ell(40, 46, 140, 66), awning)
    paint(ic.fg, soft(gl, 0.6), (255, 255, 255), 0.5)
    shape(ic.fg, rr(70, 14, 186, 50, 14), GOLD, outline=7)
    shape(ic.fg, text_mask("SHOP", 128, 33, 30), (255, 255, 255), outline=4, gloss=False, shade=False,
          stops=((255, 255, 255), (255, 230, 160)))
    coin(ic.fg, 196, 210, 24)
    sparkles(ic.top, [(30, 30, 14), (232, 140, 12)])
    ic.save("shop")


def rebirth():
    ic = Icon(glow=(200, 110, 255), burst=(230, 170, 255))
    ring = minus(ell(26, 26, 230, 230), ell(74, 74, 182, 182))
    cut1 = poly([(128, 128), (250, 60), (250, 128)])
    cut2 = poly([(128, 128), (6, 196), (6, 128)])
    ring = minus(minus(ring, cut1), cut2)
    head1 = poly([(176, 14), (252, 92), (156, 110)])
    head2 = poly([(80, 242), (4, 164), (100, 146)])
    shape(ic.fg, union(ring, head1, head2), (175, 90, 255))
    shape(ic.fg, star(128, 130, 44, 20), GOLD, outline=7)
    sparkles(ic.top, [(222, 214, 16), (34, 40, 14), (128, 60, 9)])
    ic.save("rebirth")


def index():
    ic = Icon(glow=(110, 180, 255))
    shape(ic.fg, rr(40, 26, 222, 232, 18), (70, 140, 255))
    shape(ic.fg, rr(196, 40, 230, 222, 10), (250, 245, 230), outline=7, gloss=False)
    shape(ic.fg, rr(40, 26, 76, 232, 14), (45, 100, 220), gloss=False)
    shape(ic.fg, rr(96, 54, 202, 204, 16), (255, 230, 150), outline=7, gloss=False)
    shape(ic.fg, ell(118, 70, 180, 160), (255, 90, 80), outline=7)
    for x, y, r in ((136, 104, 8), (162, 126, 7), (140, 142, 6)):
        paint(ic.fg, ell(x - r, y - r, x + r, y + r), (255, 200, 90))
    shape(ic.fg, rr(110, 172, 188, 190, 6), (255, 160, 60), outline=5, gloss=False, shade=False)
    sparkles(ic.top, [(222, 34, 16), (30, 214, 12)])
    ic.save("index")


def daily():
    ic = Icon(glow=(255, 110, 140))
    shape(ic.fg, rr(28, 46, 228, 232, 26), (250, 250, 255), stops=((255, 255, 255), (240, 242, 250), (200, 205, 225)))
    shape(ic.fg, rr(28, 46, 228, 102, 26), (255, 70, 100), outline=0)
    paint(ic.fg, minus(grow(rr(28, 46, 228, 232, 26), 9), rr(28, 46, 228, 232, 26)), INK)
    paint(ic.fg, rr(28, 98, 228, 106, 0), INK)
    for x in (82, 174):
        shape(ic.fg, rr(x - 11, 22, x + 11, 72, 11), (190, 200, 220), outline=6, gloss=False)
    shape(ic.fg, star(128, 168, 56, 24), GOLD, outline=8)
    shape(ic.fg, text_mask("FREE", 128, 74, 34), (255, 255, 255), outline=5, gloss=False, shade=False,
          stops=((255, 255, 255), (255, 220, 230)))
    sparkles(ic.top, [(228, 34, 16), (38, 200, 12), (206, 214, 10)])
    ic.save("daily")


def gift():
    ic = Icon(glow=(255, 120, 200), burst=(255, 230, 140), burst_n=12)
    shape(ic.fg, rr(40, 116, 216, 236, 14), (255, 80, 160))
    shape(ic.fg, rr(110, 116, 146, 236, 4), GOLD, outline=0, gloss=False)
    paint(ic.fg, minus(grow(rr(40, 116, 216, 236, 14), 9), rr(40, 116, 216, 236, 14)), INK)
    lid = rot(rr(26, 82, 230, 126, 14), -7)
    shape(ic.fg, lid, (255, 110, 180))
    shape(ic.fg, inter(rot(rr(108, 70, 148, 140, 2), -7), lid), GOLD, outline=0, gloss=False)
    bow = rot(union(ell(70, 20, 130, 84), ell(126, 20, 186, 84)), -7)
    shape(ic.fg, bow, GOLD, outline=8)
    shape(ic.fg, rot(ell(112, 46, 144, 78), -7), (255, 170, 30), outline=6, gloss=False)
    sparkles(ic.top, [(222, 52, 20), (30, 72, 14), (226, 206, 11), (40, 222, 9)])
    ic.save("gift")


def luck():
    ic = Icon(glow=(120, 255, 120), burst=(200, 255, 170))
    leaves = []
    for a in (45, 135, 225, 315):
        cx, cy = 128 + math.cos(math.radians(a)) * 46, 118 + math.sin(math.radians(a)) * 46
        heart = union(ell(cx - 34, cy - 34, cx + 34, cy + 34))
        leaves.append(heart)
    stem = poly([(122, 150), (138, 150), (178, 244), (158, 248)])
    shape(ic.fg, union(*leaves, stem), (70, 215, 80))
    for a in (45, 135, 225, 315):
        x1, y1 = 128 + math.cos(math.radians(a)) * 66, 118 + math.sin(math.radians(a)) * 66
        line = draw_mask(lambda d, x1=x1, y1=y1: d.line(sc(128, 118, x1, y1), fill=255, width=5 * U))
        paint(ic.fg, line, (40, 150, 60), 0.7)
    shape(ic.fg, star(128, 118, 26, 12), GOLD, outline=6)
    sparkles(ic.top, [(226, 40, 20), (30, 36, 14), (36, 214, 12), (226, 196, 10)])
    ic.save("luck")


def lock():
    ic = Icon(glow=(120, 200, 255))
    shackle = minus(rr(62, 14, 194, 160, 66), rr(96, 48, 160, 160, 32))
    shape(ic.fg, shackle, (205, 215, 235))
    body = rr(34, 100, 222, 238, 30)
    shape(ic.fg, body, GOLD)
    for y in (132, 206):
        paint(ic.fg, inter(rr(34, y - 3, 222, y + 3, 0), shrink(body, 2)), darker(GOLD, 0.7), 0.6)
    hole = union(ell(110, 140, 146, 176), poly([(116, 164), (140, 164), (146, 210), (110, 210)]))
    paint(ic.fg, grow(hole, 3), INK)
    paint(ic.fg, hole, (70, 40, 20))
    sparkles(ic.top, [(222, 52, 18), (34, 74, 12)])
    ic.save("lock")


def vip():
    ic = Icon(glow=(255, 210, 80), burst=(255, 240, 150))
    crown = poly([(24, 200), (18, 70), (78, 128), (128, 36), (178, 128), (238, 70), (232, 200)])
    shape(ic.fg, crown, GOLD)
    for x, y in ((18, 70), (128, 36), (238, 70)):
        shape(ic.fg, ell(x - 15, y - 15, x + 15, y + 15), GOLD, outline=6)
    shape(ic.fg, rr(20, 192, 236, 232, 12), (240, 170, 30))
    for x, y, c in ((128, 152, (255, 60, 100)), (70, 164, (70, 160, 255)), (186, 164, (60, 220, 120))):
        shape(ic.fg, rot(rr(x - 17, y - 17, x + 17, y + 17, 5), 45, x, y), c, outline=6)
    for x in (60, 128, 196):
        shape(ic.fg, ell(x - 9, 203, x + 9, 221), (255, 255, 255), outline=4, gloss=False, shade=False)
    sparkles(ic.top, [(222, 26, 18), (36, 24, 14)])
    ic.save("vip")


def speed():
    ic = Icon(glow=(110, 200, 255), burst=(170, 230, 255), burst_n=12)
    for k, y in enumerate((70, 128, 186)):
        shape(ic.fg, rr(6 + k * 8, y - 9, 92 - k * 6, y + 9, 9), (255, 255, 255), outline=6, gloss=False, shade=False,
              stops=((255, 255, 255), (200, 230, 255)))
    bolt = poly([(166, 8), (76, 136), (128, 136), (98, 250), (206, 104), (150, 104), (196, 8)])
    shape(ic.fg, bolt, (255, 210, 40), outline=9, stops=((255, 250, 180), (255, 205, 40), (240, 130, 20)))
    sparkles(ic.top, [(226, 40, 18), (52, 228, 12), (230, 196, 10)])
    ic.save("speed")


def starter():
    ic = Icon(glow=(255, 170, 80), burst=(255, 230, 150))
    shape(ic.fg, rr(86, 18, 170, 72, 26), (190, 100, 50), outline=8, gloss=False)
    bills = [rot(rr(70 + k * 30, 40, 120 + k * 30, 110, 6), -20 + k * 20, 95 + k * 30, 75) for k in range(3)]
    for b in bills:
        shape(ic.fg, b, CASH, outline=6, gloss=False)
    shape(ic.fg, rr(36, 64, 220, 238, 40), (255, 130, 50))
    shape(ic.fg, rr(62, 140, 194, 214, 20), (255, 170, 80), outline=7)
    shape(ic.fg, rr(70, 132, 186, 150, 9), (220, 90, 40), outline=6, gloss=False)
    coin(ic.fg, 128, 178, 22)
    shape(ic.fg, star(214, 66, 30, 14), GOLD, outline=6)
    sparkles(ic.top, [(36, 44, 18), (232, 196, 12)])
    ic.save("starter")


def plus():
    ic = Icon()
    shape(ic.fg, union(rr(94, 22, 162, 234, 24), rr(22, 94, 234, 162, 24)), (90, 230, 100))
    sparkles(ic.top, [(214, 44, 22)])
    ic.save("plus")


def egg():
    ic = Icon(glow=(255, 120, 60))
    body = ell(50, 18, 206, 240)
    shape(ic.fg, body, (230, 50, 60), stops=((255, 120, 110), (220, 40, 60), (120, 10, 40)))
    rng = random.Random(4)
    for _ in range(9):
        x, y = rng.uniform(70, 186), rng.uniform(50, 220)
        r = rng.uniform(9, 16)
        scale = inter(poly([(x, y - r), (x + r, y), (x, y + r * 1.3), (x - r, y)]), shrink(body, 6))
        paint(ic.fg, scale, (255, 170, 60), 0.85)
    crack = draw_mask(lambda d: d.line(sc(70, 120, 98, 104, 118, 130, 146, 108, 168, 132, 192, 118), fill=255,
                                       width=6 * U, joint="curve"))
    crack = inter(crack, shrink(body, 2))
    paint(ic.fg, soft(crack, 3), (255, 230, 120), 0.9)
    paint(ic.fg, crack, (255, 250, 200))
    sparkles(ic.top, [(222, 46, 18), (34, 78, 12), (212, 206, 10)])
    ic.save("egg")


def slots():
    ic = Icon(glow=(140, 200, 255))
    nest = union(ell(18, 150, 238, 240), rr(18, 160, 238, 196, 20))
    for x, c in ((72, (120, 200, 255)), (184, (190, 120, 255)), (128, (255, 220, 120))):
        shape(ic.fg, ell(x - 40, 66 if x == 128 else 90, x + 40, 180), c)
    shape(ic.fg, nest, (180, 120, 60), gloss=False)
    for k in range(5):
        paint(ic.fg, inter(draw_mask(lambda d, k=k: d.arc(sc(10 + k * 30, 160, 110 + k * 30, 260), 200, 340,
                                                           fill=255, width=4 * U)), nest), (120, 70, 30))
    badge = ell(156, 8, 248, 100)
    shape(ic.fg, badge, (70, 220, 90), outline=8)
    shape(ic.fg, text_mask("+4", 203, 58, 50), (255, 255, 255), outline=5, gloss=False, shade=False,
          stops=((255, 255, 255), (220, 255, 220)))
    sparkles(ic.top, [(34, 40, 16)])
    ic.save("slots")


def music(muted=False):
    ic = Icon(glow=(255, 120, 120) if muted else (130, 200, 255))
    beam = poly([(92, 54), (214, 24), (214, 60), (92, 90)])
    stems = union(rr(84, 60, 104, 196, 6), rr(200, 30, 220, 166, 6))
    heads = union(rot(ell(36, 168, 104, 220), -20, 70, 194), rot(ell(152, 138, 220, 190), -20, 186, 164))
    shape(ic.fg, union(beam, stems, heads), (90, 150, 255) if not muted else (150, 150, 170))
    if muted:
        bar = rot(rr(10, 112, 246, 144, 16), -40)
        shape(ic.fg, bar, (255, 60, 70), outline=8, gloss=False)
    else:
        sparkles(ic.top, [(226, 206, 16), (40, 50, 12)])
    ic.save("mute" if muted else "music")


ALL = [cash, bag, vault, shop, rebirth, index, daily, gift, luck, lock, vip, speed, starter, plus, egg, slots,
       music, lambda: music(True)]


def sheet():
    names = sorted(p.stem for p in OUT.glob("*.png"))
    cell = 150
    img = Image.new("RGBA", (cell * 6, cell * ((len(names) + 5) // 6) * 2), (40, 44, 70, 255))
    d = ImageDraw.Draw(img)
    for i, n in enumerate(names):
        icon = Image.open(OUT / f"{n}.png")
        x, y = (i % 6) * cell, (i // 6) * cell * 2
        img.alpha_composite(icon.resize((128, 128), Image.LANCZOS), (x + 11, y + 4))
        d.rounded_rectangle([x + 40, y + cell + 10, x + 110, y + cell + 80], 14, fill=(255, 170, 40), outline=(20, 20, 30),
                            width=3)
        img.alpha_composite(icon.resize((60, 60), Image.LANCZOS), (x + 45, y + cell + 6))
        d.text((x + 8, y + cell - 14), n, fill=(255, 255, 255))
    img.save(ROOT / "art" / "icons_sheet.png")


if __name__ == "__main__":
    for fn in ALL:
        fn()
    sheet()
    print("wrote", len(list(OUT.glob("*.png"))), "icons to", OUT)
