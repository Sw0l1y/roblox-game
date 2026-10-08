"""Pack chosen Kenney CC0 sound effects into one audio sprite (one upload, many sounds).

Usage: python3 tools/sfx.py <kenney-dir> [game]  ->  art/sfx/sprite.ogg + art/sfx/sprite.json
With a game name, the clip list comes from art/<game>/sfx/clips.json and output goes to art/<game>/sfx/.
A clip file of "synth:siren" is generated here instead of loaded.
<kenney-dir> holds the unzipped packs from kenney.nl (interface-sounds, casino-audio, impact-sounds,
digital-audio, music-jingles, rpg-audio). All CC0.
"""
import json
import pathlib
import subprocess
import sys

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "art" / "sfx"
SR = 44100
GAP = 0.35  # silence between clips so regions never bleed

# name -> (file name, gain). Gain is applied after peak-normalising to -1 dBFS.
CLIPS = {
    "pop": ("drop_002.ogg", 0.9),            # buttons
    "tap": ("select_002.ogg", 0.7),          # small UI taps
    "open": ("maximize_006.ogg", 0.8),       # panel open
    "offer": ("open_002.ogg", 0.9),          # offer pop-up whoosh
    "toast": ("glass_002.ogg", 0.7),
    "bell": ("impactBell_heavy_000.ogg", 0.8),  # rare egg announced
    "coins": ("handleCoins.ogg", 1.0),       # collect cash
    "chip": ("chips-collide-3.ogg", 0.8),    # coin tick
    "buy": ("powerUp9.ogg", 0.8),            # bought an egg
    "kaching": ("confirmation_001.ogg", 0.8),
    "rare": ("jingles_PIZZI02.ogg", 1.0),    # epic+ egg
    "grab": ("phaserUp4.ogg", 0.8),          # started stealing
    "win": ("jingles_STEEL02.ogg", 1.0),     # steal success
    "alarm": ("zapThreeToneDown.ogg", 0.8),  # your egg got stolen
    "back": ("jingles_NES12.ogg", 0.9),      # got your egg back
    "error": ("error_006.ogg", 0.8),         # not enough cash
    "lock": ("metalLatch.ogg", 1.0),
    "rebirth": ("jingles_HIT15.ogg", 1.0),
    "thanks": ("jingles_PIZZI10.ogg", 1.0),  # purchase thank-you
}


def load(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).copy()


def synth(kind):
    if kind == "siren":  # two rising wails, like an eruption alarm
        t = np.arange(int(SR * 1.8)) / SR
        f = 520 + 420 * (0.5 - 0.5 * np.cos(2 * np.pi * t / 0.9))
        ph = 2 * np.pi * np.cumsum(f) / SR
        x = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.15 * np.sign(np.sin(3 * ph))
        return (x * np.minimum(1, np.minimum(t / 0.05, (t[-1] - t) / 0.2))).astype(np.float32)
    raise ValueError(kind)


def main():
    global OUT, CLIPS
    src = pathlib.Path(sys.argv[1])
    if len(sys.argv) > 2:
        OUT = ROOT / "art" / sys.argv[2] / "sfx"
        CLIPS = {k: tuple(v) for k, v in json.loads((OUT / "clips.json").read_text()).items()}
    files = {p.name: p for p in src.rglob("*.ogg")}
    pieces, regions, t = [np.zeros(int(SR * GAP), np.float32)], {}, GAP
    for name, (fname, gain) in CLIPS.items():
        x = synth(fname[6:]) if fname.startswith("synth:") else load(files[fname])
        x = x / max(1e-6, np.max(np.abs(x))) * 0.89 * gain
        regions[name] = [round(t, 3), round(len(x) / SR, 3)]
        pieces += [x, np.zeros(int(SR * GAP), np.float32)]
        t += len(x) / SR + GAP
    audio = np.concatenate(pieces)
    OUT.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "6", str(OUT / "sprite.ogg")], input=audio.tobytes(), check=True)
    (OUT / "sprite.json").write_text(json.dumps(regions, indent=1))
    print(f"sprite {len(audio) / SR:.1f}s, {len(regions)} clips -> {OUT}")


if __name__ == "__main__":
    main()
