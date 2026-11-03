-- LobbyMenu: the lobby's main screen (owner 2026-11-03: "bare and boring, and it's the first impression").
-- Built by LobbyController:Init into its root; LobbyController keeps the squad panel, results and waiting cover.
--   top centre   the game's wordmark
--   top left     profile card: level badge, name, rank, XP bar, Gems (+ opens the Gem packs), best wave,
--                class, and the four loadout guns as chips in their Level colours
--   left         menu tiles: SHOP, WEAPONS, CLASSES, BOUNTIES, INVITE (shops open in place, no walk needed)
--   bottom       a big pulsing QUICK PLAY over the deploy hint strip
-- menu:Refresh() re-reads the player's attributes; menu:Enter() slides everything in (each time the lobby shows).

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Classes = require(Shared.Config.Classes)
local Weapons = require(Shared.Config.Weapons)
local Levels = require(Shared.Config.Levels)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local T = UIKit.Theme
local TITLE = Enum.Font.GothamBlack
local BODY = Enum.Font.GothamBold
local INK = Color3.fromRGB(14, 12, 14) -- panel fill (the welcome screen's warm near-black)
local EDGE = Color3.fromRGB(70, 56, 52)
local DIM = Color3.fromRGB(155, 161, 173)
local AMBER = Color3.fromRGB(232, 170, 66)
local PLAY = Color3.fromRGB(124, 214, 96)

local LobbyMenu = {}
LobbyMenu.__index = LobbyMenu

local function new(className, props)
	return UIKit.new(className, props)
end

local function text(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or BODY
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return new("TextLabel", props)
end

local function panel(props)
	props.BackgroundColor3 = props.BackgroundColor3 or INK
	props.BackgroundTransparency = props.BackgroundTransparency or 0.12
	props.BorderSizePixel = 0
	local frame = new("Frame", props)
	local stroke = UIKit.Stroke(EDGE, 1)
	stroke.Parent = frame
	return frame, stroke
end

local function icon(name, glyph, props)
	if UIKit.Icon and T.Icons and T.Icons[name] then
		props.TextColor3 = nil
		return UIKit.Icon(name, props)
	end
	props.Text, props.TextScaled, props.TextColor3, props.ImageColor3 = glyph, true, props.ImageColor3, nil
	return text(props) -- older UIKit without the icon set: a text glyph instead
end

local function sound(name, pitch)
	local ok, SoundController = pcall(require, script.Parent.Parent.Controllers.SoundController)
	if ok and SoundController.Play then
		pcall(SoundController.Play, SoundController, name, { Pitch = pitch })
	end
end

local function controller(name)
	return require(script.Parent.Parent.Controllers[name])
end

function LobbyMenu.new(root)
	local self = setmetatable({ Slides = {} }, LobbyMenu)

	-- wordmark
	local mark = new("Frame", { Name = "Wordmark", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(520, 70), BackgroundTransparency = 1, Parent = root })
	text({ Text = "S U R V I V E   A", Size = UDim2.new(1, 0, 0, 18), TextSize = 16, TextColor3 = AMBER, TextXAlignment = Enum.TextXAlignment.Center, Font = TITLE, Parent = mark })
	local big = text({ Text = "MILLION ZOMBIES", Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 48), TextSize = 46, Font = TITLE, TextXAlignment = Enum.TextXAlignment.Center, Parent = mark })
	new("UIStroke", { Color = Color3.fromRGB(70, 14, 12), Thickness = 3, Parent = big })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 120, 90)), Parent = big })
	table.insert(self.Slides, { mark, UDim2.new(0.5, 0, 0, -80) })

	-- profile card
	local card = panel({ Name = "Profile", Position = UDim2.fromOffset(16, 64), Size = UDim2.fromOffset(404, 216), Parent = root })
	table.insert(self.Slides, { card, UDim2.fromOffset(-440, 64) })
	local badge = new("Frame", { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(64, 64), BackgroundColor3 = AMBER, BorderSizePixel = 0, Parent = card })
	UIKit.Stroke(Color3.fromRGB(255, 226, 160), 2).Parent = badge
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 170, 140)), Parent = badge })
	text({ Text = "LEVEL", Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 0, 12), TextSize = 11, Font = TITLE, TextColor3 = Color3.fromRGB(70, 44, 10), TextXAlignment = Enum.TextXAlignment.Center, Parent = badge })
	self.Level = text({ Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 44), TextSize = 36, Font = TITLE, TextColor3 = Color3.fromRGB(34, 22, 6), TextXAlignment = Enum.TextXAlignment.Center, Parent = badge })
	self.BadgeScale = new("UIScale", { Parent = badge })
	text({ Text = player.DisplayName, Position = UDim2.fromOffset(88, 10), Size = UDim2.fromOffset(280, 24), TextSize = 22, Font = TITLE, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	self.Rank = text({ Position = UDim2.fromOffset(88, 35), Size = UDim2.fromOffset(280, 16), TextSize = 13, Font = TITLE, TextColor3 = AMBER, Parent = card })
	local xpBack = new("Frame", { Position = UDim2.fromOffset(88, 56), Size = UDim2.fromOffset(302, 10), BackgroundColor3 = Color3.fromRGB(16, 16, 18), BorderSizePixel = 0, Parent = card })
	UIKit.Stroke(Color3.fromRGB(58, 61, 69), 1).Parent = xpBack
	self.XPFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = AMBER, BorderSizePixel = 0, Parent = xpBack })
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 220, 140), Color3.fromRGB(232, 150, 40)), Parent = self.XPFill })
	self.XPText = text({ Position = UDim2.fromOffset(88, 68), Size = UDim2.fromOffset(280, 14), TextSize = 12, TextColor3 = DIM, Parent = card })

	new("Frame", { Position = UDim2.fromOffset(12, 90), Size = UDim2.new(1, -24, 0, 1), BackgroundColor3 = EDGE, BorderSizePixel = 0, Parent = card })
	icon("Gem", "◆", { Position = UDim2.fromOffset(12, 101), Size = UDim2.fromOffset(20, 20), ImageColor3 = T.Gem, TextColor3 = T.Gem, Parent = card })
	self.Gems = text({ Position = UDim2.fromOffset(38, 98), Size = UDim2.fromOffset(150, 26), TextSize = 22, Font = TITLE, TextColor3 = T.Gem, Parent = card })
	local plus = new("TextButton", { Name = "BuyGems", Position = UDim2.fromOffset(176, 99), Size = UDim2.fromOffset(24, 24), Text = "+", TextSize = 22, Font = TITLE, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(215, 60, 170), BorderSizePixel = 0, AutoButtonColor = true, Parent = card })
	plus.Activated:Connect(function()
		sound("Click")
		controller("StoreController"):Open("GEMS")
	end)
	self.Best = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 100), Size = UDim2.fromOffset(150, 22), TextSize = 15, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Right, Parent = card })

	new("Frame", { Position = UDim2.fromOffset(12, 132), Size = UDim2.new(1, -24, 0, 1), BackgroundColor3 = EDGE, BorderSizePixel = 0, Parent = card })
	text({ Text = "CLASS", Position = UDim2.fromOffset(12, 140), Size = UDim2.fromOffset(60, 18), TextSize = 12, Font = TITLE, TextColor3 = DIM, Parent = card })
	self.Class = text({ Position = UDim2.fromOffset(60, 137), Size = UDim2.fromOffset(300, 22), TextSize = 18, Font = TITLE, Parent = card })
	self.Chips = {}
	for level = 1, Weapons.Levels do
		local chip = new("Frame", { Position = UDim2.fromOffset(12 + (level - 1) * 96, 164), Size = UDim2.fromOffset(90, 40), BackgroundColor3 = Color3.fromRGB(33, 34, 39), BorderSizePixel = 0, Parent = card })
		local tier = GameConfig.WeaponTiers[level].Color
		new("Frame", { Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = tier, BorderSizePixel = 0, Parent = chip })
		text({ Text = "LV " .. level, Position = UDim2.fromOffset(6, 5), Size = UDim2.new(1, -12, 0, 13), TextSize = 11, Font = TITLE, TextColor3 = tier, Parent = chip })
		self.Chips[level] = text({ Position = UDim2.fromOffset(6, 19), Size = UDim2.new(1, -10, 0, 17), TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd, Parent = chip })
	end

	-- menu tiles
	local tiles = {
		{ "SHOP", "Gems, passes and gifts", Color3.fromRGB(215, 60, 170), "Gem", "◆", function()
			controller("StoreController"):Open()
		end },
		{ "WEAPONS", "Armory · pick your guns", AMBER, "Gun", "▲", function()
			controller("ShopController"):Open("Armory")
		end },
		{ "CLASSES", "Barracks · pick your class", Color3.fromRGB(80, 160, 255), "Medal", "★", function()
			controller("ShopController"):Open("Classes")
		end },
		{ "BOUNTIES", "Targets that pay Gems", Color3.fromRGB(235, 77, 66), "Skull", "✚", function()
			controller("ShopController"):Open("Bounties")
		end },
		{ "INVITE", "Bring your squad", PLAY, "Compass", "+", function()
			local SocialService = game:GetService("SocialService")
			local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
			if ok and can then
				pcall(SocialService.PromptGameInvite, SocialService, player)
			end
		end },
	}
	for i, t in tiles do
		local y = 294 + (i - 1) * 58
		local tile = new("TextButton", { Name = "Tile" .. t[1], Position = UDim2.fromOffset(16, y), Size = UDim2.fromOffset(240, 50), Text = "", AutoButtonColor = false, BackgroundColor3 = INK, BackgroundTransparency = 0.12, BorderSizePixel = 0, Parent = root })
		local stroke = UIKit.Stroke(EDGE, 1)
		stroke.Parent = tile
		local bar = new("Frame", { Size = UDim2.new(0, 5, 1, 0), BackgroundColor3 = t[3], BorderSizePixel = 0, Parent = tile })
		icon(t[4], t[5], { Position = UDim2.fromOffset(16, 13), Size = UDim2.fromOffset(24, 24), ImageColor3 = t[3], TextColor3 = t[3], Parent = tile })
		text({ Text = t[1], Position = UDim2.fromOffset(52, 6), Size = UDim2.fromOffset(180, 22), TextSize = 20, Font = TITLE, Parent = tile })
		text({ Text = t[2], Position = UDim2.fromOffset(52, 28), Size = UDim2.fromOffset(180, 15), TextSize = 12, TextColor3 = DIM, Parent = tile })
		local quick = TweenInfo.new(0.12)
		tile.MouseEnter:Connect(function()
			sound("UIHover")
			TweenService:Create(tile, quick, { Position = UDim2.fromOffset(24, y), BackgroundColor3 = t[3]:Lerp(INK, 0.75) }):Play()
			TweenService:Create(bar, quick, { Size = UDim2.new(0, 9, 1, 0) }):Play()
			stroke.Color = t[3]
		end)
		tile.MouseLeave:Connect(function()
			TweenService:Create(tile, quick, { Position = UDim2.fromOffset(16, y), BackgroundColor3 = INK }):Play()
			TweenService:Create(bar, quick, { Size = UDim2.new(0, 5, 1, 0) }):Play()
			stroke.Color = EDGE
		end)
		tile.Activated:Connect(function()
			sound("Click")
			t[6]()
		end)
		table.insert(self.Slides, { tile, UDim2.fromOffset(-280, y), 0.05 * i })
	end

	-- deploy: hint strip (LobbyController writes its text) under a big pulsing QUICK PLAY
	self.StatusBar = panel({ Name = "StatusBar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), Size = UDim2.fromOffset(560, 52), Parent = root })
	new("Frame", { Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = AMBER, BorderSizePixel = 0, Parent = self.StatusBar })
	self.Status = text({ Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -28, 1, 0), TextSize = 16, TextWrapped = true, TextColor3 = Color3.fromRGB(226, 228, 232), TextXAlignment = Enum.TextXAlignment.Center, Parent = self.StatusBar })
	table.insert(self.Slides, { self.StatusBar, UDim2.new(0.5, 0, 1, 80) })

	local play = new("TextButton", { Name = "QuickPlay", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -84), Size = UDim2.fromOffset(330, 72), Text = "", AutoButtonColor = false, BackgroundColor3 = PLAY, BorderSizePixel = 0, ClipsDescendants = true, Parent = root })
	self.QuickPlay = play
	self.PlayStroke = new("UIStroke", { Color = Color3.fromRGB(220, 255, 200), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = play })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 190, 160)), Parent = play })
	text({ Text = "QUICK PLAY", Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 38), TextSize = 36, Font = TITLE, TextColor3 = Color3.fromRGB(16, 30, 12), TextXAlignment = Enum.TextXAlignment.Center, Parent = play })
	text({ Text = "JUMP INTO THE NEXT SQUAD WITH ROOM", Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 14), TextSize = 11, Font = TITLE, TextColor3 = Color3.fromRGB(36, 70, 26), TextXAlignment = Enum.TextXAlignment.Center, Parent = play })
	self.PlaySheen = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(-0.3, 0.5), Size = UDim2.new(0, 60, 2, 0), Rotation = 20, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2, Parent = play })
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 1) }), Parent = self.PlaySheen })
	self.PlayScale = new("UIScale", { Parent = play })
	play.MouseEnter:Connect(function()
		sound("UIHover")
		TweenService:Create(self.PlayScale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1.06 }):Play()
	end)
	play.MouseLeave:Connect(function()
		TweenService:Create(self.PlayScale, TweenInfo.new(0.15), { Scale = 1 }):Play()
	end)
	play.Activated:Connect(function()
		sound("Click")
		self.PlayScale.Scale = 0.94
		TweenService:Create(self.PlayScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		Remotes.QuickPlay:FireServer()
	end)
	table.insert(self.Slides, { play, UDim2.new(0.5, 0, 1, 120), 0.1 })
	RunService.RenderStepped:Connect(function()
		if not play.Visible or not root.Visible then
			return
		end
		local t = os.clock()
		self.PlayStroke.Thickness = 2 + 2 * (0.5 + 0.5 * math.sin(t * 3))
		self.PlaySheen.Position = UDim2.fromScale(-0.3 + ((t % 3) / 3) * 1.9, 0.5)
	end)

	-- the store's own pink SHOP button (StoreController) would sit on the tiles; SHOP is a tile now
	-- shortcut: hides it by name from here, so a rename in StoreController brings it back
	task.spawn(function()
		local gui = player:WaitForChild("PlayerGui"):WaitForChild("StoreButton", 30)
		local button = gui and gui:FindFirstChild("Shop", true)
		if button then
			button.Visible = false
		end
	end)

	for _, attr in { "XP", "Gems", "BestWave", "ClassId", "LoadoutJson" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			self:Refresh()
		end)
	end
	self:Refresh()
	return self
end

function LobbyMenu:Refresh()
	local level, into, need = Levels.FromXP(player:GetAttribute("XP") or 0)
	if self.LastLevel and level > self.LastLevel then
		self.BadgeScale.Scale = 1.3
		TweenService:Create(self.BadgeScale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	self.LastLevel = level
	self.Level.Text = tostring(level)
	self.Rank.Text = if Levels.Rank then Levels.Rank(level) else ""
	TweenService:Create(self.XPFill, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(math.clamp(into / need, 0, 1), 1) }):Play()
	self.XPText.Text = Util.FormatNumber(into) .. " / " .. Util.FormatNumber(need) .. " XP to level " .. (level + 1)
	self.Gems.Text = Util.FormatNumber(player:GetAttribute("Gems") or 0)
	self.Best.Text = "BEST WAVE  " .. (player:GetAttribute("BestWave") or 0)
	local class = Classes.List[player:GetAttribute("ClassId")] or Classes.List[Classes.Default]
	self.Class.Text = class.DisplayName:upper()
	self.Class.TextColor3 = class.Color
	local ok, picked = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("LoadoutJson") or "[]")
	picked = if ok and type(picked) == "table" then picked else {}
	for lvl, label in self.Chips do
		local def = Weapons.List[picked[lvl] or Weapons.DefaultFor(lvl)]
		label.Text = def and def.DisplayName or "?"
	end
end

-- slide everything in from off screen (each time the lobby screen appears)
function LobbyMenu:Enter()
	for _, s in self.Slides do
		local inst, from, delay = s[1], s[2], s[3] or 0
		s.Home = s.Home or inst.Position
		inst.Position = from
		task.delay(delay, function()
			TweenService:Create(inst, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = s.Home }):Play()
		end)
	end
end

return LobbyMenu
