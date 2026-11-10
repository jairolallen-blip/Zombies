---
tags: [zone-config]
cssclasses: [zone-config]
---

# Sounds config (Zombies)

> Made by `tools/vault-code-notes.js` from `src/shared/Config/Sounds.luau` (138 lines). Don't edit it here: rerun the script.

Part of [[Config (Zombies)|Config]].

## What it does

```text
Sounds: every sound in the game (pure data; played by Client/Controllers/SoundController).
All ids are public Creator Store audio that loads in this place (checked 2026-11-01 with
ContentProvider:PreloadAsync). Guns, reload parts, footsteps, impacts, grenade and explosion are
from the Roblox-licensed "ProSoundEffects" library (Pro Sound Effects); stingers from "APMOfficial".
Swap any id here to change a sound everywhere. Roblox's default walking/jumping sounds are
switched off (StarterPlayerScripts.RbxCharacterSounds is an empty override); footsteps below.

Library entry: { Id, Volume, Pitch = 1, PitchVar = 0 (random +/-), MaxDistance (3D roll-off), Looped }
```

## Uses

- (none)

## Used by

- [[BossController (Zombies)]]
- [[Commons (Zombies)]]
- [[CutsceneController (Zombies)]]
- [[LobbyAudioController (Zombies)]]
- [[SoundController (Zombies)]]

## Mentions

- [[Weapons config (Zombies)]]
