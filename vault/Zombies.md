---
tags: [zone-gameplay]
cssclasses: [zone-gameplay]
game-zone: gameplay
---

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
- **Surround, don't stack:** within about 14 studs, each zombie heads for its own slot around the player instead of the exact centre, so the horde encircles you rather than piling into one ball. Since 2026-11-03 the slot is the least-taken of 8 sides, one zombie per side close in, the rest waiting in rings behind (at most 8 on you at once), and zombies push away from their neighbours and swing wide out of a clump.
- **Runner lunge:** within 12 studs, a runner bursts forward at double speed for a moment.
- **Hit flinch:** each hit slows the zombie briefly, so damage feels like it lands.
- **Attack swipe:** both arms visibly swing down when it hits you (the client reads `AttackAt`).

## Animation (client)
- Each build has its own keyframed gait in [[ZombieGaits]]: Normal shambles with a limp, Lean sprints, Bloated waddles, Hulk, Titan and bosses stomp, Gaunt stalks, Crawler crawls. A standing zombie breathes and its head sags.
- A gait advances with the zombie's real ground speed, so feet don't skate. Limp side, phase, size of motion and stride length vary by ZombieId, so a crowd doesn't march.
- Torso and Head are Motor6Ds on Root like the limbs, which is what lets a body lean and lurch. The motion is client only, so to the server a zombie is rigid and hit boxes don't move.
- Rise, Burrow and Scream fade in and out over about 0.2s, so the arms don't whip round in one frame when a pose ends.
- A hit leans a zombie away from the bullet, and a headshot snaps its head back. Hulks barely move. Each build has its own attack: claws, lunge, two-arm slam, belly bump, arm lash or bite.
- Bosses claw out hand over hand, roar with their arms wide, and rear up before a slam.
- To change a walk, edit the keys in [[ZombieGaits]]. The file's own self-check catches a cycle that jumps at the loop.
- Arms stay reaching forward with a lazy bob, the head lolls, and the attack swipe plays on top.

## Notes
- Headshots count on any part whose name starts with `Head` (face details included) and on `Eye`. Since 2026-11-03 the whole head counts: the invisible Root hitbox covers most of the face, so CombatService checks whether the bullet's line goes on through the head.
- Spawn rise-from-the-ground and the red warning circle belong to [[Spawning]] (phase 6). The boss's fight mechanics belong to [[Waves and Boss]] (phase 7).

## Code
Data in [[Zombies config]], bodies from [[ZombieModels]], AI in [[ZombieService]] with [[NavGrid]], walk animation in [[EffectsController]].

Back to [[Home]].
