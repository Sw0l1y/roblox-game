# Cake Off! 🎂 — Decorate the Cake!

**Proof:** market research row 6 — a craft sim with creative output + voting. Dress To Impress proves the
"make something to a theme, everyone votes" audience; the bakery/cake version has 0-1 entrants per job.
**Twist vs the proof game:** instead of dressing an avatar you decorate a real 3D cake (tiers, frosting, drips,
piping, 38 toppings placed by tapping the cake), it spins on a turntable while the server votes, and the
winning cake grows giant on the plaza.

```
Title / tagline   Cake Off! 🎂 — "Decorate the Cake!"
Core verb         decorate          Server size: 12        Maturity target: Minimal
Session loop (30 s)   tap a frosting colour, tap toppings onto your cake, spin it, press DONE; rate the next cake
Progress loop (1 day) coins + XP every round → unlock toppings/colours/shapes/4th tier/slots, level titles,
                      Mystery Sprinkle Boxes, Topping Index (38) with box milestones, 7-day daily treats
Meta loop (28 days)   complete the Index (Legendary/Mythic/Secret only from boxes), wins + best score on the
                      leaderboard, baker titles to Lv 50 "Grand Patissier", Golden Oven flex
Public display        every cake is built live at a station ring around the stage, then shown on the turntable
                      to the whole server; podium + giant winner cake; baker tag "🏆 👑 Lv 12 · Pastry Pro"
Social hook           everyone votes 1-5 ⭐ on everyone else (3 🪙 per vote); "Pick next theme" for the server;
                      +30 s Build Time pass is shared with the whole server ("thanks to <name>!")
Clip moment           the winning cake grows 3x giant in the middle of the plaza with fireworks, camera swoop
```

**Round loop (~3 min):** Lobby 10 s (first round 14 s after the first join) → Theme reveal 6 s (spinner, idea
glyphs; players run to their station along a pink beam) → Build 100 s (+30 s pass; ends early when every baker
pressed DONE) → Vote: each cake 5-7 s on the turntable, everyone rates 1-5 ⭐, 3 NPC judges lift score paddles
(weight 1 when <3 voters, 0.6 <6, 0.35 otherwise) → Results 6 s (podium teleport, confetti, coins/XP card,
server announce) → Giant cake 8 s. NPC bakers fill up to 4 cakes so solo play always has a contest.
**Celebrity Judge round** every 10 min: gold stage lights, Chef Gateau joins the table (2x vote weight), a
special theme (Royal Banquet, Galaxy Gala, Unicorn Dream, Golden Gala), **2x coins and XP**, winner gets a box.
HUD countdown "🌟 Celebrity Judge in 7:12" all the time.

**FTUE:** 0-10 s: spawn under the candy-cane arch facing the stage + landmark cake; "🎂 CAKE OFF!" banner; tip
"your bakery has the pink beam". ≤20 s: first theme reveal; beam + "GO TO MY BAKERY" button; build mode opens
by itself at the station. 30 s: tips walk through frost → toppings → DONE (5 free toppings, 6 free colours,
3 tiers). ~2.5 min: first results card with coins fly-in (first coins). Then: the free welcome box pulses — the
first box is guaranteed **Rare+** (first rare moment) and the 🎯 next-goal chip shows the cheapest unlock.
Late joiners mid-build get up to +30 s grace (server-wide, capped per round).

**Economy:** coins only. Earn: 25 participation + 25/⭐ + place bonus (100/60/30) per round (x2 Celebrity,
x2 pass, x1.2 VIP), 3 per vote (cap 12 votes/round), daily 50-400, box duplicates refund. Sinks: 25 toppings
(75-3,200), 12 colours (60-220), shapes Heart/Hexagon/Star (300/600/1,500), 4th tier 500, topping slots
350/750/1,500, boxes 300. Rarities: Common, Uncommon, Rare, Epic, Legendary, Mythic, Secret (glow particles from
Legendary; Legendary+ unbox = server announce). Box odds shown numerically in the Box menu (Uncommon 50%, Rare 30%,
Epic 14%, Legendary 4.9%, Mythic 1 in 100, Secret 1 in 1,000). Judges score effort, variety, theme match,
structure and rarity, so unlocks matter but taste wins.

**Money ladder (§6):** Coins 1k/6k/18k (R$25/99/249), Mystery Box 1/5 (29/119), Lucky Sprinkles 15 min (39),
Pick Next Theme (49), Starter Pack once (49: 2,000 coins + 3 boxes, offered once after 5 min, never mid-round),
Rainbow Frosting (79), Premium Colours (99: Gold, Silver, Rose Gold, Pearl, Galaxy, Electric), Topping Tray+
(99: +12 slots), +30 s Build Time for the whole server (149), 2x Coins (249), VIP Bakery (299: 3 VIP toppings,
chat tag, +20% coins), **Golden Oven (1,299 flex:** golden station + sparkle aura + tag, +25% XP).

**Live-ops (Saturdays):** 1 Holiday themes pack · 2 Topping set "Under the Sea II" · 3 Team bake (2 per cake) ·
4 Weekly trophy for top score · 5 Cake skins for the turntable · 6 Seasonal Celebrity (guest chef rotation).
Recurring event: Celebrity Judge round every 10 minutes.

**Art bible:** cozy bright bakery-street plaza. Palette: cream `#FFF4E0` (ground/tiles), strawberry pink
`#FFB3C7` (structure/awnings), mint `#A8E6CF` + sky `#A0D8F7` (accents), chocolate `#6B4226` (trim/drips),
gold `#FFCD46` (rare glow/UI highlight). Lighting: preset **A (bright cartoon day) tuned warm** — ClockTime 15.2,
pink-cream atmosphere haze, warm colour correction (+0.08 brightness, +0.22 saturation), soft clouds; no sky ids.
Materials: SmoothPlastic palette parts; 3 generated variants on big flats only (`CakeTile` checker floor,
`CakeWood` counters/station floors, `CakeStreet` paving) + kit `HousePanels` on shop facades; flat fallback =
checker tiles drawn from parts. Mesh sources: our own chunky primitives for everything structural; hero AI meshes
(prompts in Config.Meshes, primitive fallbacks already ship): Strawberry, Mini Cupcake, Royal Crown, Fairy
Castle, Unicorn Horn, Sugar Swan, Golden Trophy. Hero list: player cakes (multi-tier, rims, drips, piping,
glossy toppings), the landmark cake on the CAKE OFF! arch, 3 judges + celebrity chef, 12 bakery stations
(striped awnings, ovens, counters), giant cupcakes, candy-cane spawn arch.
