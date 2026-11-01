-- Weapons: every gun, grouped into 4 upgrade Levels (vault: Lobby.md).
-- PURE DATA. In the lobby a player picks one gun per Level (their Loadout). A run starts on the
-- Level 1 gun; each in-run Weapon upgrade (GameConfig.Upgrades.Weapon) swaps to the next Level's gun.
-- To add a weapon, copy an entry, give it a new key, a Level, an Order and a GemCost.
-- Stats are PLACEHOLDERS until the gun pass (Roadmap phase 4).
--
-- Fields:
--   DisplayName, Description   UI text
--   Level                      1..Weapons.Levels — which loadout slot it fills
--   GemCost                    0 = owned by default (exactly one free gun per Level: the default)
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
Weapons.Levels = 4

Weapons.List = {
	-- Level 1: sidearms (starter)
	Pistol = {
		DisplayName = "Service Pistol",
		Description = "Reliable sidearm. Rewards headshots.",
		Level = 1,
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
	Revolver = {
		DisplayName = "Hand Cannon",
		Description = "Slow, loud revolver. Each round punches through two zombies.",
		Level = 1,
		GemCost = 300,
		Order = 2,
		Damage = 55,
		FireRate = 2.2,
		Automatic = false,
		MagSize = 6,
		ReloadTime = 1.8,
		Pellets = 1,
		Spread = 0.4,
		Range = 320,
		Pierce = 2,
		HeadshotMultiplier = 2.5,
		Look = { Length = 1.7, Color = Color3.fromRGB(120, 110, 95) },
	},

	-- Level 2: SMG / first shotgun
	SMG = {
		DisplayName = "Scrap SMG",
		Description = "Sprays lead. Great for thinning crowds.",
		Level = 2,
		GemCost = 0,
		Order = 3,
		Damage = 21,
		FireRate = 13,
		Automatic = true,
		MagSize = 40,
		ReloadTime = 1.6,
		Pellets = 1,
		Spread = 2.6,
		Range = 220,
		Pierce = 1,
		HeadshotMultiplier = 1.5,
		Look = { Length = 2.0, Color = Color3.fromRGB(90, 80, 60) },
	},
	Shotgun = {
		DisplayName = "Pump Shotgun",
		Description = "Devastating up close. Useless at range.",
		Level = 2,
		GemCost = 400,
		Order = 4,
		Damage = 20,
		FireRate = 1.5,
		Automatic = false,
		MagSize = 7,
		ReloadTime = 2.0,
		Pellets = 9,
		Spread = 7,
		Range = 90,
		Pierce = 1,
		HeadshotMultiplier = 1.5,
		Look = { Length = 2.6, Color = Color3.fromRGB(110, 70, 40) },
	},

	-- Level 3: rifles
	AssaultRifle = {
		DisplayName = "Assault Rifle",
		Description = "Steady full-auto fire at any range.",
		Level = 3,
		GemCost = 0,
		Order = 5,
		Damage = 34,
		FireRate = 10,
		Automatic = true,
		MagSize = 36,
		ReloadTime = 1.7,
		Pellets = 1,
		Spread = 1.4,
		Range = 320,
		Pierce = 1,
		HeadshotMultiplier = 1.8,
		Look = { Length = 2.8, Color = Color3.fromRGB(60, 62, 58) },
	},
	AutoShotgun = {
		DisplayName = "Auto Shotgun",
		Description = "Hold the trigger and erase whatever is in front of you.",
		Level = 3,
		GemCost = 600,
		Order = 6,
		Damage = 26,
		FireRate = 4,
		Automatic = true,
		MagSize = 10,
		ReloadTime = 2.4,
		Pellets = 8,
		Spread = 8,
		Range = 85,
		Pierce = 1,
		HeadshotMultiplier = 1.5,
		Look = { Length = 2.8, Color = Color3.fromRGB(70, 55, 45) },
	},
	Rifle = {
		DisplayName = "Marksman Rifle",
		Description = "Heavy sniper rounds punch through a whole line.",
		Level = 3,
		GemCost = 600,
		Order = 7,
		Damage = 180,
		FireRate = 1.3,
		Automatic = false,
		MagSize = 6,
		ReloadTime = 2.2,
		Pellets = 1,
		Spread = 0.1,
		Range = 500,
		Pierce = 5,
		HeadshotMultiplier = 3,
		Look = { Length = 3.4, Color = Color3.fromRGB(60, 70, 60) },
	},

	-- Level 4: heavy hitters
	Minigun = {
		DisplayName = "Minigun",
		Description = "A wall of bullets. Long reload, endless fun.",
		Level = 4,
		GemCost = 0,
		Order = 8,
		Damage = 42,
		FireRate = 22,
		Automatic = true,
		MagSize = 200,
		ReloadTime = 4,
		Pellets = 1,
		Spread = 3.2,
		Range = 260,
		Pierce = 2,
		HeadshotMultiplier = 1.5,
		Look = { Length = 3.2, Color = Color3.fromRGB(80, 82, 88) },
	},
	LaserRifle = {
		DisplayName = "Laser Rifle",
		Description = "Beam passes straight through the entire horde.",
		Level = 4,
		GemCost = 1200,
		Order = 9,
		Damage = 90,
		FireRate = 6,
		Automatic = true,
		MagSize = 30,
		ReloadTime = 2,
		Pellets = 1,
		Spread = 0.1,
		Range = 400,
		Pierce = 12,
		HeadshotMultiplier = 2,
		Look = { Length = 3.0, Color = Color3.fromRGB(70, 200, 255) },
	},
	AutoSniper = {
		DisplayName = "Auto Sniper",
		Description = "Sniper power with an automatic trigger.",
		Level = 4,
		GemCost = 1200,
		Order = 10,
		Damage = 260,
		FireRate = 3.5,
		Automatic = true,
		MagSize = 10,
		ReloadTime = 2.6,
		Pellets = 1,
		Spread = 0.1,
		Range = 500,
		Pierce = 6,
		HeadshotMultiplier = 3,
		Look = { Length = 3.6, Color = Color3.fromRGB(45, 50, 45) },
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
