"""Launch a built game on its own experience through Open Cloud.

Usage: python3 tools/launch.py <game> <step>...    steps: publish, monetize, meta, all
The API key comes from ROBLOX_API_KEY or the file named by ROBLOX_API_KEY_FILE (never commit it).
games/<game>/game.json holds the experience: {"universeId", "placeId", "name", "description", "privateServerPrice"}.

- publish:  build.py <game>, then upload the place as a Published version (409 = place open in Team Create).
- monetize: create every Config.Passes / Config.Products line in games/<game>/shared/Config.lua that still has
            `id = 0`, then write the new id into that line. Re-running only creates what is missing. Uses
            art/<game>/shop/<Key>.png as the item image when present. Publish again afterwards.
- meta:     set the start place's display name and description, and the private server price.
- all:      monetize, meta, publish.
"""
import json
import os
import pathlib
import re
import subprocess
import sys
import urllib.error
import urllib.request
import uuid

ROOT = pathlib.Path(__file__).resolve().parent.parent
API = "https://apis.roblox.com"


def key() -> str:
    if os.environ.get("ROBLOX_API_KEY"):
        return os.environ["ROBLOX_API_KEY"].strip()
    if os.environ.get("ROBLOX_API_KEY_FILE"):
        return pathlib.Path(os.environ["ROBLOX_API_KEY_FILE"]).read_text().strip()
    sys.exit("set ROBLOX_API_KEY or ROBLOX_API_KEY_FILE")


class ApiError(Exception):
    def __init__(self, code: int, text: str):
        super().__init__(f"{code}: {text}")
        self.code, self.text = code, text


def call(method: str, url: str, body: bytes | None = None, ctype: str | None = None) -> dict:
    headers = {"x-api-key": key()}
    if ctype:
        headers["Content-Type"] = ctype
    req = urllib.request.Request(url, data=body, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
    except urllib.error.HTTPError as e:
        raise ApiError(e.code, e.read().decode()[:400]) from None
    return json.loads(raw) if raw.strip() else {}


def multipart(fields: dict, image: pathlib.Path | None) -> tuple[bytes, str]:
    boundary = uuid.uuid4().hex
    body = b""
    for k, v in fields.items():
        body += f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode()
    if image and image.exists():
        body += (f'--{boundary}\r\nContent-Disposition: form-data; name="imageFile"; filename="{image.name}"\r\n'
                 "Content-Type: image/png\r\n\r\n").encode() + image.read_bytes() + b"\r\n"
    body += f"--{boundary}--\r\n".encode()
    return body, f"multipart/form-data; boundary={boundary}"


def field(line: str, name: str):
    m = re.search(r"\b" + name + r'\s*=\s*("((?:[^"\\]|\\.)*)"|(\d+))', line)
    return None if not m else (m.group(2) if m.group(2) is not None else int(m.group(3)))


def publish(game: str, meta: dict):
    subprocess.run([sys.executable, str(ROOT / "build.py"), game], check=True)
    data = (ROOT / f"{game}.rbxlx").read_bytes()
    url = f"{API}/universes/v1/{meta['universeId']}/places/{meta['placeId']}/versions?versionType=Published"
    print(game, "published version", call("POST", url, data, "application/xml")["versionNumber"])


def monetize(game: str, meta: dict):
    config = ROOT / "games" / game / "shared" / "Config.lua"
    lines = config.read_text().split("\n")
    section = None
    for i, line in enumerate(lines):
        if line.startswith("Config.Passes"):
            section = "pass"
        elif line.startswith("Config.Products"):
            section = "product"
        elif line.startswith("}"):
            section = None
        elif section and re.search(r"\bid = 0\b", line):
            item = line.strip().split(" ", 1)[0]
            fields = {"name": field(line, "name"), "description": field(line, "desc") or "",
                      "price": str(field(line, "price")), "isForSale": "true",
                      "isRegionalPricingEnabled": "true"}  # regional pricing: more payers at the same top price
            url = (f"{API}/game-passes/v1/universes/{meta['universeId']}/game-passes" if section == "pass" else
                   f"{API}/developer-products/v2/universes/{meta['universeId']}/developer-products")
            image = ROOT / "art" / game / "shop" / f"{item}.png"
            try:
                out = call("POST", url, *multipart(fields, image))
            except ApiError as e:
                if e.code != 400 or "egional" not in e.text:
                    raise
                print(game, "regional pricing not accepted by the API, creating", item, "without it")
                del fields["isRegionalPricingEnabled"]
                out = call("POST", url, *multipart(fields, image))
            new_id = out["gamePassId" if section == "pass" else "productId"]
            lines[i] = re.sub(r"\bid = 0\b", f"id = {new_id}", line, count=1)
            config.write_text("\n".join(lines))  # after every item, so a failure halfway loses nothing
            print(game, "created", section, item, new_id)


def set_meta(game: str, meta: dict):
    place = {"displayName": meta["name"], "description": meta["description"]}
    call("PATCH", f"{API}/cloud/v2/universes/{meta['universeId']}/places/{meta['placeId']}"
         "?updateMask=displayName,description", json.dumps(place).encode(), "application/json")
    if meta.get("privateServerPrice") is not None:
        call("PATCH", f"{API}/cloud/v2/universes/{meta['universeId']}?updateMask=privateServerPriceRobux",
             json.dumps({"privateServerPriceRobux": meta["privateServerPrice"]}).encode(), "application/json")
    print(game, "name/description/private servers set")


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    game, steps = sys.argv[1], sys.argv[2:]
    meta = json.loads((ROOT / "games" / game / "game.json").read_text())
    if not meta.get("universeId") or not meta.get("placeId"):
        sys.exit(f"{game}: no experience yet (universeId/placeId empty in game.json)")
    if "all" in steps:
        steps = ["monetize", "meta", "publish"]
    for step in steps:
        try:
            {"publish": publish, "monetize": monetize, "meta": set_meta}[step](game, meta)
        except ApiError as e:
            sys.exit(f"{game} {step} failed {e}")


if __name__ == "__main__":
    main()
