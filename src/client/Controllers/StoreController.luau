-- StoreController: the Robux shop (vault: Store.md; catalogue in Shared/Config/Store, purchases granted by
-- Server/Services/StoreService). Opened by the lobby's SHOP button (left, under the info chip) or the
-- TRADER stall's prompt (attribute Store, built by Server/Map/FieldStations). Tabs (keys 1-3):
--   FEATURED  the Starter Pack bundle and the featured pass as big cards
--   GEMS      the Gem packs
--   PASSES    the game passes (not the bundle: it's on FEATURED)
-- Buy buttons call Roblox's purchase prompts; prices and icons come from Roblox (GetProductInfo), with
-- Config/Store's Price as the fallback. An id of 0 (not created on the dashboard yet) shows SOON.
-- Gem packs also have a gift button: pick a player in this server (Remotes.SetGift), then buy; StoreService
-- pays them instead of you.
-- Look: the same language as the lobby shops (ShopController) and the welcome screen: a full-screen layer
-- with letterbox bars over a warm vignette, kicker + huge title + green accent bar, near-black tiles with a
-- thin warm stroke and coloured edges, the green gradient buy button, a red X. Quint easing, a fading veil
-- (so the product icons fade too), staggered cards, a fade-out on close. Other ScreenGuis hide while open.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local ContentProvider = game:GetService("ContentProvider")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Store = require(Shared.Config.Store)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local T = UIKit.Theme
local player = Players.LocalPlayer
local StoreController = {}
local ui = {}
local tab = "FEATURED"
local prices = {} -- [ProductId or PassId] = Robux price from Roblox
local icons = {} -- [ProductId or PassId] = icon image asset id from Roblox
local fresh = {} -- cards built by this refresh, eased in when the view (re)opens

-- palette shared with ShopController / WelcomeController: warm near-blacks, orange kicker, bone text
local P = {
	Tile = Color3.fromRGB(14, 12, 14),
	TileHi = Color3.fromRGB(34, 25, 23),
	Edge = Color3.fromRGB(70, 56, 52),
	Kick = Color3.fromRGB(255, 170, 90),
	Text = Color3.fromRGB(245, 240, 235),
	Sub = Color3.fromRGB(196, 184, 174),
	Dim = Color3.fromRGB(128, 116, 110),
	Green = Color3.fromRGB(150, 240, 100),
	Gold = Color3.fromRGB(255, 196, 70),
	Bars = Color3.fromRGB(8, 6, 8),
}
-- colour jobs: purple = Gems, green = buy / yours, gold = passes, orange = the kicker and featured
local W, H = 1100, 640
local BODY_Y, BODY_H = 140, 468
local TAB_W = 220
local CARDS_X = TAB_W + 24
local CARDS_W = W - CARDS_X
local CARDS_H = BODY_H - 36

local TABS = {
	{ Name = "FEATURED", Label = "BEST DEALS", Sub = "Starter Pack + 2x Gems", Color = P.Kick },
	{ Name = "GEMS", Label = "BUY OR GIFT", Sub = "Packs from 500 to 7,500", Color = T.Gem },
	{ Name = "PASSES", Label = "OWNED FOREVER", Sub = "2x Gems and VIP", Color = P.Gold },
}

local EASE = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local EASE_SLOW = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local function tween(inst, info, goal)
	local t = TweenService:Create(inst, info, goal)
	t:Play()
	return t
end

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
		UIKit.new("Frame", { Name = "Edge", Size = UDim2.new(0, 5, 1, 0), BackgroundColor3 = edgeColor, BorderSizePixel = 0, ZIndex = (props.ZIndex or 1) + 1, Parent = f })
	end
	return f
end

-- hover lift (and a press dip for buttons)
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

local function price(entry)
	local id = entry.ProductId or entry.PassId
	return prices[id] or entry.Price
end

-- fetches any price / icon not known yet and preloads the icon images; true when something new arrived.
-- Runs once at startup so the first open is already complete (no rebuild + image pop a second later).
local function fetchPrices()
	local fresh = {}
	for _, entry in Store.ById do
		local id = entry.ProductId or entry.PassId
		if id ~= 0 and not prices[id] then
			local kind = if entry.PassId then Enum.InfoType.GamePass else Enum.InfoType.Product
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, kind)
			if ok and info then
				prices[id] = info.PriceInRobux
				if info.IconImageAssetId and info.IconImageAssetId ~= 0 then
					icons[id] = info.IconImageAssetId
					table.insert(fresh, "rbxassetid://" .. info.IconImageAssetId)
				end
				fresh.Changed = true
			end
		end
	end
	if #fresh > 0 then
		pcall(ContentProvider.PreloadAsync, ContentProvider, fresh) -- images decoded before any card shows them
	end
	return fresh.Changed == true
end

-- buttons, three kinds: primary (green gradient: buy), state (dark, green rim: owned), locked (dark: SOON)
local function button(parent, kind, label, props)
	props = props or {}
	local primary = kind == "primary"
	local b = UIKit.new("TextButton", {
		Name = props.Name or "Action",
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 1),
		Position = props.Position or UDim2.new(0.5, 0, 1, -14),
		Size = props.Size or UDim2.new(1, -28, 0, 56),
		BackgroundColor3 = if primary then Color3.new(1, 1, 1) elseif kind == "state" then Color3.fromRGB(20, 30, 18) else Color3.fromRGB(24, 20, 22),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = label,
		Font = Enum.Font.GothamBlack,
		TextSize = props.TextSize or 22,
		TextColor3 = if primary then Color3.fromRGB(16, 30, 16) elseif kind == "state" then P.Green else P.Dim,
		ZIndex = props.ZIndex or 3,
		Parent = parent,
	})
	UIKit.Corner(6).Parent = b
	if primary then
		UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(170, 255, 120), Color3.fromRGB(90, 200, 70)), Parent = b })
		lift(b, 0.03)
	else
		UIKit.Stroke(if kind == "state" then P.Green else P.Edge, if kind == "state" then 2 else 1).Parent = b
		if props.Clickable then
			lift(b, 0.03)
		end
	end
	return b
end

-- the Robux buy button (or OWNED / SOON)
local function buyButton(parent, entry)
	local id = entry.ProductId or entry.PassId
	local owned = (entry.PassId and player:GetAttribute("Pass_" .. entry.Id)) or (entry.Classes and player:GetAttribute("StarterBought"))
	if owned then
		return button(parent, "state", "✓  OWNED", { Name = "Buy_" .. entry.Id })
	elseif id == 0 then
		return button(parent, "locked", "SOON", { Name = "Buy_" .. entry.Id })
	end
	local b = button(parent, "primary", "R$ " .. Util.FormatNumber(price(entry)), { Name = "Buy_" .. entry.Id })
	b.Activated:Connect(function()
		if entry.PassId then
			MarketplaceService:PromptGamePassPurchase(player, id)
		else
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end)
	return b
end

-- transparency ramp for feathered edges: clear at both ends, solid through the middle
local FEATHER = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.2, 0),
	NumberSequenceKeypoint.new(0.8, 0),
	NumberSequenceKeypoint.new(1, 1),
})

-- the product's own icon from Roblox (the uploaded store art), in a dusk frame
local function iconFrame(parent, entry, x, y, size)
	local icon = icons[entry.ProductId or entry.PassId]
	local frame = UIKit.new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(size, size), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2, Parent = parent })
	if icon and entry.PassId then
		-- Roblox serves pass icons circle-cropped: let the circle float on the card, no square frame
		frame.BackgroundTransparency = 1
		UIKit.new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "rbxassetid://" .. icon, ZIndex = 3, Parent = frame })
		return frame
	end
	if icon then
		-- product art: feathered edges so it melts into the card. A UIGradient fades along one axis only, so
		-- the CanvasGroup fades left/right and the image's own gradient fades top/bottom
		frame.BackgroundTransparency = 1
		local group = UIKit.new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = frame })
		UIKit.new("UIGradient", { Transparency = FEATHER, Parent = group })
		local image = UIKit.new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "rbxassetid://" .. icon, ScaleType = Enum.ScaleType.Crop, ZIndex = 3, Parent = group })
		UIKit.new("UIGradient", { Rotation = 90, Transparency = FEATHER, Parent = image })
		return frame
	end
	UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 20, 24)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(96, 50, 38)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 72, 46)),
	}), Parent = frame })
	UIKit.Corner(4).Parent = frame
	if icon then
		UIKit.new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "rbxassetid://" .. icon, ScaleType = Enum.ScaleType.Crop, ZIndex = 3, Parent = frame })
	else
		text({ Text = "◆", Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack, TextSize = math.floor(size * 0.45), TextColor3 = T.Gem, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3, Parent = frame })
	end
	return frame
end

-- a card: tile + small-caps kicker + big name (auto-fits), registered to ease in
local function card(parent, width, height, kicker, kickerColor, name, highlighted)
	local frame = tile({ Size = UDim2.fromOffset(width, height), BackgroundColor3 = if highlighted then P.TileHi else P.Tile, Parent = parent })
	if highlighted then
		frame:FindFirstChildOfClass("UIStroke").Color = P.Green
		frame:FindFirstChildOfClass("UIStroke").Thickness = 2
	end
	text({ Text = kicker, Position = UDim2.fromOffset(16, 16), Size = UDim2.new(1, -32, 0, 14), TextSize = 12, TextColor3 = kickerColor, Parent = frame })
	local title = text({ Text = string.upper(name), Position = UDim2.fromOffset(16, 34), Size = UDim2.new(1, -32, 0, 28), Font = Enum.Font.GothamBlack, TextScaled = true, Parent = frame })
	UIKit.new("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 12, Parent = title })
	lift(frame, 0.02)
	table.insert(fresh, frame)
	return frame
end

-- a reward line: a small tile with a coloured edge ("MEDIC CLASS", "1,000 GEMS")
local function perk(parent, label, color, x, y, w)
	local p = tile({ Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 32), BackgroundColor3 = Color3.fromRGB(24, 18, 20), ZIndex = 2, Parent = parent }, color)
	text({ Text = label, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -24, 1, 0), TextSize = 13, TextColor3 = P.Text, ZIndex = 3, Parent = p })
	return p
end

-- big card for a bundle or a pass: icon centred, description, perks, buy button
local function heroCard(parent, entry, width)
	local owned = (entry.PassId and player:GetAttribute("Pass_" .. entry.Id)) or (entry.Classes and player:GetAttribute("StarterBought"))
	local kicker = if entry.Classes then "BUNDLE  ·  ONCE PER SURVIVOR" else "GAME PASS  ·  OWNED FOREVER"
	local c = card(parent, width, CARDS_H, kicker, if entry.Classes then P.Kick else P.Gold, entry.Name, owned)
	local size = 196
	iconFrame(c, entry, math.floor((width - size) / 2), 72, size)
	text({ Text = entry.Desc or "", Position = UDim2.fromOffset(16, 278), Size = UDim2.new(1, -32, 0, 38), Font = Enum.Font.GothamMedium, TextSize = 15, TextWrapped = true, TextColor3 = P.Sub, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, Parent = c })
	local perks = {}
	for _, classId in entry.Classes or {} do
		table.insert(perks, { "+ " .. string.upper(classId) .. " CLASS", P.Green })
	end
	if entry.Gems then
		table.insert(perks, { "+ " .. Util.FormatNumber(entry.Gems) .. " GEMS", T.Gem })
	end
	if #perks > 0 then
		local w = math.floor((width - 32 - 10 * (#perks - 1)) / #perks)
		for i, p in perks do
			perk(c, p[1], p[2], 16 + (i - 1) * (w + 10), 322, w)
		end
	end
	buyButton(c, entry)
	return c
end

function StoreController:_featured(cards)
	local hero = {}
	for _, entry in Store.ById do
		if entry.Featured then
			table.insert(hero, entry)
		end
	end
	table.sort(hero, function(a, b)
		return a.Classes ~= nil and b.Classes == nil -- the bundle (Starter Pack) first
	end)
	local width = math.floor((CARDS_W - 20 * (#hero - 1)) / math.max(#hero, 1))
	for _, entry in hero do
		heroCard(cards, entry, width)
	end
end

function StoreController:_gems(cards)
	local packs = {}
	for _, entry in Store.Products do
		if not entry.Classes then
			table.insert(packs, entry)
		end
	end
	local width = math.floor((CARDS_W - 20 * (#packs - 1)) / math.max(#packs, 1))
	for _, entry in packs do
		local c = card(cards, width, CARDS_H, entry.Tag or "GEM PACK", if entry.Tag then P.Kick else P.Dim, entry.Name)
		local size = width - 32
		iconFrame(c, entry, 16, 72, size)
		local y = 72 + size + 10
		text({ Text = "+" .. Util.FormatNumber(entry.Gems), Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -32, 0, 34), Font = Enum.Font.GothamBlack, TextSize = 32, Parent = c })
		text({ Text = "GEMS", Position = UDim2.fromOffset(16, y + 34), Size = UDim2.new(1, -32, 0, 14), TextSize = 12, TextColor3 = T.Gem, Parent = c })
		local canGift = entry.ProductId ~= 0
		local gift = button(c, "locked", "GIFT TO A FRIEND", { Name = "Gift_" .. entry.Id, Position = UDim2.new(0.5, 0, 1, -80), Size = UDim2.new(1, -28, 0, 34), TextSize = 12, Clickable = canGift })
		gift.TextColor3 = if canGift then P.Sub else P.Dim
		gift.Activated:Connect(function()
			if canGift then
				self:_pickFriend(entry)
			end
		end)
		buyButton(c, entry)
	end
end

function StoreController:_passes(cards)
	local list = {}
	for _, entry in Store.Passes do
		if not entry.Classes then -- the Starter Pack bundle lives on FEATURED
			table.insert(list, entry)
		end
	end
	local width = math.floor((CARDS_W - 20 * (#list - 1)) / math.max(#list, 1))
	for _, entry in list do
		heroCard(cards, entry, width)
	end
end

-- animate = true when the store opens or the tab changes: cards ease in under a fading veil; false (a
-- price, icon or ownership update) just cross-fades so nothing snaps
function StoreController:Refresh(animate)
	if not ui.Gui.Enabled or ui.Closing then
		return
	end
	table.clear(fresh)
	for _, child in ui.Body:GetChildren() do
		child:Destroy()
	end
	ui.Gems.Text = "◆ " .. Util.FormatNumber(player:GetAttribute("Gems") or 0)
	-- tabs: welcome tiles down the left (coloured edge, small-caps label, big name)
	local tabs = UIKit.new("Frame", { Size = UDim2.fromOffset(TAB_W, BODY_H), BackgroundTransparency = 1, Parent = ui.Body })
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabs })
	local current
	for i, t in TABS do
		local selected = t.Name == tab
		if selected then
			current = t
		end
		local b = tile({ ClassName = "TextButton", Name = "Tab" .. t.Name, LayoutOrder = i, Size = UDim2.fromOffset(TAB_W, 105), BackgroundColor3 = if selected then P.TileHi else P.Tile, Text = "", AutoButtonColor = false, Parent = tabs }, t.Color)
		if selected then
			b:FindFirstChildOfClass("UIStroke").Color = t.Color
			b:FindFirstChildOfClass("UIStroke").Thickness = 2
			text({ Text = "▶", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(20, 20), Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = t.Color, TextXAlignment = Enum.TextXAlignment.Right, Parent = b })
		else
			lift(b, 0.025)
		end
		text({ Text = i .. "  ·  " .. t.Label, Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -40, 0, 16), TextSize = 13, TextColor3 = t.Color, Parent = b })
		text({ Text = t.Name, Position = UDim2.fromOffset(20, 34), Size = UDim2.new(1, -40, 0, 36), Font = Enum.Font.GothamBlack, TextSize = 30, TextColor3 = if selected then P.Text else P.Sub, Parent = b })
		text({ Text = t.Sub, Position = UDim2.fromOffset(20, 74), Size = UDim2.new(1, -40, 0, 16), Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = P.Dim, Parent = b })
		b.Activated:Connect(function()
			self:SetTab(t.Name)
		end)
	end
	-- section line above the cards
	text({ Text = current.Name .. "  //  " .. current.Label, Position = UDim2.fromOffset(CARDS_X, 0), Size = UDim2.fromOffset(500, 18), TextSize = 14, TextColor3 = current.Color, Parent = ui.Body })
	UIKit.new("Frame", { Position = UDim2.fromOffset(CARDS_X, 24), Size = UDim2.fromOffset(CARDS_W, 1), BackgroundColor3 = P.Edge, BorderSizePixel = 0, Parent = ui.Body })
	local cards = UIKit.new("Frame", { Position = UDim2.fromOffset(CARDS_X, 36), Size = UDim2.fromOffset(CARDS_W, CARDS_H), BackgroundTransparency = 1, Parent = ui.Body })
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 20), Parent = cards })
	if tab == "FEATURED" then
		self:_featured(cards)
	elseif tab == "GEMS" then
		self:_gems(cards)
	else
		self:_passes(cards)
	end
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

function StoreController:SetTab(name)
	if name ~= tab then
		tab = name
		self:Refresh(true)
	end
end

-- other ScreenGuis (lobby chip, HUD) hide while the store is open and come back exactly as they were;
-- the SHOP button is handled by the RenderStepped below
local hidden = {}
local function hideOtherGuis(hide)
	if hide then
		for _, g in player.PlayerGui:GetChildren() do
			if g:IsA("ScreenGui") and g ~= ui.Gui and g ~= ui.ButtonGui and g.Enabled and g.DisplayOrder < 50 and not hidden[g] then
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

local transition = 0 -- bumps on every open/close, so a half-finished close never hides a reopened store

function StoreController:Open(which)
	transition += 1
	local wasOpen = ui.Gui.Enabled and not ui.Closing
	ui.Closing = false
	tab = which or tab
	hideOtherGuis(true)
	ui.Gui.Enabled = true
	self:Refresh(true)
	task.spawn(function()
		local before = transition
		if fetchPrices() and transition == before then -- only rebuild if Roblox had something new
			self:Refresh(false)
		end
	end)
	if wasOpen then
		return
	end
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

-- gift picker: everyone else in this server; picking one tells the server, then opens the purchase
function StoreController:_pickFriend(entry)
	local old = ui.Content:FindFirstChild("Picker")
	if old then
		old:Destroy()
	end
	-- a cover far bigger than any screen (the content frame is scaled), with the layout in `inner`
	local picker = UIKit.new("Frame", { Name = "Picker", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W + 4000, H + 4000), BackgroundColor3 = Color3.fromRGB(12, 8, 8), BackgroundTransparency = 1, BorderSizePixel = 0, Active = true, ZIndex = 20, Parent = ui.Content })
	tween(picker, EASE, { BackgroundTransparency = 0 }) -- fully opaque: near-zero values still let the cards ghost through
	local inner = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, ZIndex = 21, Parent = picker })
	text({ Text = "GIFT  //  PICK A SURVIVOR", Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(600, 18), TextSize = 15, TextColor3 = P.Kick, ZIndex = 21, Parent = inner })
	text({ Text = "SEND " .. entry.Name, Position = UDim2.fromOffset(0, 20), Size = UDim2.fromOffset(W, 58), Font = Enum.Font.GothamBlack, TextSize = 52, ZIndex = 21, Parent = inner })
	UIKit.new("Frame", { Position = UDim2.fromOffset(0, 88), Size = UDim2.fromOffset(90, 4), BackgroundColor3 = T.Cash, BorderSizePixel = 0, ZIndex = 21, Parent = inner })
	text({ Text = "They get the " .. Util.FormatNumber(entry.Gems or 0) .. " Gems; you pay. Only players in this server can be picked.", Position = UDim2.fromOffset(0, 102), Size = UDim2.fromOffset(W, 20), Font = Enum.Font.GothamMedium, TextColor3 = P.Sub, ZIndex = 21, Parent = inner })
	local list = UIKit.new("ScrollingFrame", { Position = UDim2.fromOffset(0, BODY_Y), Size = UDim2.fromOffset(W, BODY_H - 80), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, ScrollBarImageColor3 = P.Edge, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 21, Parent = inner })
	UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(350, 70), CellPadding = UDim2.fromOffset(16, 16), Parent = list })
	UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), Parent = list })
	local others = 0
	for _, other in Players:GetPlayers() do
		if other ~= player then
			others += 1
			local b = tile({ ClassName = "TextButton", Text = "", AutoButtonColor = false, ZIndex = 22, Parent = list }, T.Gem)
			text({ Text = "SEND TO", Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -40, 0, 14), TextSize = 12, TextColor3 = T.Gem, ZIndex = 23, Parent = b })
			text({ Text = string.upper(other.DisplayName), Position = UDim2.fromOffset(20, 28), Size = UDim2.new(1, -40, 0, 28), Font = Enum.Font.GothamBlack, TextSize = 24, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 23, Parent = b })
			lift(b, 0.03)
			b.Activated:Connect(function()
				picker:Destroy()
				Remotes.SetGift:FireServer(other.UserId)
				MarketplaceService:PromptProductPurchase(player, entry.ProductId)
			end)
		end
	end
	if others == 0 then
		text({ Text = "Nobody else is here yet. Invite a friend, then gift them!", Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(W, 30), Font = Enum.Font.GothamMedium, TextSize = 20, TextColor3 = P.Sub, ZIndex = 21, Parent = list })
	end
	local cancel = button(inner, "locked", "CANCEL", { Name = "Cancel", Position = UDim2.new(0.5, 0, 1, -20), Size = UDim2.fromOffset(240, 52), TextSize = 20, ZIndex = 22, Clickable = true })
	cancel.TextColor3 = P.Text
	cancel.Activated:Connect(function()
		picker:Destroy()
	end)
end

function StoreController:Close()
	if not ui.Gui.Enabled or ui.Closing then
		return
	end
	ui.Closing = true
	transition += 1
	local mine = transition
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
		ui.Closing = false
		local picker = ui.Content:FindFirstChild("Picker")
		if picker then
			picker:Destroy()
		end
	end)
end

function StoreController:Init()
	local gui = UIKit.Screen("Store")
	gui.DisplayOrder = 20
	gui.Enabled = false
	ui.Gui = gui
	-- warm vignette over the lobby (the welcome screen's grade) + letterbox bars
	ui.Shade = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 6, 6), BorderSizePixel = 0, Active = true, Parent = gui }, {
		UIKit.new("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(40, 18, 14), Color3.fromRGB(6, 4, 6)),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.03),
				NumberSequenceKeypoint.new(0.5, 0.14),
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
	local content = UIKit.new("Frame", { Name = "Content", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, Parent = root })
	ui.Content = content
	local fitWidth = UIKit.new("UIScale", { Parent = content })
	local function fit()
		local designWidth = workspace.CurrentCamera.ViewportSize.X / autoScale.Scale
		fitWidth.Scale = math.min(1, (designWidth - 60) / W)
	end
	fit()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

	-- header: kicker, huge title, green accent bar, subtitle; gems tile + red X on the right
	ui.Header = UIKit.new("Frame", { Size = UDim2.fromOffset(W, 130), BackgroundTransparency = 1, Parent = content })
	text({ Text = "SAFEHOUSE  //  PORT HARROW", Size = UDim2.fromOffset(500, 18), TextSize = 15, TextColor3 = P.Kick, Parent = ui.Header })
	text({ Text = "THE TRADER", Position = UDim2.fromOffset(0, 20), Size = UDim2.fromOffset(700, 62), Font = Enum.Font.GothamBlack, TextSize = 58, Parent = ui.Header })
	UIKit.new("Frame", { Position = UDim2.fromOffset(0, 88), Size = UDim2.fromOffset(90, 4), BackgroundColor3 = T.Cash, BorderSizePixel = 0, Parent = ui.Header })
	text({ Text = "Gems, bundles and passes. Every purchase helps keep the safehouse running.", Position = UDim2.fromOffset(0, 102), Size = UDim2.fromOffset(780, 20), Font = Enum.Font.GothamMedium, TextColor3 = P.Sub, Parent = ui.Header })
	local gemTile = tile({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -92, 0, 4), Size = UDim2.fromOffset(200, 76), Parent = ui.Header }, T.Gem)
	text({ Text = "GEMS", Position = UDim2.fromOffset(20, 12), Size = UDim2.fromOffset(150, 16), TextSize = 13, TextColor3 = T.Gem, ZIndex = 2, Parent = gemTile })
	ui.Gems = text({ Position = UDim2.fromOffset(20, 30), Size = UDim2.new(1, -36, 0, 38), Font = Enum.Font.GothamBlack, TextSize = 32, ZIndex = 2, Parent = gemTile })
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
	-- veils: covers in the backdrop colour that fade away (images and the 3D-ish icons fade with them)
	ui.Veil = UIKit.new("Frame", { Name = "Veil", Position = UDim2.fromOffset(-8, BODY_Y - 8), Size = UDim2.fromOffset(W + 16, BODY_H + 16), BackgroundColor3 = Color3.fromRGB(16, 9, 9), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 10, Parent = content })
	ui.HeaderVeil = UIKit.new("Frame", { Name = "HeaderVeil", Position = UDim2.fromOffset(-8, -8), Size = UDim2.fromOffset(W + 16, 146), BackgroundColor3 = Color3.fromRGB(16, 9, 9), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 10, Parent = content })
	text({ Text = "[1-3]  SWITCH TAB      ·      [BACKSPACE]  CLOSE", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(W, 16), TextSize = 12, TextColor3 = P.Dim, TextXAlignment = Enum.TextXAlignment.Center, Parent = content })

	task.spawn(fetchPrices) -- warm the prices and icons now, so the first open needs no second build

	-- the SHOP button in the lobby, under the info chip (never in the Outbreak place: no lobby there,
	-- and it would flash over the deploy cutscene until InRun replicates)
	local buttonGui = UIKit.Screen("StoreButton")
	ui.ButtonGui = buttonGui
	buttonGui.Enabled = game.PlaceId ~= 87622086122699 -- hidden at once in the Outbreak place
	local buttonRoot = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = buttonGui })
	UIKit.AutoScale(buttonRoot)
	local shop = UIKit.new("TextButton", { Name = "Shop", Position = UDim2.fromOffset(16, 262), Size = UDim2.fromOffset(170, 50), Text = "◆  SHOP", Font = Enum.Font.GothamBlack, TextSize = 24, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(215, 60, 170), Parent = buttonRoot })
	UIKit.Corner(8).Parent = shop -- solid colour: a UIGradient would tint the button's own text too
	UIKit.Stroke(Color3.fromRGB(255, 220, 245), 2).Parent = shop
	shop.Activated:Connect(function()
		self:Open()
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("Store") and not player:GetAttribute("InRun") then
			self:Open("FEATURED")
		end
	end)
	local TAB_KEYS = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3 }
	UserInputService.InputBegan:Connect(function(input, processed)
		if not gui.Enabled or ui.Closing or processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.ButtonB then
			local picker = ui.Content:FindFirstChild("Picker")
			if picker then
				picker:Destroy()
			else
				self:Close()
			end
		elseif TAB_KEYS[input.KeyCode] then
			self:SetTab(TABS[TAB_KEYS[input.KeyCode]].Name)
		end
	end)
	for _, attr in { "Gems", "StarterBought", "Pass_Starter", "Pass_DoubleGems", "Pass_VIP" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			self:Refresh(false)
		end)
	end
	RunService.RenderStepped:Connect(function()
		local lobby = not player:GetAttribute("InRun") and game.PlaceId ~= 87622086122699 -- no lobby UI in the Outbreak place
		buttonGui.Enabled = lobby and not player.PlayerGui:FindFirstChild("Welcome") and not gui.Enabled
		if gui.Enabled and not lobby then
			self:Close()
		end
	end)
end

return StoreController
