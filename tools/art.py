"""Generate cartoon UI icons (thick outline + gradient + shine) for the egg game.

Usage: python3 tools/art.py  ->  writes PNGs to art/icons/
"""
import math
import pathlib

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = pathlib.Path(__file__).resolve().parent.parent / "art" / "icons"
SS = 4  # supersampling
SIZE = 256
S = SIZE * SS
OUTLINE = (28, 22, 40, 255)


def canvas():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def mask_of(draw_fn):
    m = Image.new("L", (S, S), 0)
    draw_fn(ImageDraw.Draw(m))
    return m


def gradient(top, bottom):
    g = Image.new("RGBA", (S, S))
    d = ImageDraw.Draw(g)
    for y in range(S):
        t = y / (S - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,)
        d.line([(0, y), (S, y)], fill=c)
    return g


def dilate(mask, r):
    return mask.filter(ImageFilter.GaussianBlur(r * 0.6)).point(lambda v: 255 if v > 6 else 0)


def erode(mask, r):
    return mask.filter(ImageFilter.GaussianBlur(r * 0.6)).point(lambda v: 255 if v > 249 else 0)


def shape(img, mask, top, bottom, outline=36, shine=True):
    """Paint a filled shape with a gradient, thick dark outline and a soft top shine."""
    grown = dilate(mask, outline) if outline else mask
    border = Image.new("RGBA", (S, S), OUTLINE)
    img.paste(border, (0, 0), grown)
    img.paste(gradient(top, bottom), (0, 0), mask)
    if shine:
        # highlight: top part of the shape, shrunk, semi-transparent white
        inner = erode(mask, 28)
        band = Image.new("L", (S, S), 0)
        bbox = mask.getbbox()
        if bbox:
            x0, y0, x1, y1 = bbox
            ImageDraw.Draw(band).rectangle([0, 0, S, y0 + (y1 - y0) * 0.42], fill=110)
        hl = ImageChops.multiply(inner, band)
        img.paste(Image.new("RGBA", (S, S), (255, 255, 255, 255)), (0, 0), hl)


def save(img, name):
    OUT.mkdir(parents=True, exist_ok=True)
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    img.save(OUT / f"{name}.png")


def ellipse(box):
    return mask_of(lambda d: d.ellipse(box, fill=255))


def rrect(box, r):
    return mask_of(lambda d: d.rounded_rectangle(box, r, fill=255))


def poly(points):
    return mask_of(lambda d: d.polygon(points, fill=255))


def union(*ms):
    out = ms[0]
    for m in ms[1:]:
        out = ImageChops.lighter(out, m)
    return out


def sub(a, b):
    return ImageChops.subtract(a, b)


def P(x, y):
    return (x * SS, y * SS)


def B(x0, y0, x1, y1):
    return [x0 * SS, y0 * SS, x1 * SS, y1 * SS]


# ---------------------------------------------------------------- icons
def cash():
    img = canvas()
    for i, off in enumerate((40, 20, 0)):
        m = mask_of(lambda d, o=off: d.rounded_rectangle(B(28, 70 + o, 228, 170 + o), 18 * SS, fill=255))
        m = m.rotate(-12, center=(S / 2, S / 2), resample=Image.BICUBIC)
        shape(img, m, (120, 235, 120), (40, 160, 70), shine=i == 2)
    d = ImageDraw.Draw(img)
    c = ellipse(B(98, 82, 158, 142)).rotate(-12, center=(S / 2, S / 2))
    img.paste(Image.new("RGBA", (S, S), (30, 120, 50, 255)), (0, 0), c)
    _ = d
    save(img, "cash")


def coins_bag():
    img = canvas()
    body = ellipse(B(40, 80, 216, 236))
    neck = poly([P(96, 96), P(160, 96), P(176, 50), P(80, 50)])
    shape(img, union(body, neck), (250, 210, 110), (190, 130, 50))
    tie = rrect(B(84, 86, 172, 104), 8 * SS)
    shape(img, tie, (210, 80, 70), (150, 40, 40), outline=16, shine=False)
    dollar = mask_of(lambda d: d.text(P(100, 120), "$", fill=255))
    _ = dollar
    coin = ellipse(B(100, 130, 156, 186))
    shape(img, coin, (255, 230, 90), (230, 160, 30), outline=14)
    save(img, "bag")


def vault():
    img = canvas()
    shape(img, rrect(B(30, 40, 226, 226), 26 * SS), (180, 190, 210), (100, 110, 140))
    shape(img, ellipse(B(68, 78, 188, 198)), (230, 235, 245), (150, 160, 180), outline=20)
    shape(img, ellipse(B(110, 120, 146, 156)), (90, 100, 120), (50, 55, 70), outline=12, shine=False)
    for a in range(0, 360, 60):
        x = 128 + math.cos(math.radians(a)) * 42
        y = 138 + math.sin(math.radians(a)) * 42
        shape(img, ellipse(B(x - 8, y - 8, x + 8, y + 8)), (255, 210, 70), (220, 150, 30), outline=8, shine=False)
    save(img, "vault")


def cart():
    img = canvas()
    basket = poly([P(40, 70), P(226, 70), P(200, 160), P(66, 160)])
    shape(img, basket, (255, 200, 80), (240, 140, 30))
    handle = rrect(B(16, 50, 70, 70), 10 * SS)
    shape(img, handle, (120, 130, 150), (70, 80, 100), outline=16, shine=False)
    for cx in (88, 182):
        shape(img, ellipse(B(cx - 22, 170, cx + 22, 214)), (90, 95, 110), (50, 52, 62), outline=16)
    save(img, "shop")


def rebirth():
    img = canvas()
    ring = sub(ellipse(B(36, 36, 220, 220)), ellipse(B(84, 84, 172, 172)))
    gap = poly([P(128, 128), P(256, 40), P(256, 128)])
    ring = sub(ring, gap)
    arrow = poly([P(150, 20), P(240, 70), P(156, 120)])
    shape(img, union(ring, arrow), (210, 140, 255), (130, 60, 220))
    save(img, "rebirth")


def book():
    img = canvas()
    shape(img, rrect(B(40, 30, 216, 226), 18 * SS), (90, 170, 255), (40, 100, 210))
    shape(img, rrect(B(60, 44, 200, 206), 10 * SS), (255, 250, 235), (225, 215, 195), outline=10, shine=False)
    egg = ellipse(B(100, 80, 156, 152))
    shape(img, egg, (255, 220, 120), (240, 160, 60), outline=14)
    shape(img, rrect(B(40, 30, 74, 226), 14 * SS), (60, 140, 240), (30, 80, 180), outline=0, shine=False)
    save(img, "index")


def calendar():
    img = canvas()
    shape(img, rrect(B(32, 48, 224, 228), 24 * SS), (255, 255, 255), (220, 225, 235))
    shape(img, rrect(B(32, 48, 224, 104), 24 * SS), (255, 100, 120), (220, 50, 80), outline=0)
    for x in (80, 176):
        shape(img, rrect(B(x - 10, 28, x + 10, 72), 10 * SS), (120, 130, 150), (70, 80, 100), outline=12, shine=False)
    star = poly([P(128 + math.cos(math.radians(a - 90)) * (44 if k % 2 == 0 else 18),
                   166 + math.sin(math.radians(a - 90)) * (44 if k % 2 == 0 else 18)) for k, a in enumerate(range(0, 360, 36))])
    shape(img, star, (255, 220, 80), (240, 150, 30), outline=14)
    save(img, "daily")


def gift():
    img = canvas()
    shape(img, rrect(B(40, 104, 216, 226), 14 * SS), (255, 110, 170), (210, 50, 120))
    shape(img, rrect(B(28, 80, 228, 124), 14 * SS), (255, 140, 190), (230, 70, 140))
    shape(img, rrect(B(112, 80, 144, 226), 4 * SS), (255, 230, 90), (240, 170, 40), outline=0, shine=False)
    bow = union(ellipse(B(70, 30, 128, 86)), ellipse(B(128, 30, 186, 86)))
    shape(img, bow, (255, 230, 90), (240, 170, 40), outline=20)
    save(img, "gift")


def clover():
    img = canvas()
    leaves = union(*[ellipse(B(128 + dx - 50, 118 + dy - 50, 128 + dx + 50, 118 + dy + 50))
                     for dx, dy in ((-44, -40), (44, -40), (-44, 44), (44, 44))])
    stem = poly([P(124, 150), P(140, 150), P(176, 240), P(156, 244)])
    shape(img, union(leaves, stem), (130, 240, 110), (40, 160, 60))
    save(img, "luck")


def lock():
    img = canvas()
    shackle = sub(rrect(B(66, 20, 190, 150), 62 * SS), rrect(B(98, 52, 158, 150), 30 * SS))
    shape(img, shackle, (200, 205, 220), (120, 125, 145))
    shape(img, rrect(B(40, 100, 216, 230), 24 * SS), (255, 210, 80), (230, 140, 30))
    shape(img, union(ellipse(B(112, 136, 144, 168)), rrect(B(120, 150, 136, 196), 6 * SS)), (90, 60, 30), (60, 40, 20),
          outline=0, shine=False)
    save(img, "lock")


def crown():
    img = canvas()
    c = poly([P(30, 200), P(30, 80), P(80, 130), P(128, 50), P(176, 130), P(226, 80), P(226, 200)])
    shape(img, c, (255, 225, 90), (235, 150, 30))
    for x, y, col in ((128, 160, (255, 80, 110)), (72, 168, (90, 170, 255)), (184, 168, (90, 220, 120))):
        shape(img, ellipse(B(x - 16, y - 16, x + 16, y + 16)), col, tuple(int(v * 0.6) for v in col), outline=10)
    save(img, "vip")


def shoe():
    img = canvas()
    body = union(rrect(B(30, 120, 226, 200), 36 * SS), rrect(B(50, 60, 130, 170), 30 * SS))
    shape(img, body, (90, 200, 255), (40, 110, 230))
    shape(img, rrect(B(26, 190, 230, 222), 14 * SS), (255, 255, 255), (210, 215, 225), outline=14, shine=False)
    for k in range(3):
        shape(img, poly([P(150 + k * 26, 30), P(166 + k * 26, 30), P(140 + k * 26, 100), P(124 + k * 26, 100)]),
              (255, 230, 90), (240, 170, 40), outline=10, shine=False)
    save(img, "speed")


def egg(name, top, bottom, spots):
    img = canvas()
    shape(img, ellipse(B(52, 20, 204, 236)), top, bottom)
    for x, y, r in ((96, 150, 16), (150, 110, 12), (140, 182, 18), (110, 80, 10)):
        shape(img, ellipse(B(x - r, y - r, x + r, y + r)), spots, tuple(int(v * 0.75) for v in spots), outline=0, shine=False)
    save(img, name)


def starter():
    img = canvas()
    shape(img, rrect(B(44, 60, 212, 230), 36 * SS), (255, 150, 70), (220, 80, 40))
    shape(img, rrect(B(90, 24, 166, 76), 24 * SS), (200, 110, 50), (150, 70, 30), outline=18, shine=False)
    shape(img, rrect(B(70, 130, 186, 200), 18 * SS), (255, 190, 110), (230, 120, 60), outline=14)
    shape(img, ellipse(B(110, 140, 146, 176)), (255, 230, 90), (240, 160, 30), outline=10, shine=False)
    save(img, "starter")


def plus():
    img = canvas()
    shape(img, union(rrect(B(100, 30, 156, 226), 20 * SS), rrect(B(30, 100, 226, 156), 20 * SS)), (140, 240, 110), (50, 170, 60))
    save(img, "plus")


if __name__ == "__main__":
    cash()
    coins_bag()
    vault()
    cart()
    rebirth()
    book()
    calendar()
    gift()
    clover()
    lock()
    crown()
    shoe()
    starter()
    plus()
    egg("egg", (255, 245, 225), (230, 200, 160), (240, 170, 90))
    egg("slots", (180, 230, 255), (80, 150, 240), (255, 255, 255))
    print("wrote", len(list(OUT.glob("*.png"))), "icons to", OUT)
