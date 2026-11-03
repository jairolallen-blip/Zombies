# Commons

> Made by `tools/vault-code-notes.js` from `src/server/Map/Commons.luau` (601 lines). Don't edit it here: rerun the script.

Part of [[Map builders]].

## What it does

```text
Commons: the safehouse's hangout area south of the courtyard (vault: Lobby.md). The old south gate
(it was blocked with barriers) is open again and leads to:
  centre  a campfire ring with log benches and two beat-up couches under string lights
  west    the mess tent: long tables, benches, a cooking barrel, crates of cans
  east    sleeping tents with cots
  corners a radio shack (south-east) with live chatter, and a hoop and crates to sit on (south-west)
  entry   the Commendations board (moved here from in front of the gate) and the TOP SURVIVORS board
Things to do (Server/Services/CommonsService): sit on any couch, log or mess bench (Seats); "Listen in"
at the radio for an Overwatch broadcast; "Shoot" the ball at the hoop; read the global best-wave board.
The south ruins move back to the new edge. Sounds: every fire (here and the courtyard's barrels) gets a
looped crackle and the radio shack plays chatter; they are Sounds named "LobbyAmbient" that
Client/Controllers/LobbyAudioController starts (ids in Shared/Config/Sounds).
OurLobby.Build calls this after FlightLine. Safe to re-run on a baked lobby: it replaces its own parts.
  local m = game.ServerScriptService.Server.Map.Commons
  local c = m:Clone(); c.Parent = m.Parent; require(c).Build(workspace.OurMap.Lobby); c:Destroy()
```

## Uses

- [[GameConfig]]
- [[Sounds config]]

## Used by

- [[OurLobby]]

## Mentions

- [[CommonsService]]
- [[LobbyAudioController]]

## Design notes

- [[Lobby]]
