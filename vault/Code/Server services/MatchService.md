# MatchService

> Made by `tools/vault-code-notes.js` from `src/server/Services/MatchService.luau` (633 lines). Don't edit it here: rerun the script.

Part of [[Server services]].

## What it does

```text
MatchService: the game loop. Owns who is in the run, spawning characters, waves, and results.

Two kinds of server run this place (MatchService.IsMatchServer):
  lobby server   the safehouse; squads queue on the Flight Line pads (QueueService). On a live server a
                 squad that takes off is teleported to its own reserved server; in Studio (no
                 teleports) QueueService calls :RunMatch here instead, one run at a time
  match server   a reserved server holding one squad (or one first-time player's tutorial): waits for
                 the squad to arrive, plays one run, then teleports everyone back to a lobby server

A run (:RunMatch(players, options); options = Difficulty, Map, Tutorial from the pad / teleport data):
  Deploy (helicopter cutscene, players parachute onto the arena spawns; see _deploy)
  loop:  Break (countdown, dead teammates respawn) -> Wave (spawn N zombies, wait until cleared)
  the last wave (GameConfig.Waves.TotalWaves) is the boss wave; clearing it wins the run
  (tutorial: Config/Tutorial: fewer waves, a weaker boss, its own Gems reward; TutorialService walks
  the player through the mechanics)
  ends on victory or when every participant is dead or gone -> Results (Gems, saved) -> lobby
The commander comments on each step over Remotes.Radio (lines in Shared/Config/Radio).

Writes GameState attributes (ServerKind, Phase, Wave, TotalWaves, Timer, ZombiesLeft, Difficulty,
MapId, Tutorial) and player attribute InRun. Wave sizes/timings come from GameConfig.Waves.

Public:
  MatchService.IsMatchServer
  MatchService:RunMatch(players, options), :IsRunning()
  MatchService:IsInRun(player), :IsAliveInRun(player), :GetRunPlayers()
  MatchService:SpawnInLobby(player), :SpawnInArena(player, cframe?)
  MatchService:ReviveDead(cframe)       respawn every dead participant near cframe
```

## Uses

- [[AbilityService]]
- [[CombatService]]
- [[Conditions config]]
- [[DataService]]
- [[EconomyService]]
- [[GameConfig]]
- [[GameState]]
- [[MapService]]
- [[QueueService]]
- [[Radio config]]
- [[Remotes]]
- [[Tutorial config]]
- [[TutorialService]]
- [[ZombieService]]
- [[Zombies config]]

## Used by

- [[AbilityService]]
- [[AirdropService]]
- [[CombatService]]
- [[DailyService]]
- [[DebugService]]
- [[EconomyService]]
- [[LobbyService]]
- [[MapService]]
- [[QueueService]]
- [[ZombieService]]

## Mentions

- [[BossController]]
- [[SkipController]]

## Design notes

- [[Spawning]]
