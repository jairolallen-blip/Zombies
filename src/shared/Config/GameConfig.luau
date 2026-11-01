-- GameConfig: global tunables for match flow, waves, economy, upgrades, player, camera, map.
-- PURE DATA. Safe to edit numbers here; no logic lives in this file.
-- Read by both server and client (ReplicatedStorage.Shared.Config.GameConfig).

local GameConfig = {}

GameConfig.Lobby = {
	IntermissionTime = 20, -- seconds of countdown once enough players are in the lobby
	AllReadyTime = 3, -- countdown snaps down to this when every lobby player pressed Ready
	MinPlayers = 1,
}

GameConfig.Match = {
	ResultsTime = 6, -- seconds the results screen shows before everyone returns to the lobby
	RespawnDeadOnWaveStart = true, -- dead teammates come back at the start of each wave
}

GameConfig.Waves = {
	FirstBreakTime = 5, -- countdown before wave 1
	BreakTime = 8, -- countdown between waves
	BaseCount = 10, -- zombies in wave 1 (solo)
	CountPerWave = 5, -- +zombies each wave
	ExtraPlayerMultiplier = 0.6, -- each extra player adds +60% zombies
	SpawnInterval = 0.7, -- seconds between spawns in wave 1
	SpawnIntervalDecay = 0.04, -- interval shrinks by this each wave
	MinSpawnInterval = 0.12,
	MaxAlive = 70, -- hard cap on simultaneous zombies (performance)
	HealthScalePerWave = 0.10, -- zombie health +10% per wave
	BossEvery = 10, -- boss joins every Nth wave (0 = never)
	BossHealthScalePerAppearance = 0.75, -- each later boss appearance gets +75% health
}

GameConfig.Economy = {
	StartingCash = 0,
	TeamShare = 0.25, -- every other living teammate also gets 25% of a kill's Cash
	GemsPerWaveCleared = 5, -- Gems awarded at end of run
	GemsPerKill = 0.2,
}

-- In-run Cash upgrades. Keys bound in GameConfig.Keybinds.
GameConfig.Upgrades = {
	-- Costs[n] = price to go from tier n to tier n+1. Max tier = #Costs + 1 (must match #WeaponTiers).
	Weapon = { DisplayName = "Weapon Tier", Costs = { 250, 650, 1400 } },
	-- Each level adds HealthPerLevel max HP and fully heals. Cost = BaseCost * CostGrowth ^ level.
	Vitality = { DisplayName = "Vitality", MaxLevel = 10, BaseCost = 150, CostGrowth = 1.35, HealthPerLevel = 20 },
}

-- Multipliers applied to a weapon's base stats per tier (see Util.GetWeaponStats).
GameConfig.WeaponTiers = {
	{ Damage = 1.0, FireRate = 1.00, MagSize = 1.00, ReloadTime = 1.00, Color = Color3.fromRGB(150, 150, 155) },
	{ Damage = 1.5, FireRate = 1.10, MagSize = 1.25, ReloadTime = 0.90, Color = Color3.fromRGB(80, 210, 100) },
	{ Damage = 2.2, FireRate = 1.20, MagSize = 1.50, ReloadTime = 0.80, Color = Color3.fromRGB(70, 150, 255) },
	{ Damage = 3.2, FireRate = 1.35, MagSize = 2.00, ReloadTime = 0.70, Color = Color3.fromRGB(255, 190, 40) },
}

GameConfig.Ultimate = {
	Max = 100,
	ChargePerKill = 3,
	BossKillCharge = 100,
}

GameConfig.Player = {
	BaseHealth = 100,
	BaseWalkSpeed = 18,
}

GameConfig.Combat = {
	MaxOriginOffset = 30, -- server rejects shots whose origin is farther than this from the shooter's head
	FireRateTolerance = 0.5, -- server accepts shots this fraction faster than FireRate (latency jitter)
}

GameConfig.Camera = {
	-- Mouse is free (not centre-locked): aim with the cursor, rotate the camera with right-click drag.
	ShoulderOffset = Vector3.new(2, 1, 0), -- over-the-shoulder offset while in a run
	MinZoom = 6,
	MaxZoom = 14,
}

GameConfig.Keybinds = {
	Reload = Enum.KeyCode.R,
	Ability = Enum.KeyCode.E,
	Ultimate = Enum.KeyCode.F,
	UpgradeWeapon = Enum.KeyCode.One,
	UpgradeVitality = Enum.KeyCode.Two,
}

-- "Graveside Isle": a stud-style village island in the ocean (docs/ART_STYLE.md). Flat grass arena
-- with jagged dirt paths, a well in the plaza, cottages/trees/rocks/fences crowding the edge, and
-- 8 graveyards (4 corners + 4 side midpoints) where zombies rise. Built by MapService:Build().
GameConfig.Map = {
	ArenaCenter = Vector3.new(0, 0, 0),
	ArenaSize = 200, -- square play area, studs per side (invisible walls at the edge)
	CellSize = 4, -- ground is built from CellSize x CellSize cells, merged into rectangles
	EdgeDepth = 20, -- band along the arena edge filled with cottages, trees, rocks (behind a fence)
	BeachWidth = 18, -- jagged sand ring between the arena and the ocean
	WaterLevel = -1.5, -- ocean surface (Terrain water); ground top is at Y = 1
	PlazaRadius = 18, -- dirt plaza around the centre well
	WellRadius = 4, -- players spawn in a ring just outside the well
	GraveyardRadius = 13, -- dirt patch + tombstones around each zombie spawn
	LobbyCenter = Vector3.new(0, 0, 235),
	LobbySize = 80, -- lobby island (grass core; beach added around it)
	LobbyTier1 = 20, -- half-size of the lower walkable plateau (multiple of CellSize)
	LobbyTier2 = 12, -- half-size of the upper plateau with the tower
	ZombieSpawnCount = 8, -- graveyards: corners + side midpoints
	CoverCount = 16, -- interior props: trees, rocks, crate stacks, bushes, stalls, campfire (seeded)
	CoverClearRadius = 28, -- keep the plaza open
	Seed = 1337,
}

GameConfig.Data = {
	StoreName = "SAMZ_Profile_v1", -- change the suffix to wipe all saves
	StudioStartingGems = 2500, -- new profiles in Studio get this many Gems for testing (0 in live servers)
}

return GameConfig
