# Lobby (phase 1): done

Part of the [[Roadmap]]. Built and playtested on 2026-11-01.

## What players get
1. **Pick a class** (left panel). There are 5 classes, unlocked with Gems.
2. **Build a loadout** (right panel): **one gun per level**. The first gun in each level is free, and the others cost Gems.
3. **Ready up.** The countdown starts the run, and pressing Ready together shortens it.
4. **In a run** you start on your Level 1 gun. The **upgrade button on the right side** (or key `1`) swaps you to your next loadout gun, paid for with cash from kills plus a **wave-clear bonus** of $75 + $25 × wave.

## Gun levels
| Level | Free gun | Gem guns | Upgrade cost |
|---|---|---|---|
| 1 | Service Pistol | Hand Cannon (revolver, 300) | starter |
| 2 | Scrap SMG | Pump Shotgun (400) | $500 |
| 3 | Assault Rifle | Auto Shotgun (600), Marksman Rifle (sniper, 600) | $2,500 |
| 4 | Minigun | Laser Rifle (pierces 12, 1200), Auto Sniper (1200) | $10,000 |

The stats are **placeholders** until [[Weapons]] (phase 4). The procedural gun models are also placeholders.

## Shops (2026-11-02)
The always-on left and right panels were replaced by two **walk-up shops** (press `E` at the prompt):
- **Armory**, the west tent: level tabs 1–4 and a card per gun with a **rotating 3D model**, stat bars (damage, fire rate, magazine, range), traits, and equip or unlock.
- **Barracks**, the east sandbags: **5 class mannequins** on pedestals in the lobby, and a shop card per class with a rotating figure, abilities, traits, and equip or unlock.

Each class figure has its own pose and kit (`Shared/ClassFigures`, upgraded 2026-11-02). All of them have a face, vest, gloves and knee pads.
- **Survivor:** a cap, bandolier and backpack, with a rifle held across the chest.
- **Scout:** goggles, a scarf, binoculars and a slung sniper, mid-stride.
- **Medic:** a cross helmet, armband, medkit and cross backpack.
- **Engineer:** a hard hat with headlamp, hi-vis vest, tool belt and wrench.
- **Bruiser:** a visored helmet, armour plates, riot shield and sledgehammer.

**The barracks area** is an open army tent on a plank deck. It has string lights, a sign under the front beam, and pedestals spaced 5 studs apart. Each pedestal has a neon ring, a nameplate and a spotlight in its class colour. Lockers, a weapon rack and crates sit at the back, with sandbags at the front corners. Rebuild only that area with `OurLobby.RebuildBarracks()`, which keeps every other hand edit.

The lobby screen keeps only a small chip (Gems, best wave, class, gun lineup, where the shops are) and the take-off status. Both scale with the screen height (`UIKit.AutoScale`, 2026-11-02). The chip sits at 0.75 on top of that, and the status bar is 560 wide so the prompt fits on one line.

## Helipad ready zone (2026-11-02)
There's no Ready button; **standing on the helipad is being ready.** That way nobody is rushed while shopping.
- **The countdown only runs while someone is on the pad.** It runs 10s, or 4s when every lobby player is on it. Step off and it resets.
- **Only players on the pad deploy.** Everyone else keeps shopping and joins the next run.
- **Code:** `MapService:IsOnHelipad` (a radius check on the `Pad` cylinder) sets `Ready` each tick in `MatchService:_lobbyPhase`. The tunables are in `GameConfig.Lobby`.

## Commendations board (2026-11-02)
This is the achievements station, **south of the plaza and facing it**, so players pass it every time they come back from a run.
- **The board:** a corkboard of pinned papers and medals under an awning lit by two lamps, with an open crate of glowing gems beside it.
- **Status sign:** shows "N READY TO CLAIM" in green when there's something to collect.
- **The screen:** press `E` to open it. It's a scrolling list of 22 achievements (`Config/Achievements`), each with a progress bar and a CLAIM button that pays Gems.
- **What counts:** total kills, kills per zombie type, headshot kills, waves cleared, best wave, runs, wins (total and per class, including "win as every class"), and supply drops opened.
- **Toasts:** a message pops up mid-run when you finish one.

## Our lobby build
A fortified safehouse inside a ruined city at **x = 1000, z = 380**, on its own island south of the arena city (the old map is at x = 0). Its layout:
- **Foundation** (2026-11-02): one 184 × 172 slate slab under the whole footprint, top at Y = 0.95 and reaching below the seabed. Terrain water inside it is cleared, so no ocean shows between buildings. Before this, only the 124-stud asphalt floor existed and the ruins and containers hung over water. The lobby also moved from z = 235 to 380, which leaves about 140 studs of sea between it and the city.
- **North:** ruined towers, and in front of them the **Deploy Zone helipad**, which will be the take-off point for the drop-in cutscene (see [[Match Start]]).
- **Centre:** a concrete plaza with a flagpole and burning barrels. Players spawn in a ring around it, facing the helipad.
- **West:** the armory tent (the loadout spot). **East:** a command post behind sandbags.
- **Sides:** stacked shipping containers, with more ruins behind them. **South:** jersey barriers and a chain-link fence.

## How it's wired (code)
- `GameConfig.OurMap` (centres at x = 1000) is **the only map**. On 2026-11-01 the original "Graveside Isle" generator, the friend's city map, `Props` and `Bricks` were deleted, and MapService now only reads our marker parts (see [[Roadmap#Project history]]).
- `Server/Map/OurLobby` builds `Workspace.OurMap.Lobby`. It's baked in Edit mode (rebuild instructions are in its header), so it can be hand-edited afterwards.
- `MapService:GetLobbySpawnCFrame()` uses the parts named `LobbySpawn` in our lobby.
- **The arena is still the original one** until our city exists, since `OurMap` has no `Arena` yet. That's phase 2.
- Profile: `Loadout = { [level] = weaponId }` replaces `EquippedWeapon`. Old saves are migrated automatically, and every free gun is granted.
- `WeaponTier` now means **gun level**. `GameConfig.WeaponTiers` multipliers are all 1, kept only for the level colours.

## Notes for later
- Lighting and sky are still the original map's bright daytime look. Give our map its own atmosphere (overcast, fog, dusk) in [[City Map]], switching on `ActiveMap`.
- The helipad is decorative for now. In phase 3 it's where the drop-in cutscene starts.
- **Shared code:** the loadout and upgrade changes also apply to the friend's version.
