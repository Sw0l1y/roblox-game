# Pop All The Balloons! 🎈 — playtest checklist

Build: `python3 build.py balloons`, open `balloons.rbxlx` in Studio, Play (F5). Run debug commands from the
**server** command bar: `print(game.ServerStorage.DebugCmd:Invoke("state"))`. The player argument is optional
(defaults to the first player; `me` works too). Headless: `node tools/sim/run.mjs balloons --debug "give 1000000;event;buy SummonMega;clip;buy MegaDarts;buy VIP;rare;state"`.

## Debug commands (ServerStorage.DebugCmd, Studio only)
| Command | What it does |
|---|---|
| `help` | lists the commands |
| `state` | balloons per zone, MEGA phase / HP / next time, and every player's coins, pops, zones, rebirths, power, luck, aura, Mega Darts, pump, Index count, current zone |
| `give 1000000` / `give [player] coins n` | coins (also `megadarts n`, `pops n`) |
| `event` | MEGA BALLOON countdown now (5 s instead of 30) |
| `clip` | skip to the clip moment: Mega Balloon pops in 1.5 s (coin rain + rare shower) |
| `reset [player]` | wipe the save back to defaults (keeps passes) |
| `spawn <key> [player]` | spawn a balloon type next to the player (keys: red polka striped heart star golden rainbow gumdrop ... cosmic) |
| `rare [player]` | spawn the Secret of the zone you are in, right in front of you |
| `zones [player] n` | set unlocked zones (1-4) |
| `index [player]` | fill the Index with every non-Secret type |
| `upgrade [player] key n` | set an upgrade level (power, speed, aura, luck, walk); no n = max |
| `rebirth [player]` | give the rebirth cost and rebirth |
| `daily [player]` | make the daily gift claimable again |
| `pump [player] seconds` | fill the Balloon Pump as if this many seconds passed (default 1 h) |
| `luck [player] minutes` | Lucky Boost on |
| `tp [player] zone` | teleport to a zone (1-4) |
| `pass [player] key` | grant a pass (Coins2x, Aura, Lucky, VIP, GoldenDart) |
| `buy [player] key` | run the real purchase path for a pass or product (Studio simulates id-0 purchases): MegaDarts, LuckBoost, SummonMega, Starter, Coins1-3, or any pass key |

## FTUE (fresh save: `reset`, then rejoin)
- [ ] Spawn on the Meadow pad facing the hub; the Mega Pump stage and the "POP ALL THE BALLOONS!" sign are in view, Candy Hills floats in the distance.
- [ ] ~7 easy balloons rise from the ground around you; the goal bar says "Click/Tap a balloon" and a gold beam + bouncing arrow point at the nearest one.
- [ ] Click a balloon: arm swings, dart flies, balloon pops instantly with confetti + pop sound, "+2" popup, coins fly into the top counter. First pop < 5 s.
- [ ] Hold the mouse (or finger): darts keep flying at your throw speed; with nothing under the pointer it picks the nearest balloon ahead.
- [ ] Run into small balloons: they wobble and pop (bump).
- [ ] By ~30 s you have 30 coins: the Upgrades button pulses with an arrow, goal says "buy your first upgrade". Buying shows a floater + sparkle.
- [ ] ~42 s: "A Rare Striped Balloon appeared right next to you!" with a sparkle; beam points at it; it has a RARE label + HP bar; only you can pop it for 20 s. Pop → RARE banner, sound, "NEW! ... added to your Index" toast, Index badge.
- [ ] 2:30 on a new server: MEGA BALLOON countdown (see below). No purchase prompt before minute 4; the Starter Pack offer appears once after 4 min (never during the event).

## Core loop
- [ ] Rare+ balloons have tier labels with gradients (Secret = animated rainbow), Legendary+ have a sky beacon and a server-wide announcement when they spawn; Mythic+ pops are announced.
- [ ] Big balloons (Rare+) show an HP bar that drops per dart; mispredicted pops come back within ~1.5 s (should be rare).
- [ ] Upgrades panel: 5 rows, level, current → next, price turns green when affordable; MAX at max. Walk Speed changes your speed immediately.
- [ ] Pop Aura (upgrade or pass): lilac ring at your feet, nearby small balloons pop with a zap line; pass also pops big ones.
- [ ] `give 1000000`: Zones badge; goal bar points the beam at the Candy Hills gate; hold E on the gate prompt → zone unlocked banner, the wall disappears for you only, cross the bridge. Sky tint changes per zone (Space Rainbow = violet dusk) with a zone banner.
- [ ] A friend without the zone cannot pass the gate wall; if pushed past they are teleported back with a toast.
- [ ] Zones panel: TELEPORT for unlocked zones, price for the next one, LOCKED after.
- [ ] Index: 4 zone tabs, 7 cards each with 3D preview (black silhouette until found), name ??? until found, tier label, numeric odds ("1 in 370"), pop count; locked zones covered; header shows the set bonus. `index` → set complete celebration for each zone? (completion happens on the first pop of the last type; use `spawn` to test).
- [ ] Rebirth (`rebirth`): coins reset to 0, x1.5 coins shown, upgrades/zones/Index kept.
- [ ] Daily gift (`daily`): button shows Claim! badge; panel shows 7 days; claim → banner, coins, day 3/7 Mega Darts, day 5 Lucky Boost.
- [ ] Balloon Pump: your pump in the ring around the hub has your name and a balloon that grows; `pump 3600` then walk up, press E → coins. Other players' pumps refuse you politely.
- [ ] Offline: leave, wait > 1 min (or edit lastSave), rejoin → "Welcome back" card with pump earnings.

## MEGA BALLOON event (`event`, then `clip`)
- [ ] Pill under the coins counts down "MEGA BALLOON in m:ss" all the time.
- [ ] Countdown: banner + toast, the Mega Balloon inflates on the Mega Pump nozzle, 5-4-3-2-1 banners with beeps; guide beam points to the hub if you are far.
- [ ] Rise: it grows and floats up to the hub sky; the big HP bar appears (rainbow fill).
- [ ] Fight: clicks anywhere near it hit it (or hold); 4 Party Bots throw darts too (solo servers pop it in ~25 s); it over-inflates and shakes as HP drops; Mega Darts take big chunks with a boom.
- [ ] Pop: huge confetti burst, shockwaves, flash, camera shake, cheer + victory, "MEGA POP!" banner, reward toast with your damage %, 60 gold coins rain onto the plaza (walk through them: popup + fly to HUD), 18 rare BONUS balloons fly out and land around the plaza (pay 2x, vanish after ~30 s).
- [ ] Shop → Summon MEGA Balloon (Studio test purchase): server toast "X summoned a MEGA BALLOON!", 12 s countdown; summoner gets 2x reward; a second summon queues.

## Shop (Studio simulates every purchase; ids are 0)
- [ ] Passes tab: 2x Coins, Auto-Pop Aura, Lucky Darts, VIP (👑 head tag + [👑 VIP] chat prefix + gold darts), Golden Dart (golden glowing darts, x3 power) → OWNED after buying, celebration banner.
- [ ] Boosts tab: 10 Mega Darts (right column 💥 badge; tap to arm → ON!, next dart is a big red Mega Dart with splash), Lucky Boost (Boost button shows the timer), Summon MEGA, Starter Pack (disappears after buying).
- [ ] Coins tab: amounts scale with your best zone and rebirths.

## Robustness
- [ ] Reset the character (Esc → Reset): HUD, aura ring, guide beam and arm swing come back.
- [ ] Fall off an island: teleported back to the zone with a toast.
- [ ] Mute button toggles music and sounds.
- [ ] Leave and rejoin: coins, upgrades, zones, Index, rebirths, Mega Darts, passes persist.
- [ ] Two players: both get coins for a shared big balloon (popper 100%, helpers 50%); darts of others are visible.
