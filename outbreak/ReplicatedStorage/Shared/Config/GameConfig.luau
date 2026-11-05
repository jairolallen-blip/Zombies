-- GameConfig: global tunables for match flow, waves, economy, upgrades, player, camera, map.
-- PURE DATA. Safe to edit numbers here; no logic lives in this file.
-- Read by both server and client (ReplicatedStorage.Shared.Config.GameConfig).

local GameConfig = {}

GameConfig.Lobby = {
	-- Flight Line pads (Server/Services/QueueService): the first player on an empty pad is its host and
	-- picks the mission; the countdown runs while anyone is on that pad and only its squad takes off
	-- (live: into their own private match server; Studio: the run plays in the lobby server)
	IntermissionTime = 15, -- seconds of countdown once someone is on a pad (time for friends to hop on)
	AllReadyTime = 4, -- the countdown snaps down to this when the pad's squad is full
	SquadSizes = { 1, 2, 3, 4 }, -- the host's squad-size choices
	DefaultSquadSize = 4,
	SquadWaitTime = 20, -- match server: seconds to wait for the rest of the squad after the first arrives
	-- The pad sets the difficulty: the caged Nightmare pad (Map/FlightLine, Config/Nightmare) plays "Nightmare".
	-- Locked maps show as "SOON" and can't be picked (MatchService:RunMatch falls back to the first)
	Difficulties = {
		{ Id = "Normal", Name = "NORMAL" },
		{ Id = "Nightmare", Name = "NIGHTMARE" },
	},
	Maps = {
		{ Id = "City", Name = "DEAD CITY" },
		{ Id = "Unknown", Name = "???", Locked = true },
	},
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
	FirstBreakTime = 8, -- intermission after the drop, before wave 1 (was 12: a faster start)
	BreakTime = 8, -- countdown between waves
	-- intensity ramp over the 10 rounds (vault: Spawning.md)
	BaseCount = 14, -- zombies in wave 1 (solo); was 8, raised so the run starts busy and the $500 gun upgrade comes after wave 1
	CountPerWave = 5, -- +zombies each wave (wave 10 = 59, close to the old 62)
	ExtraPlayerMultiplier = 0.6, -- each extra player adds +60% zombies
	-- a wave's spawns are spread over SpawnSeconds + SpawnSecondsPerWave * wave seconds, so late
	-- waves are bigger AND longer instead of an instant flood (balance pass: vault Waves and Boss.md)
	SpawnSeconds = 16,
	SpawnSecondsPerWave = 1, -- wave 8 = 24s -> ~2 zombies/s solo
	SpawnInterval = 1.4, -- slowest gap between spawn groups (early waves)
	MinSpawnInterval = 0.3,
	BurstEvery = 3, -- zombies per spawn group = 1 + floor(wave / BurstEvery) (wave 10 = 4)
	-- where and how they appear
	SpawnMinDistance = 50, -- studs from every player
	SpawnMaxDistance = 75, -- studs from the player it spawns around
	SpawnWarning = 1.2, -- seconds the red circle shows before the zombie rises
	RiseTime = 0.9, -- seconds to climb out of the ground (was 0.6; slower so the crawl-out reads, 2026-11-03)
	MaxAlive = 70, -- hard cap on simultaneous zombies (performance)
	HealthScalePerWave = 0.10, -- zombie health +10% per wave
	-- the run (vault: Waves and Boss.md): clear TotalWaves to win; the last wave is the boss wave
	TotalWaves = 10,
	BossWaveHordeMult = 0.4, -- the boss wave's horde is this share of a normal wave's count (was 0.6; eased 2026-11-02)
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
	{ Name = "COMMON", Damage = 1, FireRate = 1, MagSize = 1, ReloadTime = 1, Color = Color3.fromRGB(168, 171, 182) }, -- StoneLight
	{ Name = "RARE", Damage = 1, FireRate = 1, MagSize = 1, ReloadTime = 1, Color = Color3.fromRGB(122, 194, 82) }, -- GrassLight
	{ Name = "EPIC", Damage = 1, FireRate = 1, MagSize = 1, ReloadTime = 1, Color = Color3.fromRGB(105, 160, 220) }, -- steel blue (stone family)
	{ Name = "LEGENDARY", Damage = 1, FireRate = 1, MagSize = 1, ReloadTime = 1, Color = Color3.fromRGB(245, 200, 60) }, -- warm sign Yellow
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
	-- Viewmodel (ViewmodelController). The gun is the real GunModels model scaled down, so it sits
	-- close to the eye without filling the screen or poking through walls.
	ViewmodelScale = 0.55,
	ViewmodelOffset = Vector3.new(0.55, -0.75, -1.3), -- hip position of the grip, camera space (right, up, back)
	ViewmodelYaw = 7, -- degrees the barrel angles in toward the crosshair at the hip
	-- Recoil = mostly FEEL, little aim disturbance: the viewmodel kicks hard (pushes back, muzzle
	-- rises, settles with a spring) while the camera barely moves and recovers fast.
	ViewmodelKick = 9.5, -- viewmodel punch multiplier (scaled by the gun's Recoil and fire rate)
	RecoilCamera = 0.1, -- camera climb per shot (fraction of the gun's Recoil degrees; capped at 1.5)
	RecoilPunch = 0.3, -- instant camera snap, gone in ~70ms (feel, not aim)
	RecoilShake = 0.25, -- random camera roll per shot
	RecoilFovPunch = 0.6, -- degrees of FOV punch per point of Recoil (capped at 4, snaps back fast)
	SleeveColor = Color3.fromRGB(74, 84, 58), -- olive jacket
	GloveColor = Color3.fromRGB(150, 112, 76), -- tan leather (reads against black guns)
	-- Aim down sights (hold right mouse): gun moves to the centre, FOV zooms, spread tightens.
	AimDistance = -1.55, -- how far in front of the eye the grip sits while aiming
	AimSpeed = 14, -- higher = faster in/out
	AimFieldOfView = 62,
	ScopeFieldOfView = 34, -- guns with a Scope part (Marksman, Auto Sniper) show a scope overlay
	AimSpreadMultiplier = 0.4,
	LookSensitivity = 1, -- overall look speed (scriptable first-person look)
	AimSensitivity = 0.45, -- look speed while aiming down sights (scoped: x0.6 more)
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
	Aim = Enum.UserInputType.MouseButton2, -- hold to aim down sights
}

-- The map: Workspace.OurMap (vault: Lobby.md, City Map.md), built and baked in Edit mode by
-- Server/Map/OurLobby (Lobby: "LobbySpawn" parts, helipad "Pad") and Server/Map/OurCity
-- (Arena: "PlayerSpawn" + "ZombieSpawn" parts). Read at runtime by MapService.
GameConfig.OurMap = {
	Folder = "OurMap",
	LobbyCenter = Vector3.new(1000, 0, 1000), -- far south of the city, out of sight; its Flight Line deck reaches north to z = 810
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

-- Client "shaders" (Client/Controllers/PostFXController): a moody, cinematic grade layered on top of
-- the server's sunset (OurMap.Atmosphere). Off while Deploying, so the deploy cutscene is unchanged.
GameConfig.PostFX = {
	Enabled = true,
	-- Lighting overrides (restored when the grade switches off)
	Lighting = {
		ExposureCompensation = -0.3, -- darker overall
		Ambient = Color3.fromRGB(62, 52, 46), -- deeper indoor/under-cover shadows
		OutdoorAmbient = Color3.fromRGB(118, 96, 80), -- warm shade instead of flat grey
		EnvironmentDiffuseScale = 0.45, -- less blue sky light in shadows
		EnvironmentSpecularScale = 0.8, -- a bit of sheen on smooth surfaces
	},
	Atmosphere = { Density = 0.52, Haze = 2.8, Glare = 1.1, Offset = 0.2, Color = Color3.fromRGB(206, 170, 132), Decay = Color3.fromRGB(150, 104, 74) },
	Grade = { Contrast = 0.2, Saturation = -0.1, Brightness = 0, TintColor = Color3.fromRGB(255, 234, 214) },
	Bloom = { Intensity = 0.6, Size = 36, Threshold = 1.2 }, -- adds to the server's soft bloom
	-- autofocus depth of field: focuses on whatever is under the crosshair, blurs far away
	DepthOfField = { FarIntensity = 0.12, AimFarIntensity = 0.3, MaxFocus = 300 },
	Vignette = 0.5, -- edge darkness 0..1 (0 = off)
}

GameConfig.Data = {
	StoreName = "SAMZ_Profile_v1", -- change the suffix to wipe all saves
	StudioStartingGems = 2500, -- new profiles in Studio get this many Gems for testing (0 in live servers)
}

return GameConfig
