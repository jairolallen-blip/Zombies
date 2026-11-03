# Store

The Robux shop (added 2026-11-02). Back to [[Home]]. Catalogue in [[Store config]]; purchases in [[StoreService]]; window in [[StoreController]]; the stall is built by [[FieldStations]].

## Where
- The pink **SHOP** button under the lobby info chip (always one click away: that's where purchases happen).
- **THE TRADER** stall, south-east of the plaza on the way to the Commons, opens the same window.

## What it sells
Sized to our small Gem economy (everything in the game costs about 6,650 Gems):
- **Gem packs:** 500, 1,200, 3,000, 7,500 Gems (Developer Products, buy again any time).
- **Starter Pack:** the Medic class and 1,000 Gems, once per player.
- **2x Gems** game pass: doubles the Gems from every run.
- **VIP** game pass: a VIP tag in the safehouse and +50% daily rations ([[Lobby]]).
No stronger guns for Robux, so it never feels pay-to-win. Prices are the owner's call; Roblox's real prices show in the shop.

## To go live
Create each Developer Product and Game Pass on the Creator Dashboard (Monetization) and put its id in [[Store config]]. An id of 0 shows SOON.

## How purchases stay safe
Each receipt pays once: its id is saved in the profile with the reward, and Roblox only hears "granted" after that save succeeds. If the save fails, Roblox retries later and nothing is paid twice. See [[DataService]] and [[Servers and Teleports]] (session lock).

## Later
Gifting a purchase to another player; a "Get more Gems" link where an unlock is too expensive.
