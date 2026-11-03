# WelcomeController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/WelcomeController.luau` (533 lines). Don't edit it here: rerun the script.

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
Run report (2026-11-03): after every run the same screen comes back as a report once you're at the
safehouse: VICTORY / OVERRUN / TRAINING DONE and that run's wave, kills, Gems and waves cleared. The
results come from Remotes.RunResults when the run played on this server (Studio), or from the teleport
data a match server sends back (MatchService.LastResults via QueueService:ReturnToLobby).
Level header (Config/Levels) under the headline: LEVEL n, its rank title and the XP bar; the run report
adds the run's +XP, chips breaking it down, and fills the bar from before the run (results.XPBefore) to
now with LEVEL UP! and a pop at each level gained. The wave tile gets a gold NEW BEST tag.
```

## Uses

- [[Bounties config]]
- [[GameState]]
- [[Levels config]]
- [[Remotes]]
- [[Survivors config]]
- [[UIKit]]
- [[Util]]
- [[Zombies config]]

## Used by

- (none)
