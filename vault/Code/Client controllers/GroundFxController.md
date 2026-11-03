# GroundFxController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/GroundFxController.luau` (121 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
GroundFxController: disturbed earth where zombies break through the street (local only, nothing replicates).
  "SpawnWarning" (ZombieService:SpawnWarned, every rising zombie; the red circle itself is EffectsController's):
    when the zombie breaks through, a dark patch of churned dirt, a ring of broken rubble around the hole
    and a burst of dust, with a second puff as it hauls itself up; it all settles and fades after a few seconds
  "Burrow" (ZombieService:_burrow, a Skitter going under): clods of dirt thrown up, dust and the same patch
The zombie's own crawl (reaching up and clawing) is the "Rise" / "Burrow" pose in EffectsController.
```

## Uses

- [[GameConfig]]
- [[Remotes]]

## Used by

- (none)
