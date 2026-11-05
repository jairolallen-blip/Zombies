---
tags: [zone-client]
cssclasses: [zone-client]
---

# LobbyMenu

> Made by `tools/vault-code-notes.js` from `src/client/UI/LobbyMenu.luau` (277 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
LobbyMenu: the lobby's main screen (owner 2026-11-03: "bare and boring, and it's the first impression").
Built by LobbyController:Init into its root; LobbyController keeps the squad panel, results and waiting cover.
  top centre   the game's wordmark
  top left     profile card: level badge, name, rank, XP bar, Gems (+ opens the Gem packs), best wave,
               class, and the four loadout guns as chips in their Level colours
  right        menu tiles: SHOP, WEAPONS, CLASSES, BOUNTIES, INVITE (shops open in place, no walk needed)
  bottom       the deploy hint strip over a wide pulsing QUICK PLAY
menu:Refresh() re-reads the player's attributes; menu:Enter() slides everything in (each time the lobby shows).
```

## Uses

- [[Classes config]]
- [[GameConfig]]
- [[Levels config]]
- [[Remotes]]
- [[SoundController]]
- [[UIKit]]
- [[Util]]
- [[Weapons config]]

## Used by

- [[LobbyController]]
