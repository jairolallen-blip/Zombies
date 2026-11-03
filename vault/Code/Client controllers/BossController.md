# BossController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/BossController.luau` (794 lines). Don't edit it here: rerun the script.

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
             into poison clouds; "BloomBurst" (its ultimate) is a riser, rumble and quickening thumps while
             spores stream in and its red ring fills with a countdown and GET CLEAR; "BloomBlast" is the
             explosion (core flash, shockwaves, spore column and ring) and the spore field it leaves.
  death      Effect "BossDeath" (MatchService:_bossDeath): it staggers to its knees while bits of it burst
             off, then goes up in a huge spore explosion at BurstAt as the green sky clears.
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
