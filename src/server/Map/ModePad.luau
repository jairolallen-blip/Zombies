-- ModePad: the OUTBREAK pad (the million-zombie mode's take-off spot) on the Flight Line deck.
-- Style: a ~0.5-scale copy of OurLobby.buildHelipad's construction (Pad/Ring/Inner cylinders, H bars,
-- 8 red EdgeLights, a DeployGlow-style beam wall, a sign post). Amber instead of yellow so it reads
-- as a different mode; Nightmare is the red pad. Attributes PadId 6 + ModeId "Outbreak":
-- MapService auto-discovers any Helipad model with a PadId, so QueueService can wire the mode later.
-- Called from OurLobby.Build AFTER FlightLine.Build (placePads destroys lobby Helipad models with
-- PadId ~= 1). Visual only: no queue/mode logic here yet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local ModePad = {}

-- palette copied from OurLobby.C, plus the mode accent
local CONCRETE_DARK = Color3.fromRGB(86, 84, 80)
local CONCRETE_MODE = Color3.fromRGB(96, 84, 60) -- the Outbreak pad's own concrete: warm amber-brown, a step between the squad pads' neutral grey and Nightmare's red tint
local LINE = Color3.fromRGB(196, 164, 60) -- the squad pads' ring colour (gold/amber family)
local LINE_MODE = Color3.fromRGB(200, 110, 30) -- the Outbreak ring: burnt orange, clearly not yellow (the squad pads keep the gold)
local WHITE = Color3.fromRGB(220, 220, 215)
local METAL = Color3.fromRGB(70, 72, 76)
local EDGE = Color3.fromRGB(255, 60, 50)
local GLOW = Color3.fromRGB(110, 220, 100) -- toxic green: the mode differentiator (yellow = normal pads, red = Nightmare)
local GLOW_TOP = Color3.fromRGB(180, 255, 160)

local GROUND_Y = 1
local SPOT = Vector2.new(0, -176) -- FlightLine-local: world (lobby.X, lobby.Z - 176) = (1000, 824). On the deck's central axis, mirrored north of the Nightmare cage (centre 868) so the special pads balance the grid; 22+ studs clear of the cage, pads 3/4 and the north taxi line
local RADIUS = 7.5 -- Pad diameter 15

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

local function cylinder(parent, name, height, diameter, cframe, color, material, props)
	local p = part(parent, name, Vector3.new(height, diameter, diameter), cframe * CFrame.Angles(0, 0, math.rad(90)), color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
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
	label.TextColor3 = textColor or WHITE
	label.Parent = gui
end

function ModePad.Build(lobby)
	-- the model is named "Helipad" (MapService scans Helipad models), so find our old one by PadId, not by name
	for _, d in lobby:GetChildren() do
		if d.Name == "Helipad" and d:GetAttribute("PadId") == 6 then
			d:Destroy()
		end
	end
	local origin = GameConfig.OurMap.LobbyCenter
	local c = CFrame.new(origin.X + SPOT.X, GROUND_Y, origin.Z + SPOT.Y)

	local m = Instance.new("Model")
	m.Name = "Helipad" -- MapService scans Helipad models for pads
	m:SetAttribute("PadId", 6)
	m:SetAttribute("ModeId", "Outbreak")

	cylinder(m, "Pad", 0.4, RADIUS * 2, c * CFrame.new(0, 0.2, 0), CONCRETE_MODE, Enum.Material.Concrete)
	cylinder(m, "Ring", 0.42, RADIUS * 1.92, c * CFrame.new(0, 0.22, 0), LINE_MODE, Enum.Material.SmoothPlastic)
	cylinder(m, "Inner", 0.44, RADIUS * 1.81, c * CFrame.new(0, 0.24, 0), CONCRETE_MODE, Enum.Material.Concrete)
	for _, dx in { -1.85, 1.85 } do
		part(m, "H", Vector3.new(0.85, 0.05, 5.9), c * CFrame.new(dx, 0.48, 0), WHITE, Enum.Material.SmoothPlastic)
	end
	part(m, "H", Vector3.new(2.9, 0.05, 0.85), c * CFrame.new(0, 0.48, 0), WHITE, Enum.Material.SmoothPlastic)
	for i = 0, 7 do
		local a = i * math.pi / 4
		local light = part(m, "EdgeLight", Vector3.new(0.55, 0.35, 0.55), c * CFrame.new(math.cos(a) * (RADIUS + 0.8), 0.25, math.sin(a) * (RADIUS + 0.8)), EDGE, Enum.Material.Neon)
		local glow = Instance.new("PointLight")
		glow.Color = light.Color
		glow.Range = 6
		glow.Parent = light
	end

	-- deploy glow: same construction as buildHelipad's, amber, R 7.5 / H 5 / 40 chords
	local glowFolder = Instance.new("Folder")
	glowFolder.Name = "DeployGlow"
	glowFolder.Parent = m
	local GLOW_R, GLOW_H, GLOW_N = RADIUS, 5, 40
	local chord = 2 * GLOW_R * math.sin(math.pi / GLOW_N)
	local apothem = GLOW_R * math.cos(math.pi / GLOW_N)
	local ghost = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
	local anchor = part(glowFolder, "Anchor", Vector3.new(1, 1, 1), c * CFrame.new(0, 0.4, 0), GLOW, Enum.Material.SmoothPlastic, ghost)
	anchor.Transparency = 1
	local fade = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.35, 0.6), NumberSequenceKeypoint.new(1, 1) })
	for i = 0, GLOW_N - 1 do
		local a = (i + 0.5) * 2 * math.pi / GLOW_N
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local tangent = Vector3.new(-out.Z, 0, out.X)
		local foot = Instance.new("Attachment")
		foot.CFrame = CFrame.fromMatrix(out * apothem, Vector3.yAxis, tangent)
		foot.Parent = anchor
		local top = Instance.new("Attachment")
		top.CFrame = CFrame.fromMatrix(out * apothem + Vector3.new(0, GLOW_H, 0), Vector3.yAxis, tangent)
		top.Parent = anchor
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = foot, top
		beam.Width0, beam.Width1 = chord, chord
		beam.FaceCamera = false
		beam.Segments = 1
		beam.Color = ColorSequence.new(GLOW, GLOW_TOP)
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Transparency = fade
		beam.Parent = anchor
		local at = anchor.CFrame.Position + out * apothem + Vector3.new(0, 0.06, 0)
		part(glowFolder, "Base", Vector3.new(chord + 0.02, 0.12, 0.3), CFrame.lookAt(at, at + out), GLOW, Enum.Material.Neon, ghost)
	end

	-- sign post, west side, facing the deck gate approach (same build as the pads' DEPLOY ZONE sign)
	local post = part(m, "SignPost", Vector3.new(0.4, 5, 0.4), c * CFrame.new(-9.5, 2.5, 6.5), METAL, Enum.Material.Metal)
	local board = part(m, "Sign", Vector3.new(6, 1.8, 0.25), post.CFrame * CFrame.new(0, 1.5, 0.3), LINE_MODE, Enum.Material.Metal)
	sign(board, Enum.NormalId.Back, "OUTBREAK", LINE_MODE, Color3.fromRGB(25, 25, 25)) -- Back = +Z face = faces SOUTH: players arrive from the deck gate (z 938), same convention as the pads' DEPLOY ZONE sign and the Nightmare gate sign ("read from the gate side (south)")

	m.Parent = lobby
	return m
end

return ModePad