-- MatchService: the game loop. Owns who is in the run, spawning characters, waves, and results.
--
--   Lobby  --(countdown; shortened when everyone is Ready)-->  run starts, players go to the arena
--   loop:  Break (countdown, dead teammates respawn) -> Wave (spawn N zombies, wait until cleared)
--   ends when every participant is dead or gone -> Results (Gems awarded, saved) -> Lobby
--
-- Writes GameState attributes (Phase, Wave, Timer, ZombiesLeft, PlayerCount, ReadyCount)
-- and player attribute InRun. Wave sizes/timings come from GameConfig.Waves.
--
-- Public:
--   MatchService:IsInRun(player), :IsAliveInRun(player), :GetRunPlayers()
--   MatchService:SpawnInLobby(player), :SpawnInArena(player, cframe?)
--   MatchService:ReviveDead(cframe)       respawn every dead participant near cframe

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Zombies = require(Shared.Config.Zombies)
local Remotes = require(Shared.Remotes)
local GameState = require(Shared.GameState)

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
			if player:GetAttribute("Ready") then
				ready += 1
			end
		end
		local enough = #players >= cfg.MinPlayers
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

function MatchService:_playWave(wave, bossAppearance)
	local cfg = GameConfig.Waves
	local ZombieService = Services.ZombieService
	local MapService = Services.MapService
	local players = #self:GetRunPlayers()
	local total = math.floor((cfg.BaseCount + cfg.CountPerWave * (wave - 1)) * (1 + cfg.ExtraPlayerMultiplier * math.max(0, players - 1)))
	local healthMult = 1 + cfg.HealthScalePerWave * (wave - 1)
	local interval = math.max(cfg.MinSpawnInterval, cfg.SpawnInterval - cfg.SpawnIntervalDecay * (wave - 1))

	if bossAppearance then
		local bossId = Zombies.BossOrder[((bossAppearance - 1) % #Zombies.BossOrder) + 1]
		ZombieService:Spawn(bossId, MapService:GetZombieSpawnPosition(), 1 + cfg.BossHealthScalePerAppearance * (bossAppearance - 1))
	end

	local toSpawn = total
	local nextSpawn = 0
	while true do
		if not self:_anyAlive() then
			return false
		end
		local now = os.clock()
		if toSpawn > 0 and now >= nextSpawn and ZombieService:GetAliveCount() < cfg.MaxAlive then
			ZombieService:Spawn(ZombieService:PickType(wave), MapService:GetZombieSpawnPosition(), healthMult)
			toSpawn -= 1
			nextSpawn = now + interval
		end
		local left = toSpawn + ZombieService:GetAliveCount()
		GameState:SetAttribute("ZombiesLeft", left)
		if left == 0 then
			return true
		end
		task.wait(0.05)
	end
end

function MatchService:_runMatch()
	local participants = self:_lobbyPlayers()
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
		task.spawn(self.SpawnInArena, self, player, Services.MapService:GetArenaSpawnCFrame(i))
	end

	local cfg = GameConfig.Waves
	local wave, wavesCleared, bossAppearances = 0, 0, 0
	while next(inRun) ~= nil do
		if self.DebugNextWave then -- set by DebugService:SkipToWave
			wave = self.DebugNextWave - 1
			self.DebugNextWave = nil
		end
		wave += 1
		GameState:SetAttribute("Wave", wave)
		GameState:SetAttribute("ZombiesLeft", 0)
		self:_countdown("Break", if wave == 1 then cfg.FirstBreakTime else cfg.BreakTime)
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
		local isBoss = cfg.BossEvery > 0 and wave % cfg.BossEvery == 0
		if isBoss then
			bossAppearances += 1
		end
		GameState:SetAttribute("Phase", "Wave")
		if not self:_playWave(wave, if isBoss then bossAppearances else nil) then
			break
		end
		wavesCleared = wave
	end
	self:_endRun(wave, wavesCleared)
end

function MatchService:_endRun(wave, wavesCleared)
	GameState:SetAttribute("Phase", "Results")
	Services.ZombieService:ClearAll()
	Services.AbilityService:Cleanup()
	local econ = GameConfig.Economy
	for player in inRun do
		if player.Parent then
			local kills = player:GetAttribute("Kills") or 0
			local gems = math.floor(wavesCleared * econ.GemsPerWaveCleared + kills * econ.GemsPerKill)
			local newBest = Services.DataService:RecordRun(player, wave, kills, gems)
			Remotes.RunResults:FireClient(player, { Wave = wave, WavesCleared = wavesCleared, Kills = kills, Gems = gems, NewBest = newBest })
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
