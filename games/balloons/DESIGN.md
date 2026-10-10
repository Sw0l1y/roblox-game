# Pop All The Balloons! 🎈

**Tagline:** "Throw darts. Pop EVERYTHING. Float all the way to space."  (formula: "[Verb] All The [Noun]!")

| | |
|---|---|
| **Core verb** | POP: tap/click a balloon to throw a dart (aim assist, hold to keep throwing), or run into small ones |
| **Server size** | 12 · **Maturity target:** Minimal |
| **Session loop (30 s)** | Pop the balloons floating up around you → confetti + coins fly to the HUD → buy an upgrade (power / throw speed / aura / luck / walk) → a rarer balloon with a label and HP bar appears → pop it for a big payout and a new Index entry |
| **Progress loop (1 day)** | Unlock zones with coins (Meadow → Candy Hills 1K → Sky Islands 40K → Space Rainbow 1M), max upgrades, complete each zone's Index set (+10/15/20/25% coins forever), Rebirth (25M, x2.5 cost each) for +0.5x coins permanently |
| **Meta loop (28 days)** | Find all 4 Secrets (1 in 3,333 each, +10% coins each), rebirth ladder, 7-day gift streak (Mega Darts day 3/7, Lucky Boost day 5), Balloon Pump offline earnings (up to 8 h) |
| **Public display** | Leaderstats (Coins, Pops, Rebirths), billboard rarity labels with tier gradients, sky beacons over Legendary+ balloons, server-wide announces for Legendary+ spawns and Mythic+ pops, named Balloon Pumps around the hub, 👑 VIP tag over the head and in chat, gold / golden darts |
| **Social hook** | Everyone damages the same balloons (helpers get 50% of the coins), everyone attacks the MEGA BALLOON together, anyone can buy "Summon MEGA Balloon now" for the whole server |
| **Clip moment** | **MEGA BALLOON** (every 5 min, first one 2.5 min after a server starts): banner + 30 s countdown while it inflates on the hub's Mega Pump → it rises with a server-wide HP bar → players + 4 Party Bots throw darts, it over-inflates and shakes → it EXPLODES into a coin rain over the plaza and a shower of 18 rare balloons (Rare→Secret) |

**FTUE:** 0-10 s spawn on the Meadow facing the hub and the Mega Pump; 7 easy balloons rise around you, goal bar + beam point at the nearest one, first pop < 5 s. 30 s: Dart Power costs 30 coins (≈15 pops); the Upgrades button pulses with an arrow. ~45 s: a seeded Rare (reserved for you) rises right next to you with a sparkle + beam; ~110 s a seeded Epic if you missed it. 2.5 min: first MEGA BALLOON on a new server (the "wow"), then the goal bar shows the next zone gate with a progress bar. No purchase prompt before minute 4 (one-time Starter Pack offer, never during the event).

**Economy:** one currency (coins 🪙). Sinks: upgrades (5 tracks, geometric costs), zone gates, rebirth. Value = tier value x zone value multiplier (x1 / x10 / x120 / x1,000) x coin multiplier (rebirth, 2x pass, VIP 1.25, Premium 1.1, Index set bonuses). HP x zone HP multiplier (x1 / x5 / x40 / x300).
Tiers (kit `Tiers`), spawn weights per zone with numeric odds shown in the Index (base luck; luck shifts weight toward rarer tiers):

| Tier | Odds | HP / value (Meadow) | Meadow | Candy Hills | Sky Islands | Space Rainbow |
|---|---|---|---|---|---|---|
| Common | 60% | 1 / 2 | Red | Gumdrop | Cloud | Moon |
| Uncommon | 25% | 2 / 5 | Polka | Bubblegum | Sunny | Ringed Planet |
| Rare | 10% | 6 / 18 | Striped | Lollipop | Hot Air | UFO |
| Epic | 1 in 28 | 15 / 60 | Heart | Cupcake | Balloon Bunch | Comet |
| Legendary | 1 in 91 | 40 / 250 | Star | Donut | Thunder | Galaxy |
| Mythic | 1 in 370 | 100 / 1,200 | Golden | Cotton Candy | Angel | Rainbow Star |
| Secret | 1 in 3,333 | 250 / 10,000 | Rainbow | Sugar Crystal | Phoenix | Cosmic |

Rare+ have labels; Rare+ are "big" (HP bar; the aura only pops small ones unless you own the Aura pass). Mutation layer: none (no pets per spec); the MEGA shower balloons pay 2x at your best zone's rate. Rebirth: yes.

**Money ladder (PROTOCOL §6; ids 0 until created):**

| Slot | Item | R$ |
|---|---|---|
| Impulse | 10 Mega Darts (x25 splash damage) | 25 |
| Repeatable | Lucky Boost 15 min (x2 luck, stacks) | 49 |
| Starter pack (once) | coins + 15 Mega Darts + 30 min Lucky Boost | 49 |
| Server product | Summon MEGA Balloon now (summoner gets 2x reward) | 99 |
| 2x core currency | 2x Coins | 299 |
| Convenience | Auto-Pop Aura (bigger, faster, pops big balloons) | 249 |
| Luck | Lucky Darts (x1.5 luck forever) | 199 |
| VIP | +25% coins, gold darts, 👑 chat + head tag, 2x daily gift | 399 |
| Flex | Golden Dart (x3 power, golden darts + trail) | 1,299 |
| Repeatables | Pile / Bag / Chest of Coins (scale with best zone + rebirths) | 49 / 149 / 399 |
Premium perk: +10% coins.

**Live-ops:** MEGA BALLOON every 5 min (+ purchasable summons, queued). Six Saturday updates: (1) Ocean Reef zone (bubble + jellyfish balloons), (2) Halloween ghost balloons + pumpkin MEGA, (3) dart skins + trails shop, (4) weekly Secret hunt with a global counter, (5) Boss Balloon that splits into smaller balloons, (6) daily quests + pops leaderboard board in the hub.

**Art bible**
- Palette (house five): ground `#8EE06A` (meadow lawn), structure `#FFF4E0` (cream), accent `#FF4D6D` (balloon red-pink), rare glow `#FFD23F` (gold), UI `#4CC9F0` (sky blue). Zone palettes: Candy `#FFB3D9 #A8F0D8 #8B5A3C #FFE66D #CDB4FF`, Sky `#F4FAFF #BDE6FF #FFD86B`, Space `#5B3FA8 #3B2A7A #4DF0FF #FF5CD6`.
- Lighting preset **A** (bright cartoon day), clouds Cover 0.62, CC +0.06 brightness / 0.22 saturation; the client tints Atmosphere/ColorCorrection/clock per zone (Space Rainbow goes to a violet dusk).
- Materials: house HouseGrass / HouseSand / HouseSlabs on the big flat Meadow surfaces; game variants (materials.json): CandyFrosting, CloudFluff, StarDust. Everything else SmoothPlastic palette parts, Neon for glow, Glass for crystal/UFO domes.
- Mesh sources: our own chunky primitives everywhere (one source for the whole world). Hero mesh slot `Config.Meshes.balloon` (AI "smooth round party balloon" mesh) replaces the round body when generated; the primitive balloon (stretched sphere + knot + string + shine) ships.
- **Hero assets:** 28 balloon types + the MEGA BALLOON (BalloonArt: round / heart / star / cluster / donut / cupcake / lollipop / ringed planet / UFO / hot-air / bunch / crystal, faces, stripes, dots, wings, halos, tails), the Mega Pump stage (landmark visible from spawn), 4 Party Bots, the Balloon Pumps, zone gates, floating island clusters with bridges.

**Twist vs the proof game:** a clicker-simulator where the thing you click floats, dodges into crowds and explodes into confetti, and every 5 minutes the whole server pops one giant balloon together.
