---
tags: [zone-client]
cssclasses: [zone-client]
---

# WeaponController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/WeaponController.luau` (277 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
WeaponController: shooting input, client-side prediction (ammo, tracers, muzzle flash), and
sending FireWeapon to the server (which re-validates and applies damage — see CombatService).
Stats come from Util.GetWeaponStats(WeaponId, WeaponTier) — same formula as the server.
Feel (vault: Weapons.md): camera recoil kick (stats.Recoil), per-gun tracers/flash, ejected
shells, and SpinUp guns (minigun) that ramp their fire rate while the barrel hub spins.

First person: shots originate at the camera (eye) through the crosshair; the flash, tracers,
shells and recoil jolt come from ViewmodelController's gun. Sounds via SoundController.
Hold Keybinds.Aim (right mouse) to aim down sights: ViewmodelController blends the gun to the
centre and spread shrinks by GameConfig.Camera.AimSpreadMultiplier.

Public: WeaponController:GetState() -> { Stats, Ammo, Reloading }, :Reload(), :IsAimHeld()
```

## Uses

- [[CameraController]]
- [[EffectsController]]
- [[GameConfig]]
- [[HUDController]]
- [[Remotes]]
- [[SoundController]]
- [[Util]]
- [[ViewmodelController]]

## Used by

- [[CameraController]]
- [[HUDController]]
- [[TouchController]]
- [[ViewmodelController]]

## Design notes

- [[Weapons]]
