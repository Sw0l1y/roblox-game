# Marble Mayhem 🔮: Studio playtest checklist

Build `python3 build.py marbles`, open `marbles.rbxlx`, then Play (1 player) or Start Server with 2 players.
Debug commands only work in Studio. Run them from the server command bar:
`game.ServerStorage.DebugCmd:Invoke("state")`. A player name is optional and defaults to the first player.

| Command | What it does |
|---|---|
| `help` | lists every command |
| `state` | one line: phase, time left, race number, main and warm-up race, GP countdown, and each player's coins, marbles, races, wins and league |
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

Headless sim: `node tools/sim/run.mjs marbles --debug "give 1000000;event"` (and `"clip;state"`).

## First session (new player: run `reset`, then rejoin)
- [ ] You spawn on the felt deck on top of the book tower, facing the start grid. The runner, track and trophy
      are in view and no fence post blocks the camera.
- [ ] Racing within 10 s: a warm-up heat (6 marbles, short track) or the main race's pick screen opens within ~2 s.
- [ ] Pick screen: 3 marble cards (3D spin, tier, LVL, stat bars, ⭐ BEST / LOANER tags), 4 power cards (one
      marked 👍 GOOD HERE for this track's features), 🔒 +1 SLOT opens the Shop, READY and the countdown timer.
      The camera flies over the new track.
- [ ] Countdown: 3 red lights, then green, beeps, GO! banner, and the gate bar drops.
- [ ] Your marble shows "YOU ▼". When it glows, BOOST (button, Space, E or gamepad A/R2) gives a burst, a
      PERFECT! label and a streak. A tap outside the window shows MISS. The meter shows the perfect zone.
- [ ] Track pieces: turns with striped rails, boost pads, stairs, jump with hoop, funnel bowl spiral, split lane.
      The camera button cycles follow, leader and overview.
- [ ] Big air from your marble triggers a short slow-mo. A close finish triggers PHOTO FINISH slow-mo with the
      finish-line side camera.
- [ ] Results card: podium with 3D marbles, your place, coins counting up and flying to the counter, XP,
      league points, and a level-up banner when it happens. Coins land by ~45 s.
- [ ] After the first race: FREE WELCOME PACK banner, the 🎁 Packs button pulses and the guide arrow and beam
      point to the Pack Machine. Opening it (~60 s): shake, burst, card flip, NEW!.
- [ ] By minute 3: the mutation tease (🌌 banner) and FREE first Shine. The Shine Machine shows a colour-cycle
      result.
- [ ] No purchase popup before 150 s. Popups have no countdown and come at most once every 6 min.

## Menus
- [ ] Marbles: collection grid by tier, detail pane (XP bar, Speed/Grip/Weight with + buttons, Tune-Up,
      ⭐ Favorite, Shine It). The Index tab shows n/68, mutation glyphs and milestones.
- [ ] Packs: numeric odds for every pack, OPEN FREE / coin price, OPEN x3 (locked without Triple Open), Galaxy
      Pack for R$, luck line while Lucky Charm or Luck Boost is active.
- [ ] Shine: grid of plain marbles, mutation odds, cost (first one FREE).
- [ ] League: Bronze/Silver/Gold/Diamond with CLAIM, top 10 board (daily), Grand Prix box with countdown.
- [ ] Shop: Featured, Passes (owned shows OWNED), Coins, Trails (equip owned trails).
- [ ] Daily: 7 days, claim once a day. The Music button mutes music and sfx.
- [ ] Offline: `offline 3` shows the Welcome Back card with Collect.

## Server / multiplayer
- [ ] 2 players race in the same main race and both see the same order. Bots fill to 8 and show names.
- [ ] A player who joins mid-race sees the live race (Sync catch-up), then gets the next pick screen.
- [ ] A player leaving mid-race: their marble is removed and the race continues without errors.
- [ ] `event`: purple GRAND PRIX banner, theme music, themed track, and the winner gets the GP marble reveal.
- [ ] Passes: 2x Coins (shown in the results mult), Extra Power-Up Slot (two cards), VIP (gold trail, tag,
      +10%), Triple Open, Lucky Charm. Products: StarterPack (once), coin packs, Luck Boost, Galaxy Pack (opens
      right away), trails, Start a Grand Prix (next race for the whole server), Diamond Marble.
- [ ] Rejoin keeps coins, marbles, levels, league, daily streak and trail. Mute is per session (kit Sfx has no saved setting).

## Deferred
- Trading is not in this version. It is planned for a later update (see DESIGN.md).
