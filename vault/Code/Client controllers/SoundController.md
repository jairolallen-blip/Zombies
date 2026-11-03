# SoundController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/SoundController.luau` (283 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
SoundController: all game audio, client-side (ids + volumes in Shared/Config/Sounds).
Nothing on the server changes: sounds hang off events the client already receives.
  your gun          WeaponController -> :PlayGunshot (2D), :SetSpin (minigun loop), reload
  others' guns      Remotes.Effect "Tracer" (WeaponId) -> 3D gunshot at the muzzle
  hits / kills      Remotes.HitConfirm -> hitmarker / kill tick
  zombies           ambient groans from nearby zombies, "ZombieDeath" death cries,
                    "SpawnWarning" groan as one rises, hurt swipe when your health drops
  explosions        "Explosion" boom, "Shockwave" ground slam (boss slam, Bruiser stomp)
  match             Remotes.Radio event names: radio squelch on every line, wave sting on
                    WaveStart/FirstWave, boss roar on BossIncoming/BossEnraged, Victory jingle,
                    low sting on Overrun
  loops             helicopter while Deploying, eerie ambience during the run
  UI                click on every GuiButton

Public: :Play(name, opts?) 2D, :PlayAt(name, position, opts?) 3D, :PlayGunshot(weaponId, pos),
        :SetSpin(0..1), :PlayUI(name)
        :Loop(name) -> a looped Sound for the caller to drive (CutsceneController's deploy audio)
```

## Uses

- [[GameState]]
- [[Remotes]]
- [[Sounds config]]

## Used by

- [[BossController]]
- [[CutsceneController]]
- [[WeaponController]]
- [[WelcomeController]]
