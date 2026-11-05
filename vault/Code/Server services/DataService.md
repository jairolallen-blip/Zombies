---
tags: [zone-server]
cssclasses: [zone-server]
---

# DataService

> Made by `tools/vault-code-notes.js` from `src/server/Services/DataService.luau` (515 lines). Don't edit it here: rerun the script.

Part of [[Server services]].

## What it does

```text
DataService: persistent player profiles (Gems, unlocks, equipped class, gun loadout, best wave).
Saved with DataStoreService. If DataStores are unavailable (Studio without API access) it
runs in memory-only mode and never overwrites real data.

Profile shape (DEFAULT_PROFILE). Add a field there and it is back-filled into old saves.
Replicated to the owning client as player attributes:
  Gems, BestWave, ClassId, OwnedJson ('{"Classes":{...},"Weapons":{...}}'),
  LoadoutJson ('["Pistol","SMG",...]' — one weapon id per Level),
  AchievementsJson ('{"Stats":{...},"Claimed":{...}}'; Config/Achievements)
Achievements: :AddStat(player, key, amount, isMax) counts progress (toast when one completes);
the ClaimAchievement remote pays its Gems once.
Best waves also go to an OrderedDataStore (BEST_STORE) for the Commons' TOP SURVIVORS board:
:GetTopBestWaves(n) -> {{UserId, Wave}} best first, or nil when DataStores are unavailable.
```

## Uses

- [[Achievements config]]
- [[Bounties config]]
- [[Classes config]]
- [[GameConfig]]
- [[Levels config]]
- [[Remotes]]
- [[Util]]
- [[Weapons config]]
- [[Zombies config]]

## Used by

- [[AirdropService]]
- [[CombatService]]
- [[CommonsService]]
- [[DailyService]]
- [[DebugService]]
- [[EconomyService]]
- [[LobbyService]]
- [[MatchService]]
- [[QueueService]]
- [[StoreService]]
- [[TutorialService]]
