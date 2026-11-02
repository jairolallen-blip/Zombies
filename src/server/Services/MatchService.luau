-- MatchService: the game loop. Owns who is in the run, spawning characters, waves, and results.
--
--   Lobby  --(countdown while someone is on the helipad; shortened when everyone is)-->  run starts
--   Deploy (helicopter cutscene, players parachute onto the arena spawns; see _deploy)
--   loop:  Break (countdown, dead teammates respawn) -> Wave (spawn N zombies, wait until cleared)
--   the last wave (GameConfig.Waves.TotalWaves) is the boss wave; clearing it wins the run
--   ends on victory or when every participant is dead or gone -> Results (Gems, saved) -> Lobby
-- The commander comments on each step over Remotes.Radio (lines in Shared/Config/Radio).
--
-- Writes GameState attributes (Phase, Wave, Timer, ZombiesLeft, PlayerCount, ReadyCount)
-- and player attribute InRun. Wave sizes/timings come from GameConfig.Waves.
--
-- Public:
--   MatchService:IsInRun(player), :IsAliveInRun(player), :GetRunPlayers()
--   MatchService:SpawnInLobby(player), :SpawnInArena(player, cframe?)
--   MatchService:ReviveDead(cframe)       respawn every dead participant near cframe

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Zombies = require(Shared.Config.Zombies)
local Remotes = require(Shared.Remotes)
local GameState = require(Shared.GameState)
local Radio = require(Shared.Config.Radio)

local MatchService = {}
local Services
local inRun = {} -- [Player] = true for participants of the current run
local dead = {} -- [Player] = true if their character died during this run
local spawnToken = {} -- [Player] = latest spawn request (ignore stale Died handlers)

function MatchService:Init(services)
	Services = services
	Players.PlayerRemoving:Connect(function(player)
		inRun[player] = nil
		dead[player] = nil
		spawnToken[player] = nil
	end)
	Services.ZombieService.BossEnraged:Connect(function()
		self:_radio("BossEnraged")
	end)
	Services.ZombieService.Killed:Connect(function(z)
		if z.Def.Boss then
			self:_radio("BossDown")
		end
	end)
	Services.DataService.ProfileLoaded:Connect(function(player)
		if not inRun[player] then
			self:SpawnInLobby(player)
		end
	end)
end

function MatchService:Start()
	while true do
		self:_lobbyPhase()
		self:_runMatch()
	end
end

-- Queries ---------------------------------------------------------------------------------------

function MatchService:IsInRun(player)
	return inRun[player] == true
end

function MatchService:IsAliveInRun(player)
	if not inRun[player] then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") ~= nil
end

function MatchService:GetRunPlayers()
	local list = {}
	for player in inRun do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

function MatchService:_anyAlive()
	for player in inRun do
		if self:IsAliveInRun(player) then
			return true
		end
	end
	return false
end

-- Spawning --------------------------------------------------------------------------------------

function MatchService:_spawn(player, cframe)
	local token = {}
	spawnToken[player] = token
	local ok, err = pcall(player.LoadCharacter, player)
	if not ok or not player.Parent then
		warn("[MatchService] LoadCharacter failed:", err)
		return nil, token
	end
	local character = player.Character
	local root = character and character:WaitForChild("HumanoidRootPart", 5)
	if not root then
		return nil, token
	end
	character:PivotTo(cframe)
	local function setGroup(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = "Players"
		end
	end
	for _, d in character:GetDescendants() do
		setGroup(d)
	end
	character.DescendantAdded:Connect(setGroup)
	return character, token
end

function MatchService:SpawnInLobby(player)
	player:SetAttribute("InRun", false)
	local character, token = self:_spawn(player, Services.MapService:GetLobbySpawnCFrame())
	if not character then
		return
	end
	character:FindFirstChildOfClass("Humanoid").Died:Connect(function()
		task.wait(3)
		if spawnToken[player] == token and not inRun[player] and player.Parent then
			self:SpawnInLobby(player)
		end
	end)
end

function MatchService:SpawnInArena(player, cframe)
	dead[player] = nil
	local character = self:_spawn(player, cframe or Services.MapService:GetArenaSpawnCFrame())
	if not character then
		return
	end
	Services.EconomyService:ApplyCharacterStats(player)
	Services.CombatService:EquipLoadout(player)
	character:FindFirstChildOfClass("Humanoid").Died:Connect(function()
		if inRun[player] then
			dead[player] = true
			Remotes.Notify:FireClient(player, "You're down! You'll respawn next wave if your team survives.", "Danger")
		end
	end)
end

-- Commander line to every run participant
function MatchService:_radio(event, vars)
	local text = Radio.Pick(event, vars)
	if not text then
		return
	end
	for player in inRun do
		if player.Parent then
			Remotes.Radio:FireClient(player, text, event)
		end
	end
end

-- Slow parachute descent: a world-space LinearVelocity on the root + a canopy, removed on landing.
function MatchService:_parachute(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "ParachuteAttachment"
	attachment.Parent = root
	local drag = Instance.new("LinearVelocity")
	drag.Name = "Parachute"
	drag.Attachment0 = attachment
	drag.RelativeTo = Enum.ActuatorRelativeTo.World
	drag.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	drag.LineDirection = Vector3.yAxis
	drag.LineVelocity = -GameConfig.Deploy.FallSpeed
	drag.MaxForce = 1e7
	drag.Parent = root
	local canopy = Instance.new("Part")
	canopy.Name = "ParachuteCanopy"
	canopy.Shape = Enum.PartType.Ball
	canopy.Size = Vector3.new(10, 3, 10)
	canopy.Color = Color3.fromRGB(96, 108, 70)
	canopy.Material = Enum.Material.Fabric
	canopy.CanCollide = false
	canopy.CanQuery = false
	canopy.CanTouch = false
	canopy.Massless = true
	canopy.CFrame = root.CFrame * CFrame.new(0, 8, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = canopy
	weld.Parent = canopy
	canopy.Parent = character
	root.Anchored = false

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local deadline = os.clock() + GameConfig.Deploy.DropHeight / GameConfig.Deploy.FallSpeed + 4
	while root.Parent and os.clock() < deadline do
		if workspace:Raycast(root.Position, Vector3.new(0, -4.5, 0), params) then
			break
		end
		task.wait(0.05)
	end
	drag:Destroy()
	attachment:Destroy()
	canopy:Destroy()
end

-- Run start: helicopter cutscene (client CutsceneController reads the Deploy* GameState attributes),
-- players wait anchored above their spawn pads, then parachute down together.
function MatchService:_deploy(participants)
	local cfg = GameConfig.Deploy
	if not cfg.Enabled then
		for i, player in participants do
			task.spawn(self.SpawnInArena, self, player, Services.MapService:GetArenaSpawnCFrame(i))
		end
		return
	end
	local path = {}
	for _, p in Services.MapService:GetDeployFlight() do
		table.insert(path, { math.round(p.X), math.round(p.Y), math.round(p.Z) })
	end
	GameState:SetAttribute("DeployPath", HttpService:JSONEncode(path))
	GameState:SetAttribute("DeployDuration", cfg.FlightTime)
	GameState:SetAttribute("DeployStart", workspace:GetServerTimeNow())
	GameState:SetAttribute("Phase", "Deploy")
	for i, player in participants do
		player:SetAttribute("Deploying", true)
		task.spawn(function()
			local cframe = Services.MapService:GetArenaSpawnCFrame(i) + Vector3.new(0, cfg.DropHeight, 0)
			self:SpawnInArena(player, cframe)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				root.Anchored = true
				root.CFrame = cframe
			end
		end)
	end
	self:_radio("Deploy")
	task.wait(cfg.FlightTime - 1.5)
	self:_radio("Drop")
	task.wait(1.5)
	for _, player in participants do
		if player.Parent then
			task.spawn(self._parachute, self, player)
		end
	end
	task.wait(cfg.DropHeight / cfg.FallSpeed + 0.6)
	for _, player in participants do
		player:SetAttribute("Deploying", false)
	end
	self:_radio("Landed")
end

function MatchService:ReviveDead(cframe)
	for player in inRun do
		if dead[player] and player.Parent then
			local offset = CFrame.new(math.random(-5, 5), 0, math.random(-5, 5))
			task.spawn(self.SpawnInArena, self, player, cframe * offset)
		end
	end
end

-- Phases ----------------------------------------------------------------------------------------

function MatchService:_lobbyPlayers()
	local list = {}
	for _, player in Players:GetPlayers() do
		if Services.DataService:Get(player) and player.Character then
			table.insert(list, player)
		end
	end
	return list
end

function MatchService:_lobbyPhase()
	local cfg = GameConfig.Lobby
	GameState:SetAttribute("Phase", "Lobby")
	GameState:SetAttribute("Wave", 0)
	GameState:SetAttribute("ZombiesLeft", 0)
	local timer = cfg.IntermissionTime
	while true do
		local players = self:_lobbyPlayers()
		local ready = 0
		for _, player in players do
			local onPad = Services.MapService:IsOnHelipad(player)
			player:SetAttribute("Ready", onPad)
			if onPad then
				ready += 1
			end
		end
		local enough = ready >= cfg.MinPlayers
		if not enough then
			timer = cfg.IntermissionTime
		elseif ready == #players then
			timer = math.min(timer, cfg.AllReadyTime)
		end
		GameState:SetAttribute("PlayerCount", #players)
		GameState:SetAttribute("ReadyCount", ready)
		GameState:SetAttribute("Timer", timer)
		if enough and timer <= 0 then
			return
		end
		task.wait(1)
		if enough then
			timer -= 1
		end
	end
end

function MatchService:_countdown(phase, seconds)
	GameState:SetAttribute("Phase", phase)
	for t = seconds, 1, -1 do
		GameState:SetAttribute("Timer", t)
		task.wait(1)
		if next(inRun) == nil then
			return
		end
	end
	GameState:SetAttribute("Timer", 0)
end

function MatchService:_playWave(wave, isBoss)
	local cfg = GameConfig.Waves
	local ZombieService = Services.ZombieService
	local MapService = Services.MapService
	local players = #self:GetRunPlayers()
	local playerMult = 1 + cfg.ExtraPlayerMultiplier * math.max(0, players - 1)
	local total = math.floor((cfg.BaseCount + cfg.CountPerWave * (wave - 1)) * playerMult * (if isBoss then cfg.BossWaveHordeMult else 1))
	local healthMult = 1 + cfg.HealthScalePerWave * (wave - 1)
	local burst = 1 + math.floor(wave / cfg.BurstEvery) -- zombies per spawn group (vault: Spawning.md)
	local spawnWindow = cfg.SpawnSeconds + cfg.SpawnSecondsPerWave * wave
	local interval = math.clamp(spawnWindow * burst / math.max(total, 1), cfg.MinSpawnInterval, cfg.SpawnInterval)

	if isBoss then
		ZombieService:SpawnWarned(Zombies.BossOrder[1], MapService:GetZombieSpawnPosition(true), playerMult)
	end

	local toSpawn = total
	local nextSpawn = 0
	while true do
		if not self:_anyAlive() then
			return false
		end
		local now = os.clock()
		local onField = ZombieService:GetAliveCount() + ZombieService:GetPendingCount()
		if toSpawn > 0 and now >= nextSpawn and onField < cfg.MaxAlive then
			for _ = 1, math.min(burst, toSpawn, cfg.MaxAlive - onField) do
				ZombieService:SpawnWarned(ZombieService:PickType(wave), MapService:GetZombieSpawnPosition(), healthMult)
				toSpawn -= 1
			end
			nextSpawn = now + interval
		end
		local left = toSpawn + ZombieService:GetAliveCount() + ZombieService:GetPendingCount()
		GameState:SetAttribute("ZombiesLeft", left)
		if left == 0 then
			return true
		end
		task.wait(0.05)
	end
end

function MatchService:_runMatch()
	local participants = {}
	for _, player in self:_lobbyPlayers() do
		if player:GetAttribute("Ready") then -- on the helipad
			table.insert(participants, player)
		end
	end
	if #participants == 0 then
		return
	end
	table.clear(inRun)
	table.clear(dead)
	for i, player in participants do
		inRun[player] = true
		player:SetAttribute("Ready", false)
		player:SetAttribute("InRun", true)
		Services.EconomyService:ResetRun(player)
	end
	self:_deploy(participants)

	local cfg = GameConfig.Waves
	local wave, wavesCleared = 0, 0
	while next(inRun) ~= nil and wavesCleared < cfg.TotalWaves do
		if self.DebugNextWave then -- set by DebugService:SkipToWave
			wave = self.DebugNextWave - 1
			self.DebugNextWave = nil
		end
		wave += 1
		GameState:SetAttribute("Wave", wave)
		GameState:SetAttribute("ZombiesLeft", 0)
		local breakTime = if wave == 1 then cfg.FirstBreakTime else cfg.BreakTime
		if wave == 1 and breakTime > 4 then
			task.delay(breakTime - 3.5, function()
				if next(inRun) ~= nil then
					self:_radio("Incoming")
				end
			end)
		end
		self:_countdown("Break", breakTime)
		if next(inRun) == nil then
			break
		end
		if GameConfig.Match.RespawnDeadOnWaveStart then
			for player in inRun do
				if player.Parent and not self:IsAliveInRun(player) then
					task.spawn(self.SpawnInArena, self, player)
				end
			end
			task.wait(0.5)
		end
		local isBoss = wave >= cfg.TotalWaves
		GameState:SetAttribute("Phase", "Wave")
		self:_radio(if isBoss then "BossIncoming" elseif wave == 1 then "FirstWave" else "WaveStart", { wave = wave })
		if not self:_playWave(wave, isBoss) then
			break
		end
		wavesCleared = wave
		Services.EconomyService:OnWaveCleared(wave)
		if wavesCleared < cfg.TotalWaves then
			self:_radio("WaveCleared", { wave = wave })
		end
	end
	self:_endRun(wave, wavesCleared, wavesCleared >= cfg.TotalWaves)
end

function MatchService:_endRun(wave, wavesCleared, victory)
	self:_radio(if victory then "Victory" else "Overrun")
	GameState:SetAttribute("RunWon", victory == true)
	GameState:SetAttribute("Phase", "Results")
	Services.ZombieService:ClearAll()
	Services.AbilityService:Cleanup()
	local econ = GameConfig.Economy
	for player in inRun do
		if player.Parent then
			local kills = player:GetAttribute("Kills") or 0
			local gems = math.floor(wavesCleared * econ.GemsPerWaveCleared + kills * econ.GemsPerKill + (if victory then econ.VictoryGems else 0))
			local newBest = Services.DataService:RecordRun(player, wave, kills, gems)
			Remotes.RunResults:FireClient(player, { Wave = wave, WavesCleared = wavesCleared, Kills = kills, Gems = gems, NewBest = newBest, Victory = victory })
		end
	end
	task.wait(GameConfig.Match.ResultsTime)
	local returning = {}
	for player in inRun do
		table.insert(returning, player)
	end
	table.clear(inRun)
	table.clear(dead)
	for _, player in returning do
		if player.Parent then
			task.spawn(self.SpawnInLobby, self, player)
		end
	end
	task.wait(1)
end

return MatchService
