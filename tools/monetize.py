"""Create a game's passes and dev products via Open Cloud and write their IDs into Config.lua.

Usage: ROBLOX_API_KEY_FILE=path python3 tools/monetize.py <game>
Reads games/<game>/game.json (universeId) and every `{ Key = ..., Name = ..., Desc = ..., Price = n, Id = 0 ... }` line
in games/<game>/src/Config.lua. Lines inside Config.GamePasses become passes, inside Config.Products dev products.
Only entries with Id = 0 are created, so re-running is safe. Uses art/<game>/icons/<Img>.png as the item image if present.
`python3 tools/monetize.py <game> images` instead re-uploads the image of every already-created item (after new art lands).
"""
import json
import os
import pathlib
import re
import sys
import urllib.request
import uuid

ROOT = pathlib.Path(__file__).resolve().parent.parent
GAME = sys.argv[1]
KEY = pathlib.Path(os.environ["ROBLOX_API_KEY_FILE"]).read_text().strip()
META = json.loads((ROOT / "games" / GAME / "game.json").read_text())
CONFIG = ROOT / "games" / GAME / "src" / "Config.lua"
ICONS = ROOT / "art" / GAME / "icons"


def field(line, name):
    m = re.search(name + r'\s*=\s*("([^"]*)"|(\d+))', line)
    return None if not m else (m.group(2) if m.group(2) is not None else int(m.group(3)))


def create(kind, line, item_id=None):
    url = (f"https://apis.roblox.com/game-passes/v1/universes/{META['universeId']}/game-passes" if kind == "pass" else
           f"https://apis.roblox.com/developer-products/v2/universes/{META['universeId']}/developer-products")
    fields = {"name": field(line, "Name"), "description": field(line, "Desc"), "price": str(field(line, "Price")),
              "isForSale": "true"}
    if item_id:
        url += f"/{item_id}"
        fields = {}
    boundary = uuid.uuid4().hex
    body = b""
    for k, v in fields.items():
        body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n".encode()
    img = ICONS / f"{field(line, 'Img')}.png"
    if img.exists():
        body += (f"--{boundary}\r\nContent-Disposition: form-data; name=\"imageFile\"; filename=\"{img.name}\"\r\n"
                 f"Content-Type: image/png\r\n\r\n").encode() + img.read_bytes() + b"\r\n"
    body += f"--{boundary}--\r\n".encode()
    req = urllib.request.Request(url, data=body, method="PATCH" if item_id else "POST",
                                 headers={"x-api-key": KEY, "Content-Type": f"multipart/form-data; boundary={boundary}"})
    with urllib.request.urlopen(req) as r:
        raw = r.read()
    if item_id:
        return item_id
    out = json.loads(raw)
    return out["gamePassId" if kind == "pass" else "productId"]


lines = CONFIG.read_text().split("\n")
section = None
for i, line in enumerate(lines):
    if line.startswith("Config.GamePasses"):
        section = "pass"
    elif line.startswith("Config.Products"):
        section = "product"
    elif line.startswith("}"):
        section = None
    elif section and "Key =" in line and len(sys.argv) > 2 and sys.argv[2] == "images" and field(line, "Id"):
        create(section, line, field(line, "Id"))
        print("image set", section, field(line, "Key"))
    elif section and "Key =" in line and re.search(r"Id = 0\b", line):
        new_id = create(section, line)
        lines[i] = re.sub(r"Id = 0\b", f"Id = {new_id}", line)
        CONFIG.write_text("\n".join(lines))
        print("created", section, field(line, "Key"), new_id)
