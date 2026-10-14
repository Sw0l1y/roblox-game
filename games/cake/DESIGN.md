# Cake Off! 🎂 — Decorate the Cake!

**Proof:** market research row 6 — a craft sim with creative output + voting. Dress To Impress proves the
"make something to a theme, everyone votes" audience; the bakery/cake version has 0-1 entrants per job.
**Twist vs the proof game:** instead of dressing an avatar you decorate a real 3D cake (tiers, frosting, drips,
piping, 45 toppings placed by tapping the cake), it spins on a turntable while the server votes, and the
winning cake grows giant on the plaza. Decorating is preset-only (no freehand drawing): colours paint whole
tiers, piping is a preset rim of icing balls along each tier edge in a chosen colour, and toppings are preset 3D
models snapped to the tapped surface point (size S/M/L, 8 turn steps, optional tint).
The in-game title always comes from `Config.Title` (`Config.titleCaps()` for banners/signs), so a rename (likely
"Cake Wars! 🎂") is one line; the DataStore name stays `CakeOff_v1`.

```
Title / tagline   Cake Off! 🎂 — "Decorate the Cake!"   (Config.Title)
Core verb         decorate          Server size: 12        Maturity target: Minimal
Session loop (30 s)   tap a frosting colour, tap toppings onto your cake, spin it, press DONE; rate the next cake
Progress loop (1 day) coins + XP every round → unlock toppings/colours/shapes/4th tier/slots, level titles,
                      Mystery Sprinkle Boxes, Topping Index (45) with box milestones, 7-day daily treats,
                      daily quests, playtime gifts, Caketober candy track
Meta loop (28 days)   complete the Index (Legendary/Mythic/Secret only from boxes), wins + best score on the
                      leaderboard, baker titles to Lv 50 "Grand Patissier", Golden Oven flex, 6 badges
Public display        every cake is built live at a station ring around the stage, then shown on the turntable
                      to the whole server; podium + giant winner cake; baker tag "🏆 👑 🎃 Lv 12 · Pastry Pro"
Social hook           everyone votes 1-5 ⭐ on everyone else (3 💰 per vote, +2 💰 "fair judge" bonus); paid
                      reactions cheer the cake on show (coins for its baker); server boosts with shoutouts;
                      "Pick next theme"; +30 s Build Time pass shared with the server; gift any pass
Clip moment           the winning cake grows 3x giant in the middle of the plaza with fireworks, camera swoop
```

**Round loop (~4 min):** Lobby 10 s (first round 14 s after the first join) — **warm-up**: your station is
already open, you decorate while you wait and the cake carries into the round → Theme reveal 6 s (spinner,
idea glyphs; still warm-up) → Build **150 s** (FIXES B.5: 100 s felt rushed; DTI 360 s, Style Showdown 180 s;
+30 s pass; ends early when every baker pressed DONE after 25 s) → Vote: each cake 5-7 s on the turntable,
everyone rates 1-5 ⭐, 3 NPC judges lift score paddles → Results 6 s (podium, coins/XP card) → Giant cake 8 s.
NPC bakers fill up to 4 cakes so solo play always has a contest.
**Overtime (paid, personal, 39 R$):** a baker with an Overtime ticket keeps their station open after the bell
for up to +60 s while the first cakes are judged (own camera + tray, vote UI hidden); their cake is shown last
and judged as it stands when its slot starts. The +60 s button sits above the tray in the last minute of the
build (or "⏰ OVERTIME READY ✔" when a ticket is held).
**Troll-proof voting:** with 4+ human voters the highest and lowest human vote are dropped; a vote within
±1 ⭐ of the final score earns +2 💰 "fair judge" (cap 12/round); 1-star votes on cakes that end at 3.5+ give a
strike, and after 3 strikes that voter's votes weigh 0.3x for the session (with a toast). Judges weight 1 with
<3 voters, 0.6 with <6, 0.35 otherwise; reactions never touch the score.
**Celebrity Judge round** every 10 min: gold stage lights, Chef Gateau joins the table (2x vote weight), a
special theme, **2x coins and XP**, winner gets a box. **Hourly Grand Gala** (kit Live.onHour, at :00): the
next round is a Celebrity round with **3x** rewards, boxes for the top 3 (winner 3), 2x candy, the Haunted
Gala theme during Caketober, and a free 10-minute **server 2x coins** boost (kit Boosts). HUD chip counts down
to whichever comes next.

**FTUE (first 60 s):** 0-3 s: "🎂 CAKE OFF!" banner (from Config.Title); a brand-new player is taken to their
bakery once and the tray opens on the warm-up cake (the station is open in Lobby/Theme/Build), tip "Tap a colour
to frost your cake". ≤10 s: first decorating tap (core verb). ≤30 s: the first decorating tap pays **+25 💰**
and the first topping another +25 💰 (one-time FTUE rewards, coin fly-in). ~40 s (≤55 s even mid-show): the
**welcome gift** — the free welcome box opens itself with a "🎁 WELCOME GIFT!" reveal, guaranteed **Rare+**.
No purchase prompt or offer popup in the first 2 minutes of the first session: locked pass items open the Shop
instead of a prompt, the +60 s and reaction buttons are hidden, offers wait. Starter offer pops once at the
first lobby after 2.5 min, only inside the first 10 min of the first session (HUD 🧁 countdown; kit Shop
`window = 600` refuses it after). Late joiners mid-build get up to +30 s grace (server-wide, capped per round).

**Economy:** coins only (+ Caketober candy 🍬 during the event). Earn: 25 participation + 25/⭐ + place bonus
(100/60/30) per round (x2 Celebrity, x3 Gala, x server coin boost, x1.1 with a friend in the server, x2 pass,
x1.2 VIP), 3 per vote (cap 12 votes/round) + fair-judge bonus, daily 50-400, quests 250-500, playtime gifts,
box duplicates refund. Sinks: toppings (75-3,200), 12 colours (60-220), shapes Heart/Hexagon/Star
(300/600/1,500), 4th tier 500, topping slots 350/750/1,500, boxes 300. Rarities: Common → Secret (glow from
Legendary; Legendary+ unbox = server announce). **Box odds** are shown as live % in the Box menu and on every
box-only Index card, with the current luck (Lucky Sprinkles 2.5x x server luck boost) and the base odds side by
side; secret tiers show their % too (base Uncommon 50%, Rare 30%, Epic 14%, Legendary 4.9%, Mythic 1%, Secret
0.1%).
**Paid random policy (kit Policy):** Mystery Boxes (Robux), Lucky Sprinkles and server luck boosts are
`random = true`. Players under the paid-random restriction (RandomBlocked, default until the lookup clears) never
see them; boxes they already bought open as 300 coins; the coins→box button is refused; the Starter Pack shows
and grants a fixed 3,500-coin pack instead of boxes; Caketober box rewards pay coins. Free boxes (welcome,
daily, milestones, quests) still roll for everyone.

**Money ladder (Robux; all ids 0 until created, live prices via kit Prices):**
- Deals: **Baker's Treat 9** (2,000 coins + Mini Cupcake; first purchase only, kit `intro`), **Starter Pack 49**
  (2,000 coins + 3 boxes; first 10 min only), **250,000 Coins First-Time Deal 1,199** (once).
- Server boosts (15 min, everyone, shoutout, kit Boosts pill): 2x XP 79 · 2x Coins 99 · Full Bakery Party 199
  (2x coins + 2x XP) · 4x Coins 249 (needs 2x running) · 8x Coins 499 (needs 4x) · Server Lucky Sprinkles 149 ·
  Server Super Luck 349 (needs 2x luck).
- This round: Sprinkle Burst 29 · Golden Spatula 39 · Chef's Kiss 49 (reactions: FX + 50/100/150 coins for the
  baker on show, saved as credits otherwise) · Overtime +60 s 39 · Pick Next Theme 49.
- Coins: 1,000 / 6,000 / 18,000 / 45,000 / 110,000 / 250,000 for 25 / 99 / 249 / 499 / 999 / 1,999.
- Boxes: 1 box 29 · Lucky Sprinkles 15 min 39 · 5 boxes 119 · 15 boxes 299 (all paid random).
- Caketober: +1 / +5 / +10 tiers for 29 / 119 / 199.
- Passes: Rainbow Frosting 79 · Premium Colours 99 · Topping Tray+ 99 · +30 s Build Time (server) 149 ·
  2x Coins 249 · VIP Bakery 299 · **Caketober Pass 399** · **Golden Oven 1,299** — each with a 🎁 GIFT copy
  (same price) next to it on the Passes tab.

**Live-ops:** kit Live — code LAUNCH (500 coins + 1 box), group gift (id 0 until the group exists), playtime
gifts at 5/10/30/60 min, 3 daily quests from 8 (bake, rate, top 3, ⭐ 4+, toppings, 🎯 theme toppings, bake with a
friend, Celebrity round), badges Welcome/FirstCake/FirstWin/StarBaker/TenWins/Collector (ids 0), invite reward,
+10% coins with a friend in the server; 🎁 FREE menu button with a claimable count. Hourly Grand Gala + Celebrity
every 10 min.
**Caketober (until 2026-11-03):** 30-tier candy track (100 🍬 per tier; candy from rounds, votes, quests,
playtime, 2x in the Gala). Free row: coins, boxes, Candy Eyes 👀, Little Bat 🦇, Pumpkin Spice frosting, Jelly
Spider 🕷️. Pass row: coins + Slime/Witch Purple frostings, Sugar Web 🕸️, Witch Hat 🧙, Bubbling Cauldron 🍲,
Haunted Moon 🌙, 🎃 name tag. Spooky theme and the Haunted Gala use the event items.
Next Saturdays: 1 Holiday themes pack · 2 Topping set "Under the Sea II" · 3 Team bake · 4 Weekly trophy ·
5 Turntable skins · 6 Seasonal Celebrity.

**Art bible:** cozy bright bakery-street plaza. Palette: cream `#FFF4E0` (ground/tiles), strawberry pink
`#FFB3C7` (structure/awnings), mint `#A8E6CF` + sky `#A0D8F7` (accents), chocolate `#6B4226` (trim/drips),
gold `#FFCD46` (rare glow/UI highlight). Lighting: preset **A (bright cartoon day) toned down for pastels** —
ClockTime 15.2, sun 2.3, exposure -0.1, lower ambient, clear blue-lavender haze (0.5), colour correction with no
added brightness (+0.16 contrast, +0.3 saturation), white clouds; no sky ids. Big flats stay off pure white
(plaza checker `#FCECD6` / `#FFC8DA`): near-white surfaces clip to white in Roblox's sun.
Materials: SmoothPlastic palette parts; 3 generated variants on big flats only (`CakeTile` checker floor,
`CakeWood` counters/station floors, `CakeStreet` paving) + kit `HousePanels` on shop facades; flat fallback =
checker tiles drawn from parts. Mesh sources: our own chunky primitives for everything structural; hero AI meshes
(prompts in Config.Meshes, primitive fallbacks already ship): Strawberry, Mini Cupcake, Royal Crown, Fairy
Castle, Unicorn Horn, Sugar Swan, Golden Trophy. Hero list: player cakes (multi-tier, rims, drips, piping,
glossy toppings), the landmark cake on the CAKE OFF! arch, 3 judges + celebrity chef, 12 bakery stations
(striped awnings, ovens, counters), giant cupcakes, candy-cane spawn arch.
