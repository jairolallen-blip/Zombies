-- Zombies: every enemy type. PURE DATA. Server/ZombieModels builds the blocky model from Look
-- (vault: Zombies.md); every zombie picks its own shirt/pants from the palettes.
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
--   Lunge = { Range, SpeedMult, Duration, Cooldown }
--                     burst of speed when a player is within Range (runners)
--   Look = { Build, Skin, Eyes, Shirts = {...}, Pants = {...} }
--                     Build: "Normal" | "Lean" | "Bloated" | "Hulk" | "Titan" (see ZombieModels)

local Zombies = {}

Zombies.Types = {
	Shambler = {
		DisplayName = "Shambler",
		Health = 60,
		Speed = 10,
		Damage = 10,
		AttackRange = 2.5,
		AttackCooldown = 1.0,
		Cash = 15,
		Scale = 1,
		MinWave = 1,
		Weight = 10,
		Look = {
			Build = "Normal",
			Skin = Color3.fromRGB(120, 170, 90),
			Eyes = Color3.fromRGB(255, 60, 40),
			Shirts = { Color3.fromRGB(90, 80, 110), Color3.fromRGB(120, 60, 50), Color3.fromRGB(70, 90, 110), Color3.fromRGB(150, 140, 110), Color3.fromRGB(60, 80, 60) },
			Pants = { Color3.fromRGB(60, 60, 75), Color3.fromRGB(50, 70, 100), Color3.fromRGB(80, 70, 55) },
		},
	},
	Runner = {
		DisplayName = "Runner",
		Health = 35,
		Speed = 19,
		Damage = 7,
		AttackRange = 2.5,
		AttackCooldown = 0.7,
		Cash = 20,
		Scale = 0.9,
		MinWave = 3,
		Weight = 4,
		Lunge = { Range = 12, SpeedMult = 2, Duration = 0.5, Cooldown = 3 },
		Look = {
			Build = "Lean",
			Skin = Color3.fromRGB(160, 175, 110),
			Eyes = Color3.fromRGB(255, 220, 60),
			Shirts = { Color3.fromRGB(170, 60, 50), Color3.fromRGB(200, 190, 170), Color3.fromRGB(60, 60, 60) },
			Pants = { Color3.fromRGB(50, 50, 60), Color3.fromRGB(70, 60, 50) },
		},
	},
	Bloater = {
		DisplayName = "Bloater",
		Health = 90,
		Speed = 8,
		Damage = 0,
		AttackRange = 2.5,
		AttackCooldown = 1,
		Cash = 35,
		Scale = 1.25,
		MinWave = 5,
		Weight = 2,
		Explode = { Radius = 13, Damage = 40, Fuse = 0.9, TriggerRange = 7, ShotPlayerDamageMult = 0.4 },
		Look = {
			Build = "Bloated",
			Skin = Color3.fromRGB(150, 200, 60),
			Eyes = Color3.fromRGB(230, 255, 80),
			Shirts = { Color3.fromRGB(120, 180, 40), Color3.fromRGB(170, 160, 120) },
			Pants = { Color3.fromRGB(70, 90, 40) },
		},
	},
	Brute = {
		DisplayName = "Brute",
		Health = 450,
		Speed = 7.5,
		Damage = 28,
		AttackRange = 3,
		AttackCooldown = 1.4,
		Cash = 90,
		Scale = 1.7,
		MinWave = 7,
		Weight = 1,
		Look = {
			Build = "Hulk",
			Skin = Color3.fromRGB(95, 130, 85),
			Eyes = Color3.fromRGB(255, 40, 40),
			Shirts = { Color3.fromRGB(50, 45, 40), Color3.fromRGB(80, 40, 35) },
			Pants = { Color3.fromRGB(40, 40, 45) },
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
		Cash = 1500,
		Scale = 3.4,
		Slam = { Radius = 20, Damage = 45, Windup = 1.3, Cooldown = 6, TriggerRange = 28 },
		Look = {
			Build = "Titan",
			Skin = Color3.fromRGB(80, 110, 95),
			Eyes = Color3.fromRGB(120, 255, 230),
			Shirts = { Color3.fromRGB(35, 30, 40) },
			Pants = { Color3.fromRGB(30, 30, 35) },
		},
	},
}

-- Boss rotation for boss waves (GameConfig.Waves.BossEvery). Cycles when it runs out.
Zombies.BossOrder = { "GraveTitan" }

return Zombies
