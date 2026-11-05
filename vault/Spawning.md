---
tags: [zone-gameplay]
cssclasses: [zone-gameplay]
samz-zone: gameplay
---

# Spawning (phase 6): done

Built and playtested on 2026-11-01.
- **Wave 1:** zombies appear 50+ studs out and rise with the warning circle. The HUD counter includes warnings that haven't risen yet.
- **Wave 7:** 30 zombies arrived in 8s, in **groups of 3**, at **23–70 studs** from the player, spread around **all 8 directions**, behind the player included. All 43 rose and were handed back to physics. The wave ended correctly once everything was dead.
- **Code:** `MapService:GetZombieSpawnPosition()` picks the spot, `ZombieService:SpawnWarned()` handles the warning and rise, `MatchService:_playWave()` spawns in groups, and the client draws the `SpawnWarning` effect.

Part of the [[Roadmap]]. Zombies come from the [[Zombies]] phase, and the map is [[City Map]].

## Rules (from the ground rules)
- **Random, scattered spawns** around the area rather than one spot. They can come from **behind you**.
- **A red warning circle** appears under each spawn point just before the zombie appears, so a zombie never pops up without warning. If you're not watching, you still get flanked.
- **Spawn rates start minimal** and **ramp up every round** across 10 rounds. The boss is on round 10 (see [[Waves and Boss]]).

## How it works
- **Where:** a random spot **22–75 studs** from a random living player, in any direction, on an open street cell with a little clearance (from the zombie NavGrid), and never closer than 22 studs to *any* player. If nothing fits after 40 tries, it falls back to the city's fixed `ZombieSpawn` pads. The boss always uses a pad, since it needs room.
- **Warning:** a red circle pulses for **1.2s** (a ring closes in), then the zombie **claws its way out of the ground** over 0.9s: hunched forward at first, arms reaching up and clawing, straightening as it comes up, with churned dirt, broken rubble, dust and clods around the hole that settle away after a few seconds (2026-11-03; `GroundFxController`, the "Rise" pose in EffectsController).
- **Update after the balance pass:** the "gap between groups" column below is outdated. Each wave's spawns are now spread over a window of 16s + 1s × wave, with gaps of 0.3–1.4s, which gives about 2 zombies/s at wave 8 instead of 5.4. See [[Waves and Boss#Balance pass (2026-11-01)]].
- **Original ramp per wave (solo):**

| Wave | Zombies | Spawned together | Gap between groups |
|---|---|---|---|
| 1 | 8 | 1 | 1.4s |
| 3 | 20 | 2 | 1.16s |
| 5 | 32 | 2 | 0.92s |
| 7 | 44 | 3 | 0.68s |
| 10 | 62 | 4 | 0.32s |

There are +60% zombies per extra player, at most 70 alive at once, and zombie HP rises 10% per wave.
- Tunables live in `GameConfig.Waves`.

## Faster start (2026-11-02)
Wave 1 now has 14 zombies (was 8) and each wave adds 5 (was 6), so wave 10 has 59 (was 62). The first intermission is 8s (was 12). The $500 gun upgrade now lands around the end of wave 1. Not yet rechecked with the balance bot.

## Code
[[MapService]] picks the spot, [[ZombieService]] raises the zombie, and [[EffectsController]] draws the warning circle.

Back to [[Home]].
