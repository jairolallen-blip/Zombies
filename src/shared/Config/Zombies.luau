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
--   Spores, Burst, Death, Intro.Style   the Nightmare boss's extras; see BloomMother
--   Enrage = { At, SpeedMult, SlamCooldownMult, Summon, SummonCount, SummonRadius }
--                     at At (fraction of max HP): faster, slams more often, summons a ring of Summon
--   Lunge = { Range, SpeedMult, Duration, Cooldown }
--                     burst of speed when a player is within Range (runners)
--   Look = { Build, Skin, Eyes, Shirts = {...}, Pants = {...}, Horror?, Bone? }
--                     Build: "Normal" | "Lean" | "Bloated" | "Hulk" | "Titan" | "Crawler" | "Gaunt" (see ZombieModels)
--                     Horror: the Nightmare details ZombieModels adds ("Rotter" | "Skitter" | "Husk" | "Half" | "Wailer" | "Bloom")
-- Nightmare types (Config/Nightmare; the NIGHTMARE row of the enemy index):
--   Nightmare = true   spawns only in Nightmare runs, and Nightmare runs spawn only these (ZombieService:PickType)
--   Pack               spawned in a group of this many (MatchService)
--   Burrow = { MinRange, Cooldown, Down, Under, Behind }
--                     when its target is MinRange+ studs away it sinks into the ground (Down seconds, can't be
--                     shot), stays under for Under, then a red warning circle opens Behind studs behind the target
--                     and it rises out of it (ZombieService:_burrow; GameConfig.Waves SpawnWarning / RiseTime)
--   Split = { Into, Count }   on death, Count zombies of type Into crawl out where it fell (ZombieService:Kill)
--   SpawnMin = n      never spawns closer than n studs to a player (the Wailer: no roar the moment it rises)
--   Wail = { Range, Radius, Pull, Windup, Cooldown, Blur, Stun, RushMult, RushTime }
--                     within Range of a player it stops and screams for Windup: players within Radius get their
--                     sight blurred for Blur seconds, a ringing in the ears and can't move for Stun seconds
--                     (NightmareController), and every zombie within Pull of it
--                     rushes the nearest player at RushMult speed for RushTime (ZombieService:_wail)
--   An entry without Index (the Husk's halves) is left out of the enemy index.

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

	-- The Nightmare boss (owner design 2026-11-03): a swollen spore-mother, slow and huge.
	--   Spores: it rears up for Windup, then lobs Count pods (EnragedCount in phase 2) that land after Flight
	--     inside red circles: one on each player in Range (led a little), the rest scattered within Spread.
	--     Each does Damage within Radius, then leaves a poison cloud there: CloudDamage every 0.5s for Cloud s.
	--   Burst: with a player within Radius it roots itself and swells while a red ring and a countdown run
	--     for Windup; then everyone still inside takes Damage and is thrown out. First at First s, then Cooldown.
	--   Enrage (phase 2): faster, specials come sooner (SlamCooldownMult), Rotters climb out around it.
	--   Death: a cutscene (MatchService:_bossDeath, BossController): the horde collapses, the body swells,
	--     bursts into spores at BurstAt that drift up, and the sky fades to dawn (ClockTime Dawn).
	--   Intro.Style "Bloom": the sky turns sick green and it tears out of a giant pod (BossController).
	BloomMother = {
		DisplayName = "The Bloom Mother",
		Nightmare = true,
		Index = { Gems = 400, Special = "Spore pods, poison clouds and the Bloom Burst; Rotters at 50%", Lore = "Where the Bloom began. It doesn't hunt, it seeds. Kill it and everything it grew dies with it." },
		Boss = true,
		Health = 16000, -- x Nightmare.BossHealthMult, x (1 + 0.6 per extra player)
		Speed = 7,
		Damage = 30,
		AttackRange = 5,
		AttackCooldown = 1.5,
		Cash = 2000,
		Scale = 3.6,
		Spores = { Count = 3, EnragedCount = 5, Range = 90, Windup = 0.5, Flight = 1.3, Spread = 10, Radius = 7, Damage = 18, Cloud = 4, CloudDamage = 4, Cooldown = 4.5 },
		Burst = { Radius = 30, Windup = 3.5, Damage = 75, Knockback = 70, Cooldown = 20, First = 14 },
		SpecialGap = 1.5,
		Intro = { Time = 8, RiseAt = 2.4, RiseTime = 3, RoarAt = 5.8, Style = "Bloom" },
		Death = { Time = 8, BurstAt = 3.2, Dawn = 6.4 },
		Enrage = { At = 0.5, SpeedMult = 1.25, SlamCooldownMult = 0.6, Summon = "Rotter", SummonCount = 6, SummonRadius = 16 },
		Look = {
			Build = "Bloated",
			Horror = "Bloom",
			Skin = Color3.fromRGB(118, 128, 86),
			Eyes = Color3.fromRGB(225, 255, 110),
			Shirts = { Color3.fromRGB(58, 52, 38) },
			Pants = { Color3.fromRGB(42, 38, 32) },
		},
	},

	-- Nightmare counterparts (owner design 2026-11-02; models from the owner's references, see ZombieModels horror())
	Rotter = {
		DisplayName = "Rotter",
		Nightmare = true,
		Index = { Gems = 100, Special = "Tougher, faster, jaw hanging open", Lore = "Shamblers the Bloom never let go of. The jaw came loose weeks ago; it still tries to bite." },
		Health = 80,
		Speed = 12,
		Damage = 12,
		AttackRange = 2.5,
		AttackCooldown = 0.9,
		Cash = 18,
		Scale = 1.05,
		MinWave = 1,
		Weight = 10,
		Look = {
			Build = "Normal",
			Horror = "Rotter",
			Skin = Color3.fromRGB(112, 128, 104),
			Eyes = Color3.fromRGB(255, 34, 24),
			Shirts = { Color3.fromRGB(58, 52, 60), Color3.fromRGB(84, 46, 40), Color3.fromRGB(70, 66, 54) },
			Pants = { Color3.fromRGB(44, 48, 58), Color3.fromRGB(60, 52, 44) },
		},
	},
	Skitter = {
		DisplayName = "Skitter",
		Nightmare = true,
		Index = { Gems = 125, Special = "Burrows, then bursts up behind you", Lore = "Its skin went first, then it took to the ground. A Skitter goes under where you can't shoot it and comes up at your back. Watch for the red circle behind you." },
		Health = 45,
		Speed = 9, -- a slow crawl: the threat is the ambush, not the chase (2026-11-03, was a fast lunger)
		Damage = 10,
		AttackRange = 2.5,
		AttackCooldown = 0.8,
		Cash = 25,
		Scale = 0.85,
		MinWave = 2,
		Weight = 4,
		Pack = 2,
		Burrow = { MinRange = 18, Cooldown = 8, Down = 0.6, Under = 1.4, Behind = 6 },
		Look = {
			Build = "Crawler",
			Horror = "Skitter",
			Skin = Color3.fromRGB(138, 40, 36), -- flayed muscle
			Eyes = Color3.fromRGB(255, 236, 120),
			Bone = Color3.fromRGB(226, 210, 178),
			Shirts = { Color3.fromRGB(138, 40, 36) },
			Pants = { Color3.fromRGB(118, 34, 32), Color3.fromRGB(46, 42, 46) },
		},
	},
	Wailer = {
		DisplayName = "Wailer",
		Nightmare = true,
		Index = { Gems = 150, Special = "Its scream blurs your sight and calls the horde", Lore = "Port Harrow's sirens went quiet. These took over. When one screams, everything nearby comes running." },
		Health = 120,
		Speed = 9,
		Damage = 10,
		AttackRange = 2.5,
		AttackCooldown = 1,
		Cash = 40,
		Scale = 1.15,
		MinWave = 4,
		Weight = 2,
		SpawnMin = 50,
		Wail = { Range = 20, Radius = 24, Pull = 60, Windup = 1, Cooldown = 9, Blur = 3, Stun = 0.4, RushMult = 1.5, RushTime = 4 },
		Look = {
			Build = "Gaunt",
			Horror = "Wailer",
			Skin = Color3.fromRGB(204, 200, 192),
			Eyes = Color3.fromRGB(236, 246, 255), -- blind, glowing
			Shirts = { Color3.fromRGB(78, 58, 62), Color3.fromRGB(60, 62, 70) },
			Pants = { Color3.fromRGB(58, 78, 108), Color3.fromRGB(46, 60, 84) }, -- jeans
		},
	},
	Husk = {
		DisplayName = "Husk",
		Nightmare = true,
		Index = { Gems = 200, Special = "Bone armour; splits in two when it falls", Lore = "Something grew a shell around a Brute. Crack it open and both halves keep crawling." },
		Health = 650,
		Speed = 7,
		Damage = 32,
		AttackRange = 3,
		AttackCooldown = 1.4,
		Cash = 120,
		Scale = 1.8,
		MinWave = 6,
		Weight = 1,
		Split = { Into = "HuskHalf", Count = 2 },
		Look = {
			Build = "Hulk",
			Horror = "Husk",
			Skin = Color3.fromRGB(88, 96, 84),
			Eyes = Color3.fromRGB(255, 120, 40), -- and the seam
			Bone = Color3.fromRGB(206, 192, 166),
			Shirts = { Color3.fromRGB(44, 40, 38) },
			Pants = { Color3.fromRGB(38, 36, 40) },
		},
	},
	HuskHalf = { -- what a Husk leaves behind (Split); never spawned by itself, not in the index
		DisplayName = "Husk Half",
		Nightmare = true,
		Health = 140,
		Speed = 9,
		Damage = 14,
		AttackRange = 2.5,
		AttackCooldown = 1,
		Cash = 30,
		Scale = 1.15,
		MinWave = 1,
		Weight = 0,
		Look = {
			Build = "Crawler",
			Horror = "Half",
			Skin = Color3.fromRGB(88, 96, 84),
			Eyes = Color3.fromRGB(255, 120, 40),
			Bone = Color3.fromRGB(206, 192, 166),
			Shirts = { Color3.fromRGB(44, 40, 38) },
			Pants = { Color3.fromRGB(38, 36, 40) },
		},
	},
}

-- The final wave's boss is BossOrder[1] (GameConfig.Waves.TotalWaves).
Zombies.BossOrder = { "GraveTitan" }
-- A Nightmare run's final wave has this boss instead (MatchService:_bossIntro).
Zombies.NightmareBoss = "BloomMother"

return Zombies
