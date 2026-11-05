---
tags: [zone-server]
cssclasses: [zone-server]
---

# EconomyService

> Made by `tools/vault-code-notes.js` from `src/server/Services/EconomyService.luau` (156 lines). Don't edit it here: rerun the script.

Part of [[Server services]].

## What it does

```text
EconomyService: per-run Cash, kills, Ultimate charge and the in-run upgrades (Weapon tier, Vitality).
All run stats live on player attributes (server-authoritative, readable by the client HUD):
  Cash, Kills, WeaponTier (1..), VitalityLevel (0..), UltCharge (0..GameConfig.Ultimate.Max),
  AbilityReadyAt (workspace:GetServerTimeNow() timestamp; written by AbilityService)
Upgrade prices/effects: GameConfig.Upgrades + Util.GetUpgradeCost.
```

## Uses

- [[Classes config]]
- [[CombatService]]
- [[DataService]]
- [[GameConfig]]
- [[MatchService]]
- [[Remotes]]
- [[Util]]
- [[Weapons config]]

## Used by

- [[AirdropService]]
- [[DebugService]]
- [[MatchService]]
- [[TutorialService]]
- [[ZombieService]]
