# EffectsController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/EffectsController.luau` (424 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
EffectsController: all client-side visuals. Parts go in Workspace.ClientEffects (non-queryable).
  * Server effects arrive via Remotes.Effect(kind, data) and dispatch to EffectsController.Handlers[kind]
  * Damage numbers from Remotes.HitConfirm
  * Zombie walk animation: swings each zombie's limb Motor6Ds locally (no server cost)
To add an effect: add Handlers.MyEffect = function(data) ... end and fire it from the server with
  Remotes.Effect:FireAllClients("MyEffect", { ... })
```

## Uses

- [[Remotes]]
- [[UIKit]]
- [[Weapons config]]

## Used by

- [[BossController]]
- [[ThrowController]]
- [[WeaponController]]
