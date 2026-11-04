# PostFXController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/PostFXController.luau` (182 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
PostFXController: client-side "shaders" -- a moody, slightly more realistic, cinematic grade
layered on top of the server's base sunset (MapService:ApplyAtmosphere). Darker exposure, warm
deep shadows, thicker dusty haze, more contrast, a little less saturation, extra bloom, autofocus
depth of field (focus follows the crosshair; stronger while aiming down sights) and a screen
vignette. Everything is local to this client (Lighting changes made by a client don't replicate).

OFF while Deploying: the base lighting is restored exactly, so the deploy cutscene looks as designed.
Tuning: GameConfig.PostFX (Enabled = false turns the whole thing off).

Public: PostFXController:IsActive()
```

## Uses

- [[CameraController]]
- [[GameConfig]]
- [[GameState]]
- [[ViewmodelController]]

## Used by

- (none)

## Mentions

- [[Conditions config]]
