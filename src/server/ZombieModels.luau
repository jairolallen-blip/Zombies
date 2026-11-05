-- ZombieModels: blocky R6-style zombie bodies with per-zombie variation (vault: Zombies.md; style from
-- MODEL REFERENCES). ZombieModels.Build(typeId, def, cframe) -> model, root, linearVelocity, alignOrientation
--
-- Contract used by ZombieService / CombatService / EffectsController:
--   "Root"      invisible collision hitbox (2.4 x 5 x 1.6 * Scale), centre at the given CFrame
--   Motor6Ds named LeftArm / RightArm / LeftLeg / RightLeg / Torso / Head on Root (client animates .Transform;
--   to the server they are rigid, so hits and collisions don't move)
--   "Torso"     the shirt block (Bloater fuse turns it neon)
--   "Head", "Head*" detail parts and "Eye" parts count as headshots
-- Builds (def.Look.Build): Normal, Lean (hunched), Bloated, Hulk, Titan, and for Nightmare Crawler (on all
-- fours) and Gaunt (tall, arms to the knees). def.Look.Horror adds a Nightmare type's details (horror()).

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
	-- Nightmare: ArmPitch tips the arms down from straight ahead, HeadUp lifts the face off a leaned torso,
	-- Head replaces the 1.25 cube
	Crawler = { Torso = Vector3.new(1.8, 2.2, 0.9), Arm = Vector3.new(0.7, 0.7, 2.9), Leg = Vector3.new(0.8, 2, 0.8), Lean = 1.15, ArmPitch = 1.2, HeadUp = 0.95 },
	Gaunt = { Torso = Vector3.new(1.5, 2.5, 0.75), Arm = Vector3.new(0.55, 0.55, 3.2), Leg = Vector3.new(0.7, 2, 0.7), Lean = 0.12, ArmPitch = 1.25, Head = Vector3.new(1, 1.55, 1.05) },
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
	-- front details stack on separate depth layers (0.015 x scale apart) so none share a plane: coplanar
	-- overlapping faces z-fight. Front faces: torn chest 0.025, stains 0.04 / 0.055, ribs 0.075, cracks 0.085+
	local function layer(depth)
		return front - depth * s
	end
	if build == "Normal" or build == "Lean" or build == "Hulk" then
		-- torn shirt: exposed ribs on one side of the chest
		if rng:NextNumber() < 0.65 then
			local x = (if rng:NextNumber() < 0.5 then -1 else 1) * size.X * 0.22
			stick(torso, "TornChest", Vector3.new(size.X * 0.42, size.Y * 0.5, 0.05 * s), CFrame.new(x, size.Y * 0.08, front), BLOOD)
			for r = 0, 2 do
				stick(torso, "Rib", Vector3.new(size.X * 0.36, 0.1 * s, 0.06 * s), CFrame.new(x, size.Y * (0.24 - r * 0.15), layer(0.045)), BONE)
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
	for k = 1, rng:NextInteger(1, 2) do -- blood stains, front or back, each on its own layer
		local z = if rng:NextNumber() < 0.6 then layer(0.015 * k) else -layer(0.015 * k)
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
		for n = 1, 4 do -- glowing cracks, each on its own layer (they cross each other)
			local crack = stick(torso, "Crack", Vector3.new(0.12 * s, rng:NextNumber(0.5, 1.1) * s, 0.05 * s), CFrame.new(rng:NextNumber(-0.4, 0.4) * size.X, rng:NextNumber(-0.3, 0.3) * size.Y, layer(0.06 + 0.015 * n)) * CFrame.Angles(0, 0, rng:NextNumber(-0.8, 0.8)), look.Eyes, Enum.Material.Neon)
			crack.CastShadow = false
		end
	end
end

-- Nightmare details (def.Look.Horror; the Nightmare types in Config/Zombies), added once the body is built.
-- Designs from the owner's references (vault: Nightmare Mode.md):
--   Rotter   rotting face: sunken red-rimmed eyes, a rotted-out nose, the jaw hanging open on yellow teeth,
--            lesions, ears, ribs through a torn shirt
--   Skitter  flayed: red muscle with darker striations, exposed ribcage and vertebrae, a bone skull face
--            with a lipless grin; low on all fours (Crawler build)
--   Husk     bone armour (shoulder plates, back carapace, forearm and shin guards, a skull plate and horns)
--            over a glowing seam it splits along; Half = one of the two halves it leaves behind
--   Bloom    the Nightmare boss (Bloated build): a spore sac on its back and glowing pods all over, shelf
--            fungus, a cluster of extra eyes, a gaping maw with tendrils, drifting spores and a sick green glow
--   Wailer   gaunt and bare-chested: arms to the knees with long talons, blind white eyes, a mouth
--            stretched open, gore down the chest, a rag on one shoulder, bare feet, a glowing throat sac
-- Every Nightmare zombie also gets claws and bony spikes down its spine. Head details are named "Head*"
-- and eyes "Eye", so they count as headshots like the rest of the face.
local GORE = Color3.fromRGB(78, 8, 10)
local ROT_TEETH = Color3.fromRGB(214, 190, 128)
local SOCKET = Color3.fromRGB(34, 10, 10)
local LESION = Color3.fromRGB(64, 40, 56)

local function horror(model, look, build, s, rng)
	local kind = look.Horror
	if not kind then
		return
	end
	local head, torso = model:FindFirstChild("Head"), model:FindFirstChild("Torso")
	local hs, ts = head.Size, torso.Size
	local hFront, tFront = -hs.Z / 2, -ts.Z / 2
	local bone = look.Bone or BONE
	local arms = { model:FindFirstChild("LeftArm"), model:FindFirstChild("RightArm") }
	local legs = { model:FindFirstChild("LeftLeg"), model:FindFirstChild("RightLeg") }
	local dripY = -0.45 * s -- bottom of the mouth (face() puts it at -0.3 x scale, 0.3 tall)
	local function neon(p)
		p.Material = Enum.Material.Neon
		p.CastShadow = false
		return p
	end

	-- claws: bone talons past each hand (arms reach along -Z); the Wailer's and Skitter's are long
	local clawLen = (if kind == "Wailer" then 1.25 elseif kind == "Skitter" then 0.9 else 0.6) * s
	for _, arm in arms do
		for i = -1, 1 do
			stick(arm, "Claw", Vector3.new(0.09, 0.09, 0) * s + Vector3.new(0, 0, clawLen), CFrame.new(i * arm.Size.X * 0.32, -arm.Size.Y * 0.2, -arm.Size.Z / 2 - clawLen / 2 + 0.06 * s) * CFrame.Angles(-0.4, i * 0.18, 0), bone)
		end
	end
	-- spine: bony spikes (vertebrae on the Skitter) along the back, angled up
	local spikes = if kind == "Skitter" then 7 elseif kind == "Husk" then 5 else 4
	for n = 1, spikes do
		local y = ts.Y * (0.42 - (n - 1) * 0.84 / spikes)
		local h = rng:NextNumber(0.3, 0.55) * s * (if kind == "Husk" then 1.7 elseif kind == "Skitter" then 0.7 else 1)
		stick(torso, "Spine", Vector3.new(0.24 * s, 0.24 * s, h), CFrame.new(0, y, ts.Z / 2 + h * 0.3) * CFrame.Angles(-0.5, 0, 0), bone)
	end

	-- the lower jaw hangs open, hinged just behind the face, and juts forward and down out of the mouth
	-- (Rotter, Wailer)
	local function jaw(drop, width, teeth)
		local w = hs.X * width
		local depth = hs.Z * 0.5
		local hinge = CFrame.new(0, -hs.Y / 2 + 0.14 * s, hFront + 0.3 * s) * CFrame.Angles(-drop, 0, 0)
		local j = stick(head, "HeadJaw", Vector3.new(w, 0.26 * s, depth), hinge * CFrame.new(0, -0.13 * s, -depth / 2), look.Skin:Lerp(Color3.new(), 0.2))
		stick(j, "HeadGums", Vector3.new(w * 0.86, 0.04 * s, depth * 0.8), CFrame.new(0, 0.13 * s + 0.015 * s, 0.02 * s), MOUTH)
		for i = 1, teeth do -- jagged lower teeth along the front edge
			local x = (i - (teeth + 1) / 2) / teeth * w * 0.85
			local th = rng:NextNumber(0.12, 0.24) * s
			stick(j, "HeadTooth", Vector3.new(0.09 * s, th, 0.07 * s), CFrame.new(x, 0.13 * s + th / 2, -depth / 2 + 0.06 * s) * CFrame.Angles(0, 0, rng:NextNumber(-0.25, 0.25)), ROT_TEETH)
		end
		return j
	end
	-- an exposed ribcage over a dark cavity in the chest (each on its own depth layer: no z-fighting)
	local function ribcage(ribs)
		stick(torso, "Cavity", Vector3.new(ts.X * 0.62, ts.Y * 0.5, 0.05 * s), CFrame.new(0, ts.Y * 0.08, tFront - 0.105 * s), GORE)
		for r = 0, ribs - 1 do
			stick(torso, "Rib", Vector3.new(ts.X * (0.7 - r * 0.04), 0.09 * s, 0.06 * s), CFrame.new(0, ts.Y * (0.28 - r * 0.13), tFront - 0.125 * s), bone)
		end
		stick(torso, "Sternum", Vector3.new(0.13 * s, ts.Y * 0.46, 0.07 * s), CFrame.new(0, ts.Y * 0.1, tFront - 0.14 * s), bone)
	end
	local function lesions(base, count)
		for _ = 1, count do
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local d = rng:NextNumber(0.18, 0.34) * s
			stick(base, base.Name == "Head" and "HeadLesion" or "Lesion", Vector3.new(0.05 * s, d, d * 1.2), CFrame.new(side * (base.Size.X / 2 + 0.02 * s), rng:NextNumber(-0.3, 0.3) * base.Size.Y, rng:NextNumber(-0.3, 0.3) * base.Size.Z), LESION)
		end
	end
	local function bareFeet()
		for _, p in model:GetChildren() do
			if p.Name == "Shoe" then
				p.Color = look.Skin:Lerp(Color3.new(), 0.15)
				p.Material = Enum.Material.SmoothPlastic
			end
		end
	end

	if kind == "Rotter" then
		-- sunken eyes: pale, bloodshot eyeballs with a burning pupil, in dark red-rimmed sockets
		for _, p in model:GetChildren() do
			if p.Name == "Eye" then
				p.Color = Color3.fromRGB(226, 214, 190)
				p.Material = Enum.Material.SmoothPlastic
			end
		end
		for _, x in { -0.27, 0.27 } do
			stick(head, "HeadSocket", Vector3.new(0.4, 0.34, 0.06) * s, CFrame.new(x * s, 0.12 * s, hFront - 0.005 * s), SOCKET)
			neon(stick(head, "Eye", Vector3.new(0.1, 0.1, 0.04) * s, CFrame.new(x * s, 0.12 * s, hFront - 0.085 * s), look.Eyes))
		end
		stick(head, "HeadNose", Vector3.new(0.18, 0.2, 0.06) * s, CFrame.new(0, -0.05 * s, hFront - 0.015 * s), SOCKET)
		for _, x in { -1, 1 } do
			stick(head, "HeadEar", Vector3.new(0.12, 0.36, 0.26) * s, CFrame.new(x * (hs.X / 2 + 0.05 * s), 0.05 * s, 0.08 * s) * CFrame.Angles(0, -x * 0.35, 0), look.Skin)
		end
		-- a bigger mouth, rotten upper teeth along its top edge, and the jaw hanging open below it
		for _, p in model:GetChildren() do
			if p.Name == "HeadTooth" then
				p:Destroy()
			elseif p.Name == "HeadMouth" then
				p.Size = Vector3.new(0.72, 0.36, 0.06) * s
				local weld = p:FindFirstChildOfClass("Weld")
				weld.C0 = CFrame.new(0, -0.36 * s, weld.C0.Position.Z)
				dripY = -0.54 * s
			end
		end
		for i = 1, 5 do
			local th = rng:NextNumber(0.1, 0.18) * s
			stick(head, "HeadTooth", Vector3.new(0.09 * s, th, 0.05 * s), CFrame.new((i - 3) * 0.13 * s, -0.19 * s - th / 2, hFront - 0.075 * s) * CFrame.Angles(0, 0, rng:NextNumber(-0.2, 0.2)), ROT_TEETH)
		end
		jaw(0.55, 0.62, 5)
		-- one cheek rotted through: a dark hole with the back teeth showing
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		stick(head, "HeadRot", Vector3.new(0.05 * s, 0.36 * s, 0.5 * s), CFrame.new(side * (hs.X / 2 + 0.02 * s), -0.28 * s, -hs.Z * 0.18), SOCKET)
		for k = 0, 2 do
			stick(head, "HeadTooth", Vector3.new(0.05 * s, 0.12 * s, 0.1 * s), CFrame.new(side * (hs.X / 2 + 0.05 * s), -0.26 * s, -hs.Z * 0.18 + (k - 1) * 0.13 * s), ROT_TEETH)
		end
		-- a broken bone through one forearm
		local arm = arms[if side > 0 then 1 else 2]
		stick(arm, "Bone", Vector3.new(0.2, 0.2, 0.75) * s, CFrame.new(0, arm.Size.Y * 0.45, -arm.Size.Z * 0.08) * CFrame.Angles(0.6, 0.3, 0), bone)
		stick(arm, "Gore", Vector3.new(arm.Size.X + 0.03 * s, 0.05 * s, arm.Size.Z * 0.3), CFrame.new(0, arm.Size.Y / 2 + 0.015 * s, -arm.Size.Z * 0.08), GORE)
		ribcage(3)
		lesions(head, 3)
		for _, a in arms do
			lesions(a, 2)
		end
	elseif kind == "Skitter" then
		-- flayed: muscle striations on torso and limbs, a bone skull face, bony elbows, bare feet
		local fibre = look.Skin:Lerp(Color3.new(), 0.35)
		for i = -2, 2 do
			stick(torso, "Fibre", Vector3.new(0.07 * s, ts.Y * 0.8, 0.04 * s), CFrame.new(i * ts.X * 0.17, 0, ts.Z / 2 + 0.025 * s) * CFrame.Angles(0, 0, i * 0.06), fibre)
		end
		for _, limb in { arms[1], arms[2], legs[1], legs[2] } do
			local isArm = limb.Size.Z > limb.Size.Y -- arms run along Z (top face up), legs along Y (front face)
			for _, x in { -0.22, 0.22 } do
				if isArm then
					stick(limb, "Fibre", Vector3.new(0.05 * s, 0.05 * s, limb.Size.Z * 0.7), CFrame.new(x * limb.Size.X, limb.Size.Y / 2 + 0.015 * s, 0), fibre)
				else
					stick(limb, "Fibre", Vector3.new(0.05 * s, limb.Size.Y * 0.7, 0.05 * s), CFrame.new(x * limb.Size.X, 0, -limb.Size.Z / 2 - 0.015 * s), fibre)
				end
			end
		end
		for _, arm in arms do -- elbow knob
			stick(arm, "Bone", Vector3.new(arm.Size.X * 0.7, 0.28 * s, 0.28 * s), CFrame.new(0, arm.Size.Y / 2 + 0.05 * s, arm.Size.Z * 0.1), bone)
		end
		head.Color = bone -- the skin is gone from the face
		for _, p in model:GetChildren() do
			if p.Name == "HeadHair" or p.Name == "HeadWound" or p.Name == "HeadBrow" or p.Name == "HeadTooth" then
				p:Destroy()
			elseif p.Name == "HeadMouth" then
				p.Size = Vector3.new(0.78, 0.3, 0.06) * s
			elseif p.Name == "Eye" then
				p.Size = Vector3.new(0.11, 0.11, 0.08) * s -- a pinprick of light in each socket
			end
		end
		for _, x in { -0.27, 0.27 } do -- deep sockets with a pinprick of light
			stick(head, "HeadSocket", Vector3.new(0.38, 0.36, 0.06) * s, CFrame.new(x * s, 0.12 * s, hFront - 0.005 * s), SOCKET)
		end
		for i = 1, 7 do -- a lipless grin: a full row of teeth top and bottom
			local x = (i - 4) * 0.105 * s
			stick(head, "HeadTooth", Vector3.new(0.085, 0.13, 0.05) * s, CFrame.new(x, -0.22 * s, hFront - 0.08 * s), TEETH)
			stick(head, "HeadTooth", Vector3.new(0.085, 0.11, 0.05) * s, CFrame.new(x, -0.39 * s, hFront - 0.08 * s), TEETH)
		end
		stick(head, "HeadNose", Vector3.new(0.16, 0.18, 0.06) * s, CFrame.new(0, -0.04 * s, hFront - 0.015 * s), SOCKET)
		ribcage(4)
		bareFeet()
	elseif kind == "Husk" or kind == "Half" then
		-- bare grey skin; the seam it splits along: a jagged glowing crack down the middle, spidering out,
		-- and over the skull
		torso.Color = look.Skin:Lerp(Color3.new(), 0.1)
		torso.Material = Enum.Material.SmoothPlastic
		for _, p in model:GetChildren() do
			if p.Name == "Hem" or p.Name == "TornChest" or p.Name == "Rib" then
				p:Destroy() -- no shirt left to tear
			end
		end
		local seam = look.Eyes
		local armoured = kind == "Husk"
		for k = 0, 5 do -- zigzag down the front
			local y = ts.Y * (0.42 - k * 0.17)
			neon(stick(torso, "Seam", Vector3.new(0.16 * s, ts.Y * 0.2, 0.05 * s), CFrame.new((if k % 2 == 0 then -0.05 else 0.05) * s, y, tFront - 0.11 * s) * CFrame.Angles(0, 0, if k % 2 == 0 then 0.25 else -0.25), seam))
		end
		for n = 1, 4 do -- cracks branching off it
			local x = (if n % 2 == 0 then 1 else -1) * ts.X * 0.14
			-- (on a Husk they run over the breastplate, which sits in front of the skin)
			neon(stick(torso, "Crack", Vector3.new(0.08 * s, rng:NextNumber(0.4, 0.8) * s, 0.05 * s), CFrame.new(x, ts.Y * rng:NextNumber(-0.3, 0.3), tFront - (if armoured then 0.28 else 0.125) * s) * CFrame.Angles(0, 0, -math.sign(x) * rng:NextNumber(0.6, 1.1)), seam))
		end
		neon(stick(torso, "Seam", Vector3.new(0.14 * s, ts.Y * 0.9, 0.05 * s), CFrame.new(0, 0, ts.Z / 2 + (if armoured then 0.3 else 0.11) * s), seam))
		local top = if armoured then hs.Y * 0.52 else hs.Y / 2
		neon(stick(head, "HeadSeam", Vector3.new(0.1 * s, 0.05 * s, hs.Z * 0.9), CFrame.new(0, top + 0.025 * s, 0), seam))
		local glow = Instance.new("PointLight")
		glow.Color = seam
		glow.Range = 9
		glow.Brightness = 1.4
		glow.Parent = torso
		if armoured then
			-- shoulder plates bristling with spikes, a breastplate split down the seam, a back carapace
			for _, x in { -1, 1 } do
				local plate = stick(torso, "BonePlate", Vector3.new(ts.X * 0.5, 0.5 * s, ts.Z * 1.3), CFrame.new(x * ts.X * 0.42, ts.Y * 0.5 + 0.1 * s, 0) * CFrame.Angles(0, 0, -x * 0.35), bone, Enum.Material.Slate)
				for k = -1, 1 do
					stick(plate, "Spike", Vector3.new(0.2, 0.75 + 0.2 * (1 - math.abs(k)), 0.2) * s, CFrame.new(x * plate.Size.X * 0.15, plate.Size.Y / 2 + 0.3 * s, k * plate.Size.Z * 0.3) * CFrame.Angles(k * 0.3, 0, -x * 0.25), bone)
				end
				-- the breastplate's halves, parted by the seam
				stick(torso, "BonePlate", Vector3.new(ts.X * 0.36, ts.Y * 0.62, 0.16 * s), CFrame.new(x * ts.X * 0.27, ts.Y * 0.12, tFront - 0.17 * s) * CFrame.Angles(0, x * 0.12, 0), bone, Enum.Material.Slate)
			end
			stick(torso, "Carapace", Vector3.new(ts.X * 0.85, ts.Y * 0.75, 0.3 * s), CFrame.new(0, ts.Y * 0.05, ts.Z / 2 + 0.12 * s), bone, Enum.Material.Slate)
			for _, arm in arms do
				stick(arm, "Guard", Vector3.new(arm.Size.X + 0.14 * s, arm.Size.Y * 0.55, arm.Size.Z * 0.45), CFrame.new(0, arm.Size.Y * 0.3, -arm.Size.Z * 0.16), bone, Enum.Material.Slate)
				stick(arm, "Spike", Vector3.new(0.18, 0.6, 0.18) * s, CFrame.new(0, arm.Size.Y * 0.55 + 0.25 * s, -arm.Size.Z * 0.16) * CFrame.Angles(-0.4, 0, 0), bone)
			end
			for i, leg in legs do
				stick(leg, "Guard", Vector3.new(leg.Size.X * 0.8, leg.Size.Y * 0.32, 0.18 * s), CFrame.new(0, -leg.Size.Y * 0.2, -leg.Size.Z / 2 - 0.08 * s), bone, Enum.Material.Slate)
				if i == 2 then -- bone breaking out through the knee
					stick(leg, "KneeBone", Vector3.new(0.3, 0.6, 0.3) * s, CFrame.new(leg.Size.X * 0.2, leg.Size.Y * 0.18, -leg.Size.Z / 2 - 0.12 * s) * CFrame.Angles(0.5, 0, 0.2), bone)
				end
			end
			-- tusks up out of the corners of the mouth
			for _, x in { -1, 1 } do
				stick(head, "HeadTusk", Vector3.new(0.14, 0.5, 0.14) * s, CFrame.new(x * 0.3 * s, -0.25 * s, hFront - 0.1 * s) * CFrame.Angles(-0.3, 0, -x * 0.2), bone)
			end
			stick(head, "HeadPlate", Vector3.new(hs.X + 0.12 * s, hs.Y * 0.32, hs.Z + 0.12 * s), CFrame.new(0, hs.Y * 0.36, 0), bone, Enum.Material.Slate)
			for _, x in { -1, 1 } do
				stick(head, "HeadHorn", Vector3.new(0.24, 1, 0.24) * s, CFrame.new(x * hs.X * 0.38, hs.Y * 0.66, 0.1 * s) * CFrame.Angles(0.3, 0, -x * 0.5), bone)
			end
		else -- a half: raw where it tore from the other one
			stick(torso, "RawSide", Vector3.new(0.05 * s, ts.Y * 0.9, ts.Z * 0.9), CFrame.new(ts.X / 2 + 0.03 * s, 0, 0), GORE)
			stick(head, "HeadRaw", Vector3.new(0.05 * s, hs.Y * 0.8, hs.Z * 0.8), CFrame.new(hs.X / 2 + 0.03 * s, 0, 0), GORE)
		end
	elseif kind == "Wailer" then
		torso.Color = look.Skin -- bare-chested
		torso.Material = Enum.Material.SmoothPlastic
		-- a rag of shirt hanging off one shoulder
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		stick(torso, "Rag", Vector3.new(ts.X * 0.55, ts.Y * 0.75, ts.Z + 0.12 * s), CFrame.new(side * ts.X * 0.3, ts.Y * 0.1, 0) * CFrame.Angles(0, 0, side * 0.12), pick(rng, look.Shirts), Enum.Material.Fabric)
		-- gore down the chest from the mouth
		stick(torso, "Gore", Vector3.new(ts.X * 0.34, ts.Y * 0.7, 0.05 * s), CFrame.new(-side * ts.X * 0.1, ts.Y * 0.12, tFront - 0.03 * s), GORE)
		ribcage(4)
		-- the scream: the mouth stretched down the face, rows of teeth, the jaw dropped wide
		for _, p in model:GetChildren() do
			if p.Name == "HeadHair" or p.Name == "HeadTooth" then
				p:Destroy() -- bald, blotched scalp; new teeth below
			elseif p.Name == "HeadMouth" then
				p.Size = Vector3.new(0.58, 0.72, 0.06) * s
				local weld = p:FindFirstChildOfClass("Weld")
				weld.C0 = CFrame.new(0, -0.4 * s, weld.C0.Position.Z) -- lower, clear of the eyes
				dripY = -0.76 * s
			end
		end
		for i = 1, 5 do -- the upper teeth hang from the top of the stretched mouth
			local th = rng:NextNumber(0.12, 0.2) * s
			stick(head, "HeadTooth", Vector3.new(0.08 * s, th, 0.05 * s), CFrame.new((i - 3) * 0.1 * s, -0.04 * s - th / 2, hFront - 0.075 * s), ROT_TEETH)
		end
		jaw(0.8, 0.62, 4)
		lesions(head, 4)
		for _, arm in arms do
			lesions(arm, 2)
			stick(arm, "Gore", Vector3.new(arm.Size.X + 0.03 * s, arm.Size.Y * 0.5, arm.Size.Z * 0.18), CFrame.new(0, -arm.Size.Y * 0.1, -arm.Size.Z * 0.38), GORE)
		end
		-- the scream organ: a pale glowing sac in the throat (ZombieService Wail)
		local sac = neon(stick(torso, "Throat", Vector3.one * 0.36 * s, CFrame.new(0, ts.Y / 2 - 0.3 * s, tFront - 0.06 * s), Color3.fromRGB(90, 190, 255)))
		sac.Shape = Enum.PartType.Ball
		sac.Transparency = 0.25
		bareFeet()
	elseif kind == "Bloom" then
		local POD = Color3.fromRGB(150, 255, 60)
		local FLESH = look.Skin:Lerp(Color3.fromRGB(70, 92, 40), 0.45)
		local FUNGUS = Color3.fromRGB(150, 110, 70)
		torso.Color = look.Skin -- bare, swollen
		torso.Material = Enum.Material.SmoothPlastic
		-- the spore sac: a huge bulb on its back studded with glowing pods
		local sacR = ts.X * 0.55
		local sac = stick(torso, "SporeSac", Vector3.one * sacR * 2, CFrame.new(0, ts.Y * 0.25, ts.Z * 0.5 + sacR * 0.45), FLESH)
		sac.Shape = Enum.PartType.Ball
		-- a glowing pod bulging out of a darker fleshy cup, pushed out along dir
		local function pod(base, pos, dir, d)
			local cup = stick(base, "PodCup", Vector3.one * d * 1.25, CFrame.new(pos), FLESH:Lerp(Color3.new(), 0.25))
			cup.Shape = Enum.PartType.Ball
			local p = neon(stick(base, "Pod", Vector3.one * d, CFrame.new(pos + dir * d * 0.3), POD))
			p.Shape = Enum.PartType.Ball
		end
		for _ = 1, 11 do -- pods over the back half of the sac
			local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.4, 1), rng:NextNumber(0.1, 1)).Unit
			pod(sac, dir * sacR * 0.92, dir, rng:NextNumber(0.35, 0.75) * s)
		end
		for _, x in { -0.38, 0.38 } do -- and bursting out of its shoulders
			pod(torso, Vector3.new(x * ts.X, ts.Y * rng:NextNumber(0.3, 0.45), tFront * 0.8), Vector3.new(x, 0.5, -1).Unit, rng:NextNumber(0.35, 0.5) * s)
		end
		-- the belly is split open down the middle: a dark wet maw lined with teeth, a glowing core inside
		for _, p in model:GetChildren() do
			if p.Name == "Pustule" then
				p.Color = POD -- the Bloated build's pustules, greener
			end
		end
		local bellyZ = -ts.Z * 0.63
		local mawW, mawH = ts.X * 0.3, ts.Y * 0.5
		stick(torso, "Maw", Vector3.new(mawW + 0.3 * s, mawH + 0.3 * s, 0.06 * s), CFrame.new(0, -ts.Y * 0.1, bellyZ - 0.02 * s), GORE)
		stick(torso, "Maw", Vector3.new(mawW, mawH, 0.06 * s), CFrame.new(0, -ts.Y * 0.1, bellyZ - 0.06 * s), SOCKET)
		local core = neon(stick(torso, "Core", Vector3.new(mawW * 0.55, mawH * 0.55, mawW * 0.55), CFrame.new(0, -ts.Y * 0.1, bellyZ - 0.08 * s), POD))
		core.Shape = Enum.PartType.Ball
		for k = 1, 5 do -- fangs down both lips, pointing in
			local y = -ts.Y * 0.1 + (k - 3) * mawH * 0.2
			for _, side in { -1, 1 } do
				local len = rng:NextNumber(0.3, 0.5) * s
				stick(torso, "Fang", Vector3.new(len, 0.12 * s, 0.1 * s), CFrame.new(side * (mawW / 2 - len * 0.3), y, bellyZ - 0.11 * s) * CFrame.Angles(0, 0, side * rng:NextNumber(-0.25, 0.25)), ROT_TEETH)
			end
		end
		-- shelf fungus growing out of the shoulders and arms
		for i = 1, 4 do
			local base = if i <= 2 then torso else arms[i - 2]
			local x = if i <= 2 then (if i == 1 then -1 else 1) * ts.X * 0.5 else 0
			local y = if i <= 2 then ts.Y * 0.35 else base.Size.Y * 0.5
			local cap = stick(base, "Fungus", Vector3.new(0.18 * s, 0.9 * s, 0.9 * s), CFrame.new(x, y, 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, 0), FUNGUS, Enum.Material.Sand)
			cap.Shape = Enum.PartType.Cylinder
		end
		-- a cluster of extra glowing eyes and a gaping maw with tendrils hanging from it
		for _, p in model:GetChildren() do
			if p.Name == "HeadHair" or p.Name == "HeadTooth" then
				p:Destroy()
			elseif p.Name == "HeadMouth" then
				p.Size = Vector3.new(0.7, 0.62, 0.06) * s
				local weld = p:FindFirstChildOfClass("Weld")
				weld.C0 = CFrame.new(0, -0.32 * s, weld.C0.Position.Z)
				dripY = -0.63 * s
			end
		end
		-- its own eyes are dark pits with a pinprick glow; a cluster of small eyes has grown in over the brow
		for _, p in model:GetChildren() do
			if p.Name == "HeadBrow" then
				p:Destroy()
			elseif p.Name == "Eye" then
				p.Color = SOCKET
				p.Material = Enum.Material.SmoothPlastic
				p.Size = Vector3.new(0.34, 0.3, 0.06) * s
				neon(stick(head, "Eye", Vector3.new(0.08, 0.08, 0.04) * s, p:FindFirstChildOfClass("Weld").C0 * CFrame.new(0, 0, -0.04 * s), look.Eyes))
			end
		end
		for _, e in { Vector3.new(0, 0.45, 0), Vector3.new(-0.14, 0.36, 0), Vector3.new(0.17, 0.4, 0), Vector3.new(0.3, 0.5, 0), Vector3.new(-0.33, 0.47, 0), Vector3.new(0.05, 0.56, 0) } do
			local d = rng:NextNumber(0.07, 0.12) * s
			neon(stick(head, "Eye", Vector3.new(d, d, 0.05 * s), CFrame.new(e.X * s, e.Y * s, hFront - 0.03 * s), look.Eyes))
		end
		for i = 1, 6 do
			local th = rng:NextNumber(0.12, 0.22) * s
			stick(head, "HeadTooth", Vector3.new(0.08 * s, th, 0.05 * s), CFrame.new((i - 3.5) * 0.1 * s, -0.04 * s - th / 2, hFront - 0.075 * s), ROT_TEETH)
		end
		jaw(0.9, 0.7, 5)
		for i = 1, 4 do
			local len = rng:NextNumber(0.6, 1.3) * s
			stick(head, "HeadTendril", Vector3.new(0.09 * s, len, 0.09 * s), CFrame.new((i - 2.5) * 0.16 * s, -hs.Y / 2 - len / 2 + 0.1 * s, hFront - 0.2 * s) * CFrame.Angles(rng:NextNumber(-0.3, 0.1), 0, rng:NextNumber(-0.2, 0.2)), FLESH)
		end
		local growth = stick(head, "HeadPod", Vector3.one * 0.5 * s, CFrame.new(hs.X * 0.42, hs.Y * 0.45, 0), FLESH)
		growth.Shape = Enum.PartType.Ball
		for _, arm in arms do
			lesions(arm, 3)
			for k = 1, 2 do -- tendrils trailing off the forearms
				local len = rng:NextNumber(0.6, 1.1) * s
				stick(arm, "Tendril", Vector3.new(0.08 * s, len, 0.08 * s), CFrame.new((k - 1.5) * arm.Size.X * 0.4, -arm.Size.Y / 2 - len / 2 + 0.05 * s, -arm.Size.Z * 0.3), FLESH)
			end
		end
		lesions(head, 3)
		-- spores drifting off it, and a sick green glow from the sac
		local spores = Instance.new("ParticleEmitter")
		spores.Name = "Spores"
		spores.Texture = "rbxasset://textures/particles/smoke_main.dds"
		spores.Color = ColorSequence.new(Color3.fromRGB(200, 240, 110), Color3.fromRGB(120, 150, 70))
		spores.LightEmission = 0.4
		spores.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.7), NumberSequenceKeypoint.new(1, 1) })
		spores.Size = NumberSequence.new(1.2 * s, 3 * s)
		spores.Lifetime = NumberRange.new(3, 5)
		spores.Rate = 10
		spores.Speed = NumberRange.new(1, 3)
		spores.SpreadAngle = Vector2.new(60, 60)
		spores.Acceleration = Vector3.new(0, 1.5, 0)
		spores.Parent = sac
		local glow = Instance.new("PointLight")
		glow.Color = POD
		glow.Range = 22
		glow.Brightness = 1.6
		glow.Parent = sac
		bareFeet()
	end
	-- blood drooling from the mouth
	if kind ~= "Husk" then
		for _ = 1, 2 do
			local len = rng:NextNumber(0.3, 0.7) * s
			stick(head, "HeadDrip", Vector3.new(0.07 * s, len, 0.05 * s), CFrame.new(rng:NextNumber(-0.22, 0.22) * s, dripY - len / 2, hFront - 0.045 * s), GORE)
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
	local torso = motor(newPart("Torso", torsoSize, shirt, Enum.Material.Fabric), CFrame.new(0, hip, 0), torsoCF)
	local neck = torsoCF * CFrame.new(0, torsoSize.Y / 2, 0)
	local head = motor(newPart("Head", (b.Head or Vector3.new(1.25, 1.25, 1.25)) * s, look.Skin), CFrame.new(neck.Position), neck * CFrame.Angles(b.HeadUp or 0, 0, 0) * CFrame.new(0, (if b.Head then b.Head.Y / 2 else 0.62) * s, 0) * CFrame.Angles(rng:NextNumber(-0.15, 0.1), 0, rng:NextNumber(-0.25, 0.25)))
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
		local limb = motor(newPart(side[1], arm, look.Skin), joint, joint * CFrame.Angles(-(b.ArmPitch or 0), 0, 0) * CFrame.new(0, 0, -arm.Z / 2 + 0.45 * s))
		local sleeve = if buildName == "Normal" or buildName == "Titan" then rng:NextNumber(0.25, 0.55) else 0
		if sleeve > 0 then -- torn sleeve near the shoulder
			-- 0.04 longer than the arm at the shoulder end: its end face must not share the arm's end plane
			-- (coplanar faces z-fight; it flickered at the shoulders)
			stick(limb, "Sleeve", Vector3.new(arm.X + 0.04, arm.Y + 0.04, arm.Z * sleeve + 0.04), CFrame.new(0, 0, arm.Z / 2 - arm.Z * sleeve / 2 + 0.02), shirt, Enum.Material.Fabric)
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
		-- shifted 0.035 outward: its inner side tucks 0.005 inside the leg, so the two shoes never overlap
		-- between the feet and it can't share a plane with the leg or the torn-shin patch; 0.02 lower so the
		-- sole doesn't share the leg's bottom plane (or the floor's). Coplanar overlapping faces z-fight.
		stick(limb, "Shoe", Vector3.new(leg.X + 0.06, 0.32 * s, leg.Z + 0.3 * s), CFrame.new(0.035 * side[2], -leg.Y / 2 + 0.16 * s - 0.02, -0.12 * s), SHOE)
	end

	horror(model, look, buildName, s, rng)

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
