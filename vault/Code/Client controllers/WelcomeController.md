# WelcomeController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/WelcomeController.luau` (415 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
WelcomeController: the "welcome back" screen a returning player sees when they reach a lobby server (once
per join, after the tutorial: profile Stats.Runs >= 1). Behind it, a ViewportFrame scene of a ruined Port
Harrow street at dusk: broken buildings with a few lit windows against a low sun, burning wrecks with
smoke and embers, your avatar idling on the left and a horde (ReplicatedStorage.ZombiePreviews, built by
ZombieService) running past right to left. ViewportFrames draw no particles or lights, so fire, smoke and
embers are neon / translucent parts animated each frame, and distance is faked by fading colours toward
the sky. On the right: your stats, the tracked bounty, and ENTER SAFEHOUSE (also Enter / gamepad A).
```

## Uses

- [[Bounties config]]
- [[GameState]]
- [[Survivors config]]
- [[UIKit]]
- [[Util]]
- [[Zombies config]]

## Used by

- (none)
