# Build the Rocket! 🚀 — playtest checklist

Build: `python3 build.py rocket`, open `rocket.rbxlx` in Studio, Play (solo), then Play with 3+ players (Test → Clients and Servers) for team lifts.
Debug commands (Studio only), from the server command bar:
`game.ServerStorage.DebugCmd:Invoke("state")`

| Command | What it does |
|---|---|
| `state` | Planet, mission, phase, rocket tier + next tier, slots, loose parts, bots, boosts, next drop, every player's coins/strength/gear/FTUE step, FTUE timings (lift/reward/gift), spent, RandomBlocked, friends, ladder, quests |
| `give 1e6` · `give <player> 1e6` · `give <player> strength 500` · `give hauled 60000` · `give launches 5` | Coins (or another stat) to everyone / one player |
| `event` (or `drop`) | Supply Drop now (pod falls, 3 Star Crates) |
| `clip` (or `fill`, `launch`) | Fill every open slot with Legendary parts → full launch sequence |
| `planet 2` (1-4) | Jump the server to a planet (rebuilds its rocket, moves everyone to the landing pad) |
| `rarity Legendary` (or `spawn Secret`) | Spawn a part of that tier at the depot |
| `fuel [player]` | Run "Fuel the Server" as that player (drones bolt on 3 parts, 2x for 2 min, shoutout) |
| `boost 60` | Server 2x coins + 2x strength for 60 s |
| `luck 2 60` | Server luck x2 for 60 s (Index odds rows update live) |
| `zerog 60` | Zero-G Training (3x strength gains) for 60 s |
| `hourly` | Run the hourly event now (2x coins + 2x luck 10 min, 8-crate mega drop) |
| `tier Galaxy` | Rebuild the current rocket as that tier (Basic/Silver/Gold/Galaxy) |
| `next Gold` | Queue the next rocket's tier (as if bought) |
| `parts 3` (0 = all) | Run a +Parts drop as the first player |
| `blocked <player> on\|off` | Set RandomBlocked (luck products hide and are refused) |
| `starter [player]` | Reopen the first-session 10-minute Starter Pack window |
| `quest <key> 1` | Advance a FREE-panel quest (parts, team, help, launch, friend, crate, rare, upgrade) |
| `minutes 60` | Set today's playtime to claim playtime gifts |
| `daily [player]` | Make the daily gift claimable now |
| `offline [player] 5` | Grant 5 h of offline drone earnings (sets drones to level 2 if 1) |
| `ftue [player]` | Reset the first-time flow (beam back to the nose cone pad) |
| `pass <player> <Key>` | Run the purchase flow for a pass/product (Studio simulates id 0 purchases) |
| `reset [player]` | Wipe progress (keeps passes) |
| `bots` | Re-sync crew bots for the current player count |

## First 5 minutes (fresh profile: `reset` then rejoin)
- [ ] Spawn faces the rocket (engine, fins and first tank built, the rest are cyan holograms); launch tower, crane and depot visible.
- [ ] Gold beam + bouncing arrow point at the glowing, sparkling Nose Cone on the gold pad just left of the path in front of you (it must not hide the rocket); hint line says how to lift.
- [ ] E / tap LIFT: the part rises over your head, your arms go up, carry panel shows 💪 vs ⚖️, speed and lifters.
- [ ] Beam switches to the launch pad ring; walking into the ring flies the part up to its slot with a burst, thud, coin fly and +strength popup.
- [ ] After the 2nd delivery a gift banner announces a free Epic part at the depot (purple label, sparkles).
- [ ] A booster (100 weight) is too heavy alone: wobbles on the ground, "NEED A HAND!" status, help toast for others, crew bots walk over and grab on; it then moves.
- [ ] Gear button pulses when Power Gloves are affordable; Gear kiosk prompt (F) opens the Gear panel; upgrading shows gloves colour on your hands.
- [ ] At 45 s a WELCOME GIFT banner pays coins (first session only; `state` shows gift ≈ 45 s).
- [ ] From 2:00 a Starter Pack pill with a countdown sits in the pill row (first session, first 10 min only); it opens Shop → Coins.
- [ ] Rocket completes in roughly 4 minutes solo → "ALL ABOARD!" with countdown line, then the cinematic (below). No offer popups before minute 3.

## Launch (use `clip`)
- [ ] 10 s boarding line, then everyone is seated: MVP on the nose, VIP (`pass <you> VIP`) on the gold balcony, others on the deck rings.
- [ ] HUD hides; orbit camera; big 10..1 numbers with beeps; smoke builds in the last seconds.
- [ ] LIFTOFF: flames under engine + boosters, ground smoke, shake, clouds rush past, sky darkens; VIP gets the window-seat camera, MVP the nose camera.
- [ ] White warp "NEXT STOP: THE MOON!", lander descends at the landing pad, characters appear on touchdown, dust ring + thud.
- [ ] HUD returns, "WELCOME TO THE MOON" banner, Mission Complete notice with coins; gravity is low (big slow jumps), music switches to space tracks, a bigger rocket with heavier parts, bubble helmets on.
- [ ] Repeat with `planet 3` / `planet 4` for Mars and Europa (mesas, ice spikes, Jupiter), and `clip` on Europa wraps to Earth as Mission 2.

## Systems
- [ ] Shop tabs: Strength (each step shows "FREE at N launches" / SKIP price, ACTIVE/FREE/OWNED), Boosts (The Rocket, Zero-G, Server Coins with "needs" locks, Server Luck with live odds), Passes, Skins (equip, locked, buy), Coins (Rookie Deal before any purchase, Starter with ENDS IN). Each buy simulates in Studio and shows a thank-you banner.
- [ ] Every pass card has a 🎁 gift button: with 2+ players it opens the player picker and the gift arrives with a server shoutout; solo it says "Nobody else is here yet. Invite a friend!".
- [ ] Boost pills (coins/strength/luck/zero-g) appear under the counters while a server boost runs; buying Server Strength x2 then x1024 replaces the smaller one.
- [ ] `blocked <you> on`: Server Luck cards disappear from Boosts; `pass <you> ServerLuck2` is refused with a notice.
- [ ] Index → Rockets: 4 tier cards with live % (luck shifts them), THIS ROCKET / NEXT tag, ORDER buttons; `tier Galaxy` shows the ring + glow on the pad and "GALAXY ROCKET" on the billboard.
- [ ] Landing with `give launches 2` + `pass <you> Launch2x`: summary shows the launch credit and any FREE UNLOCK of a strength step; Zero-G pill starts after landing.
- [ ] Gear panel: each track has a ⏩ skip button (SkipL<n> product) that levels it up.
- [ ] 🎁 FREE button: badge when something is claimable; code LAUNCH, playtime gifts (`minutes 60`), quests (`quest friend 1`), group gift; INVITE button opens the invite prompt.
- [ ] `hourly`: announce banner, 2x coins + luck pills, 8 crates fall.
- [ ] Fuel the Server (right column): orange flash, shoutout banner, 3 drones fly parts onto the rocket, 2X pill counts down.
- [ ] Robot Crew: 2 gold robots follow you and help lift your part. Mega Jetpack: double jump with flame, faster hauling.
- [ ] Party Popper button appears after buying; confetti for nearby players. Rainbow Trail visible.
- [ ] Skins: equipping Golden as the top hauler repaints the rocket and announces it.
- [ ] Index: cells fill in tier colours with counts; odds row shows % (… 0.05%) and a 🍀 row with luck applied; Rockets, Planets and Ranks tabs.
- [ ] Daily: claim day 1 (`daily` to re-arm), streak cards, Fuel Run bar counts deliveries to 10 → reward banner + 3x boost.
- [ ] Supply Drop (`event`): 15 s warning toast, pill countdown, pod falls onto a pulsing gold ring, 3 Star Crates with beams; each crate pays x6 and a drone bolts a part on.
- [ ] Rank up (`give hauled 2500`): banner, tag over head changes; Legend (2,000,000) tag is rainbow.
- [ ] Offline (`offline 5`): Welcome Back notice with drone coins.
- [ ] Rejoin keeps coins, gear, index, planets, launches, skin, daily streak; mute button toggles music + SFX.

## Edge cases
- [ ] Die while carrying: the part drops where you were and can be picked up again.
- [ ] Leave while carrying with a friend: the friend keeps carrying (slower).
- [ ] Join during the countdown/flight: you watch from spawn; join during warp/arrive: you are placed at the landing pad with everyone else.
- [ ] 4+ players: the next rocket is medium (4 boosters); 13+ players: large (6 boosters, 6 fins).
- [ ] Phone layout (Device emulator): counters, left grid, right column and carry panel do not overlap the thumbstick or jump button.
