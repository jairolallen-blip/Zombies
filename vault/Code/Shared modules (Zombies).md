---
tags: [zone-shared]
cssclasses: [zone-shared]
---

# Shared modules (Zombies)

> Made by `tools/vault-code-notes.js`. Don't edit it here: rerun the script.

Modules both sides require: state, remotes, helpers, model builders.

Back to [[Zombies Home]].

- [[ClassFigures (Zombies)]]: a blocky soldier figure per class (vault: Lobby.md). Used by the Barracks
- [[GameState (Zombies)]]: the one replicated Configuration instance holding match-wide state as attributes.
- [[GunModels (Zombies)]]: blocky low-poly gun models built from parts, one per weapon id (vault: Weapons.md;
- [[Health script (Zombies)]]: Intentionally empty. A Script named "Health" in StarterCharacterScripts replaces Roblox's
- [[Remotes (Zombies)]]: every RemoteEvent in the game, by name. Server creates them; clients wait for them.
- [[Util (Zombies)]]: shared helpers with no game state (Signal, weapon/upgrade math, formatting).
- [[ZombieGaits (Zombies)]]: keyframed walk cycles for the zombies (vault: Zombies.md). Pure data + sampling, no instances.
