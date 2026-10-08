"""Type-check a game's scripts without Studio (luau-lsp + Roblox type definitions).

Usage: LUAU_LSP=path/to/luau-lsp ROBLOX_DEFS=path/to/globalTypes.d.luau python3 tools/check.py <game>
Writes a Rojo-style sourcemap so require(ReplicatedStorage.Config) etc. resolve, then analyzes every script.
Get the tools from github.com/JohnnyMorganz/luau-lsp releases (luau-lsp-linux-x86_64.zip) and
scripts/globalTypes.None.d.luau in that repo.
"""
import json
import os
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
GAME = sys.argv[1]
SRC = ROOT / "games" / GAME / "src"


def node(name, cls, path=None, children=None):
    n = {"name": name, "className": cls}
    if path:
        n["filePaths"] = [str(path.relative_to(ROOT))]
    if children:
        n["children"] = children
    return n


modules = [node(p.stem, "ModuleScript", p) for p in sorted(SRC.glob("*.lua")) if p.stem.count(".") == 0]
scripts = sorted(SRC.glob("*.server.lua"))
clients = sorted(SRC.glob("*.client.lua"))
tree = node("Game", "DataModel", children=[
    node("ReplicatedStorage", "ReplicatedStorage", children=modules),
    node("ServerScriptService", "ServerScriptService", children=[node(p.name.split(".")[0], "Script", p) for p in scripts]),
    node("StarterPlayer", "StarterPlayer", children=[node("StarterPlayerScripts", "StarterPlayerScripts",
                                                          children=[node(p.name.split(".")[0], "LocalScript", p) for p in clients])]),
])
with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
    json.dump(tree, f)
files = [str(p.relative_to(ROOT)) for p in scripts + clients + [SRC / "Config.lua"]]
r = subprocess.run([os.environ["LUAU_LSP"], "analyze", f"--sourcemap={f.name}", f"--definitions={os.environ['ROBLOX_DEFS']}",
                    *files], cwd=ROOT, capture_output=True, text=True)
out = [line for line in (r.stdout + r.stderr).splitlines() if not line.startswith("[INFO]")]
print("\n".join(out) or "clean")
sys.exit(1 if any("Error" in line for line in out) else 0)
