---
tags: [zone-shared]
cssclasses: [zone-shared]
---

# GunModels

> Made by `tools/vault-code-notes.js` from `src/shared/GunModels.luau` (285 lines). Don't edit it here: rerun the script.

Part of [[Shared modules]].

## What it does

```text
GunModels: blocky low-poly gun models built from parts, one per weapon id (vault: Weapons.md;
style from MODEL REFERENCES). GunModels.BuildTool(stats) -> Tool used by CombatService.

Gun space: the grip ("Handle") sits at the origin, the gun points along -Z, +Y is up.
Spec entries: { name, size, position or CFrame, color, opts? }
  color  = a COLORS key, or "LEVEL" for the level stripe (stats.TierColor, neon)
  opts   = { Tube = true }  cylinder along Z (size = Vector3.new(diameter, diameter, length))
           { Drum = true }   cylinder along X (size = Vector3.new(thickness, diameter, diameter))
           { Neon = true, Hub = true (child of the minigun's spinning hub), Transparency = n }
Each spec also has Muzzle (Vector3) and optionally Hub (Vector3) for spinning barrels.
```

## Uses

- (none)

## Used by

- [[CombatService]]
- [[OurLobby]]
- [[ShopController]]
- [[ViewmodelController]]

## Design notes

- [[Weapons]]
