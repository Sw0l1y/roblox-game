# roblox-game

Games (each in `games/<name>/src`):

- `findthe` — Find the Dragon Eggs: 100 hidden eggs across 5 zones, hints, radar, zone gates (own experience).
- `eggs` — Steal a Dragon Egg (current, live): buy eggs off a conveyor, they earn cash in your base, steal other players' eggs.
- `candy` — Candy Smash Simulator: themed click sim with zones, combos, offers.
- `clicksim` — original ClickSim, kept for reference.

Per game: `Config.lua` → ReplicatedStorage.Config (set gamepass/product IDs here), `GameServer.server.lua` → ServerScriptService, `Client.client.lua` → StarterPlayerScripts.

Build: `python3 build.py [name]` → `<name>.rbxlx` (default `eggs`), published via the Open Cloud Place Publishing API.
