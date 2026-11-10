---
tags: [zone-map]
cssclasses: [zone-map]
---

# OurCity (Zombies)

> Made by `tools/vault-code-notes.js` from `src/server/Map/OurCity.luau` (699 lines). Don't edit it here: rerun the script.

Part of [[Map builders (Zombies)|Map builders]].

## What it does

```text
OurCity: builds our version's arena, an overgrown apocalyptic city at sunset (vault: City Map.md).
BAKED into Workspace.OurMap.Arena in Edit mode so it can be hand-edited afterwards:
  local m = game.ServerScriptService.Server.Map.OurCity
  local c = m:Clone(); c.Parent = m.Parent; require(c).Build(); c:Destroy()

The whole layout is the LAYOUT tile plan below (TILE studs per character, north = -Z):
  # building   . road   S city square   P park   A alley   L parking lot   M market
Rules that keep the horde flowing (zombies use Map/NavGrid): the floor is perfectly flat (paint,
no steps), walkable gaps are >= 1 tile wide, every side area has 2+ exits, and decorative bits
(facades, canopies, foliage) are CanCollide = false so only real cover blocks the nav grid.
Parts named "PlayerSpawn" / "ZombieSpawn" / "BossSpawn" are read by MapService.
```

## Uses

- [[GameConfig (Zombies)]]

## Used by

- (none)

## Design notes

- [[City Map]]
