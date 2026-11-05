---
tags: [zone-client]
cssclasses: [zone-client]
---

# ConditionsController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/ConditionsController.luau` (93 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
ConditionsController: the client side of a run's weather (Shared/Config/Conditions, GameState Condition).
  Rain         streaks falling around the camera (a non-colliding emitter part that follows it)
  Flashlights  a spotlight on every player's head, client-only, so nothing replicates
Everything clears when the Condition attribute does (MatchService resets it after a run).
```

## Uses

- [[Conditions config]]
- [[GameState]]

## Used by

- (none)
