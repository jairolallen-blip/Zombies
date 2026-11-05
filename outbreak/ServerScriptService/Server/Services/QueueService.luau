-- QueueService: the Flight Line pads of a lobby server (vault: Lobby.md, map: Server/Map/FlightLine).
-- Each pad is its own queue:
--   * the first player to step onto an empty pad is its HOST and picks the mission with
--     Remotes.SetPadOptions (squad size, map; choices in GameConfig.Lobby). If the host
--     steps off, the next in line takes over. An empty pad goes back to the defaults.
--   * others can step on until the squad is full; anyone after that is told the pad is full
--   * the countdown (GameConfig.Lobby) runs while anyone is on the pad and snaps short when it's full
--   * the pad sets the difficulty: the Nightmare pad (model attribute Nightmare, behind its gate) only
--     boards players who have unlocked it (Config/Nightmare) and is left out of QUICK PLAY
--   * at 0 that squad takes off. Live: teleported together into a new reserved server of this place
--     (MatchService runs the match there). Studio has no teleports, so the run plays in this server
--     instead, one at a time (the other pads wait).
-- First-time players (profile TutorialDone = false) are teleported straight into a solo tutorial run
-- instead of staying in the lobby (live only; in Studio use SAMZ_Debug "Tutorial").
-- Also owns the trip back: MatchService calls :ReturnToLobby when a match server's run is over.
--
-- The client reads pad state from GameState "Pad<id>" = JSON {Host, Count, Size, Difficulty, Map,
-- Timer, Status = "Open" | "Boarding" | "Launching" | "Waiting"} and player attribute PadId (0 = none).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)
local GameState = require(Shared.GameState)
local Nightmare = require(Shared.Config.Nightmare)
local Outbreak = require(Shared.Config.Outbreak)

local QueueService = {}
local Services
local cfg = GameConfig.Lobby
local pads = {} -- [PadId] = { Id, Part, Nightmare, Members = {Player}, Options, Timer?, Launching }
local warnedFull = {} -- [Player] = PadId they were told is full (told once per visit)

local function defaultOptions(pad)
	return { Size = cfg.DefaultSquadSize, Difficulty = if pad.Nightmare then "Nightmare" else "Normal", Mode = pad.Mode, Map = cfg.Maps[1].Id }
end

local function allowed(list, id)
	for _, entry in list do
		if entry.Id == id then
			return not entry.Locked
		end
	end
	return false
end

-- Saves every player's profile (in parallel) so the server they land on loads what this one had
local function saveAll(players)
	local left = #players
	for _, player in players do
		task.spawn(function()
			Services.DataService:Save(player, true)
			left -= 1
		end)
	end
	local deadline = os.clock() + 10
	while left > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end

-- Teleports players together to this place: a new reserved server (a match) when reserve is set,
-- else a public server (a lobby). placeId overrides the destination (Outbreak mode teleports to its
-- own place; ReturnToLobby from there comes back to the lobby place). Returns true once Roblox accepted the request.
local function teleport(players, data, reserve, placeId)
	saveAll(players)
	local options = Instance.new("TeleportOptions")
	options.ShouldReserveServer = reserve
	if data then
		options:SetTeleportData(data)
	end
	for attempt = 1, 3 do
		local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, placeId or game.PlaceId, players, options)
		if ok then
			return true
		end
		warn("[QueueService] teleport failed (attempt " .. attempt .. "):", err)
		task.wait(attempt)
	end
	return false
end

function QueueService:Init(services)
	Services = services
	Remotes.SetPadOptions.OnServerEvent:Connect(function(player, options)
		self:SetOptions(player, options)
	end)
	Remotes.QuickPlay.OnServerEvent:Connect(function(player)
		self:QuickPlay(player)
	end)
	TeleportService.TeleportInitFailed:Connect(function(player, result, message)
		warn("[QueueService] teleport of", player.Name, "failed:", result, message)
		Remotes.Notify:FireClient(player, "Take-off failed (" .. tostring(result) .. "). Try again in a moment.", "Danger")
	end)
	Players.PlayerRemoving:Connect(function(player)
		warnedFull[player] = nil
	end)
	if Services.MatchService.IsMatchServer then
		return
	end
	for id, part in Services.MapService:GetPads() do
		pads[id] = { Id = id, Part = part, Nightmare = part.Parent:GetAttribute("Nightmare") == true, Mode = part.Parent:GetAttribute("ModeId"), Members = {} }
		pads[id].Options = defaultOptions(pads[id])
	end
	Services.DataService.ProfileLoaded:Connect(function(player, profile)
		if profile.TutorialDone then
			Services.DataService:Funnel(player, 11, "Reached the lobby")
		elseif not RunService:IsStudio() then
			Remotes.Notify:FireClient(player, "First time here? Overwatch is flying you out for a training drop...", "Info")
			if not teleport({ player }, { Tutorial = true, Squad = { player.UserId } }, true) then
				Remotes.Notify:FireClient(player, "Couldn't reach the training drop, so welcome to the safehouse!", "Danger")
			end
		end
	end)
end

function QueueService:Start()
	if Services.MatchService.IsMatchServer then
		return
	end
	local step = 0.25
	while true do
		self:_tick(step)
		task.wait(step)
	end
end

-- Host only. options: any of Size, Map (each checked against GameConfig.Lobby). The pad sets Difficulty.
function QueueService:SetOptions(player, options)
	local pad = pads[player:GetAttribute("PadId") or 0]
	if not pad or pad.Members[1] ~= player or pad.Launching or type(options) ~= "table" then
		return
	end
	if table.find(cfg.SquadSizes, options.Size) then
		pad.Options.Size = options.Size
		for i = #pad.Members, options.Size + 1, -1 do -- squad shrank below its members: latest off first
			table.remove(pad.Members, i):SetAttribute("PadId", 0)
		end
	end
	if allowed(cfg.Maps, options.Map) then
		pad.Options.Map = options.Map
	end
	self:_publish(pad)
end

-- QUICK PLAY button (LobbyController): move the player onto the fullest pad that still has room and isn't
-- taking off, so solo players find a squad; an empty pad if none has players. _tick boards them as usual.
function QueueService:QuickPlay(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (player:GetAttribute("PadId") or 0) ~= 0 or Services.MatchService:IsInRun(player) then
		return
	end
	local best
	for _, pad in pads do
		local room = not pad.Nightmare and not pad.Mode and not pad.Launching and #pad.Members < pad.Options.Size
		if room and (not best or #pad.Members > #best.Members or (#pad.Members == #best.Members and pad.Id < best.Id)) then
			best = pad
		end
	end
	if not best then
		return Remotes.Notify:FireClient(player, "Every pad is full or taking off. Try again in a moment!", "Danger")
	end
	local offset = Vector3.new(math.random(-4, 4), best.Part.Size.Y / 2 + 3, math.random(-4, 4))
	player.Character:PivotTo(CFrame.new(best.Part.Position + offset))
end

function QueueService:_tick(dt)
	local MatchService = Services.MatchService
	-- drop members who stepped off, left the game or are in a run
	for _, pad in pads do
		for i = #pad.Members, 1, -1 do
			local player = pad.Members[i]
			if not player.Parent or MatchService:IsInRun(player) or Services.MapService:GetPadAt(player) ~= pad.Id then
				table.remove(pad.Members, i)
				player:SetAttribute("PadId", 0)
			end
		end
		if #pad.Members == 0 then
			pad.Options = defaultOptions(pad)
			pad.Timer = nil
		end
	end
	-- board newcomers
	for _, player in Players:GetPlayers() do
		local id = Services.MapService:GetPadAt(player)
		local pad = id and pads[id]
		if not pad or not Services.DataService:Get(player) or MatchService:IsInRun(player) then
			warnedFull[player] = nil
		elseif (player:GetAttribute("PadId") or 0) == 0 and not pad.Launching then
			local stats = Services.DataService:Get(player).Stats
			if pad.Nightmare and not Nightmare.Unlocked(stats) then
				if warnedFull[player] ~= id then
					warnedFull[player] = id
					Remotes.Notify:FireClient(player, string.format("Nightmare opens after %d normal wins (%d/%d).", Nightmare.WinsToUnlock, stats.Victories or 0, Nightmare.WinsToUnlock), "Danger")
				end
			elseif #pad.Members < pad.Options.Size then
				table.insert(pad.Members, player)
				player:SetAttribute("PadId", id)
				warnedFull[player] = nil
			elseif warnedFull[player] ~= id then
				warnedFull[player] = id
				Remotes.Notify:FireClient(player, "Pad " .. id .. " is full. Try another pad!", "Danger")
			end
		end
	end
	-- countdowns
	local busy = RunService:IsStudio() and MatchService:IsRunning()
	for _, pad in pads do
		if #pad.Members > 0 and not pad.Launching then
			pad.Timer = pad.Timer or cfg.IntermissionTime
			if #pad.Members >= pad.Options.Size then
				pad.Timer = math.min(pad.Timer, cfg.AllReadyTime)
			end
			if busy then
				pad.Timer = math.max(pad.Timer, cfg.AllReadyTime) -- Studio: wait for the run in progress
			else
				pad.Timer -= dt
				if pad.Timer <= 0 then
					task.spawn(self._launch, self, pad)
				end
			end
		end
		self:_publish(pad, busy)
	end
end

function QueueService:_launch(pad)
	pad.Launching = true
	local squad = table.clone(pad.Members)
	local options = table.clone(pad.Options)
	self:_publish(pad)
	if RunService:IsStudio() then
		pad.Launching = false
		Services.MatchService:RunMatch(squad, options) -- members leave the pad as they spawn in the arena
	else
		local ids = {}
		for _, player in squad do
			table.insert(ids, player.UserId)
		end
		options.Squad = ids
		-- the Outbreak pad takes its squad to the mode's OWN place (Config/Outbreak.PlaceId),
		-- a fresh reserved server there; every other pad uses a reserved server of this place
		local placeId = if pad.Mode == "Outbreak" then Outbreak.PlaceId else nil
		if not teleport(squad, options, true, placeId) then
			for _, player in squad do
				Remotes.Notify:FireClient(player, "Take-off failed. Stay on the pad to try again.", "Danger")
			end
		end
		-- fresh pad; anyone still standing on it (a failed teleport) boards again with a full countdown
		for _, player in pad.Members do
			player:SetAttribute("PadId", 0)
		end
		table.clear(pad.Members)
		pad.Timer = nil
		pad.Launching = false
	end
end

function QueueService:_publish(pad, busy)
	local host = pad.Members[1]
	local status = if pad.Launching then "Launching" elseif busy and #pad.Members > 0 then "Waiting" elseif #pad.Members > 0 then "Boarding" else "Open"
	GameState:SetAttribute("Pad" .. pad.Id, HttpService:JSONEncode({
		Host = if host then host.DisplayName else "",
		HostId = if host then host.UserId else 0,
		Count = #pad.Members,
		Size = pad.Options.Size,
		Difficulty = pad.Options.Difficulty,
		Map = pad.Options.Map,
		Timer = math.max(0, math.ceil(pad.Timer or cfg.IntermissionTime)),
		Status = status,
	}))
	local label = not pad.Nightmare and pad.Part.Parent:FindFirstChild("Sign") -- NightmareController writes that sign per player
	label = label and label:FindFirstChildWhichIsA("SurfaceGui")
	label = label and label:FindFirstChildWhichIsA("TextLabel")
	if label then
		label.Text = if status == "Open" then "PAD " .. pad.Id .. " · OPEN" else string.format("PAD %d · %d/%d", pad.Id, #pad.Members, pad.Options.Size)
	end
end

-- Match server, run over: everyone goes back to a lobby server together. Retries a few times; anyone
-- still here after that is kicked with a message rather than stranded on an empty match server.
function QueueService:ReturnToLobby(players)
	for attempt = 1, 3 do
		local here = {}
		for _, player in players do
			if player.Parent then
				table.insert(here, player)
			end
		end
		if #here == 0 then
			return
		end
		teleport(here, nil, false, if GameState.Mode == "Outbreak" then Outbreak.LobbyPlaceId else nil)
		task.wait(15)
	end
	for _, player in players do
		if player.Parent then
			player:Kick("Couldn't get you back to the safehouse. Please rejoin!")
		end
	end
end

return QueueService
