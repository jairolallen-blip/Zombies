# Conditions config

> Made by `tools/vault-code-notes.js` from `src/shared/Config/Conditions.luau` (112 lines). Don't edit it here: rerun the script.

Part of [[Config]].

## What it does

```text
Conditions: the weather and time of day each run gets, picked at random (vault: City Map.md). PURE DATA.
MatchService:RunMatch picks one by Weight (the tutorial is always the first) and sets GameState Condition;
MapService:ApplyAtmosphere lays its Atmosphere fields over GameConfig.OurMap.Atmosphere (fields left out
keep the sunset values). Client/Controllers/ConditionsController draws Rain around the camera and puts a
flashlight on every player while Flashlights is set. PostFXController's sunset grade only runs on Sunset.
OFF for now (2026-11-02, the owner prefers the sunset look): every weather but Sunset has Weight 0.
"Nightmare" is never rolled: MatchService uses it for every Nightmare run (Config/Nightmare).
```

## Uses

- (none)

## Used by

- [[ConditionsController]]
- [[MatchService]]

## Mentions

- [[Nightmare config]]

## Design notes

- [[City Map]]
