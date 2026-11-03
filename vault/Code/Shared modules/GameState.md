# GameState

> Made by `tools/vault-code-notes.js` from `src/shared/GameState.luau` (54 lines). Don't edit it here: rerun the script.

Part of [[Shared modules]].

## What it does

```text
GameState: the one replicated Configuration instance holding match-wide state as attributes.
Server writes it (mostly MatchService); clients read with GetAttribute / GetAttributeChangedSignal.
require() returns the Instance itself:  GameState:GetAttribute("Wave")

Attributes:
  Phase          "Lobby" | "Deploy" | "Break" | "Wave" | "Results"
  DeployPath (JSON [[x,y,z],...]), DeployStart (server time), DeployDuration   drop-in cutscene
    (MapService:GetDeployFlight -> CutsceneController)
  Wave           current wave number (0 in lobby)
  TotalWaves     waves in the current run (GameConfig.Waves.TotalWaves, or Config/Tutorial.Waves)
  Timer          seconds left in the Break countdown
  ZombiesLeft    zombies still to spawn + alive this wave
  RunWon         true when the last run cleared every wave (read during "Results")
  BossEnraged    true once the boss passed its enrage threshold
  BossName       "" when no boss alive
  BossHealth, BossMaxHealth
  ServerKind     "Lobby" | "Match" (a squad's reserved server; MatchService.IsMatchServer)
  Difficulty, MapId, Tutorial   the current run's mission (MatchService:RunMatch)
  Pad1..Pad4     JSON state of each Flight Line pad (QueueService)
```

## Uses

- (none)

## Used by

- [[AbilityService]]
- [[AirdropService]]
- [[BossController]]
- [[CutsceneController]]
- [[DebugService]]
- [[HUDController]]
- [[LobbyAudioController]]
- [[LobbyController]]
- [[MatchService]]
- [[QueueService]]
- [[SoundController]]
- [[TutorialService]]
- [[ZombieService]]

## Mentions

- [[Tutorial config]]
