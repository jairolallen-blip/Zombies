---
tags: [zone-client]
cssclasses: [zone-client]
---

# ReadyFx

> Made by `tools/vault-code-notes.js` from `src/client/UI/ReadyFx.luau` (99 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
ReadyFx: makes a ready Ability / Ultimate hard to miss without shouting (owner 2026-11-03: "I always forget
or don't notice"; then: no sound, no big text mid-screen, keep it on the slots, any text subtle).
HUDController calls ReadyFx.Update(slot, ready, opts) every frame for each slot
(slot = { Frame = <slot panel> }; opts = { Color, Key, Big = true for the ultimate }).
  becomes ready   the slot pops, a ring bursts off it, a small "READY · F" tag rises off its top edge
  while ready     a glow outline breathes around the slot and a light sweeps across it
  left unused     every REMIND seconds the pop, ring and tag come back as a reminder
```

## Uses

- (none)

## Used by

- [[HUDController]]
