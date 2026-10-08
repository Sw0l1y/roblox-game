"""Cover art for "Find the Dragon Eggs": game icon (512x512) and thumbnails (1920x1080).

Usage: python3 tools/cover_findthe.py  ->  art/cover_findthe/icon.png, thumb1.png, thumb2.png
Reuses sprites and helpers from tools/cover.py and tools/art_findthe.py.
"""
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import art  # noqa: E402
from art import Icon, ell, shape, sparkles, union  # noqa: E402
from art_findthe import magnifier  # noqa: E402
from cover import (EGGS, WHITE_TXT, YELLOW_TXT, bubble, egg, egg_sprite, place, radial_bg, rays, title,  # noqa: E402
                   vignette)

OUT = art.ROOT / "art" / "cover_findthe"


def bush_sprite(color=(90, 200, 80)):
    ic = Icon()
    blob = union(ell(10, 110, 130, 240), ell(70, 70, 200, 230), ell(140, 110, 250, 240), ell(30, 150, 230, 250))
    shape(ic.fg, blob, color, stops=((150, 235, 120), color, (40, 120, 50)))
    for x, y, c in ((70, 130, (255, 120, 160)), (150, 100, (255, 230, 90)), (200, 170, (255, 255, 255))):
        shape(ic.fg, ell(x - 11, y - 11, x + 11, y + 11), c, outline=5, gloss=False)
    return ic.image()


def magnifier_sprite():
    ic = Icon()
    magnifier(ic, 104, 100, 80)
    sparkles(ic.top, [(30, 30, 12)])
    return ic.image()


def thumb1(sp):
    w, h = 1920, 1080
    c = radial_bg(w, h, 1250, 560, [(0, (200, 255, 160)), (0.35, (90, 200, 120)), (0.7, (30, 120, 120)), (1, (10, 40, 70))])
    c.alpha_composite(rays(w, h, 1250, 560, 22, (255, 255, 200), 0.2))
    vignette(c)
    # eggs peeking out of bushes
    egg(c, sp, "gold", 1700, 300, 330, 14)
    place(c, sp["bush"], 1700, 420, 420, 0)
    egg(c, sp, "frost", 300, 820, 300, -12)
    place(c, sp["bush"], 280, 960, 420, 0)
    egg(c, sp, "void", 1760, 800, 300, -8)
    place(c, sp["bush"], 1800, 960, 400, 0)
    egg(c, sp, "dragon", 1150, 600, 760, -6)
    place(c, sp["mag"], 820, 640, 640, 10)
    title(c, "FIND THE", 560, 130, 150, WHITE_TXT, 34, angle=4)
    title(c, "DRAGON EGGS", 760, 310, 200, YELLOW_TXT, 42, angle=4)
    bubble(c, "100 HIDDEN EGGS!", 1180, 990, 70, (240, 70, 90), angle=-3)
    return c


def thumb2(sp):
    w, h = 1920, 1080
    c = radial_bg(w, h, 960, 600, [(0, (150, 220, 255)), (0.4, (80, 120, 230)), (0.75, (50, 30, 140)), (1, (15, 8, 50))])
    c.alpha_composite(rays(w, h, 960, 620, 26, (220, 240, 255), 0.2, spin=6))
    vignette(c)
    lineup = [("gold", 230, 640, 360, 10, "MEADOW", (90, 190, 70)), ("frost", 600, 600, 420, 6, "FROST", (60, 140, 255)),
              ("cosmic", 1320, 600, 420, -6, "SKY", (170, 40, 220)), ("dragon", 1690, 640, 360, -10, "VOLCANO", (230, 70, 40))]
    for k, x, y, s, a, label, col in lineup:
        egg(c, sp, k, x, y, s, a)
        bubble(c, label, x, y + s * 0.5, 46, col, angle=a / 2)
    egg(c, sp, "void", 960, 560, 600, 0)
    bubble(c, "SECRET", 960, 890, 72, (60, 20, 90))
    title(c, "5 WORLDS • 100 EGGS", 960, 130, 130, YELLOW_TXT, 32)
    return c


def icon(sp):
    w = h = 1024
    c = radial_bg(w, h, 520, 470, [(0, (220, 255, 170)), (0.4, (90, 200, 110)), (0.8, (30, 110, 120)), (1, (10, 40, 70))])
    c.alpha_composite(rays(w, h, 520, 470, 18, (255, 255, 200), 0.25))
    vignette(c, 0.45)
    egg(c, sp, "dragon", 560, 430, 700, -8)
    place(c, sp["bush"], 520, 760, 900, 0)
    place(c, sp["mag"], 330, 380, 560, 0)
    title(c, "FIND IT!", 512, 900, 160, YELLOW_TXT, 36, angle=5)
    return c.resize((512, 512), art.Image.LANCZOS)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    sprites = {k: egg_sprite(k) for k in EGGS}
    sprites.update(bush=bush_sprite(), mag=magnifier_sprite())
    icon(sprites).convert("RGB").save(OUT / "icon.png")
    thumb1(sprites).convert("RGB").save(OUT / "thumb1.png")
    thumb2(sprites).convert("RGB").save(OUT / "thumb2.png")
    print("wrote", OUT)
