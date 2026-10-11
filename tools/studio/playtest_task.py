"""Write PC Studio worker tasks that open a built game, play it and take screenshots.

Usage: python3 tools/studio/playtest_task.py <game> <seq> <out_inbox_dir>
Writes <seq>a-open-<game>.json and <seq>b-play-<game>.json. Camera positions come from the sim's world.json
(where the tester stood after joining), so run tools/sim/run.mjs <game> first.
"""
import json
import pathlib
import sys

game, seq, out = sys.argv[1], sys.argv[2], pathlib.Path(sys.argv[3])
world = json.loads(pathlib.Path(f"/mnt/project-files/rbx5/sim/{game}/world.json").read_text())
cam = world["cams"].get("join") or world["cams"].get("spawn")
px, py, pz = cam[0], cam[1], cam[2]
lx, lz = -cam[5], -cam[11]
n = max(1e-6, (lx * lx + lz * lz) ** 0.5)
lx, lz = lx / n, lz / n


def at(back, up, ahead, lift=0.0):
    eye = [px - lx * back, py + up, pz - lz * back]
    target = [px + lx * ahead, py + lift, pz + lz * ahead]
    return eye, target


def cap(name, eye=None, target=None):
    a = {"studio_id": "AUTO", "capture_id": f"ScreenCapture_{game}_{name}"}
    if eye:
        a["camera_position"], a["look_at_position"] = [round(v, 2) for v in eye], [round(v, 2) for v in target]
    return {"name": "screen_capture", "timeout": 90, "arguments": a, "save": f"{game}-{name}"}


def luau(code, dm="Server", t=90):
    return {"name": "execute_luau", "timeout": t, "arguments": {"studio_id": "AUTO", "datamodel_type": dm, "code": code}}


debug = 'local f = game:GetService("ServerStorage"):FindFirstChild("DebugCmd") if not f then return "no DebugCmd" end return tostring(f:Invoke(%s))'
hero_eye, hero_t = at(26, 11, 40, 2)
over_eye, over_t = at(150, 120, 60)
calls = [
    {"name": "get_studio_state", "arguments": {"studio_id": "AUTO"}},
    {"name": "start_stop_play", "timeout": 120, "arguments": {"studio_id": "AUTO", "is_start": True}},
    luau("task.wait(14) return 'joined'"),
    cap("1-join"),
    cap("2-hero", hero_eye, hero_t),
    cap("3-overview", over_eye, over_t),
    luau(debug % json.dumps("give 1000000")),
    luau(debug % json.dumps("event")),
    luau("task.wait(12) return 'event'"),
    cap("4-event"),
    luau(debug % json.dumps("state")),
    {"name": "get_console_output", "timeout": 60, "arguments": {"studio_id": "AUTO"}},
    {"name": "start_stop_play", "timeout": 120, "arguments": {"studio_id": "AUTO", "is_start": False}},
]
out.mkdir(parents=True, exist_ok=True)
(out / f"{seq}a-open-{game}.json").write_text(json.dumps({"kind": "open", "place": f"{game}.rbxlx", "closeOurs": True}))
(out / f"{seq}b-play-{game}.json").write_text(json.dumps({"kind": "mcp", "match": game, "timeoutSec": 1800, "calls": calls}, indent=1))
print("wrote", seq, game)
