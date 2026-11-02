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

-- Drop-in at the start of a run (vault: Match Start.md): helicopter cutscene from the lobby helipad
-- to above the arena spawn, then players parachute down. Enabled = false -> teleport straight in.
GameConfig.Deploy = {
	Enabled = true,
	FlightTime = 8, -- seconds of helicopter cutscene before the drop
	DropHeight = 75, -- studs above the spawn pads where players jump
	FallSpeed = 30, -- parachute descent, studs/s
	CruiseHeight = 95, -- helicopter altitude over the rooftops
}

GameConfig.Waves = {
	FirstBreakTime = 12, -- intermission after the drop, before wave 1
	BreakTime = 8, -- countdown between waves
	-- intensity ramp over the 10 rounds (vault: Spawning.md)
	BaseCount = 8, -- zombies in wave 1 (solo)
	CountPerWave = 6, -- +zombies each wave (wave 10 = 62)
	ExtraPlayerMultiplier = 0.6, -- each extra player adds +60% zombies
	SpawnInterval = 1.4, -- seconds between spawn groups in wave 1
	SpawnIntervalDecay = 0.12, -- interval shrinks by this each wave (wave 10 = 0.32s)
	MinSpawnInterval = 0.3,
	BurstEvery = 3, -- zombies per spawn group = 1 + floor(wave / BurstEvery) (wave 10 = 4)
	-- where and how they appear
	SpawnMinDistance = 22, -- studs from every player
	SpawnMaxDistance = 75, -- studs from the player it spawns around
	SpawnWarning = 1.2, -- seconds the red circle shows before the zombie rises
	RiseTime = 0.6, -- seconds to climb out of the ground
	MaxAlive = 70, -- hard cap on simultaneous zombies (performance)
	HealthScalePerWave = 0.10, -- zombie health +10% per wave
	-- the run (vault: Waves and Boss.md): clear TotalWaves to win; the last wave is the boss wave
	TotalWaves = 10,
	BossWaveHordeMult = 0.6, -- the boss wave's horde is this share of a normal wave's count
}

GameConfig.Economy = {
	StartingCash = 0,
	TeamShare = 0.25, -- every other living teammate also gets 25% of a kill's Cash
	GemsPerWaveCleared = 5, -- Gems awarded at end of run
	GemsPerKill = 0.2,
	VictoryGems = 100, -- bonus Gems for clearing the final wave
	-- cash every living run player gets when a wave is cleared: Base + PerWave * wave
	-- (tuned so solo players reach gun Level 2 ~wave 2, Level 3 ~wave 5, Level 4 ~wave 9; vault: Weapons.md)
	WaveClearCash = { Base = 100, PerWave = 150 },
}

-- In-run Cash upgrades. Keys bound in GameConfig.Keybinds.
GameConfig.Upgrades = {
	-- Costs[n] = price to go from gun Level n to Level n+1 (swaps to the next Loadout gun).
	-- Max level = #Costs + 1 (must match Weapons.Levels and #WeaponTiers).
	Weapon = { DisplayName = "Weapon Level", Costs = { 500, 2500, 10000 } },
	-- Each level adds HealthPerLevel max HP and fully heals. Cost = BaseCost * CostGrowth ^ level.
	Vitality = { DisplayName = "Vitality", MaxLevel = 10, BaseCost = 150, CostGrowth = 1.35, HealthPerLevel = 20 },
}

-- Per-Level multipliers on a weapon's base stats (see Util.GetWeaponStats) and the Level colour
-- (gun stripe + HUD). Each Level is its own gun now, so the multipliers stay at 1.
GameConfig.WeaponTiers = {
	{ Damage = 1, FireRate = 1, MagSize = 1, ReloadTime = 1, Color = Color3.fromRGB(150, 150, 155) },
	{ Damage = 1, FireRate = 1, MagSize = 1, ReloadTime = 1, Color = Color3.fromRGB(80, 210, 100) },
	{ Damage = 1, FireRate = 1, MagSize = 1, ReloadTime = 1, Color = Color3.fromRGB(70, 150, 255) },
	{ Damage = 1, FireRate = 1, MagSize = 1, ReloadTime = 1, Color = Color3.fromRGB(255, 190, 40) },
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

-- The map: Workspace.OurMap (vault: Lobby.md, City Map.md), built and baked in Edit mode by
-- Server/Map/OurLobby (Lobby: "LobbySpawn" parts, helipad "Pad") and Server/Map/OurCity
-- (Arena: "PlayerSpawn" + "ZombieSpawn" parts). Read at runtime by MapService.
GameConfig.OurMap = {
	Folder = "OurMap",
	LobbyCenter = Vector3.new(1000, 0, 235),
	ArenaCenter = Vector3.new(1000, 0, 0),
	ArenaHalfSize = 138, -- OurCity: 23 tiles x 12 studs / 2 (zombie nav grid covers this square)
	NavCellSize = 4, -- zombie NavGrid cell (OurCity's 12-stud tiles are 3 x 3 cells)
	-- warm, hazy sunset applied at server start (MapService:ApplyAtmosphere)
	Atmosphere = {
		ClockTime = 17.4,
		Brightness = 2.2,
		Ambient = Color3.fromRGB(96, 80, 64),
		OutdoorAmbient = Color3.fromRGB(150, 120, 92),
		HazeColor = Color3.fromRGB(214, 160, 104),
		AtmosphereColor = Color3.fromRGB(230, 190, 140),
		Density = 0.42,
		Haze = 2.4,
		TintColor = Color3.fromRGB(255, 232, 200),
		Saturation = -0.18,
		Contrast = 0.08,
	},
}

GameConfig.Data = {
	StoreName = "SAMZ_Profile_v1", -- change the suffix to wipe all saves
	StudioStartingGems = 2500, -- new profiles in Studio get this many Gems for testing (0 in live servers)
}

return GameConfig
