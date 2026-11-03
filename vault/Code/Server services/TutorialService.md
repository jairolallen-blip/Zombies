# TutorialService

> Made by `tools/vault-code-notes.js` from `src/server/Services/TutorialService.luau` (143 lines). Don't edit it here: rerun the script.

Part of [[Server services]].

## What it does

```text
TutorialService: walks a first-time player through the game during their training run
(MatchService:RunMatch with Tutorial; steps and lines in Shared/Config/Tutorial).
Each step: Setup helper (if any), a radio line from Overwatch, and an objective the client shows
(Client/Controllers/TutorialController) until its Done check passes.

Writes player attributes TutorialObjective (text, "" = none), TutorialObjectiveDone (bool),
TutorialStep / TutorialSteps (numbers for the "2 / 8" counter).

Public:
  TutorialService:Run(player)   returns when the tutorial run is over (GameState Tutorial = false)
```

## Uses

- [[AirdropService]]
- [[DataService]]
- [[EconomyService]]
- [[GameConfig]]
- [[GameState]]
- [[Remotes]]
- [[Tutorial config]]

## Used by

- [[MatchService]]

## Mentions

- [[TutorialController]]
