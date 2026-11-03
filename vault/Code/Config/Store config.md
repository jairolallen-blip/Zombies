# Store config

> Made by `tools/vault-code-notes.js` from `src/shared/Config/Store.luau` (44 lines). Don't edit it here: rerun the script.

Part of [[Config]].

## What it does

```text
Store: what the Robux shop sells (vault: Store.md). PURE DATA. Server/Services/StoreService grants it,
Client/Controllers/StoreController shows it (the SHOP button in the lobby, or the TRADER stall).

ProductId / PassId come from the Creator Dashboard (Monetization > Developer Products / Passes).
0 = not created yet: the card shows "SOON" and can't be bought. Prices are read from Roblox at runtime;
Price here is only the fallback shown before that (or while the id is 0).
Products (Developer Products, buy again any time): Gems, or a bundle (Gems + Classes, OneTime per account).
Passes (Game Passes, owned forever): their effect is keyed by Id (StoreService.HasPass).
```

## Uses

- (none)

## Used by

- [[StoreController]]
- [[StoreService]]

## Design notes

- [[Store]]
