---
tags: [zone-config]
cssclasses: [zone-config]
---

# Config (Zombies)

> Made by `tools/vault-code-notes.js`. Don't edit it here: rerun the script.

Pure data tables read by server and client. Tune numbers here.

Back to [[Zombies Home]].

- [[Achievements config (Zombies)]]: lifetime goals that pay Gems, claimed at the Commendations board in the lobby
- [[Airdrops config (Zombies)]]: mid-run supply crates (Server/Services/AirdropService, Client/Controllers/AirdropController).
- [[Bounties config (Zombies)]]: daily tasks on the BOUNTY BOARD by the Flight Line gate (vault: Bounties.md). PURE DATA + the
- [[Classes config (Zombies)]]: playable roles, unlocked with Gems and chosen in the lobby.
- [[Conditions config (Zombies)]]: the weather and time of day each run gets, picked at random (vault: City Map.md). PURE DATA.
- [[GameConfig (Zombies)]]: global tunables for match flow, waves, economy, upgrades, player, camera, map.
- [[Levels config (Zombies)]]: account XP and levels (owner design 2026-11-03; vault: Levels.md). PURE DATA + math.
- [[Nightmare config (Zombies)]]: the hard mode (vault: Nightmare Mode.md). PURE DATA plus the unlock check.
- [[Outbreak config (Zombies)]]: the million-zombie mode. Pad 6 on the Flight Line (Map/ModePad) queues it; QueueService
- [[Radio config (Zombies)]]: the commander's lines (vault: Match Start.md). PURE DATA.
- [[Sounds config (Zombies)]]: every sound in the game (pure data; played by Client/Controllers/SoundController).
- [[Store config (Zombies)]]: what the Robux shop sells (vault: Store.md). PURE DATA. Server/Services/StoreService grants it,
- [[Survivors config (Zombies)]]: the people living in the safehouse (vault: Lobby.md). PURE DATA.
- [[Tutorial config (Zombies)]]: the first-time player's training run (vault: Lobby.md). PURE DATA.
- [[Weapons config (Zombies)]]: every gun, grouped into 4 upgrade Levels (vault: Weapons.md, Lobby.md).
- [[Zombies config (Zombies)]]: every enemy type. PURE DATA. Server/ZombieModels builds the blocky model from Look
