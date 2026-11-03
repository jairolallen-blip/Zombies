-- Zombies: every enemy type. PURE DATA. Server/ZombieModels builds the blocky model from Look
-- (vault: Zombies.md); every zombie picks its own shirt/pants from the palettes.
-- To add a zombie: copy an entry, give it a new key, set MinWave/Weight so it enters the spawn pool.
--
-- Fields:
--   DisplayName
--   Index             enemy index card in the lobby (Server/Map/FieldStations, Client ShopController "Index"):
--                     Gems paid once for discovering it (first kill), Special (one line), Lore
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
--   Charge, Leap, SpecialGap, Intro   boss-only extras; see GraveTitan
--   Enrage = { At, SpeedMult, SlamCooldownMult, Summon, SummonCount, SummonRadius }
--                     at At (fraction of max HP): faster, slams more often, summons a ring of Summon
--   Lunge = { Range, SpeedMult, Duration, Cooldown }
--                     burst of speed when a player is within Range (runners)
--   Look = { Build, Skin, Eyes, Shirts = {...}, Pants = {...} }
--                     Build: "Normal" | "Lean" | "Bloated" | "Hulk" | "Titan" (see ZombieModels)

local Zombies = {}

Zombies.Types = {
	Shambler = {
		DisplayName = "Shambler",
		Index = { Gems = 50, Special = "The horde's backbone", Lore = "Most of Port Harrow, still walking its old routes. Slow alone, deadly in a crowd." },
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
		Index = { Gems = 75, Special = "Lunges when close", Lore = "The Bloom burns hot in the young ones. They sprint, then lunge from a few steps out." },
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
		Index = { Gems = 100, Special = "Bursts when close or killed", Lore = "Swollen with spores until they split. Shoot them at range; never let one reach you." },
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
		Index = { Gems = 150, Special = "Huge health, heavy hits", Lore = "Dock workers and soldiers the Bloom thickened. It takes a lot of lead to drop one." },
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
		Index = { Gems = 300, Special = "Charge, Leap, Slam; enrages at 50%", Lore = "What the Bloom grows into under the square, given time. It charges, leaps and slams; at half health it calls the pack." },
		Boss = true,
		Health = 18000, -- x (1 + 0.6 per extra player); the final-wave boss (vault: Waves and Boss.md)
		Speed = 8,
		Damage = 35,
		AttackRange = 4,
		AttackCooldown = 1.5,
		Cash = 1500,
		Scale = 3.4,
		Slam = { Radius = 20, Damage = 35, Windup = 1.3, Cooldown = 6, TriggerRange = 28 },
		-- Charge: plants its feet (red lane on the ground), then barrels straight down it, flattening
		-- anyone in the way. Leap: crouches, jumps onto a far-away player's spot (red ring) and lands
		-- with a shockwave. SpecialGap = minimum seconds between any two special attacks.
		Charge = { Windup = 1.1, Speed = 75, Distance = 70, Width = 9, Damage = 30, Knockback = 90, Cooldown = 9, MinRange = 22, MaxRange = 85 },
		Leap = { Windup = 0.8, AirTime = 1.1, Height = 30, Radius = 18, Damage = 35, Cooldown = 13, MinRange = 32 },
		SpecialGap = 2.5,
		-- 2026-11-02: Slam 45 -> 35, Charge 40 -> 30, Leap 45 -> 35 (the bot took ~1.7x a full health bar on this wave)
		-- entrance cutscene before the final wave (MatchService:_bossIntro, Client BossController)
		Intro = { Time = 7, RiseAt = 1.2, RiseTime = 3.2, RoarAt = 4.8 },
		Enrage = { At = 0.5, SpeedMult = 1.4, SlamCooldownMult = 0.5, Summon = "Runner", SummonCount = 6, SummonRadius = 14 },
		Look = {
			Build = "Titan",
			Skin = Color3.fromRGB(80, 110, 95),
			Eyes = Color3.fromRGB(120, 255, 230),
			Shirts = { Color3.fromRGB(35, 30, 40) },
			Pants = { Color3.fromRGB(30, 30, 35) },
		},
	},
}

-- The final wave's boss is BossOrder[1] (GameConfig.Waves.TotalWaves).
Zombies.BossOrder = { "GraveTitan" }

return Zombies
