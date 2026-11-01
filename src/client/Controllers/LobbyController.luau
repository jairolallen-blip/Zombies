-- LobbyController: lobby UI (visible while InRun is false) and the end-of-run results card.
--   left panel   title, Gems, best wave, class list (equip / unlock with Gems)
--   right panel  LOADOUT: one gun per Level (equip / unlock with Gems); the run starts on Level 1
--                and the in-run Weapon upgrade swaps to the next Level's gun
--   bottom       Ready toggle + countdown status
--   centre       results overlay after a run (Remotes.RunResults)
-- Cards rebuild whenever Gems / OwnedJson / ClassId / LoadoutJson attributes change.

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

local T = UIKit.Theme
local player = Players.LocalPlayer

local LobbyController = {}
local ui = {}

local function sortedKeys(list)
	local keys = {}
	for id in list do
		table.insert(keys, id)
	end
	table.sort(keys, function(a, b)
		return (list[a].Order or 99) < (list[b].Order or 99)
	end)
	return keys
end

local function owned()
	local ok, data = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("OwnedJson") or "{}")
	data = if ok and type(data) == "table" then data else {}
	return data.Classes or {}, data.Weapons or {}
end

local function loadout()
	local ok, data = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("LoadoutJson") or "[]")
	return if ok and type(data) == "table" then data else {}
end

local function clear(list)
	for _, child in list:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function card(parent, def, detail, isOwned, isEquipped, onEquip, onUnlock)
	local frame = UIKit.new("Frame", { Size = UDim2.new(1, 0, 0, 78), BackgroundColor3 = T.Card, BorderSizePixel = 0, Parent = parent })
	UIKit.Corner(10).Parent = frame
	if isEquipped then
		UIKit.Stroke(T.Accent, 2).Parent = frame
	end
	UIKit.Label({ Text = def.DisplayName, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -140, 0, 24), TextSize = 21, TextColor3 = def.Color or T.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
	UIKit.Label({
		Text = detail,
		Position = UDim2.fromOffset(12, 30),
		Size = UDim2.new(1, -140, 0, 42),
		TextSize = 14,
		TextWrapped = true,
		TextColor3 = T.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = frame,
	})
	local button = UIKit.Button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(116, 40), TextSize = 17, Parent = frame })
	if isEquipped then
		button.Text = "EQUIPPED"
		button.BackgroundColor3 = T.Disabled
		button.TextColor3 = T.Text
		button.AutoButtonColor = false
	elseif isOwned then
		button.Text = "EQUIP"
		button.Activated:Connect(onEquip)
	else
		local affordable = (player:GetAttribute("Gems") or 0) >= def.GemCost
		button.Text = "◆ " .. Util.FormatNumber(def.GemCost)
		button.BackgroundColor3 = if affordable then T.Gem else T.Disabled
		button.TextColor3 = T.Text
		button.Activated:Connect(onUnlock)
	end
end

function LobbyController:Rebuild()
	local ownedClasses, ownedWeapons = owned()
	ui.Gems.Text = "◆ " .. Util.FormatNumber(player:GetAttribute("Gems") or 0) .. " Gems"
	ui.Best.Text = "Best wave: " .. (player:GetAttribute("BestWave") or 0)
	clear(ui.List)
	clear(ui.Loadout)

	local function header(text, order, parent, color)
		UIKit.Label({ Text = text, Size = UDim2.new(1, 0, 0, 28), TextSize = 22, TextColor3 = color or T.Accent, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, Parent = parent or ui.List })
	end
	header("CLASSES", 0)
	local order = 1
	local classId = player:GetAttribute("ClassId")
	for _, id in sortedKeys(Classes.List) do
		local def = Classes.List[id]
		local detail = def.Description .. "\n[E] " .. def.Ability.Name .. "   [F] " .. def.Ultimate.Name
		local holder = UIKit.new("Frame", { Size = UDim2.new(1, 0, 0, 78), BackgroundTransparency = 1, LayoutOrder = order, Parent = ui.List })
		card(holder, def, detail, ownedClasses[id], classId == id, function()
			Remotes.SelectClass:FireServer(id)
		end, function()
			Remotes.UnlockItem:FireServer("Class", id)
		end)
		order += 1
	end
	-- Loadout: one section per Level
	local picked = loadout()
	local costs = GameConfig.Upgrades.Weapon.Costs
	order = 0
	for level = 1, Weapons.Levels do
		local price = if level == 1 then "STARTER" else "UPGRADE $" .. Util.FormatNumber(costs[level - 1])
		header("LEVEL " .. level .. "  ·  " .. price, order, ui.Loadout, GameConfig.WeaponTiers[level].Color)
		order += 1
		local equipped = picked[level] or Weapons.DefaultFor(level)
		for _, id in Weapons.ForLevel(level) do
			local def = Weapons.List[id]
			local stats = Util.GetWeaponStats(id, level)
			local detail = string.format("%s\nDMG %d%s · %.1f/s · MAG %d", def.Description, math.floor(stats.Damage), if stats.Pellets > 1 then "×" .. stats.Pellets else "", stats.FireRate, stats.MagSize)
			local holder = UIKit.new("Frame", { Size = UDim2.new(1, 0, 0, 78), BackgroundTransparency = 1, LayoutOrder = order, Parent = ui.Loadout })
			card(holder, def, detail, ownedWeapons[id], equipped == id, function()
				Remotes.SelectWeapon:FireServer(id)
			end, function()
				Remotes.UnlockItem:FireServer("Weapon", id)
			end)
			order += 1
		end
	end
end

function LobbyController:ShowResults(results)
	ui.ResultsTitle.Text = if results.NewBest then "NEW BEST!" else "OVERRUN"
	ui.ResultsTitle.TextColor3 = if results.NewBest then T.Accent else T.Danger
	ui.ResultsBody.Text = string.format("Reached wave %d\nZombies killed: %s", results.Wave, Util.FormatNumber(results.Kills))
	ui.ResultsGems.Text = "+ ◆ " .. Util.FormatNumber(results.Gems) .. " Gems"
	ui.Results.Visible = true
	task.delay(15, function()
		ui.Results.Visible = false
	end)
end

function LobbyController:Init()
	local gui = UIKit.Screen("Lobby")
	ui.Root = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })

	local panel = UIKit.Panel({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 20, 0.5, 0), Size = UDim2.new(0, 440, 0.88, 0), Parent = ui.Root })
	UIKit.Padding(14).Parent = panel
	UIKit.Label({ Text = "SURVIVE A MILLION ZOMBIES", Size = UDim2.new(1, 0, 0, 34), TextSize = 28, TextColor3 = Color3.fromRGB(150, 255, 90), TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	ui.Gems = UIKit.Label({ Position = UDim2.fromOffset(0, 38), Size = UDim2.new(0.5, 0, 0, 26), TextSize = 22, TextColor3 = T.Gem, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	ui.Best = UIKit.Label({ Position = UDim2.new(0.5, 0, 0, 38), Size = UDim2.new(0.5, 0, 0, 26), TextSize = 18, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Right, Parent = panel })
	ui.List = UIKit.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.new(1, 0, 1, -74),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = panel,
	})
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = ui.List })

	local loadoutPanel = UIKit.Panel({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0), Size = UDim2.new(0, 440, 0.88, 0), Parent = ui.Root })
	UIKit.Padding(14).Parent = loadoutPanel
	UIKit.Label({ Text = "LOADOUT", Size = UDim2.new(1, 0, 0, 34), TextSize = 28, TextColor3 = Color3.fromRGB(150, 255, 90), TextXAlignment = Enum.TextXAlignment.Left, Parent = loadoutPanel })
	UIKit.Label({ Text = "Pick one gun per level. Upgrade in-run with cash.", Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 26), TextSize = 16, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = loadoutPanel })
	ui.Loadout = UIKit.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.new(1, 0, 1, -74),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = loadoutPanel,
	})
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = ui.Loadout })

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
	for _, attr in { "Gems", "OwnedJson", "ClassId", "LoadoutJson", "BestWave" } do
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
