-- Zombies: every enemy type. PURE DATA. ZombieService builds the blocky model from Look.
-- To add a zombie: copy an entry, give it a new key, set MinWave/Weight so it enters the spawn pool.
--
-- Fields:
--   DisplayName
--   Health            base HP (scaled per wave by GameConfig.Waves.HealthScalePerWave)
--   Speed             studs/second
--   Damage            per melee hit (0 = no melee)
--   AttackRange       studs from body edge
--   AttackCooldown    seconds between melee hits
--   Cash              Cash paid to the killer
--   Scale             body size multiplier (also scales hitbox)
--   MinWave, Weight   spawn pool: eligible from MinWave, picked proportionally to Weight
--   Boss = true       never picked randomly; spawned by MatchService on boss waves (see BossOrder)
--   Explode = { Radius, Damage, Fuse, TriggerRange, ShotPlayerDamageMult }
--                     arms a fuse when a player is within TriggerRange, then explodes. Also explodes
--                     on death; if killed by a player, players take Damage * ShotPlayerDamageMult.
--   Slam = { Radius, Damage, Windup, Cooldown, TriggerRange }
--                     telegraphed ground slam (red ring) — used by bosses
--   Look = { Skin, Shirt, Pants, Eyes, TorsoSize? }   colours; TorsoSize is a Vector3 multiplier

local Zombies = {}

Zombies.Types = {
	Shambler = {
		DisplayName = "Shambler",
		Health = 60,
		Speed = 10,
		Damage = 10,
		AttackRange = 2.5,
		AttackCooldown = 1.0,
		Cash = 10,
		Scale = 1,
		MinWave = 1,
		Weight = 10,
		Look = {
			Skin = Color3.fromRGB(120, 170, 90),
			Shirt = Color3.fromRGB(90, 80, 110),
			Pants = Color3.fromRGB(60, 60, 75),
			Eyes = Color3.fromRGB(255, 60, 40),
		},
	},
	Runner = {
		DisplayName = "Runner",
		Health = 35,
		Speed = 19,
		Damage = 7,
		AttackRange = 2.5,
		AttackCooldown = 0.7,
		Cash = 14,
		Scale = 0.9,
		MinWave = 3,
		Weight = 4,
		Look = {
			Skin = Color3.fromRGB(160, 175, 110),
			Shirt = Color3.fromRGB(170, 60, 50),
			Pants = Color3.fromRGB(50, 50, 60),
			Eyes = Color3.fromRGB(255, 220, 60),
		},
	},
	Bloater = {
		DisplayName = "Bloater",
		Health = 90,
		Speed = 8,
		Damage = 0,
		AttackRange = 2.5,
		AttackCooldown = 1,
		Cash = 25,
		Scale = 1.25,
		MinWave = 5,
		Weight = 2,
		Explode = { Radius = 13, Damage = 40, Fuse = 0.9, TriggerRange = 7, ShotPlayerDamageMult = 0.4 },
		Look = {
			Skin = Color3.fromRGB(150, 200, 60),
			Shirt = Color3.fromRGB(120, 180, 40),
			Pants = Color3.fromRGB(70, 90, 40),
			Eyes = Color3.fromRGB(230, 255, 80),
			TorsoSize = Vector3.new(1.5, 1.3, 1.8),
		},
	},
	Brute = {
		DisplayName = "Brute",
		Health = 450,
		Speed = 7.5,
		Damage = 28,
		AttackRange = 3,
		AttackCooldown = 1.4,
		Cash = 60,
		Scale = 1.7,
		MinWave = 7,
		Weight = 1,
		Look = {
			Skin = Color3.fromRGB(95, 130, 85),
			Shirt = Color3.fromRGB(50, 45, 40),
			Pants = Color3.fromRGB(40, 40, 45),
			Eyes = Color3.fromRGB(255, 40, 40),
			TorsoSize = Vector3.new(1.3, 1.1, 1.3),
		},
	},
	GraveTitan = {
		DisplayName = "The Grave Titan",
		Boss = true,
		Health = 7000,
		Speed = 8,
		Damage = 35,
		AttackRange = 4,
		AttackCooldown = 1.5,
		Cash = 1000,
		Scale = 3.4,
		Slam = { Radius = 20, Damage = 45, Windup = 1.3, Cooldown = 6, TriggerRange = 28 },
		Look = {
			Skin = Color3.fromRGB(80, 110, 95),
			Shirt = Color3.fromRGB(35, 30, 40),
			Pants = Color3.fromRGB(30, 30, 35),
			Eyes = Color3.fromRGB(120, 255, 230),
			TorsoSize = Vector3.new(1.3, 1.15, 1.2),
		},
	},
}

-- Boss rotation for boss waves (GameConfig.Waves.BossEvery). Cycles when it runs out.
Zombies.BossOrder = { "GraveTitan" }

return Zombies
