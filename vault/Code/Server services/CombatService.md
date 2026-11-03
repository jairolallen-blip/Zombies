# CombatService

> Made by `tools/vault-code-notes.js` from `src/server/Services/CombatService.luau` (230 lines). Don't edit it here: rerun the script.

Part of [[Server services]].

## What it does

```text
CombatService: weapons (server-validated hitscan), reloads, explosions, and damage to players.

Flow of a shot: client WeaponController raycasts for visuals and sends FireWeapon(origin, dirs)
-> _onFire validates (alive, ammo, fire rate, origin near head, pellet count)
-> re-raycasts each direction on the server (with Pierce) -> ZombieService:Damage
-> HitConfirm to the shooter, Tracer effect to everyone else.

Player attributes written here: WeaponId, Ammo, MagSize, Reloading
Public:
  CombatService:EquipLoadout(player)   give the Loadout gun for the current WeaponTier (= Level), full ammo
  CombatService:RefreshWeapon(player)  re-apply after a Level upgrade
  CombatService:Reload(player)
  CombatService:DamagePlayer(player, amount)          applies class DamageTakenMult and MatchService.ZombieDamageMult (Nightmare)
  CombatService:Explode(position, radius, damage, attacker?, { PlayerDamage = n? })
  CombatService.EffectsFolder          Workspace.Effects (non-queryable server visuals)
```

## Uses

- [[AirdropService]]
- [[Classes config]]
- [[DataService]]
- [[GameConfig]]
- [[GunModels]]
- [[MatchService]]
- [[Remotes]]
- [[Util]]
- [[Weapons config]]
- [[ZombieService]]

## Used by

- [[AbilityService]]
- [[AirdropService]]
- [[EconomyService]]
- [[MatchService]]
- [[ZombieService]]
