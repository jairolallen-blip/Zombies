# ViewmodelController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/ViewmodelController.luau` (310 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
ViewmodelController: the first-person gun + arms you see while CameraController:IsActive().
Builds a client-only copy of the equipped gun with GunModels.BuildTool (same model as the real
Tool), parents it to the camera, and positions it every frame in camera space
(GameConfig.Camera.ViewmodelOffset) with recoil jolt, mouse sway and walk bob. Two blocky arms
(character arm colours) reach the grip and the barrel. The real third-person Tool is hidden
LOCALLY only (other players still see it).

Public (used by WeaponController):
  ViewmodelController:GetMuzzle()   -> Attachment? (viewmodel Handle.Muzzle; nil when inactive)
  ViewmodelController:GetEjectPort() -> Attachment?
  ViewmodelController:GetModel()    -> Model? (has SpinHub/SpinWeld for spinning guns)
  ViewmodelController:Kick(recoilDegrees)
Public (used by ThrowController / WeaponController):
  ViewmodelController:PlayThrow(windup, duration) -- gun dips, right arm throws a grenade
  ViewmodelController:IsThrowing() -> bool (firing is blocked meanwhile)
  ViewmodelController:GetThrowHand() -> Vector3? (grenade hand while throwing, for the projectile)
```

## Uses

- [[CameraController]]
- [[GameConfig]]
- [[GunModels]]
- [[ThrowController]]
- [[Util]]

## Used by

- [[HUDController]]
- [[ThrowController]]
- [[WeaponController]]
