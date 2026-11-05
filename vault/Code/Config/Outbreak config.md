---
tags: [zone-config]
cssclasses: [zone-config]
---

# Outbreak config

> Made by `tools/vault-code-notes.js` from `src/shared/Config/Outbreak.luau` (14 lines). Don't edit it here: rerun the script.

Part of [[Config]].

## What it does

```text
Outbreak: the million-zombie mode. Pad 6 on the Flight Line (Map/ModePad) queues it; QueueService
takes its squad to THIS place (PlaceId below) in a fresh reserved server, where MatchService runs
the match tagged Mode = "Outbreak" (GameState.Mode). The mode's own rules (half-size swarms,
million-kill meter, overpowered guns) live here as the design lands.
```

## Uses

- (none)

## Used by

- [[QueueService]]
