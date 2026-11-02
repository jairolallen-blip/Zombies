# Survive a Million Zombies

Source for the Roblox experience *Survive a Million Zombies* (placeId 110463048909417).

**New here? Read [`CLAUDE.md`](CLAUDE.md) first.** It's the always-current handoff guide: game content, architecture, workflow, playtesting and pitfalls. Studio ⇄ repo sync and the balance-test bot live in [`tools/`](tools).

## Layout

| Folder | Studio location |
|---|---|
| `src/server` | `ServerScriptService.Server` |
| `src/shared` | `ReplicatedStorage.Shared` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` |
| `src/character` | `StarterPlayer.StarterCharacterScripts` |

File suffixes follow Rojo: `.server.luau` = Script, `.client.luau` = LocalScript, `.luau` = ModuleScript.
`default.project.json` maps these folders back into Studio.

Only scripts live here. The map, UI style sheets and other instances stay in the place file.

## Notes

`vault/` is an Obsidian vault for design notes and references. Open it with **Open folder as vault**.
