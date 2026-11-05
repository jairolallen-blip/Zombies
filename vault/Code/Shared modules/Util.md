---
tags: [zone-shared]
cssclasses: [zone-shared]
---

# Util

> Made by `tools/vault-code-notes.js` from `src/shared/Util.luau` (84 lines). Don't edit it here: rerun the script.

Part of [[Shared modules]].

## What it does

```text
Util: shared helpers with no game state (Signal, weapon/upgrade math, formatting).
Formulas here are used by BOTH server (authoritative) and client (UI), so they always agree.
```

## Uses

- [[GameConfig]]
- [[Weapons config]]

## Used by

- [[CombatService]]
- [[DataService]]
- [[EconomyService]]
- [[HUDController]]
- [[LobbyController]]
- [[LobbyMenu]]
- [[OurLobby]]
- [[ShopController]]
- [[StoreController]]
- [[ViewmodelController]]
- [[WeaponController]]
- [[WelcomeController]]
- [[ZombieService]]
