# BossController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/BossController.luau` (562 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
BossController: the client side of the final boss (vault: Waves and Boss.md, Nightmare Mode.md).
  intro      Effect "BossIntro" (MatchService:_bossIntro): letterboxed camera shots while the boss
             claws out of the ground at the BossSpawn marker, a close-up roar with shake, FOV punch,
             red flash and title card, then a fade back to first person. CameraController stands down
             while the player has the BossIntro attribute. Intro.Style "Bloom" (the Nightmare boss) also
             turns the sky sick green and has it tear out of a giant pulsing pod.
  music      tense drums under the intro; the boss track fades in when the intro ends and fades out
             when the boss dies or the run ends (GameState BossName)
  attacks    roar on "BossCharge" / "BossLeap"; "BossKnock" shoves your character (you own its physics).
             Bloom Mother (ZombieService:_spores, :_bloomBurst): "SporeVolley" lobs glowing pods that burst
             into poison clouds; "BloomBurst" fills its red ring in from the middle with a countdown over
             its head and GET CLEAR on screen while you're inside; "BloomBlast" is the explosion.
  death      Effect "BossDeath" (MatchService:_bossDeath): circles the swelling body, which bursts into a
             column of spores at BurstAt while the green sky clears, then hands the camera back.
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
- [[Nightmare Mode]]
