---
tags: [zone-gameplay]
cssclasses: [zone-gameplay]
game-zone: gameplay
---

# Outbreak

The million-zombie mode, and what's different about working on it. Back to [[Home]].

## What it is

- Its own place: 87622086122699, in the same experience as the main place (110463048909417).
- Pad 6 on the Flight Line queues it. QueueService teleports the squad to a fresh reserved server there.
- The horde is shared across the server, and the run is won at 1,000,000 kills, not by clearing waves. The HUD shows HORDE instead of WAVE.
- In Studio, pressing Play starts a run by itself.
- Numbers are in `Config/Outbreak`: MaxAlive 260, zombies at 0.8 scale and half health, normal gun damage. Tune them there.

## This place is not a copy of main

`src/` holds the main place's scripts. Outbreak has its own script copies, published separately, with a backup in `outbreak/`. That folder is a snapshot, not what the place runs: changes still go to Studio first, then refresh it. On 2026-11-05 it differed from main in these ways, and it may have drifted since:

- **Scripts that differ:** Config.Outbreak, Config.Sounds, Config.Weapons, Config.Zombies, OurLobby, CommonsService, DailyService, DataService, LobbyService, MapService, MatchService, QueueService, ZombieService, BossController, EffectsController, HUDController, LobbyController, StoreController, WelcomeController.
- **Scripts it doesn't have:** Config.Levels, ReadyFx, LobbyMenu, JoinCover, TrailerDirector.
- **No lobby in the map:** `OurMap` holds only `Arena`.
- **Horde code only here:** distance LOD in `EffectsController`, and far-zombie freezing and player ownership in `ZombieService`.

## Things that live only in the place file

| What | Record |
|---|---|
| Ocean: terrain water and the hidden Baseplate | Rebuilt by `tools/outbreak-ocean.luau` |
| Its script copies | Snapshot in `outbreak/`, with `hashes.txt` |

## Changing shared code

1. Run `../Game Kit/tools/app-check.ps1` and ask the owner to open Outbreak if it's missing.
2. Hash every script in both windows and compare.
3. Patch by exact text with `execute_luau`. Never copy a whole file across unless the hashes matched before the change.
4. Localhost is blocked there, so send changes inline. Check the result against main's hash where the file should match.
5. Press Play, spawn a horde with `SAMZ_Debug`, and check for errors.
6. Publish with Alt+P. The window may be on the second monitor, so wait about 4 seconds and look there for the "Published" message.

To refresh the snapshot: File > Download a Copy to a `.rbxl`, then `node "../Game Kit/tools/rbxl-scripts.js" <file> outbreak`. Compare `outbreak/hashes.txt` with Studio's hashes. Keep the `.rbxl` out of the repo.

Packages would end most of this copying. See [[Team Create Workflow]].

## Known issues

- With one player, every zombie close to them is simulated on that player's machine. At 272 zombies, client physics took about 55 ms, against 4 ms on the server. Studio ran both on one PC, so that's a worst case.
- Options: cap how many zombies a player owns, or replace part-built zombies with meshes. Neither is decided.
- The owner's run on 2026-11-05 didn't cover Outbreak. Phones are untested.

## History

- 2026-11-03: place created.
- 2026-11-05: deploy cutscene fix confirmed, new walk and moves added, ocean restored.
