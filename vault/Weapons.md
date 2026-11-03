# Weapons (phase 4): done

Built and playtested on 2026-11-01. In a real run, all 4 levels produced the right model, the server accepted their shots, hits and kills registered, and ammo drained correctly. Upgrading at max level shows "Weapon — MAX". The wave-clear bonus is correct (+$250 after wave 1). A self-check builds all 10 gun models.

Part of the [[Roadmap]]. The loadout and upgrade flow is in [[Lobby]]. Style comes from `MODEL REFERENCES/` (the multi-gun sheets): **blocky, low-poly, part-built guns with readable silhouettes**.

## Gun identities
| Lv | Gun | Feel | Model notes |
|---|---|---|---|
| 1 | Service Pistol | snappy and accurate, rewards headshots | black slide, sights |
| 1 | Hand Cannon | slow and heavy, pierces 2, big kick | steel revolver, wood grip, cylinder |
| 2 | Scrap SMG | bullet hose, very little kick | curved mag, wire stock |
| 2 | Pump Shotgun | 9-pellet blast, big kick | long barrel, wooden pump and stock |
| 3 | Assault Rifle | the reliable all-rounder | AK style, wood furniture, curved mag |
| 3 | Auto Shotgun | full-auto shotgun for close range | boxy body, drum mag |
| 3 | Marksman Rifle | one shot pierces 5, sniper kick | olive, scope, muzzle brake |
| 4 | Minigun | **spins up**, then shreds, pierces 2 | spinning 6-barrel cluster, ammo box |
| 4 | Laser Rifle | cyan beam that pierces 12, no recoil | white body, neon strips, energy cell |
| 4 | Auto Sniper | full-auto sniper power | black, scope, box mag, brake |

## Feel features
- **Distinct model per gun** (`Shared/GunModels`), with a neon stripe in the level colour.
- **Recoil:** a camera kick per shot that recovers smoothly (`Recoil` in degrees).
- **Tracers and muzzle flash per gun** (`Tracer = {Color, Width, Fade}`, `Flash`). The laser fires a thick glowing beam, and other players see the right tracer too.
- **Minigun spin-up:** the fire rate ramps up over `SpinUp` seconds while the barrels visibly spin.
- **Shell ejection:** a small brass casing pops out (not on the laser).

## Balance targets (solo)
Zombie HP is Shambler 60, Runner 35, Bloater 90, Brute 450 and the Grave Titan boss 7000, each +10% per wave.
- Approximate DPS by level: L1 about 130, L2 about 270, L3 about 400 (Auto Shotgun about 575 up close), L4 about 550–925.
- **Economy retune** so upgrades arrive during a 10-wave run: L2 around wave 2, L3 around wave 4–5, and L4 around wave 9 solo (sooner in groups because of team share), in time for the boss.
  - Kill cash: Shambler 15, Runner 20, Bloater 35, Brute 90, boss 1,500.
  - Wave-clear bonus: $100 + $150 × wave.

## Later
- **Sounds** for shots, reloads, the minigun spin and the laser hum, once audio assets are chosen.
- Reload animations (dropping the mag).

## Code
Data in [[Weapons config]] and [[GunModels]]. [[WeaponController]] and [[ViewmodelController]] on the client, [[CombatService]] on the server, upgrades in [[EconomyService]], shared math in [[Util]].

Back to [[Home]].
