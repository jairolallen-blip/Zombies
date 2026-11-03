# FieldStations

> Made by `tools/vault-code-notes.js` from `src/server/Map/FieldStations.luau` (156 lines). Don't edit it here: rerun the script.

Part of [[Map builders]].

## What it does

```text
FieldStations: two lobby stations between the plaza and the Flight Line gate (vault: Lobby.md).
  north-east  FIELD RESEARCH: a tarp over a specimen table; its prompt (attribute Shop = "Index") opens
              the enemy index (Client ShopController "Index", rewards in Config/Zombies Index)
  north-west  BOUNTY BOARD: a cork board with today's notices; its prompt (Shop = "Bounties") opens the
              daily bounties (Config/Bounties)
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
- [[Zombies config]]

## Design notes

- [[Lobby]]
