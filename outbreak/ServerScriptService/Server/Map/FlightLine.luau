-- FlightLine: the lobby's take-off deck (vault: Lobby.md). It sits north of the safehouse courtyard,
-- through a gate where the middle north ruin stood: four helipads in a 2 x 2 grid, one squad each
-- (Server/Services/QueueService). Pads are copies of the courtyard's original Helipad model, so the
-- look (deploy glow, edge lights, sign) stays the same; each pad model has attribute PadId = 1..4.
-- In the middle, a caged red Nightmare pad (PadId 5) behind a chained gate (buildNightmare).
-- OurLobby.Build calls this last. Safe to re-run on a baked lobby: it replaces its own parts.
--   local m = game.ServerScriptService.Server.Map.FlightLine
--   local c = m:Clone(); c.Parent = m.Parent; require(c).Build(workspace.OurMap.Lobby); c:Destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local FlightLine = {}

local GROUND_Y = 1
local HALF = 60 -- deck half-width; its invisible walls line up with the courtyard's (x = +-61)
local NEAR, FAR = -62, -190 -- deck z range relative to the lobby centre (north = -Z)
local PADS = { Vector2.new(-32, -106), Vector2.new(32, -106), Vector2.new(-32, -158), Vector2.new(32, -158) }
local CENTRE = Vector2.new(0, -132)

local C = {
	Asphalt = Color3.fromRGB(48, 48, 52),
	Concrete = Color3.fromRGB(128, 124, 116),
	ConcreteDark = Color3.fromRGB(86, 84, 80),
	Line = Color3.fromRGB(196, 164, 60),
	Metal = Color3.fromRGB(70, 72, 76),
	Stripe = Color3.fromRGB(200, 60, 40),
	White = Color3.fromRGB(220, 220, 215),
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

local function signText(p, face, text)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = C.Line
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(25, 25, 25)
	label.Parent = gui
end

-- Opens the gate: the middle north ruin, the courtyard's north invisible wall and any debris in the way.
local function openGate(lobby)
	for _, ruin in lobby.Ruins:GetChildren() do
		local body = ruin:FindFirstChild("Body")
		local p = body and rel(body.Position)
		if p and math.abs(p.X) < 2 and math.abs(p.Z + 67) < 2 then
			ruin:Destroy()
		end
	end
	for _, wall in lobby.Bounds:GetChildren() do
		if math.abs(rel(wall.Position).Z + 61) < 1 then
			wall:Destroy()
		end
	end
	for _, d in lobby.Debris:GetDescendants() do
		if d:IsA("BasePart") then
			local p = rel(d.Position)
			if math.abs(p.X) < 26 and p.Z < -44 then
				d:Destroy()
			end
		end
	end
end

local function buildGround(m)
	local size = Vector3.new(HALF * 2 + 12, 26, NEAR - FAR + 4)
	local cframe = at(0, GROUND_Y - 13.05, (NEAR + FAR) / 2)
	-- reaches below the seabed like the courtyard's Foundation, so no ocean shows through
	part(m, "Foundation", size, cframe, C.ConcreteDark, Enum.Material.Slate)
	workspace.Terrain:FillBlock(cframe, size, Enum.Material.Air)
	part(m, "Asphalt", Vector3.new(HALF * 2 + 4, 2, NEAR - FAR), at(0, GROUND_Y - 1, (NEAR + FAR) / 2), C.Asphalt, Enum.Material.Asphalt)
	local paint = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Transparency = 0.25 }
	-- taxi line from the gate up the middle, with a branch to each pad
	for z = NEAR - 4, PADS[3].Y, -8 do
		part(m, "TaxiLine", Vector3.new(0.6, 0.05, 5), at(0, GROUND_Y + 0.03, z), C.Line, Enum.Material.SmoothPlastic, paint)
	end
	for _, pad in PADS do
		for x = 4, math.abs(pad.X) - 16, 6 do
			part(m, "TaxiLine", Vector3.new(4, 0.05, 0.6), at(math.sign(pad.X) * x, GROUND_Y + 0.03, pad.Y), C.Line, Enum.Material.SmoothPlastic, paint)
		end
	end
end

-- Jersey barriers and a chain-link fence along the three open edges (same look as the south barricade)
local function buildEdges(m)
	local edges = Instance.new("Model")
	edges.Name = "Edges"
	edges.Parent = m
	local function barrier(x, z, alongX)
		local cframe = at(x, GROUND_Y + 1.6, z) * CFrame.Angles(0, if alongX then 0 else math.rad(90), 0)
		part(edges, "JerseyBarrier", Vector3.new(8, 3.2, 2), cframe, C.Concrete, Enum.Material.Concrete)
		part(edges, "BarrierStripe", Vector3.new(8.05, 0.5, 2.05), cframe * CFrame.new(0, 1, 0), C.Stripe, Enum.Material.SmoothPlastic)
	end
	local function fence(from, to)
		local mid, length = (from + to) / 2, (to - from).Magnitude
		local look = CFrame.lookAt(Vector3.zero, Vector3.new(to.X - from.X, 0, to.Y - from.Y))
		for i = 0, math.floor(length / 8) do
			local p = from + (to - from) * (i * 8 / length)
			part(edges, "Post", Vector3.new(0.4, 10, 0.4), at(p.X, GROUND_Y + 5, p.Y), C.Metal, Enum.Material.Metal)
		end
		part(edges, "Mesh", Vector3.new(0.1, 9, length), at(mid.X, GROUND_Y + 4.5, mid.Y) * look, C.Metal, Enum.Material.DiamondPlate, { Transparency = 0.65 })
		part(edges, "Wire", Vector3.new(0.15, 0.15, length), at(mid.X, GROUND_Y + 9.8, mid.Y) * look, C.Metal, Enum.Material.Metal)
	end
	for _, s in { -1, 1 } do
		for z = NEAR - 16, FAR + 8, -8.5 do
			barrier(s * (HALF - 2), z, false)
		end
		fence(Vector2.new(s * HALF, NEAR - 12), Vector2.new(s * HALF, FAR + 1))
	end
	for x = -HALF + 6, HALF - 6, 8.5 do
		barrier(x, FAR + 3, true)
	end
	fence(Vector2.new(-HALF, FAR + 1), Vector2.new(HALF, FAR + 1))
	-- invisible walls: the deck's sides continue the courtyard's, plus a new north end
	local props = { Transparency = 1, CanQuery = false }
	for _, s in { -1, 1 } do
		part(edges, "InvisibleWall", Vector3.new(2, 80, NEAR - FAR + 2), at(s * (HALF + 1), GROUND_Y + 40, (NEAR + FAR) / 2), C.White, Enum.Material.SmoothPlastic, props)
	end
	part(edges, "InvisibleWall", Vector3.new(HALF * 2 + 4, 80, 2), at(0, GROUND_Y + 40, FAR - 1), C.White, Enum.Material.SmoothPlastic, props)
end

local function buildGateSign(m)
	for _, x in { -14, 14 } do
		part(m, "GatePost", Vector3.new(0.8, 13, 0.8), at(x, GROUND_Y + 6.5, -66), C.Metal, Enum.Material.Metal)
	end
	local board = part(m, "GateSign", Vector3.new(24, 3.4, 0.4), at(0, GROUND_Y + 11.6, -66), C.Line, Enum.Material.Metal)
	signText(board, Enum.NormalId.Back, "FLIGHT LINE") -- read from the courtyard (south)
	signText(board, Enum.NormalId.Front, "SAFEHOUSE")
end

-- Same lamp as OurLobby's courtyard floodlights, aimed at the middle of the deck
local function buildFloodlight(m, x, z)
	local f = Instance.new("Model")
	f.Name = "Floodlight"
	f.Parent = m
	part(f, "Pole", Vector3.new(1, 22, 1), at(x, GROUND_Y + 11, z), C.Metal, Enum.Material.Metal)
	local headPos = Vector3.new(origin.X + x, GROUND_Y + 22, origin.Z + z)
	local head = part(f, "Head", Vector3.new(4, 2.4, 1.4), CFrame.lookAt(headPos, Vector3.new(origin.X + CENTRE.X, GROUND_Y, origin.Z + CENTRE.Y)), C.Metal, Enum.Material.Metal)
	part(f, "Lens", Vector3.new(3.6, 2, 0.1), head.CFrame * CFrame.new(0, 0, -0.72), Color3.fromRGB(255, 240, 200), Enum.Material.Neon)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Angle = 70
	light.Range = 80
	light.Brightness = 1.6
	light.Color = Color3.fromRGB(255, 240, 210)
	light.Parent = head
end

-- Pad 1 is the courtyard's original Helipad, moved; pads 2-4 are copies of it
local function placePads(lobby)
	local first
	for _, m in lobby:GetChildren() do
		if m.Name == "Helipad" then
			if (m:GetAttribute("PadId") or 1) == 1 then
				first = m
			else
				m:Destroy()
			end
		end
	end
	assert(first, "[FlightLine] the lobby has no Helipad to copy")
	for id, spot in PADS do
		local pad = if id == 1 then first else first:Clone()
		pad:SetAttribute("PadId", id)
		local offset = Vector3.new(origin.X + spot.X, 0, origin.Z + spot.Y) - pad.Pad.Position * Vector3.new(1, 0, 1)
		pad:PivotTo(pad:GetPivot() + offset)
		local label = pad.Sign:FindFirstChildWhichIsA("SurfaceGui"):FindFirstChildWhichIsA("TextLabel")
		label.Text = "PAD " .. id
		pad.Parent = lobby
	end
end

-- The Nightmare pad (Config/Nightmare): a smaller red copy of pad 1 (PadId 5, attribute Nightmare) in a
-- fenced cage between the four pads, entered through a chained gate on the south side. The gate stays
-- shut for everyone on the server; Client/Controllers/NightmareController opens it locally (no
-- collision, chains gone) for players who've unlocked the mode and writes the sign for each player.
local NIGHTMARE_SPOT, CAGE = Vector2.new(0, -132), 14 -- cage half-width; pads 1-4 start at x = +-17
local RED = Color3.fromRGB(200, 30, 30)

local function buildNightmare(m, lobby)
	local cage = Instance.new("Model")
	cage.Name = "Nightmare"
	cage.Parent = m
	local front, back = NIGHTMARE_SPOT.Y + CAGE, NIGHTMARE_SPOT.Y - CAGE
	local function fence(x1, z1, x2, z2)
		local from, to = Vector2.new(x1, z1), Vector2.new(x2, z2)
		local mid, length = (from + to) / 2, (to - from).Magnitude
		local look = CFrame.lookAt(Vector3.zero, Vector3.new(to.X - from.X, 0, to.Y - from.Y))
		part(cage, "Mesh", Vector3.new(0.2, 10, length), at(mid.X, GROUND_Y + 5, mid.Y) * look, Color3.fromRGB(40, 30, 30), Enum.Material.DiamondPlate, { Transparency = 0.45 })
		part(cage, "Wire", Vector3.new(0.3, 0.3, length), at(mid.X, GROUND_Y + 10.2, mid.Y) * look, C.Metal, Enum.Material.Metal)
	end
	fence(-CAGE, back, CAGE, back)
	fence(-CAGE, front, -CAGE, back)
	fence(CAGE, front, CAGE, back)
	fence(-CAGE, front, -5, front)
	fence(5, front, CAGE, front)
	-- corner and gate posts with red warning lamps
	for _, p in { Vector2.new(-CAGE, front), Vector2.new(CAGE, front), Vector2.new(-CAGE, back), Vector2.new(CAGE, back), Vector2.new(-5, front), Vector2.new(5, front) } do
		part(cage, "Post", Vector3.new(0.8, 11, 0.8), at(p.X, GROUND_Y + 5.5, p.Y), C.Metal, Enum.Material.Metal)
		local lamp = part(cage, "Lamp", Vector3.new(1, 0.6, 1), at(p.X, GROUND_Y + 11.3, p.Y), RED, Enum.Material.Neon, { CanCollide = false })
		local light = Instance.new("PointLight")
		light.Color = RED
		light.Range = 14
		light.Brightness = 1.2
		light.Parent = lamp
	end
	-- the gate: two panels, chains crossed over them and a padlock
	local gate = Instance.new("Model")
	gate.Name = "Gate"
	gate.Parent = cage
	for _, x in { -2.5, 2.5 } do
		part(gate, "Panel", Vector3.new(4.9, 9.5, 0.3), at(x, GROUND_Y + 4.85, front), Color3.fromRGB(70, 20, 20), Enum.Material.DiamondPlate, { Transparency = 0.2 })
	end
	local chain = { CanCollide = false }
	for _, tilt in { 32, -32 } do
		part(gate, "Chain", Vector3.new(11, 0.35, 0.35), at(0, GROUND_Y + 5, front + 0.35) * CFrame.Angles(0, 0, math.rad(tilt)), Color3.fromRGB(110, 105, 100), Enum.Material.Metal, chain)
	end
	part(gate, "Padlock", Vector3.new(1.2, 1.4, 0.5), at(0, GROUND_Y + 5, front + 0.7), Color3.fromRGB(190, 150, 60), Enum.Material.Metal, chain)
	-- sign over the gate (text per player: NightmareController)
	local board = part(cage, "Sign", Vector3.new(14, 2.6, 0.4), at(0, GROUND_Y + 12.4, front), Color3.fromRGB(30, 10, 10), Enum.Material.Metal)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- read from the gate side (south)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(30, 10, 10)
	label.Text = "NIGHTMARE"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(235, 60, 50)
	label.Parent = gui

	-- the pad: pad 1 shrunk and turned red, its own signpost dropped (the gate sign replaces it)
	local first
	for _, child in lobby:GetChildren() do
		if child.Name == "Helipad" and child:GetAttribute("PadId") == 1 then
			first = child
		end
	end
	local pad = first:Clone()
	pad:SetAttribute("PadId", 5)
	pad:SetAttribute("Nightmare", true)
	pad:ScaleTo(0.7)
	local offset = Vector3.new(origin.X + NIGHTMARE_SPOT.X, 0, origin.Z + NIGHTMARE_SPOT.Y) - pad.Pad.Position * Vector3.new(1, 0, 1)
	pad:PivotTo(pad:GetPivot() + offset)
	pad:PivotTo(pad:GetPivot() + Vector3.new(0, first.Pad.Position.Y - pad.Pad.Position.Y, 0)) -- scaling lifts it off the deck
	for _, d in pad:GetDescendants() do
		if d.Name == "Sign" or d.Name == "SignPost" then
			d:Destroy()
		elseif d:IsA("BasePart") and (d.Name == "Ring" or d.Name == "Base") then
			d.Color = RED
		elseif d:IsA("BasePart") and (d.Name == "Pad" or d.Name == "Inner") then
			d.Color = Color3.fromRGB(44, 32, 32)
		elseif d:IsA("Beam") then
			d.Color = ColorSequence.new(RED)
		end
	end
	pad.Parent = lobby
end

function FlightLine.Build(lobby)
	origin = GameConfig.OurMap.LobbyCenter
	local old = lobby:FindFirstChild("FlightLine")
	if old then
		old:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = "FlightLine"
	openGate(lobby)
	buildGround(m)
	buildEdges(m)
	buildGateSign(m)
	for _, corner in { Vector2.new(-HALF + 4, NEAR - 18), Vector2.new(HALF - 4, NEAR - 18), Vector2.new(-HALF + 4, FAR + 8), Vector2.new(HALF - 4, FAR + 8) } do
		buildFloodlight(m, corner.X, corner.Y)
	end
	m.Parent = lobby
	placePads(lobby)
	buildNightmare(m, lobby)
	return m
end

return FlightLine
