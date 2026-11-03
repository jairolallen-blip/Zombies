-- FieldStations: two lobby stations between the plaza and the Flight Line gate (vault: Lobby.md).
--   north-east  FIELD RESEARCH: a tarp over a specimen table; its prompt (attribute Shop = "Index") opens
--               the enemy index (Client ShopController "Index", rewards in Config/Zombies Index)
--   north-west  BOUNTY BOARD: a cork board with today's notices; its prompt (Shop = "Bounties") opens the
--               daily bounties (Config/Bounties)
-- Debris chunks inside either footprint are removed. OurLobby.Build calls this last. Safe to re-run.
--   local m = game.ServerScriptService.Server.Map.FieldStations
--   local c = m:Clone(); c.Parent = m.Parent; require(c).Build(workspace.OurMap.Lobby); c:Destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local FieldStations = {}

local GROUND_Y = 1
local INDEX_SPOT = Vector2.new(42, -30) -- lobby-relative x, z; faces west
local BOUNTY_SPOT = Vector2.new(-42, -38) -- faces east

local WOOD = Color3.fromRGB(122, 92, 60)
local DARK = Color3.fromRGB(40, 44, 34)
local OLIVE = Color3.fromRGB(78, 88, 54)

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

local function sign(board, title, sub, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Parent = gui
	for i, text in { title, sub } do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, -20, if i == 1 then 0.55 else 0.3, 0)
		t.Font = if i == 1 then Enum.Font.GothamBlack else Enum.Font.GothamBold
		t.TextScaled = true
		t.TextColor3 = if i == 1 then color else Color3.fromRGB(220, 220, 215)
		t.Text = text
		t.Parent = gui
	end
end

local function prompt(parent, action, object, shop)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p:SetAttribute("Shop", shop)
	p.Parent = parent
end

local function clearDebris(lobby, center, half)
	local debris = lobby:FindFirstChild("Debris")
	for _, d in if debris then debris:GetChildren() else {} do
		local p = if d:IsA("BasePart") then d.Position else (d:IsA("Model") and d:GetPivot().Position)
		if p and math.abs(p.X - center.X) < half.X and math.abs(p.Z - center.Z) < half.Y then
			d:Destroy()
		end
	end
end

-- base: CFrame on the ground at the station's centre, facing its front (-Z)
local function buildIndex(model, base)
	-- tarp on four poles
	for _, x in { -4.5, 4.5 } do
		for _, z in { -2.5, 3 } do
			part(model, "Pole", Vector3.new(0.35, 7.5, 0.35), base * CFrame.new(x, 3.75, z), DARK, Enum.Material.Metal)
		end
	end
	part(model, "Tarp", Vector3.new(10, 0.2, 6.5), base * CFrame.new(0, 7.6, 0.25) * CFrame.Angles(math.rad(-8), 0, 0), OLIVE, Enum.Material.Fabric)
	-- specimen table with jars
	local top = part(model, "Table", Vector3.new(8, 0.4, 2.6), base * CFrame.new(0, 3, 0), WOOD, Enum.Material.WoodPlanks)
	for _, x in { -3.6, 3.6 } do
		part(model, "TableLeg", Vector3.new(0.4, 2.8, 2.2), base * CFrame.new(x, 1.4, 0), DARK, Enum.Material.Metal)
	end
	for i, x in { -2.6, -0.9, 0.9, 2.6 } do
		local h = 1.2 + (i % 2) * 0.4
		local jar = part(model, "Jar", Vector3.new(h, 0.9, 0.9), base * CFrame.new(x, 3.2 + h / 2, 0.2) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(150, 255, 110), Enum.Material.Glass, { Shape = Enum.PartType.Cylinder, Transparency = 0.35 })
		part(model, "Lid", Vector3.new(0.15, 1, 1), jar.CFrame * CFrame.new(h / 2, 0, 0), DARK, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	end
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(150, 255, 110)
	glow.Range = 12
	glow.Brightness = 1
	glow.Parent = top
	-- sign board at the back
	local board = part(model, "Sign", Vector3.new(8, 2.4, 0.25), base * CFrame.new(0, 5.6, 3), Color3.fromRGB(30, 33, 38), Enum.Material.Metal)
	sign(board, "FIELD RESEARCH", "Enemy index. Kill one to study it.", Color3.fromRGB(150, 255, 110))
	prompt(top, "Open index", "Field Research", "Index")
end

local function buildBounties(model, base)
	for _, x in { -4.6, 4.6 } do
		part(model, "Post", Vector3.new(0.5, 8, 0.5), base * CFrame.new(x, 4, 0.3), WOOD, Enum.Material.Wood)
	end
	local board = part(model, "Board", Vector3.new(9, 4.6, 0.3), base * CFrame.new(0, 4.4, 0), Color3.fromRGB(150, 110, 70), Enum.Material.Cardboard)
	part(model, "Frame", Vector3.new(9.6, 5.2, 0.2), base * CFrame.new(0, 4.4, 0.15), DARK, Enum.Material.Wood)
	-- three notices, each with a red pin
	for i, x in { -2.9, 0, 2.9 } do
		local note = part(model, "Notice", Vector3.new(2.4, 3, 0.05), base * CFrame.new(x, 4.3, -0.18) * CFrame.Angles(0, 0, math.rad((i - 2) * 4)), Color3.fromRGB(232, 222, 190), Enum.Material.SmoothPlastic)
		part(model, "Pin", Vector3.new(0.25, 0.25, 0.25), note.CFrame * CFrame.new(0, 1.3, -0.08), Color3.fromRGB(200, 40, 40), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Ball })
	end
	local header = part(model, "Header", Vector3.new(8, 1.6, 0.25), base * CFrame.new(0, 7.6, 0.1), Color3.fromRGB(30, 33, 38), Enum.Material.Metal)
	sign(header, "BOUNTY BOARD", "New bounties every day. Track one at a time.", Color3.fromRGB(255, 200, 70))
	local lamp = part(model, "Lamp", Vector3.new(0.6, 0.6, 0.6), base * CFrame.new(0, 8.8, -0.6), Color3.fromRGB(255, 220, 150), Enum.Material.Neon)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 80
	light.Range = 12
	light.Brightness = 2
	light.Color = Color3.fromRGB(255, 220, 160)
	light.Parent = lamp
	prompt(board, "View bounties", "Bounty Board", "Bounties")
end

function FieldStations.Build(lobby)
	local old = lobby:FindFirstChild("FieldStations")
	if old then
		old:Destroy()
	end
	local origin = GameConfig.OurMap.LobbyCenter
	local model = Instance.new("Model")
	model.Name = "FieldStations"
	local index = Vector3.new(origin.X + INDEX_SPOT.X, GROUND_Y, origin.Z + INDEX_SPOT.Y)
	local bounty = Vector3.new(origin.X + BOUNTY_SPOT.X, GROUND_Y, origin.Z + BOUNTY_SPOT.Y)
	clearDebris(lobby, index, Vector2.new(7, 6))
	clearDebris(lobby, bounty, Vector2.new(7, 4))
	-- front (-Z of the base) faces the plaza side: west for the index, east for the board
	buildIndex(model, CFrame.lookAt(index, index + Vector3.new(-1, 0, 0)))
	buildBounties(model, CFrame.lookAt(bounty, bounty + Vector3.new(1, 0, 0)))
	model.Parent = lobby
	return model
end

return FieldStations
