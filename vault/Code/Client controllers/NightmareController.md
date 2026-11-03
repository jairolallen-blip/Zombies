# NightmareController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/NightmareController.luau` (78 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
NightmareController: the client side of the Nightmare pad on the Flight Line (Map/FlightLine
buildNightmare; Config/Nightmare). For a player who has unlocked Nightmare (Stats.Victories in
AchievementsJson) the cage's chained gate opens locally: no collision, chains and panels hidden. The
character is client-owned, so walking through works; everyone else still hits the gate, and
QueueService refuses to board them anyway. The gate sign shows this player's progress or the pad's squad.
During a Nightmare run it also fades in a quiet music loop (Nightmare.Music), dropped while the boss
is up so its own music plays alone (BossController).
```

## Uses

- [[GameState]]
- [[Nightmare config]]

## Used by

- (none)
