# CameraController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/CameraController.luau` (112 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
CameraController: FIRST-PERSON run camera + the single source of truth for AIMING.
In a run (not while the deploy cutscene owns the camera) the camera is locked to first person
with the mouse locked to the screen centre; aim = a ray through the centre of the screen.
Hold Left Alt to free the cursor (e.g. to click HUD buttons); aim then follows the cursor.
In the lobby the default third-person camera + normal cursor return.
The gun you see in first person is drawn by ViewmodelController (the real Tool is hidden locally).
Tunables: GameConfig.Camera.

Public (used by WeaponController, InputController, HUDController, ViewmodelController):
  CameraController:IsActive()          true while the first-person run camera is on
  CameraController:GetMouseLocation()  Vector2 (viewport pixels; screen centre while locked)
  CameraController:GetAimRay()         Ray through the aim point on screen
  CameraController:GetAimPoint()       Vector3 world point under the crosshair
```

## Uses

- [[GameConfig]]

## Used by

- [[HUDController]]
- [[InputController]]
- [[ThrowController]]
- [[TouchController]]
- [[ViewmodelController]]
- [[WeaponController]]
