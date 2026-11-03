# AbilityService

> Made by `tools/vault-code-notes.js` from `src/server/Services/AbilityService.luau` (256 lines). Don't edit it here: rerun the script.

Part of [[Server services]].

## What it does

```text
AbilityService: class Abilities [E] (cooldown) and Ultimates [F] (charge from kills).
Class -> ability mapping is data in Config.Classes; behaviour is a handler in `Handlers` below,
keyed by Ability.Type. To add a new ability type: add Handlers.MyType = function(ctx) ... end,
then reference Type = "MyType" from a class in Config.Classes.

ctx passed to a handler:
  ctx.Player, ctx.Character, ctx.Root (HumanoidRootPart), ctx.Params (from config),
  ctx.Target (aim point on the ground, already clamped to Params.Range), ctx.Services

Player attributes: AbilityReadyAt (server time), UltCharge (written by EconomyService on kills)
```

## Uses

- [[Classes config]]
- [[CombatService]]
- [[GameConfig]]
- [[GameState]]
- [[MapService]]
- [[MatchService]]
- [[Remotes]]
- [[ZombieService]]

## Used by

- [[MatchService]]
