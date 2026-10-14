# Pop All The Balloons! 🎈

**Tagline:** "Throw darts. Pop EVERYTHING. Float all the way to space."  (formula: "[Verb] All The [Noun]!")
**Story hook** (first 10 s: title banner + toast; store description): "The balloons are carrying the town away!" Houses float off under balloon bunches over the Meadow; a hidden Balloon Factory behind Space Rainbow keeps making them. The display name lives in `Config.Title` (one line to rename).

| | |
|---|---|
| **Core verb** | POP: tap/click a balloon to throw a dart (aim assist, hold to keep throwing), or run into small ones |
| **Server size** | 12 · **Maturity target:** Minimal |
| **Session loop (30 s)** | Pop the balloons floating up around you → confetti + coins fly to the HUD → buy an upgrade (power / throw speed / aura / luck / walk) → a rarer balloon with a label and HP bar appears → pop it for a big payout and a new Index entry |
| **Progress loop (1 day)** | Every zone has an end state: a "popped %" meter (120 / 300 / 500 / 800 of its own pops) → at 100% tap it to summon the zone's **BOSS** (a giant angry crowned balloon next to you, HP sized to everyone in the zone, helpers get half) → beating it opens the next zone for free the first time (+5 Mega Darts, ZoneBoss badge); or buy the gate with coins (Candy Hills 1K → Sky Islands 40K → Space Rainbow 1M). Max upgrades, complete each zone's Index set (+10/15/20/25% coins forever), Rebirth (25M, x2.5 cost each) for +0.5x coins permanently |
| **Meta loop (28 days)** | Secret ending: beat all 4 bosses, then find the hidden Balloon Factory behind Space Rainbow and shut it down (big coin pack + 50 Mega Darts, Factory badge, server shoutout). Find all 4 Secrets (0.03% each at base luck, +10% coins each), rebirth ladder, 7-day gift streak, playtime gifts and 3 daily quests (FREE panel), Balloon Pump offline earnings (up to 8 h) |
| **Public display** | Leaderstats (Coins, Pops, Rebirths), billboard rarity labels with tier gradients, sky beacons over Legendary+ balloons, server-wide announces for Legendary+ spawns and Mythic+ pops, named Balloon Pumps around the hub, 👑 VIP tag over the head and in chat, gold / golden darts |
| **Social hook** | Everyone damages the same balloons (helpers get 50% of the coins), everyone attacks the MEGA BALLOON and zone bosses together, anyone can buy "Summon MEGA Balloon now" or a server boost for the whole server, +10% coins per friend in the server, gift any pass to a player here, invite reward for both |
| **Clip moment** | **MEGA BALLOON** (every 5 min, first one 2.5 min after a server starts): banner + 30 s countdown while it inflates on the hub's Mega Pump → it rises with a server-wide HP bar → players + 4 Party Bots throw darts, it over-inflates and shakes → it EXPLODES into a coin rain over the plaza and a shower of 18 rare balloons (Rare→Secret) |

**FTUE:** 0-10 s spawn on the Meadow facing the hub and the Mega Pump; title banner at 1.5 s and the story toast at 4.5 s; 7 easy balloons rise around you, goal bar + beam point at the nearest one, first pop < 5 s. ~22 s: a seeded Rare (reserved for you) rises right next to you with a sparkle + beam (first big reward; ~75 s a seeded Epic if you missed it). ~30 s: Dart Power costs 30 coins (≈15 pops); the Upgrades button pulses. 45 s: FREE GIFT banner, +5 Mega Darts, the guide pulses the 💥 button. After 10 pops the zone meter appears under the coins. 2.5 min: first MEGA BALLOON on a new server. **No offer before minute 2:10** (`Config.Ftue.offerAfter`, never during the MEGA event or over a menu); then the Starter Pack panel once, with its countdown, and the 🎉 HUD button with the timer while the window is open (first 10 minutes of the first session: catalog `window = 600`, the kit refuses it after). Players who never bought anything get the 9 R$ Welcome Deal popup once after that window (from minute 4 of later sessions).

**Economy:** one currency (coins 💰). Sinks: upgrades (5 tracks, geometric costs), zone gates, rebirth. Value = tier value x zone value multiplier (x1 / x10 / x120 / x1,000) x coin multiplier (rebirth, 2x pass, VIP 1.25, Premium 1.1, Index set bonuses). HP x zone HP multiplier (x1 / x5 / x40 / x300).
Tiers (kit `Tiers`), spawn weights per zone. Odds are shown as percentages that add up to 100% (kit `Tiers.percents`), live at the player's current luck ("base → boosted 🍀") in the Index, on every luck item's card and in the 📊 Odds sheet (NOW vs WITH IT, per zone; names stay ??? until found, Secrets included, the % always shows):

| Tier | Base | x2 luck | x4 luck | HP / value (Meadow) | Meadow | Candy Hills | Sky Islands | Space Rainbow |
|---|---|---|---|---|---|---|---|---|
| Common | 60% | 52.1% | 43.3% | 1 / 2 | Red | Gumdrop | Cloud | Moon |
| Uncommon | 25% | 26.5% | 26.8% | 2 / 5 | Polka | Bubblegum | Sunny | Ringed Planet |
| Rare | 10% | 12.9% | 15.9% | 6 / 18 | Striped | Lollipop | Hot Air | UFO |
| Epic | 3.6% | 5.7% | 8.5% | 15 / 60 | Heart | Cupcake | Balloon Bunch | Comet |
| Legendary | 1.1% | 2.1% | 3.9% | 40 / 250 | Star | Donut | Thunder | Galaxy |
| Mythic | 0.27% | 0.63% | 1.4% | 100 / 1,200 | Golden | Cotton Candy | Angel | Rainbow Star |
| Secret | 0.03% | 0.086% | 0.23% | 250 / 10,000 | Rainbow | Sugar Crystal | Phoenix | Cosmic |

**Paid random rule:** the only paid random in the game is luck (it changes which balloons spawn). Every luck item is `random = true` (Lucky Darts, Gift Lucky Darts, Lucky Boost, 2x/4x Luck Server Boost) and shows its live odds; the coin-bought Luck upgrade counts too (coins are sold for Robux). For players with `RandomBlocked` (kit Policy) all of them are hidden and refused, the Luck upgrade is hidden and paid luck is ignored in `Econ.luck` (free luck from gifts still works), the Starter Pack swaps its Lucky Boost for +10 Mega Darts (shown before buying), and the HUD's 🍀 slot sells the 2x Coins server boost instead. A paid "Summon MEGA" bursts into a fixed set (10 Rare, 5 Epic, 2 Legendary, 1 Mythic, written on the card); the free 5-minute and hourly MEGAs keep their random shower.

Rare+ have labels; Rare+ are "big" (HP bar; the aura only pops small ones unless you own the Aura pass). Mutation layer: none (no pets per spec); the MEGA shower balloons pay 2x at your best zone's rate. Rebirth: yes.

**Money ladder (ids 0 until created; live prices from kit Prices; one line per item in Config for tools/launch.py):**

| Tab | Item | R$ |
|---|---|---|
| Passes | 🎃 Pumpkin Darts (Halloween: pumpkin darts, candy pops, +20% coins) | 299 |
| Passes | 2x Coins / Auto-Pop Aura / Lucky Darts (x1.5 luck, random) / VIP / Golden Dart (x3 power) | 299 / 249 / 199 / 399 / 1,299 |
| Pass card: TRY | One-zone-session tool trials, 15 min: Auto-Pop Aura / 2x Coins / Golden Dart | 9 / 15 / 19 |
| Pass card: GIFT | A gift copy of every pass (same price; pick a player in the server, kit LiveUI.gift) | 199-1,299 |
| Items | Welcome Deal (once, never-bought players only: coins + 10 Mega Darts, kit `intro`) | 9 |
| Items | Starter Pack (once, first 10 min: coins + 15 Mega Darts + 30 min Lucky Boost, kit `window`) | 49 |
| Items | 10 / 50 Mega Darts | 25 / 99 |
| Items | Lucky Boost 15 min (x2 luck, stacks time, random) | 49 |
| Items | Summon MEGA Balloon now (summoner 2x reward + fixed rare burst) | 99 |
| Server (15 min, everyone, kit Boosts + shoutout) | 2x / 4x (needs 2x) / 8x (needs 4x) / 16x (needs 8x) Coins | 99 / 249 / 499 / 999 |
| Server | 2x / 4x (needs 2x) Luck (random) | 149 / 399 |
| Coins | Pile / Bag / Chest / Vault / Mountain (scale with best zone + rebirths) | 49 / 149 / 399 / 999 / 1,999 |

32 catalog items (6 passes, 26 products). Server coin boosts multiply all pop, boss, MEGA and coin-rain income (`Progress.income` = server boost x `Live.friendMult`); luck boosts multiply spawn luck. Premium perk: +10% coins.

**Live-ops (kit Live, `Config.Live`):** 🎁 FREE button (left grid, badge = claimable count): code `LAUNCH` (coin bag + 5 Mega Darts), group gift (group id 0 until the group exists), playtime gifts at 5 / 10 / 30 / 60 min, 3 daily quests from 8 (pop 150, 3 Rare+, hit the MEGA, a MEGA round with a friend in the server, 5 upgrades, collect the pump, 5 Mega Darts, 25 bumps), invite reward for both players, +10% coins per friend in the server. Badges (ids 0): Welcome, FirstRare, MegaPop, ZoneBoss, Secret, Rebirth, Factory. MEGA BALLOON every 5 min (+ purchasable summons, queued); **HOURLY MEGA** at :00 (`Live.onHour`): 1.35x size, 3x HP and reward, 100 rain coins, 36-balloon shower and 10 min of 2x coins for the server. Boost pill above the goal bar shows running server boosts. Next Saturday updates: (1) Ocean Reef zone, (2) Halloween ghost balloons + pumpkin MEGA, (3) dart skins + trails shop, (4) weekly Secret hunt with a global counter, (5) difficulty modes + perk cards, (6) helper-bird pets.

**Art bible**
- Palette (house five): ground `#8EE06A` (meadow lawn), structure `#FFF4E0` (cream), accent `#FF4D6D` (balloon red-pink), rare glow `#FFD23F` (gold), UI `#4CC9F0` (sky blue). Zone palettes: Candy `#FFB3D9 #A8F0D8 #8B5A3C #FFE66D #CDB4FF`, Sky `#F4FAFF #BDE6FF #FFD86B`, Space `#5B3FA8 #3B2A7A #4DF0FF #FF5CD6`.
- Lighting preset **A** (bright cartoon day), clouds Cover 0.62, CC +0.06 brightness / 0.22 saturation; the client tints Atmosphere/ColorCorrection/clock per zone (Space Rainbow goes to a violet dusk).
- Materials: house HouseGrass / HouseSand / HouseSlabs on the big flat Meadow surfaces; game variants (materials.json): CandyFrosting, CloudFluff, StarDust. Everything else SmoothPlastic palette parts, Neon for glow, Glass for crystal/UFO domes.
- Mesh sources: our own chunky primitives everywhere (one source for the whole world). Hero mesh slot `Config.Meshes.balloon` (AI "smooth round party balloon" mesh) replaces the round body when generated; the primitive balloon (stretched sphere + knot + string + shine) ships.
- **Hero assets:** 28 balloon types + the MEGA BALLOON (BalloonArt: round / heart / star / cluster / donut / cupcake / lollipop / ringed planet / UFO / hot-air / bunch / crystal, faces, stripes, dots, wings, halos, tails), the Mega Pump stage (landmark visible from spawn), 4 Party Bots, the Balloon Pumps, zone gates, floating island clusters with bridges.

**Twist vs the proof game:** a clicker-simulator where the thing you click floats, dodges into crowds and explodes into confetti, and every 5 minutes the whole server pops one giant balloon together.
