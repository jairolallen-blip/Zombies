# ShopController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/ShopController.luau` (469 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
ShopController: the lobby's two shops (vault: Lobby.md), opened by walking up to them and pressing
the ProximityPrompt (attribute Shop) that Server/Map/OurLobby puts in each:
  Armory   (west tent)   level tabs 1-4; one card per gun with a rotating 3D model, stat bars and
                         equip / unlock-with-Gems
  Classes  (barracks)    one card per class with a rotating figure (Shared/ClassFigures)
  Achievements (commendations board, south)  scrolling list of Config/Achievements with progress
                         bars and CLAIM buttons (Remotes.ClaimAchievement); the board's status sign
                         shows how many are ready to claim
Closes with the X button, by walking away, or when a run starts. Buttons fire the same remotes
LobbyService validates (SelectWeapon / SelectClass / UnlockItem).
```

## Uses

- [[Achievements config]]
- [[ClassFigures]]
- [[Classes config]]
- [[GameConfig]]
- [[GunModels]]
- [[Remotes]]
- [[UIKit]]
- [[Util]]
- [[Weapons config]]

## Used by

- (none)

## Mentions

- [[OurLobby]]

## Design notes

- [[Lobby]]
