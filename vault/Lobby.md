# Lobby (phase 1): done

Part of the [[Roadmap]]. Built and playtested on 2026-11-01.

## What players get
1. **Pick a class** (left panel). There are 5 classes, unlocked with Gems.
2. **Build a loadout** (right panel): **one gun per level**. The first gun in each level is free, and the others cost Gems.
3. **Ready up.** The countdown starts the run, and pressing Ready together shortens it.
4. **In a run** you start on your Level 1 gun. The **upgrade button on the right side** (or key `1`) swaps you to your next loadout gun, paid for with cash from kills plus a **wave-clear bonus** of $75 + $25 × wave.

## Gun levels
| Level | Free gun | Gem guns | Upgrade cost |
|---|---|---|---|
| 1 | Service Pistol | Hand Cannon (revolver, 300) | starter |
| 2 | Scrap SMG | Pump Shotgun (400) | $500 |
| 3 | Assault Rifle | Auto Shotgun (600), Marksman Rifle (sniper, 600) | $2,500 |
| 4 | Minigun | Laser Rifle (pierces 12, 1200), Auto Sniper (1200) | $10,000 |

The stats are **placeholders** until [[Weapons]] (phase 4). The procedural gun models are also placeholders.

## Shops (2026-11-02)
The always-on left and right panels were replaced by two **walk-up shops** (press `E` at the prompt):
- **Armory**, the west tent: level tabs 1–4 and a card per gun with a **rotating 3D model**, stat bars (damage, fire rate, magazine, range), traits, and equip or unlock.
- **Barracks**, the east sandbags: **5 class mannequins** on pedestals in the lobby, and a shop card per class with a rotating figure, abilities, traits, and equip or unlock.

Each class figure has its own pose and kit (`Shared/ClassFigures`, upgraded 2026-11-02). All of them have a face, vest, gloves and knee pads.
- **Survivor:** a cap, bandolier and backpack, with a rifle held across the chest.
- **Scout:** goggles, a scarf, binoculars and a slung sniper, mid-stride.
- **Medic:** a cross helmet, armband, medkit and cross backpack.
- **Engineer:** a hard hat with headlamp, hi-vis vest, tool belt and wrench.
- **Bruiser:** a visored helmet, armour plates, riot shield and sledgehammer.

**The armory area** (revamped 2026-11-03) is the barracks' twin across the plaza: the same plank deck and tent, a hazard-striped front beam, an amber neon-framed sign and string lights. Its back wall is a gun wall: every gun hangs on pegs in a column per Level, under a LEVEL n header with neon strips and a spotlight in that Level's colour. A new gun in `Config/Weapons` shows up there on the next rebuild. A waist-high gunsmith's bench at the front holds two guns in cases and a box of rounds; a shot-up target hangs on the north wall. Rebuild only that area with `OurLobby.Rebuild("Armory")`.

**The barracks area** is an open army tent on a plank deck. It has string lights, a sign under the front beam, and pedestals spaced 5 studs apart. Each pedestal has a neon ring, a nameplate and a spotlight in its class colour. Lockers, a weapon rack and crates sit at the back, with sandbags at the front corners. Rebuild only that area with `OurLobby.RebuildBarracks()`, which keeps every other hand edit.

The lobby screen (UI/LobbyMenu, overhauled 2026-11-03) is the main menu: the game's wordmark at the top, a profile card top left (level badge, name, rank, XP bar, Gems with a + for the Gem packs, best wave, class and the four loadout guns as Level-coloured chips), menu tiles down the right (SHOP, WEAPONS, CLASSES, BOUNTIES, INVITE) that open each shop right there, and a wide pulsing QUICK PLAY over the deploy hint. It all slides in each time the lobby comes into view. Both scale with the screen height (`UIKit.AutoScale`, 2026-11-02). The chip sits at 0.75 on top of that, and the status bar is 560 wide so the prompt fits on one line.

## The Commons and lobby sound (2026-11-02)
The lobby was quiet and purely functional, so it got a place to hang out and some life.
- **The Commons** (`Server/Map/Commons`, run by `OurLobby.Build` after FlightLine): the old south gate, blocked with barriers, is open again. Behind it, on its own slab (as wide as the courtyard's), are:
  - a **campfire** ring with two couches, three log benches and crate side tables, under four poles of sagging warm string lights
  - the **mess tent** (west): two long tables with benches, tins, a cooking barrel with a pot, crates
  - **sleeping tents** (east): three A-frame tents with bedrolls and cots, and a lantern
  - a **radio shack** (south-east): sandbag walls, a tin roof, a desk with a glowing radio set, a map board and an antenna mast with a red light
  - a **hoop** (south-west) with a ball, faded court lines and crates
  - container walls on both sides and a barrier fence at the south edge. The three south ruins moved back 84 studs to stand behind it.
- **Sound** (`Client/Controllers/LobbyAudioController`; ids in `Config/Sounds`, checked in a playtest):
  - Music: a quiet playlist of three APM tracks (Remembering You, Dawn, Eternal Ice) with 20s of quiet between them.
  - Beds: a soft sea wash and a faint eerie ambience.
  - The music and beds fade out when a run starts and back in when you return.
  - 3D loops: a fire crackle on every fire (courtyard barrels, campfire, mess stove) and radio chatter from the shack. They are Sounds named `LobbyAmbient` that the controller starts as they stream in.
- **Things to do** (`Server/Services/CommonsService`, added the same day):
  - **Sit** on the couches, log benches and mess benches (22 Seats).
  - **Listen in** at the radio shack: Sgt. Voss plays a lore broadcast on your radio panel (lines in `Config/Survivors`).
  - **Shoot** the ball at the hoop: it arcs at the rim, and about 1 in 3 goes in from 9 studs (bank shots count). A make calls "SWISH!" for you and everyone near.
  - **TOP SURVIVORS** board: the all-time best waves of every player, from an OrderedDataStore (`SAMZ_BestWave_v1`, written by DataService). Studio has no DataStores, so it lists the players in the server.
  - The **Commendations board** moved from in front of the south gate (it blocked the way in) to the Commons entrance, west of the path, facing it; TOP SURVIVORS stands opposite.
- **Survivors** (`Shared/Config/Survivors`, placed by `Server/Map/Survivors`, talking via `Client/Controllers/SurvivorController`): five people built from the class figures, each with a name tag and a "Talk" prompt. Each cycles five lines of tips and lore in a speech bubble only you see.
  - **Rook** (old-timer, campfire): the city and cash tips.
  - **Doc Hale** (medic, mess tent): health tips.
  - **Cpl. Reyes** (radio operator, radio shack): Overwatch, crates and the Titan.
  - **Sparks** (mechanic, Flight Line gate): squads, upgrades and classes.
  - **Big Mo** (bruiser, hoop): Gems, boards and the Titan's enrage.
  - **Lore so far:** the city is Port Harrow, the infection is "the Bloom", and Overwatch flies from a carrier offshore.
  - **Bubbles and tags** are sized in studs, so they always take the same space. Every NPC's bubble space was checked clear of parts.
- **Fixes found on the way:**
  - The sleeping tents were built upside down (the slope sign was flipped) and had a rectangular back panel that stuck out; both are fixed.
  - The barrel flames burned sideways: the Fire's attachment inherited the barrel cylinder's 90° roll. It's set upright now.
  - The flag hung edge-on to the plaza. It's three panels flying east-west now.
  - The ground cracks floated 0.27 studs above the asphalt and lay across the plaza, so they read as sticks. They're flat on the ground now, and off the plaza.

## Flight Line and squads (2026-11-02, replaces the single helipad)
The lobby is for many players now, so no one waits for a pad and every squad gets its **own private server**.
- **The Flight Line:** a fenced deck north of the courtyard, through a gate where the middle north ruin stood (a "FLIGHT LINE" sign over it). It has **4 helipads** in a 2 × 2 grid, joined by taxi lines, with floodlights at the corners. Pad 1 is the old courtyard helipad, moved; pads 2–4 are copies of it (same glow, edge lights and sign). Each pad model has the attribute `PadId`. Built by `Server/Map/FlightLine`, which `OurLobby.Build` calls last.
- **One squad per pad:**
  - The **first player to step on an empty pad is the host.** They pick the mission on the squad panel: squad size 1–4 and map (Dead City; a locked **???** slot for future maps). Choices live in `GameConfig.Lobby`. The pad decides the difficulty: in the middle of the deck a caged red pad behind a chained gate is the [[Nightmare Mode]] queue (opens after 3 normal wins).
  - Others step on until the squad is full; later arrivals get "Pad n is full". If the host steps off, the next in line takes over. An empty pad goes back to the defaults.
  - **The countdown** runs 15s while anyone is on the pad, or 4s once the squad is full. Step off to leave.
  - The pad's sign shows `PAD n · OPEN` or `PAD n · 2/4`.
- **Take-off:**
  - **Live:** the squad is teleported together into a **new reserved server of this same place** (`TeleportOptions.ShouldReserveServer`), with the mission in the teleport data. It's one place file, so there's nothing to keep in sync between places. There, `MatchService` waits for the squad (up to 20s after the first arrives, behind a "waiting for your squad" screen), plays one run, shows results, then teleports everyone back to a lobby server together. Profiles are saved just before each teleport.
  - **Studio** can't teleport, so a take-off plays the run in the lobby server like before, one run at a time (other pads show "RUN IN PROGRESS").
- **First-time players** (profile `TutorialDone = false`; any save with a run counts as done) are teleported straight into a **guided training run**: 5 waves, ending in a "young" Titan with 25% health. Overwatch teaches one thing at a time, each a radio line plus an objective card that ticks green: shoot and reload; press 1 to upgrade (cash topped up); 2 for Vitality; E for the ability; a supply drop on wave 3 (hold G); F for the ultimate (bar filled on wave 4); the boss; then Gems and the shops. It pays a flat 250 Gems, win or lose, isn't counted as a win, and is marked done even on a loss. Steps are data in `Shared/Config/Tutorial`, run by `Server/Services/TutorialService` and shown by `Client/Controllers/TutorialController`. In Studio, test it with `SAMZ_Debug:Invoke("Tutorial")`.
- **Code:** `Server/Services/QueueService` (pads, host options, teleports, the tutorial send-off), `MatchService.IsMatchServer` (a reserved server), `:RunMatch(players, options)`, `MapService:GetPads` / `:GetPadAt`, the remote `SetPadOptions`, and GameState `ServerKind`, `Pad1..4` (JSON), `Difficulty`, `MapId` and `Tutorial`. On the client, the squad panel is in `LobbyController`.
- **Live lobby servers delete the city** (`MapService:Init`) since they never run a match.

## Commendations board (2026-11-02)
This is the achievements station, **south of the plaza and facing it**, so players pass it every time they come back from a run.
- **The board:** a corkboard of pinned papers and medals under an awning lit by two lamps, with an open crate of glowing gems beside it.
- **Status sign:** shows "N READY TO CLAIM" in green when there's something to collect.
- **The screen:** press `E` to open it. It's a scrolling list of 22 achievements (`Config/Achievements`), each with a progress bar and a CLAIM button that pays Gems.
- **What counts:** total kills, kills per zombie type, headshot kills, waves cleared, best wave, runs, wins (total and per class, including "win as every class"), and supply drops opened.
- **Toasts:** a message pops up mid-run when you finish one.

## Our lobby build
A fortified safehouse inside a ruined city at **x = 1000, z = 1000** (moved from z = 380 on 2026-11-02, out of sight of the city; the Flight Line reaches north to z = 810), on its own island south of the arena city. Its layout:
- **Foundation** (2026-11-02): one 184 × 172 slate slab under the whole footprint, top at Y = 0.95 and reaching below the seabed. Terrain water inside it is cleared, so no ocean shows between buildings. Before this, only the 124-stud asphalt floor existed and the ruins and containers hung over water. The lobby also moved from z = 235 to 380, which leaves about 140 studs of sea between it and the city.
- **North:** ruined towers, with a gate in the middle to the **Flight Line** (see above and [[Match Start]]).
- **Centre:** a concrete plaza with a flagpole and burning barrels. Players spawn in a ring around it, facing north.
- **West:** the armory tent (the loadout spot). **East:** a command post behind sandbags.
- **Sides:** stacked shipping containers, with more ruins behind them. **South:** jersey barriers and a chain-link fence.

## How it's wired (code)
- `GameConfig.OurMap` (centres at x = 1000) is **the only map**. On 2026-11-01 the original "Graveside Isle" generator, the friend's city map, `Props` and `Bricks` were deleted, and MapService now only reads our marker parts (see [[Roadmap#Project history]]).
- `Server/Map/OurLobby` builds `Workspace.OurMap.Lobby`. It's baked in Edit mode (rebuild instructions are in its header), so it can be hand-edited afterwards.
- `MapService:GetLobbySpawnCFrame()` uses the parts named `LobbySpawn` in our lobby.
- Profile: `Loadout = { [level] = weaponId }` replaces `EquippedWeapon`. Old saves are migrated automatically, and every free gun is granted.
- `WeaponTier` now means **gun level**. `GameConfig.WeaponTiers` multipliers are all 1, kept only for the level colours.

## Notes for later
- **Shared code:** the loadout and upgrade changes also apply to the friend's version.

## Launch prep (2026-11-02)
- **Arrival:** you spawn facing the Flight Line gate. Every player in the lobby has a gold "BEST WAVE n" tag ("NEW SURVIVOR" at 0).
- **QUICK PLAY** puts you on the fullest pad that has room; **INVITE FRIENDS** opens Roblox's invite prompt. See [[Servers and Teleports]].
- **Daily Rations** ([[DailyCache]], [[DailyService]]): a pallet of crates under a sign on the south edge of the plaza, by the flag (the plaza was bare). Hold "Claim" once per UTC day. A streak pays 40, 60, 80, 100, 125, 150, then 250 Gems on day 7, then starts over; missing a day resets it.

## Welcome screen, Field Research, Bounty Board (2026-11-02)
Ideas from the owner, built our own way.
- **Welcome screen** ([[WelcomeController]]): every join after the tutorial. Your avatar idles on a ruined Port Harrow street at sunset (broken skyline, burning wrecks, smoke and embers) while a horde runs past behind you. On the right: your stats, your tracked [[Bounties|bounty]], a line from one of the safehouse people, and ENTER SAFEHOUSE. Fire and smoke are animated parts, because 3D UI scenes draw no particles or lights.
  - **Run report** (2026-11-03, the owner's idea): after every run, win or lose, the same screen comes back once you're at the safehouse, as a report: "RUN REPORT // PORT HARROW" (or NIGHTMARE / TRAINING), "WELCOME BACK, NAME", the outcome in big letters (VICTORY, NIGHTMARE CLEARED, OVERRUN or TRAINING DONE) and that run's tiles: wave reached ("NEW BEST" in the label), zombies killed, Gems earned ("NONE" for a lost Nightmare run), waves cleared, your Gems and enemies studied. The quick VICTORY / OVERRUN panel still shows at the moment the run ends. Live, the results ride back on the teleport to the lobby server ([[MatchService]] keeps them, [[QueueService]] sends them); in Studio the run plays in the lobby server, so the report comes from the RunResults message. Since 2026-11-03 it has a level header with the run's XP filling the bar and LEVEL UP! on each level (see [[Levels]]).
- **Field Research** ([[FieldStations]], north-east of the plaza): the enemy index. Kill a zombie type to unlock its card (spinning model, stats, special, lore from [[Zombies config]]), then claim its Gems once: 50, 75, 100, 150, and 300 for the Titan. See [[Lore]].
- **Bounty Board** (north-west, by the gate): see [[Bounties]].

## Code
[[OurLobby]], [[FlightLine]], [[Commons]] and [[Survivors map]] build it. [[LobbyService]], [[QueueService]] and [[CommonsService]] run it. [[ShopController]], [[LobbyController]], [[LobbyAudioController]] and [[SurvivorController]] are the client. See also [[Servers and Teleports]], [[Tutorial]], [[Achievements]] and [[Lore]].

Back to [[Home]].
