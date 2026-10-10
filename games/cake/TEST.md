# Cake Off! 🎂 — Studio playtest checklist

Build: `python3 build.py cake` → open `cake.rbxlx` → Play (1 player) and Start Server + 2 players.
Debug commands (Studio only), from the server command bar:
`game.ServerStorage.DebugCmd:Invoke("state")`

| Command | What it does |
|---|---|
| `state` | one-line round summary (phase, time left, theme, celebrity, players, NPC bakers, queue) |
| `give 1000000` | coins to everyone · `give me xp 500` · `give me box 5` |
| `unlockall` | every topping, colour, shape, 4th tier, slots and all passes for you |
| `pass VIP` / `pass GoldenOven` / `pass ExtraTime` / `pass Rainbow` | grant one pass |
| `reset` | wipe your save back to a brand-new player (FTUE again) |
| `event` | next round is a Celebrity Judge round (skips the lobby wait) |
| `skip` · `time 5` | end the current phase now · set its remaining time |
| `theme Spooky` | queue the next theme (any of the 12 regular keys) |
| `bots 8` | NPC bakers fill up to 8 cakes |
| `box` | open a Mystery Box for you (free box or 300 coins) |
| `clip` | play the giant-winner-cake moment right now |

## First session (new player — run `reset` first)
- [ ] Spawn under the candy-cane arch facing the stage; landmark cake + CAKE OFF! sign visible; HUD: coins, level
      bar, 🎯 goal chip, phase pill with countdown, Celebrity countdown, left menu, right Box/2x/Theme column.
- [ ] "🎂 CAKE OFF!" banner + toast; tip pill "your bakery has the pink beam"; pink beam + "⬇ YOUR BAKERY ⬇" over
      the nearest station; your name on the station sign.
- [ ] First round starts ≤ 20 s after joining: theme spinner lands on a theme with idea glyphs.
- [ ] Pink guide beam from you to your station; "🏃 GO TO MY BAKERY" teleports you there.
- [ ] At the station the build camera + tray open automatically; tips walk through frost → toppings → DONE.
- [ ] Cake tab: shapes (Heart/Hexagon/Star locked → opens Shop Upgrades), tiers 1-3 (4 locked), FROSTING with
      ALL/1/2/3 targets, DRIP (🚫 none), PIPING (✨ auto); tapping a tier on the cake paints it.
- [ ] Toppings tab: owned first, 🎯 THEME marks; tap cake places topping (desktop ghost preview); top-only
      toppings refuse sides with a toast; S/M/L, turn 🔄, tint strip for tintable toppings, ↩️ undo, 🗑️ twice.
- [ ] Counter "🍒 n/24" turns red at the limit; full cake toast points to the Shop.
- [ ] ◀ ▶ ➕ ➖ and drag/scroll orbit the camera; 🚶 WALK leaves build mode, "🎂 DECORATE!" re-enters.
- [ ] ✅ DONE → "⏳ WAITING"; with every human done after 25 s the build ends early ("Everyone's done!").
- [ ] Vote: camera on the turntable, cake pops in and spins, "⭐ Rate X's cake!" with 5 stars, timer bar; your own
      cake shows "🤞 Everyone is rating your cake"; +3 🪙 floater per vote (cap 12/round).
- [ ] Judges lift paddles with numbers halfway through each cake; score card "⭐ 4.3 DELICIOUS!" + cheer/clap.
- [ ] Results: podium teleport (top 3), medal billboards, confetti, results card with coins flying to the counter,
      server announce banner; level-up banner when it happens.
- [ ] Giant cake: winner's cake grows 3x on the plaza with fireworks; camera inside the arch; shrinks away after.
- [ ] After round 1 the 🎁 Box button pulses; first box is Rare or better (reveal spinner, tier colour, NEW!).

## Menus
- [ ] Shop: Toppings (cheapest first, OWNED ✔), Colours (pass colours show R$), Upgrades (shapes, 4 tiers,
      slots up to MAXED), Robux (passes then products; owned passes show OWNED).
- [ ] Index: 38 toppings by tier, progress bar, next milestone (10/20/30 → free box), Secret shows ❓ until found.
- [ ] Box: odds list (numeric), OPEN FREE BOX / OPEN · 🪙 300, Luck timer while active, Legendary+ = server announce.
- [ ] Daily: 7 days, claim once per 20 h, streak resets after 48 h, day 7 adds a box.
- [ ] Theme: with a pick (buy "Pick Next Theme") choose a theme → server toast → next round uses it.
- [ ] Music button mutes music + sfx and is remembered after rejoin.

## Server / multiplayer
- [ ] 2 players: both get stations, both vote on each other, owners can't vote on their own cake.
- [ ] A player who joins mid-build gets a station, a station beam and up to +30 s grace (announced).
- [ ] A player leaving mid-round: their station shows an NPC display cake; round continues without errors.
- [ ] `event`: gold stage lights, Chef Gateau at the table with a gold paddle, special theme, "2x REWARDS".
- [ ] `pass ExtraTime`: next build is 130 s for everyone, announced with your name.
- [ ] `pass GoldenOven`: golden oven + plate + sparkles at your station, golden showcase ring, 🏆 tag.
- [ ] `pass VIP`: Bow/Ring/Swan in your tray, 👑 tag, VIP chat prefix.
- [ ] 12 players: no NPC bakers left, every player has a station.
- [ ] Rejoin: coins, unlocks, level, boxes, mute and tutorial step persist.
