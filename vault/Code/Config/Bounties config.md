# Bounties config

> Made by `tools/vault-code-notes.js` from `src/shared/Config/Bounties.luau` (51 lines). Don't edit it here: rerun the script.

Part of [[Config]].

## What it does

```text
Bounties: daily tasks on the BOUNTY BOARD by the Flight Line gate (vault: Bounties.md). PURE DATA + the
daily pick. Every UTC day the same three bounties come up for everyone (Bounties.ForDay). A player tracks
one at a time; only the tracked one counts progress (Server/Services/DataService, profile Bounty), and
finishing it pays its Gems straight away. Progress is kept per bounty, so switching doesn't lose it.

Entry: { Id, Name, Desc, Stat, Goal, Gems, Max? }. Stat is a key DataService:AddStat counts (see
Config/Achievements); Max = the stat reports a best value (BestWave), so progress is the highest seen.
Ids are saved in profiles: rename the Name freely, never an Id.
```

## Uses

- (none)

## Used by

- [[DataService]]
- [[ShopController]]

## Mentions

- [[Achievements config]]

## Design notes

- [[Bounties]]
