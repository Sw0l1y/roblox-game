"""Auto-generated vertical promo shorts (1080x1920, ~12s) for "Steal a Dragon Egg".

Usage: python3 tools/shorts.py [--template spin|steal|ranked] [--seed N] [--out DIR]
Writes <out>/<name>.mp4 plus <name>.txt (caption + hashtags). With no --template, the
template and the featured egg are picked from the seed (default: today's date), so a daily
job gets a different video each day. Art comes from tools/cover.py, SFX from art/sfx (CC0).
"""
import argparse
import datetime
import io
import json
import math
import pathlib
import random
import subprocess
import wave

import numpy as np
from PIL import Image

import art
import cover
from cover import WHITE_TXT, YELLOW_TXT, bubble, glow, place, radial_bg, rays, title, vignette

W, H, FPS = 1080, 1920, 30
DUR = 12.0
SR = 44100
OUT = art.ROOT / "out" / "shorts"
CTA_AT = 8.8

# sprite kind -> (in-game egg name, rarity, odds %, income/s, rarity color)
FEATURED = {
    "frost": ("FROST EGG", "RARE", 6.5, "$55/s", (70, 150, 255)),
    "gold": ("GOLDEN GOOSE", "LEGENDARY", 1.75, "$900/s", (255, 190, 40)),
    "cosmic": ("COSMIC EGG", "MYTHIC", 0.6, "$12K/s", (255, 60, 90)),
    "dragon": ("DRAGON EGG", "MYTHIC", 0.6, "$6K/s", (255, 60, 90)),
    "void": ("VOID EGG", "SECRET", 0.3, "$60K/s", (40, 40, 40)),
}
BG = {
    "frost": [(0, (190, 240, 255)), (0.4, (70, 150, 240)), (1, (20, 30, 90))],
    "gold": [(0, (255, 240, 150)), (0.4, (250, 150, 30)), (1, (110, 30, 30))],
    "cosmic": [(0, (170, 140, 255)), (0.4, (80, 40, 200)), (1, (15, 5, 50))],
    "dragon": [(0, (255, 210, 90)), (0.35, (240, 80, 40)), (1, (70, 10, 40))],
    "void": [(0, (230, 90, 255)), (0.35, (90, 20, 130)), (1, (8, 0, 18))],
}
HOOKS = {
    "spin": ["ONLY {odds}% GET THIS EGG", "I HATCHED THE {name}?!", "{odds}% CHANCE... WATCH", "THE RAREST EGG IN THE GAME"],
    "steal": ["HE STOLE MY {name}", "NEVER LEAVE YOUR BASE UNLOCKED", "STEALING THE {name}"],
    "ranked": ["RAREST EGGS RANKED", "EVERY RARE EGG RANKED", "TOP 5 RAREST EGGS"],
}
TAGS = "#roblox #robloxgames #stealadragonegg #dragonegg #robloxedit #fyp"


def ease_out(t):
    t = min(max(t, 0), 1)
    return 1 - (1 - t) ** 3


def bounce(t):
    """0 -> overshoot -> 1, for pop-in scale."""
    t = min(max(t, 0), 1)
    return 1 + 0.25 * math.sin(t * math.pi * 1.5) * (1 - t) if t > 0 else 0


def text_layer(txt, cy, size, stops=YELLOW_TXT, angle=0):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    font_size = size
    # shrink long lines to fit the width
    while font_size > 60:
        f = cover.ImageFont.truetype(cover.FONT, font_size)
        if f.getlength(txt) < W * 0.88:
            break
        font_size -= 6
    title(layer, txt, W // 2, cy, font_size, stops, outline=max(14, font_size // 6), angle=angle)
    return layer


def wrap(txt, n=14):
    words, lines, cur = txt.split(), [], ""
    for w in words:
        if cur and len(cur) + len(w) + 1 > n:
            lines.append(cur)
            cur = w
        else:
            cur = (cur + " " + w).strip()
    lines.append(cur)
    return lines


def hook_layers(txt, top=230, size=150):
    return [text_layer(line, top + i * int(size * 1.05), size) for i, line in enumerate(wrap(txt))]


class Rays:
    """Pre-rendered half-res ray layer, rotated per frame."""

    def __init__(self, color, alpha, n=20):
        s = int(math.hypot(W, H)) // 2 + 4
        self.img = rays(s, s, s // 2, s // 2, n, color, alpha)

    def at(self, deg, cx, cy):
        r = self.img.rotate(deg, resample=Image.BILINEAR).resize((self.img.width * 2, self.img.height * 2))
        out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        out.alpha_composite(r, (int(cx - r.width / 2), int(cy - r.height / 2)))
        return out


# ---------------------------------------------------------------- audio
def load_sfx():
    meta = json.loads((art.ROOT / "art" / "sfx" / "sprite.json").read_text())
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(art.ROOT / "art" / "sfx" / "sprite.ogg"), "-f", "s16le",
                          "-ac", "1", "-ar", str(SR), "-"], capture_output=True, check=True).stdout
    pcm = np.frombuffer(raw, np.int16).astype(np.float32) / 32768
    return {k: pcm[int(a * SR):int((a + d) * SR)] for k, (a, d) in meta.items()}


def beat(bpm=128):
    """Simple synthesized kick + hat loop so the clip isn't silent between effects."""
    n = int(DUR * SR)
    out = np.zeros(n, np.float32)
    step = 60 / bpm
    t = np.arange(int(0.25 * SR)) / SR
    kick = np.sin(2 * np.pi * (50 + 90 * np.exp(-t * 30)) * t) * np.exp(-t * 9)
    th = np.arange(int(0.05 * SR)) / SR
    hat = np.random.default_rng(1).uniform(-1, 1, th.size) * np.exp(-th * 80)
    for k in range(int(DUR / step) + 1):
        i = int(k * step * SR)
        if i < n:
            seg = kick[: n - i]
            out[i:i + seg.size] += 0.55 * seg
        j = int((k + 0.5) * step * SR)
        if j < n:
            seg = hat[: n - j]
            out[j:j + seg.size] += 0.12 * seg
    return out


def mix(cues):
    sfx = load_sfx()
    track = beat()
    for at, name, vol in cues:
        s = sfx[name] * vol
        i = int(at * SR)
        if i >= track.size:
            continue
        s = s[: track.size - i]
        track[i:i + s.size] += s
    track = np.tanh(track * 1.1) * 0.9
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((track * 32767).astype(np.int16).tobytes())
    return buf.getvalue()


# ---------------------------------------------------------------- shared pieces
class Scene:
    def __init__(self, sp, kind):
        self.sp, self.kind = sp, kind
        self.bg = radial_bg(W // 2, H // 2, W // 4, int(H * 0.25), BG[kind]).resize((W, H), Image.BILINEAR)
        vignette(self.bg, 0.6)
        self.rays = Rays((255, 255, 255), 0.16)
        self.cta = [text_layer("STEAL A", 1180, 150, WHITE_TXT, angle=3), text_layer("DRAGON EGG", 1340, 170, YELLOW_TXT, angle=3)]
        self.cta_sub = bubble_layer("PLAY FREE ON ROBLOX", 1560, 74, (40, 190, 80))

    def base(self, t, cy=None):
        c = self.bg.copy()
        c.alpha_composite(self.rays.at(t * 25, W / 2, cy or H * 0.52))
        return c

    def end_card(self, c, t):
        """CTA slides up over a dark wash from CTA_AT."""
        k = ease_out((t - CTA_AT) / 0.5)
        if k <= 0:
            return
        wash = Image.new("RGBA", (W, H), (10, 0, 20, int(225 * k)))
        c.alpha_composite(wash)
        egg_sz = int(620 * bounce((t - CTA_AT) / 0.6))
        if egg_sz > 10:
            glow(c, W / 2, 760, egg_sz * 0.45, cover.EGGS[self.kind]["glow"])
            place(c, self.sp[self.kind], W / 2, 760 + math.sin(t * 4) * 12, egg_sz, math.sin(t * 3) * 5)
        dy = int((1 - k) * 400)
        for layer in self.cta:
            c.alpha_composite(layer, (0, dy))
        if t > CTA_AT + 0.5:
            pulse = 1 + 0.04 * math.sin(t * 8)
            s = self.cta_sub.resize((int(W * pulse), int(H * pulse)))
            c.alpha_composite(s, (int((W - s.width) / 2), int((H - s.height) / 2)))


def bubble_layer(txt, cy, size, fill):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bubble(layer, txt, W // 2, cy, size, fill)
    return layer


def overlay(c, layers, alpha=1.0, dy=0):
    for layer in layers:
        if alpha < 1:
            layer = layer.copy()
            layer.putalpha(layer.getchannel("A").point(lambda v: int(v * alpha)))
        c.alpha_composite(layer, (0, dy))


# ---------------------------------------------------------------- templates
def spin(sp, kind, rng):
    """Egg roulette that slows down and lands on the featured egg."""
    name, rarity, odds, income, color = FEATURED[kind]
    sc = Scene(sp, kind)
    hook = hook_layers(rng.choice(HOOKS["spin"]).format(odds=odds, name=name))
    pool = [k for k in FEATURED if k != kind]
    # swap times: fast at first, then slower; final swap lands on the featured egg at LAND
    times, t, gap = [], 0.6, 0.07
    while t < 4.6:
        times.append(t)
        t += gap
        gap *= 1.12
    land = t
    seq = [rng.choice(pool) for _ in times] + [kind]
    times.append(land)
    rar = bubble_layer(rarity, 1330, 120, color)
    inc = bubble_layer("+" + income, 1500, 96, (60, 190, 90))
    odds_l = text_layer(f"{odds}% CHANCE", 1660, 110, WHITE_TXT)
    cues = [(x, "tap", 0.8) for x in times[:-1]] + [(land, "rare", 1.0), (land + 0.05, "open", 0.8),
                                                    (land + 1.2, "coins", 0.7), (CTA_AT, "win", 0.8)]

    def frame(t):
        c = sc.base(t)
        i = max(0, sum(1 for x in times if x <= t) - 1)
        cur = seq[i]
        if t >= land:
            k = (t - land) / 0.5
            flash = max(0, 1 - (t - land) / 0.35)
            glow(c, W / 2, 960, 380, cover.EGGS[kind]["glow"], 0.9)
            place(c, sp[kind], W / 2, 960, int(640 * bounce(k)) or 1, math.sin(t * 5) * 4)
            if flash:
                c.alpha_composite(Image.new("RGBA", (W, H), (255, 255, 255, int(255 * flash))))
            if t > land + 0.3:
                c.alpha_composite(rar)
            if t > land + 1.2:
                c.alpha_composite(inc)
            if t > land + 1.9:
                c.alpha_composite(odds_l)
        else:
            punch = 1 + 0.1 * max(0, 1 - (t - times[i]) / 0.08)
            place(c, sp[cur], W / 2, 960, int(520 * punch), 0)
        overlay(c, hook, alpha=min(1, t / 0.25))
        sc.end_card(c, t)
        return c

    return frame, cues, f"{name}: only {odds}% get it. Could you hatch it?"


def steal(sp, kind, rng):
    """Robber sneaks in, grabs the egg off its pedestal and runs; LOCK YOUR BASE alarm."""
    name, rarity, odds, income, color = FEATURED[kind]
    sc = Scene(sp, kind)
    hook = hook_layers(rng.choice(HOOKS["steal"]).format(name=name))
    alarm = text_layer("LOCK YOUR BASE!", 1600, 130, ((255, 255, 255), (255, 120, 120), (220, 20, 40)), angle=-4)
    tag = bubble_layer(rarity + "  +" + income, 1450, 84, color)
    grab_t, run_t = 3.2, 4.4
    cues = [(1.0, "pop", 0.6), (grab_t, "grab", 1.0), (run_t, "alarm", 0.9), (run_t + 0.9, "alarm", 0.7),
            (CTA_AT, "win", 0.8)]

    def frame(t):
        c = sc.base(t, cy=1000)
        # robber walks in from the left, then runs off right with the egg
        if t < grab_t:
            rx = -300 + (W / 2 - 230 + 300) * ease_out(t / grab_t)
        else:
            rx = W / 2 - 230 + max(0, t - run_t) ** 2 * 900
        bob = abs(math.sin(t * 9)) * 22
        ex, ey = (W / 2 + 60, 1050) if t < grab_t else (rx + 170, 930 - bob)
        if t < grab_t:
            glow(c, ex, ey, 260, cover.EGGS[kind]["glow"], 0.7)
            c.alpha_composite(tag)
        place(c, sp[kind], ex, ey, 420 if t < grab_t else 330, math.sin(t * 6) * 6)
        if rx < W + 300:
            place(c, sp["robber"], rx, 1100 - bob, 560)
        if t > run_t and int(t * 6) % 2 == 0:
            c.alpha_composite(Image.new("RGBA", (W, H), (255, 0, 30, 55)))
        if t > run_t:
            c.alpha_composite(alarm)
        overlay(c, hook, alpha=min(1, t / 0.25))
        sc.end_card(c, t)
        return c

    return frame, cues, f"Someone stole my {name.title()}... lock your base!"


def ranked(sp, kind, rng):
    """Countdown 5 -> 1 of the rarest eggs; the featured egg is always #1 if it's the void egg."""
    order = sorted(FEATURED, key=lambda k: -FEATURED[k][2])
    sc = Scene(sp, "void")
    hook = hook_layers(rng.choice(HOOKS["ranked"]), top=200, size=140)
    rows = []
    for i, k in enumerate(order):
        name, rarity, odds, income, color = FEATURED[k]
        y = 1480 - i * 245  # keeps clear of TikTok's caption area at the bottom
        rows.append((0.9 + i * 1.3, k, y, bubble_layer(f"#{5 - i}", y, 70, color),
                     text_layer(name, y - 40, 74, WHITE_TXT), text_layer(f"{odds}%", y + 50, 60, YELLOW_TXT)))
    cues = [(r[0], "pop" if i < 4 else "rare", 0.9) for i, r in enumerate(rows)] + [(CTA_AT, "win", 0.8)]

    def frame(t):
        c = sc.base(t, cy=900)
        for at, k, y, num, nm, od in rows:
            if t < at:
                continue
            p = bounce((t - at) / 0.4)
            place(c, sp[k], 230, y, int(230 * p) or 1, math.sin(t * 4 + y) * 4)
            dx = int((1 - ease_out((t - at) / 0.3)) * 700)
            for layer, ox in ((nm, 180), (od, 180)):
                c.alpha_composite(layer, (ox + dx, 0))
            c.alpha_composite(num, (-W // 2 + 90, 0))
        overlay(c, hook, alpha=min(1, t / 0.25))
        sc.end_card(c, t)
        return c

    return frame, cues, "Rarest eggs in Steal a Dragon Egg, ranked. Which one do you have?"


TEMPLATES = {"spin": spin, "steal": steal, "ranked": ranked}


def render(template, seed, out_dir):
    rng = random.Random(seed)
    template = template or rng.choice(list(TEMPLATES))
    kind = rng.choice(["dragon", "void", "cosmic", "gold", "dragon", "void"])
    sp = {k: cover.egg_sprite(k) for k in cover.EGGS}
    sp["robber"] = cover.robber_sprite()
    frame, cues, caption = TEMPLATES[template](sp, kind, rng)

    out_dir.mkdir(parents=True, exist_ok=True)
    stem = f"{seed}-{template}-{kind}"
    wav = out_dir / f"{stem}.wav"
    wav.write_bytes(mix(cues))
    mp4 = out_dir / f"{stem}.mp4"
    ff = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
                           "-r", str(FPS), "-i", "-", "-i", str(wav), "-c:v", "libx264", "-preset", "medium", "-crf", "20",
                           "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "160k", "-shortest", "-movflags", "+faststart",
                           str(mp4)], stdin=subprocess.PIPE)
    for f in range(int(DUR * FPS)):
        ff.stdin.write(frame(f / FPS).convert("RGB").tobytes())
    ff.stdin.close()
    if ff.wait():
        raise SystemExit("ffmpeg failed")
    wav.unlink()
    (out_dir / f"{stem}.txt").write_text(f"{caption} {TAGS}\n")
    print(mp4)
    return mp4


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--template", choices=list(TEMPLATES))
    ap.add_argument("--seed", type=int, default=int(datetime.date.today().strftime("%Y%m%d")))
    ap.add_argument("--out", type=pathlib.Path, default=OUT)
    a = ap.parse_args()
    render(a.template, a.seed, a.out)
