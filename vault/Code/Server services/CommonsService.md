# CommonsService

> Made by `tools/vault-code-notes.js` from `src/server/Services/CommonsService.luau` (161 lines). Don't edit it here: rerun the script.

Part of [[Server services]].

## What it does

```text
CommonsService: the things to do in the safehouse's Commons (vault: Lobby.md; built by Server/Map/Commons).
  radio   "Listen in" at the radio shack: one of Overwatch's lore broadcasts (Config/Survivors) on your
          radio panel (Remotes.Radio, event "Broadcast"), at most one per player every few seconds
  hoop    "Shoot" the ball: it arcs from in front of you at the rim with an error that grows with
          distance; a make calls "SWISH!" for you and everyone near. The ball rolls home after.
  board   TOP SURVIVORS: the 10 best waves of all time (DataService:GetTopBestWaves), refreshed every
          couple of minutes. In Studio (no DataStores) it lists the players in this server instead.
```

## Uses

- [[DataService]]
- [[GameConfig]]
- [[Remotes]]
- [[Survivors config]]

## Used by

- (none)

## Mentions

- [[Commons]]

## Design notes

- [[Lobby]]
