"""Build ClickSim.rbxlx from src/."""
import pathlib

ROOT = pathlib.Path(__file__).parent
ref = 0

def item(cls, name, children="", source=None):
    global ref
    ref += 1
    props = f'<string name="Name">{name}</string>'
    if source is not None:
        props += f'<ProtectedString name="Source"><![CDATA[{source}]]></ProtectedString>'
    return f'<Item class="{cls}" referent="RBX{ref}"><Properties>{props}</Properties>{children}</Item>'

src = lambda f: (ROOT / "src" / f).read_text()
doc = "".join([
    '<roblox xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="4">',
    item("Workspace", "Workspace"),
    item("ReplicatedStorage", "ReplicatedStorage", item("ModuleScript", "Config", source=src("Config.lua"))),
    item("ServerScriptService", "ServerScriptService", item("Script", "GameServer", source=src("GameServer.server.lua"))),
    item("StarterPlayer", "StarterPlayer",
         item("StarterPlayerScripts", "StarterPlayerScripts", item("LocalScript", "Client", source=src("Client.client.lua")))),
    "</roblox>",
])
(ROOT / "ClickSim.rbxlx").write_text(doc, encoding="utf-8")
print("built", len(doc), "bytes")
