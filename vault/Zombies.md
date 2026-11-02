# Zombies (phase 5): done

Built and playtested on 2026-11-01.
- **Models:** about 22–31 parts each, built by `Server/ZombieModels`, with variety confirmed in a lineup.
- **Surround:** with a 41-zombie horde, 30 closed in and spread across **all 8 directions** (2–5 per 45° sector) instead of piling up. Late spawns from the far side arrived, and none got stuck.
- **Known limit:** in a very dense crowd (40+ around a player who stands still), the odd zombie gets pushed up onto the others (1 of 41 in the test).
- **Not watched live:** the attack swipe and the runner lunge animations need a real fight on your screen.

Part of the [[Roadmap]]. Style comes from `MODEL REFERENCES/` (the zombie images): classic blocky R6 bodies, arms out in front, red eyes, an open mouth with teeth, wounds and exposed ribs, torn clothes, and lots of variety.

## Looks
Every zombie is built from parts with **random variation**: shirt and pants colours from its type's palette, where the wounds go, which sleeve or pant leg is torn, slight differences in height and head tilt.

| Type | Silhouette | Details |
|---|---|---|
| Shambler | ordinary civilian | torn shirt with exposed ribs, ragged hem, one bare shin |
| Runner | lean, hunched forward | tank top, bare arms, yellow eyes, fast gait |
| Bloater | huge belly | glowing green pustules, stretched shirt, swollen limbs |
| Brute | hulking, wide shoulders | torn vest, rebar spikes in the back, red eyes |
| Grave Titan (boss) | giant | bone shoulder plates, cyan glowing eyes and cracks |

## Behaviour (AI)
- **Speed variety:** each zombie moves at ±15% of its type's speed, so the horde doesn't march in lockstep.
- **Surround, don't stack:** within about 14 studs, each zombie heads for its own slot around the player instead of the exact centre, so the horde encircles you rather than piling into one ball.
- **Runner lunge:** within 12 studs, a runner bursts forward at double speed for a moment.
- **Hit flinch:** each hit slows the zombie briefly, so damage feels like it lands.
- **Attack swipe:** both arms visibly swing down when it hits you (the client reads `AttackAt`).

## Animation (client)
- The walk cycle scales with the zombie's actual speed. Runners pump their legs faster, and shamblers sway.
- Arms stay reaching forward with a lazy bob, the head lolls, and the attack swipe plays on top.

## Notes
- Headshots count on any part whose name starts with `Head` (face details included) and on `Eye`.
- Spawn rise-from-the-ground and the red warning circle belong to [[Spawning]] (phase 6). The boss's fight mechanics belong to [[Waves and Boss]] (phase 7).
