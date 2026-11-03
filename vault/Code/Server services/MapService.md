# MapService

> Made by `tools/vault-code-notes.js` from `src/server/Services/MapService.luau` (257 lines). Don't edit it here: rerun the script.

Part of [[Server services]].

## What it does

```text
MapService: answers "where do things spawn" for our map and applies its sunset atmosphere.
The map itself is baked into Workspace.<OurMap.Folder> in Edit mode by Server/Map/OurLobby and
Server/Map/OurCity (vault: Lobby.md, City Map.md); this only reads the marker parts:
  Lobby: "LobbySpawn" parts + the Flight Line pads ("Helipad" models with PadId, part "Pad")
  Arena: "PlayerSpawn" + "ZombieSpawn" parts

Public:
  MapService.GroundY
  MapService:GetLobbySpawnCFrame(), :GetArenaSpawnCFrame(index?)
  MapService:GetZombieSpawnPosition(usePads?)  random open street spot around a living player
    (GameConfig.Waves.SpawnMin/MaxDistance, vault: Spawning.md); usePads = a fixed ZombieSpawn pad
  MapService:GetZombiePads() -> {Vector3}
  MapService:GetBossSpawn() -> Vector3   the "BossSpawn" marker (open ground facing the square)
  MapService:GetNavBounds() -> center, halfSize, lattice   (area the zombie NavGrid scans)
  MapService:GetDeployPoints() -> from, to   (pad 1 -> arena spawns, ground level)
  MapService:GetPads() -> {[PadId] = Pad part}   Flight Line pads (QueueService)
  MapService:GetPadAt(player) -> PadId?      the pad the player stands on (its take-off zone)
  MapService:GetDeployFlight() -> {Vector3}   helicopter path, ocean -> above the square
  MapService:ApplyAtmosphere()
```

## Uses

- [[GameConfig]]
- [[MatchService]]
- [[NavGrid]]

## Used by

- [[AbilityService]]
- [[AirdropService]]
- [[DebugService]]
- [[MatchService]]
- [[QueueService]]
- [[ZombieService]]

## Mentions

- [[OurCity]]
- [[OurLobby]]

## Design notes

- [[Lobby]]
- [[City Map]]
- [[Spawning]]
