---
tags: [zone-map]
cssclasses: [zone-map]
---

# FlightLine (Zombies)

> Made by `tools/vault-code-notes.js` from `src/server/Map/FlightLine.luau` (319 lines). Don't edit it here: rerun the script.

Part of [[Map builders (Zombies)|Map builders]].

## What it does

```text
FlightLine: the lobby's take-off deck (vault: Lobby.md). It sits north of the safehouse courtyard,
through a gate where the middle north ruin stood: four helipads in a 2 x 2 grid, one squad each
(Server/Services/QueueService). Pads are copies of the courtyard's original Helipad model, so the
look (deploy glow, edge lights, sign) stays the same; each pad model has attribute PadId = 1..4.
In the middle, a caged red Nightmare pad (PadId 5) behind a chained gate (buildNightmare).
OurLobby.Build calls this last. Safe to re-run on a baked lobby: it replaces its own parts.
  local m = game.ServerScriptService.Server.Map.FlightLine
  local c = m:Clone(); c.Parent = m.Parent; require(c).Build(workspace.OurMap.Lobby); c:Destroy()
```

## Uses

- [[GameConfig (Zombies)]]

## Used by

- [[OurLobby (Zombies)]]

## Mentions

- [[Nightmare config (Zombies)]]
- [[NightmareController (Zombies)]]
- [[QueueService (Zombies)]]

## Design notes

- [[Lobby]]
