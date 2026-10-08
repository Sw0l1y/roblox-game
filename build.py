"""Build a place file from games/<name>/src. Usage: python3 build.py [name] (default: eggs)."""
import pathlib
import sys

ROOT = pathlib.Path(__file__).parent
GAME = sys.argv[1] if len(sys.argv) > 1 else "eggs"
SRC = ROOT / "games" / GAME / "src"
ref = 0

def item(cls, name, children="", source=None):
    global ref
    ref += 1
    props = f'<string name="Name">{name}</string>'
    if source is not None:
        props += f'<ProtectedString name="Source"><![CDATA[{source}]]></ProtectedString>'
    return f'<Item class="{cls}" referent="RBX{ref}"><Properties>{props}</Properties>{children}</Item>'

src = lambda f: (SRC / f).read_text(encoding="utf-8")
doc = "".join([
    '<roblox xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="4">',
    item("Workspace", "Workspace"),
    item("ReplicatedStorage", "ReplicatedStorage", item("ModuleScript", "Config", source=src("Config.lua"))),
    item("ServerScriptService", "ServerScriptService", item("Script", "GameServer", source=src("GameServer.server.lua"))),
    item("StarterPlayer", "StarterPlayer",
         item("StarterPlayerScripts", "StarterPlayerScripts", item("LocalScript", "Client", source=src("Client.client.lua")))),
    "</roblox>",
])
out = ROOT / f"{GAME}.rbxlx"
out.write_text(doc, encoding="utf-8")
print("built", out.name, len(doc), "bytes")
