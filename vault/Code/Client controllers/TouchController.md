# TouchController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/TouchController.luau` (168 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
TouchController: run controls for phones and gamepads (keyboard + mouse live in WeaponController and
InputController). Phones get on-screen buttons on the right while the run camera is on: FIRE (hold),
AIM (toggle), RELOAD, ABILITY (E) and ULTIMATE (F); drag anywhere else to look, the left stick moves.
The HUD's upgrade buttons are tappable already, and ProximityPrompts (supply crates) are tappable.
Gamepad: R2 fire, L2 aim, X reload, L1 ability, R1 ultimate, D-pad up gun upgrade, D-pad right
Vitality, Y opens a supply crate (its prompt).
```

## Uses

- [[CameraController]]
- [[InputController]]
- [[Remotes]]
- [[UIKit]]
- [[WeaponController]]

## Used by

- (none)
