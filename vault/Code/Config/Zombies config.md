# Zombies config

> Made by `tools/vault-code-notes.js` from `src/shared/Config/Zombies.luau` (145 lines). Don't edit it here: rerun the script.

Part of [[Config]].

## What it does

```text
Zombies: every enemy type. PURE DATA. Server/ZombieModels builds the blocky model from Look
(vault: Zombies.md); every zombie picks its own shirt/pants from the palettes.
To add a zombie: copy an entry, give it a new key, set MinWave/Weight so it enters the spawn pool.

Fields:
  DisplayName
  Health            base HP (scaled per wave by GameConfig.Waves.HealthScalePerWave)
  Speed             studs/second
  Damage            per melee hit (0 = no melee)
  AttackRange       studs from body edge
  AttackCooldown    seconds between melee hits
  Cash              Cash paid to the killer
  Scale             body size multiplier (also scales hitbox)
  MinWave, Weight   spawn pool: eligible from MinWave, picked proportionally to Weight
  Boss = true       never picked randomly; spawned by MatchService on boss waves (see BossOrder)
  Explode = { Radius, Damage, Fuse, TriggerRange, ShotPlayerDamageMult }
                    arms a fuse when a player is within TriggerRange, then explodes. Also explodes
                    on death; if killed by a player, players take Damage * ShotPlayerDamageMult.
  Slam = { Radius, Damage, Windup, Cooldown, TriggerRange }
                    telegraphed ground slam (red ring) — used by bosses
  Charge, Leap, SpecialGap, Intro   boss-only extras; see GraveTitan
  Enrage = { At, SpeedMult, SlamCooldownMult, Summon, SummonCount, SummonRadius }
                    at At (fraction of max HP): faster, slams more often, summons a ring of Summon
  Lunge = { Range, SpeedMult, Duration, Cooldown }
                    burst of speed when a player is within Range (runners)
  Look = { Build, Skin, Eyes, Shirts = {...}, Pants = {...} }
                    Build: "Normal" | "Lean" | "Bloated" | "Hulk" | "Titan" (see ZombieModels)
```

## Uses

- (none)

## Used by

- [[BossController]]
- [[DebugService]]
- [[MatchService]]
- [[ZombieService]]

## Mentions

- [[ZombieModels]]

## Design notes

- [[Zombies]]
- [[Waves and Boss]]
