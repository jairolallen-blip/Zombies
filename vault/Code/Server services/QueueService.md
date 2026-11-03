# QueueService

> Made by `tools/vault-code-notes.js` from `src/server/Services/QueueService.luau` (304 lines). Don't edit it here: rerun the script.

Part of [[Server services]].

## What it does

```text
QueueService: the Flight Line pads of a lobby server (vault: Lobby.md, map: Server/Map/FlightLine).
Each pad is its own queue:
  * the first player to step onto an empty pad is its HOST and picks the mission with
    Remotes.SetPadOptions (squad size, map; choices in GameConfig.Lobby). If the host
    steps off, the next in line takes over. An empty pad goes back to the defaults.
  * others can step on until the squad is full; anyone after that is told the pad is full
  * the countdown (GameConfig.Lobby) runs while anyone is on the pad and snaps short when it's full
  * the pad sets the difficulty: the Nightmare pad (model attribute Nightmare, behind its gate) only
    boards players who have unlocked it (Config/Nightmare) and is left out of QUICK PLAY
  * at 0 that squad takes off. Live: teleported together into a new reserved server of this place
    (MatchService runs the match there). Studio has no teleports, so the run plays in this server
    instead, one at a time (the other pads wait).
First-time players (profile TutorialDone = false) are teleported straight into a solo tutorial run
instead of staying in the lobby (live only; in Studio use SAMZ_Debug "Tutorial").
Also owns the trip back: MatchService calls :ReturnToLobby when a match server's run is over.

The client reads pad state from GameState "Pad<id>" = JSON {Host, Count, Size, Difficulty, Map,
Timer, Status = "Open" | "Boarding" | "Launching" | "Waiting"} and player attribute PadId (0 = none).
```

## Uses

- [[DataService]]
- [[GameConfig]]
- [[GameState]]
- [[MapService]]
- [[MatchService]]
- [[Nightmare config]]
- [[Remotes]]

## Used by

- [[MatchService]]

## Mentions

- [[FlightLine]]

## Design notes

- [[Lobby]]
