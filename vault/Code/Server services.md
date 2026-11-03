# Server services

> Made by `tools/vault-code-notes.js`. Don't edit it here: rerun the script.

Server game systems. Server Main loads them in order and calls Init, then Start.

Back to [[Home]].

- [[AbilityService]]: class Abilities [E] (cooldown) and Ultimates [F] (charge from kills).
- [[AirdropService]]: mid-run supply drops (tunables + rewards: Shared/Config/Airdrops).
- [[CombatService]]: weapons (server-validated hitscan), reloads, explosions, and damage to players.
- [[CommonsService]]: the things to do in the safehouse's Commons (vault: Lobby.md; built by Server/Map/Commons).
- [[DataService]]: persistent player profiles (Gems, unlocks, equipped class, gun loadout, best wave).
- [[DebugService]]: STUDIO-ONLY test commands, exposed as ServerStorage.SAMZ_Debug (BindableFunction).
- [[EconomyService]]: per-run Cash, kills, Ultimate charge and the in-run upgrades (Weapon tier, Vitality).
- [[LobbyService]]: lobby-only actions — equip class, put a gun in its Loadout slot (one per Level),
- [[MapService]]: answers "where do things spawn" for our map and applies its sunset atmosphere.
- [[MatchService]]: the game loop. Owns who is in the run, spawning characters, waves, and results.
- [[QueueService]]: the Flight Line pads of a lobby server (vault: Lobby.md, map: Server/Map/FlightLine).
- [[Server Main]]: Server entry point. Requires every ModuleScript in Services, then calls
- [[TutorialService]]: walks a first-time player through the game during their training run
- [[ZombieModels]]: blocky R6-style zombie bodies with per-zombie variation (vault: Zombies.md; style from
- [[ZombieService]]: spawns zombies (models from Server/ZombieModels), runs their AI every Heartbeat,
