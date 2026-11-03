# ZombieModels

> Made by `tools/vault-code-notes.js` from `src/server/ZombieModels.luau` (533 lines). Don't edit it here: rerun the script.

Part of [[Server services]].

## What it does

```text
ZombieModels: blocky R6-style zombie bodies with per-zombie variation (vault: Zombies.md; style from
MODEL REFERENCES). ZombieModels.Build(typeId, def, cframe) -> model, root, linearVelocity, alignOrientation

Contract used by ZombieService / CombatService / EffectsController:
  "Root"      invisible collision hitbox (2.4 x 5 x 1.6 * Scale), centre at the given CFrame
  Motor6Ds named LeftArm / RightArm / LeftLeg / RightLeg on Root (client animates .Transform)
  "Torso"     the shirt block (Bloater fuse turns it neon)
  "Head", "Head*" detail parts and "Eye" parts count as headshots
Builds (def.Look.Build): Normal, Lean (hunched), Bloated, Hulk, Titan, and for Nightmare Crawler (on all
fours) and Gaunt (tall, arms to the knees). def.Look.Horror adds a Nightmare type's details (horror()).
```

## Uses

- (none)

## Used by

- [[ZombieService]]

## Mentions

- [[Zombies config]]

## Design notes

- [[Zombies]]
- [[Nightmare Mode]]
