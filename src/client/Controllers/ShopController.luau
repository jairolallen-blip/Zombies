-- ShopController: the lobby's walk-up menus (vault: Lobby.md), opened by the ProximityPrompts (attribute
-- Shop) that Server/Map/OurLobby puts in each:
--   Armory   (west tent)   level tabs 1-4; one card per gun with a rotating 3D model, stat bars and
--                          equip / unlock-with-Gems
--   Classes  (barracks)    one card per class with a rotating figure (Shared/ClassFigures)
--   Achievements (commendations board, south)  scrolling list of Config/Achievements with progress
--                          bars and CLAIM buttons (Remotes.ClaimAchievement); the board's status sign
--                          shows how many are ready to claim
--   Index    (field research)  one card per zombie type, locked until you've killed one
--   Bounties (bounty board)    today's three bounties; track one
-- Look: the same language as the welcome screen (WelcomeController): a full-screen cinematic layer with
-- letterbox bars over a warm vignette, an orange kicker + huge GothamBlack title + green accent bar,
-- near-black tiles with a thin warm stroke and a coloured edge, small-caps GothamBold labels over big
-- GothamBlack values, and the green gradient primary button. Cards pop in, tiles lift on hover.
-- Closes with the X button, Backspace / gamepad B, by walking away, or when a run starts. Buttons fire
-- the same remotes LobbyService validates (SelectWeapon / SelectClass / UnlockItem / ...).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
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
local Zombies = require(Shared.Config.Zombies)
local Bounties = require(Shared.Config.Bounties)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local T = UIKit.Theme
local player = Players.LocalPlayer
local ShopController = {}
local ui = {}
local openShop = nil -- "Armory" | "Classes" | "Achievements" | "Index" | "Bounties" | nil
local anchor = nil -- prompt part the shop was opened from (walk away to close)
local level = 1 -- armory tab
local spinning = {} -- { Model, Base, Center, Sway }
local fresh = {} -- cards built by this refresh, popped in when the view (re)opens

-- welcome-screen palette (WelcomeController): warm near-blacks, sunset orange kicker, bone text
local P = {
	Tile = Color3.fromRGB(14, 12, 14),
	TileHi = Color3.fromRGB(34, 25, 23), -- selected / hovered tile
	Edge = Color3.fromRGB(70, 56, 52), -- the thin warm stroke on every tile
	Kick = Color3.fromRGB(255, 170, 90),
	Text = Color3.fromRGB(245, 240, 235),
	Sub = Color3.fromRGB(196, 184, 174),
	Dim = Color3.fromRGB(128, 116, 110),
	Bar = Color3.fromRGB(36, 30, 30), -- stat bar backs
	Green = Color3.fromRGB(150, 240, 100),
	Bars = Color3.fromRGB(8, 6, 8), -- letterbox
	Meter = Color3.fromRGB(214, 200, 188), -- stat bars: neutral bone, so tier colours don't fight the gem / state colours
}
-- colour jobs (keep them apart so nothing clashes): tier colour = identity only (tab edge, section line);
-- green = yours / active; purple = Gems; orange = the page kicker and in-progress; everything else bone
local W, H = 1100, 640 -- design size of the content area (UIKit.AutoScale: 800 px tall screen)
local BODY_Y, BODY_H = 140, 468

local function decode(attr)
	local ok, data = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute(attr) or "{}")
	return if ok and type(data) == "table" then data else {}
end

local function clear(frame)
	for _, child in frame:GetChildren() do
		child:Destroy() -- layouts too: each view adds its own
	end
end

-- a text label with the welcome-screen defaults (GothamBold, bone, left-aligned)
local function text(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or P.Text
	props.TextSize = props.TextSize or 16
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return UIKit.new("TextLabel", props)
end

-- the welcome tile: near-black, thin warm stroke, optional coloured left edge
local function tile(props, edgeColor)
	local class = props.ClassName or "Frame" -- TextButton for clickable tiles
	props.ClassName = nil
	props.BackgroundColor3 = props.BackgroundColor3 or P.Tile
	props.BorderSizePixel = 0
	local f = UIKit.new(class, props)
	UIKit.Corner(6).Parent = f
	UIKit.Stroke(P.Edge, 1).Parent = f
	if edgeColor then
		UIKit.new("Frame", { Name = "Edge", Size = UDim2.new(0, 5, 1, 0), BackgroundColor3 = edgeColor, BorderSizePixel = 0, ZIndex = 2, Parent = f })
	end
	return f
end

-- one easing for everything that moves: fast start, long soft settle (no bounce)
local EASE = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local EASE_SLOW = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local function tween(inst, info, goal)
	local t = TweenService:Create(inst, info, goal)
	t:Play()
	return t
end

-- hover lift: a UIScale that eases up on mouse-over (and dips on press, for buttons)
local function lift(gui, amount)
	local scale = UIKit.new("UIScale", { Parent = gui })
	local hovering = false
	gui.MouseEnter:Connect(function()
		hovering = true
		tween(scale, EASE, { Scale = 1 + amount })
	end)
	gui.MouseLeave:Connect(function()
		hovering = false
		tween(scale, EASE, { Scale = 1 })
	end)
	if gui:IsA("GuiButton") then
		gui.MouseButton1Down:Connect(function()
			tween(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { Scale = 0.97 })
		end)
		gui.MouseButton1Up:Connect(function()
			tween(scale, EASE, { Scale = if hovering then 1 + amount else 1 })
		end)
	end
	return scale
end

-- lock a button for a beat after firing so a double-click can't double-spend (ux: loading-buttons)
local function lock(button)
	button.Active = false
	button.TextTransparency = 0.5
	task.delay(0.8, function()
		if button.Parent then
			button.Active = true
			button.TextTransparency = 0
		end
	end)
end

-- buttons, four kinds:
--   primary  the welcome screen's green gradient (equip, claim, track)
--   gem      purple gradient: spend Gems (unlock you can afford)
--   locked   a dark tile: can't do it yet (not enough Gems, not finished)
--   state    dark with a green rim: already true (equipped, claimed, tracking)
local GRADIENTS = {
	primary = { Color3.fromRGB(170, 255, 120), Color3.fromRGB(90, 200, 70), Color3.fromRGB(16, 30, 16) },
	gem = { Color3.fromRGB(214, 172, 255), Color3.fromRGB(140, 88, 226), Color3.fromRGB(28, 12, 46) },
}
local function button(parent, kind, label, props, onClick)
	props = props or {}
	local b = UIKit.new("TextButton", {
		Name = props.Name or "Action",
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 1),
		Position = props.Position or UDim2.new(0.5, 0, 1, -14),
		Size = props.Size or UDim2.new(1, -28, 0, 48),
		BackgroundColor3 = if GRADIENTS[kind] then Color3.new(1, 1, 1) elseif kind == "state" then Color3.fromRGB(20, 30, 18) else Color3.fromRGB(24, 20, 22),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = label,
		Font = Enum.Font.GothamBlack,
		TextSize = props.TextSize or 18,
		TextColor3 = if GRADIENTS[kind] then GRADIENTS[kind][3] elseif kind == "state" then P.Green else P.Dim,
		ZIndex = 3,
		Parent = parent,
	})
	UIKit.Corner(6).Parent = b
	if GRADIENTS[kind] then
		UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(GRADIENTS[kind][1], GRADIENTS[kind][2]), Parent = b })
		lift(b, 0.03)
		if onClick then
			b.Activated:Connect(function()
				if b.Active then
					lock(b)
					onClick()
				end
			end)
		end
	else
		UIKit.Stroke(if kind == "state" then P.Green else P.Edge, if kind == "state" then 2 else 1).Parent = b
	end
	return b
end

-- the shared equip / unlock button for guns and classes
local function actionButton(parent, isEquipped, isOwned, gemCost, onEquip, onUnlock)
	if isEquipped then
		return button(parent, "state", "✓  EQUIPPED")
	elseif isOwned then
		return button(parent, "primary", "EQUIP", nil, onEquip)
	end
	local gems = player:GetAttribute("Gems") or 0
	if gems >= gemCost then
		return button(parent, "gem", "◆ " .. Util.FormatNumber(gemCost) .. "   UNLOCK", nil, onUnlock)
	end
	local b = button(parent, "locked", "◆ " .. Util.FormatNumber(gemCost), nil)
	b.Activated:Connect(function()
		require(script.Parent.StoreController):Open("GEMS") -- too few Gems: straight to the Gem packs
	end)
	-- say how far off it is, small, under the price
	b.TextYAlignment = Enum.TextYAlignment.Top
	b.Text = "◆ " .. Util.FormatNumber(gemCost)
	b.TextSize = 17
	UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 7), Parent = b })
	text({ Text = Util.FormatNumber(gemCost - gems) .. " MORE  ·  TAP FOR GEMS", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, 0, 0, 12), TextSize = 11, TextColor3 = P.Dim, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = b })
	return b
end

-- a card: welcome tile with a small-caps kicker and a big name (no colour cap: it fought the outline)
local function card(parent, width, height, accent, highlighted, kicker, name, kickerColor)
	local frame = tile({ Size = UDim2.fromOffset(width, height), BackgroundColor3 = if highlighted then P.TileHi else P.Tile, Parent = parent })
	if highlighted then
		frame:FindFirstChildOfClass("UIStroke").Color = P.Green
		frame:FindFirstChildOfClass("UIStroke").Thickness = 2
	end
	text({ Text = kicker or "", Position = UDim2.fromOffset(16, 16), Size = UDim2.new(1, -32, 0, 14), TextSize = 12, TextColor3 = kickerColor or accent, Parent = frame })
	-- long names ("THE GRAVE TITAN") shrink to fit instead of truncating
	local title = text({ Text = string.upper(name), Position = UDim2.fromOffset(16, 34), Size = UDim2.new(1, -32, 0, 26), Font = Enum.Font.GothamBlack, TextScaled = true, Parent = frame })
	UIKit.new("UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 12, Parent = title })
	lift(frame, 0.02)
	table.insert(fresh, frame)
	return frame
end

-- 3D preview: frames the model and registers it to turn (guns sway to keep their profile)
local function preview(parent, x, y, w, h, model, sway)
	local vp = UIKit.new("ViewportFrame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		-- bright, warm key light: the models are dark plastics and vanish against the dusk otherwise
		Ambient = Color3.fromRGB(235, 215, 205),
		LightColor = Color3.fromRGB(255, 230, 200),
		LightDirection = Vector3.new(-0.5, -0.6, 0.6),
		ZIndex = 2,
		Parent = parent,
	})
	-- the welcome screen's dusk: warm glow low, dark at the top
	UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 20, 24)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(96, 50, 38)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 72, 46)),
	}), Parent = vp })
	UIKit.Corner(4).Parent = vp
	model.Parent = vp
	local cf, extent = model:GetBoundingBox()
	local center = cf.Position
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	-- distance that fits the model's width and height in the frame, plus a margin
	local halfV = math.tan(math.rad(camera.FieldOfView / 2))
	local width = if sway then extent.Z else extent.X
	local fit = math.max(width / 2 / (halfV * w / h), extent.Y / 2 / halfV) * 1.25
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

-- a small dark key plate with a letter, like the HUD's [E]/[F] plates
local function keyPlate(parent, key, x, y, color)
	local plate = UIKit.new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = Color3.fromRGB(30, 24, 24), BorderSizePixel = 0, ZIndex = 2, Parent = parent })
	UIKit.Stroke(color, 1).Parent = plate
	text({ Text = key, Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack, TextSize = 12, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3, Parent = plate })
	return plate
end

-- stat rows: small-caps label left, big value right, a thin bar beneath (largest gun = full bar)
local STATS = {
	{ "DAMAGE", function(w) return w.Damage * w.Pellets end, function(w) return if w.Pellets > 1 then w.Damage .. "×" .. w.Pellets else tostring(w.Damage) end },
	{ "FIRE RATE", function(w) return w.FireRate end, function(w) return string.format("%g/s", w.FireRate) end },
	{ "MAGAZINE", function(w) return w.MagSize end, function(w) return tostring(w.MagSize) end },
	{ "RANGE", function(w) return w.Range end, function(w) return tostring(w.Range) end },
}
local statMax = {}
for i, stat in STATS do
	statMax[i] = 0
	for _, w in Weapons.List do
		statMax[i] = math.max(statMax[i], stat[2](w))
	end
end

local function bar(parent, x, y, w, h, fraction, color)
	local back = UIKit.new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = P.Bar, BorderSizePixel = 0, ZIndex = 2, Parent = parent })
	UIKit.new("Frame", { Size = UDim2.fromScale(math.clamp(fraction, 0.03, 1), 1), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 3, Parent = back })
	return back
end

function ShopController:_buildArmory()
	local body = ui.Body
	local owned = decode("OwnedJson").Weapons or {}
	local picked = decode("LoadoutJson")
	local costs = GameConfig.Upgrades.Weapon.Costs

	-- level tabs: welcome tiles (tier-coloured edge, small-caps label, big value)
	local tabs = UIKit.new("Frame", { Size = UDim2.fromOffset(220, BODY_H), BackgroundTransparency = 1, Parent = body })
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabs })
	for lvl = 1, Weapons.Levels do
		local tier = GameConfig.WeaponTiers[lvl]
		local selected = lvl == level
		local tab = tile({ ClassName = "TextButton", Name = "LevelTab" .. lvl, LayoutOrder = lvl, Size = UDim2.fromOffset(220, 105), BackgroundColor3 = if selected then P.TileHi else P.Tile, Text = "", AutoButtonColor = false, Parent = tabs }, tier.Color)
		if selected then
			tab:FindFirstChildOfClass("UIStroke").Color = tier.Color
			tab:FindFirstChildOfClass("UIStroke").Thickness = 2
			text({ Text = "▶", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(20, 20), Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = tier.Color, TextXAlignment = Enum.TextXAlignment.Right, Parent = tab })
		end
		text({ Text = "LEVEL " .. lvl .. "  ·  " .. string.upper(tier.Name), Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -40, 0, 16), TextSize = 13, TextColor3 = tier.Color, Parent = tab })
		text({ Text = if lvl == 1 then "STARTER" else "$" .. Util.FormatNumber(costs[lvl - 1]), Position = UDim2.fromOffset(20, 34), Size = UDim2.new(1, -40, 0, 36), Font = Enum.Font.GothamBlack, TextSize = 30, TextColor3 = if lvl == 1 or selected then P.Text else P.Sub, Parent = tab })
		text({ Text = if lvl == 1 then "You start every run with it" else "In-run upgrade, paid in cash", Position = UDim2.fromOffset(20, 74), Size = UDim2.new(1, -40, 0, 16), Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = P.Dim, Parent = tab })
		if not selected then
			lift(tab, 0.025)
		end
		tab.Activated:Connect(function()
			if level ~= lvl then
				level = lvl
				self:Refresh(true)
			end
		end)
	end

	local tier = GameConfig.WeaponTiers[level]
	local color = tier.Color
	local equipped = picked[level] or Weapons.DefaultFor(level)
	-- section line above the cards: "LEVEL 3  //  RARE" + rule
	text({ Text = "LEVEL " .. level .. "  //  " .. string.upper(tier.Name) .. "  ·  PICK ONE", Position = UDim2.fromOffset(244, 0), Size = UDim2.fromOffset(400, 18), TextSize = 14, TextColor3 = color, Parent = body })
	UIKit.new("Frame", { Position = UDim2.fromOffset(244, 24), Size = UDim2.fromOffset(W - 244, 1), BackgroundColor3 = P.Edge, BorderSizePixel = 0, Parent = body })
	local cards = UIKit.new("Frame", { Position = UDim2.fromOffset(244, 36), Size = UDim2.fromOffset(W - 244, BODY_H - 36), BackgroundTransparency = 1, Parent = body })
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Left, Padding = UDim.new(0, 20), Parent = cards })
	local CW, CH = 272, BODY_H - 36
	for _, id in Weapons.ForLevel(level) do
		local def = Weapons.List[id]
		local c = card(cards, CW, CH, color, equipped == id, if equipped == id then "EQUIPPED" elseif owned[id] or def.GemCost == 0 then "OWNED" else "◆ " .. Util.FormatNumber(def.GemCost) .. " GEMS", def.DisplayName, if equipped == id then P.Green elseif owned[id] or def.GemCost == 0 then P.Sub else T.Gem)
		preview(c, 16, 70, CW - 32, 118, gunModel(id, level), true)
		text({ Text = def.Description, Position = UDim2.fromOffset(16, 198), Size = UDim2.new(1, -32, 0, 38), Font = Enum.Font.GothamMedium, TextSize = 14, TextWrapped = true, TextColor3 = P.Sub, TextYAlignment = Enum.TextYAlignment.Top, Parent = c })
		for i, stat in STATS do
			local y = 244 + (i - 1) * 26
			text({ Text = stat[1], Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -100, 0, 14), TextSize = 11, TextColor3 = P.Dim, Parent = c })
			text({ Text = stat[3](def), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, y - 2), Size = UDim2.fromOffset(90, 16), Font = Enum.Font.GothamBlack, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, Parent = c })
			bar(c, 16, y + 17, CW - 32, 4, stat[2](def) / statMax[i], P.Meter)
		end
		local extras = {}
		if def.Pierce > 1 then
			table.insert(extras, "PIERCES " .. def.Pierce)
		end
		if def.Automatic then
			table.insert(extras, "FULL-AUTO")
		end
		if def.SpinUp then
			table.insert(extras, "SPINS UP")
		end
		table.insert(extras, "HEADSHOT ×" .. def.HeadshotMultiplier)
		text({ Text = table.concat(extras, "  ·  "), Position = UDim2.fromOffset(16, 352), Size = UDim2.new(1, -32, 0, 14), TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = P.Dim, Parent = c })
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
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 20), Parent = body })
	local CW = math.floor((W - 20 * (#ids - 1)) / #ids)
	for _, id in ids do
		local def = Classes.List[id]
		local isOwned = owned[id] or def.GemCost == 0
		local c = card(body, CW, BODY_H, def.Color, current == id, if current == id then "YOUR CLASS" elseif isOwned then "OWNED" else "◆ " .. Util.FormatNumber(def.GemCost) .. " GEMS", def.DisplayName, if current == id then P.Green elseif isOwned then P.Sub else T.Gem)
		preview(c, 14, 70, CW - 28, 170, ClassFigures.Build(id), false)
		text({ Text = def.Description, Position = UDim2.fromOffset(16, 250), Size = UDim2.new(1, -32, 0, 54), Font = Enum.Font.GothamMedium, TextSize = 13, TextWrapped = true, TextColor3 = P.Sub, TextYAlignment = Enum.TextYAlignment.Top, Parent = c })
		keyPlate(c, "E", 16, 310, P.Sub)
		text({ Text = def.Ability.Name, Position = UDim2.fromOffset(44, 310), Size = UDim2.new(1, -60, 0, 20), TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, Parent = c })
		keyPlate(c, "F", 16, 336, P.Sub)
		text({ Text = def.Ultimate.Name, Position = UDim2.fromOffset(44, 336), Size = UDim2.new(1, -60, 0, 20), TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, Parent = c })
		local traits = {}
		if def.HealthBonus ~= 0 then
			table.insert(traits, string.format("%+d HP", def.HealthBonus))
		end
		if def.SpeedBonus ~= 0 then
			table.insert(traits, string.format("%+d SPEED", def.SpeedBonus))
		end
		if def.DamageTakenMult ~= 1 then
			table.insert(traits, string.format("%d%% ARMOR", math.floor((1 - def.DamageTakenMult) * 100 + 0.5)))
		end
		text({ Text = if #traits > 0 then table.concat(traits, " · ") else "BALANCED", Position = UDim2.fromOffset(16, 366), Size = UDim2.new(1, -32, 0, 14), TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = P.Dim, Parent = c })
		actionButton(c, current == id, isOwned, def.GemCost, function()
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
		Size = UDim2.fromOffset(W, BODY_H),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = P.Edge,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = ui.Body,
	})
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 10), Parent = list })
	UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), Parent = list })
	for _, row in sortedAchievements(stats, claimed) do
		local def = row.Def
		local ready, done = row.Rank == 0, row.Rank == 2
		local accent = if ready then P.Green elseif done then P.Dim else P.Kick
		local c = tile({ Size = UDim2.new(1, -20, 0, 76), BackgroundColor3 = if ready then P.TileHi else P.Tile, Parent = list }, accent)
		if ready then
			c:FindFirstChildOfClass("UIStroke").Color = P.Green
		end
		text({ Text = if ready then "READY TO CLAIM" elseif done then "CLAIMED" else "IN PROGRESS", Position = UDim2.fromOffset(22, 10), Size = UDim2.fromOffset(300, 14), TextSize = 11, TextColor3 = accent, Parent = c })
		text({ Text = string.upper(def.Name), Position = UDim2.fromOffset(22, 26), Size = UDim2.new(1, -470, 0, 24), Font = Enum.Font.GothamBlack, TextSize = 20, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = if done then P.Sub else P.Text, Parent = c })
		text({ Text = def.Desc, Position = UDim2.fromOffset(22, 50), Size = UDim2.new(1, -470, 0, 18), Font = Enum.Font.GothamMedium, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = P.Sub, Parent = c })
		local progress = UIKit.new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -196, 0.5, 0), Size = UDim2.fromOffset(220, 40), BackgroundTransparency = 1, Parent = c })
		text({ Text = "PROGRESS", Size = UDim2.fromOffset(100, 14), TextSize = 11, TextColor3 = P.Dim, Parent = progress })
		text({ Text = Util.FormatNumber(math.min(row.Progress, def.Goal)) .. " / " .. Util.FormatNumber(def.Goal), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, -2), Size = UDim2.fromOffset(120, 18), Font = Enum.Font.GothamBlack, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, Parent = progress })
		bar(progress, 0, 24, 220, 6, row.Fraction, accent)
		local props = { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(160, 46), TextSize = 16 }
		if ready then
			button(c, "primary", "CLAIM  ◆ " .. def.Gems, props, function()
				Remotes.ClaimAchievement:FireServer(def.Id)
			end)
		elseif done then
			button(c, "state", "✓  CLAIMED", props)
		else
			local b = button(c, "locked", "◆ " .. def.Gems, props)
			b.TextColor3 = T.Gem
		end
	end
end

-- Enemy index (FIELD RESEARCH station): one card per zombie type, locked until you've killed one
-- (Stats Kills_<type>); a discovered card shows the model, stats and lore, and pays its Gems once
-- (Remotes.ClaimIndex; claims are "Index_<type>" in Claimed). Models: ReplicatedStorage.ZombiePreviews.
-- Two rows in a vertical scroll: the normal horde, then the NIGHTMARE row underneath (Config/Zombies
-- Nightmare types, met only in Nightmare runs). Types without an Index entry (the Husk's halves) aren't listed.
function ShopController:_buildIndex()
	local data = decode("AchievementsJson")
	local stats, claimed = data.Stats or {}, data.Claimed or {}
	local rows = { {}, {} }
	for id, def in Zombies.Types do
		if def.Index then
			table.insert(rows[if def.Nightmare then 2 else 1], id)
		end
	end
	local function order(a, b)
		local da, db = Zombies.Types[a], Zombies.Types[b]
		if (da.Boss or false) ~= (db.Boss or false) then
			return not da.Boss
		end
		return (da.MinWave or 0) < (db.MinWave or 0)
	end
	local LABEL, GAP = 30, 26
	local scroll = UIKit.new("ScrollingFrame", {
		Name = "IndexScroll",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 2 * (LABEL + BODY_H) + GAP),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = P.Edge,
		Parent = ui.Body,
	})
	local previews = ReplicatedStorage:FindFirstChild("ZombiePreviews")
	local most = math.max(#rows[1], #rows[2])
	local CW = math.floor((W - 12 - 20 * (most - 1)) / most) -- same card width in both rows
	for r, ids in rows do
		table.sort(ids, order)
		local nightmare = r == 2
		local top = (r - 1) * (LABEL + BODY_H + GAP)
		text({ Text = if nightmare then "NIGHTMARE  ·  MET ONLY IN NIGHTMARE RUNS" else "THE HORDE", Position = UDim2.fromOffset(4, top), Size = UDim2.new(1, -16, 0, 22), Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = if nightmare then T.Danger else P.Kick, Parent = scroll })
		local row = UIKit.new("Frame", { Name = if nightmare then "NightmareRow" else "HordeRow", Position = UDim2.fromOffset(0, top + LABEL), Size = UDim2.fromOffset(W - 12, BODY_H), BackgroundTransparency = 1, Parent = scroll })
		UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 20), Parent = row })
		for _, id in ids do
			local def = Zombies.Types[id]
			local found = (stats["Kills_" .. id] or 0) > 0
			local done = claimed["Index_" .. id] == true
			local accent = if def.Boss or nightmare then T.Danger else P.Kick
			local kicker = if not found then "UNKNOWN" elseif def.Boss then "BOSS  ·  FINAL WAVE" elseif nightmare then "NIGHTMARE  ·  WAVE " .. (def.MinWave or 1) .. "+" else "FROM WAVE " .. (def.MinWave or 1)
			local c = card(row, CW, BODY_H, accent, found and not done, kicker, if found then def.DisplayName else "???")
			local source = previews and previews:FindFirstChild(id)
			if found and source then
				preview(c, 14, 70, CW - 28, 150, source:Clone(), false)
			else
				local box = UIKit.new("Frame", { Position = UDim2.fromOffset(14, 70), Size = UDim2.fromOffset(CW - 28, 150), BackgroundColor3 = Color3.fromRGB(22, 18, 20), BorderSizePixel = 0, ZIndex = 2, Parent = c })
				UIKit.Stroke(P.Edge, 1).Parent = box
				text({ Text = "?", Size = UDim2.new(1, 0, 1, -30), Font = Enum.Font.GothamBlack, TextSize = 72, TextColor3 = if nightmare then T.Danger else P.Edge, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3, Parent = box })
				text({ Text = "KILL ONE TO STUDY IT", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -14), Size = UDim2.new(1, 0, 0, 14), TextSize = 11, TextColor3 = P.Dim, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3, Parent = box })
			end
			if found then
				text({ Text = def.Index.Special, Position = UDim2.fromOffset(16, 230), Size = UDim2.new(1, -32, 0, 32), TextSize = 13, TextWrapped = true, TextColor3 = accent, TextYAlignment = Enum.TextYAlignment.Top, Parent = c })
				text({ Text = string.format("HP %s  ·  SPD %g  ·  DMG %d", Util.FormatNumber(def.Health), def.Speed, def.Damage), Position = UDim2.fromOffset(16, 266), Size = UDim2.new(1, -32, 0, 14), TextSize = 11, TextColor3 = P.Text, Parent = c })
				text({ Text = if def.Boss then "NO BOUNTY: SURVIVE IT" else string.format("$%d A KILL", def.Cash), Position = UDim2.fromOffset(16, 284), Size = UDim2.new(1, -32, 0, 14), TextSize = 11, TextColor3 = T.Cash, Parent = c })
				text({ Text = def.Index.Lore, Position = UDim2.fromOffset(16, 306), Size = UDim2.new(1, -32, 0, 88), Font = Enum.Font.GothamMedium, TextSize = 12, LineHeight = 1.15, TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = P.Sub, TextYAlignment = Enum.TextYAlignment.Top, Parent = c })
			end
			local props = { Name = "Index_" .. id }
			if found and not done then
				button(c, "primary", "CLAIM  ◆ " .. def.Index.Gems, props, function()
					Remotes.ClaimIndex:FireServer(id)
				end)
			elseif done then
				button(c, "state", "✓  STUDIED", props)
			else
				local b = button(c, "locked", "◆ " .. def.Index.Gems, props)
				b.TextColor3 = T.Gem
			end
		end
	end
end

-- Daily bounties (BOUNTY BOARD): today's three (Bounties.ForDay); track one, only it counts progress
-- (DataService). BountyJson = { Day, Tracked, Progress = {[id] = n}, Done = {[id] = true} }.
function ShopController:_buildBounties()
	local now = workspace:GetServerTimeNow()
	local today = Bounties.Today(now)
	local data = decode("BountyJson")
	if data.Day ~= today then
		data = {} -- a new day: the server resets it on the next save
	end
	local progress, done = data.Progress or {}, data.Done or {}
	local left = (today + 1) * Bounties.Day - now
	ui.Subtitle.Text = string.format("Track one at a time; only the tracked bounty counts. New bounties in %dh %dm.", left // 3600, left % 3600 // 60)
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 30), Parent = ui.Body })
	local list = Bounties.ForDay(today)
	local CW = math.min(340, math.floor((W - 30 * (#list - 1)) / #list))
	for _, def in list do
		local tracked = data.Tracked == def.Id
		local finished = done[def.Id] == true
		local accent = if finished then P.Dim elseif tracked then P.Green else P.Kick
		local c = card(ui.Body, CW, BODY_H, accent, tracked, if finished then "COMPLETED" elseif tracked then "TRACKING NOW" else "DAILY BOUNTY", def.Name)
		text({ Text = def.Desc, Position = UDim2.fromOffset(20, 80), Size = UDim2.new(1, -40, 0, 80), Font = Enum.Font.GothamMedium, TextSize = 22, LineHeight = 1.15, TextWrapped = true, TextColor3 = P.Text, TextYAlignment = Enum.TextYAlignment.Top, Parent = c })
		local n = math.min(progress[def.Id] or 0, def.Goal)
		text({ Text = "PROGRESS", Position = UDim2.fromOffset(20, 206), Size = UDim2.fromOffset(120, 14), TextSize = 12, TextColor3 = P.Dim, Parent = c })
		text({ Text = n .. " / " .. def.Goal, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 202), Size = UDim2.fromOffset(140, 22), Font = Enum.Font.GothamBlack, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right, Parent = c })
		bar(c, 20, 232, CW - 40, 10, n / def.Goal, accent)
		-- reward: a welcome stat tile with the Gem edge
		local reward = tile({ Position = UDim2.fromOffset(20, 288), Size = UDim2.new(1, -40, 0, 84), BackgroundColor3 = Color3.fromRGB(22, 16, 26), ZIndex = 2, Parent = c }, T.Gem)
		text({ Text = "REWARD", Position = UDim2.fromOffset(20, 12), Size = UDim2.fromOffset(120, 16), TextSize = 13, TextColor3 = T.Gem, ZIndex = 3, Parent = reward })
		text({ Text = "◆ " .. Util.FormatNumber(def.Gems or 0), Position = UDim2.fromOffset(20, 32), Size = UDim2.new(1, -40, 0, 40), Font = Enum.Font.GothamBlack, TextSize = 34, ZIndex = 3, Parent = reward })
		local props = { Name = "Bounty_" .. def.Id }
		if finished then
			button(c, "state", "✓  DONE", props)
		elseif tracked then
			button(c, "state", "TRACKING", props)
		else
			button(c, "primary", "TRACK THIS BOUNTY", props, function()
				Remotes.TrackBounty:FireServer(def.Id)
			end)
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

local VIEWS = {
	Armory = { "ARMORY", "Pick one gun for each level. A run starts on Level 1; upgrade in-run with cash.", "_buildArmory", "[1-4]  SWITCH LEVEL" },
	Classes = { "BARRACKS", "Choose your class. Each has an ability [E] and an ultimate [F].", "_buildClasses" },
	Index = { "FIELD RESEARCH", "Kill a zombie to study it. Each discovery pays Gems once.", "_buildIndex" },
	Bounties = { "BOUNTY BOARD", "", "_buildBounties" },
	Achievements = { "COMMENDATIONS", "Lifetime goals. Finish one, then claim its Gems here.", "_buildAchievements" },
}

-- animate = true when the view opens or the tab changes: the cards ease in one after another under a
-- fading veil; false (data changed: equipped, claimed) just cross-fades so nothing snaps
function ShopController:Refresh(animate)
	if not openShop then
		return
	end
	table.clear(spinning)
	table.clear(fresh)
	clear(ui.Body)
	ui.Gems.Text = "◆ " .. Util.FormatNumber(player:GetAttribute("Gems") or 0)
	local view = VIEWS[openShop] or VIEWS.Classes
	ui.Title.Text = view[1]
	ui.Subtitle.Text = view[2]
	ui.Footer.Text = (if view[4] then view[4] .. "      ·      " else "") .. "[BACKSPACE]  CLOSE      ·      WALK AWAY TO CLOSE"
	self[view[3]](self)
	-- the veil (a body-sized cover in the backdrop colour) fades away; ViewportFrames can't fade on their
	-- own, so this is what makes the 3D previews fade in with everything else
	ui.Veil.BackgroundTransparency = if animate then 0 else 0.45
	tween(ui.Veil, if animate then EASE_SLOW else EASE, { BackgroundTransparency = 1 })
	if animate then
		for i, frame in fresh do
			local scale = frame:FindFirstChildOfClass("UIScale")
			if scale then
				scale.Scale = 0.94
				task.delay((i - 1) * 0.045, function()
					tween(scale, EASE_SLOW, { Scale = 1 })
				end)
			end
		end
	end
end

-- the shop takes the whole screen: other ScreenGuis (lobby chip, Quick Play, radio) are hidden while it
-- is open and given back exactly as they were on close
local hidden = {}
local function hideOtherGuis(hide)
	if hide then
		for _, g in player.PlayerGui:GetChildren() do
			if g:IsA("ScreenGui") and g ~= ui.Gui and g.Enabled and g.DisplayOrder < 50 and not hidden[g] then
				hidden[g] = true
				g.Enabled = false
			end
		end
	else
		for g in hidden do
			if g.Parent then
				g.Enabled = true
			end
		end
		table.clear(hidden)
	end
end

local transition = 0 -- bumps on every open/close, so a half-finished close never hides a reopened shop

function ShopController:Open(shop, fromPart)
	transition += 1
	local wasOpen = ui.Gui.Enabled
	openShop, anchor = shop, fromPart
	hideOtherGuis(true)
	ui.Gui.Enabled = true
	self:Refresh(true)
	if wasOpen then
		return -- switching straight from another menu: the cards already ease in
	end
	-- entrance like the welcome screen: the scene darkens, the bars close in, the header glides in
	ui.Shade.BackgroundTransparency = 1
	tween(ui.Shade, EASE_SLOW, { BackgroundTransparency = 0 })
	ui.Header.Position = UDim2.fromOffset(-40, 0)
	ui.HeaderVeil.BackgroundTransparency = 0
	tween(ui.Header, EASE_SLOW, { Position = UDim2.fromOffset(0, 0) })
	tween(ui.HeaderVeil, EASE_SLOW, { BackgroundTransparency = 1 })
	for _, strip in ui.Letterbox do
		strip.Size = UDim2.new(1, 0, 0, 0)
		tween(strip, EASE_SLOW, { Size = UDim2.new(1, 0, 0.07, 0) })
	end
end

function ShopController:Close()
	if not openShop then
		return
	end
	openShop, anchor = nil, nil
	transition += 1
	local mine = transition
	-- exit: everything fades back into the scene, the bars open, then the gui goes away
	local out = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(ui.Veil, out, { BackgroundTransparency = 0 })
	tween(ui.HeaderVeil, out, { BackgroundTransparency = 0 })
	tween(ui.Shade, out, { BackgroundTransparency = 1 })
	for _, strip in ui.Letterbox do
		tween(strip, out, { Size = UDim2.new(1, 0, 0, 0) })
	end
	hideOtherGuis(false)
	task.delay(0.21, function()
		if transition ~= mine then
			return -- reopened meanwhile
		end
		ui.Gui.Enabled = false
		table.clear(spinning)
		table.clear(fresh)
		clear(ui.Body)
	end)
end

function ShopController:IsOpen()
	return openShop ~= nil
end

function ShopController:Init()
	local gui = UIKit.Screen("Shop")
	gui.DisplayOrder = 8
	gui.Enabled = false
	ui.Gui = gui
	-- warm vignette over the lobby: dark everywhere, darkest at the edges (the welcome screen's grade)
	ui.Shade = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 6, 6), BorderSizePixel = 0, Parent = gui }, {
		UIKit.new("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(40, 18, 14), Color3.fromRGB(6, 4, 6)),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.03),
				NumberSequenceKeypoint.new(0.5, 0.14), -- dark enough that the lobby HUD behind can't bleed through
				NumberSequenceKeypoint.new(1, 0.03),
			}),
		}),
	})
	ui.Letterbox = {}
	for _, top in { true, false } do
		table.insert(ui.Letterbox, UIKit.new("Frame", { AnchorPoint = Vector2.new(0, if top then 0 else 1), Position = UDim2.fromScale(0, if top then 0 else 1), Size = UDim2.new(1, 0, 0.07, 0), BackgroundColor3 = P.Bars, BorderSizePixel = 0, ZIndex = 2, Parent = gui }))
	end
	local root = UIKit.new("Frame", { BackgroundTransparency = 1, Parent = gui })
	local autoScale = UIKit.AutoScale(root)
	-- the content keeps its 1100 px design width; narrow screens (4:3 tablets) shrink it to fit
	local content = UIKit.new("Frame", { Name = "Content", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, Parent = root })
	local fitWidth = UIKit.new("UIScale", { Parent = content })
	local function fit()
		local designWidth = workspace.CurrentCamera.ViewportSize.X / autoScale.Scale
		fitWidth.Scale = math.min(1, (designWidth - 60) / W)
	end
	fit()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

	-- header: the welcome stack (orange kicker, huge white title, green accent bar) + gems tile + close
	ui.Header = UIKit.new("Frame", { Size = UDim2.fromOffset(W, 130), BackgroundTransparency = 1, Parent = content })
	text({ Text = "SAFEHOUSE  //  PORT HARROW", Size = UDim2.fromOffset(500, 18), TextSize = 15, TextColor3 = P.Kick, Parent = ui.Header })
	ui.Title = text({ Position = UDim2.fromOffset(0, 20), Size = UDim2.fromOffset(700, 62), Font = Enum.Font.GothamBlack, TextSize = 58, Parent = ui.Header })
	UIKit.new("Frame", { Position = UDim2.fromOffset(0, 88), Size = UDim2.fromOffset(90, 4), BackgroundColor3 = T.Cash, BorderSizePixel = 0, Parent = ui.Header })
	ui.Subtitle = text({ Position = UDim2.fromOffset(0, 102), Size = UDim2.fromOffset(780, 20), Font = Enum.Font.GothamMedium, TextSize = 16, TextColor3 = P.Sub, Parent = ui.Header })
	local gemTile = tile({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -92, 0, 4), Size = UDim2.fromOffset(200, 76), Parent = ui.Header }, T.Gem)
	text({ Text = "GEMS", Position = UDim2.fromOffset(20, 12), Size = UDim2.fromOffset(150, 16), TextSize = 13, TextColor3 = T.Gem, ZIndex = 2, Parent = gemTile })
	ui.Gems = text({ Position = UDim2.fromOffset(20, 30), Size = UDim2.new(1, -36, 0, 38), Font = Enum.Font.GothamBlack, TextSize = 32, ZIndex = 2, Parent = gemTile })
	-- close: a solid red button (the one red thing on screen), big white X, brightens on hover
	local close = UIKit.new("TextButton", { Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), Size = UDim2.fromOffset(76, 76), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AutoButtonColor = false, Text = "", Parent = ui.Header })
	UIKit.Corner(6).Parent = close
	local closeFill = UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(240, 92, 78), Color3.fromRGB(178, 40, 34)), Parent = close })
	UIKit.Stroke(Color3.fromRGB(255, 150, 130), 1).Parent = close
	text({ Text = "X", Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack, TextSize = 38, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = close })
	lift(close, 0.05)
	close.MouseEnter:Connect(function()
		closeFill.Color = ColorSequence.new(Color3.fromRGB(255, 120, 104), Color3.fromRGB(205, 52, 44))
	end)
	close.MouseLeave:Connect(function()
		closeFill.Color = ColorSequence.new(Color3.fromRGB(240, 92, 78), Color3.fromRGB(178, 40, 34))
	end)
	close.Activated:Connect(function()
		self:Close()
	end)

	ui.Body = UIKit.new("Frame", { Name = "Body", Position = UDim2.fromOffset(0, BODY_Y), Size = UDim2.fromOffset(W, BODY_H), BackgroundTransparency = 1, Parent = content })
	-- veils: covers in the backdrop colour that fade away (ViewportFrames can't fade themselves)
	ui.Veil = UIKit.new("Frame", { Name = "Veil", Position = UDim2.fromOffset(-8, BODY_Y - 8), Size = UDim2.fromOffset(W + 16, BODY_H + 16), BackgroundColor3 = Color3.fromRGB(16, 9, 9), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 10, Parent = content })
	ui.HeaderVeil = UIKit.new("Frame", { Name = "HeaderVeil", Position = UDim2.fromOffset(-8, -8), Size = UDim2.fromOffset(W + 16, 146), BackgroundColor3 = Color3.fromRGB(16, 9, 9), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 10, Parent = content })
	ui.Footer = text({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(W, 16), TextSize = 12, TextColor3 = P.Dim, TextXAlignment = Enum.TextXAlignment.Center, Parent = content })

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local shop = prompt:GetAttribute("Shop")
		if shop and player:GetAttribute("InRun") ~= true then
			self:Open(shop, prompt.Parent)
		end
	end)
	-- keys: 1-4 switch armory levels; Backspace / gamepad B close
	local LEVEL_KEYS = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4 }
	UserInputService.InputBegan:Connect(function(input, processed)
		if not openShop or processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.ButtonB then
			self:Close()
		elseif openShop == "Armory" and LEVEL_KEYS[input.KeyCode] and LEVEL_KEYS[input.KeyCode] <= Weapons.Levels and LEVEL_KEYS[input.KeyCode] ~= level then
			level = LEVEL_KEYS[input.KeyCode]
			self:Refresh(true)
		end
	end)
	for _, attr in { "Gems", "OwnedJson", "ClassId", "LoadoutJson", "AchievementsJson", "BountyJson" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			if (attr ~= "AchievementsJson" or openShop == "Achievements" or openShop == "Index") and (attr ~= "BountyJson" or openShop == "Bounties") then
				self:Refresh(false)
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
