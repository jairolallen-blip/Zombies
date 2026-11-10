---
tags: [zone-config]
cssclasses: [zone-config]
---

# Survivors config (Zombies)

> Made by `tools/vault-code-notes.js` from `src/shared/Config/Survivors.luau` (100 lines). Don't edit it here: rerun the script.

Part of [[Config (Zombies)|Config]].

## What it does

```text
Survivors: the people living in the safehouse (vault: Lobby.md). PURE DATA.
Server/Map/Survivors places one figure per entry (Shared/ClassFigures, by Class) at Spot (lobby-relative
x, z) facing Face (x, z) with a name tag and a "Talk" prompt; Client/Controllers/SurvivorController
shows their Lines one at a time in a speech bubble, in order, starting from a random one.
Broadcasts are Overwatch's lore lines for the radio shack's "Listen in" (Server/Services/CommonsService).
Lore so far: the city is Port Harrow; the infection ("the Bloom") came up out of the ground under it;
Overwatch (Sgt. Voss) flies drops from a carrier offshore; the Grave Titans are what the Bloom grows
into given time. Keep new lines consistent with Config/Radio.
```

## Uses

- (none)

## Used by

- [[CommonsService (Zombies)]]
- [[SurvivorController (Zombies)]]
- [[Survivors map (Zombies)]]
- [[WelcomeController (Zombies)]]

## Mentions

- [[ClassFigures (Zombies)]]
- [[Radio config (Zombies)]]

## Design notes

- [[Lobby]]
