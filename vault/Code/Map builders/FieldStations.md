---
tags: [zone-map]
cssclasses: [zone-map]
---

# FieldStations

> Made by `tools/vault-code-notes.js` from `src/server/Map/FieldStations.luau` (199 lines). Don't edit it here: rerun the script.

Part of [[Map builders]].

## What it does

```text
FieldStations: three lobby stations around the plaza (vault: Lobby.md).
  north-east  FIELD RESEARCH: a tarp over a specimen table; its prompt (attribute Shop = "Index") opens
              the enemy index (Client ShopController "Index", rewards in Config/Zombies Index)
  north-west  BOUNTY BOARD: a cork board with today's notices; its prompt (Shop = "Bounties") opens the
              daily bounties (Config/Bounties)
  south-east  THE TRADER: a market stall under a striped awning; its prompt (attribute Store) opens the
              Robux shop (Client StoreController, Config/Store)
Debris chunks inside either footprint are removed. OurLobby.Build calls this last. Safe to re-run.
  local m = game.ServerScriptService.Server.Map.FieldStations
  local c = m:Clone(); c.Parent = m.Parent; require(c).Build(workspace.OurMap.Lobby); c:Destroy()
```

## Uses

- [[GameConfig]]

## Used by

- [[OurLobby]]

## Mentions

- [[Bounties config]]
- [[Store config]]
- [[Zombies config]]

## Design notes

- [[Lobby]]
