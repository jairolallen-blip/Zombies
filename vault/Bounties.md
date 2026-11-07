---
tags: [zone-progress]
cssclasses: [zone-progress]
game-zone: progress
---

# Bounties

Daily tasks on the BOUNTY BOARD, north-west of the plaza by the Flight Line gate (added 2026-11-02). Back to [[Home]]. Data in [[Bounties config]]; tracking in [[DataService]]; screen in [[ShopController]]; board built by [[FieldStations]].

- **Three a day, the same for everyone:** [[Bounties config]] picks them from a pool, seeded by the UTC day number, so every server and client agrees without storing the list.
- **Track one at a time.** Only the tracked bounty counts progress. Switching keeps each bounty's progress. Finishing one pays its Gems at once and frees the slot.
- **What counts:** anything [[DataService]] counts with AddStat (kills, kills by type, headshots, waves cleared, best wave, supply crates, wins). See [[Achievements]].
- **Pool:** kill 150 zombies; 40 Runners; 20 Bloaters; 15 Brutes; 60 headshots; clear 15 waves; reach wave 8; open 2 crates; win a run. Rewards 150 to 400 Gems.
- **Later:** show the tracked bounty in the run HUD; rerolls.
