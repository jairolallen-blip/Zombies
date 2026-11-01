# Roadmap: our version

Our take on *Survive a Million Zombies*, built next to the friend's version. Each phase has its own note, and we finish one before starting the next.

| # | Phase | Note | Status |
|---|---|---|---|
| 1 | Lobby and loadout | [[Lobby]] | **Done** (2026-11-01) |
| 2 | Main map: apocalyptic city | [[City Map]] | **Done** (2026-11-01) |
| 3 | Drop-in cutscene, intermission, commander notice | [[Match Start]] | Not started |
| 4 | Gun functionality (4 levels) | [[Weapons]] | Not started |
| 5 | Zombie models and AI | [[Zombies]] | Not started |
| 6 | Zombie spawns (random, red warning circle) | [[Spawning]] | Not started |
| 7 | Waves (10 rounds) and final boss | [[Waves and Boss]] | Not started |

## Ground rules
- The game starts in a **queue lobby**. Players pick a **class** and a **loadout** with one gun per level.
- There are **4 gun levels**. Players upgrade during a run with cash from kills and end-of-round rewards, using a button on the side of the screen.
- **Difficulty scales with party size.** Our version lives in the **same place** as the friend's, with a version switch (see [[Lobby#Decisions (2026-11-01)]]).
- The map is an **apocalyptic city**: one big open **city square** for mowing down zombies, with side areas that always loop back to it. **It should never feel like a maze**, so the zombie AI can't get lost.
- **10 rounds** for now, with a **boss on round 10**.

## Existing code we build on
These come from the current Studio game and can be searched in Graphify.
- `LobbyService` / `LobbyController`: class and weapon pickers (unlocked with Gems), Ready button.
- `EconomyService`: cash per kill, team share, `Weapon` tier upgrade (multipliers in `GameConfig.WeaponTiers`).
- `MatchService`: lobby countdown → break/wave loop → results.
- `ZombieService`, `MapService` (procedural "Graveside Isle"), `CombatService`, `AbilityService`.

## Reference images
- `MAP REFERENCES/`: zombie city shots for phase 2.
- `MODEL REFERENCES/`: guns (pistol, SMG, shotgun, AR/AK, sniper, Uzi) and zombies for phases 4 and 5.
