-- MapService: answers "where do things spawn" for our map and applies its sunset atmosphere.
-- The map itself is baked into Workspace.<OurMap.Folder> in Edit mode by Server/Map/OurLobby and
-- Server/Map/OurCity (vault: Lobby.md, City Map.md); this only reads the marker parts:
--   Lobby: "LobbySpawn" parts + the Flight Line pads ("Helipad" models with PadId, part "Pad")
--   Arena: "PlayerSpawn" + "ZombieSpawn" parts
--
-- Public:
--   MapService.GroundY
--   MapService:GetLobbySpawnCFrame(), :GetArenaSpawnCFrame(index?)
--   MapService:GetZombieSpawnPosition(usePads?)  random open street spot around a living player
--     (GameConfig.Waves.SpawnMin/MaxDistance, vault: Spawning.md); usePads = a fixed ZombieSpawn pad
--   MapService:GetZombiePads() -> {Vector3}
--   MapService:GetBossSpawn() -> Vector3   the "BossSpawn" marker (open ground facing the square)
--   MapService:GetNavBounds() -> center, halfSize, lattice   (area the zombie NavGrid scans)
--   MapService:GetDeployPoints() -> from, to   (pad 1 -> arena spawns, ground level)
--   MapService:GetPads() -> {[PadId] = Pad part}   Flight Line pads (QueueService)
--   MapService:GetPadAt(player) -> PadId?      the pad the player stands on (its take-off zone)
--   MapService:GetDeployFlight() -> {Vector3}   helicopter path, ocean -> above the square
--   MapService:ApplyAtmosphere(condition?)   sunset, or a run's weather (Config/Conditions)

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.GameConfig)
local NavGrid = require(script.Parent.Parent:WaitForChild("Map"):WaitForChild("NavGrid"))
local OUR = GameConfig.OurMap
local Services

local MapService = {}
MapService.GroundY = 1

local lobbySpawns, playerSpawns, zombiePads = {}, {}, {}
local bossSpawn
local pads = {} -- [PadId] = Pad part (a cylinder: Size.Y = diameter)

local function collect(folder, name)
	local found = {}
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") and d.Name == name then
			table.insert(found, d)
		end
	end
	assert(#found > 0, "[MapService] no '" .. name .. "' parts in " .. folder:GetFullName())
	return found
end

function MapService:Init(services)
	Services = services
	local root = workspace:FindFirstChild(OUR.Folder)
	local lobby = root and root:FindFirstChild("Lobby")
	local arena = root and root:FindFirstChild("Arena")
	assert(lobby and arena, "[MapService] Workspace." .. OUR.Folder .. " needs Lobby + Arena (rebuild with Server/Map/OurLobby and OurCity)")
	lobbySpawns = collect(lobby, "LobbySpawn")
	for _, pad in collect(lobby, "Pad") do
		pads[pad.Parent:GetAttribute("PadId") or 1] = pad
	end
	playerSpawns = collect(arena, "PlayerSpawn")
	for _, pad in collect(arena, "ZombieSpawn") do
		table.insert(zombiePads, pad.Position)
	end
	bossSpawn = collect(arena, "BossSpawn")[1].Position
	self:ApplyAtmosphere()
	if not services.MatchService.IsMatchServer and not RunService:IsStudio() then
		arena:Destroy() -- a live lobby server never runs a match (squads get their own server)
	end
end

-- Warm, hazy sunset (GameConfig.OurMap.Atmosphere). Runtime only; Edit-mode Lighting is untouched.
-- condition (Config/Conditions entry, optional): its Atmosphere fields replace the sunset ones
function MapService:ApplyAtmosphere(condition)
	local a = setmetatable(table.clone(condition and condition.Atmosphere or {}), { __index = OUR.Atmosphere })
	Lighting.ClockTime = a.ClockTime
	Lighting.Brightness = a.Brightness
	Lighting.Ambient = a.Ambient
	Lighting.OutdoorAmbient = a.OutdoorAmbient
	Lighting.FogEnd = 100000
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("ColorCorrectionEffect") or child:IsA("Sky") or child:IsA("BloomEffect") or child:IsA("SunRaysEffect") then
			child:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = a.Density
	atmosphere.Offset = 0.1
	atmosphere.Color = a.AtmosphereColor
	atmosphere.Decay = a.HazeColor
	atmosphere.Glare = 0.6
	atmosphere.Haze = a.Haze
	atmosphere.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.TintColor = a.TintColor
	grade.Saturation = a.Saturation
	grade.Contrast = a.Contrast
	grade.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 30
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.08
	rays.Spread = 0.6
	rays.Parent = Lighting
end

function MapService:GetLobbySpawnCFrame()
	local pad = lobbySpawns[math.random(1, #lobbySpawns)]
	local offset = Vector3.new(math.random(-3, 3), pad.Size.Y / 2 + 3, math.random(-3, 3))
	local pos = pad.Position + offset
	local gate = GameConfig.OurMap.LobbyCenter + Vector3.new(0, 0, -62) -- the Flight Line gate (Map/FlightLine NEAR)
	return CFrame.lookAt(pos, Vector3.new(gate.X, pos.Y, gate.Z)) -- face it, so new players see where to go
end

function MapService:GetArenaSpawnCFrame(index)
	local pad = playerSpawns[((index or math.random(1, #playerSpawns)) - 1) % #playerSpawns + 1]
	return CFrame.new(pad.Position + Vector3.new(0, pad.Size.Y / 2 + 3, 0)) * pad.CFrame.Rotation
end

-- open street (walkable nav cells around it too) and at least minDist from every player
local function spawnSpotOK(pos, players, minDist)
	for _, d in { Vector3.zero, Vector3.new(3, 0, 0), Vector3.new(-3, 0, 0), Vector3.new(0, 0, 3), Vector3.new(0, 0, -3) } do
		if not NavGrid.IsWalkable(pos + d) then
			return false
		end
	end
	for _, p in players do
		if (Vector3.new(p.X, pos.Y, p.Z) - pos).Magnitude < minDist then
			return false
		end
	end
	return true
end

function MapService:GetZombieSpawnPosition(usePads)
	if not usePads then
		local players = {}
		for _, player in Services.MatchService:GetRunPlayers() do
			if Services.MatchService:IsAliveInRun(player) then
				table.insert(players, player.Character.HumanoidRootPart.Position)
			end
		end
		local W = GameConfig.Waves
		for _ = 1, if #players > 0 then 40 else 0 do
			local around = players[math.random(1, #players)]
			local angle = math.random() * math.pi * 2
			local dist = W.SpawnMinDistance + math.random() * (W.SpawnMaxDistance - W.SpawnMinDistance)
			local pos = Vector3.new(around.X + math.cos(angle) * dist, self.GroundY, around.Z + math.sin(angle) * dist)
			if spawnSpotOK(pos, players, W.SpawnMinDistance) then
				return pos
			end
		end
	end
	local pad = zombiePads[math.random(1, #zombiePads)]
	return Vector3.new(pad.X + math.random(-4, 4), self.GroundY, pad.Z + math.random(-4, 4))
end

function MapService:GetZombiePads()
	return zombiePads
end

function MapService:GetBossSpawn()
	return bossSpawn
end

function MapService:GetPads()
	return pads
end

function MapService:GetPadAt(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	for id, pad in pads do
		local offset = root.Position - pad.Position
		if Vector3.new(offset.X, 0, offset.Z).Magnitude < pad.Size.Y / 2 and math.abs(offset.Y) < 10 then
			return id
		end
	end
	return nil
end

-- Deploy flight for CutsceneController: from out over the ocean north of the city to the hover point
-- above the square. Built here because the server has every building; with streaming on, a client
-- may not. Each sample flies at max(planned altitude, highest roof under the rotor + Clearance), and
-- that floor is slope-limited both ways so the helicopter climbs early and never dips into a block.
function MapService:GetDeployFlight()
	local cfg = GameConfig.Deploy
	local _, to = self:GetDeployPoints()
	local from = to + cfg.OceanStart
	local bend = to + cfg.FinalApproach
	local hover = cfg.DropHeight + 12
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local ignore = {}
	for _, d in workspace:FindFirstChild(OUR.Folder):GetDescendants() do
		if d:IsA("BasePart") and d.Transparency >= 0.95 then
			table.insert(ignore, d) -- invisible walls / markers
		end
	end
	for _, p in game:GetService("Players"):GetPlayers() do
		table.insert(ignore, p.Character)
	end
	params.FilterDescendantsInstances = ignore

	local function at(u)
		return from:Lerp(bend, u):Lerp(bend:Lerp(to, u), u) -- quadratic bezier
	end
	local n = cfg.PathSamples
	local points, floor = {}, {}
	for i = 0, n do
		local u = i / n
		local xz = at(u)
		local frame = CFrame.lookAt(xz, xz + (at(u + 0.01) - xz) * Vector3.new(1, 0, 1))
		local top = 0
		for _, dx in { -18, 0, 18 } do -- rotor span
			for _, dz in { -14, 0, 14 } do -- nose to tail
				local origin = (frame * CFrame.new(dx, 0, dz)).Position
				local hit = workspace:Raycast(Vector3.new(origin.X, 600, origin.Z), Vector3.new(0, -700, 0), params)
				top = math.max(top, if hit then hit.Position.Y else 0)
			end
		end
		-- planned altitude: skim the sea, climb over the coast, settle at the hover height
		local climb = math.clamp((u - 0.3) / 0.3, 0, 1)
		local planned = cfg.SeaAltitude + (cfg.CruiseHeight - cfg.SeaAltitude) * climb * climb * (3 - 2 * climb)
		planned += (hover - cfg.CruiseHeight) * math.clamp((u - 0.85) / 0.15, 0, 1)
		points[i + 1] = Vector3.new(xz.X, planned, xz.Z)
		floor[i + 1] = top + cfg.Clearance
	end
	local step = cfg.MaxClimbPerSample
	for i = #floor - 1, 1, -1 do
		floor[i] = math.max(floor[i], floor[i + 1] - step)
	end
	for i = 2, #floor do
		floor[i] = math.max(floor[i], floor[i - 1] - step)
	end
	for i, p in points do
		points[i] = Vector3.new(p.X, math.max(p.Y, floor[i]), p.Z)
	end
	return points
end

function MapService:GetNavBounds()
	local c, half = OUR.ArenaCenter, OUR.ArenaHalfSize
	return c, half, Vector3.new(c.X - half, 0, c.Z - half)
end

function MapService:GetDeployPoints()
	local sum = Vector3.zero
	for _, p in playerSpawns do
		sum += p.Position
	end
	local to = sum / #playerSpawns
	return Vector3.new(pads[1].Position.X, self.GroundY, pads[1].Position.Z), Vector3.new(to.X, self.GroundY, to.Z)
end

return MapService
