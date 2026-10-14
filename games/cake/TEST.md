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
| `hourly` | Hourly Grand Gala next round (3x, boxes top 3, Haunted theme in Caketober) + 10 min server 2x coins |
| `candy 500` | Caketober candy for you (100 per tier) |
| `policy on` / `policy off` | paid-random restriction on/off for you (RandomBlocked) |
| `boost coins 2 15` | start a server boost (coins, xp, luck) |
| `product Overtime` | run a product grant as if bought (any Config.Products key) |

## First minute (new player — run `reset`, then rejoin; time from joining)
- [ ] 0-3 s: title banner from Config.Title; you are moved to your bakery once and the tray opens on the warm-up
      cake ("🎨 WARM-UP" on the DONE button) whatever the phase (Lobby/Theme/Build).
- [ ] ≤ 10 s: tap a colour → the cake changes (core verb). ≤ 30 s: "+25 💰" floater + coin fly-in for the first
      decorating tap, another +25 for the first topping.
- [ ] ~40 s (≤ 55 s even during judging): the welcome box opens itself — "🎁 WELCOME GIFT!", Rare or better,
      AWESOME closes it.
- [ ] First 2 minutes: no purchase prompt or offer popup; locked Premium/VIP items open the Shop (Passes) instead
      of a prompt; no +60 s or reaction buttons. The HUD deal button shows "2x Coins" until minute 2, then the
      🧁 starter countdown.
- [ ] After 2.5 min, at a lobby: the Starter Pack offer (countdown to the 10-minute mark); gone after 10 min and on
      later sessions (the kit refuses the prompt then too). Later, a never-spent player sees the 9 R$ Baker's Treat
      once per session (4+ min in, lobby only).

## First session (new player — run `reset` first)
- [ ] Spawn under the candy-cane arch facing the stage; landmark cake + CAKE OFF! sign visible; HUD: phase pill with
      countdown + Celebrity countdown (top centre), coins/level/🎯 goal + 2x2 menu (left-middle), Box/2x/Theme
      (right-middle); nothing under the chat window (top-left) or the player list (top-right).
- [ ] "🎂 CAKE OFF!" banner + toast; tip pill "your bakery has the pink beam"; pink beam + "⬇ YOUR BAKERY ⬇" over
      the nearest station; your name on the station sign.
- [ ] First round starts ≤ 20 s after joining: theme spinner lands on a theme with idea glyphs.
- [ ] Pink guide beam from you to your station; "🏃 GO TO MY BAKERY" teleports you there.
- [ ] At the station the build camera + tray open automatically; tips walk through frost → toppings → DONE.
- [ ] Decorating is preset-only: colours paint tiers, PIPING picks a colour for the preset rim, toppings snap to
      the tapped spot; there is no freehand drawing tool.
- [ ] Cake tab: shapes (Heart/Hexagon/Star locked → opens Shop Upgrades), tiers 1-3 (4 locked), FROSTING with
      ALL/1/2/3 targets, DRIP (🚫 none), PIPING (✨ auto); tapping a tier on the cake paints it.
- [ ] Toppings tab: owned first, 🎯 THEME marks; tap cake places topping (desktop ghost preview); top-only
      toppings refuse sides with a toast; S/M/L, turn 🔄, tint strip for tintable toppings, ↩️ undo, 🗑️ twice.
- [ ] Counter "🍒 n/24" turns red at the limit; full cake toast points to the Shop.
- [ ] ◀ ▶ ➕ ➖ and drag/scroll orbit the camera; 🚶 WALK leaves build mode, "🎂 DECORATE!" re-enters.
- [ ] ✅ DONE → "⏳ WAITING"; with every human done after 25 s the build ends early ("Everyone's done!").
- [ ] Vote: camera on the turntable, cake pops in and spins, "⭐ Rate X's cake!" with 5 stars, timer bar; your own
      cake shows "🤞 Everyone is rating your cake"; +3 💰 floater per vote (cap 12/round); "🎯 Fair judge! +2 💰"
      when your rating lands within 1 ⭐ of the final score.
- [ ] Reactions row above the vote card (not on your own cake): 🎊 / 🥄 / 💋 with R$ prices or "xN" saved credits;
      a reaction plays its FX for everyone + toast, and the baker gets 50/100/150 coins.
- [ ] Overtime: `product Overtime`, then in the last minute of the build the button reads "⏰ OVERTIME READY ✔".
      After the bell you keep your camera + tray (pill "⏰ YOUR OVERTIME! 0:59", vote card hidden); your cake is
      shown last with what was on it when its slot started.
- [ ] Judges lift paddles with numbers halfway through each cake; score card "⭐ 4.3 DELICIOUS!" + cheer/clap.
- [ ] Results: podium teleport (top 3), medal billboards, confetti, results card with coins flying to the counter,
      server announce banner; level-up banner when it happens.
- [ ] Giant cake: winner's cake grows 3x on the plaza with fireworks; camera inside the arch; shrinks away after.
- [ ] Results card extras: Gala 3x / Celebrity 2x, ⚡ server boost, 👫 +10% friend, 🍬 candy, 🎁 boxes.

## Menus
- [ ] Shop: Toppings (cheapest first, OWNED ✔), Colours (pass colours show R$), Upgrades (shapes, 4 tiers,
      slots up to MAXED), Passes (each with BUY + 🎁 GIFT), Robux (Deals, Server Boosts with 🔒 "needs 2x" locks,
      This Round, Coins up to 1,999, Boxes, Caketober skips).
- [ ] Index: 45 toppings by tier, progress bar, next milestone (10/20/30 → free box), Secret shows ❓ until found;
      box-only cards show their live % (Secret too).
- [ ] Box: live % per tier with the current luck and the base odds, OPEN FREE BOX / OPEN · 💰 300, Luck timer.
- [ ] `policy on`: Robux boxes, Lucky Sprinkles and server luck disappear from the shop; the Box menu only opens
      free boxes (a bought box opens as 300 coins); the Starter Pack reads "3,500 coins (once)". `policy off` brings
      them back.
- [ ] 🎁 FREE: playtime gifts, 3 daily quests, code LAUNCH, invite; the button shows a count when something is ready.
- [ ] 🎃 Caketober: 30 tiers × free/premium cells, candy bar, CLAIM ALL, GET PASS / GIFT PASS, +1/+5/+10 skips;
      `candy 900` → 9 tiers claimable (count on the 🎃 button); event toppings/colours in the tray say "🎃 Track".
- [ ] `hourly`: HUD chip "👑 Hourly Grand Gala: NEXT ROUND!", gold "HOURLY GRAND GALA" reveal, boost pill
      "2x COINS", results show Gala 3x and boxes for the top 3.
- [ ] Server boosts: buying 2x Coins shows the boost pill + shoutout; 4x unlocks only while 2x runs.
- [ ] Daily: 7 days, claim once per 20 h, streak resets after 48 h, day 7 adds a box.
- [ ] Theme: with a pick (buy "Pick Next Theme") choose a theme → server toast → next round uses it.
- [ ] Music button mutes music + sfx and is remembered after rejoin.

## Server / multiplayer
- [ ] 2 players: both get stations, both vote on each other, owners can't vote on their own cake.
- [ ] A player who joins mid-build gets a station, a station beam and up to +30 s grace (announced).
- [ ] A player leaving mid-round: their station shows an NPC display cake; round continues without errors.
- [ ] `event`: gold stage lights, Chef Gateau at the table with a gold paddle, special theme, "2x REWARDS".
- [ ] `pass ExtraTime`: next build is 180 s for everyone, announced with your name.
- [ ] `pass GoldenOven`: golden oven + plate + sparkles at your station, golden showcase ring, 🏆 tag.
- [ ] `pass VIP`: Bow/Ring/Swan in your tray, 👑 tag, VIP chat prefix.
- [ ] 12 players: no NPC bakers left, every player has a station.
- [ ] Rejoin: coins, unlocks, level, boxes, candy + claimed tiers, Overtime tickets, reaction credits, mute and
      tutorial step persist; no starter offer on the second session.
