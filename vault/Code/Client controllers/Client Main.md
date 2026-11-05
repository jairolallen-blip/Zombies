---
tags: [zone-client]
cssclasses: [zone-client]
---

# Client Main

> Made by `tools/vault-code-notes.js` from `src/client/Main.client.luau` (24 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
Client entry point. Requires every ModuleScript in Controllers, then calls
  controller:Init(Controllers)  on all  -- build UI, connect events
  controller:Start()            on all  -- spawned in its own thread
Controllers can reach each other through the table passed to Init (e.g. Controllers.HUDController).
```

## Uses

- (none)

## Used by

- (none)
