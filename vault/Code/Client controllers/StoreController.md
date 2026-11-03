# StoreController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/StoreController.luau` (303 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
StoreController: the Robux shop (vault: Store.md; catalogue in Shared/Config/Store, purchases granted by
Server/Services/StoreService). Opened by the lobby's SHOP button (left, under the info chip) or the
TRADER stall's prompt (attribute Store, built by Server/Map/FieldStations). Tabs:
  FEATURED  the Starter Pack and the featured pass as big cards
  GEMS      the Gem packs
  PASSES    the game passes
Buy buttons call Roblox's purchase prompts; prices come from Roblox (GetProductInfo), with Config/Store's
Price as the fallback. An id of 0 (not created on the dashboard yet) shows SOON.
```

## Uses

- [[Store config]]
- [[UIKit]]
- [[Util]]

## Used by

- (none)

## Mentions

- [[FieldStations]]
- [[StoreService]]

## Design notes

- [[Store]]
