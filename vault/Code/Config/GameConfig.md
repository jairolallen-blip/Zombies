# GameConfig

> Made by `tools/vault-code-notes.js` from `src/shared/Config/GameConfig.luau` (179 lines). Don't edit it here: rerun the script.

Part of [[Config]].

## What it does

```text
GameConfig: global tunables for match flow, waves, economy, upgrades, player, camera, map.
PURE DATA. Safe to edit numbers here; no logic lives in this file.
Read by both server and client (ReplicatedStorage.Shared.Config.GameConfig).
```

## Uses

- (none)

## Used by

- [[AbilityService]]
- [[AirdropService]]
- [[BossController]]
- [[CameraController]]
- [[CombatService]]
- [[CommonsService]]
- [[Commons]]
- [[CutsceneController]]
- [[DailyCache]]
- [[DailyService]]
- [[DataService]]
- [[EconomyService]]
- [[FlightLine]]
- [[HUDController]]
- [[InputController]]
- [[LobbyAudioController]]
- [[LobbyController]]
- [[MapService]]
- [[MatchService]]
- [[OurCity]]
- [[OurLobby]]
- [[QueueService]]
- [[ShopController]]
- [[Survivors map]]
- [[TutorialService]]
- [[Util]]
- [[ViewmodelController]]
- [[WeaponController]]
- [[ZombieService]]

## Design notes

- [[Match Start]]
- [[Spawning]]
- [[Waves and Boss]]
- [[Weapons]]
- [[Lobby]]
- [[City Map]]
