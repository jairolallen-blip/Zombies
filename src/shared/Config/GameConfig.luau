-- GameConfig: global tunables for match flow, waves, economy, upgrades, player, camera, map.
-- PURE DATA. Safe to edit numbers here; no logic lives in this file.
-- Read by both server and client (ReplicatedStorage.Shared.Config.GameConfig).

local GameConfig = {}

GameConfig.Lobby = {
	-- the countdown only runs while someone stands on the helipad (MapService:IsOnHelipad); only
	-- players on it when it hits 0 deploy, everyone else keeps shopping
	IntermissionTime = 10, -- seconds of countdown once someone is on the helipad
	AllReadyTime = 4, -- countdown snaps down to this when every lobby player is on the helipad
	MinPlayers = 1,
}

GameConfig.Match = {
	ResultsTime = 6, -- seconds the results screen shows before everyone returns to the lobby
	RespawnDeadOnWaveStart = true, -- dead teammates come back at the start of each wave
	HealOnWaveClear = 1, -- living players heal this fraction of max HP when a wave is cleared (no regen otherwise)
}

-- Drop-in at the start of a run (vault: Match Start.md): first-person helicopter cutscene from over
-- the ocean to above the city square (path: MapService:GetDeployFlight), then players parachute
-- down. Enabled = false -> teleport straight in.
GameConfig.Deploy = {
	Enabled = true,
	FlightTime = 18, -- seconds of helicopter cutscene before the drop
	DropHeight = 110, -- studs above the spawn pads where players jump
	FreefallTime = 0.5, -- seconds of freefall before the canopy opens
	FallSpeed = 22, -- parachute descent, studs/s
	OceanStart = Vector3.new(140, 0, -1050), -- flight start, relative to the square (north = -Z, the sea)
	FinalApproach = Vector3.new(0, 0, -300), -- bezier bend: lines up on the north avenue
	SeaAltitude = 28, -- skimming the waves
	CruiseHeight = 95, -- planned altitude over the city
	Clearance = 16, -- minimum studs between the helicopter's centre and any roof under it
	MaxClimbPerSample = 7, -- slope limit of that floor (samples are ~13 studs apart)
	PathSamples = 80,
}

GameConfig.Waves = {
	FirstBreakTime = 12, -- intermission after the drop, before wave 1
	BreakTime = 8, -- countdown between waves
	-- intensity ramp over the 10 rounds (vault: Spawning.md)
	BaseCount = 8, -- zombies in wave 1 (solo)
	CountPerWave = 6, -- +zombies each wave (wave 10 = 62)
	ExtraPlayerMultiplier = 0.6, -- each extra player adds +60% zombies
	-- a wave's spawns are spread over SpawnSeconds + SpawnSecondsPerWave * wave seconds, so late
	-- waves are bigger AND longer instead of an instant flood (balance pass: vault Waves and Boss.md)
	SpawnSeconds = 16,
	SpawnSecondsPerWave = 1, -- wave 8 = 24s -> ~2 zombies/s solo
	SpawnInterval = 1.4, -- slowest gap between spawn groups (early waves)
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
	-- Runs are FIRST PERSON (CameraController): mouse locked to the screen centre, aim from the
	-- centre, gun drawn by ViewmodelController. Hold Keybinds.FreeCursor to free the mouse.
	FieldOfView = 80, -- first-person FOV during runs (lobby uses Roblox's default 70)
	LobbyMaxZoom = 30, -- third-person zoom limit in the lobby
	-- Viewmodel placement in camera space (studs): right, down, forward
	ViewmodelOffset = Vector3.new(0.85, -0.95, -1.6),
	ViewmodelKick = 0.18, -- how far the gun jolts back per shot (scaled by the gun's Recoil)
}

-- Grenade throw animation (ThrowController / ViewmodelController); the server releases the grenade
-- at Windup, so the projectile leaves the hand at the top of the swing.
GameConfig.Throw = {
	Windup = 0.32, -- seconds from key press to release
	Duration = 0.8, -- whole animation (wind-up, swing, recover)
}

GameConfig.Keybinds = {
	Reload = Enum.KeyCode.R,
	Ability = Enum.KeyCode.E,
	Ultimate = Enum.KeyCode.F,
	UpgradeWeapon = Enum.KeyCode.One,
	UpgradeVitality = Enum.KeyCode.Two,
	FreeCursor = Enum.KeyCode.LeftAlt, -- hold to free the mouse in first person (click HUD buttons)
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
