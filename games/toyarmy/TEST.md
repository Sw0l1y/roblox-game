# Toy Army ⚔️: Studio playtest checklist

Build `python3 build.py toyarmy`, open `toyarmy.rbxlx`, then Play (1 player) or Start Server with 2-3 players
(players are split Green / Tan; an AI commander fills an empty or out-numbered team).
Debug commands only work in Studio. Run them from the server command bar:
`game.ServerStorage.DebugCmd:Invoke("state")`. `[p]` is an optional player name; with no name (or an unknown one)
the command applies to every player.

| Command | What it does |
|---|---|
| `help` | lists every command |
| `state` | one line: every zone (owner, garrison size, power, `*` = fighting), each player's side, plastic, units, busy, tutorial step, rank, FTUE timings and `randomBlocked`, the cat's status, server boosts, strikes fired, the AI modes |
| `ftue [p]` | seconds from join to first deploy, first reward, when the free gift is ready and when it was claimed |
| `hourly` | the hourly event now: HOURLY MEGA CAT + 10 min server 2x plastic |
| `strike rockets [zone] [p]` | fires a paid strike for that player (`rubber`, `balloon`, `callcat`, `rcplane`, `rockets`, `flashlight`, `dog`) at the zone or the auto-picked target |
| `boost plastic 4 [min]` · `boost luck 2` | a server-wide boost (as if bought) |
| `skin skinGold [p]` · `skin none` | equips an army skin / tank paint (`skinPumpkin`, `skinCamo`, `skinChrome`, `skinGold`, `tankLava`) |
| `pass skinChrome [p]` | grants a pass (simulated purchase in Studio) |
| `policy on [p]` · `policy off` | pretend the paid random item rule applies (`RandomBlocked`) |
| `bag Basic [p]` | buys a bag with plastic and lists what came out (fixed contents while `policy on`) |
| `give 1000000` · `give xp 500` · `give bags 10` | plastic (raw, no multipliers), XP, or free Bags of Soldiers |
| `give unit Tank Gold 3` | add units (`Rifleman`, `Bazooka`, `Medic`, `Tank`, `Heli`, `General`, `Dino`; mutation `Gold`, `Glow`, `Rainbow` or none) |
| `event` / `cat` | the house cat wakes up now and runs its full route (jump off the bed, walk, swat the two busiest zones) |
| `clip` | instant swat on the busiest zone (no walk): records the toys-flying clip |
| `call [p]` | the "Call the Cat!" product for that player (cat goes for their enemies; queued if it is already out) |
| `topple` | knocks the letter-block tower over on every client (it rebuilds after 24 s) |
| `round` | ends the war round now and pays it |
| `supply [p]` | the Supply Drop (guaranteed Tank) is ready now |
| `merge [p]` | finishes every merge in the mold press |
| `rank [p] 5` | raises XP to that rank (1-11) |
| `tut [p] 4` | sets the tutorial step (1-7, 8 = done) |
| `daily [p]` | the daily reward can be claimed again |
| `zone rug Tan` | gives a zone to a team (`none` makes it neutral again, guarded by wind-up toys) |
| `deploy rug [p]` | deploys that player's best ready squad to a zone |
| `ai on` · `ai off` · `ai act` | AI commanders on/off, or make both act now |
| `reset [p]` | wipes the save and starts the FTUE again (passes are kept) |

Headless sim: `node tools/sim/run.mjs toyarmy --debug "give 1000000;give unit Tank Gold 3;event;clip;round;supply;merge;rank 5;ai act;topple;daily;call;zone rug Tan;deploy rug;state"`.
Launch features: `--debug "give 1000000;strike rubber;strike balloon;strike rcplane;strike rockets;strike flashlight;strike dog;hourly;boost luck 4;skin skinGold;policy on;bag Basic;ftue;state"`.

## First session (new player: run `reset`, then rejoin)
- [ ] You spawn on your team's glowing pad beside your Outpost flag (Green on the west side, Tan on the east), facing it. Warm afternoon light, sunbeams through the window, the cat asleep on the bed.
- [ ] 0-10 s: banner "Deploy the Toy Army! ⚔️", goal bar "Deploy your soldiers at your Outpost flag!", a bouncing 👇 over the red DEPLOY ▸ Outpost button and a yellow beam from you to the flag ("⬇️ GO HERE! ⬇️"). Pressing DEPLOY (or the flag's E prompt) hops 3 Riflemen onto the outpost for a drill vs grey wind-up toys.
- [ ] Drill: pellets fly, toys recoil, the losers tip over and fade, "GREEN 3 ⚔️ 2 WIND-UP" label above the fight. Win → "🎯 DRILL COMPLETE!", plastic flies to the counter, a FREE Bag of Soldiers flies to OPEN (~30 s).
- [ ] OPEN FREE: the bag wobbles, pops, 3 cards flip in with the real toy model, tier colour, NEW! sticker. AWESOME! / OPEN ANOTHER.
- [ ] "Merge 3 Riflemen into a Bazooka!": MERGE button with badge → MOLDING pill above the button → after 4 s the "🔀 MERGED!" Bazooka card (~60 s).
- [ ] "Capture The Rug!": the beam moves to the rug flag; the squad hops in from your side and fights the wind-up guards; capture → "🚩 VICTORY! ZONE CAPTURED!", confetti, the flag turns your colour, your soldiers stay on as the garrison (★ over your own).
- [ ] 2:30: "🪂 A SUPPLY DROP landed!" toast, SUPPLY button on the right → a guaranteed Tank. "Deploy your Tank at the Block Tower!" → capturing it topples the letter-block tower.
- [ ] "Upgrade your Toy Box!" (finger on BASE) → "🎖️ BASIC TRAINING COMPLETE!" + a Heavy Duffel.
- [ ] The ⏰ gift on the right is ready at 0:45 (toast "free gift ready"); `ftue` shows deploy < 10 s and first reward < 30 s when you press DEPLOY right away.
- [ ] No purchase pop-up before minute 2. At ~2:05 the STARTER PACK pops up once ("Ends in" countdown); the 🎒 deal button on the right keeps counting down until minute 10 of the first session, then disappears (never again on later sessions). Players who never bought anything then see the R$9 RECRUIT DEAL (🏷️ button, one pop-up per session). Other offers (tanks after a defeat, call the cat when losing a round) at most once per 10 min.

## The cat (run `event`)
- [ ] 25 s before a natural visit: "🐱 THE CAT IS WAKING UP!" banner; the CAT timer on the right counts down.
- [ ] The cat opens its eyes (❗), jumps off the bed (screen shake, thud, shockwave), walks to a zone, raises a paw and slams: every toy there flies spinning across the room and fades, fights there end "🐱 SWATTED!", dropped toy bags appear on the floor (walk over one to grab a free bag).
- [ ] It swats a second zone, walks back, jumps on the bed and goes back to sleep (💤). Toast: "The cat went back to sleep. Re-deploy your army!".
- [ ] A player who joins mid-visit sees the cat where it is (not asleep on the bed).
- [ ] `call`: "🐱 NAME CALLED THE CAT!" banner for everyone; the cat goes for the caller's enemy zones. Calling while it is out says "your call is next in line".

## War, zones and AI
- [ ] Top: GREEN n · 🏆 timer · n TAN; zone counts update on capture. At 0:00 "🏆 GREEN ARMY WINS THE ROUND!" and the winners get plastic + a bag.
- [ ] MAP: every zone with owner, power, garrison count, income, yours, ⚔️ BATTLE!; DEPLOY / GUARD / ATTACK and ↩️ recall work; your own outpost shows 🎯 DRILL with its cooldown.
- [ ] Two players on the same team can reinforce the same fight (squads hop in as "join"); more than 8 per side queue and step in as others fall.
- [ ] Solo player: after ~45 s the AI commander (Captain Crumbs 🤖 / Sgt. Sprout 🤖) attacks zones; it leaves zones guarded by brand-new players alone; when real players go idle for 4 min the AI takes over their team.
- [ ] Knocked-over soldiers show "getting up" in the Toy Box and are ready again after 10 s.

## Menus and economy
- [ ] TOY BOX: count / capacity / power / squad size, mold press with progress bar and ⏩ SKIP (R$19), one row per unit kind with the real model, deployed / getting-up counts and MERGE when 3 are ready.
- [ ] BAGS: 4 bags, each toy's % (sums to 100; Secret shows "??? SECRET" with its %), a 🍀 boosted % under each while any luck applies (`boost luck 4`: numbers change within 1 s), mutation % line, rank locks, BUY (plastic) / OPEN FREE (n), luck line with the boost timer. `policy on`: BUY says BUY (FIXED) and "BUY gives exactly: …"; `bag Basic` returns exactly that.
- [ ] BASE (upgrades): 5 upgrades with level and cost; the Plastic Press raises offline income; Bigger Box raises capacity.
- [ ] INDEX: 28 cells with the counter class glyph and the best bag % (mutations: their %); undiscovered ones are dark silhouettes; the Dino stays "???"; found count updates when a new toy arrives.
- [ ] Counters: TOY BOX header legend "💂 > 🚁 > 🛡️ > 💂", every row says what it beats; the DEPLOY button shows STRONG / WEAK / EVEN vs its target.
- [ ] SHOP: PASSES (each with a 🎁 gift button that opens the player picker), SKINS (3D preview, BUY / EQUIP / EQUIPPED; the skin shows on your soldiers on the field and in the toy box), BOOSTS (server boosts say NEEDS nx ON until the lower one is running; Starter Pack only in its window with "Ends in"; Recruit Deal only if you never bought), PLASTIC (amounts scale with rank). `policy on`: Lucky Bags, 10 Bags and the luck boosts disappear. Owned passes say OWNED ✅. In Studio purchases are simulated.
- [ ] STRIKE (left menu): enemy zones as target buttons (strongest pre-selected), 7 strike cards with prices. Each strike draws for everyone and knocks toys over when it lands (`strike dog`: the dog runs in from the door to every enemy zone, WOOF!). A strike with no target is saved and the card says USE FREE (n).
- [ ] 🎁 FREE (left menu): codes (`LAUNCH`), group gift ("coming soon" while id 0), playtime gifts 5/10/30/60, 3 quests; the "!" badge appears when something is claimable. A bought server boost shows as a pill under the top bar.
- [ ] `hourly`: "HOURLY MEGA CAT! 2x PLASTIC" banner, the cat swats 4 zones and drops 8 bags, plastic pill x2 for 10 min.
- [ ] Your toy box at the south wall shows your 3 strongest soldiers and an army-size sign; it turns gold with Pro Commander.
- [ ] Head tag shows rank; VIP / PRO get 🎖️ / 👑 in the tag and in chat.
- [ ] DAILY: 7 days, today's card highlighted, CLAIM pays plastic + bags; the 🎁 button shows "!" when ready. GIFT: a free bag every 10 min online.
- [ ] Leave and rejoin after a few minutes: "👋 WELCOME BACK!" with the press's offline plastic (cap 8 h, 12 h with VIP); plastic, units, rank, index, upgrades and tutorial step persisted.

## Mobile
- [ ] Phone layout: top counters, left menu and right column do not cover the bottom buttons; the DEPLOY button and the flag prompt are reachable with a thumb.
