---
tags: [zone-server]
cssclasses: [zone-server]
---

# Server services (Zombies)

> Made by `tools/vault-code-notes.js`. Don't edit it here: rerun the script.

Server game systems. Server Main loads them in order and calls Init, then Start.

Back to [[Zombies Home]].

- [[AbilityService (Zombies)]]: class Abilities [E] (cooldown) and Ultimates [F] (charge from kills).
- [[AirdropService (Zombies)]]: mid-run supply drops (tunables + rewards: Shared/Config/Airdrops).
- [[CombatService (Zombies)]]: weapons (server-validated hitscan), reloads, explosions, and damage to players.
- [[CommonsService (Zombies)]]: the things to do in the safehouse's Commons (vault: Lobby.md; built by Server/Map/Commons).
- [[DailyService (Zombies)]]: the DAILY RATIONS cache by the lobby flag (vault: Lobby.md; built by Server/Map/DailyCache).
- [[DataService (Zombies)]]: persistent player profiles (Gems, unlocks, equipped class, gun loadout, best wave).
- [[DebugService (Zombies)]]: STUDIO-ONLY test commands, exposed as ServerStorage.SAMZ_Debug (BindableFunction).
- [[EconomyService (Zombies)]]: per-run Cash, kills, Ultimate charge and the in-run upgrades (Weapon tier, Vitality).
- [[LobbyService (Zombies)]]: lobby-only actions — equip class, put a gun in its Loadout slot (one per Level),
- [[MapService (Zombies)]]: answers "where do things spawn" for our map and applies its sunset atmosphere.
- [[MatchService (Zombies)]]: the game loop. Owns who is in the run, spawning characters, waves, and results.
- [[QueueService (Zombies)]]: the Flight Line pads of a lobby server (vault: Lobby.md, map: Server/Map/FlightLine).
- [[Server Main (Zombies)]]: Server entry point. Requires every ModuleScript in Services, then calls
- [[StoreService (Zombies)]]: Robux purchases (vault: Store.md; catalogue in Shared/Config/Store).
- [[TutorialService (Zombies)]]: walks a first-time player through the game during their training run
- [[ZombieModels (Zombies)]]: blocky R6-style zombie bodies with per-zombie variation (vault: Zombies.md; style from
- [[ZombieService (Zombies)]]: spawns zombies (models from Server/ZombieModels), runs their AI every Heartbeat,
