-- Weapons: every gun a player can unlock with Gems and equip in the lobby.
-- PURE DATA. To add a weapon, copy an entry, give it a new key, and set Order/GemCost.
-- Stats are tier-1 base values; GameConfig.WeaponTiers multiplies them during a run.
--
-- Fields:
--   DisplayName, Description   UI text
--   GemCost                    0 = owned by default
--   Order                      sort order in the lobby list
--   Damage                     per pellet
--   FireRate                   shots per second
--   Automatic                  true = hold to fire
--   MagSize, ReloadTime
--   Pellets                    rays per shot (shotguns > 1)
--   Spread                     cone half-angle in degrees
--   Range                      studs
--   Pierce                     how many zombies one ray can pass through (1 = stops at first)
--   HeadshotMultiplier
--   Look = { Length, Color }   procedural gun model

local Weapons = {}

Weapons.Default = "Pistol"

Weapons.List = {
	Pistol = {
		DisplayName = "Service Pistol",
		Description = "Reliable sidearm. Rewards headshots.",
		GemCost = 0,
		Order = 1,
		Damage = 26,
		FireRate = 5,
		Automatic = false,
		MagSize = 12,
		ReloadTime = 1.1,
		Pellets = 1,
		Spread = 0.6,
		Range = 300,
		Pierce = 1,
		HeadshotMultiplier = 2,
		Look = { Length = 1.4, Color = Color3.fromRGB(45, 45, 50) },
	},
	SMG = {
		DisplayName = "Scrap SMG",
		Description = "Sprays lead. Great for thinning crowds.",
		GemCost = 400,
		Order = 2,
		Damage = 14,
		FireRate = 12,
		Automatic = true,
		MagSize = 36,
		ReloadTime = 1.7,
		Pellets = 1,
		Spread = 2.8,
		Range = 220,
		Pierce = 1,
		HeadshotMultiplier = 1.5,
		Look = { Length = 2.0, Color = Color3.fromRGB(90, 80, 60) },
	},
	Shotgun = {
		DisplayName = "Pump Shotgun",
		Description = "Devastating up close. Useless at range.",
		GemCost = 650,
		Order = 3,
		Damage = 14,
		FireRate = 1.4,
		Automatic = false,
		MagSize = 6,
		ReloadTime = 2.2,
		Pellets = 9,
		Spread = 7,
		Range = 90,
		Pierce = 1,
		HeadshotMultiplier = 1.5,
		Look = { Length = 2.6, Color = Color3.fromRGB(110, 70, 40) },
	},
	Rifle = {
		DisplayName = "Marksman Rifle",
		Description = "Heavy rounds punch through a whole line.",
		GemCost = 900,
		Order = 4,
		Damage = 80,
		FireRate = 2,
		Automatic = false,
		MagSize = 8,
		ReloadTime = 2.0,
		Pellets = 1,
		Spread = 0.15,
		Range = 400,
		Pierce = 4,
		HeadshotMultiplier = 2.5,
		Look = { Length = 3.2, Color = Color3.fromRGB(60, 70, 60) },
	},
}

return Weapons
