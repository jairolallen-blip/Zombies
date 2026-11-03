# Sounds config

> Made by `tools/vault-code-notes.js` from `src/shared/Config/Sounds.luau` (109 lines). Don't edit it here: rerun the script.

Part of [[Config]].

## What it does

```text
Sounds: every sound in the game (pure data; played by Client/Controllers/SoundController).
All ids are public Creator Store audio that loads in this place (checked 2026-11-01). Most are from
the Roblox-licensed libraries "ProSoundEffects" (Pro Sound Effects) and "APMOfficial" (APM
Music); swap any id here to change a sound everywhere.

Library entry: { Id, Volume, Pitch = 1, PitchVar = 0 (random +/-), MaxDistance (3D roll-off), Looped }
```

## Uses

- (none)

## Used by

- [[BossController]]
- [[Commons]]
- [[CutsceneController]]
- [[LobbyAudioController]]
- [[SoundController]]

## Mentions

- [[Weapons config]]
