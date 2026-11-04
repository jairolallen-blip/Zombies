# CameraController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/CameraController.luau` (212 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
CameraController: FIRST-PERSON run camera + the single source of truth for AIMING.
In a run (not while the deploy cutscene owns the camera) the view is a SCRIPTABLE first-person
camera: we rotate it ourselves from the mouse delta, because Roblox's MouseDeltaSensitivity does
NOT affect the default camera scripts — owning the rotation is the only way to get a real ADS
sensitivity. The mouse is locked to the screen centre; aim = a ray through the centre.
Hold Left Alt to free the cursor (e.g. to click HUD buttons); look rotation pauses while held.
Phones look by dragging on open screen (TouchStarted not processed by a button/stick); gamepads
look with the right stick. Both feed the same delta as the mouse, so ADS sensitivity applies.
In the lobby the default third-person camera + normal cursor return.
The gun you see in first person is drawn by ViewmodelController (the real Tool is hidden locally).
Aiming down sights (ViewmodelController:GetAim) zooms the FOV and slows the look speed.
Tunables: GameConfig.Camera (LookSensitivity, AimSensitivity, FieldOfView).

Public (used by WeaponController, InputController, HUDController, ViewmodelController):
  CameraController:IsActive()          true while the first-person run camera is on
  CameraController:GetMouseLocation()  Vector2 (viewport pixels; screen centre while locked)
  CameraController:GetAimRay()         Ray through the aim point on screen
  CameraController:GetAimPoint()       Vector3 world point under the crosshair
```

## Uses

- [[GameConfig]]
- [[LobbyController]]
- [[ViewmodelController]]
- [[WeaponController]]

## Used by

- [[HUDController]]
- [[InputController]]
- [[PostFXController]]
- [[ThrowController]]
- [[TouchController]]
- [[ViewmodelController]]
- [[WeaponController]]
