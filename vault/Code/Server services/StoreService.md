# StoreService

> Made by `tools/vault-code-notes.js` from `src/server/Services/StoreService.luau` (166 lines). Don't edit it here: rerun the script.

Part of [[Server services]].

## What it does

```text
StoreService: Robux purchases (vault: Store.md; catalogue in Shared/Config/Store).
  Developer Products: MarketplaceService.ProcessReceipt -> :Grant. Each receipt pays exactly once: its
    PurchaseId goes into the profile's Receipts list with the reward, and Roblox is only told
    PurchaseGranted after that save succeeds. If the save fails we answer NotProcessedYet and Roblox retries;
    the retry finds the receipt already in the profile (same server) or the reward missing (after a crash)
    and does the right thing either way.
  Gifts: a Gem pack can be bought for another player in the server. The buyer picks them first
    (Remotes.SetGift), then buys as usual; the next receipt within GIFT_WINDOW pays the friend instead.
    The receipt's recipient is remembered, so a retry pays the same person; if they've left, the buyer.
  Game Passes: checked on join and after a purchase; owned passes become player attributes Pass_<Id>
    (MatchService doubles run Gems with DoubleGems; DailyService and LobbyService read VIP).
    A bundle pass (Gems / Classes in its entry, e.g. the Starter Pack) pays them ONCE per account: the
    profile flag named by its Flag is set and saved with the reward, so later joins only re-check it.
```

## Uses

- [[DataService]]
- [[Remotes]]
- [[Store config]]

## Used by

- [[DebugService]]

## Design notes

- [[Store]]
