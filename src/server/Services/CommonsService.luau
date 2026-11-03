-- CommonsService: the things to do in the safehouse's Commons (vault: Lobby.md; built by Server/Map/Commons).
--   radio   "Listen in" at the radio shack: one of Overwatch's lore broadcasts (Config/Survivors) on your
--           radio panel (Remotes.Radio, event "Broadcast"), at most one per player every few seconds
--   hoop    "Shoot" the ball: it arcs from in front of you at the rim with an error that grows with
--           distance; a make calls "SWISH!" for you and everyone near. The ball rolls home after.
--   board   TOP SURVIVORS: the 10 best waves of all time (DataService:GetTopBestWaves), refreshed every
--           couple of minutes. In Studio (no DataStores) it lists the players in this server instead.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Survivors = require(Shared.Config.Survivors)
local Remotes = require(Shared.Remotes)

local CommonsService = {}
local Services

local RADIO_COOLDOWN = 8
local BOARD_REFRESH = 120
local lastBroadcast = {} -- [Player] = os.clock() of their last "Listen in"
local lastLine = 0
local names = {} -- [UserId] = name (cache)

local function nameOf(userId)
	if not names[userId] then
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		names[userId] = if ok then name else "Survivor " .. userId
	end
	return names[userId]
end

function CommonsService:Init(services)
	Services = services
	Players.PlayerRemoving:Connect(function(player)
		lastBroadcast[player] = nil
	end)
end

function CommonsService:Start()
	local lobby = workspace:WaitForChild(GameConfig.OurMap.Folder):WaitForChild("Lobby")
	local commons = lobby:FindFirstChild("Commons")
	if not commons then
		return
	end
	for _, prompt in commons:GetDescendants() do
		if prompt:IsA("ProximityPrompt") then
			local kind = prompt:GetAttribute("Commons")
			prompt.Triggered:Connect(function(player)
				if kind == "Radio" then
					self:_broadcast(player)
				elseif kind == "Hoop" then
					self:_shoot(player, prompt.Parent)
				end
			end)
		end
	end
	local board = commons:FindFirstChild("TopSurvivors")
	local rows = board and board:FindFirstChild("Rows", true)
	if rows then
		while true do
			local live = self:_refreshBoard(rows)
			task.wait(if live then BOARD_REFRESH else 10) -- the in-server fallback is cheap, so keep it fresh
		end
	end
end

function CommonsService:_broadcast(player)
	if os.clock() - (lastBroadcast[player] or -math.huge) < RADIO_COOLDOWN then
		return
	end
	lastBroadcast[player] = os.clock()
	local lines = Survivors.Broadcasts
	local i = math.random(1, #lines)
	if i == lastLine then
		i = i % #lines + 1 -- not the same story twice in a row
	end
	lastLine = i
	Remotes.Radio:FireClient(player, lines[i], "Broadcast")
end

function CommonsService:_shoot(player, ball)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local hoop = ball.Parent
	local rim = hoop:GetAttribute("RimCenter")
	if not root or not rim or ball:GetAttribute("Flying") then
		return
	end
	ball:SetAttribute("Flying", true)
	local start = root.Position + root.CFrame.LookVector * 2 + Vector3.new(0, 2, 0)
	local distance = ((rim - start) * Vector3.new(1, 0, 1)).Magnitude
	-- the miss chance grows with distance (about half go in from 9 studs, counting bank shots; few from 20)
	local err = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * (0.6 + distance * 0.17)
	local aim = rim + err
	-- a natural arc: up to an apex 4 studs over the rim, then down through it
	local g = workspace.Gravity
	local apex = math.max(rim.Y, start.Y) + 4
	local up = math.sqrt(2 * g * (apex - start.Y))
	local t = up / g + math.sqrt(2 * (apex - aim.Y) / g)
	local velocity = (aim - start) * Vector3.new(1, 0, 1) / t + Vector3.new(0, up, 0)
	ball.Anchored = false
	ball.CFrame = CFrame.new(start)
	ball.AssemblyLinearVelocity = velocity
	ball:SetNetworkOwner(nil)

	local scored = false
	local prevY = start.Y
	local began = os.clock()
	local watch
	watch = RunService.Heartbeat:Connect(function()
		local p = ball.Position
		if not scored and prevY > rim.Y and p.Y <= rim.Y and ((p - rim) * Vector3.new(1, 0, 1)).Magnitude < 0.7 then
			scored = true
			Remotes.Notify:FireClient(player, "SWISH!", "Good")
			for _, other in Players:GetPlayers() do
				local r = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
				if other ~= player and r and (r.Position - rim).Magnitude < 40 then
					Remotes.Notify:FireClient(other, player.DisplayName .. " sinks one from " .. math.floor(distance) .. " studs!", "Info")
				end
			end
		end
		prevY = p.Y
		if os.clock() - began > 4 then
			watch:Disconnect()
			ball.Anchored = true
			ball.AssemblyLinearVelocity = Vector3.zero
			ball.CFrame = CFrame.new(ball:GetAttribute("Home"))
			ball:SetAttribute("Flying", nil)
		end
	end)
end

function CommonsService:_refreshBoard(rows)
	local top = Services.DataService:GetTopBestWaves(10)
	local lines = {}
	if top then
		for _, entry in top do
			table.insert(lines, { nameOf(entry.UserId), entry.Wave })
		end
	else -- no DataStores (Studio): this server's players
		for _, player in Players:GetPlayers() do
			table.insert(lines, { player.DisplayName, player:GetAttribute("BestWave") or 0 })
		end
		table.sort(lines, function(a, b)
			return a[2] > b[2]
		end)
	end
	for i = 1, 10 do
		local row = rows:FindFirstChild("Row" .. i)
		local line = lines[i]
		if row then
			row.Text = if line then string.format("%d.  %s  ·  WAVE %d", i, line[1], line[2]) else ""
		end
	end
	return top ~= nil
end

return CommonsService
