---
tags: [zone-config]
cssclasses: [zone-config]
---

# Store config (Zombies)

> Made by `tools/vault-code-notes.js` from `src/shared/Config/Store.luau` (46 lines). Don't edit it here: rerun the script.

Part of [[Config (Zombies)|Config]].

## What it does

```text
Store: what the Robux shop sells (vault: Store.md). PURE DATA. Server/Services/StoreService grants it,
Client/Controllers/StoreController shows it (the SHOP button in the lobby, or the TRADER stall).

ProductId / PassId come from the Creator Dashboard (Monetization > Developer Products / Passes).
0 = not created yet: the card shows "SOON" and can't be bought. Prices are read from Roblox at runtime;
Price here is only the fallback shown before that (or while the id is 0).
Products (Developer Products, buy again any time): Gem packs.
Passes (Game Passes, owned forever, one per account): their effect is keyed by Id (StoreService.HasPass).
A pass with Gems / Classes is a bundle: StoreService pays those once per account, then sets the profile
flag named by Flag (the Starter Pack is a pass so Roblox itself stops a second purchase).
```

## Uses

- (none)

## Used by

- [[DebugService (Zombies)]]
- [[StoreController (Zombies)]]
- [[StoreService (Zombies)]]

## Design notes

- [[Store]]
