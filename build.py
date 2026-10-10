"""Build games/<name> into <name>.rbxlx.  Usage: python3 build.py <name>

Layout (every game = the shared kit + its own modules):
  kit/shared/*.lua,    games/<name>/shared/*.lua  -> ReplicatedStorage.Shared   (ModuleScripts)
  kit/client/*.lua,    games/<name>/client/*.lua  -> ReplicatedStorage.ClientLib (ModuleScripts)
  kit/server/*.lua,    games/<name>/server/*.lua  -> ServerScriptService.Lib   (ModuleScripts)
  games/<name>/server/Main.server.lua             -> ServerScriptService.Main  (Script)
  games/<name>/client/Main.client.lua             -> StarterPlayerScripts.Main (LocalScript)
  kit/materials.json + games/<name>/materials.json -> MaterialService MaterialVariants (our generated textures;
                                                      their maps are plugin-only properties, so they live in the file)
A game file overrides a kit file with the same name.
"""
import json
import pathlib
import sys
from xml.sax.saxutils import escape

ROOT = pathlib.Path(__file__).resolve().parent
MATERIAL = {'Plastic': 256, 'Wood': 512, 'Slate': 800, 'Concrete': 816, 'CorrodedMetal': 1040, 'DiamondPlate': 1056,
            'Foil': 1072, 'Grass': 1280, 'Ice': 1536, 'Marble': 784, 'Granite': 832, 'Brick': 848, 'Pebble': 864,
            'Sand': 1296, 'Fabric': 1312, 'SmoothPlastic': 272, 'Metal': 1088, 'WoodPlanks': 528, 'Cobblestone': 880,
            'Rock': 896, 'Glacier': 1552, 'Snow': 1328, 'Sandstone': 912, 'Mud': 1344, 'Basalt': 788, 'Ground': 1360,
            'CrackedLava': 804, 'Neon': 288, 'Glass': 1568, 'Asphalt': 1376, 'LeafyGrass': 1284, 'Salt': 1392,
            'Limestone': 820, 'Pavement': 836, 'Cardboard': 2304, 'Carpet': 2305, 'CeramicTiles': 2306,
            'ClayRoofTiles': 2307, 'RoofShingles': 2308, 'Leather': 2309, 'Plaster': 2310, 'Rubber': 2311}


class Doc:
    def __init__(self):
        self.ref = 0

    def item(self, cls, name, children="", props=""):
        self.ref += 1
        return (f'<Item class="{cls}" referent="RBX{self.ref}"><Properties><string name="Name">{escape(name)}</string>'
                f'{props}</Properties>{children}</Item>')

    def script(self, cls, name, source):
        src = source.replace("]]>", "]]]]><![CDATA[>")
        return self.item(cls, name, props=f'<ProtectedString name="Source"><![CDATA[{src}]]></ProtectedString>')


def modules(*dirs):
    """name -> path for every plain module (not .server/.client) in dirs; later dirs override earlier ones."""
    out = {}
    for d in dirs:
        if d.is_dir():
            for p in sorted(d.glob("*.lua")):
                if p.name.count(".") == 1:
                    out[p.stem] = p
    return out


def material_variants(doc, game_dir):
    mats = {}
    for f in (ROOT / "kit" / "materials.json", game_dir / "materials.json"):
        if f.exists():
            mats.update({k: v for k, v in json.loads(f.read_text()).items() if not k.startswith("_")})
    out = ""
    for name, m in list(mats.items()):
        if not m.get("color"):  # still waiting for its generated maps: World.texture falls back to flat colour
            del mats[name]
            continue
        props = f'<token name="BaseMaterial">{MATERIAL[m["base"]]}</token>'
        for key, prop in (("color", "ColorMap"), ("normal", "NormalMap"), ("roughness", "RoughnessMap"), ("metalness", "MetalnessMap")):
            if m.get(key):
                props += f'<Content name="{prop}"><url>rbxassetid://{m[key]}</url></Content>'
        props += f'<float name="StudsPerTile">{m.get("studsPerTile", 16)}</float>'
        props += f'<token name="MaterialPattern">{1 if m.get("pattern") == "Organic" else 0}</token>'
        out += doc.item("MaterialVariant", name, props=props)
    return out, mats


def build(game):
    gdir = ROOT / "games" / game
    if not gdir.is_dir():
        sys.exit(f"no such game: {gdir}")
    doc = Doc()
    read = lambda p: p.read_text(encoding="utf-8")
    shared = modules(ROOT / "kit" / "shared", gdir / "shared")
    client = modules(ROOT / "kit" / "client", gdir / "client")
    server = modules(ROOT / "kit" / "server", gdir / "server")
    main_server = gdir / "server" / "Main.server.lua"
    main_client = gdir / "client" / "Main.client.lua"
    variants, mats = material_variants(doc, gdir)
    meta = json.loads(read(gdir / "game.json")) if (gdir / "game.json").exists() else {}

    rs = doc.item("Folder", "Shared", "".join(doc.script("ModuleScript", n, read(p)) for n, p in shared.items()))
    rs += doc.item("Folder", "ClientLib", "".join(doc.script("ModuleScript", n, read(p)) for n, p in client.items()))
    sss = doc.item("Folder", "Lib", "".join(doc.script("ModuleScript", n, read(p)) for n, p in server.items()))
    sss += doc.script("Script", "Main", read(main_server))
    sps = doc.script("LocalScript", "Main", read(main_client))

    xml = "".join([
        '<roblox xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="4">',
        doc.item("Workspace", "Workspace"),
        doc.item("Lighting", "Lighting"),
        doc.item("MaterialService", "MaterialService", variants, props='<bool name="Use2022Materials">true</bool>'),
        doc.item("ReplicatedStorage", "ReplicatedStorage", rs),
        doc.item("ServerScriptService", "ServerScriptService", sss),
        doc.item("StarterPlayer", "StarterPlayer", doc.item("StarterPlayerScripts", "StarterPlayerScripts", sps),
                 props=f'<float name="CharacterWalkSpeed">{meta.get("walkSpeed", 20)}</float>'
                       f'<float name="CharacterJumpPower">{meta.get("jumpPower", 50)}</float>'),
        "</roblox>",
    ])
    out = ROOT / f"{game}.rbxlx"
    out.write_text(xml, encoding="utf-8")
    print(f"built {out.name}: {len(xml)} bytes, {len(shared)} shared, {len(client)} client, {len(server)} server modules, "
          f"{len(mats)} material variants")
    return out


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    for g in sys.argv[1:]:
        build(g)
