"""Cover art for "Steal a Dragon Egg": game icon (512x512) and thumbnails (1920x1080).

Usage: python3 tools/cover.py  ->  art/cover/icon.png, art/cover/thumb1.png, art/cover/thumb2.png
Reuses the icon style from tools/art.py (outline, gradient, cel shade, gloss, sparkles).
"""
import math
import pathlib
import random

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

import art
from art import (CASH, GOLD, INK, Icon, coin, darker, draw_mask, ell, grow, inter, lighter, paint, poly, rot, rr, sc,
                 shape, shrink, soft, sparkles, star, union)

OUT = art.ROOT / "art" / "cover"
FONT = str(art.FONT)


# ---------------------------------------------------------------- sprites (1024px, 256-unit grid)
EGGS = {
    "dragon": dict(stops=((255, 130, 110), (225, 40, 60), (110, 10, 40)), glow=(255, 110, 40), spots=None,
                   scales=(120, 10, 30), crack=(255, 235, 140)),
    "gold": dict(stops=((255, 250, 190), (255, 200, 40), (210, 120, 10)), glow=(255, 220, 80), spots=(255, 240, 160),
                 crack=None),
    "cosmic": dict(stops=((150, 130, 255), (90, 50, 230), (30, 10, 110)), glow=(150, 100, 255), spots=None,
                   crack=None, stars=True),
    "void": dict(stops=((90, 40, 110), (35, 10, 50), (8, 0, 14)), glow=(220, 60, 255), spots=None,
                 crack=(255, 120, 255)),
    "frost": dict(stops=((235, 250, 255), (160, 220, 255), (70, 140, 230)), glow=(140, 220, 255), spots=(255, 255, 255),
                  crack=None),
}


def egg_sprite(kind, seed=4):
    e = EGGS[kind]
    ic = Icon()
    body = ell(50, 18, 206, 240)
    shape(ic.fg, body, e["stops"][1], stops=e["stops"])
    rng = random.Random(seed)
    if e.get("scales"):
        scales = art.blank()
        d = ImageDraw.Draw(scales)
        for row, y in enumerate(range(30, 240, 20)):
            for x in range(40 + (row % 2) * 13, 220, 26):
                d.arc(sc(x - 13, y - 13, x + 13, y + 13), 10, 170, fill=255, width=3 * art.U)
        paint(ic.fg, inter(scales, shrink(body, 5)), e["scales"], 0.55)
    if e.get("spots"):
        for _ in range(9):
            x, y, r = rng.uniform(70, 186), rng.uniform(50, 220), rng.uniform(9, 16)
            paint(ic.fg, inter(poly([(x, y - r), (x + r, y), (x, y + r * 1.3), (x - r, y)]), shrink(body, 6)), e["spots"], 0.85)
    if e.get("stars"):
        for _ in range(14):
            x, y, r = rng.uniform(70, 186), rng.uniform(40, 225), rng.uniform(3, 8)
            paint(ic.fg, inter(star(x, y, r, r * 0.3, 4), shrink(body, 6)), (255, 255, 255), 0.9)
    if e.get("crack"):
        crack = draw_mask(lambda d: d.line(sc(70, 120, 98, 104, 118, 130, 146, 108, 168, 132, 192, 118), fill=255,
                                           width=6 * art.U, joint="curve"))
        crack = inter(crack, shrink(body, 2))
        paint(ic.fg, soft(crack, 4), e["crack"], 0.95)
        paint(ic.fg, crack, lighter(e["crack"], 0.6))
    sparkles(ic.top, [(222, 46, 18), (34, 78, 12)])
    return ic.image()


def robber_sprite():
    """Blocky avatar in a striped shirt, beanie and eye mask, reaching right."""
    ic = Icon()
    skin = (250, 205, 50)
    shirt = ((255, 255, 255), (230, 232, 240))

    def striped(m):
        shape(ic.fg, m, shirt[0], gloss=False, stops=shirt)
        for y in range(120, 256, 22):
            paint(ic.fg, inter(rr(0, y, 256, y + 11, 0), shrink(m, 1)), (35, 35, 45), 0.95)

    striped(rr(84, 132, 172, 252, 12))
    striped(rr(46, 136, 82, 230, 12))
    shape(ic.fg, rr(46, 222, 82, 250, 12), skin, gloss=False)
    sx, sy, length, ang = 178, 146, 60, 128
    striped(rot(rr(sx - 18, sy, sx + 18, sy + length, 12), ang, sx, sy))
    ex, ey = sx + length * math.sin(math.radians(ang)), sy + length * math.cos(math.radians(ang))
    shape(ic.fg, ell(ex - 17, ey - 17, ex + 17, ey + 17), skin, gloss=False)
    head = rr(78, 40, 178, 130, 36)
    shape(ic.fg, head, skin)
    shape(ic.fg, rr(72, 72, 184, 102, 14), (30, 30, 40), outline=6, gloss=False, shade=False)
    for x in (110, 146):
        paint(ic.fg, ell(x - 13, 76, x + 13, 98), (255, 255, 255))
        paint(ic.fg, ell(x - 1, 81, x + 11, 94), (20, 20, 30))
    smirk = draw_mask(lambda d: d.arc(sc(112, 96, 162, 122), 20, 150, fill=255, width=5 * art.U))
    paint(ic.fg, smirk, (40, 25, 25))
    shape(ic.fg, union(rr(72, 12, 184, 62, 28), ell(116, 2, 140, 26)), (50, 50, 64), outline=7)
    shape(ic.fg, rr(68, 48, 188, 66, 9), (70, 70, 88), outline=6, gloss=False)
    return ic.image()


def sack_sprite():
    ic = Icon()
    body = union(ell(34, 82, 222, 244), poly([(92, 98), (164, 98), (186, 44), (70, 44)]))
    shape(ic.fg, body, (200, 150, 80))
    shape(ic.fg, rr(78, 84, 178, 106, 10), (230, 60, 70), outline=7)
    shape(ic.fg, art.text_mask("$", 128, 168, 92), (110, 230, 120), outline=8, stops=((170, 255, 170), (60, 180, 80)))
    return ic.image()


def coin_sprite():
    ic = Icon()
    coin(ic.fg, 128, 128, 96, label="")
    shape(ic.fg, art.text_mask("$", 128, 134, 120), (255, 230, 120), outline=6, gloss=False, shade=False,
          stops=((255, 250, 210), (240, 170, 30)))
    return ic.image()


def bill_sprite():
    ic = Icon()
    shape(ic.fg, rr(20, 70, 236, 186, 16), CASH)
    inner = rr(38, 86, 218, 170, 10)
    paint(ic.fg, ImageChops.subtract(inner, shrink(inner, 3)), (40, 130, 60), 0.9)
    coin(ic.fg, 128, 128, 34)
    return ic.image()


# ---------------------------------------------------------------- big-canvas helpers (pixel units)
def radial_bg(w, h, cx, cy, stops):
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / math.hypot(max(cx, w - cx), max(cy, h - cy))
    d = np.clip(d, 0, 1)
    pos = np.array([p for p, _ in stops])
    cols = np.array([c for _, c in stops], float)
    arr = np.empty((h, w, 4), np.uint8)
    for ch in range(3):
        arr[..., ch] = np.interp(d, pos, cols[:, ch]).astype(np.uint8)
    arr[..., 3] = 255
    return Image.fromarray(arr, "RGBA")


def rays(w, h, cx, cy, n, color, alpha, spin=0):
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    r = math.hypot(w, h)
    for k in range(n):
        a0 = math.radians(spin + k * 360 / n)
        a1 = math.radians(spin + (k + 0.5) * 360 / n)
        d.polygon([(cx, cy), (cx + math.cos(a0) * r, cy + math.sin(a0) * r), (cx + math.cos(a1) * r, cy + math.sin(a1) * r)],
                  fill=int(255 * alpha))
    layer = Image.new("RGBA", (w, h), color + (0,))
    layer.putalpha(m.filter(ImageFilter.GaussianBlur(3)))
    return layer


def vignette(img, strength=0.55):
    w, h = img.size
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2) / math.sqrt(2)
    a = (np.clip((d - 0.45) / 0.55, 0, 1) ** 1.6 * 255 * strength).astype(np.uint8)
    dark = Image.new("RGBA", (w, h), (20, 0, 30, 0))
    dark.putalpha(Image.fromarray(a, "L"))
    img.alpha_composite(dark)


def glow(canvas, cx, cy, r, color, alpha=0.8):
    w, h = canvas.size
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).ellipse([cx - r, cy - r * 1.1, cx + r, cy + r * 1.1], fill=int(255 * alpha))
    layer = Image.new("RGBA", (w, h), color + (0,))
    layer.putalpha(m.filter(ImageFilter.GaussianBlur(r * 0.35)))
    canvas.alpha_composite(layer)


def egg(canvas, sp, kind, cx, cy, size, angle=0):
    glow(canvas, cx, cy, size * 0.42, EGGS[kind]["glow"])
    place(canvas, sp[kind], cx, cy, size, angle)


def place(canvas, sprite, cx, cy, size, angle=0):
    s = sprite.resize((size, size), Image.LANCZOS)
    if angle:
        s = s.rotate(angle, resample=Image.BICUBIC, expand=True)
    canvas.alpha_composite(s, (int(cx - s.width / 2), int(cy - s.height / 2)))


def title(canvas, txt, cx, cy, size, stops, outline, angle=0, shadow=14):
    w, h = canvas.size
    font = ImageFont.truetype(FONT, size)
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    x0, y0, x1, y1 = d.textbbox((0, 0), txt, font=font)
    d.text((cx - (x0 + x1) / 2, cy - (y0 + y1) / 2), txt, font=font, fill=255)
    if angle:
        m = m.rotate(angle, center=(cx, cy), resample=Image.BICUBIC)
    ol = m.filter(ImageFilter.GaussianBlur(outline * 0.55)).point(lambda v: 255 if v > 8 else 0)
    sh = ImageChops.offset(ol, 0, shadow).filter(ImageFilter.GaussianBlur(6)).point(lambda v: int(v * 0.6))
    canvas.paste(Image.new("RGBA", (w, h), (0, 0, 0, 255)), (0, 0), sh)
    canvas.paste(Image.new("RGBA", (w, h), INK + (255,)), (0, 0), ol)
    box = m.getbbox()
    yy = np.clip((np.arange(h) - box[1]) / max(1, box[3] - box[1]), 0, 1)
    pos = np.linspace(0, 1, len(stops))
    cols = np.array(stops, float)
    grad = np.empty((h, w, 4), np.uint8)
    for ch in range(3):
        grad[..., ch] = np.interp(yy, pos, cols[:, ch])[:, None].astype(np.uint8)
    grad[..., 3] = 255
    canvas.paste(Image.fromarray(grad, "RGBA"), (0, 0), m)
    # glossy band on the upper part of the letters
    band = Image.new("L", (w, h), 0)
    ImageDraw.Draw(band).rectangle([0, box[1], w, box[1] + (box[3] - box[1]) * 0.42], fill=90)
    inner = m.filter(ImageFilter.GaussianBlur(outline * 0.3)).point(lambda v: 255 if v > 247 else 0)
    canvas.paste(Image.new("RGBA", (w, h), (255, 255, 255, 255)), (0, 0), ImageChops.multiply(inner, band))


def bubble(canvas, txt, cx, cy, size, fill, angle=0):
    """Text on a rounded pill, e.g. "+$60K/s"."""
    font = ImageFont.truetype(FONT, size)
    tmp = ImageDraw.Draw(Image.new("L", (1, 1)))
    x0, y0, x1, y1 = tmp.textbbox((0, 0), txt, font=font)
    pw, ph = x1 - x0 + size, y1 - y0 + size * 0.6
    pill = Image.new("RGBA", (int(pw + 40), int(ph + 40)), (0, 0, 0, 0))
    d = ImageDraw.Draw(pill)
    d.rounded_rectangle([20, 20, 20 + pw, 20 + ph], ph / 2, fill=fill + (255,), outline=INK + (255,), width=max(6, size // 9))
    d.rounded_rectangle([20 + ph * 0.3, 20 + ph * 0.14, 20 + pw - ph * 0.3, 20 + ph * 0.4], ph * 0.15,
                        fill=(255, 255, 255, 80))
    d.text((20 + pw / 2 - (x0 + x1) / 2, 20 + ph / 2 - (y0 + y1) / 2), txt, font=font, fill=(255, 255, 255, 255),
           stroke_width=max(4, size // 12), stroke_fill=INK + (255,))
    if angle:
        pill = pill.rotate(angle, resample=Image.BICUBIC, expand=True)
    canvas.alpha_composite(pill, (int(cx - pill.width / 2), int(cy - pill.height / 2)))


YELLOW_TXT = ((255, 255, 190), (255, 225, 60), (255, 150, 20))
WHITE_TXT = ((255, 255, 255), (255, 240, 220), (255, 200, 170))


# ---------------------------------------------------------------- compositions
def thumb1(sp):
    w, h = 1920, 1080
    c = radial_bg(w, h, 1300, 560, [(0, (255, 215, 90)), (0.35, (250, 110, 40)), (0.7, (170, 30, 70)), (1, (60, 10, 70))])
    c.alpha_composite(rays(w, h, 1300, 560, 22, (255, 240, 180), 0.22))
    vignette(c)
    egg(c, sp, "void", 1720, 300, 420, -12)
    egg(c, sp, "gold", 1760, 850, 430, 14)
    egg(c, sp, "dragon", 1300, 580, 1000, -6)
    for x, y, s, a in ((960, 980, 260, 20), (1530, 1010, 200, -10), (820, 820, 170, 0)):
        place(c, sp["coin"], x, y, s, a)
    for x, y, s, a in ((640, 1000, 300, -25), (1080, 1040, 280, 12)):
        place(c, sp["bill"], x, y, s, a)
    place(c, sp["robber"], 420, 760, 760, 0)
    place(c, sp["sack"], 170, 930, 330, -10)
    title(c, "STEAL A", 470, 120, 150, WHITE_TXT, 34, angle=4)
    title(c, "DRAGON EGG", 640, 300, 210, YELLOW_TXT, 42, angle=4)
    bubble(c, "+$60K/s", 1330, 980, 70, (60, 200, 80), angle=-4)
    bubble(c, "SECRET", 1720, 520, 54, (170, 40, 220), angle=8)
    return c


def thumb2(sp):
    w, h = 1920, 1080
    c = radial_bg(w, h, 960, 600, [(0, (190, 120, 255)), (0.4, (100, 40, 200)), (0.75, (40, 10, 100)), (1, (12, 4, 40))])
    c.alpha_composite(rays(w, h, 960, 620, 26, (230, 200, 255), 0.2, spin=6))
    vignette(c)
    lineup = [("frost", 260, 640, 400, 10, "RARE", (60, 140, 255)), ("gold", 640, 600, 470, 6, "LEGENDARY", (240, 160, 20)),
              ("cosmic", 1280, 600, 470, -6, "MYTHIC", (230, 40, 90)), ("dragon", 1660, 640, 400, -10, "MYTHIC", (230, 40, 90))]
    for k, x, y, s, a, label, col in lineup:
        egg(c, sp, k, x, y, s, a)
        bubble(c, label, x, y + s * 0.47, 46, col, angle=a / 2)
    egg(c, sp, "void", 960, 560, 640, 0)
    bubble(c, "SECRET", 960, 900, 72, (170, 40, 220))
    title(c, "STEAL THE RAREST EGGS!", 960, 130, 130, YELLOW_TXT, 32, angle=0)
    return c


def icon(sp):
    w = h = 1024
    c = radial_bg(w, h, 560, 470, [(0, (255, 220, 100)), (0.4, (250, 110, 40)), (0.8, (160, 25, 80)), (1, (70, 10, 70))])
    c.alpha_composite(rays(w, h, 560, 470, 18, (255, 240, 180), 0.25))
    vignette(c, 0.45)
    egg(c, sp, "dragon", 600, 470, 860, -8)
    place(c, sp["coin"], 860, 880, 230, 15)
    place(c, sp["coin"], 700, 950, 170, -10)
    place(c, sp["robber"], 250, 720, 640, 0)
    title(c, "STEAL!", 512, 900, 170, YELLOW_TXT, 36, angle=6)
    return c.resize((512, 512), Image.LANCZOS)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    sprites = {k: egg_sprite(k) for k in EGGS}
    sprites.update(robber=robber_sprite(), sack=sack_sprite(), coin=coin_sprite(), bill=bill_sprite())
    icon(sprites).convert("RGB").save(OUT / "icon.png")
    thumb1(sprites).convert("RGB").save(OUT / "thumb1.png")
    thumb2(sprites).convert("RGB").save(OUT / "thumb2.png")
    print("wrote", OUT)
