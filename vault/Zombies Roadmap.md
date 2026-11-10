---
tags: [zone-working]
cssclasses: [zone-working]
game-zone: working
---

# Roadmap: our version

> **New agent or collaborator?** Start with `CLAUDE.md` in the repo root (outside this vault). It's the always-current handoff guide: game content, architecture, workflow, playtesting and pitfalls.

Back to [[Zombies Home|Home]]. Our take on *Survive a Million Zombies*, built next to the friend's version. Each phase has its own note, and we finish one before starting the next.

| # | Phase | Note | Status |
|---|---|---|---|
| 1 | Lobby and loadout | [[Lobby]] | **Done** (2026-11-01) |
| 2 | Main map: apocalyptic city | [[City Map]] | **Done** (2026-11-01) |
| 3 | Drop-in cutscene, intermission, commander notice | [[Match Start]] | **Done** (2026-11-01) |
| 4 | Gun functionality (4 levels) | [[Weapons]] | **Done** (2026-11-01) |
| 5 | Zombie models and AI | [[Zombies]] | **Done** (2026-11-01) |
| 6 | Zombie spawns (random, red warning circle) | [[Spawning]] | **Done** (2026-11-01) |
| 7 | Waves (10 rounds) and final boss | [[Waves and Boss]] | **Done** (2026-11-01) |

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

## Project history
- **2026-11-01:** during phase 4, the friend's script sync overwrote our edits in the shared Team Create place. We restored everything from GitHub. We looked at their additions (a stud-style city map, plus props: traffic lights, hydrants, signs, weeds) and **kept none of it**, because the studs style clashes with our hazy city and nothing in it was gameplay. Then we deleted their map, the original map generator and its `Props` and `Bricks` helpers. The place now holds only our lobby, our city and our code.

## Reference images
- `MAP REFERENCES/`: zombie city shots for phase 2.
- `MODEL REFERENCES/`: guns (pistol, SMG, shotgun, AR/AK, sniper, Uzi) and zombies for phases 4 and 5.

**Store page art** (2026-11-04): three icon concepts and a 1920x1080 thumbnail, all real in-game shots, are in `thumbnails/` (made with `tools/thumbnail-compose.ps1`). Final pick (owner): **last stand**, `icon-last-stand-final.png` and `thumbnail-last-stand-final.png`. Suggested title: **[🧟] Survive 1,000,000 Zombies**, swapping the emoji for an update tag on each update.

**Gameplay trailer** (2026-11-04): `tools/TrailerDirector.luau` (in Studio: `ReplicatedStorage.DevTools.TrailerDirector`) plays a 61s scripted trailer in Play for screen recording. Shots: foggy street, lone zombie, rising from the ground, dusk flyover, crossroads last stand, crane over the horde, Grave Titan, Bloom Mother, title card. Music: APM "Growing Tension (a 60)". Record it, crop to the 16:9 box, upload as a video thumbnail (Roblox wants real gameplay; title cards are fine).
