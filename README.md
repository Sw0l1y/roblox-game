# roblox-game

Games (each in `games/<name>/src`):

- `eggs` — Steal a Dragon Egg (current, live): buy eggs off a conveyor, they earn cash in your base, steal other players' eggs.
- `candy` — Candy Smash Simulator: themed click sim with zones, combos, offers.
- `clicksim` — original ClickSim, kept for reference.

Per game: `Config.lua` → ReplicatedStorage.Config (set gamepass/product IDs here), `GameServer.server.lua` → ServerScriptService, `Client.client.lua` → StarterPlayerScripts.

Build: `python3 build.py [name]` → `<name>.rbxlx` (default `eggs`), published via the Open Cloud Place Publishing API.

Promo shorts: `cd tools && python3 shorts.py` renders a 12s vertical video to `out/shorts/` (templates: spin, steal, ranked; picked by date). `tools/tiktok_draft.py` sends it to TikTok drafts; `.github/workflows/tiktok-shorts.yml` does both daily once the TikTok secrets are set.
