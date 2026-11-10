---
tags: [zone-map]
cssclasses: [zone-map]
---

# ModePad (Zombies)

> Made by `tools/vault-code-notes.js` from `src/server/Map/ModePad.luau` (144 lines). Don't edit it here: rerun the script.

Part of [[Map builders (Zombies)|Map builders]].

## What it does

```text
ModePad: the OUTBREAK pad (the million-zombie mode's take-off spot) on the Flight Line deck.
Style: a ~0.5-scale copy of OurLobby.buildHelipad's construction (Pad/Ring/Inner cylinders, H bars,
8 red EdgeLights, a DeployGlow-style beam wall, a sign post). Amber instead of yellow so it reads
as a different mode; Nightmare is the red pad. Attributes PadId 6 + ModeId "Outbreak":
MapService auto-discovers any Helipad model with a PadId, so QueueService can wire the mode later.
Called from OurLobby.Build AFTER FlightLine.Build (placePads destroys lobby Helipad models with
PadId ~= 1). Visual only: no queue/mode logic here yet.
```

## Uses

- [[GameConfig (Zombies)]]

## Used by

- [[OurLobby (Zombies)]]
