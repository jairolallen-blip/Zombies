---
tags: [zone-server]
cssclasses: [zone-server]
---

# Server Main

> Made by `tools/vault-code-notes.js` from `src/server/Main.server.luau` (48 lines). Don't edit it here: rerun the script.

Part of [[Server services]].

## What it does

```text
Server entry point. Requires every ModuleScript in Services, then calls
  service:Init(Services)  on all (in ORDER)  -- create instances, connect remotes, no yielding
  service:Start()         on all (in ORDER)  -- spawned in its own thread; may loop forever
Services reference each other through the Services table passed to Init.
New service? Drop a ModuleScript in Services/ — it is auto-loaded after the ordered ones.
```

## Uses

- (none)

## Used by

- (none)
