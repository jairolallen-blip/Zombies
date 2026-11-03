# DebugService

> Made by `tools/vault-code-notes.js` from `src/server/Services/DebugService.luau` (203 lines). Don't edit it here: rerun the script.

Part of [[Server services]].

## What it does

```text
DebugService: STUDIO-ONLY test commands, exposed as ServerStorage.SAMZ_Debug (BindableFunction).
Lets a developer or an AI agent drive the game from the Command Bar / MCP execute_luau (Server):
  game.ServerStorage.SAMZ_Debug:Invoke("Help")
  game.ServerStorage.SAMZ_Debug:Invoke("Spawn", "GraveTitan", 1)
Not created in live servers. Add a command by adding a function to Commands.
```

## Uses

- [[AirdropService]]
- [[DataService]]
- [[EconomyService]]
- [[GameState]]
- [[MapService]]
- [[MatchService]]
- [[NavGrid]]
- [[StoreService]]
- [[ZombieService]]
- [[Zombies config]]

## Used by

- (none)
