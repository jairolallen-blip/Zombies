---
tags: [zone-config]
cssclasses: [zone-config]
---

# GameConfig (Zombies)

> Made by `tools/vault-code-notes.js` from `src/shared/Config/GameConfig.luau` (220 lines). Don't edit it here: rerun the script.

Part of [[Config (Zombies)|Config]].

## What it does

```text
GameConfig: global tunables for match flow, waves, economy, upgrades, player, camera, map.
PURE DATA. Safe to edit numbers here; no logic lives in this file.
Read by both server and client (ReplicatedStorage.Shared.Config.GameConfig).
```

## Uses

- (none)

## Used by

- [[AbilityService (Zombies)]]
- [[AirdropService (Zombies)]]
- [[BossController (Zombies)]]
- [[CameraController (Zombies)]]
- [[CombatService (Zombies)]]
- [[Commons (Zombies)]]
- [[CommonsService (Zombies)]]
- [[CutsceneController (Zombies)]]
- [[DailyCache (Zombies)]]
- [[DailyService (Zombies)]]
- [[DataService (Zombies)]]
- [[EconomyService (Zombies)]]
- [[FieldStations (Zombies)]]
- [[FlightLine (Zombies)]]
- [[GroundFxController (Zombies)]]
- [[HUDController (Zombies)]]
- [[InputController (Zombies)]]
- [[LobbyAudioController (Zombies)]]
- [[LobbyController (Zombies)]]
- [[LobbyMenu (Zombies)]]
- [[MapService (Zombies)]]
- [[MatchService (Zombies)]]
- [[ModePad (Zombies)]]
- [[OurCity (Zombies)]]
- [[OurLobby (Zombies)]]
- [[PostFXController (Zombies)]]
- [[QueueService (Zombies)]]
- [[ShopController (Zombies)]]
- [[Survivors map (Zombies)]]
- [[TutorialService (Zombies)]]
- [[Util (Zombies)]]
- [[ViewmodelController (Zombies)]]
- [[WeaponController (Zombies)]]
- [[ZombieService (Zombies)]]

## Mentions

- [[Nightmare config (Zombies)]]

## Design notes

- [[Match Start]]
- [[Spawning]]
- [[Waves and Boss]]
- [[Weapons]]
- [[Lobby]]
- [[City Map]]
