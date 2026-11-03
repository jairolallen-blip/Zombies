# ZombieService

> Made by `tools/vault-code-notes.js` from `src/server/Services/ZombieService.luau` (782 lines). Don't edit it here: rerun the script.

Part of [[Server services]].

## What it does

```text
ZombieService: spawns zombies (models from Server/ZombieModels), runs their AI every Heartbeat,
and owns zombie health/death. Zombies live in Workspace.Zombies. Behaviour (vault: Zombies.md):
per-zombie speed variety, surround slots near the player, runner lunges, hit flinch, and an
"AttackAt" model attribute the client uses for the swipe animation.

Movement: each zombie is one physics assembly (invisible "Root" hitbox + welded/motor limbs).
A LinearVelocity (plane mode) drives it toward its target and an AlignOrientation faces it.
Physics handles zombie-vs-zombie and zombie-vs-cover collision for free. Zombies do NOT
collide with players (collision groups) so the horde can never permanently pin someone.
Routing: straight at the player when there's a clear line, otherwise down the flow field
(Server/Map/NavGrid.lua) around fences, terrace and props. See navigate().

Public:
  ZombieService:Spawn(typeId, position, healthMult?, riseTime?) -> Model
  ZombieService:SpawnWarned(typeId, position, healthMult?)   red circle first, then it rises (vault: Spawning.md)
  ZombieService:GetPendingCount()   warned spawns that haven't risen yet
  ZombieService:Damage(model, amount, attacker?) -> killed: boolean
  ZombieService:Kill(model, attacker?)
  ZombieService:Knockback(model, fromPosition, power, stunTime?)
  ZombieService:GetInRadius(position, radius) -> {{Model, State, Distance, Position}}
  ZombieService:GetZombieFromPart(part) -> Model?
  ZombieService:PickType(wave, nightmare?) -> typeId (weighted by MinWave/Weight; a Nightmare run picks only
    the Nightmare types, a normal run never does)
Nightmare extras (Config/Zombies): Split (the Husk's halves crawl out in Kill), Wail (_wail: a scream that
calls the horde; clients blur and play it in NightmareController).
  ZombieService:GetAliveCount(), ZombieService:ClearAll()
  ZombieService.Killed  Signal(state, attacker)
  ZombieService.BossEnraged  Signal(state)   boss crossed Def.Enrage.At (see _enrage)
```

## Uses

- [[CombatService]]
- [[EconomyService]]
- [[GameConfig]]
- [[GameState]]
- [[MapService]]
- [[MatchService]]
- [[NavGrid]]
- [[Remotes]]
- [[Util]]
- [[ZombieModels]]
- [[Zombies config]]

## Used by

- [[AbilityService]]
- [[AirdropService]]
- [[CombatService]]
- [[DebugService]]
- [[MatchService]]

## Design notes

- [[Zombies]]
- [[Spawning]]
