---
tags: [zone-client]
cssclasses: [zone-client]
---

# LobbyAudioController (Zombies)

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/LobbyAudioController.luau` (97 lines). Don't edit it here: rerun the script.

Part of [[Client controllers (Zombies)|Client controllers]].

## What it does

```text
LobbyAudioController: the safehouse's sound (ids and volumes in Shared/Config/Sounds).
  music     Sounds.LobbyPlaylist in order, quiet, with a pause between tracks; fades in while you're in
            the lobby (InRun false, not a match server's waiting screen) and out when a run starts
  ambience  a soft sea wash and a faint eerie bed under it, same fade
  3D loops  Sounds named "LobbyAmbient" in the lobby map (fire crackle, radio chatter; placed by
            Server/Map/Commons) are started as they stream in; their roll-off keeps them local
```

## Uses

- [[GameConfig (Zombies)]]
- [[GameState (Zombies)]]
- [[Sounds config (Zombies)]]

## Used by

- (none)

## Mentions

- [[Commons (Zombies)]]
