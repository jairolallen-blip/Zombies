---
tags: [zone-config]
cssclasses: [zone-config]
---

# Radio config

> Made by `tools/vault-code-notes.js` from `src/shared/Config/Radio.luau` (138 lines). Don't edit it here: rerun the script.

Part of [[Config]].

## What it does

```text
Radio: the commander's lines (vault: Match Start.md). PURE DATA.
MatchService picks a random line for an event and sends it to run players (Remotes.Radio);
Client/Controllers/RadioController shows it next to the commander's portrait.
"{wave}" is replaced with the wave number. The tutorial's step lines live in Config/Tutorial.
Tutorial and Nightmare runs use "Tutorial<event>" / "Nightmare<event>" over "<event>" when it exists.
```

## Uses

- (none)

## Used by

- [[MatchService]]
- [[RadioController]]

## Mentions

- [[Nightmare config]]
- [[Tutorial config]]

## Design notes

- [[Match Start]]
