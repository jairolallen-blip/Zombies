---
tags: [zone-client]
cssclasses: [zone-client]
---

# StoreController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/StoreController.luau` (655 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
StoreController: the Robux shop (vault: Store.md; catalogue in Shared/Config/Store, purchases granted by
Server/Services/StoreService). Opened by the lobby's SHOP button (left, under the info chip) or the
TRADER stall's prompt (attribute Store, built by Server/Map/FieldStations). Tabs (keys 1-3):
  FEATURED  the Starter Pack bundle and the featured pass as big cards
  GEMS      the Gem packs
  PASSES    the game passes (not the bundle: it's on FEATURED)
Buy buttons call Roblox's purchase prompts; prices and icons come from Roblox (GetProductInfo), with
Config/Store's Price as the fallback. An id of 0 (not created on the dashboard yet) shows SOON.
Gem packs also have a gift button: pick a player in this server (Remotes.SetGift), then buy; StoreService
pays them instead of you.
Look: the same language as the lobby shops (ShopController) and the welcome screen: a full-screen layer
with letterbox bars over a warm vignette, kicker + huge title + green accent bar, near-black tiles with a
thin warm stroke and coloured edges, the green gradient buy button, a red X. Quint easing, a fading veil
(so the product icons fade too), staggered cards, a fade-out on close. Other ScreenGuis hide while open.
```

## Uses

- [[Remotes]]
- [[Store config]]
- [[UIKit]]
- [[Util]]

## Used by

- [[ShopController]]

## Mentions

- [[FieldStations]]
- [[StoreService]]

## Design notes

- [[Store]]
