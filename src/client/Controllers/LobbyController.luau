-- LobbyController: lobby screen (visible while InRun is false) and the end-of-run results card.
--   top-left   compact chip: Gems, best wave, current class + loadout, and where the shops are
--              (class and gun choices happen in the Armory / Barracks shops: ShopController)
--   bottom     Ready toggle + countdown status
--   centre     results overlay after a run (Remotes.RunResults)

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Classes = require(Shared.Config.Classes)
local Weapons = require(Shared.Config.Weapons)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)
local GameState = require(Shared.GameState)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local T = UIKit.Theme
local player = Players.LocalPlayer

local LobbyController = {}
local ui = {}

function LobbyController:Rebuild()
	ui.Gems.Text = "◆ " .. Util.FormatNumber(player:GetAttribute("Gems") or 0) .. " Gems"
	ui.Best.Text = "Best wave " .. (player:GetAttribute("BestWave") or 0)
	local class = Classes.List[player:GetAttribute("ClassId")] or Classes.List[Classes.Default]
	local ok, picked = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("LoadoutJson") or "[]")
	picked = if ok and type(picked) == "table" then picked else {}
	local guns = {}
	for level = 1, Weapons.Levels do
		table.insert(guns, Weapons.List[picked[level] or Weapons.DefaultFor(level)].DisplayName)
	end
	ui.Class.Text = "Class: " .. class.DisplayName
	ui.Class.TextColor3 = class.Color
	ui.Guns.Text = "Guns: " .. table.concat(guns, " → ")
end

function LobbyController:ShowResults(results)
	ui.ResultsTitle.Text = if results.Victory then "VICTORY" elseif results.NewBest then "NEW BEST!" else "OVERRUN"
	ui.ResultsTitle.TextColor3 = if results.Victory then T.Cash elseif results.NewBest then T.Accent else T.Danger
	local reached = if results.Victory then string.format("Survived all %d waves", results.WavesCleared) else string.format("Reached wave %d", results.Wave)
	ui.ResultsBody.Text = string.format("%s\nZombies killed: %s", reached, Util.FormatNumber(results.Kills))
	ui.ResultsGems.Text = "+ ◆ " .. Util.FormatNumber(results.Gems) .. " Gems"
	ui.Results.Visible = true
	task.delay(15, function()
		ui.Results.Visible = false
	end)
end

function LobbyController:Init()
	local gui = UIKit.Screen("Lobby")
	ui.Root = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })

	local chip = UIKit.Panel({ Position = UDim2.fromOffset(20, 20), Size = UDim2.fromOffset(420, 150), Parent = ui.Root })
	UIKit.Padding(12).Parent = chip
	UIKit.Label({ Text = "SURVIVE A MILLION ZOMBIES", Size = UDim2.new(1, 0, 0, 28), TextSize = 24, TextColor3 = Color3.fromRGB(150, 255, 90), TextXAlignment = Enum.TextXAlignment.Left, Parent = chip })
	ui.Gems = UIKit.Label({ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(0.55, 0, 0, 24), TextSize = 20, TextColor3 = T.Gem, TextXAlignment = Enum.TextXAlignment.Left, Parent = chip })
	ui.Best = UIKit.Label({ Position = UDim2.new(0.55, 0, 0, 30), Size = UDim2.new(0.45, 0, 0, 24), TextSize = 16, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Right, Parent = chip })
	ui.Class = UIKit.Label({ Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 20), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Parent = chip })
	ui.Guns = UIKit.Label({ Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 0, 20), TextSize = 14, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = chip })
	UIKit.Label({ Text = "ARMORY (west tent): guns  ·  BARRACKS (east): classes", Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 0, 20), TextSize = 14, TextColor3 = T.Accent, TextXAlignment = Enum.TextXAlignment.Left, Parent = chip })

	-- Ready bar
	local readyBar = UIKit.Panel({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(420, 70), Parent = ui.Root })
	ui.Status = UIKit.Label({ Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -170, 1, 0), TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Parent = readyBar })
	ui.Ready = UIKit.Button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(140, 48), TextSize = 24, Text = "READY", Parent = readyBar }, function()
		Remotes.SetReady:FireServer(not player:GetAttribute("Ready"))
	end)

	-- Results overlay
	ui.Results = UIKit.Panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(380, 230), Visible = false, ZIndex = 5, Parent = gui })
	ui.ResultsTitle = UIKit.Label({ Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 50), TextSize = 46, ZIndex = 5, Parent = ui.Results })
	ui.ResultsBody = UIKit.Label({ Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 0, 56), TextSize = 21, ZIndex = 5, Parent = ui.Results })
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
		ui.Root.Visible = not inRun
		if not inRun then
			local ready = player:GetAttribute("Ready") == true
			ui.Ready.Text = if ready then "UNREADY" else "READY"
			ui.Ready.BackgroundColor3 = if ready then T.Cash else T.Accent
			local phase = GameState:GetAttribute("Phase")
			if phase == "Lobby" then
				ui.Status.Text = string.format(
					"Run starts in %ds\n%d / %d ready",
					GameState:GetAttribute("Timer") or 0,
					GameState:GetAttribute("ReadyCount") or 0,
					GameState:GetAttribute("PlayerCount") or 0
				)
			else
				ui.Status.Text = "Run in progress (wave " .. (GameState:GetAttribute("Wave") or 0) .. ")\nYou'll join the next one"
			end
		end
		task.wait(0.1)
	end
end

return LobbyController
