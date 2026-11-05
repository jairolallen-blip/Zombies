-- Weapons: every gun, grouped into 4 upgrade Levels (vault: Weapons.md, Lobby.md).
-- PURE DATA. In the lobby a player picks one gun per Level (their Loadout). A run starts on the
-- Level 1 gun; each in-run Weapon upgrade (GameConfig.Upgrades.Weapon) swaps to the next Level's gun.
-- The 3D model for each id lives in Shared/GunModels (same key).
-- To add a weapon, copy an entry, give it a new key, a Level, an Order and a GemCost, and add a
-- model spec to GunModels (it falls back to the pistol model otherwise).
--
-- Fields:
--   DisplayName, Description   UI text
--   Level                      1..Weapons.Levels — which loadout slot it fills
--   GemCost                    0 = owned by default (exactly one free gun per Level: the default)
--   Order                      sort order in the lobby list
--   Damage                     per pellet
--   FireRate                   shots per second (top speed for SpinUp guns)
--   Automatic                  true = hold to fire
--   SpinUp                     seconds of holding fire to reach full FireRate (starts at 30%)
--   MagSize, ReloadTime
--   Pellets                    rays per shot (shotguns > 1)
--   Spread                     cone half-angle in degrees
--   Range                      studs
--   Pierce                     how many zombies one ray can pass through (1 = stops at first)
--   HeadshotMultiplier
--   Recoil                     camera kick per shot, degrees
--   Tracer = { Color, Width, Fade }   bullet trail look (Fade = seconds)
--   Flash                      muzzle flash size multiplier; FlashColor optional
--   NoShells = true            no ejected casings (energy weapons)

local Weapons = {}

Weapons.Default = "Pistol"
Weapons.Levels = 4

local BULLET = Color3.fromRGB(255, 226, 150)
local BRIGHT = Color3.fromRGB(255, 250, 235)

Weapons.List = {
	-- Level 1: sidearms (starter)
	Pistol = {
		DisplayName = "Service Pistol", Description = "Snappy and accurate. Rewards headshots.",
		Level = 1, GemCost = 0, Order = 1,
		Damage = 26, FireRate = 5, Automatic = false, MagSize = 12, ReloadTime = 1.1,
		Pellets = 1, Spread = 0.6, Range = 300, Pierce = 6, HeadshotMultiplier = 2,
		Recoil = 1.4, Tracer = { Color = BULLET, Width = 0.1, Fade = 0.08 }, Flash = 0.8,
	},
	Revolver = {
		DisplayName = "Hand Cannon", Description = "Slow, loud revolver. Each round punches through two zombies.",
		Level = 1, GemCost = 300, Order = 2,
		Damage = 60, FireRate = 2, Automatic = false, MagSize = 6, ReloadTime = 1.9,
		Pellets = 1, Spread = 0.3, Range = 340, Pierce = 5, HeadshotMultiplier = 2.5,
		Recoil = 3, Tracer = { Color = BULLET, Width = 0.16, Fade = 0.12 }, Flash = 1.3,
	},

	-- Level 2: SMG / first shotgun
	SMG = {
		DisplayName = "Scrap SMG", Description = "Sprays lead with barely any kick. Great for thinning crowds.",
		Level = 2, GemCost = 0, Order = 3,
		Damage = 20, FireRate = 13, Automatic = true, MagSize = 40, ReloadTime = 1.6,
		Pellets = 1, Spread = 2.6, Range = 220, Pierce = 6, HeadshotMultiplier = 1.5,
		Recoil = 0.7, Tracer = { Color = BULLET, Width = 0.08, Fade = 0.07 }, Flash = 0.8,
	},
	Shotgun = {
		DisplayName = "Pump Shotgun", Description = "Nine-pellet blast. Devastating up close, useless at range.",
		Level = 2, GemCost = 400, Order = 4,
		Damage = 22, FireRate = 1.4, Automatic = false, MagSize = 7, ReloadTime = 2.1,
		Pellets = 9, Spread = 7, Range = 90, Pierce = 5, HeadshotMultiplier = 1.5,
		Recoil = 4.5, Tracer = { Color = BULLET, Width = 0.06, Fade = 0.06 }, Flash = 1.6,
	},

	-- Level 3: rifles
	AssaultRifle = {
		DisplayName = "Assault Rifle", Description = "Steady full-auto fire at any range. The reliable all-rounder.",
		Level = 3, GemCost = 0, Order = 5,
		Damage = 40, FireRate = 10, Automatic = true, MagSize = 36, ReloadTime = 1.7,
		Pellets = 1, Spread = 1.3, Range = 320, Pierce = 7, HeadshotMultiplier = 1.8,
		Recoil = 0.9, Tracer = { Color = BULLET, Width = 0.1, Fade = 0.08 }, Flash = 1,
	},
	AutoShotgun = {
		DisplayName = "Auto Shotgun", Description = "Hold the trigger and erase whatever is in front of you.",
		Level = 3, GemCost = 600, Order = 6,
		Damage = 18, FireRate = 4, Automatic = true, MagSize = 12, ReloadTime = 2.4,
		Pellets = 8, Spread = 8, Range = 85, Pierce = 5, HeadshotMultiplier = 1.5,
		Recoil = 2.4, Tracer = { Color = BULLET, Width = 0.06, Fade = 0.06 }, Flash = 1.4,
	},
	Rifle = {
		DisplayName = "Marksman Rifle", Description = "Heavy sniper rounds punch through a whole line of five.",
		Level = 3, GemCost = 600, Order = 7,
		Damage = 190, FireRate = 1.3, Automatic = false, MagSize = 6, ReloadTime = 2.2,
		Pellets = 1, Spread = 0.1, Range = 500, Pierce = 8, HeadshotMultiplier = 3,
		Recoil = 5, Tracer = { Color = BRIGHT, Width = 0.22, Fade = 0.35 }, Flash = 1.6,
	},

	-- Level 4: heavy hitters
	Minigun = {
		DisplayName = "Minigun", Description = "Spins up, then becomes a wall of bullets. Long reload.",
		Level = 4, GemCost = 0, Order = 8,
		Damage = 42, FireRate = 22, SpinUp = 0.7, Automatic = true, MagSize = 200, ReloadTime = 4,
		Pellets = 1, Spread = 3.2, Range = 260, Pierce = 5, HeadshotMultiplier = 1.5,
		Recoil = 0.3, Tracer = { Color = Color3.fromRGB(255, 170, 80), Width = 0.1, Fade = 0.07 }, Flash = 1.1,
	},
	LaserRifle = {
		DisplayName = "Laser Rifle", Description = "A cyan beam that passes straight through the entire horde.",
		Level = 4, GemCost = 1200, Order = 9,
		Damage = 90, FireRate = 6, Automatic = true, MagSize = 30, ReloadTime = 2,
		Pellets = 1, Spread = 0.1, Range = 400, Pierce = 15, HeadshotMultiplier = 2,
		Recoil = 0.25, Tracer = { Color = Color3.fromRGB(70, 220, 255), Width = 0.35, Fade = 0.25 },
		Flash = 0.9, FlashColor = Color3.fromRGB(70, 220, 255), NoShells = true,
	},
	AutoSniper = {
		DisplayName = "Auto Sniper", Description = "Sniper power with an automatic trigger. Pierces six.",
		Level = 4, GemCost = 1200, Order = 10,
		Damage = 260, FireRate = 3.5, Automatic = true, MagSize = 10, ReloadTime = 2.6,
		Pellets = 1, Spread = 0.1, Range = 500, Pierce = 9, HeadshotMultiplier = 3,
		Recoil = 2.8, Tracer = { Color = BRIGHT, Width = 0.2, Fade = 0.3 }, Flash = 1.5,
	},
}

-- The free gun of a Level (used for new profiles and as a fallback).
function Weapons.DefaultFor(level)
	for id, def in Weapons.List do
		if def.Level == level and def.GemCost == 0 then
			return id
		end
	end
	return Weapons.Default
end

-- Every gun of a Level, sorted by Order.
function Weapons.ForLevel(level)
	local ids = {}
	for id, def in Weapons.List do
		if def.Level == level then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return Weapons.List[a].Order < Weapons.List[b].Order
	end)
	return ids
end

return Weapons
