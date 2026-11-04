-- LobbyController: lobby screen (visible while InRun is false) and the end-of-run results card.
--   main       wordmark, profile card, menu tiles and QUICK PLAY (UI/LobbyMenu; the shops: ShopController)
--   bottom     take-off status; on a Flight Line pad (player attribute PadId) it becomes the squad
--              panel: squad count, countdown and the mission (squad size, map; the caged Nightmare pad plays Nightmare), which
--              only the pad's host can change (Remotes.SetPadOptions; QueueService)
--   centre     results overlay after a run (Remotes.RunResults)
--   full       "waiting for your squad" cover on a match server until the drop starts

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Classes = require(Shared.Config.Classes)
local Weapons = require(Shared.Config.Weapons)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)
local GameState = require(Shared.GameState)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local LobbyMenu = require(script.Parent.Parent.UI.LobbyMenu)

local T = UIKit.Theme
local player = Players.LocalPlayer

local LobbyController = {}
local ui = {}

function LobbyController:Rebuild()
	ui.Menu:Refresh()
end

local resultsShownAt = 0

function LobbyController:ShowResults(results)
	ui.ResultsTitle.Text = if results.Tutorial then "TRAINING DONE" elseif results.Victory then "VICTORY" elseif results.NewBest and results.Wave > 1 then "NEW BEST!" else "OVERRUN"
	ui.ResultsTitle.TextColor3 = if results.Tutorial then T.Accent elseif results.Victory then T.Cash elseif results.NewBest and results.Wave > 1 then T.Accent else T.Danger
	local reached = if results.Victory and results.Nightmare then "You survived the Nightmare" elseif results.Victory then string.format("Survived all %d waves", results.WavesCleared) else string.format("Reached wave %d", results.Wave)
	ui.ResultsBody.Text = string.format("%s\nZombies killed: %s", reached, Util.FormatNumber(results.Kills))
	ui.ResultsGems.Text = if results.Nightmare and not results.Victory then "NO GEMS THIS TIME" else "+ " .. Util.FormatNumber(results.Gems) .. " Gems"
	ui.Results.Visible = true
	local shown = os.clock()
	resultsShownAt = shown
	task.delay(15, function()
		if resultsShownAt == shown then -- a newer result keeps its own 15s
			ui.Results.Visible = false
		end
	end)
end

-- CameraController frees the cursor while this is open, so CONTINUE is clickable mid-run too
function LobbyController:IsResultsOpen()
	return ui.Results ~= nil and ui.Results.Visible
end

-- Squad panel (shown on a pad): one row of choice buttons per mission setting
local ROWS = {
	{ Key = "Size", Label = "SQUAD SIZE" },
	{ Key = "Map", Label = "MAP", List = GameConfig.Lobby.Maps },
}

function LobbyController:_buildSquadPanel()
	local cfg = GameConfig.Lobby
	ui.Squad = UIKit.Panel({ Name = "Squad", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(560, 196), Visible = false, Parent = ui.Root })
	UIKit.Padding(14).Parent = ui.Squad
	ui.SquadTitle = UIKit.Label({ Size = UDim2.new(0.6, 0, 0, 30), TextSize = 26, TextColor3 = T.N100, TextXAlignment = Enum.TextXAlignment.Left, Parent = ui.Squad })
	ui.SquadTimer = UIKit.Label({ Position = UDim2.fromScale(0.6, 0), Size = UDim2.new(0.4, 0, 0, 30), TextSize = 24, TextColor3 = T.Cash, TextXAlignment = Enum.TextXAlignment.Right, Parent = ui.Squad })
	ui.Choices = {} -- { Button, Key, Value, Locked }
	ROWS[1].List = {}
	for _, size in cfg.SquadSizes do
		table.insert(ROWS[1].List, { Id = size, Name = tostring(size) })
	end
	for r, row in ROWS do
		local y = 4 + r * 40
		UIKit.Label({ Text = row.Label, Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(130, 32), TextSize = 17, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = ui.Squad })
		local width = math.floor(390 / #row.List) - 6
		for i, entry in row.List do
			local button = UIKit.Button({
				Name = row.Key .. tostring(entry.Id),
				Position = UDim2.fromOffset(142 + (i - 1) * (width + 6), y),
				Size = UDim2.fromOffset(width, 32),
				Text = if entry.Locked then entry.Name .. " · SOON" else entry.Name,
				TextSize = 17,
				Parent = ui.Squad,
			}, function()
				if not entry.Locked and ui.IsHost then
					Remotes.SetPadOptions:FireServer({ [row.Key] = entry.Id })
				end
			end)
			table.insert(ui.Choices, { Button = button, Key = row.Key, Value = entry.Id, Locked = entry.Locked })
		end
	end
	ui.SquadHint = UIKit.Label({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 24), TextSize = 17, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = ui.Squad })
end

-- pad: decoded GameState "Pad<id>" (QueueService:_publish)
function LobbyController:_showSquad(padId, pad)
	ui.IsHost = pad.HostId == player.UserId
	ui.SquadTitle.Text = string.format("%s  ·  SQUAD %d/%d", if pad.Difficulty == "Nightmare" then "NIGHTMARE" elseif pad.Mode == "Outbreak" then "OUTBREAK" else "PAD " .. padId, pad.Count, pad.Size)
	ui.SquadTimer.Text = if pad.Status == "Launching" then "TAKING OFF..." elseif pad.Status == "Waiting" then "RUN IN PROGRESS" else "TAKE-OFF IN " .. pad.Timer .. "s"
	for _, choice in ui.Choices do
		local selected = pad[choice.Key] == choice.Value
		local button = choice.Button
		button.BackgroundColor3 = if selected then T.Accent elseif choice.Locked then T.Disabled else T.Card
		button.TextColor3 = if selected then Color3.fromRGB(35, 35, 40) elseif choice.Locked then T.SubText else T.Text
		button.AutoButtonColor = ui.IsHost and not choice.Locked
	end
	ui.SquadHint.Text = if pad.Difficulty == "Nightmare" then "NIGHTMARE: win for 3x Gems. Die and you get nothing." elseif pad.Mode == "Outbreak" then "OUTBREAK: the horde is a million deep. Survive it." elseif ui.IsHost then "You're the host: pick the mission. Full squad = take-off in " .. GameConfig.Lobby.AllReadyTime .. "s"
		else pad.Host .. " is the host and picks the mission"
end

function LobbyController:Init()
	local gui = UIKit.Screen("Lobby")
	ui.Root = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	UIKit.AutoScale(ui.Root)

	-- the main screen: wordmark, profile card, menu tiles, QUICK PLAY and the deploy hint (UI/LobbyMenu)
	ui.Menu = LobbyMenu.new(ui.Root)

	ui.StatusBar, ui.Status, ui.QuickPlay = ui.Menu.StatusBar, ui.Menu.Status, ui.Menu.QuickPlay
	self:_buildSquadPanel()
	-- match server: cover the empty world until the drop starts
	ui.Waiting = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 10, 12), Visible = false, ZIndex = 10, Parent = gui })
	ui.WaitingText = UIKit.Label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(600, 90), TextSize = 30, TextWrapped = true, ZIndex = 10, Parent = ui.Waiting })

	-- Results overlay (own root: it shows over the lobby whether or not ui.Root is visible)
	local resultsRoot = UIKit.new("Frame", { BackgroundTransparency = 1, Parent = gui })
	UIKit.AutoScale(resultsRoot)
	ui.Results = UIKit.Panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(380, 230), Visible = false, ZIndex = 5, Parent = resultsRoot })
	ui.ResultsTitle = UIKit.Label({ Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 50), TextSize = 46, Font = T.FontTitle, ZIndex = 5, Parent = ui.Results })
	ui.ResultsBody = UIKit.Label({ Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 0, 56), TextSize = 22, ZIndex = 5, Parent = ui.Results })
	ui.ResultsGems = UIKit.Label({ Position = UDim2.fromOffset(0, 128), Size = UDim2.new(1, 0, 0, 34), TextSize = 28, TextColor3 = T.Gem, ZIndex = 5, Parent = ui.Results })
	UIKit.Button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(140, 40), Text = "CONTINUE", ZIndex = 5, Parent = ui.Results }, function()
		ui.Results.Visible = false
	end)

	Remotes.RunResults.OnClientEvent:Connect(function(results)
		self:ShowResults(results)
	end)
	for _, attr in { "Gems", "ClassId", "LoadoutJson", "BestWave" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			self:Rebuild()
		end)
	end
	self:Rebuild()
end

function LobbyController:Start()
	while true do
		local inRun = player:GetAttribute("InRun") == true
		local matchServer = GameState:GetAttribute("ServerKind") == "Match"
		local show = not inRun and not matchServer
		local seen = show and not player.PlayerGui:FindFirstChild("Welcome")
		if seen and not ui.Seen then
			ui.Menu:Enter() -- slide the menu in each time the lobby screen comes into view
		end
		ui.Seen = seen
		ui.Root.Visible = show
		ui.Waiting.Visible = matchServer and not inRun and GameState:GetAttribute("Phase") == "Lobby"
		if ui.Waiting.Visible then
			ui.WaitingText.Text = "WHEELS UP SOON\nWaiting for your squad to board..."
		elseif not inRun then
			local padId = player:GetAttribute("PadId") or 0
			local ok, pad = pcall(HttpService.JSONDecode, HttpService, GameState:GetAttribute("Pad" .. padId) or "")
			local onPad = padId ~= 0 and ok and type(pad) == "table"
			ui.Squad.Visible = onPad
			ui.StatusBar.Visible = not onPad
			ui.QuickPlay.Visible = not onPad
			if onPad then
				self:_showSquad(padId, pad)
			elseif GameState:GetAttribute("Phase") ~= "Lobby" then -- Studio: a run plays in this server
				ui.Status.Text = "Run in progress (wave " .. (GameState:GetAttribute("Wave") or 0) .. ")\nYou'll join the next one"
			else
				ui.Status.Text = "Gear up, then head through the FLIGHT LINE gate (north)\nand step onto a pad to deploy"
			end
		end
		task.wait(0.1)
	end
end

return LobbyController
