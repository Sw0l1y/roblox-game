# Marble Mayhem 🔮: Studio playtest checklist

Build `python3 build.py marbles`, open `marbles.rbxlx`, then Play (1 player) or Start Server with 2 players.
Debug commands only work in Studio. Run them from the server command bar:
`game.ServerStorage.DebugCmd:Invoke("state")`. A player name is optional and defaults to the first player.

| Command | What it does |
|---|---|
| `help` | lists every command |
| `state` | one line: phase, time left, race number, main and warm-up race, GP countdown, server boosts, next-race mods, and each player's coins, marbles, races, wins, league and FTUE times (`ftue go 6.5s reward 28.5s` = first race started / first reward after join) |
| `give 1000000` · `give xp 500` · `give league 150` | coins, XP for your best marble, or league points |
| `marble phoenix gold` | add a marble (any id from `Config.Marbles`; mutation is `gold`, `rainbow` or `cosmic`) |
| `pack galaxy 3` | add packs (`basic`, `shiny`, `mega`, `galaxy` or `welcome`) |
| `event` / `gp` | the next race is a Grand Prix with the weekly theme, music and prize marble |
| `clip` | the current or next race gets a photo finish and huge jumps, for recording the slow-mo clip |
| `skip` | ends the pick or results phase now |
| `reset` | wipes your save and starts the FTUE again (passes are kept) |
| `ftue` | resets only the FTUE flags and the join clock |
| `practice` | starts a warm-up heat for you |
| `level 20` | levels your best marble |
| `daily` · `luck` · `offline 3` | daily reward claimable · 15 min luck boost · simulate 3 h away and show the Welcome Back card |
| `tease` | plays the mutation tease |
| `bots 12` | bots fill races up to n marbles (the default is 8) |
| `hourly` | the next race is the HOURLY GRAND PRIX + 10 min server 2x coins (what Live.onHour runs) |
| `boost coins 4 5` · `boost luck 2 5` | start a server boost (multiplier, minutes) as if bought |
| `mod chaos` · `mod ice` · `mod bigair Volcano` | queue a round modifier (and optional theme) for the next race |
| `blocked on` · `blocked off` | turn the paid random item restriction on/off for a player (RandomBlocked) |
| `starter` | restarts the 10-minute Starter Pack window and gives the 9 R$ first-buy offer back |
| `streak` | breaks a 5-day streak so the Keep Streak card shows in Daily |
| `open Packs` | opens a panel on the player's screen (Packs, Odds, Shine, Daily, Shop, CustomRound, ...) |

Headless sim: `node tools/sim/run.mjs marbles --debug "give 1000000;event" --no-render` (and `--mobile`; also
`"marble comet;blocked on;streak;open Packs;open Odds;open Shine;open Daily;open Shop"` and `"hourly;mod chaos;boost luck 2 5;luck;open Packs"`).

## First session (new player: run `reset`, then rejoin)
- [ ] You spawn on the felt deck on top of the book tower, facing the start grid. The runner, track and trophy
      are in view and no fence post blocks the camera.
- [ ] Racing within 10 s: a new player's warm-up heat (6 marbles, short track) starts right after the save loads.
- [ ] Pick screen: 3 marble cards (3D spin, tier, LVL, stat bars, ⭐ BEST / LOANER tags), with 2+ marbles owned a
      🎯 FREE PICK card (opens a list of every owned marble by power; the chosen one races), power cards (one
      marked 👍 GOOD HERE for this track's features), 🔒 +1 SLOT opens Shop > Passes, READY and the countdown
      timer. The camera flies over the new track.
- [ ] Countdown: 3 red lights, then green, beeps, GO! banner, and the gate bar drops.
- [ ] Your marble shows "YOU ▼". When it glows, BOOST (button, Space, E or gamepad A/R2) gives a burst, a
      PERFECT! label and a streak. A tap outside the window shows MISS. The meter shows the perfect zone.
- [ ] Track pieces: turns with striped rails, boost pads, stairs, jump with hoop, funnel bowl spiral, split lane.
      The camera button cycles follow, leader and overview.
- [ ] Big air from your marble triggers a short slow-mo. A close finish triggers PHOTO FINISH slow-mo with the
      finish-line side camera.
- [ ] Results card: podium with 3D marbles, your place, coins counting up and flying to the counter, XP,
      league points, and a level-up banner when it happens. Coins land by ~45 s.
- [ ] After the first race (~30 s): FREE WELCOME PACK banner, the 📦 Packs button pulses and the guide arrow and
      beam point to the Pack Machine. Opening it: shake, burst, card flip, NEW!. The 🎁 FREE button shows its
      "!" when a gift/quest/code is claimable and opens the free-rewards menu (try code LAUNCH).
- [ ] By minute 3: the mutation tease (🌌 banner) and FREE first Shine. The Shine Machine shows a colour-cycle
      result.
- [ ] No purchase popup and no offer button before 150 s. After that the right column shows 🎒 with the Starter
      Pack countdown (first 10 min of the first session only; gone on rejoin), then 2x. Popups come at most once
      every 6 min, only after a race; the Starter Pack popup has a countdown.

## Menus
- [ ] Marbles: collection grid by tier, detail pane (XP bar, Speed/Grip/Weight with + buttons, Tune-Up,
      ⭐ Favorite, Shine It). The Index tab shows n/69, mutation glyphs and milestones.
- [ ] Packs: exact % per tier on every pack (they add up to 100%) and mutation %, ODDS opens the ALL ODDS sheet
      (each tier, each marble's own %, Secret names ??? until found, Shine odds). With `luck`/`boost luck 2 5`
      every row shows normal % in grey and your % in green, and the panel redraws when luck starts/ends.
      OPEN FREE / coin price, OPEN x3 (locked without Triple Open), Galaxy Pack for R$.
- [ ] `blocked on`: coin packs show "TODAY YOU GET" + the fixed marble and give exactly it; Galaxy Pack, Luck
      Boost, Lucky Charm, server luck and the random 9 R$ Epic are hidden (the fixed First-Buy Epic shows);
      Shine shows "GOLD SHINE 15K" and always gives Gold. Free packs still roll.
- [ ] Shine: grid of plain marbles, live mutation odds, cost (first one FREE and Gold).
- [ ] League: Bronze/Silver/Gold/Diamond with CLAIM, top 10 board (daily), Grand Prix box with countdown.
- [ ] Shop: Deals (first buy 9, Starter Pack with countdown, 4 daily marble deals with reset timer, 🎃 Halloween
      bundle, Diamond), Passes (OWNED, 🎁 GIFT opens the player picker), Boosts (4x/8x locked until 2x/4x runs;
      the boost pill under the goal pill shows active boosts), Race (Start a GP, Chaos, Ice, Custom Round picker),
      Coins (up to 1,999), Trails (equip owned trails).
- [ ] Round modifiers: buying Chaos/Ice/Custom shows "NEXT RACE: ..." for everyone and the next race uses it.
- [ ] Daily: 7 days, claim once a day; after `streak`, the Keep Streak card (R$ 19) restores the old streak.
      The Music button mutes music and sfx.
- [ ] Offline: `offline 3` shows the Welcome Back card with Collect.

## Server / multiplayer
- [ ] 2 players race in the same main race and both see the same order. Bots fill to 8 and show names.
- [ ] A player who joins mid-race sees the live race (Sync catch-up), then gets the next pick screen.
- [ ] A player leaving mid-race: their marble is removed and the race continues without errors.
- [ ] `event`: purple GRAND PRIX banner, theme music, themed track, and the winner gets the GP marble reveal.
- [ ] `hourly`: HOURLY GRAND PRIX banner, 3x coins, the whole podium gets the GP marble, and a 10 min 2x COINS pill.
- [ ] Passes: 2x Coins (shown in the results mult), Extra Power-Up Slot (two cards), VIP (gold trail, tag,
      +10%), Triple Open, Lucky Charm. Products: first buy (refused after any purchase), StarterPack (once, first
      10 min), coin packs, Luck Boost, Galaxy Pack (opens right away), daily deals (gives the marble shown),
      server boosts, round modifiers, Keep Streak, trails, Start a Grand Prix, Jack-o'-Marble, Diamond Marble, gifts.
- [ ] Rejoin keeps coins, marbles, levels, league, daily streak and trail. Mute is per session (kit Sfx has no saved setting).

## Deferred
- Trading is not in this version. It is planned for a later update (see DESIGN.md).
