"""Write generated asset ids from the PC Studio worker's results into the games.

Usage: python3 tools/studio/apply_ids.py <results.json> [<results.json> ...]
- generate_material results + the MaterialService dump (lines "Name|Base|ColorMap|NormalMap|RoughnessMap|MetalnessMap|...")
  fill games/<g>/materials.json entries whose "color" is null, using the alternate named in PICKS; "STAT|Name|..|r,g,b"
  lines from the measure task set its "preview" (on-screen average colour, used by World.texture to tint correctly).
- mesh dumps (lines "MESH|game.Key|MeshId|TextureID|...") fill Config.Meshes <Key> mesh/texture ids in
  games/<game>/shared/Config.lua. Keys listed in TINT_ONLY keep texture = 0 (the game colours them).
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
GAMES = ["rocket", "toyarmy", "marbles", "balloons", "cake"]
# meshes the game recolours (team colours, balloon tints): a texture would hide Part.Color
TINT_ONLY = {"marbles.Marble", "toyarmy.Rifleman", "toyarmy.Bazooka", "toyarmy.Medic", "toyarmy.Tank", "toyarmy.Heli", "toyarmy.General",
             "toyarmy.Dino", "balloons.balloon"}


# generate_material makes Name plus alternates Name1..Name3. The pick per material comes from the 006-measure task
# (each colour map's average colour, noise and blotchiness) and a look at the swatches; SKIP keeps the flat palette.
PICKS = {"MoonDust": "MoonDust2", "MarsSoil": "MarsSoil1", "EuropaIce": "EuropaIce3", "ToyFloorWood": "ToyFloorWood2",
         "ToyRugCarpet": "ToyRugCarpet3", "ToyBlanket": "ToyBlanket2", "MarbleTableTop": "MarbleTableTop1",
         "MarbleFeltMat": "MarbleFeltMat", "CandyFrosting": "CandyFrosting3", "CloudFluff": "CloudFluff",
         "StarDust": "StarDust1", "CakeStreet": "CakeStreet2"}
SKIP = {"CakeTile": "no checker came out (irregular paving); the plaza keeps its checker of parts",
        "CakeWood": "all four came out dark and busy; booths keep flat honey wood"}
# A texture looks about this much brighter on screen than its raw average (calibrated on the house variants).
LOOK = 1.2


def num(s):
    m = re.search(r"(\d{6,})", s or "")
    return int(m.group(1)) if m else None


def mesh_prompts():
    """prompt -> "game.Key" for every Config.Meshes entry."""
    out = {}
    for g in GAMES:
        src = (ROOT / "games" / g / "shared" / "Config.lua").read_text()
        if "Config.Meshes = {" not in src:
            continue
        start = src.index("Config.Meshes = {")
        block = src[start:src.index("\n}", start)]
        heads = list(re.finditer(r"\n\t(\w+)\s*=\s*\{", block))
        for i, m in enumerate(heads):
            body = block[m.end(): heads[i + 1].start() if i + 1 < len(heads) else len(block)]
            pm = re.search(r'prompt\s*=\s*"([^"]*)"', body)
            if pm:
                out[pm.group(1)] = f"{g}.{m.group(1)}"
    return out


def texts(path):
    """All result texts in order. A MESH line takes its key from the prompt of the generate_mesh call before it
    (the key written into the task can be wrong; the prompt is what was generated)."""
    raw = pathlib.Path(path).read_bytes().decode("utf-8-sig")
    prompts = mesh_prompts()
    out = []
    last = None
    for rec in json.loads(raw):
        for t in rec.get("texts") or []:
            if rec.get("name") == "generate_mesh":
                try:
                    last = prompts.get(json.loads(t).get("generationName"))
                except ValueError:
                    last = None
            elif last and t.startswith("MESH|"):
                f = t.split("|")
                f[1] = last
                t = "|".join(f)
                last = None
            out.append(t)
    return out


def apply_materials(lines):
    variants, means = {}, {}
    for line in lines:
        f = line.split("|")
        if f[0] == "STAT" and len(f) > 3 and f[3].count(",") == 2:
            means[f[1]] = [int(c) for c in f[3].split(",")]
        elif len(f) >= 6 and num(f[2]):
            variants.setdefault(f[0], {"color": num(f[2]), "normal": num(f[3]), "roughness": num(f[4]), "metalness": num(f[5])})
    done = []
    for g in GAMES:
        p = ROOT / "games" / g / "materials.json"
        d = json.loads(p.read_text())
        changed = False
        for k, v in d.items():
            if k.startswith("_") or v.get("color"):
                continue
            if k in SKIP:
                if v.get("skip") != SKIP[k]:
                    v["skip"] = SKIP[k]
                    changed = True
                continue
            src = PICKS.get(k, k)
            if src not in variants:
                continue
            v.update({kk: vv for kk, vv in variants[src].items() if vv})
            if src in means:
                v["preview"] = [min(255, round(c * LOOK)) for c in means[src]]
            v["variant"] = src
            changed = True
            done.append(f"{g}.{k}={src}")
        if changed:
            p.write_text(json.dumps(d, indent=2) + "\n")
    return done


def apply_meshes(lines):
    done = []
    for line in lines:
        f = line.split("|")
        if len(f) < 4 or f[0] != "MESH":
            continue
        g, key = f[1].split(".", 1)
        mesh, tex = num(f[2]) or num(f[4] if len(f) > 4 else ""), num(f[3]) or num(f[5] if len(f) > 5 else "")
        if not mesh:
            continue
        if f[1] in TINT_ONLY:
            tex = 0
        p = ROOT / "games" / g / "shared" / "Config.lua"
        src = p.read_text()
        start = src.index("Config.Meshes = {")
        end = src.index("\n}", start)
        block = src[start:end]
        m = re.search(r"(\b%s\s*=\s*\{)(.*?)(\n\t\}|\})" % re.escape(key), block, re.S)
        if not m:
            print("no Config.Meshes entry for", f[1])
            continue
        body = m.group(2)
        body = re.sub(r"mesh\s*=\s*\d+", f"mesh = {mesh}", body, count=1)
        body = re.sub(r"texture\s*=\s*\d+", f"texture = {tex or 0}", body, count=1)
        block = block[: m.start(2)] + body + block[m.end(2):]
        p.write_text(src[:start] + block + src[end:])
        done.append(f"{f[1]} mesh={mesh} texture={tex or 0}")
    return done


if __name__ == "__main__":
    lines = []
    for path in sys.argv[1:]:
        for t in texts(path):
            lines.extend(t.splitlines())
    print("materials:", apply_materials(lines))
    for d in apply_meshes(lines):
        print("mesh:", d)
