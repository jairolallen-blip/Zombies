---
tags: [zone-config]
cssclasses: [zone-config]
---

# Weapons config (Zombies)

> Made by `tools/vault-code-notes.js` from `src/shared/Config/Weapons.luau` (142 lines). Don't edit it here: rerun the script.

Part of [[Config (Zombies)|Config]].

## What it does

```text
Weapons: every gun, grouped into 4 upgrade Levels (vault: Weapons.md, Lobby.md).
PURE DATA. In the lobby a player picks one gun per Level (their Loadout). A run starts on the
Level 1 gun; each in-run Weapon upgrade (GameConfig.Upgrades.Weapon) swaps to the next Level's gun.
The 3D model for each id lives in Shared/GunModels (same key).
To add a weapon, copy an entry, give it a new key, a Level, an Order and a GemCost, and add a
model spec to GunModels (it falls back to the pistol model otherwise).

Fields:
  DisplayName, Description   UI text
  Level                      1..Weapons.Levels — which loadout slot it fills
  GemCost                    0 = owned by default (exactly one free gun per Level: the default)
  Order                      sort order in the lobby list
  Damage                     per pellet
  FireRate                   shots per second (top speed for SpinUp guns)
  Automatic                  true = hold to fire
  SpinUp                     seconds of holding fire to reach full FireRate (starts at 30%)
  MagSize, ReloadTime
  Pellets                    rays per shot (shotguns > 1)
  Spread                     cone half-angle in degrees
  Range                      studs
  Pierce                     how many zombies one ray can pass through (1 = stops at first)
  HeadshotMultiplier
  Recoil                     camera kick per shot, degrees
  Tracer = { Color, Width, Fade }   bullet trail look (Fade = seconds)
  Flash                      muzzle flash size multiplier; FlashColor optional
  NoShells = true            no ejected casings (energy weapons)
```

## Uses

- (none)

## Used by

- [[CombatService (Zombies)]]
- [[DataService (Zombies)]]
- [[EconomyService (Zombies)]]
- [[EffectsController (Zombies)]]
- [[HUDController (Zombies)]]
- [[LobbyController (Zombies)]]
- [[LobbyMenu (Zombies)]]
- [[LobbyService (Zombies)]]
- [[OurLobby (Zombies)]]
- [[ShopController (Zombies)]]
- [[Util (Zombies)]]

## Mentions

- [[GunModels (Zombies)]]

## Design notes

- [[Weapons]]
- [[Lobby]]
