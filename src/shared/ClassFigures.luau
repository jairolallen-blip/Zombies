-- ClassFigures: a blocky soldier figure per class (vault: Lobby.md). Used by the Barracks
-- mannequins (Server/Map/OurLobby) and the class shop previews (Client/Controllers/ShopController).
-- ClassFigures.Build(classId) -> Model (anchored, non-colliding; feet at y = 0, facing -Z,
-- PrimaryPart = Torso). The shirt is the class Color; each class carries its own signature prop.

local Classes = require(script.Parent:WaitForChild("Config"):WaitForChild("Classes"))

local ClassFigures = {}

local SKIN = Color3.fromRGB(204, 162, 128)
local PANTS = Color3.fromRGB(50, 52, 58)
local BOOTS = Color3.fromRGB(32, 30, 28)
local METAL = Color3.fromRGB(70, 72, 78)
local WHITE = Color3.fromRGB(235, 235, 230)
local RED = Color3.fromRGB(200, 40, 40)

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

function ClassFigures.Build(classId)
	local def = Classes.List[classId] or Classes.List[Classes.Default]
	local shirt = def.Color
	local big = classId == "Bruiser"
	local model = Instance.new("Model")
	model.Name = classId
	local V, C = Vector3.new, CFrame.new
	local torsoW = if big then 2.6 else 2
	local armW = if big then 1.2 else 1

	-- legs (the Scout is mid-stride)
	local stride = if classId == "Scout" then 0.45 else 0
	for _, x in { -0.5, 0.5 } do
		local swing = CFrame.Angles(stride * (if x < 0 then 1 else -1), 0, 0)
		local hip = C(x, 2, 0) * swing
		add(model, "Leg", V(1, 2, 1), hip * C(0, -1, 0), PANTS, Enum.Material.Fabric)
		add(model, "Boot", V(1.04, 0.4, 1.2), hip * C(0, -1.8, -0.1), BOOTS)
	end
	local torso = add(model, "Torso", V(torsoW, 2, if big then 1.4 else 1), C(0, 3, 0), shirt, Enum.Material.Fabric)
	add(model, "Belt", V(torsoW + 0.04, 0.3, (if big then 1.4 else 1) + 0.04), C(0, 2.15, 0), Color3.fromRGB(60, 46, 34))
	add(model, "Head", V(1.2, 1.2, 1.2), C(0, 4.6, 0), SKIN)
	for _, x in { -0.25, 0.25 } do
		add(model, "Eye", V(0.18, 0.2, 0.05), C(x, 4.68, -0.62), Color3.fromRGB(30, 30, 34))
	end
	for _, side in { -1, 1 } do
		add(model, "Arm", V(armW, 2, armW), C(side * (torsoW / 2 + armW / 2), 3, 0), SKIN)
		add(model, "Sleeve", V(armW + 0.04, 0.9, armW + 0.04), C(side * (torsoW / 2 + armW / 2), 3.55, 0), shirt, Enum.Material.Fabric)
	end
	local rightHand = C(torsoW / 2 + armW / 2, 1.8, -0.2)
	local leftHand = C(-(torsoW / 2 + armW / 2), 1.8, -0.2)

	if classId == "Survivor" then
		add(model, "Cap", V(1.3, 0.35, 1.3), C(0, 5.3, 0), Color3.fromRGB(84, 92, 62), Enum.Material.Fabric)
		add(model, "Brim", V(1.2, 0.12, 0.6), C(0, 5.18, -0.85), Color3.fromRGB(70, 78, 52), Enum.Material.Fabric)
		add(model, "Bandolier", V(0.35, 2.6, 0.1), C(0, 3, -0.55) * CFrame.Angles(0, 0, math.rad(40)), Color3.fromRGB(110, 76, 44), Enum.Material.Fabric)
		add(model, "Grenade", V(0.6, 0.6, 0.6), rightHand * C(0, -0.2, -0.3), Color3.fromRGB(70, 96, 52), Enum.Material.Metal, Enum.PartType.Ball)
	elseif classId == "Scout" then
		add(model, "GoggleBand", V(1.24, 0.3, 1.24), C(0, 4.9, 0), Color3.fromRGB(30, 30, 30))
		add(model, "Goggles", V(0.9, 0.26, 0.08), C(0, 4.9, -0.64), Color3.fromRGB(110, 230, 255), Enum.Material.Neon)
		add(model, "Scarf", V(1.3, 0.35, 1.1), C(0, 4.05, 0), shirt:Lerp(Color3.new(), 0.3), Enum.Material.Fabric)
	elseif classId == "Medic" then
		add(model, "Patch", V(0.9, 0.9, 0.06), C(0, 3.2, -0.53), WHITE)
		add(model, "CrossV", V(0.22, 0.65, 0.04), C(0, 3.2, -0.57), RED)
		add(model, "CrossH", V(0.65, 0.22, 0.04), C(0, 3.2, -0.57), RED)
		local kit = leftHand * C(0, -0.4, -0.3)
		add(model, "Medkit", V(0.9, 0.7, 0.4), kit, WHITE)
		add(model, "KitCross", V(0.5, 0.15, 0.42), kit, RED)
	elseif classId == "Engineer" then
		add(model, "HardHat", V(1.35, 0.45, 1.35), C(0, 5.35, 0), Color3.fromRGB(240, 200, 40))
		add(model, "HatBrim", V(1.6, 0.1, 1.6), C(0, 5.13, 0), Color3.fromRGB(240, 200, 40))
		local wrench = rightHand * C(0, -0.1, -0.5) * CFrame.Angles(math.rad(-70), 0, 0)
		add(model, "WrenchShaft", V(0.2, 1.6, 0.2), wrench, METAL, Enum.Material.Metal)
		add(model, "WrenchHead", V(0.55, 0.3, 0.2), wrench * C(0, 0.85, 0), METAL, Enum.Material.Metal)
		add(model, "ToolPouch", V(0.6, 0.6, 0.4), C(0.7, 2, -0.6), Color3.fromRGB(110, 76, 44), Enum.Material.Fabric)
	elseif classId == "Bruiser" then
		for _, side in { -1, 1 } do
			add(model, "ShoulderPad", V(1.5, 0.6, 1.6), C(side * (torsoW / 2 + 0.55), 4.15, 0) * CFrame.Angles(0, 0, side * -0.25), METAL, Enum.Material.DiamondPlate)
		end
		add(model, "ChestPlate", V(torsoW - 0.3, 1.3, 0.1), C(0, 3.3, -0.72), METAL, Enum.Material.DiamondPlate)
	end

	model.PrimaryPart = torso
	return model
end

return ClassFigures
