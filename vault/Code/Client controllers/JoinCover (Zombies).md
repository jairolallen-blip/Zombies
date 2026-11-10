---
tags: [zone-client]
cssclasses: [zone-client]
---

# JoinCover (Zombies)

> Made by `tools/vault-code-notes.js` from `src/first/JoinCover.client.luau` (60 lines). Don't edit it here: rerun the script.

Part of [[Client controllers (Zombies)|Client controllers]].

## What it does

```text
JoinCover: covers the screen from the first frame of a join, so nobody glimpses the world (their
character standing in the lobby) before the welcome screen is built. It is drawn in the welcome
screen's own dusk colours and letterbox, so the hand-off reads as one scene.
Client/Controllers/WelcomeController fades it out: once the welcome screen is up, or as soon as the
character exists when there's no welcome screen (new players, match servers). Gone after 25s regardless.
```

## Uses

- (none)

## Used by

- (none)

## Mentions

- [[WelcomeController (Zombies)]]
