"""Build and publish a game to its own place via the Open Cloud Place Publishing API.

Usage: ROBLOX_API_KEY_FILE=path python3 tools/publish.py <game>
games/<game>/game.json holds {"universeId": ..., "placeId": ...}. A 409 "Server is busy" means the place is open in
Studio with Team Create on: close it there and retry.
"""
import json
import os
import pathlib
import subprocess
import sys
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
GAME = sys.argv[1]
KEY = pathlib.Path(os.environ["ROBLOX_API_KEY_FILE"]).read_text().strip()
META = json.loads((ROOT / "games" / GAME / "game.json").read_text())

subprocess.run([sys.executable, str(ROOT / "build.py"), GAME], check=True)
data = (ROOT / f"{GAME}.rbxlx").read_bytes()
url = (f"https://apis.roblox.com/universes/v1/{META['universeId']}/places/{META['placeId']}/versions"
       "?versionType=Published")
req = urllib.request.Request(url, data=data, method="POST", headers={"x-api-key": KEY, "Content-Type": "application/xml"})
try:
    with urllib.request.urlopen(req) as r:
        print("published version", json.loads(r.read())["versionNumber"])
except urllib.error.HTTPError as e:
    sys.exit(f"publish failed {e.code}: {e.read().decode()[:300]}")
