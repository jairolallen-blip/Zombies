-- MapService: answers "where do things spawn" for our map and applies its sunset atmosphere.
-- The map itself is baked into Workspace.<OurMap.Folder> in Edit mode by Server/Map/OurLobby and
-- Server/Map/OurCity (vault: Lobby.md, City Map.md); this only reads the marker parts:
--   Lobby: "LobbySpawn" parts + the helipad "Pad"      Arena: "PlayerSpawn" + "ZombieSpawn" parts
--
-- Public:
--   MapService.GroundY
--   MapService:GetLobbySpawnCFrame(), :GetArenaSpawnCFrame(index?)
--   MapService:GetZombieSpawnPosition(usePads?)  random open street spot around a living player
--     (GameConfig.Waves.SpawnMin/MaxDistance, vault: Spawning.md); usePads = a fixed ZombieSpawn pad
--   MapService:GetZombiePads() -> {Vector3}
--   MapService:GetNavBounds() -> center, halfSize, lattice   (area the zombie NavGrid scans)
--   MapService:GetDeployPoints() -> from, to   (helipad -> arena spawns, ground level)
--   MapService:ApplyAtmosphere()

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.GameConfig)
local NavGrid = require(script.Parent.Parent:WaitForChild("Map"):WaitForChild("NavGrid"))
local OUR = GameConfig.OurMap
local Services

local MapService = {}
MapService.GroundY = 1

local lobbySpawns, playerSpawns, zombiePads = {}, {}, {}
local helipad

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
	helipad = collect(lobby, "Pad")[1]
	playerSpawns = collect(arena, "PlayerSpawn")
	for _, pad in collect(arena, "ZombieSpawn") do
		table.insert(zombiePads, pad.Position)
	end
	self:ApplyAtmosphere()
end

-- Warm, hazy sunset (GameConfig.OurMap.Atmosphere). Runtime only; Edit-mode Lighting is untouched.
function MapService:ApplyAtmosphere()
	local a = OUR.Atmosphere
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
	return CFrame.new(pad.Position + offset) * pad.CFrame.Rotation
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
	return Vector3.new(helipad.Position.X, self.GroundY, helipad.Position.Z), Vector3.new(to.X, self.GroundY, to.Z)
end

return MapService
