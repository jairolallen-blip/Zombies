---
tags: [zone-server]
cssclasses: [zone-server]
---

# AirdropService

> Made by `tools/vault-code-notes.js` from `src/server/Services/AirdropService.luau` (288 lines). Don't edit it here: rerun the script.

Part of [[Server services]].

## What it does

```text
AirdropService: mid-run supply drops (tunables + rewards: Shared/Config/Airdrops).
When a wave starts (GameState Phase = "Wave") it may schedule one crate. The crate falls under a
parachute onto a street away from the squad (MapService:GetZombieSpawnPosition), lands with red
smoke and a light pillar, and guards rise around it (they count toward the wave). Holding its
ProximityPrompt opens it: a random reward for every living squad member within ShareRadius.
Timed buffs live on player attributes Buff (reward Id) + BuffUntil (server time), which
Client/Controllers/AirdropController shows; CombatService asks :DamageMult(player).
Crates and buffs are cleared when the run ends.
```

## Uses

- [[Airdrops config]]
- [[Classes config]]
- [[CombatService]]
- [[DataService]]
- [[EconomyService]]
- [[GameConfig]]
- [[GameState]]
- [[MapService]]
- [[MatchService]]
- [[Remotes]]
- [[ZombieService]]

## Used by

- [[CombatService]]
- [[DebugService]]
- [[TutorialService]]

## Mentions

- [[AirdropController]]
