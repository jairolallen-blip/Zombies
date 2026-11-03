-- StoreController: the Robux shop (vault: Store.md; catalogue in Shared/Config/Store, purchases granted by
-- Server/Services/StoreService). Opened by the lobby's SHOP button (left, under the info chip) or the
-- TRADER stall's prompt (attribute Store, built by Server/Map/FieldStations). Tabs:
--   FEATURED  the Starter Pack and the featured pass as big cards
--   GEMS      the Gem packs
--   PASSES    the game passes
-- Buy buttons call Roblox's purchase prompts; prices come from Roblox (GetProductInfo), with Config/Store's
-- Price as the fallback. An id of 0 (not created on the dashboard yet) shows SOON.
-- Gem packs also have a gift button: pick a player in this server (Remotes.SetGift), then buy; StoreService
-- pays them instead of you.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Store = require(Shared.Config.Store)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local player = Players.LocalPlayer
local StoreController = {}
local ui = {}
local tab = "FEATURED"
local prices = {} -- [ProductId or PassId] = Robux price from Roblox

local PINK = Color3.fromRGB(255, 90, 200)
local GOLD = Color3.fromRGB(255, 190, 60)
local GREEN = Color3.fromRGB(90, 220, 90)
local CARD = Color3.fromRGB(26, 22, 28)

local function label(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.GothamBlack
	props.TextColor3 = props.TextColor3 or Color3.fromRGB(245, 240, 240)
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return UIKit.new("TextLabel", props)
end

local function gradient(parent, a, b, rotation)
	UIKit.new("UIGradient", { Rotation = rotation or 90, Color = ColorSequence.new(a, b), Parent = parent })
end

local function price(entry)
	local id = entry.ProductId or entry.PassId
	return prices[id] or entry.Price
end

local function fetchPrices()
	for _, entry in Store.ById do
		local id = entry.ProductId or entry.PassId
		if id ~= 0 and not prices[id] then
			local kind = if entry.PassId then Enum.InfoType.GamePass else Enum.InfoType.Product
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, kind)
			if ok and info and info.PriceInRobux then
				prices[id] = info.PriceInRobux
			end
		end
	end
end

-- the green Robux button (or OWNED / SOON). Solid colours: a UIGradient would tint the button's own text.
local function buyButton(parent, entry, position, size)
	local id = entry.ProductId or entry.PassId
	local owned = (entry.PassId and player:GetAttribute("Pass_" .. entry.Id)) or (entry.OneTime and player:GetAttribute("StarterBought"))
	local b = UIKit.new("TextButton", { Name = "Buy_" .. entry.Id, AnchorPoint = Vector2.new(1, 1), Position = position, Size = size, Font = Enum.Font.GothamBlack, TextSize = 26, AutoButtonColor = id ~= 0 and not owned, BackgroundColor3 = Color3.new(1, 1, 1), Parent = parent })
	UIKit.Corner(6).Parent = b
	if owned then
		b.Text = "OWNED"
		b.TextColor3 = Color3.fromRGB(220, 220, 220)
		b.BackgroundColor3 = Color3.fromRGB(60, 60, 66)
	elseif id == 0 then
		b.Text = "SOON"
		b.TextColor3 = Color3.fromRGB(210, 210, 215)
		b.BackgroundColor3 = Color3.fromRGB(40, 38, 46)
	else
		b.Text = "R$ " .. Util.FormatNumber(price(entry))
		b.TextColor3 = Color3.fromRGB(12, 40, 12)
		b.BackgroundColor3 = GREEN
		b.Activated:Connect(function()
			if entry.PassId then
				MarketplaceService:PromptGamePassPurchase(player, id)
			else
				MarketplaceService:PromptProductPurchase(player, id)
			end
		end)
	end
	return b
end

-- a stack of gem glyphs that grows with the pack
local function gems(parent, count, position, size)
	local holder = UIKit.new("Frame", { Position = position, Size = size, BackgroundTransparency = 1, Parent = parent })
	for i = 1, count do
		local g = label({ Text = "◆", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + (i - (count + 1) / 2) * 0.22, 0.5 + (i % 2) * 0.12), Size = UDim2.fromScale(0.6, 0.8), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.new(1, 1, 1), Rotation = (i - 2) * 8, Parent = holder })
		gradient(g, Color3.fromRGB(255, 190, 245), PINK, 45)
	end
	return holder
end

local function chip(parent, text, color, y)
	local c = UIKit.new("Frame", { Position = UDim2.fromOffset(24, y), Size = UDim2.fromOffset(250, 34), BackgroundColor3 = color, BorderSizePixel = 0, Parent = parent })
	UIKit.Corner(4).Parent = c
	label({ Text = text, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), TextSize = 18, TextColor3 = Color3.fromRGB(16, 16, 20), Parent = c })
end

-- the big picture on a pass card: x2 over a pile of gems, or a gold star
local function passArt(c, entry, y)
	if entry.Id == "DoubleGems" then
		gems(c, 4, UDim2.fromOffset(40, y + 10), UDim2.fromOffset(240, 180))
		label({ Text = "×2", Position = UDim2.fromOffset(240, y), Size = UDim2.fromOffset(190, 150), TextSize = 120, Rotation = -8, TextColor3 = Color3.fromRGB(255, 240, 120), TextStrokeTransparency = 0.4, Parent = c })
	elseif entry.Id == "VIP" then
		label({ Text = "★", Position = UDim2.fromOffset(40, y - 10), Size = UDim2.fromOffset(200, 200), TextSize = 170, TextColor3 = Color3.fromRGB(255, 245, 200), TextStrokeTransparency = 0.5, Rotation = -10, Parent = c })
	end
end

local function heroCard(parent, entry, from, to, x, width)
	local c = UIKit.new("Frame", { Position = UDim2.fromOffset(x, 0), Size = UDim2.new(0, width, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = parent })
	UIKit.Corner(8).Parent = c
	gradient(c, from, to, 120)
	local edge = UIKit.Stroke(Color3.fromRGB(255, 255, 255), 2)
	edge.Transparency = 0.6
	edge.Parent = c
	label({ Text = entry.Name, Position = UDim2.fromOffset(24, 18), Size = UDim2.new(1, -48, 0, 46), TextSize = 40, Parent = c })
	label({ Text = entry.Desc or "", Position = UDim2.fromOffset(24, 66), Size = UDim2.new(1, -48, 0, 44), TextSize = 17, TextWrapped = true, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 240, 230), TextYAlignment = Enum.TextYAlignment.Top, Parent = c })
	local y = 124
	for _, classId in entry.Classes or {} do
		chip(c, "+ " .. string.upper(classId) .. " CLASS", Color3.fromRGB(120, 230, 120), y)
		y += 42
	end
	if entry.Gems then
		chip(c, "+ " .. Util.FormatNumber(entry.Gems) .. " GEMS", PINK, y)
		gems(c, 3, UDim2.new(1, -200, 0, 110), UDim2.fromOffset(180, 150))
	else
		passArt(c, entry, 110)
	end
	buyButton(c, entry, UDim2.new(1, -20, 1, -20), UDim2.fromOffset(200, 64))
	return c
end

function StoreController:_featured(body)
	local hero = {}
	for _, entry in Store.ById do
		if entry.Featured then
			table.insert(hero, entry)
		end
	end
	table.sort(hero, function(a, b)
		return (a.ProductId ~= nil) and not (b.ProductId ~= nil) -- products first
	end)
	local styles = { { Color3.fromRGB(255, 170, 60), Color3.fromRGB(200, 70, 30) }, { Color3.fromRGB(200, 90, 255), Color3.fromRGB(110, 30, 160) } }
	for i, entry in hero do
		heroCard(body, entry, styles[i][1], styles[i][2], (i - 1) * 476, 460)
	end
end

function StoreController:_gems(body)
	UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(460, 190), CellPadding = UDim2.fromOffset(16, 16), Parent = body })
	local packs = {}
	for _, entry in Store.Products do
		if not entry.Classes then
			table.insert(packs, entry)
		end
	end
	for i, entry in packs do
		local c = UIKit.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = body })
		UIKit.Corner(8).Parent = c
		gradient(c, Color3.fromRGB(255, 120, 215), Color3.fromRGB(150, 30, 120), 120)
		gems(c, i, UDim2.fromOffset(10, 20), UDim2.fromOffset(170, 150))
		label({ Text = "+" .. Util.FormatNumber(entry.Gems) .. " GEMS", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 22), Size = UDim2.fromOffset(270, 44), TextSize = 36, TextXAlignment = Enum.TextXAlignment.Right, Parent = c })
		label({ Text = entry.Name, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 66), Size = UDim2.fromOffset(270, 22), TextSize = 17, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 225, 245), TextXAlignment = Enum.TextXAlignment.Right, Parent = c })
		if entry.Tag then
			local tag = label({ Text = entry.Tag, Position = UDim2.fromOffset(14, 12), Size = UDim2.fromOffset(110, 26), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(230, 40, 60), Rotation = -6, Parent = c })
			tag.BackgroundTransparency = 0
			UIKit.Corner(4).Parent = tag
		end
		buyButton(c, entry, UDim2.new(1, -20, 1, -20), UDim2.fromOffset(190, 60))
		local gift = UIKit.new("TextButton", { Name = "Gift_" .. entry.Id, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -222, 1, -20), Size = UDim2.fromOffset(60, 60), Text = "🎁", TextSize = 32, Font = Enum.Font.GothamBlack, BackgroundColor3 = if entry.ProductId ~= 0 then Color3.fromRGB(150, 70, 220) else Color3.fromRGB(40, 38, 46), AutoButtonColor = entry.ProductId ~= 0, Parent = c })
		UIKit.Corner(6).Parent = gift
		gift.Activated:Connect(function()
			if entry.ProductId ~= 0 then
				self:_pickFriend(entry)
			end
		end)
	end
end

function StoreController:_passes(body)
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 16), Parent = body })
	for i, entry in Store.Passes do
		local c = UIKit.new("Frame", { Size = UDim2.new(0, 460, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = body })
		UIKit.Corner(8).Parent = c
		if i == 1 then
			gradient(c, Color3.fromRGB(200, 90, 255), Color3.fromRGB(110, 30, 160), 120)
		else
			gradient(c, Color3.fromRGB(255, 210, 90), Color3.fromRGB(190, 120, 20), 120)
		end
		label({ Text = "GAME PASS", Position = UDim2.fromOffset(24, 18), Size = UDim2.new(1, -48, 0, 20), TextSize = 16, TextColor3 = Color3.fromRGB(255, 240, 220), Parent = c })
		label({ Text = entry.Name, Position = UDim2.fromOffset(24, 40), Size = UDim2.new(1, -48, 0, 70), TextSize = 64, Parent = c })
		label({ Text = entry.Desc, Position = UDim2.fromOffset(24, 120), Size = UDim2.new(1, -48, 0, 80), TextSize = 22, TextWrapped = true, Font = Enum.Font.GothamBold, TextYAlignment = Enum.TextYAlignment.Top, Parent = c })
		passArt(c, entry, 180)
		buyButton(c, entry, UDim2.new(1, -20, 1, -20), UDim2.fromOffset(200, 64))
	end
end

function StoreController:Refresh()
	if not ui.Gui.Enabled then
		return
	end
	for _, child in ui.Body:GetChildren() do
		child:Destroy()
	end
	ui.Gems.Text = "◆ " .. Util.FormatNumber(player:GetAttribute("Gems") or 0)
	for name, button in ui.Tabs do
		local on = name == tab
		button.BackgroundColor3 = if on then PINK else Color3.fromRGB(34, 30, 38)
		button.TextColor3 = if on then Color3.fromRGB(30, 10, 25) else Color3.fromRGB(200, 195, 205)
	end
	if tab == "FEATURED" then
		self:_featured(ui.Body)
	elseif tab == "GEMS" then
		self:_gems(ui.Body)
	else
		self:_passes(ui.Body)
	end
end

function StoreController:Open(which)
	tab = which or tab
	ui.Gui.Enabled = true
	ui.Scale.Scale = 0.92
	TweenService:Create(ui.Scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	self:Refresh()
	task.spawn(function()
		fetchPrices()
		self:Refresh()
	end)
end

-- gift picker: everyone else in this server; picking one tells the server, then opens the purchase
function StoreController:_pickFriend(entry)
	local old = ui.Panel:FindFirstChild("Picker")
	if old then
		old:Destroy()
	end
	local picker = UIKit.new("Frame", { Name = "Picker", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 8, 12), BackgroundTransparency = 0.08, Active = true, ZIndex = 10, Parent = ui.Panel })
	UIKit.Corner(10).Parent = picker
	label({ Text = "GIFT " .. entry.Name .. " TO...", Position = UDim2.fromOffset(28, 24), Size = UDim2.new(1, -56, 0, 40), TextSize = 32, TextColor3 = PINK, ZIndex = 11, Parent = picker })
	local list = UIKit.new("ScrollingFrame", { Position = UDim2.fromOffset(28, 84), Size = UDim2.new(1, -56, 1, -170), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 11, Parent = picker })
	UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(300, 56), CellPadding = UDim2.fromOffset(12, 12), Parent = list })
	local others = 0
	for _, other in Players:GetPlayers() do
		if other ~= player then
			others += 1
			local b = UIKit.new("TextButton", { Text = other.DisplayName, Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(150, 70, 220), ZIndex = 12, Parent = list })
			UIKit.Corner(6).Parent = b
			b.Activated:Connect(function()
				picker:Destroy()
				Remotes.SetGift:FireServer(other.UserId)
				MarketplaceService:PromptProductPurchase(player, entry.ProductId)
			end)
		end
	end
	if others == 0 then
		label({ Text = "Nobody else is here yet. Invite a friend, then gift them!", Position = UDim2.fromOffset(28, 90), Size = UDim2.new(1, -56, 0, 30), TextSize = 22, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 190, 205), ZIndex = 11, Parent = picker })
	end
	local cancel = UIKit.new("TextButton", { Name = "Cancel", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(200, 50), Text = "CANCEL", Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(60, 58, 66), ZIndex = 11, Parent = picker })
	UIKit.Corner(6).Parent = cancel
	cancel.Activated:Connect(function()
		picker:Destroy()
	end)
end

function StoreController:Close()
	ui.Gui.Enabled = false
end

function StoreController:Init()
	local gui = UIKit.Screen("Store")
	gui.DisplayOrder = 20
	gui.Enabled = false
	ui.Gui = gui
	UIKit.new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(), BackgroundTransparency = 0.4, BorderSizePixel = 0, Parent = gui }).Activated:Connect(function()
		self:Close() -- click outside to close
	end)
	local fit = UIKit.new("Frame", { BackgroundTransparency = 1, Parent = gui })
	UIKit.AutoScale(fit)
	local panel = UIKit.new("Frame", { Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1000, 600), BackgroundColor3 = Color3.fromRGB(16, 14, 18), BorderSizePixel = 0, Active = true, Parent = fit })
	UIKit.Corner(10).Parent = panel
	UIKit.Stroke(PINK, 2).Parent = panel
	ui.Scale = UIKit.new("UIScale", { Parent = panel })
	ui.Panel = panel
	label({ Text = "THE TRADER", Position = UDim2.fromOffset(28, 18), Size = UDim2.fromOffset(400, 40), TextSize = 36, TextColor3 = PINK, Parent = panel })
	label({ Text = "Gems, bundles and passes. Every purchase helps keep the safehouse running.", Position = UDim2.fromOffset(28, 58), Size = UDim2.fromOffset(600, 20), TextSize = 15, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(180, 170, 185), Parent = panel })
	ui.Gems = label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -86, 0, 24), Size = UDim2.fromOffset(240, 32), TextSize = 26, TextColor3 = PINK, TextXAlignment = Enum.TextXAlignment.Right, Parent = panel })
	local close = UIKit.new("TextButton", { Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 20), Size = UDim2.fromOffset(44, 44), Text = "X", Font = Enum.Font.GothamBlack, TextSize = 24, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(200, 50, 60), Parent = panel })
	UIKit.Corner(6).Parent = close
	close.Activated:Connect(function()
		self:Close()
	end)
	ui.Tabs = {}
	for i, name in { "FEATURED", "GEMS", "PASSES" } do
		local b = UIKit.new("TextButton", { Name = "Tab" .. name, Position = UDim2.fromOffset(28 + (i - 1) * 168, 96), Size = UDim2.fromOffset(156, 42), Text = name, Font = Enum.Font.GothamBlack, TextSize = 18, Parent = panel })
		UIKit.Corner(6).Parent = b
		b.Activated:Connect(function()
			tab = name
			self:Refresh()
		end)
		ui.Tabs[name] = b
	end
	ui.Body = UIKit.new("Frame", { Name = "Body", Position = UDim2.fromOffset(28, 156), Size = UDim2.new(1, -56, 1, -180), BackgroundTransparency = 1, Parent = panel })

	-- the SHOP button in the lobby, under the info chip
	local buttonGui = UIKit.Screen("StoreButton")
	local root = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = buttonGui })
	UIKit.AutoScale(root)
	local shop = UIKit.new("TextButton", { Name = "Shop", Position = UDim2.fromOffset(16, 262), Size = UDim2.fromOffset(170, 50), Text = "◆  SHOP", Font = Enum.Font.GothamBlack, TextSize = 24, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(215, 60, 170), Parent = root })
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
	for _, attr in { "Gems", "StarterBought", "Pass_DoubleGems", "Pass_VIP" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			self:Refresh()
		end)
	end
	RunService.RenderStepped:Connect(function()
		local lobby = not player:GetAttribute("InRun")
		buttonGui.Enabled = lobby and not player.PlayerGui:FindFirstChild("Welcome")
		if gui.Enabled and not lobby then
			self:Close()
		end
	end)
end

return StoreController
