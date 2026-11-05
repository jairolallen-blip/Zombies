---
tags: [zone-world]
cssclasses: [zone-world]
samz-zone: world
---

# Tutorial

The first-time player's training run (added 2026-11-02). Back to [[Home]]. Part of [[Servers and Teleports]].

- **Who:** profiles with `TutorialDone = false`. Saves with any run already count as done. [[QueueService]] sends them into a solo match server on join (live only).
- **The run:** a normal run ([[MatchService]] `RunMatch` with `Tutorial`) cut to **5 waves**, ending in a **young Titan** at 25% health (see [[Waves and Boss]]). Random supply drops are off.
- **The steps** (data in [[Tutorial config]], run by [[TutorialService]], shown by [[TutorialController]]): each step is an Overwatch radio line plus an objective card that ticks green when done.
  1. shoot and reload
  2. upgrade the gun with 1 (cash topped up)
  3. Vitality with 2
  4. the class ability with E (see [[Classes and Abilities]])
  5. a guaranteed supply drop on wave 3, hold G (see [[Supply Drops]])
  6. the ultimate with F (bar filled on wave 4)
  7. the boss
  8. Gems and the shops
- **Reward:** a flat 350 Gems (enough for the Scout right away), win or lose. It isn't counted as a win, and it's marked done even on a loss.
- **Test in Studio:** `game.ServerStorage.SAMZ_Debug:Invoke("Tutorial")` ([[DebugService]]).
- **Still open:** point out the shops when a new player first reaches the lobby.
