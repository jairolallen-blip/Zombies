---
tags: [zone-config]
cssclasses: [zone-config]
---

# Tutorial config (Zombies)

> Made by `tools/vault-code-notes.js` from `src/shared/Config/Tutorial.luau` (78 lines). Don't edit it here: rerun the script.

Part of [[Config (Zombies)|Config]].

## What it does

```text
Tutorial: the first-time player's training run (vault: Lobby.md). PURE DATA.
New players (profile TutorialDone = false) are sent straight into it instead of the lobby
(QueueService). It's a normal run with fewer waves and a weaker boss, and Overwatch walks them
through one mechanic at a time (Server/Services/TutorialService):
  each step shows an objective card (Client/Controllers/TutorialController) and says its radio line
  when the run reaches its Start (wave number + phase "Break" or "Wave"; phase "Results" = the end,
  any wave).
  Steps run in order: a step whose Start comes when the one before isn't done yet waits for it,
  unless its Start is a later wave or phase, then the unfinished one is dropped.
  Delay (optional) holds the radio line and objective that many seconds.
  Done names a check in TutorialService ("WaveCleared", "Upgraded", "Vitality", "Ability",
  "Airdrop", "Ultimate", "RunOver"); Setup names a helper that runs when the step starts
  ("CashForUpgrade", "CashForVitality", "DropCrate", "FillUltimate").
```

## Uses

- (none)

## Used by

- [[MatchService (Zombies)]]
- [[TutorialService (Zombies)]]

## Mentions

- [[TutorialController (Zombies)]]

## Design notes

- [[Lobby]]
