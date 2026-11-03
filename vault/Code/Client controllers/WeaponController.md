# WeaponController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/WeaponController.luau` (229 lines). Don't edit it here: rerun the script.

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

Public: WeaponController:GetState() -> { Stats, Ammo, Reloading }, :Reload()
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

- [[HUDController]]
- [[TouchController]]

## Design notes

- [[Weapons]]
