# ThrowController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/ThrowController.luau` (175 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
ThrowController: the grenade throw animation (server sends Remotes.Effect "Throw" from
AbilityService's Grenade handler; timings in GameConfig.Throw).
  * Your own throw in first person -> ViewmodelController:PlayThrow (arm + grenade in view)
  * Everyone else (and you in third person) -> the character's right arm winds up over the
    shoulder and swings through, holding a client-only grenade until release. The arm is driven
    by overriding the RightShoulder Motor6D.Transform after the Animator runs each frame, blended
    in/out so it mixes with the tool-hold animation.
Also provides the grenade model (viewmodel hand + flying projectile) and the thrower's hand
position so your projectile visually leaves your first-person hand.

Public: ThrowController.MakeGrenade(parent) -> Model, ThrowController:IsThrowing(character)
```

## Uses

- [[CameraController]]
- [[EffectsController]]
- [[ViewmodelController]]

## Used by

- [[ViewmodelController]]
