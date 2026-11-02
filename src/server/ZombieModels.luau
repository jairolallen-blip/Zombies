-- ZombieModels: blocky R6-style zombie bodies with per-zombie variation (vault: Zombies.md; style from
-- MODEL REFERENCES). ZombieModels.Build(typeId, def, cframe) -> model, root, linearVelocity, alignOrientation
--
-- Contract used by ZombieService / CombatService / EffectsController:
--   "Root"      invisible collision hitbox (2.4 x 5 x 1.6 * Scale), centre at the given CFrame
--   Motor6Ds named LeftArm / RightArm / LeftLeg / RightLeg on Root (client animates .Transform)
--   "Torso"     the shirt block (Bloater fuse turns it neon)
--   "Head", "Head*" detail parts and "Eye" parts count as headshots
-- Builds (def.Look.Build): Normal, Lean (hunched), Bloated, Hulk, Titan.

local ZombieModels = {}

local BLOOD = Color3.fromRGB(96, 18, 16)
local MOUTH = Color3.fromRGB(46, 8, 8)
local TEETH = Color3.fromRGB(226, 220, 190)
local BONE = Color3.fromRGB(214, 204, 182)
local SHOE = Color3.fromRGB(34, 30, 28)
local RUST = Color3.fromRGB(116, 64, 40)

-- body proportions per build (unit scale): torso / arm / leg sizes, torso lean (radians)
local BUILDS = {
	Normal = { Torso = Vector3.new(2, 2, 1), Arm = Vector3.new(1, 1, 2.2), Leg = Vector3.new(1, 2, 1), Lean = 0.08 },
	Lean = { Torso = Vector3.new(1.7, 2, 0.85), Arm = Vector3.new(0.8, 0.8, 2.3), Leg = Vector3.new(0.85, 2, 0.85), Lean = 0.3 },
	Bloated = { Torso = Vector3.new(2.8, 2.1, 2), Arm = Vector3.new(1.1, 1.1, 2), Leg = Vector3.new(1.1, 2, 1.1), Lean = 0 },
	Hulk = { Torso = Vector3.new(2.8, 2.2, 1.4), Arm = Vector3.new(1.3, 1.3, 2.6), Leg = Vector3.new(1.2, 2, 1.2), Lean = 0.15 },
	Titan = { Torso = Vector3.new(2.8, 2.2, 1.4), Arm = Vector3.new(1.3, 1.3, 2.6), Leg = Vector3.new(1.2, 2, 1.2), Lean = 0.1 },
}

local function newPart(name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.CollisionGroup = "Zombies"
	return p
end

-- detail part welded to `base` at `offset` (base-local)
local function stick(base, name, size, offset, color, material)
	local p = newPart(name, size, color, material)
	p.CFrame = base.CFrame * offset
	local w = Instance.new("Weld")
	w.Part0 = base
	w.Part1 = p
	w.C0 = offset
	w.Parent = p
	p.Parent = base.Parent
	return p
end

local function pick(rng, list)
	return list[rng:NextInteger(1, #list)]
end

local function face(head, look, s, rng)
	local front = -(head.Size.Z / 2 + 0.03 * s)
	local skin = look.Skin
	for _, x in { -0.27, 0.27 } do
		local eye = stick(head, "Eye", Vector3.new(0.28, 0.22, 0.08) * s, CFrame.new(x * s, 0.12 * s, front), look.Eyes, Enum.Material.Neon)
		eye.CastShadow = false
		stick(head, "HeadBrow", Vector3.new(0.34, 0.08, 0.06) * s, CFrame.new(x * s, 0.31 * s, front) * CFrame.Angles(0, 0, x > 0 and 0.35 or -0.35), skin:Lerp(Color3.new(), 0.45))
	end
	stick(head, "HeadMouth", Vector3.new(0.62, 0.3, 0.06) * s, CFrame.new(0, -0.3 * s, front), MOUTH)
	for _, x in { -0.18, 0, 0.18 } do
		if rng:NextNumber() < 0.75 then
			stick(head, "HeadTooth", Vector3.new(0.11, 0.12, 0.05) * s, CFrame.new(x * s, -0.2 * s, front - 0.01 * s), TEETH)
		end
	end
	if rng:NextNumber() < 0.6 then -- wound on the cheek or forehead
		local spot = pick(rng, { Vector3.new(0.35, -0.05, 0), Vector3.new(-0.35, -0.05, 0), Vector3.new(0.1, 0.45, 0) })
		stick(head, "HeadWound", Vector3.new(0.3, 0.26, 0.05) * s, CFrame.new(spot.X * s, spot.Y * s, front), BLOOD)
	end
	if look.Build ~= "Titan" and rng:NextNumber() < 0.4 then -- matted hair
		stick(head, "HeadHair", Vector3.new(head.Size.X + 0.04, 0.28 * s, head.Size.Z + 0.04), CFrame.new(0, head.Size.Y / 2, 0.05 * s), pick(rng, { Color3.fromRGB(40, 32, 26), Color3.fromRGB(90, 80, 70), Color3.fromRGB(70, 46, 30) }), Enum.Material.Fabric)
	end
end

local function torsoDetails(torso, look, build, s, rng)
	local size = torso.Size
	local front = -(size.Z / 2 + 0.03 * s)
	if build == "Normal" or build == "Lean" or build == "Hulk" then
		-- torn shirt: exposed ribs on one side of the chest
		if rng:NextNumber() < 0.65 then
			local x = (if rng:NextNumber() < 0.5 then -1 else 1) * size.X * 0.22
			stick(torso, "TornChest", Vector3.new(size.X * 0.42, size.Y * 0.5, 0.05 * s), CFrame.new(x, size.Y * 0.08, front), BLOOD)
			for r = 0, 2 do
				stick(torso, "Rib", Vector3.new(size.X * 0.36, 0.1 * s, 0.06 * s), CFrame.new(x, size.Y * (0.24 - r * 0.15), front - 0.02 * s), BONE)
			end
		end
		-- ragged hem hanging over the hips
		local shirt = torso.Color
		for i = -1, 1 do
			if rng:NextNumber() < 0.7 then
				local h = rng:NextNumber(0.2, 0.45) * s
				stick(torso, "Hem", Vector3.new(size.X * 0.28, h, size.Z + 0.02), CFrame.new(i * size.X * 0.33, -size.Y / 2 - h / 2, 0), shirt, Enum.Material.Fabric)
			end
		end
	end
	for _ = 1, rng:NextInteger(1, 2) do -- blood stains, front or back
		local z = if rng:NextNumber() < 0.6 then front else -front
		local w = rng:NextNumber(0.35, 0.6) * s
		stick(torso, "Stain", Vector3.new(w, w * 0.8, 0.05 * s), CFrame.new(rng:NextNumber(-0.5, 0.5) * size.X * 0.6, rng:NextNumber(-0.4, 0.3) * size.Y, z), BLOOD)
	end
	if build == "Bloated" then
		local belly = stick(torso, "Belly", Vector3.new(size.X * 0.8, size.Y * 0.7, size.Z * 0.7), CFrame.new(0, -size.Y * 0.12, -size.Z * 0.28), look.Skin)
		belly.Shape = Enum.PartType.Ball
		for _ = 1, 6 do
			local d = rng:NextNumber(0.35, 0.7) * s
			local pustule = stick(torso, "Pustule", Vector3.one * d, CFrame.new(rng:NextNumber(-0.45, 0.45) * size.X, rng:NextNumber(-0.4, 0.4) * size.Y, (if rng:NextNumber() < 0.7 then -1 else 1) * size.Z * 0.5), Color3.fromRGB(170, 255, 70), Enum.Material.Neon)
			pustule.Shape = Enum.PartType.Ball
			pustule.CastShadow = false
		end
	elseif build == "Hulk" then
		for n = 1, 3 do -- rebar driven through the back
			stick(torso, "Rebar", Vector3.new(0.18, 0.18, 2.2) * s, CFrame.new((n - 2) * size.X * 0.25, size.Y * (0.25 - n * 0.12), size.Z * 0.5) * CFrame.Angles(rng:NextNumber(-0.6, -0.2), rng:NextNumber(-0.4, 0.4), 0), RUST, Enum.Material.Metal)
		end
	elseif build == "Titan" then
		for _, x in { -1, 1 } do
			stick(torso, "BonePlate", Vector3.new(size.X * 0.42, 0.6 * s, size.Z * 1.15), CFrame.new(x * size.X * 0.42, size.Y * 0.5, 0) * CFrame.Angles(0, 0, -x * 0.3), BONE, Enum.Material.Slate)
		end
		for n = 1, 4 do -- glowing cracks
			local crack = stick(torso, "Crack", Vector3.new(0.12 * s, rng:NextNumber(0.5, 1.1) * s, 0.05 * s), CFrame.new(rng:NextNumber(-0.4, 0.4) * size.X, rng:NextNumber(-0.3, 0.3) * size.Y, front) * CFrame.Angles(0, 0, rng:NextNumber(-0.8, 0.8)), look.Eyes, Enum.Material.Neon)
			crack.CastShadow = false
		end
	end
end

function ZombieModels.Build(typeId, def, cf)
	local rng = Random.new()
	local s = def.Scale or 1
	local look = def.Look
	local buildName = look.Build or "Normal"
	local b = BUILDS[buildName]
	local shirt, pants = pick(rng, look.Shirts), pick(rng, look.Pants)
	local model = Instance.new("Model")
	model.Name = typeId

	local root = newPart("Root", Vector3.new(2.4, 5, 1.6) * s, Color3.new())
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	root.CustomPhysicalProperties = PhysicalProperties.new(1, 0, 0, 100, 100)
	root.CFrame = cf
	root.Parent = model
	model.PrimaryPart = root

	local function weldToRoot(p, offset)
		p.CFrame = cf * offset
		local w = Instance.new("Weld")
		w.Part0 = root
		w.Part1 = p
		w.C0 = offset
		w.Parent = p
		p.Parent = model
		return p
	end
	local function motor(p, joint, limbCenter)
		p.CFrame = cf * limbCenter
		local m = Instance.new("Motor6D")
		m.Name = p.Name
		m.Part0 = root
		m.Part1 = p
		m.C0 = joint
		m.C1 = limbCenter:Inverse() * joint
		m.Parent = root
		p.Parent = model
		return p
	end

	local torsoSize = b.Torso * s
	local hip = -0.5 * s
	local torsoCF = CFrame.new(0, hip + torsoSize.Y / 2, 0) * CFrame.Angles(-b.Lean, 0, 0)
	local torso = weldToRoot(newPart("Torso", torsoSize, shirt, Enum.Material.Fabric), torsoCF)
	local neck = torsoCF * CFrame.new(0, torsoSize.Y / 2, 0)
	local head = weldToRoot(newPart("Head", Vector3.new(1.25, 1.25, 1.25) * s, look.Skin), neck * CFrame.new(0, 0.62 * s, 0) * CFrame.Angles(rng:NextNumber(-0.15, 0.1), 0, rng:NextNumber(-0.25, 0.25)))
	face(head, look, s, rng)
	torsoDetails(torso, look, buildName, s, rng)
	if buildName == "Titan" then
		local glow = Instance.new("PointLight")
		glow.Color = look.Eyes
		glow.Range = 14
		glow.Brightness = 2
		glow.Parent = head
	end

	-- arms reach forward from the shoulders
	local arm = b.Arm * s
	local shoulder = torsoCF * CFrame.new(0, torsoSize.Y / 2 - arm.Y / 2, 0)
	for _, side in { { "LeftArm", -1 }, { "RightArm", 1 } } do
		local x = (torsoSize.X / 2 + arm.X / 2) * side[2]
		local joint = CFrame.new(x, shoulder.Y, shoulder.Z)
		local limb = motor(newPart(side[1], arm, look.Skin), joint, joint * CFrame.new(0, 0, -arm.Z / 2 + 0.45 * s))
		local sleeve = if buildName == "Normal" or buildName == "Titan" then rng:NextNumber(0.25, 0.55) else 0
		if sleeve > 0 then -- torn sleeve near the shoulder
			stick(limb, "Sleeve", Vector3.new(arm.X + 0.04, arm.Y + 0.04, arm.Z * sleeve), CFrame.new(0, 0, arm.Z / 2 - arm.Z * sleeve / 2), shirt, Enum.Material.Fabric)
		end
		if rng:NextNumber() < 0.35 then
			stick(limb, "Stain", Vector3.new(arm.X + 0.02, arm.Y * 0.5, arm.Z * 0.2), CFrame.new(0, -arm.Y * 0.2, rng:NextNumber(-0.3, 0.2) * arm.Z), BLOOD)
		end
	end

	-- legs: pants (one sometimes torn to the shin) and shoes
	local leg = b.Leg * s
	for _, side in { { "LeftLeg", -1 }, { "RightLeg", 1 } } do
		local x = leg.X / 2 * side[2] * 1.02
		local limb = motor(newPart(side[1], leg, pants, Enum.Material.Fabric), CFrame.new(x, hip, 0), CFrame.new(x, hip - leg.Y / 2, 0))
		if rng:NextNumber() < 0.35 then
			stick(limb, "Shin", Vector3.new(leg.X + 0.02, leg.Y * 0.32, leg.Z + 0.02), CFrame.new(0, -leg.Y * 0.22, 0), look.Skin)
		end
		stick(limb, "Shoe", Vector3.new(leg.X + 0.06, 0.32 * s, leg.Z + 0.3 * s), CFrame.new(0, -leg.Y / 2 + 0.16 * s, -0.12 * s), SHOE)
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "Move"
	attachment.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.PlaneVelocity = Vector2.zero
	lv.MaxForce = root:GetMass() * 250
	lv.Parent = root
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = attachment
	ao.Responsiveness = 25
	ao.MaxTorque = math.huge
	ao.CFrame = cf.Rotation
	ao.Parent = root

	return model, root, lv, ao
end

return ZombieModels
