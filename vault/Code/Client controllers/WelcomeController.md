# WelcomeController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/WelcomeController.luau` (198 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
WelcomeController: the "welcome back" screen a returning player sees when they reach a lobby server (once
per join, after the tutorial: profile Stats.Runs >= 1). Behind it, a ViewportFrame scene: your avatar
standing on the left playing its idle animation while a horde (ReplicatedStorage.ZombiePreviews, built by
ZombieService) runs past from right to left in the dusk. On the right: your stats and ENTER SAFEHOUSE.
```

## Uses

- [[GameState]]
- [[UIKit]]
- [[Util]]
- [[Zombies config]]

## Used by

- (none)
