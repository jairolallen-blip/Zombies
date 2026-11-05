---
tags: [zone-config]
cssclasses: [zone-config]
---

# Airdrops config

> Made by `tools/vault-code-notes.js` from `src/shared/Config/Airdrops.luau` (35 lines). Don't edit it here: rerun the script.

Part of [[Config]].

## What it does

```text
Airdrops: mid-run supply crates (Server/Services/AirdropService, Client/Controllers/AirdropController).
From FirstWave on, each wave has Chance of one crate parachuting onto a street away from the squad,
marked with red smoke, a light pillar and an on-screen marker. Guards rise around it as it lands;
hold G to open it (E is the class ability). The reward goes to every living squad member within ShareRadius of the crate.
PURE DATA.
```

## Uses

- (none)

## Used by

- [[AirdropController]]
- [[AirdropService]]
