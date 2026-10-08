"""Extra UI icons for Find the Dragon Eggs, drawn with the same primitives as tools/art.py.

Usage: python3 tools/art_findthe.py  ->  writes hint, hints, radar, glow, skip, jump, teleport PNGs to art/icons/
"""
import math
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from art import (GOLD, INK, Icon, darker, draw_mask, ell, grow, inter, lighter, minus, paint, poly, rot, rr, sc,  # noqa: E402
                 shape, shrink, soft, sparkles, star, text_mask, union)


def magnifier(ic, cx, cy, r, lens=(170, 230, 255)):
    ring = minus(ell(cx - r, cy - r, cx + r, cy + r), ell(cx - r * 0.72, cy - r * 0.72, cx + r * 0.72, cy + r * 0.72))
    # handle pointing down-right
    hx, hy = cx + r * 0.62, cy + r * 0.62
    handle = rot(rr(hx - r * 0.22, hy, hx + r * 0.22, hy + r * 1.05, r * 0.2), 45, hx, hy)
    shape(ic.fg, handle, (150, 80, 40))
    glass = ell(cx - r * 0.74, cy - r * 0.74, cx + r * 0.74, cy + r * 0.74)
    shape(ic.fg, glass, lens, outline=0, stops=(lighter(lens, 0.6), lens, darker(lens, 0.8)))
    shape(ic.fg, ring, GOLD)
    return glass


def hint():
    ic = Icon(glow=(120, 200, 255), burst=(200, 235, 255))
    glass = magnifier(ic, 104, 100, 78)
    # a tiny dragon egg seen through the lens
    egg = ell(80, 62, 132, 140)
    shape(ic.fg, inter(egg, glass), (240, 70, 80), outline=5, stops=((255, 140, 120), (230, 50, 70), (140, 20, 50)))
    paint(ic.fg, soft(inter(ell(52, 48, 112, 84), glass), 1), (255, 255, 255), 0.6)
    shape(ic.fg, text_mask("?", 206, 52, 70, 12), (255, 230, 80), outline=7, gloss=False)
    sparkles(ic.top, [(222, 120, 16), (30, 214, 12)])
    ic.save("hint")


def hints():
    ic = Icon(glow=(120, 200, 255), burst=(200, 235, 255))
    magnifier(ic, 74, 70, 50)
    magnifier(ic, 124, 112, 66)
    badge = ell(150, 150, 248, 248)
    shape(ic.fg, badge, (70, 220, 90), outline=8)
    shape(ic.fg, text_mask("x10", 199, 201, 42), (255, 255, 255), outline=5, gloss=False, shade=False,
          stops=((255, 255, 255), (220, 255, 220)))
    sparkles(ic.top, [(34, 210, 14), (226, 40, 16)])
    ic.save("hints")


def radar():
    ic = Icon(glow=(150, 255, 170))
    disc = ell(22, 22, 234, 234)
    shape(ic.fg, disc, (40, 150, 90), stops=((80, 210, 130), (30, 130, 80), (10, 70, 50)))
    for r in (70, 40):
        ring = minus(ell(128 - r, 128 - r, 128 + r, 128 + r), ell(128 - r + 4, 128 - r + 4, 128 + r - 4, 128 + r - 4))
        paint(ic.fg, ring, (160, 255, 190), 0.7)
    paint(ic.fg, rr(126, 30, 130, 226, 0), (160, 255, 190), 0.5)
    paint(ic.fg, rr(30, 126, 226, 130, 0), (160, 255, 190), 0.5)
    sweep = inter(poly([(128, 128), (128, 18), (240, 60)]), shrink(disc, 4))
    paint(ic.fg, soft(sweep, 2), (190, 255, 200), 0.75)
    for x, y, r, c in ((176, 80, 16, (255, 80, 90)), (88, 162, 11, (255, 210, 60))):
        paint(ic.fg, soft(ell(x - r * 2, y - r * 2, x + r * 2, y + r * 2), 4), c, 0.7)
        shape(ic.fg, ell(x - r, y - r, x + r, y + r), c, outline=5)
    paint(ic.fg, minus(grow(disc, 9), disc), INK)
    sparkles(ic.top, [(224, 30, 16), (34, 222, 12)])
    ic.save("radar")


def glow():
    ic = Icon(glow=(255, 230, 120), burst=(255, 245, 170), burst_n=16)
    egg = ell(62, 30, 194, 226)
    paint(ic.bg, soft(grow(egg, 20), 12), (255, 240, 150), 0.9)
    shape(ic.fg, egg, (255, 210, 60), stops=((255, 255, 210), (255, 200, 50), (230, 120, 20)))
    for x, y, r in ((104, 90, 12), (150, 130, 10), (112, 168, 9), (160, 186, 8)):
        paint(ic.fg, inter(ell(x - r, y - r, x + r, y + r), shrink(egg, 4)), (255, 250, 220), 0.9)
    shape(ic.fg, star(206, 52, 34, 12, 4), (255, 255, 255), outline=6, gloss=False,
          stops=((255, 255, 255), (255, 240, 180)))
    sparkles(ic.top, [(36, 60, 18), (44, 206, 14), (220, 196, 12)])
    ic.save("glow")


def skip():
    ic = Icon(glow=(255, 160, 80), burst=(255, 220, 150), burst_n=12)
    a1 = poly([(20, 48), (128, 128), (20, 208)])
    a2 = poly([(118, 48), (226, 128), (118, 208)])
    shape(ic.fg, union(a1, a2), (255, 140, 40), stops=((255, 220, 120), (255, 140, 40), (220, 70, 20)))
    shape(ic.fg, rr(214, 44, 244, 212, 10), (255, 140, 40), outline=8)
    sparkles(ic.top, [(40, 30, 16), (220, 226, 12)])
    ic.save("skip")


def jump():
    ic = Icon(glow=(140, 220, 255), burst=(200, 240, 255))
    for k, y in enumerate((150, 200)):
        arrow = poly([(128, y - 108), (214, y - 30), (162, y - 30), (162, y + 2), (94, y + 2), (94, y - 30), (42, y - 30)])
        shape(ic.fg, arrow, (90, 200, 255) if k else (255, 120, 200))
    paint(ic.fg, soft(ell(70, 222, 186, 246), 2), (0, 0, 0), 0.35)
    sparkles(ic.top, [(36, 40, 16), (222, 60, 12)])
    ic.save("jump")


def teleport():
    ic = Icon(glow=(120, 230, 255), burst=(190, 245, 255))
    swirl = draw_mask(lambda d: [d.arc(sc(128 - r, 128 - r, 128 + r, 128 + r), a, a + 250, fill=255, width=18 * 4)
                                 for r, a in ((104, 0), (72, 120), (40, 240))])
    shape(ic.fg, swirl, (90, 210, 240), stops=((200, 250, 255), (80, 200, 240), (50, 110, 220)))
    shape(ic.fg, ell(108, 108, 148, 148), (255, 255, 255), outline=6)
    sparkles(ic.top, [(222, 40, 18), (34, 214, 14), (218, 214, 10)])
    ic.save("teleport")


ALL = [hint, hints, radar, glow, skip, jump, teleport]

if __name__ == "__main__":
    for fn in ALL:
        fn()
    print("wrote", [f.__name__ for f in ALL])
