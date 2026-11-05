---
tags: [zone-client]
cssclasses: [zone-client]
---

# NightmareController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/NightmareController.luau` (261 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
NightmareController: the client side of the Nightmare pad on the Flight Line (Map/FlightLine
buildNightmare; Config/Nightmare). For a player who has unlocked Nightmare (Stats.Victories in
AchievementsJson) the cage's chained gate opens locally: no collision, chains and panels hidden. The
character is client-owned, so walking through works; everyone else still hits the gate, and
QueueService refuses to board them anyway. The gate sign shows this player's progress or the pad's squad.
During a Nightmare run it also fades in a quiet music loop (Nightmare.Music), dropped while the boss
is up so its own music plays alone (BossController), a heartbeat that rises as zombies close in
(Nightmare.Heartbeat), and the city's street lamps go out or flicker (Nightmare.Lamps; local only, picked
by lamp position so every player sees the same ones; restored when the run ends).
The Wailer's scream (ZombieService:_wail): "WailStart" plays the scream from it and swells its throat sac,
"Wail" rolls out a shockwave ring, and players within its Radius get blurred sight, ringing ears and are
rooted for Stun seconds.
```

## Uses

- [[GameState]]
- [[Nightmare config]]
- [[Remotes]]

## Used by

- (none)
