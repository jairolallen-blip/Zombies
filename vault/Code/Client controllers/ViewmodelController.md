# ViewmodelController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/ViewmodelController.luau` (647 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
ViewmodelController: the first-person gun + arms you see while CameraController:IsActive().
Builds a client-only copy of the equipped gun with GunModels.BuildTool (same model as the real
Tool), scales it down (GameConfig.Camera.ViewmodelScale), parents it to the camera and poses it
every frame in camera space. Two blocky arms (olive sleeves, skin forearms, dark gloves) reach
the grip and the handguard with a two-bone IK. The real third-person Tool is hidden LOCALLY only
(other players still see it).

Pose layers (update -> compose): hip / aim-down-sights blend, mouse sway, walk bob + breathing,
strafe tilt, jump/land bounce, recoil jolt, equip raise, wall tuck, reload (the mag really comes
out on guns that have one), grenade throw (right arm leaves the grip).

Public:
  :GetMuzzle() / :GetEjectPort() -> Attachment? (nil when inactive)        (WeaponController)
  :GetModel() -> Model? (has SpinHub/SpinWeld for spinning guns)
  :Kick(recoilDegrees, fireRate?)                                    (WeaponController, per shot)
  :GetAim() -> 0..1, :IsScoped() -> bool, :GetAimFieldOfView()        (Camera, Weapon, HUD)
  :PlayReload(seconds)                                                (WeaponController:Reload)
  :PlayThrow(windup, duration), :IsThrowing(), :GetThrowHand() -> Vector3?  (ThrowController)
  ViewmodelController.Preview(camCF, weaponId, tier, pose) -- Edit-mode visual check (bottom)
```

## Uses

- [[CameraController]]
- [[GameConfig]]
- [[GunModels]]
- [[SoundController]]
- [[ThrowController]]
- [[Util]]
- [[WeaponController]]

## Used by

- [[CameraController]]
- [[HUDController]]
- [[PostFXController]]
- [[ThrowController]]
- [[WeaponController]]
