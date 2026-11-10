---
tags: [zone-client]
cssclasses: [zone-client]
---

# SkipController (Zombies)

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/SkipController.luau` (100 lines). Don't edit it here: rerun the script.

Part of [[Client controllers (Zombies)|Client controllers]].

## What it does

```text
SkipController: "hold to skip" for the deploy ride and the boss intro (Server/Services/MatchService
:_skippableWait). Shown while GameState SkipOpen is set and you have CanSkip (you've finished a run
before). Hold Space, gamepad X, or press and hold the button (touch / mouse) to vote; the cutscene ends
once the whole squad has voted (GameState SkipVotes = "votes/players").
```

## Uses

- [[GameState (Zombies)]]
- [[Remotes (Zombies)]]
- [[UIKit (Zombies)]]

## Used by

- (none)

## Mentions

- [[MatchService (Zombies)]]
