# BossController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/BossController.luau` (180 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
BossController: the client side of the final boss (vault: Waves and Boss.md).
  intro      Effect "BossIntro" (MatchService:_bossIntro): letterboxed camera shots while the boss
             claws out of the ground at the BossSpawn marker, a close-up roar with shake, FOV punch,
             red flash and title card, then a fade back to first person. CameraController stands down
             while the player has the BossIntro attribute.
  music      tense drums under the intro; the boss track fades in when the intro ends and fades out
             when the boss dies or the run ends (GameState BossName)
  attacks    roar on "BossCharge" / "BossLeap"; "BossKnock" shoves your character (you own its physics)
```

## Uses

- [[EffectsController]]
- [[GameConfig]]
- [[GameState]]
- [[Remotes]]
- [[SoundController]]
- [[Sounds config]]
- [[UIKit]]
- [[Zombies config]]

## Used by

- (none)

## Design notes

- [[Waves and Boss]]
