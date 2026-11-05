---
tags: [zone-config]
cssclasses: [zone-config]
---

# Nightmare config

> Made by `tools/vault-code-notes.js` from `src/shared/Config/Nightmare.luau` (34 lines). Don't edit it here: rerun the script.

Part of [[Config]].

## What it does

```text
Nightmare: the hard mode (vault: Nightmare Mode.md). PURE DATA plus the unlock check.
Queued on its own pad on the Flight Line (Map/FlightLine builds it behind a chained gate; the pad
model has attribute Nightmare = true). QueueService only boards players who have unlocked it, and
MatchService plays the run with these multipliers, the Nightmare weather (Config/Conditions) and the
commander's "Nightmare<event>" lines (Config/Radio). Gems are paid only for a win.
```

## Uses

- (none)

## Used by

- [[MatchService]]
- [[NightmareController]]
- [[QueueService]]

## Mentions

- [[Conditions config]]
- [[Radio config]]

## Design notes

- [[Nightmare Mode]]
