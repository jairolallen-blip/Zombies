# Waves and Boss (phase 7): done

Built and playtested on 2026-11-01.
- **Final wave:** wave 10 started as "FINAL WAVE". The Titan rose at 18,000 HP behind a large warning circle, alongside a horde of 37 (60% of 62).
- **Boss fight:** with sustained level 4 minigun fire, the Titan **enraged at exactly 50%** (17s), 6 summoned Runners rose around it, and it **died at 35s**. The "enraged" and "Titan down" radio lines both fired.
- **Victory:** clearing the wave ended the run. The VICTORY screen showed "Survived all 10 waves" and +150 Gems (including the +100 bonus), the HUD read "Victory! Extraction inbound", and players returned to the lobby.
- **Bug fixed:** since phase 6 the "APPROACHES" banner never showed, because the boss rises after its warning circle. The banner now fires when the boss actually appears.
- **Not re-tested this phase:** the overrun (everyone dead) ending. Its code path only gained the victory flag.

Part of the [[Roadmap]]. The spawn ramp per wave is in [[Spawning]].

## The run
- **10 waves** (`GameConfig.Waves.TotalWaves`). The HUD shows **WAVE n / 10**.
- **Wave 10 is the boss wave:** the Grave Titan plus a smaller horde (60% of the normal wave-10 count), so the fight stays about the boss.
- **Clearing wave 10 wins the run:** a VICTORY results screen, a victory radio sign-off from Sgt. Voss, and **+100 bonus Gems** on top of the usual rewards.
- **Dying** is the same as before: OVERRUN, with rewards for the waves you cleared.

## The Grave Titan
- **Entrance:** a huge warning circle, then the Titan rises out of the ground. The radio warns that something big is coming, and a "THE GRAVE TITAN APPROACHES" banner shows with its health bar.
- **Health:** 18,000, plus 60% per extra player. That's roughly 45s solo with a level 3 gun and 20–30s with level 4, while the horde keeps coming.
- **Slam:** a telegraphed ground-pound with a red ring (already existed), every 6s.
- **Enrage at 50% HP:** a "THE TITAN IS ENRAGED" banner and radio line. It moves 40% faster, slams twice as often, and **summons 6 Runners** around itself, each with its own warning circle.
- **Death:** the radio confirms the kill. Clear the remaining zombies to win.

## Balance pass (2026-11-01)
The solo runs had no cheats. A test bot played like an average player: body shots only, aim error, backing away from the horde, grenades and ultimate, and saving for guns.

| Run | Change | Result |
|---|---|---|
| 1 | as built in phase 6–7 | overrun at **wave 8**: the spawn rate hit about 5.4 zombies/s, and HP went from 240 to 0 in 11s |
| 2 | each wave's spawns spread over a 16s + 1s × wave window | overrun at **wave 7**: steady HP attrition (100 → 72 → 56 → 26 → 5), because HP never regenerates |
| 3 | **plus a full heal on clearing a wave** | **reached the boss**, got the Titan down to 9% HP (1,683/18,000), then died. The user approved it as a good final-boss difficulty |

Final run 3 progression: level 2 in wave 2, level 3 in wave 5, level 4 at the start of wave 10. Waves take 12–36s (the boss wave 64s). Lowest HP by wave: 100, 100, 100, 93, 100, 93, 63, **5**, 24, then died to the boss. At most 22 zombies were alive at once.

Tunables: `GameConfig.Waves.SpawnSeconds` / `SpawnSecondsPerWave` (spawn window) and `GameConfig.Match.HealOnWaveClear`.

## Later ideas
- A helicopter extraction cutscene on victory, reusing the drop-in helicopter.
- Endless mode after wave 10 for high scores.
