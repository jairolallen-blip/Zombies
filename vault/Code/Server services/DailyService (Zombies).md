---
tags: [zone-server]
cssclasses: [zone-server]
---

# DailyService (Zombies)

> Made by `tools/vault-code-notes.js` from `src/server/Services/DailyService.luau` (66 lines). Don't edit it here: rerun the script.

Part of [[Server services (Zombies)|Server services]].

## What it does

```text
DailyService: the DAILY RATIONS cache by the lobby flag (vault: Lobby.md; built by Server/Map/DailyCache).
Holding its "Claim" prompt (attribute Daily) once per UTC day pays Gems. Claiming on consecutive days
grows a streak up to 7 (REWARDS), which then starts over; missing a day resets it to day 1.
Profile fields DailyStreak and DailyDay (DataService).
```

## Uses

- [[DataService (Zombies)]]
- [[GameConfig (Zombies)]]
- [[MatchService (Zombies)]]
- [[Remotes (Zombies)]]

## Used by

- (none)

## Mentions

- [[DailyCache (Zombies)]]

## Design notes

- [[Lobby]]
