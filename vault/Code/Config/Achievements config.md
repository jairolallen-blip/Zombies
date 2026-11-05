---
tags: [zone-config]
cssclasses: [zone-config]
---

# Achievements config

> Made by `tools/vault-code-notes.js` from `src/shared/Config/Achievements.luau` (62 lines). Don't edit it here: rerun the script.

Part of [[Config]].

## What it does

```text
Achievements: lifetime goals that pay Gems, claimed at the Commendations board in the lobby
(vault: Lobby.md). Progress lives in the profile's Stats table (DataService:AddStat), claims in
Claimed; both reach the client as the AchievementsJson attribute.

Entry: { Id, Name, Desc, Stat, Goal, Gems }. Stat is a key of profile.Stats:
  Kills, Kills_<zombie type> (Shambler, Runner, Bloater, Brute, GraveTitan), Headshots (headshot
  kills), WavesCleared, BestWave (highest wave reached), Runs, Victories, Wins_<class id>,
  Airdrops (supply crates opened), or the computed "ClassWins" (classes with at least one win).
Ids are saved in profiles: rename the Name freely, never an Id.
```

## Uses

- (none)

## Used by

- [[DataService]]
- [[ShopController]]

## Design notes

- [[Lobby]]
