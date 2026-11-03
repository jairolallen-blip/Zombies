-- HUDController: the in-run HUD. Visible only while the player attribute InRun is true.
-- Layout (by priority, see research/03-ui-ux.md):
--   cursor        crosshair + hitmarker (follow the free mouse; aim = CameraController:GetAimPoint)
--   top centre    wave / phase text, big banner on wave start, boss bar
--   bottom left   health bar, Ability [E] and Ultimate [F] slots
--   bottom right  weapon card (level stripe, name, ammo + mag bar), Cash chip
--                 upgrade buttons above it: [1] weapon level, [2] vitality (lit green when affordable)
--   top right     toast messages (Remotes.Notify)
-- Everything refreshes in one RenderStepped loop from attributes (player + GameState).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Classes = require(Shared.Config.Classes)
local Weapons = require(Shared.Config.Weapons)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)
local GameState = require(Shared.GameState)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local ReadyFx = require(script.Parent.Parent.UI.ReadyFx)

local T = UIKit.Theme
local player = Players.LocalPlayer

local HUDController = {}
local Controllers
local ui = {}
local crosshairGap = 0
local lastHealth = nil

-- Weapon id the player picked for a Level in the lobby (LoadoutJson attribute)
local function nextLoadoutGun(level)
	local HttpService = game:GetService("HttpService")
	local ok, loadout = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("LoadoutJson") or "[]")
	return (ok and type(loadout) == "table" and loadout[level]) or Weapons.DefaultFor(level)
end

local function keyName(keyCode)
	local names = { One = "1", Two = "2", Three = "3", Four = "4" }
	return names[keyCode.Name] or keyCode.Name
end

local function bar(parent, props, fillColor)
	local back = UIKit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(30, 34, 28),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Parent = parent,
	})
	for k, v in props do
		back[k] = v
	end
	UIKit.Corner(4).Parent = back
	UIKit.Stroke(Color3.fromRGB(18, 20, 16), 2).Parent = back
	local fill = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = fillColor, BorderSizePixel = 0, Parent = back })
	UIKit.Corner(4).Parent = fill
	return back, fill
end

local function abilitySlot(parent, key, position)
	local slot = UIKit.Panel({ Size = UDim2.fromOffset(150, 64), Position = position, Parent = parent })
	UIKit.Label({ Text = key, Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(8, 15), TextSize = 22, BackgroundTransparency = 0, BackgroundColor3 = T.Card, TextColor3 = T.Accent, Parent = slot })
	local keyPlate = slot:FindFirstChild("TextLabel")
	if keyPlate then
		UIKit.Stroke(Color3.fromRGB(18, 20, 16), 2).Parent = keyPlate
	end
	local name = UIKit.Label({ Size = UDim2.new(1, -54, 0, 26), Position = UDim2.fromOffset(50, 8), TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Parent = slot })
	local status = UIKit.Label({ Size = UDim2.new(1, -54, 0, 20), Position = UDim2.fromOffset(50, 34), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.SubText, Parent = slot })
	local _, fill = bar(slot, { Size = UDim2.new(1, -16, 0, 4), Position = UDim2.new(0, 8, 1, -7) }, T.Accent)
	return { Frame = slot, Name = name, Status = status, Fill = fill }
end

function HUDController:Init(controllers)
	Controllers = controllers
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)
	local gui = UIKit.Screen("HUD")
	self.Gui = gui
	ui.Root = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	local root = ui.Root
	ui.Scale = UIKit.AutoScale(root)

	-- Crosshair
	ui.Crosshair = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(2, 2), BackgroundTransparency = 1, Parent = root })
	ui.CrossLines = {}
	for _, dir in { Vector2.new(1, 0), Vector2.new(-1, 0), Vector2.new(0, 1), Vector2.new(0, -1) } do
		local line = UIKit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = if dir.X ~= 0 then UDim2.fromOffset(10, 2) else UDim2.fromOffset(2, 10),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = ui.Crosshair,
		})
		UIKit.Stroke(Color3.new(0, 0, 0), 1).Parent = line
		table.insert(ui.CrossLines, { Frame = line, Dir = dir })
	end
	ui.Hitmarker = UIKit.Label({ Text = "X", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30), TextSize = 26, TextTransparency = 1, Parent = root })
	-- Scope view (scoped guns while aiming, ViewmodelController:IsScoped): a clear circle with a huge
	-- black stroke as the vignette, plus a fine reticle
	ui.Scope = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.86), SizeConstraint = Enum.SizeConstraint.RelativeYY, BackgroundTransparency = 1, Visible = false, ZIndex = 0, Parent = root })
	UIKit.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = ui.Scope })
	UIKit.new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 3000, Parent = ui.Scope })
	for _, horizontal in { true, false } do
		UIKit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = if horizontal then UDim2.new(1, 0, 0, 2) else UDim2.new(0, 2, 1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Parent = ui.Scope,
		})
	end
	UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = Color3.fromRGB(255, 60, 50), BorderSizePixel = 0, Parent = ui.Scope })

	-- Top centre
	ui.Wave = UIKit.Label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(300, 40), TextSize = 36, Text = "WAVE 1", Parent = root })
	ui.SubInfo = UIKit.Label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52), Size = UDim2.fromOffset(400, 26), TextSize = 20, TextColor3 = T.SubText, Parent = root })
	ui.Banner = UIKit.Label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(800, 80), TextSize = 64, TextTransparency = 1, Parent = root })
	ui.Banner.UIStroke.Thickness = 3
	ui.Boss = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 84), Size = UDim2.fromOffset(460, 40), BackgroundTransparency = 1, Visible = false, Parent = root })
	ui.BossName = UIKit.Label({ Size = UDim2.new(1, 0, 0, 20), TextSize = 18, TextColor3 = T.Danger, Parent = ui.Boss })
	_, ui.BossFill = bar(ui.Boss, { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 22) }, T.Danger)

	-- Bottom left: health + abilities
	ui.HealthBack, ui.HealthFill = bar(root, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -96), Size = UDim2.fromOffset(310, 26) }, T.Health)
	ui.HealthText = UIKit.Label({ Size = UDim2.fromScale(1, 1), TextSize = 18, ZIndex = 2, Parent = ui.HealthBack })
	ui.Ability = abilitySlot(root, keyName(GameConfig.Keybinds.Ability), UDim2.new(0, 20, 1, -84))
	ui.Ultimate = abilitySlot(root, keyName(GameConfig.Keybinds.Ultimate), UDim2.new(0, 180, 1, -84))
	ui.Ability.Frame.AnchorPoint = Vector2.new(0, 0)
	ui.Ultimate.Frame.AnchorPoint = Vector2.new(0, 0)

	-- Teammate strip (above own health): mini health per teammate, DOWN while they wait for the wave respawn
	ui.TeamStrip = UIKit.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -128), Size = UDim2.new(0, 310, 0, 0), BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Visible = false, Parent = root })
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = ui.TeamStrip })
	ui.Teammates = {}

	-- Reload prompt under the crosshair (aim-adjacent, per the free-cursor HUD)
	ui.ReloadHint = UIKit.Label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 26), Size = UDim2.fromOffset(240, 24), TextSize = 20, TextColor3 = T.Danger, TextTransparency = 1, Parent = root })

	-- Bottom right, stacked upwards: weapon card (level stripe, name, big ammo + mag bar), Cash chip,
	-- upgrade buttons
	local weaponPanel = UIKit.Panel({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20), Size = UDim2.fromOffset(280, 96), Parent = root })
	ui.LevelStripe = UIKit.new("Frame", { Size = UDim2.new(0, 6, 1, 0), BorderSizePixel = 0, Parent = weaponPanel })
	UIKit.Corner(4).Parent = ui.LevelStripe
	ui.WeaponName = UIKit.Label({ Position = UDim2.fromOffset(18, 6), Size = UDim2.new(1, -78, 0, 24), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Parent = weaponPanel })
	ui.Level = UIKit.Label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 6), Size = UDim2.fromOffset(56, 24), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Right, Parent = weaponPanel })
	ui.Ammo = UIKit.Label({ Position = UDim2.fromOffset(18, 30), Size = UDim2.new(1, -100, 0, 44), TextSize = 44, TextXAlignment = Enum.TextXAlignment.Right, Parent = weaponPanel })
	ui.AmmoMax = UIKit.Label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 46), Size = UDim2.fromOffset(72, 24), TextSize = 20, TextColor3 = T.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = weaponPanel })
	_, ui.MagFill = bar(weaponPanel, { Position = UDim2.new(0, 18, 1, -16), Size = UDim2.new(1, -30, 0, 6) }, T.Text)
	local cashChip = UIKit.Panel({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -124), Size = UDim2.fromOffset(150, 36), Parent = root })
	ui.Cash = UIKit.Label({ Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), TextSize = 26, TextColor3 = T.Cash, TextXAlignment = Enum.TextXAlignment.Right, Parent = cashChip })

	-- Upgrade buttons above the Cash chip (click, or press the hotkey on the key plate); they light
	-- up green when affordable
	local upgrades = UIKit.new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -168), Size = UDim2.fromOffset(280, 92), BackgroundTransparency = 1, Parent = root })
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Bottom, Parent = upgrades })
	local function upgradeRow(upgradeId, key)
		local row = UIKit.Panel({ Size = UDim2.new(1, 0, 0, 42), Parent = upgrades })
		local plate = UIKit.Label({ Text = key, Position = UDim2.fromOffset(7, 7), Size = UDim2.fromOffset(28, 28), TextSize = 18, BackgroundTransparency = 0, BackgroundColor3 = T.Card, TextColor3 = T.Accent, Parent = row })
		UIKit.Corner(4).Parent = plate
		local label = UIKit.Label({ Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -124, 1, 0), TextSize = 16, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		local price = UIKit.Label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.new(0, 76, 1, 0), TextSize = 19, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
		local button = UIKit.new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 3, Parent = row })
		button.Activated:Connect(function()
			Remotes.BuyUpgrade:FireServer(upgradeId)
		end)
		return { Frame = row, Label = label, Price = price }
	end
	ui.UpgradeWeapon = upgradeRow("Weapon", keyName(GameConfig.Keybinds.UpgradeWeapon))
	ui.UpgradeVitality = upgradeRow("Vitality", keyName(GameConfig.Keybinds.UpgradeVitality))

	-- Toasts (own root: they also show in the lobby, where the HUD root is hidden)
	local toastRoot = UIKit.new("Frame", { BackgroundTransparency = 1, Parent = gui })
	UIKit.AutoScale(toastRoot)
	ui.Toasts = UIKit.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 68), -- below Roblox's top bar (health, menu)
		 Size = UDim2.fromOffset(360, 300), BackgroundTransparency = 1, Parent = toastRoot })
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = ui.Toasts })

	-- Damage vignette
	ui.Vignette = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Danger, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 0, Parent = root })
	UIKit.new("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.35, 1), NumberSequenceKeypoint.new(0.65, 1), NumberSequenceKeypoint.new(1, 0) }),
		Parent = ui.Vignette,
	})

	-- Events
	Remotes.Notify.OnClientEvent:Connect(function(text, kind)
		self:Toast(text, kind)
	end)
	Remotes.HitConfirm.OnClientEvent:Connect(function(hits)
		local killed = false
		for _, hit in hits do
			killed = killed or hit.Killed
		end
		ui.Hitmarker.TextColor3 = if killed then T.Danger else Color3.new(1, 1, 1)
		ui.Hitmarker.TextTransparency = 0
		TweenService:Create(ui.Hitmarker, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
	end)
	GameState:GetAttributeChangedSignal("Phase"):Connect(function()
		if GameState:GetAttribute("Phase") == "Wave" then
			local wave = GameState:GetAttribute("Wave")
			self:ShowBanner(if wave >= (GameState:GetAttribute("TotalWaves") or GameConfig.Waves.TotalWaves) then "FINAL WAVE" else "WAVE " .. wave, T.Text)
		elseif GameState:GetAttribute("Phase") == "Break" and (GameState:GetAttribute("Wave") or 0) > 1 then
			self:ShowBanner("WAVE CLEARED", T.Cash)
		end
	end)

	-- the boss rises after its warning circle, so announce it when it actually appears
	GameState:GetAttributeChangedSignal("BossName"):Connect(function()
		local boss = GameState:GetAttribute("BossName")
		if boss ~= "" then
			self:ShowBanner(boss:upper() .. " APPROACHES", T.Danger)
		end
	end)
	GameState:GetAttributeChangedSignal("BossEnraged"):Connect(function()
		if GameState:GetAttribute("BossEnraged") then
			self:ShowBanner("THE TITAN IS ENRAGED", T.Danger)
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		self:_update(dt)
	end)
end

function HUDController:KickCrosshair()
	crosshairGap = math.min(crosshairGap + 6, 18)
end

function HUDController:ShowBanner(text, color)
	local banner = ui.Banner
	banner.Text = text
	banner.TextColor3 = color or T.Text
	banner.TextTransparency = 0
	banner.UIStroke.Transparency = 0.2
	banner.Size = UDim2.fromOffset(900, 100)
	TweenService:Create(banner, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(800, 80) }):Play()
	task.delay(1.6, function()
		if banner.Text == text then
			TweenService:Create(banner, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			TweenService:Create(banner.UIStroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end
	end)
end

function HUDController:Toast(text, kind)
	local color = if kind == "Danger" then T.Danger elseif kind == "Good" then T.Cash else T.Text
	local toast = UIKit.Panel({ Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, Parent = ui.Toasts })
	UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = toast })
	UIKit.Label({ Text = text, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, TextSize = 18, TextColor3 = color, Parent = toast })
	task.delay(2.5, function()
		toast:Destroy()
	end)
end

function HUDController:_update(dt)
	local inRun = player:GetAttribute("InRun") == true
	ui.Root.Visible = inRun and player:GetAttribute("Deploying") ~= true -- hidden during the drop-in
	if not ui.Root.Visible then
		return
	end
	local now = workspace:GetServerTimeNow()

	-- Crosshair + hitmarker follow the (free) mouse cursor
	local mouse = Controllers.CameraController:GetMouseLocation() / ui.Scale.Scale -- screen px -> scaled root px
	ui.Crosshair.Position = UDim2.fromOffset(mouse.X, mouse.Y)
	ui.Hitmarker.Position = UDim2.fromOffset(mouse.X, mouse.Y)
	crosshairGap = math.max(0, crosshairGap - dt * 60)
	local weapon = Controllers.WeaponController:GetState()
	local baseGap = 6 + (if weapon.Stats then weapon.Stats.Spread * 2 else 0)
	local viewmodel = Controllers.ViewmodelController
	local aim = if viewmodel.GetAim then viewmodel:GetAim() else 0 -- older ViewmodelController has no aim-down-sights
	for _, line in ui.CrossLines do
		local gap = (baseGap + crosshairGap) * (1 - 0.6 * aim)
		line.Frame.Position = UDim2.fromOffset(line.Dir.X * gap, line.Dir.Y * gap)
		line.Frame.BackgroundTransparency = aim -- the sights take over while aiming
		line.Frame.Visible = aim < 0.98
	end
	ui.Scope.Visible = if viewmodel.IsScoped then viewmodel:IsScoped() else false
	ui.Scope.Position = ui.Crosshair.Position
	ui.ReloadHint.Position = UDim2.fromOffset(mouse.X, mouse.Y + 26)

	-- Wave info
	local phase = GameState:GetAttribute("Phase")
	ui.Wave.Text = "WAVE " .. (GameState:GetAttribute("Wave") or 0) .. " / " .. (GameState:GetAttribute("TotalWaves") or GameConfig.Waves.TotalWaves)
	if phase == "Break" and (GameState:GetAttribute("Wave") or 0) <= 1 then
		ui.SubInfo.Text = "Zombies inbound in " .. (GameState:GetAttribute("Timer") or 0) .. "s  —  find cover!"
	elseif phase == "Break" then
		ui.SubInfo.Text = "Next wave in " .. (GameState:GetAttribute("Timer") or 0) .. "s  —  spend your Cash!"
	elseif phase == "Wave" then
		ui.SubInfo.Text = (GameState:GetAttribute("ZombiesLeft") or 0) .. " zombies left"
	elseif phase == "Results" then
		ui.SubInfo.Text = if GameState:GetAttribute("RunWon") then "Victory! Extraction inbound" else "Overrun!"
	else
		ui.SubInfo.Text = "" -- no stale text from the last run during the drop-in
	end
	local bossMax = GameState:GetAttribute("BossMaxHealth") or 0
	ui.Boss.Visible = bossMax > 0
	if bossMax > 0 then
		ui.BossName.Text = GameState:GetAttribute("BossName")
		ui.BossFill.Size = UDim2.fromScale(math.clamp((GameState:GetAttribute("BossHealth") or 0) / bossMax, 0, 1), 1)
	end

	-- Health
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local health, maxHealth = math.max(0, humanoid.Health), humanoid.MaxHealth
		ui.HealthFill.Size = UDim2.fromScale(math.clamp(health / maxHealth, 0, 1), 1)
		ui.HealthFill.BackgroundColor3 = if health / maxHealth < 0.3 then T.Danger else T.Health
		ui.HealthText.Text = if health > 0 then math.ceil(health) .. " / " .. maxHealth else "DOWN — wait for next wave"
		if lastHealth and health < lastHealth then
			ui.Vignette.BackgroundTransparency = 0.35
		end
		lastHealth = health
	end
	ui.Vignette.BackgroundTransparency = math.min(1, ui.Vignette.BackgroundTransparency + dt * 1.5)

	-- Teammates: one row each while InRun, refreshed from replicated humanoids
	local seen = 0
	for _, plr in Players:GetPlayers() do
		if plr == player or plr:GetAttribute("InRun") ~= true then
			continue
		end
		seen += 1
		local entry = ui.Teammates[plr]
		if not entry then
			local row = UIKit.new("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = T.Card, BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = ui.TeamStrip })
			UIKit.Corner(4).Parent = row
			UIKit.Stroke(Color3.fromRGB(18, 20, 16), 2).Parent = row
			local name = UIKit.Label({ Size = UDim2.new(0, 110, 1, 0), Position = UDim2.fromOffset(8, 0), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.SubText, Parent = row })
			local _, fill = bar(row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(1, -126, 0, 8) }, T.Health)
			local status = UIKit.Label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.new(1, -126, 1, 0), TextSize = 12, ZIndex = 2, Parent = row })
			entry = { Frame = row, Name = name, Fill = fill, Status = status }
			entry.Name.Text = plr.DisplayName
			ui.Teammates[plr] = entry
		end
		local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		local hp = hum and hum.Health or 0
		local maxHp = (hum and hum.MaxHealth) or 1
		entry.Fill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
		entry.Fill.BackgroundColor3 = if hp / maxHp < 0.3 then T.Danger else T.Health
		entry.Status.Text = if hp <= 0 then "DOWN" else math.ceil(hp)
		entry.Status.TextColor3 = if hp <= 0 then T.Danger else T.Text
	end
	for plr, entry in ui.Teammates do
		if not plr.Parent or plr:GetAttribute("InRun") ~= true then
			entry.Frame:Destroy()
			ui.Teammates[plr] = nil
		end
	end
	ui.TeamStrip.Visible = seen > 0

	-- Abilities
	local class = Classes.List[player:GetAttribute("ClassId")] or Classes.List[Classes.Default]
	local remaining = (player:GetAttribute("AbilityReadyAt") or 0) - now
	ui.Ability.Name.Text = class.Ability.Name
	ui.Ability.Status.Text = if remaining > 0 then string.format("%.1fs", remaining) else "READY"
	ui.Ability.Status.TextColor3 = if remaining > 0 then T.SubText else T.Cash
	local early = class.Ability.EarlyWaves and (GameState:GetAttribute("Wave") or 0) <= class.Ability.EarlyWaves
	ui.Ability.Fill.Size = UDim2.fromScale(1 - math.clamp(remaining / (if early then class.Ability.EarlyCooldown else class.Ability.Cooldown), 0, 1), 1)
	local charge = player:GetAttribute("UltCharge") or 0
	local max = GameConfig.Ultimate.Max
	ui.Ultimate.Name.Text = class.Ultimate.Name
	ui.Ultimate.Status.Text = if charge >= max then "READY" else math.floor(charge / max * 100) .. "%"
	ui.Ultimate.Status.TextColor3 = if charge >= max then T.Accent else T.SubText
	ui.Ultimate.Fill.Size = UDim2.fromScale(math.clamp(charge / max, 0, 1), 1)
	-- ready cues on the slots: pop, ring, small READY tag, breathing glow, reminders (UI/ReadyFx)
	ReadyFx.Update(ui.Ability, remaining <= 0, { Color = T.Cash, Key = keyName(GameConfig.Keybinds.Ability) })
	ReadyFx.Update(ui.Ultimate, charge >= max, { Color = T.Accent, Key = keyName(GameConfig.Keybinds.Ultimate), Big = true })

	-- Weapon + cash
	local cash = player:GetAttribute("Cash") or 0
	ui.Cash.Text = "$" .. Util.FormatNumber(cash)
	if weapon.Stats then
		ui.WeaponName.Text = weapon.Stats.DisplayName
		ui.Level.Text = "LV " .. weapon.Stats.Tier
		ui.Level.TextColor3 = weapon.Stats.TierColor
		ui.LevelStripe.BackgroundColor3 = weapon.Stats.TierColor
		ui.AmmoMax.Text = "/ " .. weapon.Stats.MagSize
		local lowAmmo = math.ceil(weapon.Stats.MagSize * 0.25)
		local ammoColor = if weapon.Reloading then T.Accent elseif weapon.Ammo == 0 then T.Danger elseif weapon.Ammo <= lowAmmo then T.Accent else T.Text
		ui.Ammo.Text = if weapon.Reloading then "RELOADING" else tostring(weapon.Ammo)
		ui.Ammo.TextSize = if weapon.Reloading then 26 else 44
		ui.Ammo.TextColor3 = ammoColor
		ui.MagFill.Size = UDim2.fromScale(if weapon.Reloading then 0 else math.clamp(weapon.Ammo / weapon.Stats.MagSize, 0, 1), 1)
		ui.MagFill.BackgroundColor3 = ammoColor
		if weapon.Reloading then
			ui.ReloadHint.Text = "RELOADING"
			ui.ReloadHint.TextColor3 = T.Accent
			ui.ReloadHint.TextTransparency = 0
		elseif weapon.Ammo == 0 then
			ui.ReloadHint.Text = "RELOAD [" .. keyName(GameConfig.Keybinds.Reload) .. "]"
			ui.ReloadHint.TextColor3 = T.Danger
			ui.ReloadHint.TextTransparency = 0
		else
			ui.ReloadHint.TextTransparency = 1
		end
	else
		ui.ReloadHint.TextTransparency = 1
	end

	-- Upgrades
	-- upgrades are for the Break; dim them mid-wave so the buy phase owns the screen
	local dim = if phase == "Wave" then 0.55 else T.PanelTransparency
	ui.UpgradeWeapon.Frame.BackgroundTransparency = dim
	ui.UpgradeVitality.Frame.BackgroundTransparency = dim
	local lit = Color3.fromRGB(46, 78, 32) -- dark Cash green behind an affordable upgrade
	local function showUpgrade(row, id, level, label)
		local cost = Util.GetUpgradeCost(id, level)
		local affordable = cost ~= nil and cash >= cost
		row.Label.Text = label
		row.Label.TextColor3 = if affordable then T.Text else T.SubText
		row.Price.Text = if cost then "$" .. Util.FormatNumber(cost) else "MAX"
		row.Price.TextColor3 = if not cost then T.Accent elseif affordable then T.Cash else T.SubText
		if row._affordable == false and affordable then
			row._flashAt = os.clock() -- flash bright the moment it becomes affordable
		end
		row._affordable = if cost then affordable else nil
		local flash = 1 - math.clamp((os.clock() - (row._flashAt or 0)) / 0.6, 0, 1)
		row.Frame.BackgroundColor3 = (if affordable then lit else T.Panel):Lerp(T.Cash, flash)
		row.Frame.UIStroke.Color = if affordable then T.Cash else Color3.fromRGB(18, 20, 16)
	end
	local tier = player:GetAttribute("WeaponTier") or 1
	local vitality = player:GetAttribute("VitalityLevel") or 0
	local nextGun = tier < Weapons.Levels and Weapons.List[nextLoadoutGun(tier + 1)]
	showUpgrade(ui.UpgradeWeapon, "Weapon", tier, if nextGun then "Lv " .. (tier + 1) .. ": " .. nextGun.DisplayName else "Weapon")
	showUpgrade(ui.UpgradeVitality, "Vitality", vitality, "Vitality +" .. GameConfig.Upgrades.Vitality.HealthPerLevel .. " HP")
end

return HUDController
