---
tags: [zone-working]
cssclasses: [zone-working]
game-zone: working
---

# Phones and Gamepads

Most Roblox players are on phones, so the run plays without a keyboard (added 2026-11-02). Back to [[Zombies Home|Home]]. Code: [[TouchController (Zombies)|TouchController]], with the trigger in [[WeaponController (Zombies)|WeaponController]].

## Phones
- Buttons on the right while the run camera is on: **FIRE** (hold), **AIM** (toggle), **R** reload, **E** ability, **F** ultimate.
- Drag anywhere else to look; the left stick moves. Aim is the centre of the screen, same as on PC.
- The HUD's upgrade buttons ([[HUDController (Zombies)|HUDController]]) and every ProximityPrompt (supply crates, shops, the daily rations) are tappable already.
- The cutscene skip has its own hold button ([[SkipController (Zombies)|SkipController]]).

## Gamepads
R2 fire, L2 aim, X reload, L1 ability, R1 ultimate, D-pad up gun upgrade, D-pad right Vitality, Y opens a supply crate ([[Supply Drops]]).

## Layout check (2026-11-02)
On a small landscape phone (844 x 390) the UI shrinks to its minimum scale, 0.6. There FIRE and AIM overlapped the HUD upgrade buttons (about y 238-290), so the cluster moved up: it now sits between the toasts and the upgrade buttons, clear of Roblox's jump button (y 300-370). Worked out from the layout numbers, not seen on a screen yet.

## Not checked yet
- On a real phone: button placement next to Roblox's jump button and the HUD, and aiming feel.
- Aim-down-sights is AnimatedSL's Studio-only work, so AIM does nothing in builds without it.
