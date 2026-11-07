---
tags: [zone-progress]
cssclasses: [zone-progress]
game-zone: progress
---

# Achievements

Lifetime goals that pay Gems (added 2026-11-02). Back to [[Home]]. List in [[Achievements config]]; progress in [[DataService]]; screen in [[ShopController]].

- **Where:** the Commendations board, at the Commons entrance in the [[Lobby]] (moved there out of the south gateway). Its `Status` sign shows how many are ready to claim.
- **Counting:** `DataService:AddStat` counts progress and toasts each completion. It's called for kills (total and per zombie type), headshot kills, waves cleared, runs, best wave, wins (total and per class) and supply drops opened.
- **Claiming:** the `ClaimAchievement` remote ([[Remotes]]) pays once.
- **Saving:** progress is in profile `Stats`, claims are in `Claimed`, and the client sees both as `AchievementsJson`. Ids are saved in profiles: rename a Name freely, never an Id.
- **Next to it:** the TOP SURVIVORS global best-wave board ([[CommonsService]], OrderedDataStore `SAMZ_BestWave_v1`).
