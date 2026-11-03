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
- **Entrance cutscene (2026-11-02), 7s:** before the horde spawns, every player is frozen and the camera takes over (`MatchService:_bossIntro`, client `BossController`).
  - **Shots:** letterboxed, with tense drums ("Stalking the Prey"). It starts high over the square pushing down the south avenue, cuts low in front as the Titan claws out of the ground, then goes close up for the **roar**.
  - **The roar:** heavy shake, an FOV punch, a red flash, a shockwave ring, the radio line and the "THE GRAVE TITAN · FINAL WAVE" title card.
  - **Back to the fight:** a fade back to first person, and the boss track ("Vengeful Attack") fades in. It fades out when the Titan dies.
  - The HUD and radio are hidden during the shot.
  - **Framing (fixed 2026-11-02):** the roar close-up sits 24 studs back, so the whole Titan is in frame. The title card is over the bottom letterbox bar, not over the boss. On hand-back the camera is levelled from your head toward the boss; it used to come back pitched up about 21°.
- **Spawn:** at the `BossSpawn` marker, the open mouth of the south avenue at (1000, 46), facing the square. It used to spawn on a random zombie pad behind obstacles and get stuck.
- **Charge:** stops behind a red lane (9 wide, 70 long) for 1.1s, then runs it at 75 studs/s. 40 damage and a big knockback to anyone in it. Cooldown 9s, at 22–85 studs and only with a clear line to you.
- **Leap:** a red ring lands on a far-away player (32+ studs), then the Titan jumps onto it 1.1s later with a shockwave. 45 damage and knockback. Cooldown 13s.
- **Pacing:** at least 2.5s between special attacks. Enrage halves every cooldown. Knockback is applied by the hit player's own client (`BossKnock`), since players own their characters' physics.
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

## Bot run after the faster start (2026-11-02)
One solo run (Fog): every wave up to 9 cleared, then overrun on the boss wave with the Titan at 64% HP. The 2026-11-01 baseline got the boss to 9%. Late wave sizes barely changed, so this may be noise. Run the bot again before changing anything. See [[Spawning]].

Second run, with god mode from wave 4 so it shows damage instead of deaths: waves 1-9 matched the first run, and it killed the Titan in 49s but took 407 damage on the boss wave against a 240 max HP. A real player would die about halfway through. **The boss wave is the wall.** The 2026-11-01 baseline came before the boss got Charge and Leap, so it no longer applies. **Eased (2026-11-02):** boss-wave horde 0.6 -> 0.4, Slam 45 -> 35, Charge 40 -> 30, Leap 45 -> 35. A third bot run still died 20s into the boss wave (Titan at 60%), but the bot never steps out of the red lanes and rings, so it takes every special. A real player dodges them, so a human playtest decides whether more is needed. Further options were: a smaller boss-wave horde (`BossWaveHordeMult`, 0.6 now), less Charge/Leap damage, or less Titan health.

## Later ideas
- A helicopter extraction cutscene on victory, reusing the drop-in helicopter.
- Endless mode after wave 10 for high scores.

## Code
The run loop is in [[MatchService]] and the boss in [[ZombieService]]. Client: [[BossController]] and [[HUDController]].

Back to [[Home]].
