# HUDController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/HUDController.luau` (435 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

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

- [[CameraController]]
- [[Classes config]]
- [[GameConfig]]
- [[GameState]]
- [[ReadyFx]]
- [[Remotes]]
- [[UIKit]]
- [[Util]]
- [[ViewmodelController]]
- [[WeaponController]]
- [[Weapons config]]

## Used by

- [[WeaponController]]
