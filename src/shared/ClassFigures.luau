-- ClassFigures: a blocky soldier figure per class (vault: Lobby.md). Used by the Barracks
-- mannequins (Server/Map/OurLobby) and the class shop previews (Client/Controllers/ShopController).
-- ClassFigures.Build(classId) -> Model (anchored, non-colliding; feet at y = 0, facing -Z,
-- PrimaryPart = Torso, centred 3 studs up). Every figure has a face, gloves, knee pads and a vest;
-- the sleeves are the class Color, and each class has its own pose, headgear and kit:
--   Survivor  cap, bandolier, backpack, rifle held across the chest
--   Scout     goggles on the forehead, scarf, binoculars, sniper slung on the back, mid-stride
--   Medic     white cross helmet, armband, medkit in hand, cross backpack
--   Engineer  hard hat with headlamp, hi-vis vest, tool belt, wrench
--   Bruiser   heavy visored helmet, armour plates, riot shield, sledgehammer (wider build)

local Classes = require(script.Parent:WaitForChild("Config"):WaitForChild("Classes"))

local ClassFigures = {}

local V, C, A = Vector3.new, CFrame.new, CFrame.Angles
local PANTS = Color3.fromRGB(50, 52, 58)
local BOOTS = Color3.fromRGB(32, 30, 28)
local GLOVE = Color3.fromRGB(38, 36, 34)
local METAL = Color3.fromRGB(70, 72, 78)
local GUN = Color3.fromRGB(34, 35, 38)
local OLIVE = Color3.fromRGB(84, 92, 62)
local STRAP = Color3.fromRGB(110, 76, 44)
local WHITE = Color3.fromRGB(235, 235, 230)
local RED = Color3.fromRGB(200, 40, 40)
local DARK = Color3.fromRGB(28, 28, 32)
local SKIN = {
	Survivor = Color3.fromRGB(204, 162, 128),
	Scout = Color3.fromRGB(232, 194, 164),
	Medic = Color3.fromRGB(141, 96, 70),
	Engineer = Color3.fromRGB(184, 134, 98),
	Bruiser = Color3.fromRGB(120, 84, 62),
}
-- arm poses { pitch (+ = forward), roll (toward the body: - for the right arm, + for the left) }
-- per side (right, left); hands end 2 studs down the arm
local POSES = {
	Survivor = { { 0.6, -0.25 }, { 1.1, 0.55 } }, -- rifle across the chest
	Scout = { { -0.25, -0.05 }, { 0.3, 0.1 } },
	Medic = { { 0.15, -0.08 }, { 0.15, 0.08 } },
	Engineer = { { 0.25, -0.1 }, { 0.1, 0.08 } },
	Bruiser = { { 0.1, -0.06 }, { 0.95, 0.3 } }, -- shield arm up
}

local function add(model, name, size, cframe, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

-- A rifle from the grip (hand) toward the support hand; long = sniper
local function rifle(model, grip, fore, long)
	local cf = CFrame.lookAt(grip, fore)
	local reach = (fore - grip).Magnitude
	add(model, "Receiver", V(0.3, 0.45, 1.5), cf * C(0, 0.2, -0.45), GUN, Enum.Material.Metal)
	add(model, "Stock", V(0.26, 0.5, 1), cf * C(0, 0.1, 0.65), GUN)
	add(model, "Handguard", V(0.32, 0.34, 1.1), cf * C(0, 0.22, -(reach + 0.1)), OLIVE)
	add(model, "Barrel", V(0.14, 0.14, if long then 2.6 else 1.4), cf * C(0, 0.24, -(reach + (if long then 1.7 else 1.1))), GUN, Enum.Material.Metal)
	add(model, "Mag", V(0.24, 0.6, 0.34), cf * C(0, -0.25, -0.75) * A(0.25, 0, 0), GUN)
	if long then
		add(model, "Scope", V(0.2, 0.2, 1.1), cf * C(0, 0.6, -0.5), DARK, Enum.Material.Metal)
	end
end

function ClassFigures.Build(classId)
	local def = Classes.List[classId] or Classes.List[Classes.Default]
	classId = if Classes.List[classId] then classId else Classes.Default
	local shirt = def.Color
	local skin = SKIN[classId] or SKIN.Survivor
	local big = classId == "Bruiser"
	local model = Instance.new("Model")
	model.Name = classId
	local torsoW = if big then 2.6 else 2
	local torsoD = if big then 1.3 else 1
	local armW = if big then 1.15 else 0.95

	-- legs with knee pads and boots (the Scout is mid-stride)
	local stride = if classId == "Scout" then 0.4 else 0
	for _, x in { -0.5, 0.5 } do
		local hip = C(x, 2, 0) * A(stride * (if x < 0 then 1 else -1), 0, 0)
		add(model, "Leg", V(0.98, 2, 0.98), hip * C(0, -1, 0), PANTS, Enum.Material.Fabric)
		add(model, "KneePad", V(0.9, 0.5, 0.2), hip * C(0, -1, -0.55), DARK)
		add(model, "Boot", V(1.04, 0.45, 1.25), hip * C(0, -1.78, -0.12), BOOTS)
	end

	-- torso, vest, belt
	local torso = add(model, "Torso", V(torsoW, 2, torsoD), C(0, 3, 0), shirt, Enum.Material.Fabric)
	local vestColor = if classId == "Engineer" then Color3.fromRGB(255, 120, 30) elseif classId == "Medic" then WHITE elseif big then METAL else OLIVE
	local vestMat = if big then Enum.Material.DiamondPlate else Enum.Material.Fabric
	add(model, "VestFront", V(torsoW - 0.1, 1.5, 0.22), C(0, 3.2, -(torsoD / 2 + 0.1)), vestColor, vestMat)
	add(model, "VestBack", V(torsoW - 0.1, 1.5, 0.22), C(0, 3.2, torsoD / 2 + 0.1), vestColor, vestMat)
	for _, x in { -0.55, 0.55 } do
		add(model, "VestStrap", V(0.35, 0.2, torsoD + 0.5), C(x * torsoW / 2, 3.98, 0), vestColor, vestMat)
	end
	add(model, "Belt", V(torsoW + 0.06, 0.32, torsoD + 0.06), C(0, 2.12, 0), STRAP)
	add(model, "Buckle", V(0.3, 0.22, 0.06), C(0, 2.12, -(torsoD / 2 + 0.05)), METAL, Enum.Material.Metal)
	if classId ~= "Engineer" then
		for _, x in { -0.55, 0, 0.55 } do
			add(model, "Pouch", V(0.46, 0.45, 0.22), C(x * torsoW / 2, 2.62, -(torsoD / 2 + 0.3)), (if big then METAL else OLIVE):Lerp(DARK, 0.25), Enum.Material.Fabric)
		end
	end

	-- neck, head, face
	add(model, "Neck", V(0.6, 0.25, 0.6), C(0, 4.08, 0), skin)
	add(model, "Head", V(1.2, 1.2, 1.2), C(0, 4.75, 0), skin)
	for _, x in { -0.26, 0.26 } do
		add(model, "Eye", V(0.2, 0.22, 0.05), C(x, 4.8, -0.62), DARK)
		add(model, "Brow", V(0.32, 0.08, 0.05), C(x, 5.0, -0.62) * A(0, 0, x * -0.4), DARK)
	end
	add(model, "Mouth", V(0.42, 0.07, 0.05), C(0, 4.42, -0.62), skin:Lerp(DARK, 0.6))

	-- arms: one block from the shoulder, sleeve on the upper half, glove at the end
	local hands = {}
	for i, side in { 1, -1 } do
		local pose = POSES[classId][i]
		local shoulder = C(side * (torsoW / 2 + armW / 2), 3.9, 0) * A(pose[1], 0, pose[2])
		add(model, "Arm", V(armW, 2, armW), shoulder * C(0, -1, 0), skin)
		add(model, "Sleeve", V(armW + 0.05, 1, armW + 0.05), shoulder * C(0, -0.5, 0), shirt, Enum.Material.Fabric)
		add(model, "Glove", V(armW + 0.08, 0.5, armW + 0.08), shoulder * C(0, -1.8, 0), GLOVE, Enum.Material.Fabric)
		hands[i] = shoulder * C(0, -2, 0)
	end
	local rightHand, leftHand = hands[1], hands[2]

	if classId == "Survivor" then
		add(model, "Cap", V(1.3, 0.4, 1.3), C(0, 5.5, 0), OLIVE, Enum.Material.Fabric)
		add(model, "Brim", V(1.2, 0.12, 0.6), C(0, 5.36, -0.85), OLIVE:Lerp(DARK, 0.2), Enum.Material.Fabric)
		add(model, "Bandolier", V(0.35, 2.7, 0.1), C(0, 3.1, -(torsoD / 2 + 0.24)) * A(0, 0, math.rad(40)), STRAP, Enum.Material.Fabric)
		add(model, "Backpack", V(1.5, 1.6, 0.7), C(0, 3.1, torsoD / 2 + 0.55), OLIVE:Lerp(STRAP, 0.4), Enum.Material.Fabric)
		add(model, "Grenade", V(0.45, 0.45, 0.45), C(0.55, 2.62, -(torsoD / 2 + 0.5)), Color3.fromRGB(70, 96, 52), Enum.Material.Metal, Enum.PartType.Ball)
		rifle(model, rightHand.Position, leftHand.Position)
	elseif classId == "Scout" then
		add(model, "GoggleBand", V(1.26, 0.3, 1.26), C(0, 5.1, 0), DARK)
		add(model, "Goggles", V(0.95, 0.3, 0.1), C(0, 5.12, -0.66), Color3.fromRGB(110, 230, 255), Enum.Material.Neon)
		add(model, "Scarf", V(1.35, 0.4, 1.15), C(0, 4.15, 0), shirt:Lerp(DARK, 0.4), Enum.Material.Fabric)
		add(model, "Binoculars", V(0.7, 0.32, 0.36), C(0, 3.55, -(torsoD / 2 + 0.42)), DARK, Enum.Material.Metal)
		local sling = C(0, 3, torsoD / 2 + 0.35) * A(0, 0, math.rad(-35))
		rifle(model, (sling * C(0, -1.4, 0)).Position, (sling * C(0, 0.5, 0)).Position, true)
		add(model, "Sling", V(0.18, 2.8, 0.08), C(0, 3.2, -(torsoD / 2 + 0.24)) * A(0, 0, math.rad(35)), STRAP, Enum.Material.Fabric)
	elseif classId == "Medic" then
		add(model, "Helmet", V(1.4, 0.6, 1.4), C(0, 5.5, 0), WHITE)
		add(model, "HelmetRim", V(1.5, 0.14, 1.5), C(0, 5.22, 0), WHITE:Lerp(DARK, 0.15))
		add(model, "HelmetCrossV", V(0.16, 0.45, 0.04), C(0, 5.5, -0.72), RED)
		add(model, "HelmetCrossH", V(0.45, 0.16, 0.04), C(0, 5.5, -0.72), RED)
		add(model, "CrossV", V(0.25, 0.75, 0.04), C(0, 3.3, -(torsoD / 2 + 0.23)), RED)
		add(model, "CrossH", V(0.75, 0.25, 0.04), C(0, 3.3, -(torsoD / 2 + 0.23)), RED)
		add(model, "Armband", V(1.02, 0.28, 1.02), C(-(torsoW / 2 + armW / 2), 3.3, 0), WHITE)
		add(model, "Backpack", V(1.5, 1.6, 0.7), C(0, 3.1, torsoD / 2 + 0.55), WHITE:Lerp(DARK, 0.1))
		add(model, "PackCrossV", V(0.25, 0.75, 0.04), C(0, 3.1, torsoD / 2 + 0.92), RED)
		add(model, "PackCrossH", V(0.75, 0.25, 0.04), C(0, 3.1, torsoD / 2 + 0.92), RED)
		local kit = rightHand * C(0, -0.35, 0)
		add(model, "Medkit", V(0.5, 0.75, 1), kit, WHITE)
		add(model, "KitCross", V(0.52, 0.15, 0.55), kit, RED)
	elseif classId == "Engineer" then
		local yellow = Color3.fromRGB(240, 200, 40)
		add(model, "HardHat", V(1.35, 0.5, 1.35), C(0, 5.55, 0), yellow)
		add(model, "HatBrim", V(1.6, 0.1, 1.7), C(0, 5.3, -0.05), yellow)
		add(model, "Headlamp", V(0.4, 0.3, 0.12), C(0, 5.55, -0.72), WHITE, Enum.Material.Neon)
		add(model, "WeldGoggles", V(0.9, 0.25, 0.1), C(0, 5.85, -0.5) * A(-0.5, 0, 0), DARK, Enum.Material.Glass)
		for _, y in { 2.85, 3.55 } do
			add(model, "Reflector", V(torsoW, 0.16, torsoD + 0.5), C(0, y, 0), Color3.fromRGB(220, 220, 210), Enum.Material.Foil)
		end
		add(model, "ToolBelt", V(torsoW + 0.2, 0.5, torsoD + 0.3), C(0, 2.2, 0), STRAP, Enum.Material.Fabric)
		add(model, "Hammer", V(0.14, 0.9, 0.14), C(-0.8, 2.1, -(torsoD / 2 + 0.25)), Color3.fromRGB(150, 110, 70))
		local wrench = rightHand * C(0, -0.2, -0.2) * A(math.rad(-80), 0, 0)
		add(model, "WrenchShaft", V(0.2, 1.7, 0.2), wrench * C(0, 0.55, 0), METAL, Enum.Material.Metal)
		add(model, "WrenchHead", V(0.6, 0.32, 0.2), wrench * C(0, 1.45, 0), METAL, Enum.Material.Metal)
	elseif classId == "Bruiser" then
		add(model, "Helmet", V(1.5, 0.75, 1.5), C(0, 5.45, 0), METAL, Enum.Material.DiamondPlate)
		add(model, "Visor", V(1.3, 0.35, 0.1), C(0, 4.95, -0.68), Color3.fromRGB(40, 50, 60), Enum.Material.Glass)
		for _, side in { -1, 1 } do
			add(model, "ShoulderPad", V(1.5, 0.6, 1.6), C(side * (torsoW / 2 + 0.55), 4.15, 0) * A(0, 0, side * -0.25), METAL, Enum.Material.DiamondPlate)
		end
		local shield = leftHand * C(0, 0.2, -0.5) * A(-math.rad(50), 0, 0)
		add(model, "Shield", V(1.9, 2.8, 0.15), shield, Color3.fromRGB(60, 70, 80), Enum.Material.Glass)
		add(model, "ShieldRim", V(2, 0.2, 0.18), shield * C(0, 1.35, 0), DARK, Enum.Material.Metal)
		add(model, "ShieldStripe", V(1.9, 0.25, 0.16), shield * C(0, 0.4, 0), shirt, Enum.Material.SmoothPlastic)
		local hammer = rightHand * C(0, -0.1, 0)
		add(model, "HammerHandle", V(0.2, 2, 0.2), hammer * C(0, -0.6, 0), Color3.fromRGB(110, 82, 52))
		add(model, "HammerHead", V(1.1, 0.6, 0.6), hammer * C(0, -1.6, 0), METAL, Enum.Material.Metal)
	end

	model.PrimaryPart = torso
	return model
end

return ClassFigures
