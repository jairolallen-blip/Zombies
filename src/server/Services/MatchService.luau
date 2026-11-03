-- MatchService: the game loop. Owns who is in the run, spawning characters, waves, and results.
--
-- Two kinds of server run this place (MatchService.IsMatchServer):
--   lobby server   the safehouse; squads queue on the Flight Line pads (QueueService). On a live server a
--                  squad that takes off is teleported to its own reserved server; in Studio (no
--                  teleports) QueueService calls :RunMatch here instead, one run at a time
--   match server   a reserved server holding one squad (or one first-time player's tutorial): waits for
--                  the squad to arrive, plays one run, then teleports everyone back to a lobby server
--
-- A run (:RunMatch(players, options); options = Difficulty, Map, Tutorial from the pad / teleport data):
--   Deploy (helicopter cutscene, players parachute onto the arena spawns; see _deploy)
--   loop:  Break (countdown, dead teammates respawn) -> Wave (spawn N zombies, wait until cleared)
--   the last wave (GameConfig.Waves.TotalWaves) is the boss wave; clearing it wins the run
--   (tutorial: Config/Tutorial: fewer waves, a weaker boss, its own Gems reward; TutorialService walks
--   the player through the mechanics)
--   (Nightmare: Config/Nightmare: tougher zombies, the Nightmare weather and radio, Gems only on a win;
--   played only when every participant has unlocked it)
--   ends on victory or when every participant is dead or gone -> Results (Gems, saved) -> lobby
-- The commander comments on each step over Remotes.Radio (lines in Shared/Config/Radio).
--
-- Writes GameState attributes (ServerKind, Phase, Wave, TotalWaves, Timer, ZombiesLeft, Difficulty,
-- MapId, Tutorial) and player attribute InRun. Wave sizes/timings come from GameConfig.Waves.
--
-- Public:
--   MatchService.IsMatchServer, .LocalRuns, :WaitForKind()   what kind of server this is (see below)
--   MatchService:RunMatch(players, options), :IsRunning()
--   MatchService:IsInRun(player), :IsAliveInRun(player), :GetRunPlayers()
--   MatchService:SpawnInLobby(player), :SpawnInArena(player, cframe?)
--   MatchService:ReviveDead(cframe)       respawn every dead participant near cframe

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Zombies = require(Shared.Config.Zombies)
local Conditions = require(Shared.Config.Conditions)
local Remotes = require(Shared.Remotes)
local GameState = require(Shared.GameState)
local Radio = require(Shared.Config.Radio)
local Tutorial = require(Shared.Config.Tutorial)
local Nightmare = require(Shared.Config.Nightmare)
local Levels = require(Shared.Config.Levels)

local MatchService = {}
-- a reserved server is one squad's private match (QueueService teleports squads into one)
-- A reserved server and a Team Test server look the same (a PrivateServerId, no owner), and Team Test's
-- server isn't IsStudio(). Only our squads arrive with teleport data (QueueService: Squad), so the first
-- player to join a private server settles it: squad data = a match server; none = Team Test, which plays
-- like Studio (lobby, runs on this server, no teleports). Public servers are lobbies straight away.
MatchService.Reserved = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
MatchService.IsMatchServer = false
MatchService.LocalRuns = RunService:IsStudio() -- runs play on this server instead of a squad's own (Studio, Team Test)
local kindSettled = not MatchService.Reserved
local kindEvent = Instance.new("BindableEvent")
local function settleKind(player)
	if kindSettled then
		return
	end
	kindSettled = true
	local data = player:GetJoinData().TeleportData
	MatchService.IsMatchServer = type(data) == "table" and data.Squad ~= nil
	MatchService.LocalRuns = MatchService.LocalRuns or not MatchService.IsMatchServer
	GameState:SetAttribute("ServerKind", if MatchService.IsMatchServer then "Match" else "Lobby")
	kindEvent:Fire()
end
if MatchService.Reserved then
	Players.PlayerAdded:Connect(settleKind) -- connected at require, before any service sees the player
	for _, player in Players:GetPlayers() do
		settleKind(player)
	end
end

-- Yields until the kind of server is known (only a private server waits, for its first player).
function MatchService:WaitForKind()
	if not kindSettled then
		kindEvent.Event:Wait()
	end
end
local Services
local inRun = {} -- [Player] = true for participants of the current run
local dead = {} -- [Player] = true if their character died during this run
local spawnToken = {} -- [Player] = latest spawn request (ignore stale Died handlers)
local running = false
local tutorial = false -- the current run is a first-time player's tutorial
local nightmare = false -- the current run is a Nightmare run
MatchService.ZombieDamageMult = 1 -- read by CombatService:DamagePlayer

local skipVotes = {} -- [Player] = true: voted to skip the cutscene that's playing

function MatchService:Init(services)
	Services = services
	Remotes.SkipCutscene.OnServerEvent:Connect(function(player)
		if GameState:GetAttribute("SkipOpen") and player:GetAttribute("CanSkip") and inRun[player] then
			skipVotes[player] = true
		end
	end)
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
			self._bossFell = z -- _playWave plays its death scene (def.Death)
			self:_radio("BossDown")
		end
	end)
	GameState:SetAttribute("ServerKind", if self.IsMatchServer then "Match" else "Lobby")
	Services.DataService.ProfileLoaded:Connect(function(player)
		if not self.IsMatchServer then
			self:SpawnInLobby(player)
		elseif running and not inRun[player] then
			-- a squad member whose teleport landed after the drop: straight into the fight
			inRun[player] = true
			player:SetAttribute("InRun", true)
			Services.EconomyService:ResetRun(player)
			self:SpawnInArena(player)
		end -- otherwise the squad is still arriving; _awaitSquad picks them up
	end)
end

function MatchService:Start()
	self:WaitForKind()
	if not self.IsMatchServer then
		return -- lobby server: QueueService runs the pads (and calls :RunMatch in Studio)
	end
	local players, options = self:_awaitSquad()
	self:RunMatch(players, options)
	Services.QueueService:ReturnToLobby(Players:GetPlayers(), { Results = self.LastResults }) -- the lobby's run report (WelcomeController)
end

-- Match server: the squad's teleport data (set by QueueService) lists who's coming. Start once all of
-- them have loaded, or GameConfig.Lobby.SquadWaitTime after the first one did.
function MatchService:_awaitSquad()
	local DataService = Services.DataService
	local function loaded()
		local list = {}
		for _, player in Players:GetPlayers() do
			if DataService:Get(player) then
				table.insert(list, player)
			end
		end
		return list
	end
	while #loaded() == 0 do
		task.wait(0.25)
	end
	local first = loaded()[1]
	local data = first:GetJoinData().TeleportData
	local options = if type(data) == "table" then data else {}
	local expected = if type(options.Squad) == "table" then #options.Squad else 1
	local deadline = os.clock() + GameConfig.Lobby.SquadWaitTime
	while #loaded() < expected and os.clock() < deadline do
		task.wait(0.25)
	end
	return loaded(), options
end

function MatchService:IsRunning()
	return running
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

-- Commander line to every run participant (a tutorial / Nightmare run uses its "Tutorial<event>" /
-- "Nightmare<event>" lines where there are any)
function MatchService:_radio(event, vars)
	local prefix = if tutorial then "Tutorial" elseif nightmare then "Nightmare" else ""
	local text = Radio.Pick(if Radio.Lines[prefix .. event] then prefix .. event else event, vars)
	if not text then
		return
	end
	for player in inRun do
		if player.Parent then
			Remotes.Radio:FireClient(player, text, event)
		end
	end
end

-- Ram-air canopy (an arc of fabric cells) and its lines, welded above the root
local function buildCanopy(root)
	local canopy = Instance.new("Model")
	canopy.Name = "ParachuteCanopy"
	local function add(size, cframe, color, material)
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = root.CFrame * cframe
		p.Color = color
		p.Material = material
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
		p.Parent = canopy
	end
	local radius, cells = 11, 7
	for i = 1, cells do
		local a = (i - (cells + 1) / 2) * 0.16
		local color = if i % 2 == 0 then Color3.fromRGB(170, 150, 105) else Color3.fromRGB(96, 108, 70)
		add(Vector3.new(1.9, 0.35, 7), CFrame.new(math.sin(a) * radius, math.cos(a) * radius, 0) * CFrame.Angles(0, 0, -a), color, Enum.Material.Fabric)
	end
	local edge = math.sin(0.48) * radius
	for _, x in { -1, 1 } do
		for _, z in { -3, 0, 3 } do
			local top = Vector3.new(x * edge, math.cos(0.48) * radius - 0.2, z)
			local shoulder = Vector3.new(x * 0.9, 1.4, 0)
			add(Vector3.new(0.05, 0.05, (top - shoulder).Magnitude), CFrame.lookAt((top + shoulder) / 2, top), Color3.fromRGB(205, 205, 195), Enum.Material.SmoothPlastic)
		end
	end
	canopy.Parent = root.Parent
	return canopy
end

-- The drop: a short freefall, then the canopy opens and a world-space LinearVelocity on the root holds
-- a slow descent (the sudden brake is the opening jolt); both removed on landing.
function MatchService:_parachute(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.Anchored = false
	task.wait(GameConfig.Deploy.FreefallTime)
	if not root.Parent then
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
	local canopy = buildCanopy(root)

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
	player:SetAttribute("Deploying", false) -- control back on touchdown, not when the slowest lands
end

-- Run start: helicopter cutscene (client CutsceneController reads the Deploy* GameState attributes),
-- players wait anchored above their spawn pads, then parachute down together.
-- Cutscene skips (Client/Controllers/SkipController): players who have finished a run before get the
-- CanSkip attribute and can vote while GameState SkipOpen is set. Once every player in the run has voted
-- (so a first-timer in the squad always sees it all), the cutscene ends early.
-- Waits up to `seconds`; returns true when skipped.
function MatchService:_skippableWait(seconds, kind)
	table.clear(skipVotes)
	GameState:SetAttribute("SkipOpen", kind)
	local ends = os.clock() + seconds
	local skipped = false
	while os.clock() < ends do
		local players, votes = self:GetRunPlayers(), 0
		for _, player in players do
			votes += if skipVotes[player] then 1 else 0
		end
		GameState:SetAttribute("SkipVotes", votes .. "/" .. #players)
		if #players > 0 and votes == #players then
			skipped = true
			Remotes.Effect:FireAllClients("CutsceneSkip", { Kind = kind })
			break
		end
		task.wait(0.1)
	end
	GameState:SetAttribute("SkipOpen", nil)
	return skipped
end

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
	if self:_skippableWait(cfg.FlightTime - 1.5, "Deploy") then
		-- jump the ride to the door: CutsceneController follows DeployStart
		GameState:SetAttribute("DeployStart", workspace:GetServerTimeNow() - (cfg.FlightTime - 1.5))
	end
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

-- Final boss entrance (Zombies def Intro timings). Every run player is anchored and gets the
-- BossIntro attribute, which hands their camera to Client/Controllers/BossController (CameraController
-- stands down). The boss claws out of the ground at the BossSpawn marker facing the square, roars
-- (radio "BossIncoming" + shockwave), then the fight starts. The horde spawns after this returns.
function MatchService:_bossIntro(playerMult)
	local typeId = if nightmare then Zombies.NightmareBoss else Zombies.BossOrder[1]
	local intro = Zombies.Types[typeId].Intro
	self._bossFell = nil
	local position = Services.MapService:GetBossSpawn()
	local players = self:GetRunPlayers()
	self:_freeze(players, true)
	Remotes.Effect:FireAllClients("BossIntro", { TypeId = typeId, Position = position, Time = intro.Time, RiseAt = intro.RiseAt, RiseTime = intro.RiseTime, RoarAt = intro.RoarAt })
	local skipped = self:_skippableWait(intro.RiseAt, "BossIntro")
	if intro.Style then -- it tears up out of the street (GroundFxController throws the dirt)
		Remotes.Effect:FireAllClients("Burrow", { Position = position, Radius = 12 })
	end
	local boss = Services.ZombieService:Spawn(typeId, position, playerMult, intro.RiseTime, GameConfig.OurMap.ArenaCenter)
	Services.ZombieService:Hold(boss, if skipped then intro.RiseTime else intro.Time - intro.RiseAt)
	skipped = skipped or self:_skippableWait(intro.RoarAt - intro.RiseAt, "BossIntro")
	self:_radio("BossIncoming")
	Remotes.Effect:FireAllClients("Shockwave", { Position = position, Radius = 45 })
	if not skipped then
		self:_skippableWait(intro.Time - intro.RoarAt, "BossIntro")
	end
	self:_freeze(players, false)
end

-- Cutscene hold: the BossIntro player attribute hands the camera to BossController (CameraController stands
-- down) and the character is anchored in place.
function MatchService:_freeze(players, on)
	for _, player in players do
		player:SetAttribute("BossIntro", if on then true else nil)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			root.Anchored = on
		end
	end
end

-- Nightmare boss death scene (def.Death; called by _playWave once it fell, after the horde collapsed): every
-- run player is frozen while BossController circles the swelling body; it bursts into spores at BurstAt,
-- the spores drift up and the sky fades from the Nightmare night to dawn before the Victory.
function MatchService:_bossDeath(z)
	local death = z.Def.Death
	local players = self:GetRunPlayers()
	local corpse = z.Corpse
	if corpse then
		for _, d in corpse:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
			elseif d:IsA("Constraint") then
				d:Destroy()
			end
		end
		corpse.Parent = Services.CombatService.EffectsFolder
	end
	self:_freeze(players, true)
	Remotes.Effect:FireAllClients("BossDeath", { Corpse = corpse, Position = z.Root.Position, Time = death.Time, BurstAt = death.BurstAt, Scale = z.Def.Scale or 1 })
	task.wait(death.BurstAt)
	Services.MapService:FadeFromDeploy({ Atmosphere = { ClockTime = death.Dawn } }, death.Time - death.BurstAt)
	task.wait(1)
	if corpse then
		corpse:Destroy()
	end
	task.wait(death.Time - death.BurstAt - 1)
	self:_freeze(players, false)
end

function MatchService:_playWave(wave, isBoss)
	local cfg = GameConfig.Waves
	local ZombieService = Services.ZombieService
	local MapService = Services.MapService
	local players = #self:GetRunPlayers()
	local playerMult = 1 + cfg.ExtraPlayerMultiplier * math.max(0, players - 1)
	local countMult = 1 + (if nightmare then Nightmare.ExtraPlayerMultiplier else cfg.ExtraPlayerMultiplier) * math.max(0, players - 1)
	local perWave = if nightmare then Nightmare.CountPerWave else cfg.CountPerWave
	local maxAlive = if nightmare then Nightmare.MaxAlive else cfg.MaxAlive
	local total = math.floor((cfg.BaseCount + perWave * (wave - 1)) * countMult * (if isBoss then cfg.BossWaveHordeMult else 1) * (if nightmare then Nightmare.CountMult else 1))
	local healthMult = (1 + cfg.HealthScalePerWave * (wave - 1)) * (if nightmare then Nightmare.HealthMult else 1)
	local burst = 1 + math.floor(wave / cfg.BurstEvery) -- zombies per spawn group (vault: Spawning.md)
	local spawnWindow = cfg.SpawnSeconds + cfg.SpawnSecondsPerWave * wave
	local interval = math.clamp(spawnWindow * burst / math.max(total, 1), cfg.MinSpawnInterval, cfg.SpawnInterval)

	if isBoss then
		self:_bossIntro(playerMult * (if tutorial then Tutorial.BossHealthMult elseif nightmare then Nightmare.BossHealthMult else 1)) -- the tutorial's "young" Titan
	end

	local toSpawn = total
	local nextSpawn = 0
	while true do
		if not self:_anyAlive() then
			return false
		end
		local now = os.clock()
		local onField = ZombieService:GetAliveCount() + ZombieService:GetPendingCount()
		if toSpawn > 0 and now >= nextSpawn and onField < maxAlive then
			local n = math.min(burst, toSpawn, maxAlive - onField)
			while n > 0 do
				local typeId = ZombieService:PickType(wave, nightmare)
				local position = MapService:GetZombieSpawnPosition(nil, Zombies.Types[typeId].SpawnMin)
				for k = 1, math.min(Zombies.Types[typeId].Pack or 1, n) do -- a pack (Skitters) rises together
					local spread = if k == 1 then Vector3.zero else Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))
					ZombieService:SpawnWarned(typeId, position + spread, healthMult)
					toSpawn -= 1
					n -= 1
				end
			end
			nextSpawn = now + interval
		end
		if isBoss and self._bossFell and self._bossFell.Def.Death then -- the Nightmare boss fell: its horde dies with it
			local fell = self._bossFell
			self._bossFell = nil
			ZombieService:Collapse()
			GameState:SetAttribute("ZombiesLeft", 0)
			self:_bossDeath(fell)
			return true
		end
		local left = toSpawn + ZombieService:GetAliveCount() + ZombieService:GetPendingCount()
		GameState:SetAttribute("ZombiesLeft", left)
		if left == 0 then
			return true
		end
		task.wait(0.05)
	end
end

-- Plays one run with these players. options (all optional, from the pad or the teleport data):
-- Difficulty, Map (validated against GameConfig.Lobby), Tutorial (honoured only for one player whose
-- profile hasn't done it, so it can't be farmed). Difficulty "Nightmare" needs every participant to
-- have unlocked it (Config/Nightmare), else the run is Normal. Returns when the run is over and Results are done.
function MatchService:RunMatch(participants, options)
	options = options or {}
	local cfg = GameConfig.Waves
	local lobbyCfg = GameConfig.Lobby
	local profile = #participants == 1 and Services.DataService:Get(participants[1])
	tutorial = options.Tutorial == true and profile and not profile.TutorialDone or false
	for _, player in participants do
		local p = Services.DataService:Get(player)
		player:SetAttribute("CanSkip", p ~= nil and p.RunsPlayed > 0) -- the cutscenes play in full the first time
	end
	local function pick(list, id)
		for _, entry in list do
			if entry.Id == id and not entry.Locked then
				return id
			end
		end
		return list[1].Id
	end
	nightmare = not tutorial and pick(lobbyCfg.Difficulties, options.Difficulty) == "Nightmare"
	for _, player in participants do
		local p = Services.DataService:Get(player)
		nightmare = nightmare and p ~= nil and Nightmare.Unlocked(p.Stats)
	end
	self.ZombieDamageMult = if nightmare then Nightmare.ZombieDamageMult else 1
	GameState:SetAttribute("Difficulty", if nightmare then "Nightmare" else "Normal")
	GameState:SetAttribute("MapId", pick(lobbyCfg.Maps, options.Map))
	GameState:SetAttribute("Tutorial", tutorial)
	-- this run's weather (Config/Conditions). The attribute goes first so PostFXController steps aside
	-- before the new lighting arrives.
	local condition = if tutorial then Conditions.List[1] elseif nightmare then Conditions.ById.Nightmare else Conditions.Pick()
	GameState:SetAttribute("Condition", condition.Id)
	task.delay(0.5, Services.MapService.ApplyAtmosphere, Services.MapService, condition, true)
	if condition ~= Conditions.List[1] then -- only announce weather that isn't the usual sunset
		for _, player in participants do
			Remotes.Notify:FireClient(player, "CONDITIONS: " .. condition.Name .. ". " .. condition.Desc, "Info")
		end
	end
	if tutorial then
		task.spawn(Services.TutorialService.Run, Services.TutorialService, participants[1])
	end
	local totalWaves = if tutorial then Tutorial.Waves elseif nightmare then Nightmare.TotalWaves else cfg.TotalWaves
	GameState:SetAttribute("TotalWaves", totalWaves)

	running = true
	table.clear(inRun)
	table.clear(dead)
	for _, player in participants do
		inRun[player] = true
		player:SetAttribute("InRun", true)
		Services.EconomyService:ResetRun(player)
	end
	self:_deploy(participants)
	if condition.Deploy then
		Services.MapService:FadeFromDeploy(condition, 5) -- the city goes dark once you're on the ground
	end

	local wave, wavesCleared = 0, 0
	while next(inRun) ~= nil and wavesCleared < totalWaves do
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
		local isBoss = wave >= totalWaves
		GameState:SetAttribute("Phase", "Wave")
		if not isBoss then -- the boss's radio line comes with its roar (_bossIntro)
			self:_radio(if wave == 1 then "FirstWave" else "WaveStart", { wave = wave })
		end
		if not self:_playWave(wave, isBoss) then
			break
		end
		wavesCleared = wave
		Services.EconomyService:OnWaveCleared(wave)
		if wavesCleared < totalWaves then
			self:_radio("WaveCleared", { wave = wave })
		end
	end
	self:_endRun(wave, wavesCleared, wavesCleared >= totalWaves)
	running, tutorial, nightmare = false, false, false
	self.ZombieDamageMult = 1
	GameState:SetAttribute("Tutorial", false)
	GameState:SetAttribute("Phase", "Lobby")
	GameState:SetAttribute("Wave", 0)
	GameState:SetAttribute("ZombiesLeft", 0)
end

function MatchService:_endRun(wave, wavesCleared, victory)
	self.LastResults = {} -- [tostring(UserId)] = this run's results, carried back to the lobby server (Start)
	self:_radio(if victory then "Victory" else "Overrun")
	GameState:SetAttribute("RunWon", victory == true)
	GameState:SetAttribute("Phase", "Results")
	Services.MapService:ApplyAtmosphere() -- back to sunset; the attribute clears after it so PostFX regrades it
	task.delay(0.5, GameState.SetAttribute, GameState, "Condition", nil)
	Services.ZombieService:ClearAll()
	Services.AbilityService:Cleanup()
	local econ = GameConfig.Economy
	for player in inRun do
		if player.Parent then
			local kills = player:GetAttribute("Kills") or 0
			local gems = if tutorial then Tutorial.RewardGems else math.floor(wavesCleared * econ.GemsPerWaveCleared + kills * econ.GemsPerKill + (if victory then econ.VictoryGems else 0))
			if nightmare then
				gems = if victory then math.floor(gems * Nightmare.GemsMult) else 0 -- Nightmare pays survivors only
			end
			if not tutorial and player:GetAttribute("Pass_DoubleGems") then
				gems *= 2 -- 2x GEMS game pass (StoreService)
			end
			local DataService = Services.DataService
			if tutorial then
				DataService:Get(player).TutorialDone = true -- even on a loss: never send them through it twice
				DataService:Funnel(player, 10, "Finished the tutorial")
			else
				DataService:Funnel(player, 12, "Finished a squad run")
				DataService:LogWave(player, wave)
			end
			local xp = Levels.RunXP(kills, wavesCleared, victory and not tutorial, nightmare)
			local xpBefore = DataService:AddXP(player, xp) -- saved with the run below
			local newBest = DataService:RecordRun(player, wave, kills, gems)
			DataService:AddStat(player, "Runs")
			DataService:AddStat(player, "BestWave", wave, true)
			if victory and not tutorial then -- a training run isn't a win
				DataService:AddStat(player, "Victories")
				DataService:AddStat(player, "Wins_" .. (player:GetAttribute("ClassId") or "Survivor"))
				if nightmare then
					DataService:AddStat(player, "NightmareWins")
				end
			end
			local results = { Wave = wave, WavesCleared = wavesCleared, Kills = kills, Gems = gems, NewBest = newBest, Victory = victory, Tutorial = tutorial, Nightmare = nightmare, XP = xp, XPBefore = xpBefore }
			self.LastResults[tostring(player.UserId)] = results
			Remotes.RunResults:FireClient(player, results)
		end
	end
	task.wait(if tutorial then Tutorial.ResultsTime else GameConfig.Match.ResultsTime)
	local returning = {}
	for player in inRun do
		table.insert(returning, player)
	end
	table.clear(inRun)
	table.clear(dead)
	if self.IsMatchServer then
		return -- Start sends everyone back to a lobby server
	end
	for _, player in returning do
		if player.Parent then
			task.spawn(self.SpawnInLobby, self, player)
		end
	end
	task.wait(1)
end

return MatchService
