-- ShopController: the lobby's two shops (vault: Lobby.md), opened by walking up to them and pressing
-- the ProximityPrompt (attribute Shop) that Server/Map/OurLobby puts in each:
--   Armory   (west tent)   level tabs 1-4; one card per gun with a rotating 3D model, stat bars and
--                          equip / unlock-with-Gems
--   Classes  (barracks)    one card per class with a rotating figure (Shared/ClassFigures)
--   Achievements (commendations board, south)  scrolling list of Config/Achievements with progress
--                          bars and CLAIM buttons (Remotes.ClaimAchievement); the board's status sign
--                          shows how many are ready to claim
-- Closes with the X button, by walking away, or when a run starts. Buttons fire the same remotes
-- LobbyService validates (SelectWeapon / SelectClass / UnlockItem).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Classes = require(Shared.Config.Classes)
local Weapons = require(Shared.Config.Weapons)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)
local GunModels = require(Shared.GunModels)
local ClassFigures = require(Shared.ClassFigures)
local Achievements = require(Shared.Config.Achievements)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local T = UIKit.Theme
local TITLE = T.Sign
local player = Players.LocalPlayer
local ShopController = {}
local ui = {}
local openShop = nil -- "Armory" | "Classes" | nil
local anchor = nil -- prompt part the shop was opened from (walk away to close)
local level = 1 -- armory tab
local spinning = {} -- { Model, Base, Center, Sway }

-- largest value of each stat over every gun, for the bars
local STATS = {
	{ "Damage", function(w) return w.Damage * w.Pellets end, function(w) return if w.Pellets > 1 then w.Damage .. "×" .. w.Pellets else tostring(w.Damage) end },
	{ "Fire rate", function(w) return w.FireRate end, function(w) return string.format("%g/s", w.FireRate) end },
	{ "Magazine", function(w) return w.MagSize end, function(w) return tostring(w.MagSize) end },
	{ "Range", function(w) return w.Range end, function(w) return tostring(w.Range) end },
}
local statMax = {}
for i, stat in STATS do
	statMax[i] = 0
	for _, w in Weapons.List do
		statMax[i] = math.max(statMax[i], stat[2](w))
	end
end

local function decode(attr)
	local ok, data = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute(attr) or "{}")
	return if ok and type(data) == "table" then data else {}
end

local function clear(frame)
	for _, child in frame:GetChildren() do
		child:Destroy() -- layouts too: each shop adds its own
	end
end

-- 3D preview: frames the model and registers it to turn (guns sway to keep their profile)
local function preview(parent, size, model, sway)
	local vp = UIKit.new("ViewportFrame", {
		Size = size,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Ambient = Color3.fromRGB(205, 200, 185),
		LightColor = Color3.fromRGB(255, 245, 230),
		LightDirection = Vector3.new(-0.6, -0.8, 0.4),
		Parent = parent,
	})
	UIKit.Corner(4).Parent = vp
	UIKit.Stroke(Color3.fromRGB(20, 22, 18), 2).Parent = vp
	UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(148, 152, 138), Color3.fromRGB(58, 60, 50)), Parent = vp })
	model.Parent = vp
	local cf, extent = model:GetBoundingBox()
	local center = cf.Position
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	-- distance that fits the model's width and height in the frame, plus a margin
	local aspect = parent.AbsoluteSize.X > 0 and (size.X.Offset + parent.AbsoluteSize.X * size.X.Scale) / size.Y.Offset or 1.5
	local halfV = math.tan(math.rad(camera.FieldOfView / 2))
	local width = if sway then extent.Z else extent.X
	local fit = math.max(width / 2 / (halfV * aspect), extent.Y / 2 / halfV) * 1.3
	if sway then -- gun points along -Z: look at its side
		camera.CFrame = CFrame.lookAt(center + Vector3.new(fit + extent.X / 2, fit * 0.12, 0), center)
	else -- figure faces -Z: look at its front
		camera.CFrame = CFrame.lookAt(center + Vector3.new(0, fit * 0.05, -(fit + extent.Z / 2)), center)
	end
	camera.Parent = vp
	vp.CurrentCamera = camera
	table.insert(spinning, { Model = model, Base = model:GetPivot(), Center = center, Sway = sway })
	return vp
end

local function gunModel(id, lvl)
	local tool = GunModels.BuildTool(Util.GetWeaponStats(id, lvl))
	local model = Instance.new("Model")
	for _, child in tool:GetChildren() do
		if child:IsA("BasePart") then
			child.Anchored = true
			child.Parent = model
		end
	end
	model.PrimaryPart = model:FindFirstChild("Handle")
	tool:Destroy()
	return model
end

-- equip / unlock button shared by both shops
local function actionButton(parent, isEquipped, isOwned, gemCost, onEquip, onUnlock)
	local button = UIKit.Button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -20, 0, 44), TextSize = 20, Parent = parent })
	UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 150)), Parent = button })
	local bc = button:FindFirstChildOfClass("UICorner")
	if bc then
		bc:Destroy()
	end
	UIKit.Corner(4).Parent = button
	UIKit.Stroke(Color3.fromRGB(18, 20, 16), 3).Parent = button
	if isEquipped then
		button.Text = "EQUIPPED"
		button.BackgroundColor3 = T.Cash
		button.TextColor3 = Color3.fromRGB(20, 30, 20)
		button.AutoButtonColor = false
	elseif isOwned then
		button.Text = "EQUIP"
		button.Activated:Connect(onEquip)
	else
		local affordable = (player:GetAttribute("Gems") or 0) >= gemCost
		button.Text = "◆ " .. Util.FormatNumber(gemCost) .. "  UNLOCK"
		button.BackgroundColor3 = if affordable then T.Gem else T.Disabled
		button.TextColor3 = T.Text
		button.Activated:Connect(onUnlock)
	end
end

local function card(parent, width, accent, highlighted, name)
	local frame = UIKit.new("Frame", { Size = UDim2.new(0, width, 1, 0), BackgroundColor3 = Color3.fromRGB(56, 54, 46), BorderSizePixel = 0, Parent = parent })
	UIKit.Corner(4).Parent = frame
	local stroke = UIKit.Stroke(if highlighted then accent else Color3.fromRGB(16, 18, 14), if highlighted then 4 else 3)
	stroke.Parent = frame
	local strip = UIKit.new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = accent, BorderSizePixel = 0, Parent = frame })
	UIKit.Corner(4).Parent = strip
	UIKit.Label({ Text = name, Size = UDim2.new(1, 0, 1, 0), TextSize = 20, TextColor3 = Color3.fromRGB(22, 24, 18), Parent = strip })
	return frame
end

function ShopController:_buildArmory()
	local body = ui.Body
	local owned = decode("OwnedJson").Weapons or {}
	local picked = decode("LoadoutJson")
	local costs = GameConfig.Upgrades.Weapon.Costs

	local tabs = UIKit.new("Frame", { Size = UDim2.new(0, 170, 1, 0), BackgroundTransparency = 1, Parent = body })
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 10), Parent = tabs })
	for lvl = 1, Weapons.Levels do
		local color = GameConfig.WeaponTiers[lvl].Color
		local selected = lvl == level
		local tab = UIKit.new("TextButton", {
			Name = "LevelTab" .. lvl,
			Size = UDim2.new(1, 0, 0, 74),
			BackgroundColor3 = if selected then color:Lerp(Color3.new(), 0.55) else T.Card,
			Text = "",
			AutoButtonColor = true,
			Parent = tabs,
		})
		UIKit.Corner(4).Parent = tab
		UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(165, 165, 165)), Parent = tab })
		UIKit.Stroke(if selected then color else Color3.fromRGB(70, 74, 62), if selected then 4 else 2).Parent = tab
		UIKit.Label({ Text = "LEVEL " .. lvl, Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 30), TextSize = 26, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, Parent = tab })
		UIKit.Label({ Text = if lvl == 1 then "Starter gun" else "In-run upgrade $" .. Util.FormatNumber(costs[lvl - 1]), Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -28, 0, 20), TextSize = 16, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = tab })
		tab.Activated:Connect(function()
			level = lvl
			self:Refresh()
		end)
	end

	local cards = UIKit.new("Frame", { Position = UDim2.fromOffset(190, 0), Size = UDim2.new(1, -190, 1, 0), BackgroundTransparency = 1, Parent = body })
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 14), Parent = cards })
	local color = GameConfig.WeaponTiers[level].Color
	local equipped = picked[level] or Weapons.DefaultFor(level)
	for _, id in Weapons.ForLevel(level) do
		local def = Weapons.List[id]
		local c = card(cards, 220, color, equipped == id, def.DisplayName)
		preview(c, UDim2.new(1, -16, 0, 112), gunModel(id, level), true).Position = UDim2.fromOffset(8, 40)
		UIKit.Label({ Text = def.Description, Position = UDim2.fromOffset(12, 158), Size = UDim2.new(1, -24, 0, 48), TextSize = 16, TextWrapped = true, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = c })
		for i, stat in STATS do
			local y = 206 + (i - 1) * 24
			UIKit.Label({ Text = stat[1], Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(80, 20), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Parent = c })
			local back = UIKit.new("Frame", { Position = UDim2.fromOffset(90, y + 6), Size = UDim2.new(1, -156, 0, 8), BackgroundColor3 = Color3.fromRGB(30, 34, 28), BorderSizePixel = 0, Parent = c })
			UIKit.Corner(4).Parent = back
			local fill = UIKit.new("Frame", { Size = UDim2.fromScale(math.clamp(stat[2](def) / statMax[i], 0.04, 1), 1), BackgroundColor3 = color, BorderSizePixel = 0, Parent = back })
			UIKit.Corner(4).Parent = fill
			UIKit.Label({ Text = stat[3](def), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, y), Size = UDim2.fromOffset(58, 20), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Right, Parent = c })
		end
		local extras = {}
		if def.Pierce > 1 then
			table.insert(extras, "Pierces " .. def.Pierce)
		end
		if def.Automatic then
			table.insert(extras, "Full-auto")
		end
		if def.SpinUp then
			table.insert(extras, "Spins up")
		end
		table.insert(extras, "Headshot ×" .. def.HeadshotMultiplier)
		UIKit.Label({ Text = table.concat(extras, " · "), Position = UDim2.fromOffset(12, 302), Size = UDim2.new(1, -24, 0, 40), TextSize = 15, TextWrapped = true, TextColor3 = T.Accent, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = c })
		actionButton(c, equipped == id, owned[id], def.GemCost, function()
			Remotes.SelectWeapon:FireServer(id)
		end, function()
			Remotes.UnlockItem:FireServer("Weapon", id)
		end)
	end
end

function ShopController:_buildClasses()
	local body = ui.Body
	local owned = decode("OwnedJson").Classes or {}
	local current = player:GetAttribute("ClassId")
	local ids = {}
	for id in Classes.List do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Classes.List[a].Order < Classes.List[b].Order
	end)
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 12), Parent = body })
	for _, id in ids do
		local def = Classes.List[id]
		local c = card(body, 168, def.Color, current == id, def.DisplayName)
		preview(c, UDim2.new(1, -16, 0, 164), ClassFigures.Build(id), false).Position = UDim2.fromOffset(8, 40)
		UIKit.Label({ Text = def.Description, Position = UDim2.fromOffset(10, 212), Size = UDim2.new(1, -20, 0, 54), TextSize = 15, TextWrapped = true, TextColor3 = T.SubText, TextYAlignment = Enum.TextYAlignment.Top, Parent = c })
		UIKit.Label({ Text = "[E] " .. def.Ability.Name, Position = UDim2.fromOffset(10, 270), Size = UDim2.new(1, -20, 0, 20), TextSize = 16, TextColor3 = T.Accent, Parent = c })
		UIKit.Label({ Text = "[F] " .. def.Ultimate.Name, Position = UDim2.fromOffset(10, 290), Size = UDim2.new(1, -20, 0, 20), TextSize = 16, TextColor3 = T.Accent, Parent = c })
		local traits = {}
		if def.HealthBonus ~= 0 then
			table.insert(traits, string.format("%+d HP", def.HealthBonus))
		end
		if def.SpeedBonus ~= 0 then
			table.insert(traits, string.format("%+d speed", def.SpeedBonus))
		end
		if def.DamageTakenMult ~= 1 then
			table.insert(traits, string.format("%d%% armor", math.floor((1 - def.DamageTakenMult) * 100 + 0.5)))
		end
		UIKit.Label({ Text = if #traits > 0 then table.concat(traits, " · ") else "Balanced", Position = UDim2.fromOffset(10, 312), Size = UDim2.new(1, -20, 0, 20), TextSize = 15, TextColor3 = T.Text, Parent = c })
		actionButton(c, current == id, owned[id], def.GemCost, function()
			Remotes.SelectClass:FireServer(id)
		end, function()
			Remotes.UnlockItem:FireServer("Class", id)
		end)
	end
end

-- ready to claim first, then closest to done, claimed last
local function sortedAchievements(stats, claimed)
	local rows = {}
	for i, def in Achievements.List do
		local progress = Achievements.Progress(def, stats)
		local rank = if claimed[def.Id] then 2 elseif progress >= def.Goal then 0 else 1
		table.insert(rows, { Def = def, Progress = progress, Rank = rank, Fraction = math.min(progress / def.Goal, 1), Order = i })
	end
	table.sort(rows, function(a, b)
		if a.Rank ~= b.Rank then
			return a.Rank < b.Rank
		end
		if a.Rank == 1 and a.Fraction ~= b.Fraction then
			return a.Fraction > b.Fraction
		end
		return a.Order < b.Order
	end)
	return rows
end

function ShopController:_buildAchievements()
	local data = decode("AchievementsJson")
	local stats, claimed = data.Stats or {}, data.Claimed or {}
	local list = UIKit.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = ui.Body,
	})
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 8), Parent = list })
	for _, row in sortedAchievements(stats, claimed) do
		local def = row.Def
		local ready, done = row.Rank == 0, row.Rank == 2
		local accent = if ready then T.Cash elseif done then T.SubText else T.Accent
		local c = UIKit.new("Frame", { Size = UDim2.new(1, -12, 0, 66), BackgroundColor3 = Color3.fromRGB(56, 54, 46), BorderSizePixel = 0, Parent = list })
		UIKit.Corner(4).Parent = c
		UIKit.Stroke(if ready then T.Cash else Color3.fromRGB(16, 18, 14), if ready then 4 else 3).Parent = c
		local edge = UIKit.new("Frame", { Size = UDim2.fromOffset(6, 66), BackgroundColor3 = accent, BorderSizePixel = 0, Parent = c })
		UIKit.Corner(4).Parent = edge
		UIKit.Label({ Text = def.Name, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -330, 0, 24), TextSize = 21, TextColor3 = accent, TextXAlignment = Enum.TextXAlignment.Left, Parent = c })
		UIKit.Label({ Text = def.Desc, Position = UDim2.fromOffset(14, 34), Size = UDim2.new(1, -330, 0, 20), TextSize = 16, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = c })
		local back = UIKit.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -170, 0, 18), Size = UDim2.fromOffset(140, 10), BackgroundColor3 = Color3.fromRGB(30, 34, 28), BorderSizePixel = 0, Parent = c })
		UIKit.Corner(5).Parent = back
		local fill = UIKit.new("Frame", { Size = UDim2.fromScale(math.max(row.Fraction, 0.03), 1), BackgroundColor3 = accent, BorderSizePixel = 0, Parent = back })
		UIKit.Corner(5).Parent = fill
		UIKit.Label({ Text = Util.FormatNumber(math.min(row.Progress, def.Goal)) .. " / " .. Util.FormatNumber(def.Goal), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -170, 0, 34), Size = UDim2.fromOffset(140, 20), TextSize = 15, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Right, Parent = c })
		local button = UIKit.Button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(140, 42), TextSize = 20, Parent = c })
		UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 150)), Parent = button })
		local bc = button:FindFirstChildOfClass("UICorner")
		if bc then
			bc:Destroy()
		end
		UIKit.Corner(4).Parent = button
		UIKit.Stroke(Color3.fromRGB(18, 20, 16), 3).Parent = button
		if ready then
			button.Text = "CLAIM ◆" .. def.Gems
			button.BackgroundColor3 = T.Cash
			button.TextColor3 = Color3.fromRGB(20, 30, 20)
			button.Activated:Connect(function()
				Remotes.ClaimAchievement:FireServer(def.Id)
			end)
		else
			button.Text = if done then "CLAIMED" else "◆ " .. def.Gems
			button.BackgroundColor3 = T.Disabled
			button.TextColor3 = if done then T.SubText else T.Gem
			button.AutoButtonColor = false
		end
	end
end

-- "N READY TO CLAIM" on the lobby board's status sign (Workspace.OurMap.Lobby.Commendations.Status)
local function updateBoardSign()
	local data = decode("AchievementsJson")
	local stats, claimed = data.Stats or {}, data.Claimed or {}
	local ready = 0
	for _, def in Achievements.List do
		if not claimed[def.Id] and Achievements.Progress(def, stats) >= def.Goal then
			ready += 1
		end
	end
	local map = workspace:FindFirstChild(GameConfig.OurMap.Folder)
	local status = map and map:FindFirstChild("Lobby") and map.Lobby:FindFirstChild("Commendations")
	status = status and status:FindFirstChild("Status")
	local label = status and status:FindFirstChildOfClass("SurfaceGui") and status:FindFirstChildOfClass("SurfaceGui"):FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = if ready > 0 then ready .. " READY TO CLAIM" else "KEEP FIGHTING"
		label.TextColor3 = if ready > 0 then T.Cash else T.SubText
	end
end

function ShopController:Refresh()
	if not openShop then
		return
	end
	table.clear(spinning)
	clear(ui.Body)
	ui.Gems.Text = "◆ " .. Util.FormatNumber(player:GetAttribute("Gems") or 0)
	if openShop == "Armory" then
		ui.Title.Text = "ARMORY"
		ui.Subtitle.Text = "Pick one gun for each level. A run starts on Level 1; upgrade in-run with cash."
		self:_buildArmory()
	elseif openShop == "Achievements" then
		ui.Title.Text = "COMMENDATIONS"
		ui.Subtitle.Text = "Lifetime goals. Finish one, then claim its Gems here."
		self:_buildAchievements()
	else
		ui.Title.Text = "BARRACKS"
		ui.Subtitle.Text = "Choose your class. Each has an ability [E] and an ultimate [F]."
		self:_buildClasses()
	end
end

function ShopController:Open(shop, fromPart)
	openShop, anchor = shop, fromPart
	self:Refresh()
	ui.Gui.Enabled = true
	ui.Scale.Scale = 0.92
	TweenService:Create(ui.Scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

function ShopController:Close()
	openShop, anchor = nil, nil
	ui.Gui.Enabled = false
	table.clear(spinning)
	clear(ui.Body)
end

function ShopController:IsOpen()
	return openShop ~= nil
end

function ShopController:Init()
	local gui = UIKit.Screen("Shop")
	gui.DisplayOrder = 8
	gui.Enabled = false
	ui.Gui = gui
	UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(), BackgroundTransparency = 0.45, BorderSizePixel = 0, Parent = gui })
	local fit = UIKit.new("Frame", { BackgroundTransparency = 1, Parent = gui }) -- shrinks the 960 px shop on small screens
	UIKit.AutoScale(fit)
	UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1000, 570), BackgroundColor3 = Color3.new(), BackgroundTransparency = 0.35, BorderSizePixel = 0, Parent = fit })
	local panel = UIKit.Panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(960, 530), BackgroundTransparency = 0.05, Parent = fit })
	panel.BackgroundColor3 = Color3.fromRGB(34, 32, 26)
	UIKit.Stroke(TITLE, 3).Parent = panel
	local pc = panel:FindFirstChildOfClass("UICorner")
	if pc then
		pc:Destroy()
	end
	UIKit.Corner(4).Parent = panel
	ui.Scale = UIKit.new("UIScale", { Parent = panel })
	UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(960, 530), Parent = panel })
	local header = UIKit.new("Frame", { Position = UDim2.fromOffset(14, 14), Size = UDim2.new(1, -28, 0, 92), BackgroundColor3 = Color3.fromRGB(22, 24, 18), BorderSizePixel = 0, Parent = panel })
	UIKit.Corner(4).Parent = header
	UIKit.new("Frame", { Size = UDim2.fromOffset(6, 92), BackgroundColor3 = TITLE, BorderSizePixel = 0, Parent = header })
	ui.Title = UIKit.Label({ Position = UDim2.fromOffset(24, 10), Size = UDim2.fromOffset(430, 48), TextSize = 40, TextColor3 = TITLE, TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
	ui.Subtitle = UIKit.Label({ Position = UDim2.fromOffset(24, 60), Size = UDim2.new(1, -270, 0, 24), TextSize = 17, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
	ui.Gems = UIKit.Label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -76, 0, 22), Size = UDim2.fromOffset(160, 30), TextSize = 26, TextColor3 = T.Gem, TextXAlignment = Enum.TextXAlignment.Right, Parent = panel })
	local closeButton = UIKit.Button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -22, 0, 22), Size = UDim2.fromOffset(40, 40), Text = "X", TextSize = 22, BackgroundColor3 = T.Danger, TextColor3 = T.Text, Parent = panel }, function()
		self:Close()
	end)
	local xc = closeButton:FindFirstChildOfClass("UICorner")
	if xc then
		xc:Destroy()
	end
	UIKit.Corner(4).Parent = closeButton
	UIKit.Stroke(Color3.fromRGB(18, 20, 16), 3).Parent = closeButton
	ui.Body = UIKit.new("Frame", { Name = "Body", Position = UDim2.fromOffset(24, 120), Size = UDim2.new(1, -48, 1, -140), BackgroundTransparency = 1, Parent = panel })
	panel.Name = "Panel"

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local shop = prompt:GetAttribute("Shop")
		if shop and player:GetAttribute("InRun") ~= true then
			self:Open(shop, prompt.Parent)
		end
	end)
	for _, attr in { "Gems", "OwnedJson", "ClassId", "LoadoutJson", "AchievementsJson" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			if attr ~= "AchievementsJson" or openShop == "Achievements" then
				self:Refresh()
			end
		end)
	end
	player:GetAttributeChangedSignal("AchievementsJson"):Connect(updateBoardSign)
	task.spawn(function() -- the board may stream in after the attribute arrives
		while true do
			updateBoardSign()
			task.wait(3)
		end
	end)
	RunService.RenderStepped:Connect(function()
		if not openShop then
			return
		end
		-- close on run start or when the player walks away from the shop
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if player:GetAttribute("InRun") or not root or (anchor and (root.Position - anchor.Position).Magnitude > 18) then
			self:Close()
			return
		end
		local t = os.clock()
		for _, entry in spinning do
			local angle = if entry.Sway then math.sin(t * 0.9) * 0.45 else t * 0.8
			local pivot = CFrame.new(entry.Center) * CFrame.Angles(0, angle, 0) * CFrame.new(entry.Center):Inverse()
			entry.Model:PivotTo(pivot * entry.Base)
		end
	end)
end

return ShopController
