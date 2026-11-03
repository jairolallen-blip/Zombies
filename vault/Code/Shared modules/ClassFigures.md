# ClassFigures

> Made by `tools/vault-code-notes.js` from `src/shared/ClassFigures.luau` (199 lines). Don't edit it here: rerun the script.

Part of [[Shared modules]].

## What it does

```text
ClassFigures: a blocky soldier figure per class (vault: Lobby.md). Used by the Barracks
mannequins (Server/Map/OurLobby) and the class shop previews (Client/Controllers/ShopController).
ClassFigures.Build(classId) -> Model (anchored, non-colliding; feet at y = 0, facing -Z,
PrimaryPart = Torso, centred 3 studs up). Every figure has a face, gloves, knee pads and a vest;
the sleeves are the class Color, and each class has its own pose, headgear and kit:
  Survivor  cap, bandolier, backpack, rifle held across the chest
  Scout     goggles on the forehead, scarf, binoculars, sniper slung on the back, mid-stride
  Medic     white cross helmet, armband, medkit in hand, cross backpack
  Engineer  hard hat with headlamp, hi-vis vest, tool belt, wrench
  Bruiser   heavy visored helmet, armour plates, riot shield, sledgehammer (wider build)
```

## Uses

- [[Classes config]]

## Used by

- [[OurLobby]]
- [[ShopController]]
- [[Survivors map]]

## Design notes

- [[Lobby]]
