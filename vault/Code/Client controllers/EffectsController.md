# EffectsController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/EffectsController.luau` (581 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
EffectsController: all client-side visuals. Parts go in Workspace.ClientEffects (non-queryable).
  * Server effects arrive via Remotes.Effect(kind, data) and dispatch to EffectsController.Handlers[kind]
  * Damage numbers from Remotes.HitConfirm
  * Zombie animation: plays keyframed gaits (Shared/ZombieGaits) on each zombie's Motor6Ds locally (no server cost)
  * Zombie hit reaction: "ZombieHit" makes the zombie flinch and flash red (animateZombies)
To add an effect: add Handlers.MyEffect = function(data) ... end and fire it from the server with
  Remotes.Effect:FireAllClients("MyEffect", { ... })
```

## Uses

- [[Remotes]]
- [[UIKit]]
- [[Weapons config]]
- [[ZombieGaits]]
- [[Zombies config]]

## Used by

- [[BossController]]
- [[ThrowController]]
- [[WeaponController]]
