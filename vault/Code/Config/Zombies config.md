# Zombies config

> Made by `tools/vault-code-notes.js` from `src/shared/Config/Zombies.luau` (285 lines). Don't edit it here: rerun the script.

Part of [[Config]].

## What it does

```text
Zombies: every enemy type. PURE DATA. Server/ZombieModels builds the blocky model from Look
(vault: Zombies.md); every zombie picks its own shirt/pants from the palettes.
To add a zombie: copy an entry, give it a new key, set MinWave/Weight so it enters the spawn pool.

Fields:
  DisplayName
  Index             enemy index card in the lobby (Server/Map/FieldStations, Client ShopController "Index"):
                    Gems paid once for discovering it (first kill), Special (one line), Lore
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
  Look = { Build, Skin, Eyes, Shirts = {...}, Pants = {...}, Horror?, Bone? }
                    Build: "Normal" | "Lean" | "Bloated" | "Hulk" | "Titan" | "Crawler" | "Gaunt" (see ZombieModels)
                    Horror: the Nightmare details ZombieModels adds ("Rotter" | "Skitter" | "Husk" | "Half" | "Wailer")
Nightmare types (Config/Nightmare; the NIGHTMARE row of the enemy index):
  Nightmare = true   spawns only in Nightmare runs, and Nightmare runs spawn only these (ZombieService:PickType)
  Pack               spawned in a group of this many (MatchService)
  Burrow = { MinRange, Cooldown, Down, Under, Behind }
                    when its target is MinRange+ studs away it sinks into the ground (Down seconds, can't be
                    shot), stays under for Under, then a red warning circle opens Behind studs behind the target
                    and it rises out of it (ZombieService:_burrow; GameConfig.Waves SpawnWarning / RiseTime)
  Split = { Into, Count }   on death, Count zombies of type Into crawl out where it fell (ZombieService:Kill)
  Wail = { Range, Radius, Pull, Windup, Cooldown, Blur, Stun, RushMult, RushTime }
                    within Range of a player it stops and screams for Windup: players within Radius get their
                    sight blurred for Blur seconds, a ringing in the ears and can't move for Stun seconds
                    (NightmareController), and every zombie within Pull of it
                    rushes the nearest player at RushMult speed for RushTime (ZombieService:_wail)
  An entry without Index (the Husk's halves) is left out of the enemy index.
```

## Uses

- (none)

## Used by

- [[BossController]]
- [[DataService]]
- [[DebugService]]
- [[MatchService]]
- [[ShopController]]
- [[WelcomeController]]
- [[ZombieService]]

## Mentions

- [[FieldStations]]
- [[Nightmare config]]
- [[ZombieModels]]

## Design notes

- [[Zombies]]
- [[Waves and Boss]]
