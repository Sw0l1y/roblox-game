"""Run a game's server script on a real headless Roblox server (Open Cloud Luau Execution) and report errors.

Usage: ROBLOX_API_KEY_FILE=path python3 tools/live_test.py <game>
Publish first (tools/publish.py). Execution sessions don't start the place's own scripts, so this inlines
GameServer.server.lua into the task, waits for one full lava/whatever cycle (60s max), and returns world stats
plus every error/warning logged. Needs the key scope universe.place.luau-execution-session write.
"""
import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
GAME = sys.argv[1]
KEY = pathlib.Path(os.environ["ROBLOX_API_KEY_FILE"]).read_text().strip()
META = json.loads((ROOT / "games" / GAME / "game.json").read_text())
SRC = (ROOT / "games" / GAME / "src" / "GameServer.server.lua").read_text()

PROBE = """local errs = {}
game:GetService("LogService").MessageOut:Connect(function(m, t)
	if t == Enum.MessageType.MessageError or t == Enum.MessageType.MessageWarning then table.insert(errs, m) end
end)
local ok, err = pcall(function()
""" + SRC + """
end)
if not ok then table.insert(errs, "TOP: " .. tostring(err)) end
task.wait(60)
local w = workspace:FindFirstChild("World")
return { parts = w and #w:GetDescendants() or 0, errs = errs }
"""


def call(method, url, body=None):
    req = urllib.request.Request(url, data=json.dumps(body).encode() if body else None, method=method,
                                 headers={"x-api-key": KEY, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        sys.exit(f"{e.code} {e.read().decode()[:400]}")


base = f"https://apis.roblox.com/cloud/v2/universes/{META['universeId']}/places/{META['placeId']}"
task = call("POST", base + "/luau-execution-session-tasks", {"script": PROBE, "timeout": "180s"})
for _ in range(100):
    time.sleep(3)
    task = call("GET", "https://apis.roblox.com/cloud/v2/" + task["path"])
    if task["state"] in ("COMPLETE", "FAILED", "CANCELLED"):
        break
print(task["state"], json.dumps(task.get("output") or task.get("error"), indent=1))
