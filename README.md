# roblox-game

Games (each in `games/<name>/src`):

- `eggs` — Steal a Dragon Egg (current, live): buy eggs off a conveyor, they earn cash in your base, steal other players' eggs.
- `crystal` — Grow a Crystal Garden: buy seeds, plant them, crystals grow in real time (even offline), harvest and sell; server-wide weather events mutate crystals (Gold, Frozen, Charged, Cosmic, Rainbow). Art/sound tools in `games/crystal/tools`.
- `candy` — Candy Smash Simulator: themed click sim with zones, combos, offers.
- `clicksim` — original ClickSim, kept for reference.

Per game: `Config.lua` → ReplicatedStorage.Config (set gamepass/product IDs here), `GameServer.server.lua` → ServerScriptService, `Client.client.lua` → StarterPlayerScripts.

Build: `python3 build.py [name]` → `<name>.rbxlx` (default `eggs`), published via the Open Cloud Place Publishing API.
