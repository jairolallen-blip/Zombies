# ShopController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/ShopController.luau` (869 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
ShopController: the lobby's walk-up menus (vault: Lobby.md), opened by the ProximityPrompts (attribute
Shop) that Server/Map/OurLobby puts in each:
  Armory   (west tent)   level tabs 1-4; one card per gun with a rotating 3D model, stat bars and
                         equip / unlock-with-Gems
  Classes  (barracks)    one card per class with a rotating figure (Shared/ClassFigures)
  Achievements (commendations board, south)  scrolling list of Config/Achievements with progress
                         bars and CLAIM buttons (Remotes.ClaimAchievement); the board's status sign
                         shows how many are ready to claim
  Index    (field research)  one card per zombie type, locked until you've killed one
  Bounties (bounty board)    today's three bounties; track one
Look: the same language as the welcome screen (WelcomeController): a full-screen cinematic layer with
letterbox bars over a warm vignette, an orange kicker + huge GothamBlack title + green accent bar,
near-black tiles with a thin warm stroke and a coloured edge, small-caps GothamBold labels over big
GothamBlack values, and the green gradient primary button. Cards pop in, tiles lift on hover.
Closes with the X button, Backspace / gamepad B, by walking away, or when a run starts. Buttons fire
the same remotes LobbyService validates (SelectWeapon / SelectClass / UnlockItem / ...).
```

## Uses

- [[Achievements config]]
- [[Bounties config]]
- [[ClassFigures]]
- [[Classes config]]
- [[GameConfig]]
- [[GunModels]]
- [[Remotes]]
- [[StoreController]]
- [[UIKit]]
- [[Util]]
- [[Weapons config]]
- [[Zombies config]]

## Used by

- (none)

## Mentions

- [[OurLobby]]

## Design notes

- [[Lobby]]
