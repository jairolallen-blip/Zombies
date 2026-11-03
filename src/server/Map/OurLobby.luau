-- OurLobby: builds our version's lobby, a fortified safehouse in a ruined city (vault: Lobby.md).
-- It is BAKED into Workspace.OurMap.Lobby in Edit mode so it can be hand-edited afterwards:
--   local m = game.ServerScriptService.Server.Map.OurLobby
--   local c = m:Clone(); c.Parent = m.Parent; require(c).Build(); c:Destroy()
--
-- Layout (north = -Z):
--   north   ruined building facades; a gate through them leads to the Flight Line (4 helipads, Map/FlightLine)
--   centre  concrete plaza with a flagpole and burning barrels; LobbySpawn pads ring it
--   west    armory tent (gun shop)       east  barracks: class mannequins behind sandbags
--   both shops have a ProximityPrompt (attribute Shop = "Armory" | "Classes") that opens
--   their UI on the client (Client/Controllers/ShopController)
--   sides   stacked shipping containers   south jersey barriers + chain-link fence
--   south   commendations board (achievements; prompt Shop = "Achievements"), facing the plaza
-- Parts named "LobbySpawn" are read by MapService:GetLobbySpawnCFrame().

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local ClassFigures = require(ReplicatedStorage.Shared.ClassFigures)

local OurLobby = {}

local GROUND_Y = 1 -- top of the floor (matches MapService.GroundY)
local HALF = 60 -- half-size of the walkable square
local PLAZA = Vector3.new(0, 0, 8) -- plaza centre, relative to the lobby centre
local HELIPAD = Vector3.new(0, 0, -34)

local C = {
	Asphalt = Color3.fromRGB(48, 48, 52),
	Crack = Color3.fromRGB(30, 30, 33),
	Concrete = Color3.fromRGB(128, 124, 116),
	ConcreteDark = Color3.fromRGB(86, 84, 80),
	Line = Color3.fromRGB(196, 164, 60),
	Containers = { Color3.fromRGB(122, 62, 38), Color3.fromRGB(58, 78, 96), Color3.fromRGB(84, 92, 58), Color3.fromRGB(128, 44, 36) },
	Sandbag = Color3.fromRGB(170, 150, 110),
	Canvas = Color3.fromRGB(92, 98, 66),
	Metal = Color3.fromRGB(70, 72, 76),
	Charred = Color3.fromRGB(32, 30, 30),
	Rust = Color3.fromRGB(110, 58, 36),
	Wood = Color3.fromRGB(110, 82, 52),
	Crate = Color3.fromRGB(78, 88, 54),
	White = Color3.fromRGB(220, 220, 215),
	Window = Color3.fromRGB(18, 18, 22),
	Fire = Color3.fromRGB(255, 150, 60),
}

local origin -- lobby centre (Vector3), set by Build
local rng

-- CFrame at lobby-relative x/z and ABSOLUTE y
local function at(x, y, z)
	return CFrame.new(origin.X + x, y, origin.Z + z)
end

local function part(parent, name, size, cframe, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props or {} do
		p[key] = value
	end
	p.Parent = parent
	return p
end

-- Vertical-axis cylinder (Roblox cylinders run along X, so roll it 90 degrees)
local function cylinder(parent, name, height, diameter, cframe, color, material, props)
	local p = part(parent, name, Vector3.new(height, diameter, diameter), cframe * CFrame.Angles(0, 0, math.rad(90)), color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function sign(p, face, text, background, textColor)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = background or Color3.new()
	label.BackgroundTransparency = if background then 0 else 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = textColor or C.White
	label.Parent = gui
end

-- Invisible anchor with a "press E" prompt; the client opens the matching shop UI.
local function shopPrompt(parent, cframe, shop, action)
	local anchor = part(parent, "ShopPrompt", Vector3.new(1, 1, 1), cframe, C.White, Enum.Material.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = shop:upper()
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt:SetAttribute("Shop", shop)
	prompt.Parent = anchor
	return anchor
end

local function fire(p, size)
	local f = Instance.new("Fire")
	f.Size = size or 5
	f.Heat = 9
	f.Parent = p
	local light = Instance.new("PointLight")
	light.Color = C.Fire
	light.Range = 18
	light.Brightness = 2
	light.Parent = p
end

-- Ground ------------------------------------------------------------------------------------------

local function buildGround(parent)
	local ground = model(parent, "Ground")
	part(ground, "Asphalt", Vector3.new(HALF * 2 + 4, 2, HALF * 2 + 4), at(0, GROUND_Y - 1, 0), C.Asphalt, Enum.Material.Asphalt)
	-- foundation under the whole footprint (ruins and containers overhang the asphalt), reaching below
	-- the seabed so no ocean shows between buildings; the terrain water inside it is cleared
	local footprint, footprintSize = at(0, GROUND_Y - 13.05, 4), Vector3.new(184, 26, 172)
	part(ground, "Foundation", footprintSize, footprint, C.ConcreteDark, Enum.Material.Slate)
	workspace.Terrain:FillBlock(footprint, footprintSize, Enum.Material.Air)
	part(ground, "Plaza", Vector3.new(40, 0.2, 40), at(PLAZA.X, GROUND_Y + 0.1, PLAZA.Z), C.Concrete, Enum.Material.Concrete)
	part(ground, "PlazaCurb", Vector3.new(42, 0.1, 42), at(PLAZA.X, GROUND_Y + 0.05, PLAZA.Z), C.ConcreteDark, Enum.Material.Concrete)
	-- faded centre line of the old street running east-west
	for x = -HALF + 4, HALF - 8, 10 do
		part(ground, "RoadLine", Vector3.new(6, 0.05, 0.6), at(x + 3, GROUND_Y + 0.03, 40), C.Line, Enum.Material.SmoothPlastic, { Transparency = 0.25 })
	end
	for _ = 1, 34 do
		local x, z = rng:NextNumber(-HALF + 4, HALF - 4), rng:NextNumber(-HALF + 4, HALF - 4)
		local crack = part(ground, "Crack", Vector3.new(rng:NextNumber(0.2, 0.5), 0.05, rng:NextNumber(4, 12)), at(x, GROUND_Y + 0.03, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), C.Crack, Enum.Material.SmoothPlastic)
		crack.CanCollide = false
		if math.abs(x - PLAZA.X) < 22 and math.abs(z - PLAZA.Z) < 22 then
			crack:Destroy() -- not on the plaza slab (made after the rng calls, so the rest of the layout stays the same)
		end
	end
end

-- Edges -------------------------------------------------------------------------------------------

local function container(parent, x, y, z, rotY, color)
	local m = model(parent, "Container")
	local base = at(x, y + 4.5, z) * CFrame.Angles(0, rotY, 0)
	part(m, "Body", Vector3.new(8, 9, 20), base, color, Enum.Material.Metal)
	for _, dz in { -10, 10 } do
		part(m, "Frame", Vector3.new(8.3, 9.3, 0.6), base * CFrame.new(0, 0, dz), color:Lerp(Color3.new(), 0.35), Enum.Material.Metal)
	end
	for i = -3, 3 do
		part(m, "Rib", Vector3.new(8.15, 8.4, 0.3), base * CFrame.new(0, 0, i * 2.6), color:Lerp(Color3.new(), 0.15), Enum.Material.Metal)
	end
end

local function buildContainerWalls(parent)
	local walls = model(parent, "Containers")
	local i = 0
	for _, side in { -1, 1 } do
		for z = -46, 46, 21 do
			i += 1
			local x = side * (HALF - 3)
			container(walls, x, GROUND_Y, z, rng:NextNumber(-0.04, 0.04), C.Containers[i % #C.Containers + 1])
			if i % 2 == 0 then
				container(walls, x + side * 0.5, GROUND_Y + 9, z + rng:NextNumber(-2, 2), rng:NextNumber(-0.12, 0.12), C.Containers[(i + 2) % #C.Containers + 1])
			end
		end
	end
end

-- A ruined building: facade with window holes and a jagged, broken top.
local function ruin(parent, x, z, width, height, depth, faceSign)
	local m = model(parent, "Ruin")
	local shade = C.ConcreteDark:Lerp(C.Concrete, rng:NextNumber(0, 0.6))
	part(m, "Body", Vector3.new(width, height, depth), at(x, GROUND_Y + height / 2, z), shade, Enum.Material.Concrete)
	local faceZ = z + faceSign * (depth / 2 + 0.15)
	for y = 8, height - 6, 8 do
		for wx = -width / 2 + 4, width / 2 - 4, 6 do
			if rng:NextNumber() < 0.85 then
				local lit = rng:NextNumber() < 0.08
				part(m, "Window", Vector3.new(3, 4, 0.4), at(x + wx, GROUND_Y + y, faceZ), if lit then C.Fire else C.Window, if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic, { Transparency = if lit then 0.4 else 0 })
			end
		end
		part(m, "Ledge", Vector3.new(width + 0.6, 0.6, 0.8), at(x, GROUND_Y + y - 3, faceZ), shade:Lerp(Color3.new(), 0.2), Enum.Material.Concrete)
	end
	-- broken top: uneven chunks of wall
	local wx = -width / 2
	while wx < width / 2 do
		local w = math.min(rng:NextNumber(3, 7), width / 2 - wx)
		local h = rng:NextNumber(0, 7)
		if h > 1 then
			part(m, "Rubble", Vector3.new(w, h, depth * rng:NextNumber(0.3, 1)), at(x + wx + w / 2, GROUND_Y + height + h / 2, z) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), 0, rng:NextNumber(-0.15, 0.15)), shade, Enum.Material.Concrete)
		end
		wx += w
	end
	return m
end

local function buildRuins(parent)
	local ruins = model(parent, "Ruins")
	local north = { { -40, 34, 46 }, { 0, 36, 62 }, { 40, 34, 40 } }
	for i, r in north do
		local m = ruin(ruins, r[1], -HALF - 7, r[2], r[3], 12, 1)
		if i == 2 then
			local smoke = Instance.new("Smoke")
			smoke.Color = Color3.fromRGB(60, 58, 56)
			smoke.Size = 20
			smoke.RiseVelocity = 6
			smoke.Opacity = 0.35
			smoke.Parent = m.Body
		end
	end
	for _, r in { { -46, 26, 22 }, { 0, 30, 16 }, { 46, 26, 26 } } do
		ruin(ruins, r[1], HALF + 16, r[2], r[3], 10, -1)
	end
	-- east/west skyline behind the containers (rotated so their windows face the lobby)
	for _, side in { -1, 1 } do
		for i, z in { -44, -12, 20, 50 } do
			local height = 28 + ((i * 17 + (if side > 0 then 9 else 0)) % 24)
			local m = ruin(ruins, 0, 0, 30, height, 14, 1)
			m.WorldPivot = m.Body.CFrame
			m:PivotTo(at(side * (HALF + 16), GROUND_Y + height / 2, z) * CFrame.Angles(0, -side * math.rad(90), 0))
		end
	end
end

local function sandbagWall(parent, from, to, rows)
	local dir = (to - from)
	local length = dir.Magnitude
	local look = CFrame.lookAt(Vector3.zero, dir.Unit)
	local count = math.max(1, math.floor(length / 2.4))
	for row = 0, rows - 1 do
		for i = 0, count - 1 do
			local t = (i + 0.5 + (row % 2) * 0.5) / count
			if t <= 1 then
				local p = from + dir * math.min(t, 1)
				part(parent, "Sandbag", Vector3.new(1.6, 1.1, 2.6), at(p.X, GROUND_Y + 0.55 + row * 1.05, p.Z) * look * CFrame.Angles(0, rng:NextNumber(-0.08, 0.08), 0), C.Sandbag:Lerp(Color3.new(), rng:NextNumber(0, 0.15)), Enum.Material.Fabric)
			end
		end
	end
end

local function buildSouthBarricade(parent)
	local m = model(parent, "Barricade")
	local z = HALF - 2
	for x = -HALF + 4, HALF - 4, 8.5 do
		if math.abs(x) > 8 then
			part(m, "JerseyBarrier", Vector3.new(8, 3.2, 2), at(x, GROUND_Y + 1.6, z) * CFrame.Angles(0, rng:NextNumber(-0.06, 0.06), 0), C.Concrete, Enum.Material.Concrete)
			part(m, "BarrierStripe", Vector3.new(8.05, 0.5, 2.05), at(x, GROUND_Y + 2.6, z), Color3.fromRGB(200, 60, 40), Enum.Material.SmoothPlastic)
		end
	end
	-- the old gate: blocked off with angled barriers and sandbags
	part(m, "JerseyBarrier", Vector3.new(8, 3.2, 2), at(-3, GROUND_Y + 1.6, z - 2) * CFrame.Angles(0, 0.35, 0), C.Concrete, Enum.Material.Concrete)
	part(m, "JerseyBarrier", Vector3.new(8, 3.2, 2), at(4, GROUND_Y + 1.6, z + 1) * CFrame.Angles(0, -0.3, 0), C.Concrete, Enum.Material.Concrete)
	sandbagWall(m, Vector3.new(-9, 0, z - 4), Vector3.new(9, 0, z - 4), 2)
	-- chain-link fence along the barriers
	local fence = model(m, "Fence")
	for x = -HALF + 2, HALF - 2, 8 do
		part(fence, "Post", Vector3.new(0.4, 10, 0.4), at(x, GROUND_Y + 5, z + 1.6), C.Metal, Enum.Material.Metal)
	end
	part(fence, "Mesh", Vector3.new(HALF * 2 - 4, 9, 0.1), at(0, GROUND_Y + 4.5, z + 1.6), C.Metal, Enum.Material.DiamondPlate, { Transparency = 0.65 })
	part(fence, "Wire", Vector3.new(HALF * 2 - 4, 0.15, 0.15), at(0, GROUND_Y + 9.8, z + 1.6), C.Metal, Enum.Material.Metal)
end

-- Centre ------------------------------------------------------------------------------------------

local function buildHelipad(parent)
	local m = model(parent, "Helipad")
	local c = at(HELIPAD.X, GROUND_Y, HELIPAD.Z)
	cylinder(m, "Pad", 0.4, 30, c * CFrame.new(0, 0.2, 0), C.ConcreteDark, Enum.Material.Concrete)
	cylinder(m, "Ring", 0.42, 27, c * CFrame.new(0, 0.22, 0), C.Line, Enum.Material.SmoothPlastic)
	cylinder(m, "Inner", 0.44, 25.5, c * CFrame.new(0, 0.24, 0), C.ConcreteDark, Enum.Material.Concrete)
	for _, dx in { -3.5, 3.5 } do
		part(m, "H", Vector3.new(1.6, 0.05, 11), c * CFrame.new(dx, 0.48, 0), C.White, Enum.Material.SmoothPlastic)
	end
	part(m, "H", Vector3.new(5.4, 0.05, 1.6), c * CFrame.new(0, 0.48, 0), C.White, Enum.Material.SmoothPlastic)
	for i = 0, 7 do
		local a = i * math.pi / 4
		local light = part(m, "EdgeLight", Vector3.new(0.8, 0.5, 0.8), c * CFrame.new(math.cos(a) * 15.5, 0.25, math.sin(a) * 15.5), Color3.fromRGB(255, 60, 50), Enum.Material.Neon)
		local glow = Instance.new("PointLight")
		glow.Color = light.Color
		glow.Range = 8
		glow.Parent = light
	end
	local post = part(m, "SignPost", Vector3.new(0.5, 8, 0.5), c * CFrame.new(-18, 4, 10), C.Metal, Enum.Material.Metal)
	local board = part(m, "Sign", Vector3.new(10, 3, 0.3), post.CFrame * CFrame.new(0, 3, 0.4), C.Line, Enum.Material.Metal)
	sign(board, Enum.NormalId.Back, "DEPLOY ZONE", C.Line, Color3.fromRGB(25, 25, 25))
end

local function buildArmory(parent)
	local m = model(parent, "Armory")
	local c = at(-30, GROUND_Y, PLAZA.Z)
	for _, corner in { { -6, -8 }, { 6, -8 }, { -6, 8 }, { 6, 8 } } do
		part(m, "Post", Vector3.new(0.6, 9, 0.6), c * CFrame.new(corner[1], 4.5, corner[2]), C.Metal, Enum.Material.Metal)
	end
	for _, s in { -1, 1 } do
		part(m, "Canvas", Vector3.new(7.4, 0.3, 18), c * CFrame.new(s * 3.3, 10.2, 0) * CFrame.Angles(0, 0, s * math.rad(-22)), C.Canvas, Enum.Material.Fabric)
	end
	part(m, "Table", Vector3.new(4, 0.5, 12), c * CFrame.new(2, 3.6, 0), C.Wood, Enum.Material.WoodPlanks)
	for _, dz in { -5, 5 } do
		part(m, "Leg", Vector3.new(3.6, 3.4, 0.4), c * CFrame.new(2, 1.7, dz), C.Metal, Enum.Material.Metal)
	end
	for i = -2, 2 do
		part(m, "GunCase", Vector3.new(1.4, 0.7, 1.9), c * CFrame.new(2, 4.2, i * 2.3) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), C.Crate, Enum.Material.Metal)
	end
	for _, pos in { { -3, -5 }, { -3, -2.5 }, { -3.2, -3.8, 2 }, { -3, 5 } } do
		part(m, "AmmoCrate", Vector3.new(2.4, 2, 2.4), c * CFrame.new(pos[1], 1 + (if pos[3] then 2 else 0), pos[2]), C.Crate, Enum.Material.WoodPlanks)
	end
	local board = part(m, "Sign", Vector3.new(0.3, 3, 12), c * CFrame.new(6.4, 7.4, 0), C.Charred, Enum.Material.Metal)
	sign(board, Enum.NormalId.Right, "ARMORY · GUNS", Color3.fromRGB(30, 34, 28), Color3.fromRGB(150, 255, 90))
	shopPrompt(m, c * CFrame.new(5, 3, 0), "Armory", "Browse guns")
end

-- Barracks: an open-front army tent on a plank deck, one class figure per pedestal facing the plaza
-- (west), each with a lit nameplate and a spotlight in its class colour, string lights along the
-- front beam, lockers and a weapon rack at the back, sandbags at the front corners.
local function buildBarracks(parent)
	local m = model(parent, "Barracks")
	local cx, cz = 30, PLAZA.Z
	local c = at(cx, GROUND_Y, cz) -- deck front edge centre; +X = back of the tent
	local DECK = 0.6
	local warm = Color3.fromRGB(255, 200, 120)

	-- deck and step
	part(m, "Deck", Vector3.new(16, DECK, 27), c * CFrame.new(8, DECK / 2, 0), C.Wood, Enum.Material.WoodPlanks)
	part(m, "DeckEdge", Vector3.new(0.3, DECK + 0.05, 27.2), c * CFrame.new(0, DECK / 2, 0), C.Metal, Enum.Material.Metal)
	part(m, "Step", Vector3.new(1.6, DECK / 2, 10), c * CFrame.new(-0.8, DECK / 4, 0), C.Wood, Enum.Material.WoodPlanks)

	-- tent: posts, front beam, two roof slopes, back and side walls
	for _, corner in { { 0.5, -13 }, { 0.5, 13 }, { 15.5, -13 }, { 15.5, 13 } } do
		part(m, "Post", Vector3.new(0.6, 10.5, 0.6), c * CFrame.new(corner[1], DECK + 5.25, corner[2]), C.Metal, Enum.Material.Metal)
	end
	part(m, "FrontBeam", Vector3.new(0.6, 0.8, 27), c * CFrame.new(0.5, DECK + 10.2, 0), C.Metal, Enum.Material.Metal)
	for _, s in { -1, 1 } do
		part(m, "Roof", Vector3.new(8.8, 0.3, 28), c * CFrame.new(8 + s * 4, DECK + 11.6, 0) * CFrame.Angles(0, 0, s * -0.3), C.Canvas, Enum.Material.Fabric)
	end
	part(m, "BackWall", Vector3.new(0.3, 10.5, 26.4), c * CFrame.new(15.6, DECK + 5.25, 0), C.Canvas:Lerp(Color3.new(), 0.15), Enum.Material.Fabric)
	for _, s in { -1, 1 } do
		part(m, "SideWall", Vector3.new(9, 10.5, 0.3), c * CFrame.new(11, DECK + 5.25, s * 13.1), C.Canvas:Lerp(Color3.new(), 0.1), Enum.Material.Fabric)
	end
	for i = 1, 6 do -- camo patches on the back wall
		part(m, "Camo", Vector3.new(0.1, rng:NextNumber(1.5, 3), rng:NextNumber(2.5, 5)), c * CFrame.new(15.4, DECK + rng:NextNumber(2.5, 8.5), -11 + i * 3.6 + rng:NextNumber(-1, 1)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, 0), C.Crate:Lerp(Color3.new(), 0.3), Enum.Material.Fabric)
	end

	-- sign under the front beam
	local board = part(m, "Sign", Vector3.new(0.3, 2.2, 13), c * CFrame.new(0.3, DECK + 8.7, 0), C.Charred, Enum.Material.Metal)
	sign(board, Enum.NormalId.Left, "BARRACKS · CLASSES", Color3.fromRGB(30, 34, 28), Color3.fromRGB(150, 255, 90))

	-- string lights sagging along the front beam
	for i = -6, 6 do
		local z = i * 2.1
		local sag = 0.8 * (1 - (z / 13) ^ 2)
		local bulb = part(m, "Bulb", Vector3.new(0.45, 0.45, 0.45), c * CFrame.new(0.1, DECK + 9.6 - sag, z), warm, Enum.Material.Neon, { Shape = Enum.PartType.Ball, CanCollide = false })
		if i % 3 == 0 then
			local light = Instance.new("PointLight")
			light.Color = warm
			light.Range = 14
			light.Brightness = 0.9
			light.Parent = bulb
		end
	end

	-- pedestals: figure, glowing ring, nameplate, spotlight
	local ids = {}
	for id in Classes.List do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Classes.List[a].Order < Classes.List[b].Order
	end)
	local faceWest = CFrame.Angles(0, math.rad(90), 0) -- figures face -Z; turn them toward the plaza
	for i, id in ids do
		local class = Classes.List[id]
		local z = (i - (#ids + 1) / 2) * 5
		local base = c * CFrame.new(6 + math.abs(z) * 0.12, DECK, z)
		cylinder(m, "Pedestal", 0.8, 3.2, base * CFrame.new(0, 0.4, 0), C.ConcreteDark, Enum.Material.Concrete)
		cylinder(m, "PedestalRing", 0.14, 3.35, base * CFrame.new(0, 0.72, 0), class.Color, Enum.Material.Neon)
		local plate = part(m, "Nameplate", Vector3.new(0.25, 0.7, 2.8), base * CFrame.new(-2.1, 0.45, 0) * CFrame.Angles(0, 0, math.rad(-25)), C.Charred, Enum.Material.Metal)
		sign(plate, Enum.NormalId.Left, class.DisplayName:upper(), Color3.fromRGB(22, 24, 22), class.Color)
		local figure = ClassFigures.Build(id)
		figure:PivotTo(base * CFrame.new(0, 0.8 + 3, 0) * faceWest) -- pivot = torso, 3 studs above the feet
		figure.Parent = m
		local lamp = part(m, "Spot", Vector3.new(0.9, 0.6, 0.9), base * CFrame.new(-1, 9.6, 0), C.Metal, Enum.Material.Metal)
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Bottom
		spot.Angle = 45
		spot.Range = 14
		spot.Brightness = 2.5
		spot.Color = class.Color:Lerp(Color3.new(1, 1, 1), 0.45)
		spot.Parent = lamp
	end

	-- back of the tent: weapon rack, lockers, footlockers, crates
	local rack = c * CFrame.new(14.8, DECK, -8)
	part(m, "RackFrame", Vector3.new(0.8, 4.2, 5.5), rack * CFrame.new(0, 2.1, 0), C.Wood, Enum.Material.WoodPlanks)
	for k = -2, 2 do
		part(m, "RackRifle", Vector3.new(0.3, 3.6, 0.4), rack * CFrame.new(-0.5, 2.2, k * 1.05) * CFrame.Angles(math.rad(8), 0, 0), Color3.fromRGB(34, 35, 38), Enum.Material.Metal)
	end
	for k = 0, 2 do
		local locker = part(m, "Locker", Vector3.new(1.4, 6.5, 2.2), c * CFrame.new(14.6, DECK + 3.25, 3.5 + k * 2.3), Color3.fromRGB(72, 84, 70), Enum.Material.Metal)
		part(m, "LockerVent", Vector3.new(0.05, 0.8, 1.4), locker.CFrame * CFrame.new(-0.72, 2.3, 0), C.Charred, Enum.Material.Metal)
	end
	for _, z in { -11.5, 11 } do
		part(m, "Footlocker", Vector3.new(2.2, 1.2, 3), c * CFrame.new(12.5, DECK + 0.6, z), Color3.fromRGB(70, 78, 52), Enum.Material.Metal)
	end
	part(m, "AmmoCrate", Vector3.new(2.2, 1.8, 2.2), c * CFrame.new(13.8, DECK + 0.9, -12) * CFrame.Angles(0, 0.3, 0), C.Crate, Enum.Material.WoodPlanks)
	part(m, "AmmoCrate", Vector3.new(2, 1.6, 2), c * CFrame.new(13.9, DECK + 2.6, -12.1) * CFrame.Angles(0, -0.2, 0), C.Crate, Enum.Material.WoodPlanks)

	-- sandbags guarding the front corners
	sandbagWall(m, Vector3.new(cx - 1.5, 0, cz - 13.5), Vector3.new(cx - 1.5, 0, cz - 7), 2)
	sandbagWall(m, Vector3.new(cx - 1.5, 0, cz + 7), Vector3.new(cx - 1.5, 0, cz + 13.5), 2)

	shopPrompt(m, c * CFrame.new(1.5, 3, 0), "Classes", "Choose class")
end

-- Commendations: the achievements board south of the plaza, facing it. A corkboard of pinned
-- papers and medals under an awning; the Status sign is rewritten by the client (ShopController)
-- with how many achievements are ready to claim; an open crate of gems beside it.
local function buildCommendations(parent)
	local m = model(parent, "Commendations")
	local c = at(0, GROUND_Y, 44) -- front of the board faces -Z (the plaza)
	local warm = Color3.fromRGB(255, 220, 160)
	part(m, "Slab", Vector3.new(22, 0.4, 8), c * CFrame.new(0, 0.2, -1), C.ConcreteDark, Enum.Material.Concrete)
	for _, x in { -8.4, 8.4 } do
		part(m, "Post", Vector3.new(0.8, 11, 0.8), c * CFrame.new(x, 5.5, 0.6), C.Wood, Enum.Material.WoodPlanks)
	end
	part(m, "Backing", Vector3.new(16.4, 7.4, 0.5), c * CFrame.new(0, 5.8, 0.6), C.Wood, Enum.Material.WoodPlanks)
	part(m, "Cork", Vector3.new(15.4, 6.6, 0.2), c * CFrame.new(0, 5.8, 0.3), Color3.fromRGB(176, 128, 82), Enum.Material.Sand)
	local header = part(m, "Header", Vector3.new(15.6, 1.8, 0.4), c * CFrame.new(0, 10.3, 0.2), C.Charred, Enum.Material.Metal)
	sign(header, Enum.NormalId.Front, "COMMENDATIONS", Color3.fromRGB(30, 34, 28), Color3.fromRGB(150, 255, 90))
	local status = part(m, "Status", Vector3.new(9, 1.1, 0.3), c * CFrame.new(0, 1.55, 0.3), C.Charred, Enum.Material.Metal)
	sign(status, Enum.NormalId.Front, "KEEP FIGHTING", Color3.fromRGB(22, 24, 22), C.White)
	-- pinned papers and three medals
	for i = 1, 14 do
		local x, y = -6.4 + ((i - 1) % 7) * 2.1 + rng:NextNumber(-0.3, 0.3), if i <= 7 then 7.2 else 4.6
		local paper = part(m, "Paper", Vector3.new(1.5, 1.9, 0.05), c * CFrame.new(x, y + rng:NextNumber(-0.4, 0.4), 0.17) * CFrame.Angles(0, 0, rng:NextNumber(-0.18, 0.18)), Color3.fromRGB(236, 230, 210):Lerp(Color3.fromRGB(210, 190, 150), rng:NextNumber()), Enum.Material.SmoothPlastic)
		part(m, "Pin", Vector3.new(0.18, 0.18, 0.12), paper.CFrame * CFrame.new(0, 0.75, -0.06), Color3.fromRGB(200, 40, 40), Enum.Material.SmoothPlastic)
	end
	for i, color in { Color3.fromRGB(230, 190, 60), Color3.fromRGB(200, 205, 215), Color3.fromRGB(190, 120, 70) } do
		local x = (i - 2) * 1.6
		part(m, "Ribbon", Vector3.new(0.5, 0.9, 0.05), c * CFrame.new(x, 8.75, 0.12), Color3.fromRGB(160, 40, 40), Enum.Material.Fabric)
		cylinder(m, "Medal", 0.12, 0.8, c * CFrame.new(x, 8.15, 0.1) * CFrame.Angles(math.rad(90), 0, 0), color, Enum.Material.Metal)
	end
	-- awning with two lamps on the board
	part(m, "Awning", Vector3.new(19, 0.3, 4), c * CFrame.new(0, 11.4, -1.3) * CFrame.Angles(math.rad(-8), 0, 0), C.Metal, Enum.Material.Metal)
	for _, x in { -5, 5 } do
		local lamp = part(m, "Lamp", Vector3.new(1, 0.5, 0.8), c * CFrame.new(x, 11, -2.4), C.Metal, Enum.Material.Metal)
		part(m, "Bulb", Vector3.new(0.7, 0.1, 0.5), lamp.CFrame * CFrame.new(0, -0.3, 0), warm, Enum.Material.Neon)
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Bottom
		spot.Angle = 70
		spot.Range = 16
		spot.Brightness = 1.6
		spot.Color = warm
		spot.Parent = lamp
	end
	-- open crate of gems
	local crate = c * CFrame.new(11.2, 1.4, -1)
	part(m, "GemCrate", Vector3.new(2.8, 2, 2.8), crate, C.Crate, Enum.Material.WoodPlanks)
	part(m, "GemLid", Vector3.new(2.8, 0.25, 2.8), crate * CFrame.new(0, 1.4, 1.6) * CFrame.Angles(math.rad(-70), 0, 0), C.Crate, Enum.Material.WoodPlanks)
	local gemColor = Color3.fromRGB(170, 110, 255)
	for _ = 1, 9 do
		part(m, "Gem", Vector3.new(0.5, 0.5, 0.5), crate * CFrame.new(rng:NextNumber(-0.9, 0.9), 1.05 + rng:NextNumber(0, 0.3), rng:NextNumber(-0.9, 0.9)) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0), gemColor, Enum.Material.Neon, { CanCollide = false })
	end
	local glow = Instance.new("PointLight")
	glow.Color = gemColor
	glow.Range = 10
	glow.Brightness = 1.2
	glow.Parent = m:FindFirstChild("GemCrate")
	shopPrompt(m, c * CFrame.new(0, 3, -3), "Achievements", "View achievements")
end

-- Rebuilds one area inside the baked lobby (keeps every other hand edit):
--   require(<clone of this module>).Rebuild("Barracks")   -- or "Commendations"
local AREAS = { Barracks = buildBarracks, Commendations = buildCommendations }
function OurLobby.Rebuild(name)
	origin = GameConfig.OurMap.LobbyCenter
	rng = Random.new(2611)
	local lobby = workspace[GameConfig.OurMap.Folder].Lobby
	local old = lobby:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	AREAS[name](lobby)
end

local function buildFloodlight(parent, x, z)
	local m = model(parent, "Floodlight")
	part(m, "Pole", Vector3.new(1, 22, 1), at(x, GROUND_Y + 11, z), C.Metal, Enum.Material.Metal)
	local headPos = Vector3.new(origin.X + x, GROUND_Y + 22, origin.Z + z)
	local target = Vector3.new(origin.X + PLAZA.X, GROUND_Y, origin.Z + PLAZA.Z)
	local head = part(m, "Head", Vector3.new(4, 2.4, 1.4), CFrame.lookAt(headPos, target), C.Metal, Enum.Material.Metal)
	part(m, "Lens", Vector3.new(3.6, 2, 0.1), head.CFrame * CFrame.new(0, 0, -0.72), Color3.fromRGB(255, 240, 200), Enum.Material.Neon)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Angle = 70
	light.Range = 60
	light.Brightness = 1.6
	light.Color = Color3.fromRGB(255, 240, 210)
	light.Parent = head
end

local function buildPlaza(parent)
	local m = model(parent, "Plaza")
	local c = at(PLAZA.X, GROUND_Y, PLAZA.Z)
	cylinder(m, "FlagBase", 1, 4, c * CFrame.new(0, 0.5, 0), C.ConcreteDark, Enum.Material.Concrete)
	part(m, "FlagPole", Vector3.new(0.5, 20, 0.5), c * CFrame.new(0, 10, 0), C.Metal, Enum.Material.Metal)
	-- the flag flies east-west so it faces the plaza (north-south it was edge-on); three panels give it a wave
	local flagAt = c * CFrame.new(0.25, 17.8, 0)
	for i, yaw in { 8, -10, 6 } do
		flagAt = flagAt * CFrame.Angles(0, math.rad(yaw), 0)
		part(m, "Flag", Vector3.new(2.05, 3.4 - i * 0.15, 0.1), flagAt * CFrame.new(1, -i * 0.08, 0), Color3.fromRGB(140, 40, 34), Enum.Material.Fabric)
		flagAt = flagAt * CFrame.new(2, 0, 0)
	end
	for _, corner in { { -16, -16 }, { 16, -16 }, { -16, 16 }, { 16, 16 } } do
		local barrel = cylinder(m, "FireBarrel", 3.4, 2.4, c * CFrame.new(corner[1], 1.7, corner[2]), C.Rust, Enum.Material.Metal)
		fire(barrel, 4)
	end
	-- LobbySpawn pads: invisible, facing the helipad
	local helipad = Vector3.new(origin.X + HELIPAD.X, GROUND_Y, origin.Z + HELIPAD.Z)
	for i = 0, 7 do
		local a = i * math.pi / 4 + math.pi / 8
		local pos = Vector3.new(origin.X + PLAZA.X + math.cos(a) * 10, GROUND_Y + 0.5, origin.Z + PLAZA.Z + math.sin(a) * 10)
		part(m, "LobbySpawn", Vector3.new(4, 1, 4), CFrame.lookAt(pos, Vector3.new(helipad.X, pos.Y, helipad.Z)), C.White, Enum.Material.SmoothPlastic, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
	end
end

local function car(parent, x, z, rotY, flipped)
	local m = model(parent, "BurntCar")
	local base = at(x, GROUND_Y + (if flipped then 3.1 else 1.7), z) * CFrame.Angles(0, rotY, 0) * (if flipped then CFrame.Angles(0, 0, math.pi) else CFrame.identity)
	part(m, "Body", Vector3.new(7, 2.2, 15), base, C.Charred, Enum.Material.Metal)
	part(m, "Cabin", Vector3.new(6.4, 2, 7), base * CFrame.new(0, 2.1, 1), C.Charred:Lerp(C.Rust, 0.3), Enum.Material.Metal)
	part(m, "Windshield", Vector3.new(5.8, 1.6, 0.2), base * CFrame.new(0, 2.1, -2.55), C.Window, Enum.Material.Glass, { Transparency = 0.3 })
	for _, w in { { -3.4, -4.5 }, { 3.4, -4.5 }, { -3.4, 4.5 }, { 3.4, 4.5 } } do
		local wheel = part(m, "Wheel", Vector3.new(1, 2.6, 2.6), base * CFrame.new(w[1], -1, w[2]), Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic)
		wheel.Shape = Enum.PartType.Cylinder
	end
end

local function buildDebris(parent)
	local m = model(parent, "Debris")
	car(m, -40, 42, math.rad(20), false)
	car(m, 44, 44, math.rad(-62), false)
	car(m, -42, -24, math.rad(80), true)
	for _, pos in { { 46, -20 }, { -46, 20 }, { 20, 50 } } do
		for i = 0, 2 do
			cylinder(m, "Tire", 1, 3, at(pos[1] + rng:NextNumber(-0.3, 0.3), GROUND_Y + 0.5 + i, pos[2]), Color3.fromRGB(22, 22, 22), Enum.Material.SmoothPlastic)
		end
	end
	local placed = 0
	while placed < 26 do
		local x, z = rng:NextNumber(-HALF + 8, HALF - 8), rng:NextNumber(-HALF + 6, HALF - 6)
		local nearPlaza = math.abs(x - PLAZA.X) < 26 and math.abs(z - PLAZA.Z) < 26
		local nearPad = (Vector3.new(x, 0, z) - HELIPAD).Magnitude < 20
		local inBarracks = x > 27 and x < 48 and math.abs(z - PLAZA.Z) < 16
		local atBoard = math.abs(x) < 16 and z > 33 and z < 52
		if not nearPlaza and not nearPad and not inBarracks and not atBoard then
			local s = rng:NextNumber(1, 3.5)
			part(m, "Chunk", Vector3.new(s * rng:NextNumber(0.8, 1.6), s * 0.7, s), at(x, GROUND_Y + s * 0.3, z) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi), rng:NextNumber(-0.4, 0.4)), C.Concrete:Lerp(C.ConcreteDark, rng:NextNumber()), Enum.Material.Concrete)
			placed += 1
		end
	end
	for _, pos in { { -48, -48 }, { 48, 50 }, { 48, -48 } } do
		local barrel = cylinder(m, "FireBarrel", 3.4, 2.4, at(pos[1], GROUND_Y + 1.7, pos[2]), C.Rust, Enum.Material.Metal)
		fire(barrel, 5)
	end
end

local function buildBounds(parent)
	local m = model(parent, "Bounds")
	local props = { Transparency = 1, CanQuery = false }
	for _, s in { -1, 1 } do
		part(m, "InvisibleWall", Vector3.new(2, 80, HALF * 2 + 8), at(s * (HALF + 1), GROUND_Y + 40, 0), C.White, Enum.Material.SmoothPlastic, props)
		part(m, "InvisibleWall", Vector3.new(HALF * 2 + 8, 80, 2), at(0, GROUND_Y + 40, s * (HALF + 1)), C.White, Enum.Material.SmoothPlastic, props)
	end
end

-- Builds (replacing) Workspace.<OurMap.Folder>.Lobby around GameConfig.OurMap.LobbyCenter.
function OurLobby.Build()
	origin = GameConfig.OurMap.LobbyCenter
	rng = Random.new(2611)
	local root = workspace:FindFirstChild(GameConfig.OurMap.Folder)
	if not root then
		root = Instance.new("Folder")
		root.Name = GameConfig.OurMap.Folder
		root.Parent = workspace
	end
	local old = root:FindFirstChild("Lobby")
	if old then
		old:Destroy()
	end
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	buildGround(lobby)
	buildContainerWalls(lobby)
	buildRuins(lobby)
	buildSouthBarricade(lobby)
	buildHelipad(lobby)
	buildArmory(lobby)
	buildBarracks(lobby)
	buildCommendations(lobby)
	buildFloodlight(lobby, -44, -46)
	buildFloodlight(lobby, 44, -46)
	buildPlaza(lobby)
	buildDebris(lobby)
	buildBounds(lobby)
	lobby.Parent = root
	require(script.Parent.FlightLine).Build(lobby) -- the 4-pad take-off deck north of the courtyard
	require(script.Parent.Commons).Build(lobby) -- the hangout area south of the courtyard
	require(script.Parent.Survivors).Build(lobby) -- the safehouse's people (Config/Survivors)
	return lobby
end

return OurLobby
