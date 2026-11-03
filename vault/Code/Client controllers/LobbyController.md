# LobbyController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/LobbyController.luau` (187 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
LobbyController: lobby screen (visible while InRun is false) and the end-of-run results card.
  top-left   compact chip: Gems, best wave, current class + loadout, and where the shops are
             (class and gun choices happen in the Armory / Barracks shops: ShopController)
  bottom     take-off status; on a Flight Line pad (player attribute PadId) it becomes the squad
             panel: squad count, countdown and the mission (squad size, difficulty, map), which
             only the pad's host can change (Remotes.SetPadOptions; QueueService)
  centre     results overlay after a run (Remotes.RunResults)
  full       "waiting for your squad" cover on a match server until the drop starts
```

## Uses

- [[Classes config]]
- [[GameConfig]]
- [[GameState]]
- [[Remotes]]
- [[UIKit]]
- [[Util]]
- [[Weapons config]]

## Used by

- (none)
