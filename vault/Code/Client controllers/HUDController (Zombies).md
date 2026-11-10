---
tags: [zone-client]
cssclasses: [zone-client]
---

# HUDController (Zombies)

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/HUDController.luau` (529 lines). Don't edit it here: rerun the script.

Part of [[Client controllers (Zombies)|Client controllers]].

## What it does

```text
HUDController: the in-run HUD. Visible only while the player attribute InRun is true.
Layout (by priority, see research/03-ui-ux.md):
  cursor        crosshair + hitmarker (follow the free mouse; aim = CameraController:GetAimPoint)
  top centre    wave / phase text, big banner on wave start, boss bar
  bottom left   health bar, Ability [E] and Ultimate [F] slots
  bottom right  weapon card (level stripe, name, ammo + mag bar), Cash chip
                upgrade buttons above it: [1] weapon level, [2] vitality (lit green when affordable)
  top right     toast messages (Remotes.Notify)
Everything refreshes in one RenderStepped loop from attributes (player + GameState).
```

## Uses

- [[CameraController (Zombies)]]
- [[Classes config (Zombies)]]
- [[GameConfig (Zombies)]]
- [[GameState (Zombies)]]
- [[ReadyFx (Zombies)]]
- [[Remotes (Zombies)]]
- [[UIKit (Zombies)]]
- [[Util (Zombies)]]
- [[ViewmodelController (Zombies)]]
- [[WeaponController (Zombies)]]
- [[Weapons config (Zombies)]]

## Used by

- [[WeaponController (Zombies)]]
