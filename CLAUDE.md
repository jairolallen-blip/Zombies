# Survive a Million Zombies: agent handoff guide

> **Keep this file current. It's part of every task.** Before you finish any task that changes the game, update the sections it touched: Status, Content, Architecture, Pitfalls and Changelog. Add a dated line to the Changelog. A new agent should be able to start from this file alone.

## 1. What this is
A Roblox **horde-survival shooter**. Players queue in a lobby, pick a class and a 4-level gun loadout, get dropped by helicopter into an apocalyptic city, and survive **10 waves** that end in a **boss** (the Grave Titan). The genre reference is *Survive a Million Monkeys*. **Inspiration only:** all names, mechanics and art here are our own, so never copy that game.

- **Owner:** `jairolallen-blip` on GitHub, `ja123asd` on Roblox. They work with a friend, `AnimatedSL`, in the same Team Create place.
- **Status:** all 7 roadmap phases are done, and a balance pass is done (see §8).

## 2. Where things live (sources of truth)
| What | Where |
|---|---|
| **Live game** | Roblox Studio place "Survive a Million Zombies", **placeId 110463048909417**, in **Team Create** (edits are live for everyone in the session) |
| **Shared guide with the friend's agent** | `ServerStorage.README_AI_GUIDE` in the place. It's the main channel between our work and AnimatedSL's: **update its Status/Content and Changelog in Studio on every task**, same as this file |
| **Code + notes, versioned** | GitHub `jairolallen-blip/Zombies` (`main`), cloned at `D:\CLAUDE WORK\Zombies` |
| **Design notes** | `vault/`, an Obsidian vault in the repo. Start at `vault/Roadmap.md`. One note per system: Lobby, City Map, Match Start, Weapons, Zombies, Spawning, Waves and Boss |
| **Reference images** | `vault/MAP REFERENCES`, `MODEL REFERENCES`, `UI REFERENCES`, `VISUAL REFERENCES`. Look at these before building art. Use them for inspiration, not copying |
| **Code search** | Graphify repo `jairolallen-blip/Zombies` (id `d1b46534-fb62-460e-968f-3bb73970c238`). It indexes only **pushed** commits; re-indexing after a push takes a few minutes |

**Studio is the live truth, and the repo is a mirror.** Code is written in Studio (through the Studio MCP), then **exported** to the repo and committed. The repo doesn't sync automatically, so export after every task (§6).

**⚠ Team Create overwrite risk.** On 2026-11-01 the friend synced their own copies of the scripts into the place and silently reverted our work. Before editing, check that our markers are present:
```lua
-- execute_luau (Edit): all should be true
local S = game.ServerScriptService.Server
return S.Services.MatchService.Source:find("_deploy") ~= nil, S.Services.DataService.Source:find("Loadout") ~= nil,
       game.ReplicatedStorage.Shared:FindFirstChild("GunModels") ~= nil, S:FindFirstChild("ZombieModels") ~= nil
```
If any are false, someone overwrote Studio. **Restore from GitHub with §6's import**, then check whether they added anything worth keeping (diff their scripts against `git show <commit>:src/...`).

## 3. Game content (current numbers live in config; these are summaries)
**Flow:** Lobby (squads form on the 4 **Flight Line pads**: 15s countdown while anyone is on a pad, 4s once its squad is full; live, each squad is teleported into **its own reserved server**) → **Deploy** (18s first-person helicopter cutscene, parachute drop) → 12s intermission → waves 1–10 with an 8s break between each → **Victory** after wave 10, or **Overrun** if everyone dies → Results → back to a lobby server. **New players** skip the lobby: a 5-wave solo training run first (see Lobby below).

- **Lobby** (`vault/Lobby.md`): a ruined-city safehouse at (1000, 0, 1000), far south of the city. The screen shows only a small chip (Gems, best wave, class, gun lineup, shop locations) and the take-off status. Choices happen in two **walk-up shops**, opened with `E` at their ProximityPrompt:
  - **Armory** (west tent): level tabs 1–4, and a card per gun with a rotating 3D model, stat bars, and equip or unlock-with-Gems.
  - **Barracks** (east): class mannequins on pedestals, and a card per class with a rotating figure, abilities, traits, and equip or unlock.
  - **Commendations board** (south, facing the plaza): achievements that pay Gems.
    - **Data:** `Config/Achievements` holds the list. Progress lives in profile `Stats`, claims in `Claimed`, and the client sees both as the `AchievementsJson` attribute.
    - **Counting:** `DataService:AddStat` counts progress and toasts each completion. It's called for kills (total and per zombie type), headshot kills, waves cleared, runs, best wave, wins (total and per class) and supply drops opened.
    - **Claiming:** the `ClaimAchievement` remote pays once.
    - **Screen:** a third ShopController view. The board's `Status` sign shows how many are ready to claim.
    - Old saves are credited from `TotalKills`, `RunsPlayed` and `BestWave`.
  - The shops close with X, by walking away, or when a run starts.
  - Rebuild one lobby area without touching hand edits: `require(<clone of OurLobby>).Rebuild("Barracks" | "Commendations")`.
  - **Flight Line + squads** (2026-11-02, `Server/Map/FlightLine`, `Services/QueueService`): a gate in the north ruins leads to a deck with **4 helipads** (`PadId` 1-4). The first player on an empty pad is its **host** and picks squad size 1-4, difficulty (Hard locked "SOON") and map (one locked "???" slot) on the squad panel (`SetPadOptions`, choices in `GameConfig.Lobby`). Others join until full.
  - **Servers:** one place file. A live squad is teleported into a **reserved server of the same place** (`MatchService.IsMatchServer`); there MatchService waits for the squad, plays one run (`RunMatch`), then teleports everyone back. **Studio can't teleport**, so a take-off plays the run in the lobby server, one at a time. Live lobby servers delete the Arena.
  - **Tutorial** (`Config/Tutorial`, `Services/TutorialService`, `Controllers/TutorialController`): profiles with `TutorialDone = false` (saves with any run count as done) are teleported into a solo **5-wave training run** that ends in a **young Titan** (25% health). Overwatch walks them through 8 steps, each a radio line plus an objective card on the left that ticks green when done: shoot and reload, upgrade the gun with 1 (cash topped up), Vitality with 2, the class ability with E, a guaranteed supply drop on wave 3 (hold G), the ultimate with F (bar filled on wave 4), the boss, then Gems and the shops. Random supply drops are off in it. It pays a flat **250 Gems** win or lose, isn't counted as a win, and is marked done even on a loss. In Studio: `SAMZ_Debug:Invoke("Tutorial")`.
- **Deploy cutscene** (`Controllers/CutsceneController`, `GameConfig.Deploy`): first person from a seat in the helicopter's open cabin.
  - **The ride:** it starts **over the ocean** north of the city (terrain water is baked all round the map), skims the waves, climbs over the rooftops and hovers above the square.
  - **The camera:** it looks out the door, through the windshield, and leans out over the streets. Then it turns to the **pilot** (helmet, shades, headset, tactical vest), who turns round, gives a thumbs-up and says "Good luck down there." You step out the door and parachute down in first person, until `CameraController` takes over on landing.
  - **The fall** (`dropView` in CutsceneController, `MatchService:_parachute`): about 0.5s of freefall looking down at the square with arms out, then the server welds a ram-air canopy (7 striped cells plus lines) and brakes the fall, which gives the opening jolt. The camera looks up at the canopy, then sways down to the landing with gloved forearms on the toggles. Your own body and gun are hidden locally only, so there's no third-person fall pose or Tool in view; everyone else sees your canopy. Tunables: `GameConfig.Deploy` `DropHeight` 110, `FreefallTime` 0.5, `FallSpeed` 22.
  - **The path** is built on the server by `MapService:GetDeployFlight`, which raycasts the roofs under the rotor span along a bezier with a slope-limited clearance floor, so the helicopter never clips a building. It's sent as JSON in GameState `DeployPath`. It's built server-side because StreamingEnabled is on and a client may not have every building loaded.
  - **Sound + effects:** cabin wind that swells at the door, sea wash and rotor-wash spray while low over the waves, faint radio chatter, an intercom squelch before the pilot speaks, wind streaks past the door, a whoosh, shake and FOV kick on the jump, then the chute opening and falling wind until landing. Ids are in the `Config/Sounds` deploy block, loops come from `SoundController:Loop`, and one-shot timings are the `CUES` table in CutsceneController.
- **Classes** (`Config/Classes`): Survivor (free), Scout 350, Medic 500, Engineer 750, Bruiser 750 Gems. Each has an ability on `E` and an ultimate on `F`.
  - **Engineer balance** (2026-11-02): the Sentry has a 42s cooldown through wave 4, then 22s. Sentries only fire at zombies within 30 studs (35 for the Nest). Sentry Nest charges at half speed (`Ultimate.ChargeMult = 0.5`), so it needs twice the kills. These optional class fields are `Ability.EarlyCooldown` and `EarlyWaves`, and `Ultimate.ChargeMult`.
- **Guns** (`Config/Weapons`, models in `Shared/GunModels`): 4 levels, upgraded in-run for $500 / $2,500 / $10,000 (key `1` or the HUD button). The first gun of each level is free; the others cost Gems.
  - **Level 1:** Pistol, Revolver
  - **Level 2:** SMG, Pump Shotgun
  - **Level 3:** Assault Rifle, Auto Shotgun, Marksman Rifle
  - **Level 4:** Minigun (spins up), Laser Rifle (pierces 12), Auto Sniper
- **Weapon feel:** recoil, per-gun tracer and flash, ejected shells.
- **Vitality** (key `2`): +20 max HP and a full heal, costing 150 × 1.35^level.
- **Zombies** (`Config/Zombies`, models in `Server/ZombieModels`):

| Type | HP | Speed | Damage | Cash | From wave | Special |
|---|---|---|---|---|---|---|
| Shambler | 60 | 10 | 10 | $15 | 1 | — |
| Runner | 35 | 19 | 7 | $20 | 3 | lunges |
| Bloater | 90 | 8 | 0 | $35 | 5 | explodes |
| Brute | 450 | 7.5 | 28 | $90 | 7 | — |
| **Grave Titan** (boss) | 18,000 | — | — | — | wave 10 | slam; enrages at 50% (faster, double slams, summons 6 Runners) |

  HP rises 10% per wave. Every zombie is randomised (clothes, wounds, hair). AI: flow-field navigation, surround slots near the player, hit flinch, attack swipe.
- **Spawning** (`vault/Spawning.md`): random open-street spots 22–75 studs from a living player, any direction. A red warning circle shows for 1.2s, then the zombie rises out of the ground over 0.6s.
  - **Counts:** wave n has 8 + 6 × (n − 1) zombies (60% of that on the boss wave), ×1.6 per extra player.
  - **Groups:** 1 + ⌊n/3⌋ zombies at a time, spread over 16 + n seconds. At most 70 alive.
- **Economy:**
  - Kill cash goes to the killer, and other living teammates each get 25% of it.
  - Wave-clear bonus: $100 + $150 × wave.
  - **Clearing a wave also heals everyone to full.** HP never regenerates otherwise, because `StarterCharacterScripts.Health` is deliberately empty.
  - Gems at the end of a run: 5 per wave cleared, 0.2 per kill, +100 for a victory.
- **Commander radio** (`Config/Radio`): Sgt. Voss (callsign Overwatch) speaks on deploy, drop, landing, every wave start and clear, boss incoming/enraged/down, victory and overrun.
- **Map** (`vault/City Map.md`): `Workspace.OurMap`, holding the Lobby (centre 1000, 0, 1000, on its own island with slate `Foundation` slabs, plus the Flight Line deck) and the Arena city (centre 1000, 0, 0).
  - **Layout:** 23 × 23 tiles of 12 studs, drawn as a text grid in `Server/Map/OurCity`. A big central square, 4 streets, a ring road, and a park, alleys, a parking lot and a market. No dead ends.
  - **Floor:** perfectly flat at Y = 1, which the zombie navigation requires.
  - **Lighting:** the sunset atmosphere is applied **at runtime only** (`MapService:ApplyAtmosphere`). In Edit mode it looks bright, and that's expected.

## 4. Architecture
```
ServerScriptService/Server/
  Main.server.luau        loads Services/ in ORDER (Data, Map, Economy, Combat, Zombie, Ability, Lobby, Match), then Init() all, Start() all
  Services/               DataService (DataStore profiles; key "SAMZ_Profile_v1"), MapService (spawn points, nav bounds, atmosphere),
                          EconomyService (cash/upgrades/wave-clear heal), CombatService (server-validated hitscan),
                          ZombieService (spawn/AI/damage/boss), AbilityService, LobbyService, MatchService (run loop, deploy, radio; IsMatchServer),
                          QueueService (Flight Line pads, squad options, teleports, tutorial send-off),
                          DebugService (Studio-only commands)
  Map/                    NavGrid (flow-field pathing), OurLobby + FlightLine + OurCity (map BUILDERS, baked in Edit mode)
  ZombieModels            zombie bodies
ReplicatedStorage/Shared/
  Config/                 GameConfig, Weapons, Classes, Zombies, Radio   <- pure data; tune numbers here
  GunModels, ClassFigures (class mannequins/previews), Util (weapon/upgrade math shared by client+server),
  Remotes (all RemoteEvents), GameState (replicated attributes)
StarterPlayerScripts/Client/
  Main.client.luau        loads Controllers/, Init() then Start()
  Controllers/            Camera (aim = mouse ray), Weapon (fire/recoil/spin-up), HUD, Lobby (lobby chip, Ready, results),
                          Shop (Armory + Barracks shop UIs, opened by ProximityPrompts with attribute Shop), Input,
                          Effects (tracers, explosions, zombie animation, SpawnWarning), Cutscene (deploy), Radio (commander panel)
  UI/UIKit                UI builder + theme; AutoScale(root) fits a full-screen root to the screen height (800 px design)
StarterCharacterScripts/Health   empty on purpose (disables regen)
```
- **Server-authoritative:** the client sends `FireWeapon(origin, dirs)`, and the server validates fire rate, ammo, origin distance and pellet count before re-raycasting.
- **Remotes:** FireWeapon, Reload, UseAbility, BuyUpgrade, SelectClass, SelectWeapon, UnlockItem, ClaimAchievement, SetPadOptions, Notify, HitConfirm, Effect, RunResults, Radio.
- **Supply drops** (`Services/AirdropService`, `Config/Airdrops`, `Controllers/AirdropController`).
  - **When:** from wave 2, each wave has a 65% chance of one crate parachuting onto a street away from the squad. Red smoke, a light pillar and a `SUPPLY DROP · Nm` marker show where it is.
  - **The fight:** guards rise around the crate, and they count toward the wave.
  - **Opening:** **hold G** to open it (E is the ability). It gives a random reward to every living squad member within 30 studs.
  - **Rewards:** Overcharge (+50% gun damage, 30s), Adrenaline (+35% speed and a full heal, 30s), Ult Surge (+50%), Cash Stash, or Gem Cache (+25).
  - **Buffs** live on the `Buff`/`BuffUntil` attributes. A chip under the wave counter shows them. `CombatService` asks `AirdropService:DamageMult`.
  - **Gotcha:** prompts only show when their part is on screen, so face the crate to open it.
- **GameState attributes:** Phase (Lobby/Deploy/Break/Wave/Results), ServerKind (Lobby/Match), Pad1..Pad4 (JSON pad state), Difficulty, MapId, Tutorial, Wave, Timer, ZombiesLeft, BossName/Health/MaxHealth, BossEnraged, RunWon, DeployPath (JSON), DeployStart, DeployDuration.
- **Player attributes:** InRun, PadId, Deploying, Cash, Kills, WeaponId, WeaponTier (= gun level), Ammo, Reloading, VitalityLevel, UltCharge, ClassId, LoadoutJson, OwnedJson, Gems.

## 5. Development workflow (with the Roblox Studio MCP)
1. **Check the markers** (§2), and read the vault note for the system you're touching.
2. **Find code** with Graphify (`graphify_find`, `query_graph`, callers and impact), or by grepping `src/`. `src/` mirrors Studio once you've exported.
3. **Edit in Studio:**
   - **Small edits:** use `multi_edit`. The `old_string` must match Studio's current source exactly. Studio may differ from `src/` if you haven't exported yet.
   - **Whole-file rewrites:** use `execute_luau` with `ScriptEditorService:UpdateSourceAsync(script, function() return src end)`. ⚠ A `[==[` long string already drops its first newline, so **don't** also call `:sub(2)` on it (that bug once deleted a character).
   - **New scripts:** use `multi_edit` with `className`, or create them with `Instance.new`.
4. **Requiring modules from `execute_luau`:** the command-bar context has its own module cache. A service you `require` there has `Services == nil`. To call service logic, use the `ServerStorage.SAMZ_Debug` BindableFunction, or fire real remotes from the Client context. To run a builder, `require` a **clone**: `local c = m:Clone(); c.Parent = m.Parent; require(c).Build(); c:Destroy()`.
5. **Map changes:** edit `OurCity`'s `LAYOUT` grid or the builder code, then rebuild. The rebuild replaces `Workspace.OurMap.Arena`, so hand edits are lost. After any map change, run `NavCheck` (§7). Every zombie pad must say ROUTE OK.
6. **Playtest** (§7), and check `get_console_output` for errors.
7. **Export, update and commit** (§6). Update this file and the vault note, then commit with a clear message ending in the attribution line, and push.

## 6. Export and import (tools/)
- **Studio → repo:**
  1. `Remove-Item src -Recurse`, then start `tools/receiver.ps1` in the background.
  2. Run `tools/studio-export.luau` in `execute_luau` (Edit). Its "problems" output must be empty.
  3. `git add -A`, then commit.
- **Repo → Studio** (restore or roll back):
  1. `tools/pack-scripts.ps1 -Out <file.json>`, then `tools/serve.ps1 -File <file.json>` in the background.
  2. Run `tools/studio-import.luau` (Edit). It overwrites scripts and **deletes** any under the four code roots that aren't in the repo.
- **Scope:** only scripts are in the repo. The baked map (`Workspace.OurMap`) lives only in the place file; rebuild it from the builders if it's ever lost.

## 7. Playtesting
- `start_stop_play(true)`, then use `execute_luau` with datamodel **Server** or **Client**. In Studio, DataStores run memory-only, and new profiles get 2,500 test Gems.
- **Start a run quickly:** in Server, move the character onto a pad with `p.Character:PivotTo(CFrame.new(workspace.OurMap.Lobby.Helipad.Pad.Position + Vector3.new(4, 4, 0)))` (any `Helipad` model; `PadId` 1-4), then click `LocalPlayer.PlayerGui.Lobby.Frame.Squad.Size1` so the squad is full and the countdown drops to 4s. In Studio the run plays in this server. Teleports (live squads, the tutorial send-off, the trip back) can only be tested in a published game.
- **Freeze-frame the deploy cutscene** (after one real deploy, so `DeployPath` exists):
  1. In Client, set the `GameState` attribute `DeployDuration` to 1e6.
  2. Set `DeployStart` to `GetServerTimeNow() - t * 1e6`.
  3. Set the local player's `Deploying` to true. To change `t`, set it to false, then true again.
  4. Good shots: t = 0.08 / 0.36 / 0.6 / 0.875 / 0.955.
  - **Screenshots and the MCP link:** several `screen_capture` calls in a row while the cutscene renders can time out and drop the MCP link. Use one capture at a time.
- **Team Create:** before any repo → Studio push, compare first. Push only the files you changed. A full import overwrote a live GameConfig edit by AnimatedSL on 2026-11-02.
- **Debug commands:** `game.ServerStorage.SAMZ_Debug:Invoke(cmd, ...)`. Commands: `God` (stays on across respawns until `God(false)`), `GiveCash`, `GiveGems`, `KillAll`, `SkipToWave n` (it applies after the current wave), `Spawn type n`, `NavCheck`, `State`, `ChargeUlt`, `AddStat key n` (achievement progress), `Airdrop` (drop a crate now), `Tutorial` (play the first-time solo run here), `Help`.
- **Fire real shots** from Client: `Remotes.FireWeapon:FireServer(muzzle.WorldPosition, {dir})`, where the muzzle is `Character.Tool.Handle.Muzzle`. Use `Remotes.BuyUpgrade:FireServer("Weapon")` to upgrade.
- **Balance:** `tools/balance-bot.luau` plays a full no-cheat solo run and logs each wave (instructions are in its header). Baseline from 2026-11-01: it reached wave 10 and got the boss to 9% HP. The owner approved that difficulty.
- **Screenshots:** `screen_capture` with `camera_position` / `look_at_position` aims the camera in Play mode too. Effects far from the player won't be in view.
- ⚠ **Keep every `execute_luau` call under about 60s.** Longer calls time out, and Studio can drop the MCP connection (`list_roblox_studios` comes back empty for a moment). Poll in about 55s chunks instead.
- ⚠ **Stop play when you're done.** A new run auto-starts after the lobby countdown.
- **Clicking UI:** `user_mouse_input` clicks only register by `instance_path` (for example `LocalPlayer.PlayerGui.Shop.Panel.Body.Frame.LevelTab4`), not by screen coordinates, so give testable buttons a Name. Open a shop by pivoting the character next to its prompt and sending `E` with `user_keyboard_input`. The lobby countdown keeps running (overwriting `Timer` doesn't hold it), so test within the 20s window.
- **You can't verify feel:** mouse-driven recoil, the minigun spin and the animations play on the user's screen. Ask the user to check them.

## 8. Pitfalls we've hit (read these)
- **Team Create overwrite:** see §2. Always check the markers first.
- **Gun specs:** in `GunModels`, the specs mix list entries with named fields (`Muzzle`, `Hub`). Loop over them with `ipairs`, not plain `for ... in`.
- **Local functions:** they must be defined *above* any function that uses them. `EconomyService` once called `notify` before it was defined, which stalled every run after wave 1.
- **Delayed spawns:** anything spawned through `SpawnWarned` appears 1.2s later, so react to the actual appearance (attribute-change signals), not the wave start. That's how the boss banner bug happened.
- **Cylinder axis:** Roblox cylinders run along X. Builders rotate them (`Tube` and `Drum` in GunModels; a 90° Z-roll in the map builders).
- **Collision and nav:** decorative parts must be `CanCollide = false`, or they block NavGrid cells and zombies route around nothing. The floor must stay flat. Keep props clear of spawn pads; OurCity enforces a 13-stud clearance.
- **Damage carries over:** HP doesn't regenerate, so any change to damage or waves should be re-checked with the balance bot.
- **Network ownership:** anchored roots can't change network owner. Rising zombies get `SetNetworkOwner(nil)` *after* they're unanchored.

## 9. Next ideas (not started)
From the vault notes:
- a helicopter extraction cutscene on victory
- endless mode after wave 10
- more city detail (fire escapes, traffic lights, an enterable shop)
- group-play balance testing
- **First-time drop-in** and **per-squad private servers**: done on 2026-11-02 (see §3 Lobby). Still open: point out the shops when a new player first reaches the lobby, and make Hard mode and a second map (both locked "SOON" on the squad panel).
- Replayability ideas from 2026-11-02, best first:
  1. pick 1 of 3 perks between waves
  2. endless mode plus a best-wave leaderboard
  3. daily challenge run with a modifier
  4. class mastery cosmetics
  5. mid-run events: supply drops are **done**. Blackout and extraction are saved for a possible **Nightmare mode**.
  6. badges: **done** as the in-game achievements at the Commendations board.

## 10. Changelog (newest first; one line per task)
- 2026-11-02: **guided tutorial.** The first-time run is now 5 waves with a quarter-health "young" Titan on wave 5, and a new `TutorialService` walks the player through 8 steps (gun upgrade, Vitality, ability, a scripted supply drop, ultimate, boss, Gems) with radio lines and a new objective card (`TutorialController`). Steps are data in the new `Config/Tutorial` (the old `GameConfig.Tutorial` block and `Radio.TutorialTips` are gone). Flat 250-Gem reward and 12s results. The HUD wave counter reads the new GameState `TotalWaves` (targeted edit on AnimatedSL's HUD). Played through in Studio: every step completed, boss 4,500 HP, +250 Gems, back to the lobby.
- 2026-11-02: **ready for a playerbase: squads, private servers, tutorial, bigger lobby.**
  - **City:** the overhead wires between street lamps and over alleys are gone (they read as gridlines over the map from above). 124 baked parts were deleted, and `OurCity` no longer builds them.
  - **Lobby moved** from z = 380 to **z = 1000** (`PivotTo`, so hand edits are kept; terrain sea refilled at the old spot and cleared at the new one).
  - **Flight Line:** a gate replaces the middle north ruin and leads to a fenced deck with **4 helipads** (new builder `Server/Map/FlightLine`; `OurLobby.Build` calls it, a one-line insert into AnimatedSL's live `OurLobby`).
  - **Squads:** new `QueueService`. The first player on a pad hosts and picks squad size, difficulty and map on a new squad panel (`LobbyController`); Hard and a second map are locked "SOON". Countdown 15s, or 4s once full.
  - **Private servers:** live squads are teleported into a reserved server of this place, and `MatchService` there waits for the squad, plays one run (`RunMatch(players, options)`), then sends everyone back. Studio plays the run in the lobby server instead. Live lobby servers delete the Arena.
  - **Tutorial:** new players (`TutorialDone` profile flag) are sent straight into a solo 3-wave run with radio tips. It's marked done even on a loss, and it isn't counted as a win.
  - **Tested in Studio:** pad boarding, host options, take-off, overrun back to the new lobby, and the tutorial (3 waves, no boss, +115 Gems). **Not tested:** the teleports, which only work in a published game.
  - Only targeted edits went into AnimatedSL's live `GameConfig` (the Lobby block, a new Tutorial block and LobbyCenter) and `OurLobby`.
- 2026-11-02: **UI + cutscene fix pass (playtest list).**
  - **UI scales with the screen:** a new `UIKit.AutoScale(root)` (designed for an 800-px-tall screen, clamped 0.6–1.5) is on the HUD, Lobby, Shop, Radio, Airdrop, cutscene captions and boss title. HUD mouse-follow positions are divided by its scale.
  - **Ghost "RELOADING" text:** `UIKit.Label` outlines now fade with `TextTransparency`.
  - **Bottom-right HUD redone:**
    - The weapon card has a level-colour stripe, the gun name with "LV n", a big ammo count with "/ mag", and a mag bar.
    - Cash is its own chip.
    - Upgrade buttons have a key plate and a price, and light green when affordable.
    - The duplicate "SPEND YOUR CASH" buy window was removed.
  - **Lobby:** the chip scale went from 0.9 to 0.75, and the status bar is 560 wide (no wrap). "NEW BEST" no longer shows on a wave-1 overrun.
  - **Radio:** the panel is tighter (420×100). It no longer pops back on during the boss intro. It stays on during the drop-in on purpose, since it carries the Deploy/Drop lines.
  - **Parachute:** the camera faces the body (the canopy is built off the root), and only thin forearms are drawn.
  - **Boss intro:** the close-up is pulled back to 24 studs, the title sits over the bottom letterbox, and the camera is levelled at the boss on hand-back.
  - **Debug and HUD fixes:** `God` now carries over to new characters (the `DebugGod` attribute). The HUD teammate row bug (`entry.Frame` was nil) is fixed.
  - **What was committed:**
    - Committed: Cutscene, Boss, Radio, Airdrop, DebugService, and `UIKit.AutoScale` only.
    - Committed in `1314d2c` (synced from Studio, so it also carries AnimatedSL's live edits to these four files): HUDController, LobbyController, ShopController, and the UIKit Label change. HUD guards `ViewmodelController:GetAim`/`IsScoped` (Studio-only aim-down-sights WIP).
- 2026-11-02: **lobby island.** The lobby moved from z = 235 to 380 (`GameConfig.OurMap.LobbyCenter`; the baked model was shifted with `PivotTo`, so hand edits are kept). A `Foundation` slab (184 × 172, slate, down to Y ≈ −25) now sits under the whole footprint, and the terrain water inside it is cleared, so the ocean no longer shows between the buildings. Only targeted edits went into `OurLobby.buildGround` and `GameConfig`.
- 2026-11-02: **boss overhaul + sound fix.**
  - **Boss:** the Grave Titan now spawns at the new `BossSpawn` marker (south avenue, in the open) after a 7s entrance cutscene.
    - **Server:** `MatchService:_bossIntro` freezes players and sets the `BossIntro` player attribute, which makes CameraController stand down.
    - **Client:** the new `BossController` handles the camera, title, drums, HUD hide, boss music and knockback.
    - **New moves:** Charge (red lane) and Leap (red ring), added to the slam (`Zombies.GraveTitan.Charge` / `Leap` / `SpecialGap` / `Intro`). `ZombieService:Spawn` takes `faceTowards`, and there's a new `:Hold`.
  - **Sound fix:** SoundController one-shots were destroyed after `TimeLength`, which is 0 before the asset loads, so first plays cut off at ~1s (the wave sting). They now clean up on `Ended`, with a 30s safety net.
  - **Hand cannon:** back to the pistol grip, and recoil is now 3.
- 2026-11-02: **owner playtest fixes.**
  - The hand cannon is back to the "Heavy Pistol Gunshot" sound (`3102797479`), and its recoil went from 4 to 2.2.
  - The hand cannon is held SMG-style, with the left hand under the barrel (`ViewmodelController`, where `pistol` excludes the Revolver).
  - Both shotguns use "HM Shotgun Shot" again. AnimatedSL's `9112913564` is the pump rack: it's now `ShotgunPump`, played 0.35s after a **pump-shotgun** shot only, through an optional third field in `Sounds.Guns`.
  - The Scout ultimate is now **Hunter's Mark** (new `Mark` type). Zombies within 70 studs glow red and take ×1.75 damage for 10s (`ZombieService:Mark`).
  - Toasts moved down to y = 68, below Roblox's top bar.
  - Edits to AnimatedSL's live Sounds, SoundController, ViewmodelController and HUDController were targeted only.
- 2026-11-02: **achievements + supply drops.**
  - 22 achievements that pay Gems, claimed at the new Commendations board, south of the plaza.
  - Mid-run supply crates you fight to reach, with timed buffs, ult, cash or gems.
  - Edits to AnimatedSL's live `OurLobby` were targeted inserts only; their helipad glow is kept, and it's still not in the repo.
  - **Idea from the owner:** a future "Nightmare" mode built from a blackout wave plus an extraction wave.
- 2026-11-02: **Engineer nerf.** Early Sentry cooldown is 42s through wave 4, sentry range drops from 65 to 30 (Nest from 75 to 35), and the Nest needs twice the ult charge. HUD ability bar uses the early cooldown (targeted edit on AnimatedSL's live HUDController).
- 2026-11-02: **class figures + barracks upgrade.** `ClassFigures` now gives each class a face, vest, gloves, a pose and class kit. The barracks is a tent on a deck with string lights, class-coloured pedestal rings, nameplates and spotlights. It was rebuilt in place with the new `OurLobby.RebuildBarracks()`. Three debris chunks overlapping the deck were deleted from the baked lobby, and `buildDebris` now skips that area.
- 2026-11-02: lobby info chip scaled to 0.75 and moved to (16, 68), below Roblox's top-bar buttons.
- 2026-11-02: parachute follow-up. The full-length arms are back (they fill the screen edges, which the owner prefers). Landing ends the fall at once: the client ends the drop view when the canopy disappears, and `_parachute` clears that player's `Deploying` on touchdown. Before, the fall view lingered about 1s until the shared timer ran out.
- 2026-11-02: **first-person parachute drop.** Freefall, then a ram-air canopy that opens with a jolt; you look up at it and sway down holding the toggles. Your body and gun are hidden locally during the fall. `DropHeight` 75→110 and `FallSpeed` 30→22, so the chute ride lasts about 4s. Only a targeted line edit went into AnimatedSL's live `GameConfig`.
- 2026-11-02: **deploy cutscene sound + effects** (wind, sea, spray, radio chatter, door streaks, jump whoosh, chute, fall wind). Only two small inserts went into AnimatedSL's live `Sounds` and `SoundController`; their footstep, reload and impact work there is still Studio-only, so the repo copies are older plus the same inserts.
- 2026-11-02: **helipad ready zone + first-person deploy cutscene.** The lobby countdown waits for someone to be on the helipad. The ride starts over the ocean, includes a cabin and a pilot, and the server-built path never clips a building. Place edits: terrain sea all round the map, and `Baseplate` sunk to Y = -21 and made invisible. Also exported AnimatedSL's first-person, sounds and throw work into the repo, which supersedes the "not committed" note below.
- 2026-11-02: lobby shops. Armory and Barracks are walk-up shops with 3D gun and class previews; the side panels are gone and the screen keeps only the chip and Ready bar. **Friend's work in progress seen in Studio, not committed:** `ViewmodelController` (first-person viewmodel), `Config/Sounds`, plus edits to `Camera`, `Weapon` and `GameConfig`. `WeaponController` calls a `SoundController` that doesn't exist yet, so in Studio it throws `attempt to index nil with 'SetSpin'` every frame until they add it. Coordinate before exporting those files.
- 2026-11-01: wrote this guide; moved the export/import/bot tools into `tools/`.
- 2026-11-01: balance pass (spawns spread over a time window, full heal on wave clear). `94efbee`
- 2026-11-01: phase 7, 10-wave run, Grave Titan boss and victory. `16cf951`
- 2026-11-01: phase 6, random spawns with red warning circles. `2283f74`
- 2026-11-01: phase 5, zombie models and AI. `1a3efef`
- 2026-11-01: phase 4, guns; restored after the Team Create overwrite; deleted the friend's map and the old generator. `115a71b`
- 2026-11-01: phases 1–3: lobby, city, drop-in and radio. `4840b5c`, `d708bb0`, `8f3eba4`
