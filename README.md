# roblox-game

Games (each in `games/<name>/src`):

- `candy` — Candy Smash Simulator (current, live): themed click sim with zones, combos, offers.
- `clicksim` — original ClickSim, kept for reference.

Per game: `Config.lua` → ReplicatedStorage.Config (set gamepass/product IDs here), `GameServer.server.lua` → ServerScriptService, `Client.client.lua` → StarterPlayerScripts.

Build: `python3 build.py [name]` → `<name>.rbxlx` (default `candy`), published via the Open Cloud Place Publishing API.
