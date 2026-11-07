---
tags: [zone-library]
cssclasses: [zone-library]
samz-zone: library
---

# AI Art Pipeline

How other people make Roblox models and game ideas with Claude, taken from the owner's saved clips. Clips are listed in [[Video References]]. The claims are the creators', and nothing here has been tried on this game yet.

## Making a creature with Claude Design

From "Claude design modeling tips", 8:05 long, read from both its screen and its speech.

1. In Claude, open Design, then choose the standalone Claude Design and pick **3D object**. The creator isn't sure whether this needs a Pro plan.
2. Find a reference image, or have an image AI make a mock one. Claude gets a much better idea of what you want.
3. Write a base prompt in plain parts: body shape, details, colour palette, face and pose, and what each part is inspired by.
4. Send it and wait. The creator's first model took long enough to play two games of something else.
5. Rate the model with stars and say what you like and don't like. The creator says this stops you spending usage on re-prompting small details.
6. Send one long second prompt listing every fix, with lots of strong, specific words. Attach an image, and **say exactly which part to take from it**. If you don't, it copies the whole picture.

**Handoff docs are the creator's first rule.** When Claude offers to save tokens by moving to a new chat, always accept. It starts the new chat with a full script of the old one. If it doesn't offer, ask for a handoff doc, then start the new chat with it. This also rescued them when a chat stopped making the model: the same request worked in a fresh chat with the doc.

**Don't try to do it in one prompt.** The land shark was rough after one prompt and far better after two: teeth fixed, gums hidden, bigger head. It still had a plain back fin and janky water, and they say you can keep refining for as long as you like.

Their handoff doc is worth copying as a shape. As read from the screen:

**Style rules** (from the doc on screen)
- Built entirely from three.js primitives: spheres, capsules, cones, tori, lathes and extrudes.
- Silhouette first, then dense repeated detail: hundreds of small scales, spikes, plates and studs.
- One themed concept per creature, shown everywhere on it.
- One or two glowing materials on a darker base, carrying the theme through veins, eyes and runes.
- Menace or charm comes from the face.

**Tech rules**
- Binary `.glb` from `THREE.GLTFExporter`, metres, y-up, centred on the origin.
- About 400 to 1,300 meshes and about 17k to 66k triangles, 1 to 7 MB.
- No textures: colour comes from material settings and vertex colours.
- 5 or 6 shared materials: base skin, armour or metal, main glow, hot accent, dark punctuation, an optional see-through layer.
- No animation in the file: no clips, skins or morphs. The creator says movement such as portals and idles is added in the game.

The numbers are read from a blurry frame, so treat them as close, not exact.

## Concept sheet first

"3d Modeling Tips for Claude Design" shows another route, captioned Gemini + Opus 5.5: make a four-view character sheet with an image model, give it to Claude for the 3D model, then bring it into Roblox. The clip ends with the model walking and attacking in a Roblox test place. It claims one prompt.

## Does this fit our game?

Worth a test, with limits:

- **Bosses fit best.** A boss is one model on screen. See [[Waves and Boss]].
- **Horde zombies don't fit as made.** 17k to 66k triangles times 70 zombies is far too heavy, and [[Outbreak]] already struggles with hundreds of parts-based zombies. A horde mesh needs a much lower budget.
- **Our zombies are animated through Motor6Ds** (`ZombieGaits`). A one-piece mesh with no rig can't use them. It would need splitting into limbs that match the rig, or a skinned mesh, which is new work.
- **Getting it in** needs a route. [[Team Create Workflow]] covers scripts only. Roblox's Open Cloud takes model uploads, and that key isn't set up yet.
- **Keep it our own.** New creatures come from our [[Lore]], not from the clips' designs. The creator's land shark starts from a well-known game character and changes details, which isn't a safe way to work here: start from our own idea.

A fair first test is one boss prop or one Shambler, measured for looks and frame rate.

## Finding a game idea: the dead game method

From "Game Ideas TIPS IMPORTANT!!", read from its captions:

> Thousands of video games got shut down, but some had really good ideas.

The steps:
1. Have Claude research discontinued multiplayer games that had passionate communities.
2. Find out what made them fun, why people stopped playing, and which mechanics players still miss.
3. Have Claude take those mechanics and reinvent them as original game concepts.

Forgotten games become a research library. Step 3 matters: the mechanic is the idea, and the names, art and characters are not ours to use.

Try this on our "why people stop" question too, such as what keeps a horde game fresh after the first win. See [[Roadmap]].

## A daily build log

"UI and loading screen ideas" and "Visual and UI Loadscreen References" are one creator's day-by-day log of a sword RPG made with Claude. Each day ends with a short clip and a plain list of changes. Their list shows them changing their mind freely, such as renaming the game and swapping rolling for sidestepping. Short logs like these can also serve as marketing.
