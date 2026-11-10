---
tags: [zone-server]
cssclasses: [zone-server]
---

# DebugService (Zombies)

> Made by `tools/vault-code-notes.js` from `src/server/Services/DebugService.luau` (217 lines). Don't edit it here: rerun the script.

Part of [[Server services (Zombies)|Server services]].

## What it does

```text
DebugService: STUDIO-ONLY test commands, exposed as ServerStorage.SAMZ_Debug (BindableFunction).
Lets a developer or an AI agent drive the game from the Command Bar / MCP execute_luau (Server):
  game.ServerStorage.SAMZ_Debug:Invoke("Help")
  game.ServerStorage.SAMZ_Debug:Invoke("Spawn", "GraveTitan", 1)
Not created in live servers. Add a command by adding a function to Commands.
```

## Uses

- [[AirdropService (Zombies)]]
- [[DataService (Zombies)]]
- [[EconomyService (Zombies)]]
- [[GameState (Zombies)]]
- [[MapService (Zombies)]]
- [[MatchService (Zombies)]]
- [[NavGrid (Zombies)]]
- [[Store config (Zombies)]]
- [[StoreService (Zombies)]]
- [[ZombieService (Zombies)]]
- [[Zombies config (Zombies)]]

## Used by

- (none)
