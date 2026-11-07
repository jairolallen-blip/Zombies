---
tags: [zone-library]
cssclasses: [zone-library]
samz-zone: library
---

# Game Feel Guide

What the owner's saved clips teach about making actions feel good, and what to do with it here. Clips are listed in [[Video References]]. See also [[Zombies]] and [[Waves and Boss]].

## The idea

A hit works when the game answers it on several channels at the same moment. The research tip in "ANIMATION TIPS IMPORTANT!!" says it in one line: study how Nintendo uses animation timing, sound effects and visual feedback to make simple actions satisfying, then improve the three most common actions in your game using that method.

Our three most common actions are **shooting a zombie, killing a zombie and taking a hit**. Polish those before anything rarer.

## The five steps

From "Hitting Animation Improvements". Each step goes on top of the last.

| Step | What to do | Note |
|---|---|---|
| 1. Flash | Turn the enemy white for a moment | Reads instantly, even in a crowd |
| 2. Sound | A sharp whack exactly on the impact frame | Late sound kills the hit |
| 3. Particles | Blast them out in the direction of the hit | Direction is what sells it |
| 4. Knockback | Push the enemy away and bounce the attacker back | Both sides react |
| 5. Shake and freeze | Tiny screen shake on impact, and freeze the game for a few frames | Small numbers. More is worse |

When the target runs out of health, pop it like a balloon: it bursts into chunks and sparks with a word like POP.

## Impact frames

An impact frame is one or two frames of pure graphic shape at the moment of contact. It works because the eye gets a shock, not an image.

**Timing from "impact frame animation"**, read at 15 frames a second:
- The punch lands in about 2 frames, with a smear of speed lines.
- One frame of a white spike burst on contact.
- The victim then holds still in the wall for about 1.1 seconds, with the camera drifting.
- One fully white frame marks the cut to the finisher.

The long hold is what makes it feel heavy. Fast, still, fast.

**Timing from "Explosion and magic VFX"**, read at 30 frames a second from 3.9s:
- About 0.3 seconds of flat colour frames, each lasting 1 or 2 frames: pale, white, black with yellow streaks, white, black, red, crimson.
- It then settles into slower orange swirls.

The flat frames never show the scene. They replace it. Keep them short and few.

**Safety:** full-screen flashes can hurt people with photosensitive epilepsy. Don't flash more than 3 times in a second, and don't use them on anything that repeats, such as gunfire. Use them for rare moments only.

## VFX recipes

- **Fire** ("Fire sword"): white-yellow core, orange edge, dark smoke behind. Three layers read as hot. One orange layer reads as paint.
- **One-colour screen** ("Magic Animation and vfx"): for a moment everything is one green with the character in pure black. It costs little and looks expensive. Good for an ultimate.
- **Ring burst** ("Magic Vfx References!"): sharp crystals thrown outward from a centre, a ground crack and one fast arc. The arc adds speed.
- **Far effect, calm caster** ("Magic Attack VFX"): the hero stands still while the big thing happens far away. Then a white flash, then ash drifting down. The quiet afterwards matters.
- **Telegraph** ("Attack Animations"): a red pool pulses twice on the ground as a fuse before the blast. Players read rhythm better than a timer.
- **2D smears** ("Running and animation VFX"): a drawn smear on a limb for one or two frames adds speed. The clip's own warning: the edges can go jagged after export.
- **Sound from real objects** ("Sword Attacks VFX"): it appears to record a tape measure snapping for its slash. A real recording beats a library sound for texture. Earshot can check the result.

## What this game already has

Checked in `EffectsController` and `HUDController`:
- a red flash on a hit (`FLASH_TIME` 0.12s), a flinch and damage numbers
- a hitmarker that turns red on a kill
- camera shake scaled by distance on explosions (`Shake`)
- keyframed attacks and boss moves (`ZombieGaits`)

## What to try here, best first

None of this is built yet. Each needs a real test, since guns fire many times a second.

1. **Kill pop.** Give a killing shot a white flash and chunks thrown along the bullet's direction, not only a red flash. This is our most common good moment.
2. **Hit direction.** Throw hit particles along the shot. Check first how `ZombieHit` places them now.
3. **Freeze on big kills only.** A short local freeze of that zombie and the camera, about 40 to 60 ms, for Brutes and bosses. Never freeze the server, and never on every shot.
4. **Boss impact frames.** One or two flat frames on the Titan's roar and slam landing, within the safety limit above. Follow with a held pose.
5. **Bloater fuse.** Two red pulses on the ground before it bursts, so players learn the rhythm.
6. **Ultimate colour screen.** A one-colour flash per class when F fires.
7. **Boss death.** Hold, white frame, then the blast, using the timing above.
8. **Wailer ? icon.** See [[Nightmare Mode]]: "Roblox AI references" shows a ? over an enemy that heard you, which tells the player what it knows.
9. **Build reveal.** The white ring sweep from "Building Animation References" suits unlocks and level-ups in the [[Lobby]].
