"""Crystal Garden sound sprite: reuses tools/sfx.py with its own clip list.

Usage: python3 games/crystal/tools/sfx.py <kenney-dir>  ->  games/crystal/art/sfx/sprite.ogg + sprite.json (Kenney CC0)
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))
import sfx  # noqa: E402

sfx.OUT = ROOT / "games" / "crystal" / "art" / "sfx"
sfx.CLIPS = {
    "pop": ("drop_003.ogg", 0.9),                 # buttons
    "tap": ("select_005.ogg", 0.7),
    "open": ("maximize_003.ogg", 0.8),            # panel open / teleport
    "offer": ("open_004.ogg", 0.9),
    "toast": ("glass_005.ogg", 0.7),
    "bell": ("impactBell_heavy_002.ogg", 0.8),    # server announcement
    "coins": ("handleCoins2.ogg", 1.0),
    "chip": ("chips-stack-2.ogg", 0.8),
    "kaching": ("confirmation_003.ogg", 0.8),
    "plant": ("impactSoft_medium_002.ogg", 1.0),  # seed goes in the soil
    "seed": ("pluck_002.ogg", 0.9),               # bought a seed
    "harvest": ("impactGlass_light_002.ogg", 1.0),
    "ripe": ("glass_003.ogg", 0.8),
    "rare": ("jingles_STEEL06.ogg", 1.0),
    "sell": ("jingles_PIZZI05.ogg", 1.0),
    "mutate": ("phaserUp6.ogg", 0.8),
    "event": ("jingles_HIT03.ogg", 1.0),          # weather event starts
    "thunder": ("lowFrequency_explosion_001.ogg", 1.0),
    "meteor": ("explosionCrunch_002.ogg", 0.9),
    "expand": ("powerUp11.ogg", 0.9),
    "error": ("error_004.ogg", 0.8),
    "thanks": ("jingles_NES05.ogg", 1.0),
    "dig": ("impactMining_001.ogg", 1.0),
    "restock": ("twoTone2.ogg", 0.8),
}

if __name__ == "__main__":
    sfx.main()
