# NavGrid

> Made by `tools/vault-code-notes.js` from `src/server/Map/NavGrid.luau` (235 lines). Don't edit it here: rerun the script.

Part of [[Map builders]].

## What it does

```text
NavGrid: flow-field navigation for the zombie horde (cheap enough for 70+ zombies, unlike
per-zombie PathfindingService calls).

1. Build(): scans the arena once into a grid of CellSize cells. A cell is blocked if any
   CanCollide part (fence, terrace wall, prop...) overlaps it between knee and head height.
2. A "flow field" for a target cell = walking distance from every cell to that cell (Dijkstra,
   8 directions, no corner cutting). The map is static, so a field never changes: fields are
   cached per target cell (LRU, MAX_FIELDS) and only computed when a player enters a new cell.
3. GetDirection(from, target): step toward the neighbouring cell with the lowest distance.
Zombies use it only when they have no clear line to the player (see ZombieService).

Public:
  NavGrid.Build(center, halfSize, cellSize, groundY, ignore, lattice?)
      ignore = instances to skip in the scan; lattice = a corner of the map's ground cell grid
      (MapService:GetNavBounds()) so nav cells line up with terrace/graveyard cells
  NavGrid.GetDirection(fromPos, targetPos) -> unit Vector3 (flat) or nil (no grid / no route / arrived)
  NavGrid.IsWalkable(pos) -> boolean
  NavGrid.Stats() -> string
```

## Uses

- (none)

## Used by

- [[DebugService]]
- [[MapService]]
- [[ZombieService]]
