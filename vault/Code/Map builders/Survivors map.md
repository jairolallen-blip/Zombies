# Survivors map

> Made by `tools/vault-code-notes.js` from `src/server/Map/Survivors.luau` (74 lines). Don't edit it here: rerun the script.

Part of [[Map builders]].

## What it does

```text
Survivors: places the safehouse's people (Shared/Config/Survivors) in the lobby as figures from
Shared/ClassFigures, each with a name tag and a "Talk" prompt (attribute Survivor = their Id;
Client/Controllers/SurvivorController shows what they say). Baked into Workspace.OurMap.Lobby.Survivors.
OurLobby.Build calls this last. Safe to re-run: it replaces the Survivors model.
  local m = game.ServerScriptService.Server.Map.Survivors
  local c = m:Clone(); c.Parent = m.Parent; require(c).Build(workspace.OurMap.Lobby); c:Destroy()
```

## Uses

- [[ClassFigures]]
- [[GameConfig]]
- [[Survivors config]]

## Used by

- [[OurLobby]]

## Mentions

- [[SurvivorController]]
