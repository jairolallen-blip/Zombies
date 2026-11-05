---
tags: [zone-config]
cssclasses: [zone-config]
---

# Levels config

> Made by `tools/vault-code-notes.js` from `src/shared/Config/Levels.luau` (68 lines). Don't edit it here: rerun the script.

Part of [[Config]].

## What it does

```text
Levels: account XP and levels (owner design 2026-11-03; vault: Levels.md). PURE DATA + math.
Each run pays XP for how it went (MatchService:_endRun -> DataService:AddXP); the profile keeps the
running total (XP) and the level is worked out from it. The welcome screen's run report fills the level
bar from before the run to now, levelling up on the way (WelcomeController).
  Levels.RunXP(kills, wavesCleared, victory, nightmare)   XP one run pays
  Levels.FromXP(xp) -> level, xp into that level, xp that level needs
  Levels.Credit(stats)   starting XP for saves from before levels (from their Stats history)
  Levels.Rank(level)     the rank title for a level (Levels.Ranks)
```

## Uses

- (none)

## Used by

- [[DataService]]
- [[LobbyMenu]]
- [[MatchService]]
- [[WelcomeController]]

## Design notes

- [[Levels]]
