-- DailyCache: the DAILY RATIONS supply cache on the south edge of the plaza, by the flag (vault: Lobby.md).
-- A pallet of crates under a sign; holding "Claim" on the top crate (attribute Daily = true) pays the day's
-- Gems (Server/Services/DailyService). OurLobby.Build calls this last. Safe to re-run: it replaces itself.
--   local m = game.ServerScriptService.Server.Map.DailyCache
--   local c = m:Clone(); c.Parent = m.Parent; require(c).Build(workspace.OurMap.Lobby); c:Destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local DailyCache = {}

local GROUND_Y = 1
local SPOT = Vector2.new(0, 26) -- lobby-relative x, z: between the south barrels, clear of the spawn ring

local function part(parent, name, size, cframe, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props or {} do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function label(parent, face, lines)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = parent
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Parent = gui
	for _, l in lines do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, -20, l.Height, 0)
		t.Font = l.Font
		t.TextScaled = true
		t.TextColor3 = l.Color
		t.Text = l.Text
		t.Parent = gui
	end
end

function DailyCache.Build(lobby)
	local old = lobby:FindFirstChild("DailyCache")
	if old then
		old:Destroy()
	end
	local origin = GameConfig.OurMap.LobbyCenter
	local model = Instance.new("Model")
	model.Name = "DailyCache"
	-- faces north, toward the flag and the spawn ring
	local base = CFrame.new(origin.X + SPOT.X, GROUND_Y, origin.Z + SPOT.Y)
	local wood = Color3.fromRGB(122, 92, 60)
	local olive = Color3.fromRGB(78, 88, 54)
	local dark = Color3.fromRGB(40, 44, 34)
	-- pallet
	for i = -1, 1 do
		part(model, "PalletSlat", Vector3.new(7, 0.3, 1.1), base * CFrame.new(0, 0.55, i * 1.6), wood, Enum.Material.WoodPlanks)
	end
	for i = -1, 1, 2 do
		part(model, "PalletRail", Vector3.new(0.6, 0.4, 4.4), base * CFrame.new(i * 3, 0.2, 0), wood, Enum.Material.WoodPlanks)
	end
	-- crates: two side by side, one on top (the one you claim)
	local function crate(name, cf, size)
		local c = part(model, name, size, cf, olive, Enum.Material.Metal)
		part(model, name .. "Band", Vector3.new(size.X + 0.1, 0.25, size.Z + 0.1), cf * CFrame.new(0, size.Y / 2 - 0.4, 0), dark, Enum.Material.Metal)
		return c
	end
	crate("CrateLeft", base * CFrame.new(-1.8, 1.9, 0), Vector3.new(3.2, 2.4, 3))
	crate("CrateRight", base * CFrame.new(1.8, 1.9, 0) * CFrame.Angles(0, math.rad(6), 0), Vector3.new(3.2, 2.4, 3))
	local top = crate("CrateTop", base * CFrame.new(0, 4.1, 0) * CFrame.Angles(0, math.rad(-4), 0), Vector3.new(3.4, 2, 2.8))
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(150, 255, 90)
	glow.Range = 10
	glow.Brightness = 1.2
	glow.Parent = top
	-- sign on a post behind the crates
	-- posts behind the board, so they don't cover its text
	part(model, "SignPost", Vector3.new(0.4, 8, 0.4), base * CFrame.new(-3.2, 4, 2.15), dark, Enum.Material.Metal)
	part(model, "SignPost", Vector3.new(0.4, 8, 0.4), base * CFrame.new(3.2, 4, 2.15), dark, Enum.Material.Metal)
	local board = part(model, "Sign", Vector3.new(7.4, 2.2, 0.25), base * CFrame.new(0, 7.2, 1.8), Color3.fromRGB(30, 33, 38), Enum.Material.Metal)
	label(board, Enum.NormalId.Front, {
		{ Text = "DAILY RATIONS", Height = 0.55, Font = Enum.Font.GothamBlack, Color = Color3.fromRGB(150, 255, 90) },
		{ Text = "Claim once a day. Days in a row pay more.", Height = 0.3, Font = Enum.Font.GothamBold, Color = Color3.fromRGB(220, 220, 215) },
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Claim rations"
	prompt.ObjectText = "Daily Rations"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Daily", true)
	prompt.Parent = top
	model.Parent = lobby
	return model
end

return DailyCache
