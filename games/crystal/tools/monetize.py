"""Create Crystal Garden's game passes and developer products (Open Cloud) and write their IDs into Config.lua.

Usage: ROBLOX_API_KEY_FILE=path python3 games/crystal/tools/monetize.py <universeId>
Only entries with Id = 0 are created; their icon (art/icons/<Img>.png) is used as the thumbnail when present.
"""
import json
import os
import pathlib
import re
import sys
import urllib.request
import uuid

GAME = pathlib.Path(__file__).resolve().parents[1]
CONFIG = GAME / "src" / "Config.lua"
KEY = pathlib.Path(os.environ["ROBLOX_API_KEY_FILE"]).read_text().strip()
UNIVERSE = sys.argv[1]


def create(kind, name, desc, price, img):
    boundary = uuid.uuid4().hex
    fields = {"name": name, "description": desc, "price": str(price), "isForSale": "true"}
    body = b""
    for k, v in fields.items():
        body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n".encode()
    if img.exists():
        body += (f"--{boundary}\r\nContent-Disposition: form-data; name=\"imageFile\"; filename=\"{img.name}\"\r\n"
                 f"Content-Type: image/png\r\n\r\n").encode() + img.read_bytes() + b"\r\n"
    body += f"--{boundary}--\r\n".encode()
    path = "game-passes/v1/universes/{u}/game-passes" if kind == "Pass" else "developer-products/v2/universes/{u}/developer-products"
    req = urllib.request.Request(f"https://apis.roblox.com/{path.format(u=UNIVERSE)}", data=body, method="POST",
                                 headers={"x-api-key": KEY, "Content-Type": f"multipart/form-data; boundary={boundary}"})
    with urllib.request.urlopen(req) as r:
        out = json.loads(r.read())
    return out.get("gamePassId") or out.get("productId") or out.get("id")


src = CONFIG.read_text()
row = re.compile(r'\{ Key = "(\w+)", Img = "(\w+)", Name = "([^"]+)", Icon = "[^"]*", Desc = "([^"]+)", Price = (\d+), Id = 0')
section = None
lines = src.split("\n")
for i, line in enumerate(lines):
    if line.startswith("Config.GamePasses"):
        section = "Pass"
    elif line.startswith("Config.Products"):
        section = "Product"
    elif line.startswith("}"):
        section = None
    m = row.search(line)
    if section and m:
        key, img, name, desc, price = m.groups()
        new_id = create(section, name, desc, int(price), GAME / "art" / "icons" / f"{img}.png")
        lines[i] = line.replace("Id = 0", f"Id = {new_id}", 1)
        print(section, key, new_id)
        CONFIG.write_text("\n".join(lines))
print("done")
