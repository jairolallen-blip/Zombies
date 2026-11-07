---
tags: [zone-home]
cssclasses: [zone-home]
samz-zone: home
---

# Home

The map of the vault. Start here, then follow links.

> **New agent or collaborator?** Read `CLAUDE.md` in the repo root first. It's the always-current handoff guide.

## Colour key

<span class="samz-key zone-gameplay">Gameplay</span> <span class="samz-key zone-world">World and story</span> <span class="samz-key zone-progress">Progress and store</span> <span class="samz-key zone-working">How we work</span> <span class="samz-key zone-library">Reference library</span> <span class="samz-key zone-server">Server code</span> <span class="samz-key zone-client">Client code</span> <span class="samz-key zone-map">Map code</span> <span class="samz-key zone-shared">Shared code</span> <span class="samz-key zone-config">Config</span>

Notes, the sidebar and the graph all use these colours. To colour a new note, add it in `tools/vault-style.js`.

Open the vault as a 3D planet with the orbit icon on the left (CosmoGraph 3D). It uses its own colours, not this key.

## How the vault is laid out
- **Design notes** (this folder): what each system is meant to do, the decisions behind it and ideas for later. Written by hand and kept current.
- **Code notes** (`Code/`): one note per source file, made by `node tools/vault-code-notes.js`. Each has the file's header, what it uses, what uses it and the design notes it names. **Never hand-edit them:** rerun the script after code changes.
- **References** (`MAP REFERENCES`, `MODEL REFERENCES`, `UI REFERENCES`, `VISUAL REFERENCES`): images and clips for inspiration, not copying.

## The game, phase by phase
See [[Roadmap]] for status.
1. [[Lobby]]: the safehouse, shops, the Commons, the Flight Line
2. [[City Map]]: the arena city
3. [[Match Start]]: the helicopter drop-in and the commander radio
4. [[Weapons]]: 4 gun levels
5. [[Zombies]]: models and AI
6. [[Spawning]]: where and how zombies rise
7. [[Waves and Boss]]: the 10-wave run and the Grave Titan

## Systems added after the phases
- [[Servers and Teleports]]: lobby servers, squads, private match servers
- [[Tutorial]]: the first-time training run
- [[Classes and Abilities]]: the 5 classes, E abilities and F ultimates
- [[Supply Drops]]: mid-run crates and buffs
- [[Achievements]]: the Commendations board
- [[Bounties]]: daily tasks, one tracked at a time
- [[Store]]: the Robux shop and game passes
- [[Levels]]: account XP and levels, the level bar on the welcome screen
- [[Nightmare Mode]]: the hard mode (unlock at 3 wins, caged pad, pays only survivors)
- [[Outbreak]]: the million-zombie mode, its separate place, and how to change it
- [[Lore]]: Port Harrow, the Bloom, Overwatch and the safehouse people
- [[Phones and Gamepads]]: touch buttons and controller mapping

## Reference library
- [[Video References]]: the owner's saved clips, sorted by topic
- [[Game Feel Guide]]: hits, impact frames, VFX recipes and what to try here
- [[AI Art Pipeline]]: making models with Claude, and the dead game method
- [[UI Ideas]]: reveals, shops and menus

## Code
- [[Server services]]: the server's game systems
- [[Map builders]]: the baked lobby and city, and the zombie nav grid
- [[Client controllers]]: screens, camera, guns, sound
- [[Shared modules]]: GameState, Remotes, Util, model builders
- [[Config]]: pure data, where numbers get tuned

## Working on the game
- [[Team Create Workflow]]: how to edit the shared Studio place safely
- [[Apps To Keep Open]]: the apps Claude wants running, and how to ask for them
- [[Playing Million Zombies]]: controls, a normal run, how to survive, how to test this game
- [[Playing Roblox Games]]: how an AI agent plays and tests any Roblox game
