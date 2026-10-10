# Brief for building one game on the shared kit

Repo: `/home/user/roblox-game` (branch `claude/project-thread-bwmsz8`). Five games are being built at the same
time, one per person, each in its own `games/<name>/` folder. The owner (Nathan) asked for: "5 roblox games,
fully made, tested, proprietary textures, match the style of current popular roblox games". Games stay private;
they are proof-of-concept but must be complete and fun, not stubs.

## Read first (all of it)
1. Every file in `kit/` (shared/Net, Fmt, Tiers, World; server/Data, Shop, Look, Assets; client/UI, Sfx, State, Fx;
   kit/materials.json). Use these APIs exactly as written; do not guess signatures.
2. `build.py` and `tools/check.mjs` (how files map into the place).
3. `/mnt/project-files/playbook/PROTOCOL.md` sections 0, 2, 3 and 6 (house rules, design spec, the look, money ladder).
4. Your game's spec (in your task prompt; for Rocket/Toy Army/Marbles also `/mnt/project-files/playbook/IDEAS.md`).

## Layout you write
```
games/<name>/game.json          {"name": "...", "walkSpeed": 20, "jumpPower": 50, "maxPlayers": N}
games/<name>/DESIGN.md          one page, PROTOCOL §2 template filled in (incl. palette hexes, preset, hero list)
games/<name>/materials.json     game-specific MaterialVariants still to generate (see Textures)
games/<name>/TEST.md            playtest checklist: what to verify in Studio, with the Debug commands to use
games/<name>/shared/Config.lua  all tuning numbers, palette, items/tiers, Passes/Products, Meshes, Icons
games/<name>/server/Main.server.lua   + any server modules (plain .lua files in server/)
games/<name>/client/Main.client.lua   + any client modules (plain .lua files in client/)
```
Require conventions (match the kit): shared modules `require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("X"))`,
server modules `require(script.Parent:WaitForChild("Lib"):WaitForChild("X"))` from Main and
`require(script.Parent:WaitForChild("X"))` between Lib modules, client modules
`require(ReplicatedStorage:WaitForChild("ClientLib"):WaitForChild("X"))`. Keep the last segment of every require
the module's file name (the checker relies on it).

Do NOT edit anything in `kit/`, `build.py` or `tools/` (other games share them). If the kit is missing something,
write a helper module inside your game folder under a new name, and list the kit gap in your final message.
Do NOT run git commands that change state (no add/commit/push/checkout/stash). Do not touch other games' folders.

## Gates you must pass before you finish
- `python3 build.py <name>` builds without error.
- `node tools/check.mjs <name>` reports **0 errors** (strict Luau with Roblox API types; it hides generic-Instance
  noise). Fix real errors properly; use `:: any` casts only where Luau cannot see a real type
  (FindFirstChild results, IsA refinements, Clone results).
- Re-read your own code adversarially for runtime errors the checker cannot see: nil indexes, WaitForChild on
  things never created, remotes fired before they exist, infinite yields, events connected twice, players who
  leave mid-action, unanchored parts falling through the floor, touching parts with no debounce, a player who
  already joined before PlayerAdded was connected (loop over Players:GetPlayers()).

## Proprietary art rules (the owner's main complaint: "we keep having that issue")
- **Never** put any Creator Store / toolbox / catalog image, decal, texture, mesh or model id in the game. No
  `rbxassetid://` image ids except: the house MaterialVariants in `kit/materials.json` (ours) and ids we generate
  later. No stock-texture look: never use Grass/Brick/Wood/etc. materials bare on big surfaces; use SmoothPlastic
  palette parts, plus `World.texture(part, "HouseGrass")` etc. on big flat surfaces (Part.Color stays white then).
  Neon and Glass are fine for glow and marbles.
- **Textures:** if the game needs its own surface (carpet, wood floor, frosting, track), add an entry to
  `games/<name>/materials.json`: `{"base": "Carpet", "studsPerTile": 24, "pattern": "Organic", "prompt": "almost flat
  ... no lines", "color": null}`. The prompt must forbid detail (see PROTOCOL §3.2). These get generated in Studio
  later and the ids filled in; until then `World.texture` falls back to flat colour, so the game must look good
  flat too. Use at most 4 game materials.
- **Hero meshes** (the thing players collect or stare at): add `Config.Meshes = { key = { mesh = 0, texture = 0,
  size = Vector3, prompt = "short shape words per PROTOCOL §4.3" } }`, call `Assets.init(Config.Meshes)` on the
  server, and always handle `Assets.get(key) == nil` by building a **good-looking primitive model** from palette
  parts (multi-part, chunky, balls/cylinders/wedges, 2-3 palette colours, a face or details where it helps). The
  primitive version must be good enough to ship.
- **UI icons:** emoji glyphs for now, all listed in `Config.Icons` (so they can be swapped for our own AI-made
  icon ids later). `UI.iconButton` accepts a glyph.
- **Sounds:** only the ids already in `kit/client/Sfx.lua` (licensed Roblox library sounds) and these licensed
  music ids: 1842976958, 1836942830, 1840434670, 1845266081, 1839807682, 1838005831.
- **Sky:** no sky image ids yet. Use `Look.apply` with Atmosphere haze and clouds so the sky reads as a tinted
  gradient, never the plain default.

## Style target: what current top Roblox games look like (PROTOCOL §3)
Bright, saturated, chunky low-poly; almost no PBR. Polish comes from density, one palette, lighting preset,
glow/particles on rares, billboard rarity labels with gradients, and very juicy UI (thick dark strokes, gradients,
bounce, rolling counters, number popups, coin-fly-to-HUD, confetti, short camera kicks, rarity reveal with banner
and server announce). Left icon menu, right gift/boost column, top currency counters, tabbed shop. Mobile first:
44px+ targets, nothing hover-only, HUD off screen centre. Landmark visible from spawn, spawn faces the goal, props
in purposeful clusters, no walk longer than 10 s without something to look at. No default baseplate (make your own
ground + SpawnLocation). Names/titles in the "[Verb] the [Noun]!" style with emoji.

## "Fully made" means
- Core 30 s loop, 1-day progress loop (upgrades/unlocks/rebirth or similar), collection/index with 5-7 rarity tiers
  (use `Tiers`), numeric odds on anything random.
- FTUE per the spec: fun in 10 s, first reward in 30 s, rare-feeling moment by 60 s, a "wow" by minute 3-5, with a
  clear next goal on screen (arrow/beam or highlighted button). No purchase prompts before minute 2.
- Saving via `Data.init` (unique store name `<Name>_v1`), leaderstats, daily reward, offline earnings if the spec
  has them.
- Shop via `Shop.init` with a full money ladder per PROTOCOL §6 (passes and products, ids 0 for now; the kit
  simulates purchases in Studio). Grants must actually work.
- A recurring server event (every few minutes) with a banner + countdown, and the spec's clip moment built on purpose.
- Solo servers must still be fun (NPC/bot helpers where the spec needs other players).
- Music + SFX on every action, mute button. Rarity colours/labels/sounds.
- Server-authoritative: clients only ask; the server validates (rate limits with `Net.allow`, distance checks).
- Performance: under ~8k parts total, anchored scenery, CanQuery/CanTouch false and CastShadow false on decor,
  client-side visuals for many moving things.
- `server/Debug.lua`: in Studio only (`RunService:IsStudio()`), create `ServerStorage.DebugCmd` (BindableFunction)
  with commands for testing, e.g. `give <player> cash 1e6`, `event` (start the server event now), `clip` (trigger
  the clip moment), `reset <player>`, `state` (returns a short text summary of game state), plus anything game
  specific. List them in TEST.md.

## Final message
Reply with: files written (one line), what the game does (5 lines max), check.mjs result, kit gaps found, and
anything you are unsure will work at runtime. Do not call any `mcp__hearthbot__` tools.
