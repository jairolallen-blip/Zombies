-- Commons: the safehouse's hangout area south of the courtyard (vault: Lobby.md). The old south gate
-- (it was blocked with barriers) is open again and leads to:
--   centre  a campfire ring with log benches and two beat-up couches under string lights
--   west    the mess tent: long tables, benches, a cooking barrel, crates of cans
--   east    sleeping tents with cots
--   corners a radio shack (south-east) with live chatter, and a hoop and crates to sit on (south-west)
--   entry   the Commendations board (moved here from in front of the gate) and the TOP SURVIVORS board
-- Things to do (Server/Services/CommonsService): sit on any couch, log or mess bench (Seats); "Listen in"
-- at the radio for an Overwatch broadcast; "Shoot" the ball at the hoop; read the global best-wave board.
-- The south ruins move back to the new edge. Sounds: every fire (here and the courtyard's barrels) gets a
-- looped crackle and the radio shack plays chatter; they are Sounds named "LobbyAmbient" that
-- Client/Controllers/LobbyAudioController starts (ids in Shared/Config/Sounds).
-- OurLobby.Build calls this after FlightLine. Safe to re-run on a baked lobby: it replaces its own parts.
--   local m = game.ServerScriptService.Server.Map.Commons
--   local c = m:Clone(); c.Parent = m.Parent; require(c).Build(workspace.OurMap.Lobby); c:Destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Sounds = require(Shared.Config.Sounds)

local Commons = {}

local GROUND_Y = 1
local HALF = 60 -- matches the courtyard
local NEAR, FAR = 61, 156 -- area z range relative to the lobby centre (south = +Z)
local RUINS_SHIFT = 84 -- the south ruins (z = 76) move back to the new edge
local FIRE = Vector2.new(0, 100)

local C = {
	Asphalt = Color3.fromRGB(48, 48, 52),
	Concrete = Color3.fromRGB(128, 124, 116),
	ConcreteDark = Color3.fromRGB(86, 84, 80),
	Stone = Color3.fromRGB(104, 100, 94),
	Wood = Color3.fromRGB(110, 82, 52),
	Log = Color3.fromRGB(84, 60, 40),
	Canvas = Color3.fromRGB(92, 98, 66),
	CanvasDark = Color3.fromRGB(70, 74, 52),
	Metal = Color3.fromRGB(70, 72, 76),
	Rust = Color3.fromRGB(110, 58, 36),
	Crate = Color3.fromRGB(78, 88, 54),
	Sandbag = Color3.fromRGB(170, 150, 110),
	Couch = { Color3.fromRGB(96, 70, 58), Color3.fromRGB(62, 74, 84) },
	Bulb = Color3.fromRGB(255, 214, 140),
	Fire = Color3.fromRGB(255, 150, 60),
	Line = Color3.fromRGB(196, 164, 60),
	Stripe = Color3.fromRGB(200, 60, 40),
	White = Color3.fromRGB(220, 220, 215),
	Screen = Color3.fromRGB(110, 230, 120),
}

local origin

local function at(x, y, z)
	return CFrame.new(origin.X + x, y, origin.Z + z)
end

local function rel(position)
	return position - origin
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

-- vertical-axis cylinder (Roblox cylinders run along X)
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

local DECOR = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }

-- A looped 3D sound from Shared/Config/Sounds, started on clients by LobbyAudioController
local function ambient(p, key)
	local def = Sounds.Library[key]
	local s = Instance.new("Sound")
	s.Name = "LobbyAmbient"
	s.SoundId = "rbxassetid://" .. def.Id
	s.Volume = def.Volume
	s.Looped = true
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 4
	s.RollOffMaxDistance = def.MaxDistance or 30
	s.Parent = p
	return s
end

-- Fire on an upright attachment at the top of p (plus light and crackle)
local function fire(p, top, size, range)
	local spot = Instance.new("Attachment")
	spot.Name = "FireSpot"
	spot.Parent = p
	spot.WorldCFrame = CFrame.new(top)
	local f = Instance.new("Fire")
	f.Size = size
	f.Heat = 9
	f.Parent = spot
	local light = Instance.new("PointLight")
	light.Color = C.Fire
	light.Range = range
	light.Brightness = 2
	light.Shadows = true
	light.Parent = p
	ambient(p, "FireCrackle")
end

local function signText(p, face, text)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(150, 255, 90) -- the lobby's green sign paint
	label.Parent = gui
end

-- Opening the south --------------------------------------------------------------------------------

local function openSouth(lobby)
	-- the blocked old gate: the angled barriers and sandbags in the middle of the barricade
	local barricade = lobby:FindFirstChild("Barricade")
	if barricade then
		for _, d in barricade:GetDescendants() do
			if d:IsA("BasePart") then
				local p = rel(d.Position)
				-- the fence's one long Mesh and Wire: cut a gap in the middle (the halves are marked Cut)
				if d.Size.X > 40 and math.abs(p.X) < 1 and not d:GetAttribute("Cut") then
					local gap = 7
					for _, s in { -1, 1 } do
						local piece = d:Clone()
						local length = (d.Size.X / 2) - gap
						piece.Size = Vector3.new(length, d.Size.Y, d.Size.Z)
						piece.CFrame = d.CFrame * CFrame.new(s * (gap + length / 2), 0, 0)
						piece:SetAttribute("Cut", true)
						piece.Parent = d.Parent
					end
					d:Destroy()
				elseif math.abs(p.X) < 12 and p.Z > 50 and (d.Name ~= "Post" or math.abs(p.X) < 7) then
					d:Destroy()
				end
			end
		end
	end
	for _, wall in lobby.Bounds:GetChildren() do
		if math.abs(rel(wall.Position).Z - 61) < 1 then
			wall:Destroy()
		end
	end
	-- the south ruins back to the new edge (once: they're marked)
	for _, ruin in lobby.Ruins:GetChildren() do
		local body = ruin:FindFirstChild("Body")
		if body and not ruin:GetAttribute("Moved") and math.abs(rel(body.Position).Z - 76) < 2 then
			ruin:PivotTo(ruin:GetPivot() + Vector3.new(0, 0, RUINS_SHIFT))
			ruin:SetAttribute("Moved", true)
		end
	end
	-- the courtyard's fire barrels get their crackle too
	for _, d in lobby:GetDescendants() do
		if d.Name == "FireBarrel" and d:IsA("BasePart") and not d:FindFirstChild("LobbyAmbient") then
			ambient(d, "FireCrackle")
		end
	end
end

-- Ground and edges ---------------------------------------------------------------------------------

local function buildGround(m)
	local size = Vector3.new(184, 26, FAR - NEAR + 34) -- as wide as the courtyard's Foundation, so the island keeps one outline
	local cframe = at(0, GROUND_Y - 13.05, (NEAR + FAR) / 2 + 12)
	part(m, "Foundation", size, cframe, C.ConcreteDark, Enum.Material.Slate)
	workspace.Terrain:FillBlock(cframe, size, Enum.Material.Air)
	part(m, "Asphalt", Vector3.new(HALF * 2 + 4, 2, FAR - NEAR + 3), at(0, GROUND_Y - 1, (NEAR + FAR) / 2), C.Asphalt, Enum.Material.Asphalt)
	-- packed dirt around the campfire
	cylinder(m, "Dirt", 0.1, 30, at(FIRE.X, GROUND_Y + 0.05, FIRE.Y), Color3.fromRGB(92, 74, 56), Enum.Material.Ground, DECOR)
end

local function buildEdges(m, lobby)
	local edges = model(m, "Edges")
	-- containers along both sides, copies of the courtyard's (same colours and ribs)
	local sources = {}
	for _, c in lobby.Containers:GetChildren() do
		if c:IsA("Model") and c:GetBoundingBox().Y - origin.Y < GROUND_Y + 8 then -- ground row only
			table.insert(sources, c)
		end
	end
	local i = 0
	for _, side in { -1, 1 } do
		for _, z in { 72, 93, 114, 135 } do
			i += 1
			local copy = sources[i % #sources + 1]:Clone()
			local cf = copy:GetBoundingBox()
			copy:PivotTo(copy:GetPivot() + (Vector3.new(origin.X + side * (HALF - 3), cf.Y, origin.Z + z) - cf.Position))
			copy.Parent = edges
		end
	end
	-- jersey barriers and a chain-link fence along the south edge, in front of the ruins
	for x = -HALF + 6, HALF - 6, 8.5 do
		local cframe = at(x, GROUND_Y + 1.6, FAR - 4)
		part(edges, "JerseyBarrier", Vector3.new(8, 3.2, 2), cframe, C.Concrete, Enum.Material.Concrete)
		part(edges, "BarrierStripe", Vector3.new(8.05, 0.5, 2.05), cframe * CFrame.new(0, 1, 0), C.Stripe, Enum.Material.SmoothPlastic)
	end
	for x = -HALF, HALF, 8 do
		part(edges, "Post", Vector3.new(0.4, 10, 0.4), at(x, GROUND_Y + 5, FAR - 2), C.Metal, Enum.Material.Metal)
	end
	part(edges, "Mesh", Vector3.new(HALF * 2, 9, 0.1), at(0, GROUND_Y + 4.5, FAR - 2), C.Metal, Enum.Material.DiamondPlate, { Transparency = 0.65 })
	part(edges, "Wire", Vector3.new(HALF * 2, 0.15, 0.15), at(0, GROUND_Y + 9.8, FAR - 2), C.Metal, Enum.Material.Metal)
	-- invisible walls: the sides continue the courtyard's, plus a new south end
	local props = { Transparency = 1, CanQuery = false }
	for _, s in { -1, 1 } do
		part(edges, "InvisibleWall", Vector3.new(2, 80, FAR - NEAR + 2), at(s * (HALF + 1), GROUND_Y + 40, (NEAR + FAR) / 2), C.White, Enum.Material.SmoothPlastic, props)
	end
	part(edges, "InvisibleWall", Vector3.new(HALF * 2 + 4, 80, 2), at(0, GROUND_Y + 40, FAR), C.White, Enum.Material.SmoothPlastic, props)
end

-- Hangout pieces -----------------------------------------------------------------------------------

-- An invisible Seat players can sit on; they face the cframe's front (-Z)
local function seat(parent, cframe)
	local s = Instance.new("Seat")
	s.Name = "Seat"
	s.Anchored = true
	s.Size = Vector3.new(2, 0.4, 2)
	s.CFrame = cframe
	s.Transparency = 1
	s.CanCollide = false
	s.Parent = parent
	return s
end

local function couch(parent, cframe, color)
	local m = model(parent, "Couch")
	part(m, "Base", Vector3.new(7, 1.4, 3), cframe * CFrame.new(0, 0.9, 0), color, Enum.Material.Fabric)
	part(m, "Back", Vector3.new(7, 2.4, 0.9), cframe * CFrame.new(0, 2.2, 1.1) * CFrame.Angles(math.rad(-8), 0, 0), color, Enum.Material.Fabric)
	for _, s in { -1, 1 } do
		part(m, "Arm", Vector3.new(0.9, 1.2, 3), cframe * CFrame.new(s * 3.5, 2, 0), color:Lerp(Color3.new(), 0.15), Enum.Material.Fabric)
		part(m, "Cushion", Vector3.new(3.2, 0.5, 2.6), cframe * CFrame.new(s * 1.65, 1.85, -0.1) * CFrame.Angles(0, 0, math.rad(s * 2)), color:Lerp(Color3.new(1, 1, 1), 0.08), Enum.Material.Fabric)
		seat(m, cframe * CFrame.new(s * 1.65, 2.1, -0.1))
	end
	return m
end

local function logBench(parent, cframe)
	local log = part(parent, "LogBench", Vector3.new(8, 1.6, 1.6), cframe * CFrame.new(0, 0.8, 0), C.Log, Enum.Material.Wood)
	log.Shape = Enum.PartType.Cylinder
	for _, x in { -2, 2 } do
		seat(parent, cframe * CFrame.new(x, 1.6, 0))
	end
	return log
end

local function crate(parent, cframe, size)
	part(parent, "Crate", Vector3.new(size, size, size), cframe * CFrame.new(0, size / 2, 0), C.Crate, Enum.Material.WoodPlanks)
end

local function buildCampfire(m)
	local f = model(m, "Campfire")
	local c = at(FIRE.X, GROUND_Y, FIRE.Y)
	for i = 0, 9 do
		local a = i * math.pi / 5
		part(f, "Stone", Vector3.new(1.4, 0.9, 1.1), c * CFrame.Angles(0, -a, 0) * CFrame.new(3, 0.4, 0) * CFrame.Angles(0.1 * (i % 3), 0, 0.15), C.Stone, Enum.Material.Slate)
	end
	for i = 0, 2 do
		part(f, "Firewood", Vector3.new(4, 0.6, 0.6), c * CFrame.Angles(0, i * math.pi / 3, 0) * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.rad(12)), C.Log, Enum.Material.Wood)
	end
	local embers = part(f, "Embers", Vector3.new(2.6, 0.2, 2.6), c * CFrame.new(0, 0.15, 0), C.Fire, Enum.Material.Neon, DECOR)
	fire(embers, c.Position + Vector3.new(0, 0.6, 0), 7, 32)
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(70, 66, 62)
	smoke.Size = 6
	smoke.Opacity = 0.12
	smoke.RiseVelocity = 4
	smoke.Parent = embers
	-- seats around it, all facing the fire
	local seats = {
		{ a = 0, kind = "Couch", color = C.Couch[1] },
		{ a = 72, kind = "Log" },
		{ a = 144, kind = "Couch", color = C.Couch[2] },
		{ a = 216, kind = "Log" },
		{ a = 288, kind = "Log" },
	}
	for _, s in seats do
		local a = math.rad(s.a + 90)
		local pos = c.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * 10
		local cf = CFrame.lookAt(pos, Vector3.new(c.X, pos.Y, c.Z)) -- front (-Z) to the fire, back to the outside
		if s.kind == "Couch" then
			couch(f, cf, s.color)
		else
			logBench(f, cf)
		end
	end
	for _, a in { 54, 126 } do -- side-table crates in two gaps between the seats
		crate(f, c * CFrame.new(math.cos(math.rad(a)) * 10, 0, math.sin(math.rad(a)) * 10) * CFrame.Angles(0, math.rad(a), 0), 2.2)
	end
end

-- Poles at the corners of the campfire square with sagging strings of warm bulbs between them
local function buildStringLights(m)
	local lights = model(m, "StringLights")
	local h = 11
	local corners = { Vector2.new(-17, 84), Vector2.new(17, 84), Vector2.new(17, 116), Vector2.new(-17, 116) }
	local tops = {}
	for i, p in corners do
		part(lights, "Pole", Vector3.new(0.6, h, 0.6), at(p.X, GROUND_Y + h / 2, p.Y), C.Wood, Enum.Material.Wood)
		tops[i] = Vector3.new(origin.X + p.X, GROUND_Y + h - 0.4, origin.Z + p.Y)
	end
	local runs = { { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 1 }, { 1, 3 }, { 2, 4 } }
	for _, r in runs do
		local a, b = tops[r[1]], tops[r[2]]
		local length = (b - a).Magnitude
		local n = math.floor(length / 3)
		local prev
		for k = 0, n do
			local t = k / n
			local p = a:Lerp(b, t) - Vector3.new(0, 2.2 * 4 * t * (1 - t), 0) -- sag
			if prev then
				part(lights, "Cord", Vector3.new(0.08, 0.08, (p - prev).Magnitude), CFrame.lookAt((p + prev) / 2, p), Color3.fromRGB(30, 30, 30), Enum.Material.SmoothPlastic, DECOR)
			end
			if k > 0 and k < n then
				local bulb = part(lights, "Bulb", Vector3.new(0.35, 0.45, 0.35), CFrame.new(p - Vector3.new(0, 0.3, 0)), C.Bulb, Enum.Material.Neon, DECOR)
				if k % 3 == 0 then
					local glow = Instance.new("PointLight")
					glow.Color = C.Bulb
					glow.Range = 9
					glow.Brightness = 0.8
					glow.Parent = bulb
				end
			end
			prev = p
		end
	end
end

local function buildMessTent(m)
	local t = model(m, "MessTent")
	local cx, cz, w, d, h = -36, 98, 16, 22, 9
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(t, "Pole", Vector3.new(0.5, h, 0.5), at(cx + sx * w / 2, GROUND_Y + h / 2, cz + sz * d / 2), C.Wood, Enum.Material.Wood)
		end
	end
	-- pitched canvas roof, ridge along z
	for _, sx in { -1, 1 } do
		part(t, "Roof", Vector3.new(w / 2 + 1.6, 0.2, d + 2), at(cx + sx * w / 4, GROUND_Y + h + 1.4, cz) * CFrame.Angles(0, 0, math.rad(-sx * 18)), C.Canvas, Enum.Material.Fabric)
	end
	local sign = part(t, "Sign", Vector3.new(0.3, 2, 9), at(cx + w / 2 + 0.3, GROUND_Y + h - 1.4, cz), Color3.fromRGB(32, 30, 30), Enum.Material.Metal)
	signText(sign, Enum.NormalId.Right, "MESS")
	-- two long tables with benches
	for _, tx in { -3.5, 3.5 } do
		part(t, "Table", Vector3.new(3, 0.3, 14), at(cx + tx, GROUND_Y + 2.6, cz), C.Wood, Enum.Material.WoodPlanks)
		for _, lz in { -6, 6 } do
			part(t, "Leg", Vector3.new(2.4, 2.4, 0.3), at(cx + tx, GROUND_Y + 1.2, cz + lz), C.Wood, Enum.Material.Wood)
		end
		for _, bx in { -2.2, 2.2 } do
			part(t, "Bench", Vector3.new(1, 0.25, 13), at(cx + tx + bx, GROUND_Y + 1.5, cz), C.Wood, Enum.Material.WoodPlanks)
			for _, sz in { -4, 0, 4 } do -- facing the table
				local p = at(cx + tx + bx, GROUND_Y + 1.6, cz + sz).Position
				seat(t, CFrame.lookAt(p, p - Vector3.new(bx, 0, 0)))
			end
			part(t, "BenchLeg", Vector3.new(0.8, 1.4, 0.25), at(cx + tx + bx, GROUND_Y + 0.7, cz - 5.5), C.Wood, Enum.Material.Wood)
			part(t, "BenchLeg", Vector3.new(0.8, 1.4, 0.25), at(cx + tx + bx, GROUND_Y + 0.7, cz + 5.5), C.Wood, Enum.Material.Wood)
		end
		for k = -2, 2 do -- tins and mugs on the table
			cylinder(t, "Tin", 0.5, 0.45, at(cx + tx + (k % 2) * 0.6 - 0.3, GROUND_Y + 3, cz + k * 2.6), Color3.fromRGB(150, 150, 140), Enum.Material.Metal, DECOR)
		end
	end
	-- cooking barrel at the back with a pot on a grate
	local stove = cylinder(t, "StoveBarrel", 3.4, 2.4, at(cx - 5, GROUND_Y + 1.7, cz - d / 2 + 2), C.Rust, Enum.Material.Metal)
	fire(stove, stove.Position + Vector3.new(0, 1.8, 0), 3, 16)
	part(t, "Grate", Vector3.new(2.6, 0.15, 2.6), at(cx - 5, GROUND_Y + 3.5, cz - d / 2 + 2), C.Metal, Enum.Material.DiamondPlate)
	cylinder(t, "Pot", 1.2, 1.6, at(cx - 5, GROUND_Y + 4.2, cz - d / 2 + 2), Color3.fromRGB(56, 56, 60), Enum.Material.Metal)
	for k = 0, 3 do
		crate(t, at(cx + 5.5, GROUND_Y + (k >= 2 and 2 or 0), cz - d / 2 + 1.5 + (k % 2) * 2.2) * CFrame.Angles(0, 0.1 * k, 0), 2)
	end
end

local function buildBunks(m)
	local b = model(m, "Bunks")
	for i, z in { 82, 98, 114 } do
		local cx = 40
		local cf = at(cx, GROUND_Y, z)
		-- A-frame tent, open at both ends (a flat back panel stuck out past the slopes)
		for _, s in { -1, 1 } do
			part(b, "TentSide", Vector3.new(9, 0.2, 5.2), cf * CFrame.new(0, 2, s * 1.9) * CFrame.Angles(math.rad(s * 52), 0, 0), if i == 2 then C.CanvasDark else C.Canvas, Enum.Material.Fabric)
		end
		part(b, "Bedroll", Vector3.new(6, 0.4, 1.8), cf * CFrame.new(0.5, 0.2, 0), Color3.fromRGB(80, 60, 50), Enum.Material.Fabric)
		-- a cot beside each tent
		part(b, "Cot", Vector3.new(6, 0.3, 2.2), cf * CFrame.new(1, 1.4, 5.5), C.CanvasDark, Enum.Material.Fabric)
		for _, lx in { -2.6, 3.6 } do
			part(b, "CotLeg", Vector3.new(0.2, 1.3, 2), cf * CFrame.new(lx, 0.65, 5.5), C.Metal, Enum.Material.Metal)
		end
	end
	local lantern = part(b, "Lantern", Vector3.new(0.6, 0.9, 0.6), at(35, GROUND_Y + 0.45, 106), C.Bulb, Enum.Material.Neon)
	local glow = Instance.new("PointLight")
	glow.Color = C.Bulb
	glow.Range = 12
	glow.Parent = lantern
end

local function buildRadioShack(m)
	local r = model(m, "RadioShack")
	local cx, cz = 40, 138
	-- sandbag walls on three sides, open to the north
	local function bags(fromX, fromZ, toX, toZ)
		local from, to = Vector3.new(fromX, 0, fromZ), Vector3.new(toX, 0, toZ)
		local dir = to - from
		local count = math.floor(dir.Magnitude / 2.4)
		for row = 0, 2 do
			for k = 0, count - 1 do
				local p = from + dir * ((k + 0.5 + (row % 2) * 0.5) / count)
				if (p - from).Magnitude <= dir.Magnitude then
					part(r, "Sandbag", Vector3.new(1.6, 1.1, 2.6), at(p.X, GROUND_Y + 0.55 + row * 1.05, p.Z) * CFrame.lookAt(Vector3.zero, dir.Unit), C.Sandbag, Enum.Material.Fabric)
				end
			end
		end
	end
	bags(cx - 8, cz + 6, cx + 8, cz + 6)
	bags(cx - 8, cz - 4, cx - 8, cz + 6)
	bags(cx + 8, cz - 4, cx + 8, cz + 6)
	-- corrugated roof on posts
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(r, "Post", Vector3.new(0.4, 8, 0.4), at(cx + sx * 7.5, GROUND_Y + 4, cz + 1 + sz * 4.5), C.Metal, Enum.Material.Metal)
		end
	end
	part(r, "Roof", Vector3.new(17, 0.3, 11), at(cx, GROUND_Y + 8.2, cz + 1) * CFrame.Angles(math.rad(6), 0, 0), C.Rust, Enum.Material.CorrodedMetal)
	-- desk with the radio set, facing north
	part(r, "Desk", Vector3.new(7, 0.3, 2.6), at(cx, GROUND_Y + 2.7, cz + 4), C.Wood, Enum.Material.WoodPlanks)
	for _, lx in { -3.2, 3.2 } do
		part(r, "DeskLeg", Vector3.new(0.3, 2.6, 2.4), at(cx + lx, GROUND_Y + 1.3, cz + 4), C.Wood, Enum.Material.Wood)
	end
	local radio = part(r, "Radio", Vector3.new(3, 1.6, 1.2), at(cx - 1, GROUND_Y + 3.65, cz + 4.4), Color3.fromRGB(64, 70, 54), Enum.Material.Metal)
	part(r, "Dial", Vector3.new(1.2, 0.5, 0.05), radio.CFrame * CFrame.new(-0.6, 0.3, -0.62), C.Screen, Enum.Material.Neon, DECOR)
	for k = 0, 2 do
		cylinder(r, "Knob", 0.15, 0.3, radio.CFrame * CFrame.new(0.4 + k * 0.4, -0.35, -0.65) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(30, 30, 30), Enum.Material.SmoothPlastic, DECOR)
	end
	part(r, "Handset", Vector3.new(0.4, 0.3, 1.4), at(cx + 1.4, GROUND_Y + 3, cz + 3.8) * CFrame.Angles(0, 0.4, 0), Color3.fromRGB(30, 30, 30), Enum.Material.SmoothPlastic)
	ambient(radio, "RadioChatter")
	-- "Listen in": Overwatch plays a lore broadcast on your radio panel (Server/Services/CommonsService)
	local listen = Instance.new("ProximityPrompt")
	listen.ActionText = "Listen in"
	listen.ObjectText = "RADIO"
	listen.MaxActivationDistance = 9
	listen.RequiresLineOfSight = false
	listen:SetAttribute("Commons", "Radio")
	listen.Parent = radio
	local light = Instance.new("PointLight")
	light.Color = C.Screen
	light.Range = 6
	light.Brightness = 0.6
	light.Parent = radio
	part(r, "Chair", Vector3.new(1.8, 0.3, 1.8), at(cx - 1, GROUND_Y + 1.8, cz + 1.6), C.Metal, Enum.Material.Metal)
	part(r, "ChairBack", Vector3.new(1.8, 1.8, 0.2), at(cx - 1, GROUND_Y + 2.8, cz + 0.8), C.Metal, Enum.Material.Metal)
	-- map board and the antenna mast with a red light on top
	local board = part(r, "MapBoard", Vector3.new(4, 3, 0.2), at(cx + 5.5, GROUND_Y + 4.5, cz + 5.2), Color3.fromRGB(200, 190, 160), Enum.Material.SmoothPlastic)
	board.CFrame = board.CFrame * CFrame.Angles(0, math.rad(-20), 0)
	part(r, "Mast", Vector3.new(0.3, 18, 0.3), at(cx + 6, GROUND_Y + 9, cz + 7), C.Metal, Enum.Material.Metal)
	part(r, "MastLight", Vector3.new(0.6, 0.6, 0.6), at(cx + 6, GROUND_Y + 18.3, cz + 7), Color3.fromRGB(255, 50, 40), Enum.Material.Neon)
end

-- South-west corner: a hoop on a pole and a few crates to sit on
local function buildHangoutCorner(m)
	local h = model(m, "Hoop")
	local cx, cz = -40, 140
	part(h, "Pole", Vector3.new(0.5, 11, 0.5), at(cx, GROUND_Y + 5.5, cz + 4), C.Metal, Enum.Material.Metal)
	part(h, "Backboard", Vector3.new(6, 3.6, 0.3), at(cx, GROUND_Y + 11, cz + 3.6), Color3.fromRGB(200, 196, 186), Enum.Material.SmoothPlastic)
	for k = 0, 7 do
		local a = k * math.pi / 4
		part(h, "Rim", Vector3.new(0.12, 0.12, 0.9), at(cx + math.cos(a) * 1.1, GROUND_Y + 10, cz + 2.2 + math.sin(a) * 1.1) * CFrame.Angles(0, -a, 0), Color3.fromRGB(220, 90, 40), Enum.Material.Metal, DECOR)
	end
	-- the rim's centre and the ball's resting spot are attributes for CommonsService (the "Shoot" prompt)
	h:SetAttribute("RimCenter", Vector3.new(origin.X + cx, GROUND_Y + 10, origin.Z + cz + 2.2))
	local ball = part(h, "Ball", Vector3.new(1.4, 1.4, 1.4), at(cx + 3, GROUND_Y + 0.7, cz - 2), Color3.fromRGB(200, 100, 40), Enum.Material.SmoothPlastic)
	ball.Shape = Enum.PartType.Ball
	ball:SetAttribute("Home", ball.Position)
	local shoot = Instance.new("ProximityPrompt")
	shoot.ActionText = "Shoot"
	shoot.ObjectText = "BALL"
	shoot.MaxActivationDistance = 8
	shoot.RequiresLineOfSight = false
	shoot:SetAttribute("Commons", "Hoop")
	shoot.Parent = ball
	-- faded court lines
	part(h, "CourtLine", Vector3.new(14, 0.05, 0.4), at(cx, GROUND_Y + 0.03, cz - 6), C.White, Enum.Material.SmoothPlastic, { Transparency = 0.5, CanCollide = false })
	for k = 0, 2 do
		crate(h, at(cx + 8 + k * 2.6, GROUND_Y, cz - 10 + (k % 2) * 1.2) * CFrame.Angles(0, 0.2 * k, 0), 2.2)
	end
end

-- "TOP SURVIVORS": the all-time best waves of every player (CommonsService fills Row1..Row10 from an
-- OrderedDataStore). It stands east of the path in from the gate, facing west.
local function buildLeaderboard(m)
	local b = model(m, "TopSurvivors")
	local cx, cz = 20, 72
	for _, dz in { -5.5, 5.5 } do
		part(b, "Post", Vector3.new(0.6, 10, 0.6), at(cx + 0.4, GROUND_Y + 5, cz + dz), C.Wood, Enum.Material.Wood)
	end
	local board = part(b, "Board", Vector3.new(0.4, 7.5, 11), at(cx, GROUND_Y + 5.6, cz), Color3.fromRGB(34, 32, 30), Enum.Material.Wood)
	part(b, "Awning", Vector3.new(2.4, 0.2, 12.4), at(cx - 0.6, GROUND_Y + 9.7, cz) * CFrame.Angles(0, 0, math.rad(-12)), C.Rust, Enum.Material.CorrodedMetal)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Rows"
	gui.Face = Enum.NormalId.Left -- -X: towards the path
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui
	local function row(name, order, text, color, height)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.LayoutOrder = order
		label.Size = UDim2.new(1, 0, height, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = text
		label.Parent = gui
	end
	row("Header", 0, "TOP SURVIVORS · BEST WAVE", Color3.fromRGB(150, 255, 90), 0.12)
	for i = 1, 10 do
		row("Row" .. i, i, "", if i <= 3 then Color3.fromRGB(255, 214, 120) else C.White, 0.088)
	end
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Left
	light.Range = 12
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 230, 190)
	light.Parent = board
end

-- The Commendations board used to stand right in front of the south gate. It moves into the Commons,
-- west of the path in, turned to face east (once: it's marked Moved).
local function moveCommendations(lobby)
	local board = lobby:FindFirstChild("Commendations")
	if not board or board:GetAttribute("Moved") then
		return
	end
	local pivot = board:GetPivot()
	local cf = board:GetBoundingBox()
	local offset = pivot.Position - cf.Position
	local target = Vector3.new(origin.X - 20, cf.Y, origin.Z + 72)
	-- it faced north (-Z); a -90 degree turn makes it face east (+X)
	local turn = CFrame.Angles(0, math.rad(-90), 0)
	board:PivotTo(CFrame.new(target) * turn * CFrame.new(offset) * pivot.Rotation)
	board:SetAttribute("Moved", true)
end

function Commons.Build(lobby)
	origin = GameConfig.OurMap.LobbyCenter
	local old = lobby:FindFirstChild("Commons")
	if old then
		old:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = "Commons"
	openSouth(lobby)
	buildGround(m)
	buildEdges(m, lobby)
	buildCampfire(m)
	buildStringLights(m)
	buildMessTent(m)
	buildBunks(m)
	buildRadioShack(m)
	buildHangoutCorner(m)
	buildLeaderboard(m)
	moveCommendations(lobby)
	m.Parent = lobby
	return m
end

return Commons
