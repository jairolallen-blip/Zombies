---
tags: [zone-map]
cssclasses: [zone-map]
---

# DailyCache

> Made by `tools/vault-code-notes.js` from `src/server/Map/DailyCache.luau` (110 lines). Don't edit it here: rerun the script.

Part of [[Map builders]].

## What it does

```text
DailyCache: the DAILY RATIONS supply cache on the south edge of the plaza, by the flag (vault: Lobby.md).
A pallet of crates under a sign; holding "Claim" on the top crate (attribute Daily = true) pays the day's
Gems (Server/Services/DailyService). OurLobby.Build calls this last. Safe to re-run: it replaces itself.
  local m = game.ServerScriptService.Server.Map.DailyCache
  local c = m:Clone(); c.Parent = m.Parent; require(c).Build(workspace.OurMap.Lobby); c:Destroy()
```

## Uses

- [[GameConfig]]

## Used by

- [[OurLobby]]

## Mentions

- [[DailyService]]

## Design notes

- [[Lobby]]
