# OurLobby

> Made by `tools/vault-code-notes.js` from `src/server/Map/OurLobby.luau` (638 lines). Don't edit it here: rerun the script.

Part of [[Map builders]].

## What it does

```text
OurLobby: builds our version's lobby, a fortified safehouse in a ruined city (vault: Lobby.md).
It is BAKED into Workspace.OurMap.Lobby in Edit mode so it can be hand-edited afterwards:
  local m = game.ServerScriptService.Server.Map.OurLobby
  local c = m:Clone(); c.Parent = m.Parent; require(c).Build(); c:Destroy()

Layout (north = -Z):
  north   ruined building facades; a gate through them leads to the Flight Line (4 helipads, Map/FlightLine)
  centre  concrete plaza with a flagpole and burning barrels; LobbySpawn pads ring it
  west    armory tent (gun shop)       east  barracks: class mannequins behind sandbags
  both shops have a ProximityPrompt (attribute Shop = "Armory" | "Classes") that opens
  their UI on the client (Client/Controllers/ShopController)
  sides   stacked shipping containers   south jersey barriers + chain-link fence
  south   commendations board (achievements; prompt Shop = "Achievements"), facing the plaza
Parts named "LobbySpawn" are read by MapService:GetLobbySpawnCFrame().
```

## Uses

- [[ClassFigures]]
- [[Classes config]]
- [[Commons]]
- [[FlightLine]]
- [[GameConfig]]
- [[Survivors map]]

## Used by

- (none)

## Mentions

- [[ShopController]]
- [[Survivors config]]

## Design notes

- [[Lobby]]
