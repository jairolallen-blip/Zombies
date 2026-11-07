---
tags: [zone-working]
cssclasses: [zone-working]
game-zone: working
---

# Polish Ideas

What the owner's saved clips suggest for this game. Nothing here is built yet. The general lessons are in the Game Kit's `Game Feel Guide`, `AI Art Pipeline` and `UI Ideas`. Back to [[Home]].

Our three most common actions are **shooting a zombie, killing a zombie and taking a hit**. Polish those before anything rarer.

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

## UI

- Reveals: the same beats suit a Gem pack, a class unlock or a supply crate reward. Dim, build up, burst, name it. [[Levels]] already has a LEVEL UP! moment to match.
- Shop: the black-shape locked entries suit FIELD RESEARCH, which already locks each zombie until you kill one. The ribbon suits Store deals. Our look is darker than this, so take the layout, not the colours.
- Diegetic UI: a survivor's field notebook could be FIELD RESEARCH, or the Overwatch radio could be a held handset. It suits the safehouse setting. More work than a flat panel, so only for one showpiece screen.
- Weapon wheel: a wheel suits a gamepad or phone, but we carry one gun at a time. It would fit a later emote or quick-chat menu better.
- Quiet menus: the place name idea fits entering the Commons or the Flight Line. Our lobby menu is busier by design, so this is a contrast to keep in mind, not a change to make.

## AI models here

Worth a test, with limits:

- **Bosses fit best.** A boss is one model on screen. See [[Waves and Boss]].
- **Horde zombies don't fit as made.** 17k to 66k triangles times 70 zombies is far too heavy, and [[Outbreak]] already struggles with hundreds of parts-based zombies. A horde mesh needs a much lower budget.
- **Our zombies are animated through Motor6Ds** (`ZombieGaits`). A one-piece mesh with no rig can't use them. It would need splitting into limbs that match the rig, or a skinned mesh, which is new work.
- **Getting it in** needs a route. [[Team Create Workflow]] covers scripts only. Roblox's Open Cloud takes model uploads, and that key isn't set up yet.
- **Keep it our own.** New creatures come from our [[Lore]], not from the clips' designs. The creator's land shark starts from a well-known game character and changes details, which isn't a safe way to work here: start from our own idea.

A fair first test is one boss prop or one Shambler, measured for looks and frame rate.
