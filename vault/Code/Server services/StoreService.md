# StoreService

> Made by `tools/vault-code-notes.js` from `src/server/Services/StoreService.luau` (105 lines). Don't edit it here: rerun the script.

Part of [[Server services]].

## What it does

```text
StoreService: Robux purchases (vault: Store.md; catalogue in Shared/Config/Store).
  Developer Products: MarketplaceService.ProcessReceipt -> :Grant. Each receipt pays exactly once: its
    PurchaseId goes into the profile's Receipts list with the reward, and Roblox is only told
    PurchaseGranted after that save succeeds. If the save fails we answer NotProcessedYet and Roblox retries;
    the retry finds the receipt already in the profile (same server) or the reward missing (after a crash)
    and does the right thing either way.
  Game Passes: checked on join and after a purchase; owned passes become player attributes Pass_<Id>
    (MatchService doubles run Gems with DoubleGems; DailyService and LobbyService read VIP).
```

## Uses

- [[DataService]]
- [[Remotes]]
- [[Store config]]

## Used by

- [[DebugService]]

## Design notes

- [[Store]]
