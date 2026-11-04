# SoundController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/SoundController.luau` (429 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
SoundController: all game audio, client-side (ids + volumes in Shared/Config/Sounds).
Nothing on the server changes: sounds hang off events the client already receives.
  your gun          WeaponController -> :PlayGunshot (2D), :SetSpin (minigun loop),
                    :PlayReload (mag out / mag in / bolt timed to the viewmodel reload), :PlayShell,
                    equip + aim cloth rustle (ViewmodelController / WeaponController)
  movement          footsteps for every character by distance walked (Roblox's default walking
                    sounds are disabled by the empty StarterPlayerScripts.RbxCharacterSounds),
                    your jump + landing
  others' guns      Remotes.Effect "Tracer" (WeaponId) -> 3D gunshot at the muzzle
  hits / kills      Remotes.HitConfirm -> hitmarker / kill tick
  zombies           ambient groans from nearby zombies, "ZombieDeath" death cries,
                    "ZombieHit" hurt grunt as one takes a bullet, "SpawnWarning" groan
                    as one rises, hurt swipe when your health drops
  explosions        "Explosion" boom, "Shockwave" ground slam (boss slam, Bruiser stomp)
  match             Remotes.Radio event names: radio squelch on every line, wave sting on
                    WaveStart/FirstWave, boss roar on BossIncoming/BossEnraged, Victory jingle,
                    low sting on Overrun
  loops             helicopter while Deploying, eerie ambience during the run
  UI                click on every GuiButton

Public: :Play(name, opts?) 2D, :PlayAt(name, position, opts?) 3D, :PlayGunshot(weaponId, pos),
        :SetSpin(0..1), :PlayUI(name), :PlayReload(seconds, viewmodel?), :PlayShell()
        :Loop(name) -> a looped Sound for the caller to drive (CutsceneController's deploy audio)
```

## Uses

- [[GameState]]
- [[Remotes]]
- [[Sounds config]]

## Used by

- [[BossController]]
- [[CutsceneController]]
- [[LobbyMenu]]
- [[ThrowController]]
- [[ViewmodelController]]
- [[WeaponController]]
- [[WelcomeController]]
