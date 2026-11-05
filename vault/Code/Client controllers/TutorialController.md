---
tags: [zone-client]
cssclasses: [zone-client]
---

# TutorialController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/TutorialController.luau` (50 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
TutorialController: the objective card during a first-time player's training run (left side,
below the radio panel). Server/Services/TutorialService sets the player attributes it reads:
  TutorialObjective (text, "" = hidden), TutorialObjectiveDone (turns it green with a tick),
  TutorialStep / TutorialSteps (the "TRAINING 3 / 8" counter). Steps are in Shared/Config/Tutorial.
```

## Uses

- [[UIKit]]

## Used by

- (none)

## Mentions

- [[Tutorial config]]
- [[TutorialService]]
