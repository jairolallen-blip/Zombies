-- HUDController: the in-run HUD. Visible only while the player attribute InRun is true.
-- Layout (by priority, see research/03-ui-ux.md):
--   cursor        crosshair + hitmarker (follow the free mouse; aim = CameraController:GetAimPoint)
--   top centre    wave / phase text, big banner on wave start, boss bar
--   bottom left   health bar, Ability [E] and Ultimate [F] slots
--   bottom right  weapon name + tier, ammo, Cash
--   right         upgrade prompts [1] weapon tier, [2] vitality (price + affordability)
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
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)
local GameState = require(Shared.GameState)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local T = UIKit.Theme
local player = Players.LocalPlayer

local HUDController = {}
local Controllers
local ui = {}
local crosshairGap = 0
local lastHealth = nil

local function keyName(keyCode)
	local names = { One = "1", Two = "2", Three = "3", Four = "4" }
	return names[keyCode.Name] or keyCode.Name
end

local function bar(parent, props, fillColor)
	local back = UIKit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(15, 15, 18),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Parent = parent,
	})
	for k, v in props do
		back[k] = v
	end
	UIKit.Corner(6).Parent = back
	local fill = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = fillColor, BorderSizePixel = 0, Parent = back })
	UIKit.Corner(6).Parent = fill
	return back, fill
end

local function abilitySlot(parent, key, position)
	local slot = UIKit.Panel({ Size = UDim2.fromOffset(150, 64), Position = position, Parent = parent })
	UIKit.Label({ Text = key, Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(8, 15), TextSize = 22, BackgroundTransparency = 0, BackgroundColor3 = T.Card, TextColor3 = T.Accent, Parent = slot })
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

	-- Bottom right: weapon + ammo + cash
	local weaponPanel = UIKit.Panel({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20), Size = UDim2.fromOffset(260, 110), Parent = root })
	ui.Cash = UIKit.Label({ Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 34), TextSize = 30, TextColor3 = T.Cash, TextXAlignment = Enum.TextXAlignment.Right, Parent = weaponPanel })
	ui.WeaponName = UIKit.Label({ Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -28, 0, 24), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Right, Parent = weaponPanel })
	ui.Ammo = UIKit.Label({ Position = UDim2.fromOffset(14, 66), Size = UDim2.new(1, -28, 0, 36), TextSize = 32, TextXAlignment = Enum.TextXAlignment.Right, Parent = weaponPanel })

	-- Right: upgrade prompts
	local upgrades = UIKit.new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -140), Size = UDim2.fromOffset(260, 76), BackgroundTransparency = 1, Parent = root })
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Bottom, Parent = upgrades })
	local function upgradeRow()
		local row = UIKit.Panel({ Size = UDim2.new(1, 0, 0, 34), Parent = upgrades })
		local label = UIKit.Label({ Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		return { Frame = row, Label = label }
	end
	ui.UpgradeWeapon = upgradeRow()
	ui.UpgradeVitality = upgradeRow()

	-- Toasts
	ui.Toasts = UIKit.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 20), Size = UDim2.fromOffset(360, 300), BackgroundTransparency = 1, Parent = gui })
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
			local boss = GameState:GetAttribute("BossName")
			self:ShowBanner("WAVE " .. GameState:GetAttribute("Wave"), T.Text)
			if boss ~= "" then
				task.delay(1.2, function()
					self:ShowBanner(boss:upper() .. " APPROACHES", T.Danger)
				end)
			end
		elseif GameState:GetAttribute("Phase") == "Break" and (GameState:GetAttribute("Wave") or 0) > 1 then
			self:ShowBanner("WAVE CLEARED", T.Cash)
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
	ui.Root.Visible = inRun
	if not inRun then
		return
	end
	local now = workspace:GetServerTimeNow()

	-- Crosshair + hitmarker follow the (free) mouse cursor
	local mouse = Controllers.CameraController:GetMouseLocation()
	ui.Crosshair.Position = UDim2.fromOffset(mouse.X, mouse.Y)
	ui.Hitmarker.Position = UDim2.fromOffset(mouse.X, mouse.Y)
	crosshairGap = math.max(0, crosshairGap - dt * 60)
	local weapon = Controllers.WeaponController:GetState()
	local baseGap = 6 + (if weapon.Stats then weapon.Stats.Spread * 2 else 0)
	for _, line in ui.CrossLines do
		local gap = baseGap + crosshairGap
		line.Frame.Position = UDim2.fromOffset(line.Dir.X * gap, line.Dir.Y * gap)
	end

	-- Wave info
	local phase = GameState:GetAttribute("Phase")
	ui.Wave.Text = "WAVE " .. (GameState:GetAttribute("Wave") or 0)
	if phase == "Break" then
		ui.SubInfo.Text = "Next wave in " .. (GameState:GetAttribute("Timer") or 0) .. "s  —  spend your Cash!"
	elseif phase == "Wave" then
		ui.SubInfo.Text = (GameState:GetAttribute("ZombiesLeft") or 0) .. " zombies left"
	elseif phase == "Results" then
		ui.SubInfo.Text = "Overrun!"
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

	-- Abilities
	local class = Classes.List[player:GetAttribute("ClassId")] or Classes.List[Classes.Default]
	local remaining = (player:GetAttribute("AbilityReadyAt") or 0) - now
	ui.Ability.Name.Text = class.Ability.Name
	ui.Ability.Status.Text = if remaining > 0 then string.format("%.1fs", remaining) else "READY"
	ui.Ability.Status.TextColor3 = if remaining > 0 then T.SubText else T.Cash
	ui.Ability.Fill.Size = UDim2.fromScale(1 - math.clamp(remaining / class.Ability.Cooldown, 0, 1), 1)
	local charge = player:GetAttribute("UltCharge") or 0
	local max = GameConfig.Ultimate.Max
	ui.Ultimate.Name.Text = class.Ultimate.Name
	ui.Ultimate.Status.Text = if charge >= max then "READY" else math.floor(charge / max * 100) .. "%"
	ui.Ultimate.Status.TextColor3 = if charge >= max then T.Accent else T.SubText
	ui.Ultimate.Fill.Size = UDim2.fromScale(math.clamp(charge / max, 0, 1), 1)

	-- Weapon + cash
	local cash = player:GetAttribute("Cash") or 0
	ui.Cash.Text = "$" .. Util.FormatNumber(cash)
	if weapon.Stats then
		ui.WeaponName.Text = weapon.Stats.DisplayName .. "  ·  T" .. weapon.Stats.Tier
		ui.WeaponName.TextColor3 = weapon.Stats.TierColor
		if weapon.Reloading then
			ui.Ammo.Text = "RELOADING"
			ui.Ammo.TextColor3 = T.Accent
		else
			ui.Ammo.Text = weapon.Ammo .. " / " .. weapon.Stats.MagSize
			ui.Ammo.TextColor3 = if weapon.Ammo == 0 then T.Danger else T.Text
		end
	end

	-- Upgrades
	local binds = GameConfig.Keybinds
	local function showUpgrade(row, key, id, level, label)
		local cost = Util.GetUpgradeCost(id, level)
		if not cost then
			row.Label.Text = "[" .. key .. "] " .. label .. " — MAX"
			row.Label.TextColor3 = T.SubText
		else
			row.Label.Text = "[" .. key .. "] " .. label .. " — $" .. Util.FormatNumber(cost)
			row.Label.TextColor3 = if cash >= cost then T.Cash else T.Disabled
		end
	end
	local tier = player:GetAttribute("WeaponTier") or 1
	local vitality = player:GetAttribute("VitalityLevel") or 0
	showUpgrade(ui.UpgradeWeapon, keyName(binds.UpgradeWeapon), "Weapon", tier, "Weapon → T" .. (tier + 1))
	showUpgrade(ui.UpgradeVitality, keyName(binds.UpgradeVitality), "Vitality", vitality, "Vitality +" .. GameConfig.Upgrades.Vitality.HealthPerLevel .. " HP")
end

return HUDController
