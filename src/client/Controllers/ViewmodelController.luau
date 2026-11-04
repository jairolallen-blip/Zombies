-- ViewmodelController: the first-person gun + arms you see while CameraController:IsActive().
-- Builds a client-only copy of the equipped gun with GunModels.BuildTool (same model as the real
-- Tool), scales it down (GameConfig.Camera.ViewmodelScale), parents it to the camera and poses it
-- every frame in camera space. Two blocky arms (olive sleeves, skin forearms, dark gloves) reach
-- the grip and the handguard with a two-bone IK. The real third-person Tool is hidden LOCALLY only
-- (other players still see it).
--
-- Pose layers (update -> compose): hip / aim-down-sights blend, mouse sway, walk bob + breathing,
-- strafe tilt, jump/land bounce, recoil jolt, equip raise, wall tuck, reload (the mag really comes
-- out on guns that have one), grenade throw (right arm leaves the grip).
--
-- Public:
--   :GetMuzzle() / :GetEjectPort() -> Attachment? (nil when inactive)        (WeaponController)
--   :GetModel() -> Model? (has SpinHub/SpinWeld for spinning guns)
--   :Kick(recoilDegrees, fireRate?)                                    (WeaponController, per shot)
--   :GetAim() -> 0..1, :IsScoped() -> bool, :GetAimFieldOfView()        (Camera, Weapon, HUD)
--   :PlayReload(seconds)                                                (WeaponController:Reload)
--   :PlayThrow(windup, duration), :IsThrowing(), :GetThrowHand() -> Vector3?  (ThrowController)
--   ViewmodelController.Preview(camCF, weaponId, tier, pose) -- Edit-mode visual check (bottom)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Util = require(Shared.Util)
local GunModels = require(Shared.GunModels)

local Cam = GameConfig.Camera
local player = Players.LocalPlayer
local ViewmodelController = {}
local Controllers

-- Arm proportions (studs, camera space). Shoulders sit off-screen below/behind the eye.
local UPPER_LEN, FORE_LEN = 1.1, 1.05
local UPPER_W, FORE_W, CUFF_W = 0.3, 0.24, 0.34
local HAND_SIZE = Vector3.new(0.22, 0.24, 0.26)
local RIGHT_SHOULDER = Vector3.new(0.8, -1.15, 0.15)
local LEFT_SHOULDER = Vector3.new(-0.5, -1.25, -0.05)
local MAG_NAMES = { "Mag", "BoxMag", "Cell", "AmmoBox", "Drum" } -- parts that come out on a reload

-- Grenade throw hand path, camera space: ready -> cocked over the shoulder -> released -> down.
local THROW_READY = Vector3.new(0.45, -0.8, -0.9)
local THROW_COCKED = Vector3.new(0.55, 0.0, -0.85)
local THROW_SHOULDER = Vector3.new(1.25, -1.35, 0.55) -- further out/back so the elbow stays out of view
local THROW_RELEASE = Vector3.new(0.05, -0.25, -1.55)
local THROW_DOWN = Vector3.new(0.45, -1.6, -0.6)

local vm = nil -- the built viewmodel (see build)
local hiddenTool = nil
local aim = 0
local equipStart = 0
local reload = nil -- { Start, Duration }
local throw = nil -- { Start, Windup, Duration, Grenade, Hand }
local bobT = 0
local tuck = 0
local lastCamCF = nil
local wasGrounded = true
local airVelY = 0
local tuckParams = RaycastParams.new()
tuckParams.FilterType = Enum.RaycastFilterType.Exclude

-- Small damped spring (Vector3) for the bouncy layers.
local Spring = {}
Spring.__index = Spring
function Spring.new(stiffness, damping)
	return setmetatable({ P = Vector3.zero, V = Vector3.zero, K = stiffness, D = damping }, Spring)
end
function Spring:Step(target, dt)
	local steps = math.clamp(math.ceil(dt * 240), 1, 10)
	local h = dt / steps
	for _ = 1, steps do
		self.V += ((target - self.P) * self.K - self.V * self.D) * h
		self.P += self.V * h
	end
	return self.P
end
-- recoil springs: very stiff, nearly critically damped -- the gun slams back in ~30ms and is home
-- again in ~130ms (a hard punch with an instant snap back, no wobble)
local kickPos = Spring.new(900, 48)
local kickRot = Spring.new(950, 50)
local swayRot = Spring.new(120, 16)
local moveSpring = Spring.new(90, 13) -- strafe tilt, vertical lag, landing dip

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- World-axis half extents of a part (works for rotated cylinders too).
local function extents(p)
	local cf, h = p.CFrame, p.Size / 2
	local x, y, z = cf.XVector * h.X, cf.YVector * h.Y, cf.ZVector * h.Z
	return Vector3.new(
		math.abs(x.X) + math.abs(y.X) + math.abs(z.X),
		math.abs(x.Y) + math.abs(y.Y) + math.abs(z.Y),
		math.abs(x.Z) + math.abs(y.Z) + math.abs(z.Z)
	)
end

function ViewmodelController:GetMuzzle()
	return if vm then vm.Muzzle else nil
end

function ViewmodelController:GetEjectPort()
	return if vm then vm.Eject else nil
end

function ViewmodelController:GetModel()
	return if vm then vm.Model else nil
end

function ViewmodelController:GetAim()
	return aim
end

function ViewmodelController:IsScoped()
	return vm ~= nil and vm.Scoped and aim > 0.85
end

function ViewmodelController:GetAimFieldOfView()
	return if vm and vm.Scoped then Cam.ScopeFieldOfView else Cam.AimFieldOfView
end

-- Visual recoil (aim is unaffected: shots come from the camera). sqrt keeps big guns from going wild;
-- fast-firing guns get smaller kicks per shot so a spray stays a steady shudder, not a drift.
function ViewmodelController:Kick(recoilDegrees, fireRate)
	local k = (0.6 + math.sqrt(recoilDegrees or 1) * 0.55) * Cam.ViewmodelKick
	k *= math.clamp(5 / (fireRate or 5), 0.3, 1)
	kickPos.V += Vector3.new((math.random() - 0.5) * 0.12, 0.16, 1.5) * k
	kickRot.V += Vector3.new(0.95, (math.random() - 0.5) * 0.4, (math.random() - 0.5) * 0.9) * k
end

function ViewmodelController:PlayReload(seconds)
	if vm then
		reload = { Start = os.clock(), Duration = math.max(seconds, 0.4) }
	end
end

function ViewmodelController:IsThrowing()
	return throw ~= nil
end

function ViewmodelController:GetThrowHand()
	return if throw then throw.Hand else nil
end

function ViewmodelController:PlayThrow(windup, duration)
	if throw and throw.Grenade then
		throw.Grenade:Destroy()
	end
	throw = { Start = os.clock(), Windup = windup, Duration = duration }
	if vm and Controllers and Controllers.ThrowController then
		throw.Grenade = Controllers.ThrowController.MakeGrenade(vm.Model)
		throw.Grenade:ScaleTo(0.42) -- hand-sized next to the eye
	end
end

local function newPart(parent, name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function skinColor()
	local character = player and player.Character
	local part = character and (character:FindFirstChild("RightLowerArm") or character:FindFirstChild("Right Arm") or character:FindFirstChild("Head"))
	return if part then part.Color else Color3.fromRGB(234, 184, 146)
end

local function destroyModel()
	if vm then
		vm.Model:Destroy()
	end
	vm = nil
	reload = nil
	if throw then
		throw.Grenade = nil -- was parented to the model
	end
end

local function build(weaponId, tier, parent)
	destroyModel()
	local s = Cam.ViewmodelScale
	local stats = Util.GetWeaponStats(weaponId, tier)
	local tool = GunModels.BuildTool(stats)
	local model = Instance.new("Model")
	model.Name = "SAMZ_Viewmodel"
	for _, child in tool:GetChildren() do
		child.Parent = model
	end
	tool:Destroy()
	local handle = model:FindFirstChild("Handle")
	handle.Anchored = true -- everything else is welded to it (or to the spin hub)
	model.PrimaryPart = handle
	model:PivotTo(CFrame.new())
	model:ScaleTo(s)
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CastShadow = false
			d.CanQuery = false
			d.CanCollide = false
			d.CanTouch = false
			table.insert(parts, d)
		end
	end
	local hub = model:FindFirstChild("SpinHub")
	local spinWeld = hub and hub:FindFirstChild("SpinWeld")
	if spinWeld then
		hub:SetAttribute("BaseC0", spinWeld.C0) -- WeaponController spins the barrels from this
	end

	-- Measurements in gun space (the handle sits at the origin, barrel along -Z).
	local muzzle = handle:FindFirstChild("Muzzle")
	local muzzleZ = if muzzle then muzzle.Position.Z else -1.5 * s
	local scope = model:FindFirstChild("Scope")
	local top = 0
	for _, p in parts do
		top = math.max(top, p.Position.Y + extents(p).Y)
	end
	local pistol = muzzleZ > -1.4 * s
	local support
	if pistol then
		support = Vector3.new(-0.15 * s, -0.04 * s, 0.05 * s) -- left hand wraps the grip
	else
		local supportZ = muzzleZ * 0.55
		local bottom = math.huge
		for _, p in parts do
			if p ~= handle and not table.find(MAG_NAMES, p.Name) then
				local e = extents(p)
				if math.abs(p.Position.Z - supportZ) <= e.Z then
					bottom = math.min(bottom, p.Position.Y - e.Y)
				end
			end
		end
		support = Vector3.new(0, (if bottom < math.huge then bottom else 0.3 * s) - HAND_SIZE.Y * 0.4, supportZ)
	end
	local mag, magWeld
	for _, name in MAG_NAMES do
		mag = mag or model:FindFirstChild(name)
	end
	if mag then
		for _, d in model:GetDescendants() do
			if d:IsA("JointInstance") and (d.Part0 == mag or d.Part1 == mag) then
				magWeld = d
			end
		end
	end

	-- Arms: sleeve (olive, rolled up), cuff, skin forearm, gloved hand.
	local skin = skinColor()
	local arms = {}
	for _, side in { "R", "L" } do
		arms[side .. "Upper"] = newPart(model, side .. "UpperArm", Vector3.new(UPPER_W, UPPER_W, UPPER_LEN), Cam.SleeveColor, Enum.Material.Fabric)
		arms[side .. "Cuff"] = newPart(model, side .. "Cuff", Vector3.new(CUFF_W, CUFF_W, 0.16), Cam.SleeveColor:Lerp(Color3.new(), 0.18), Enum.Material.Fabric)
		arms[side .. "Fore"] = newPart(model, side .. "Forearm", Vector3.new(FORE_W, FORE_W, FORE_LEN), skin)
		arms[side .. "Hand"] = newPart(model, side .. "Hand", HAND_SIZE, Cam.GloveColor)
	end
	for _, p in arms do
		table.insert(parts, p)
	end
	model.Parent = parent
	vm = {
		Model = model,
		Handle = handle,
		Muzzle = muzzle,
		Eject = handle:FindFirstChild("EjectPort"),
		Key = weaponId .. "#" .. tier,
		SightY = if scope then scope.Position.Y else top + 0.03,
		Scoped = scope ~= nil,
		Pistol = pistol,
		Support = support,
		Mag = mag,
		MagWeld = magWeld,
		MagRel = mag and mag.CFrame, -- gun-space seat of the mag
		MagHalf = mag and extents(mag).Y,
		MagOut = false,
		Arms = arms,
		Parts = parts,
		Hidden = false,
		RightHand = CFrame.new(),
	}
	equipStart = os.clock()
	return vm
end

-- Two-bone arm: shoulder -> elbow -> hand, elbow bent toward `pole`. If the hand is out of reach
-- the shoulder slides toward it (it is off-screen anyway).
local function solveArm(side, shoulder, hand, pole)
	local arms = vm.Arms
	local total = UPPER_LEN + FORE_LEN
	local toHand = hand - shoulder
	local d = toHand.Magnitude
	if d < 1e-3 then
		return
	end
	local dir = toHand / d
	if d > total * 0.995 then
		shoulder = hand - dir * total * 0.995
		d = total * 0.995
	end
	local a = (UPPER_LEN * UPPER_LEN - FORE_LEN * FORE_LEN + d * d) / (2 * d)
	local h = math.sqrt(math.max(UPPER_LEN * UPPER_LEN - a * a, 0))
	local bend = pole - dir * pole:Dot(dir)
	bend = if bend.Magnitude > 1e-3 then bend.Unit else -Vector3.yAxis
	local elbow = shoulder + dir * a + bend * h
	arms[side .. "Upper"].CFrame = CFrame.lookAt((shoulder + elbow) / 2, elbow)
	arms[side .. "Cuff"].CFrame = CFrame.lookAt(elbow, shoulder) * CFrame.new(0, 0, -0.1)
	local fore = arms[side .. "Fore"]
	fore.Size = Vector3.new(FORE_W, FORE_W, (hand - elbow).Magnitude)
	fore.CFrame = CFrame.lookAt((elbow + hand) / 2, hand)
end

local function throwPose(t, windup, duration)
	local swing = 0.16
	local hand
	if t < windup then
		local a = t / windup
		hand = if a < 0.3 then THROW_DOWN:Lerp(THROW_READY, smooth(a / 0.3)) else THROW_READY:Lerp(THROW_COCKED, smooth((a - 0.3) / 0.7))
	elseif t < windup + swing then
		hand = THROW_COCKED:Lerp(THROW_RELEASE, 1 - (1 - (t - windup) / swing) ^ 3)
	else
		hand = THROW_RELEASE:Lerp(THROW_DOWN, smooth((t - windup - swing) / math.max(duration - windup - swing, 0.05)))
	end
	local dip = math.min(1, t / 0.1) * math.clamp((duration - t) / 0.2, 0, 1)
	return hand, smooth(dip)
end

-- Mag swap: hand to the mag, mag drops out of view, a new one comes up and seats, hand returns.
local function magReload(u, gunCF, camCF, supportCF)
	local attached = gunCF * vm.MagRel
	local grab = attached * CFrame.new(0, -vm.MagHalf, 0)
	local drop = CFrame.new((camCF * CFrame.new(0.05, -1.35, -0.9)).Position) * attached.Rotation
	local below = attached * CFrame.new(0, -0.35, 0.05)
	local magCF, seated = attached, true
	if u < 0.16 then
		return attached, supportCF:Lerp(grab, smooth(u / 0.16)), true
	elseif u < 0.36 then
		magCF, seated = attached:Lerp(drop, smooth((u - 0.16) / 0.2)), false
	elseif u < 0.5 then
		magCF, seated = drop, false
	elseif u < 0.68 then
		magCF, seated = drop:Lerp(below, smooth((u - 0.5) / 0.18)), false
	elseif u < 0.76 then
		magCF, seated = below:Lerp(attached, smooth((u - 0.68) / 0.08)), false
	else
		return attached, grab:Lerp(supportCF, smooth((u - 0.76) / 0.2)), true
	end
	return magCF, magCF * CFrame.new(0, -vm.MagHalf, 0), seated
end

local function setMag(seated, cf)
	local mag = vm.Mag
	if not mag then
		return
	end
	if seated then
		if vm.MagOut then
			mag.Anchored = false
			if vm.MagWeld then
				vm.MagWeld.Enabled = true
			end
			vm.MagOut = false
		end
	else
		if not vm.MagOut then
			if vm.MagWeld then
				vm.MagWeld.Enabled = false
			end
			mag.Anchored = true
			vm.MagOut = true
		end
		mag.CFrame = cf
	end
end

-- Pose everything for one frame. st = { Offset, Rot, Aim, Equip, Tuck, ReloadU?, ThrowT?, ThrowWindup, ThrowDuration }
local function compose(camCF, st)
	local s = Cam.ViewmodelScale
	local hip = CFrame.new(Cam.ViewmodelOffset) * CFrame.Angles(0, math.rad(Cam.ViewmodelYaw), 0)
	local ads = CFrame.new(0, -vm.SightY, Cam.AimDistance)
	local base = hip:Lerp(ads, smooth(st.Aim))
	local tilt = if st.ReloadU then smooth(st.ReloadU / 0.14) * (1 - smooth((st.ReloadU - 0.82) / 0.16)) else 0
	local throwHand, dip = nil, 0
	if st.ThrowT then
		throwHand, dip = throwPose(st.ThrowT, st.ThrowWindup, st.ThrowDuration)
	end
	local lower = (1 - st.Equip) ^ 2
	local tk = st.Tuck
	local pos = st.Offset
		+ Vector3.new(-0.12, 0.14, 0.05) * tilt
		+ Vector3.new(-0.18, -0.3, 0.12) * dip
		+ Vector3.new(0.05, -0.6, 0.1) * lower
		+ Vector3.new(0.02, -0.08, 0.35) * tk
	local rot = st.Rot
		+ Vector3.new(0.2, 0.1, 0.42) * tilt
		+ Vector3.new(-0.4, 0.05, 0.35) * dip
		+ Vector3.new(-0.9, 0.3, 0.2) * lower
		+ Vector3.new(0.55, 0.45, 0.1) * tk
	local gunCF = camCF * CFrame.new(pos) * base * CFrame.Angles(rot.X, rot.Y, rot.Z)
	vm.Handle.CFrame = gunCF

	local rShoulder = (camCF * CFrame.new(RIGHT_SHOULDER)).Position
	local lShoulder = (camCF * CFrame.new(LEFT_SHOULDER)).Position
	local rightPole = camCF:VectorToWorldSpace(Vector3.new(0.7, -1, 0.1))
	local leftPole = camCF:VectorToWorldSpace(Vector3.new(-0.8, -1, 0.1))

	-- right hand: on the grip, or throwing the grenade
	local rightHand
	if throwHand then
		rShoulder = (camCF * CFrame.new(THROW_SHOULDER)).Position
		rightPole = camCF:VectorToWorldSpace(Vector3.new(1, -0.8, 0.9))
		local p = (camCF * CFrame.new(throwHand)).Position
		rightHand = CFrame.lookAt(p, p + (p - rShoulder))
	else
		rightHand = gunCF * CFrame.new(0, 0.03 * s, 0.03 * s)
	end
	vm.RightHand = rightHand

	-- left hand: under the handguard (or wrapping a pistol grip), busy during a reload
	local supportCF = gunCF * CFrame.new(vm.Support)
	local leftHand = supportCF
	if st.ReloadU and vm.Mag then
		local magCF, handCF, seated = magReload(st.ReloadU, gunCF, camCF, supportCF)
		setMag(seated, magCF)
		leftHand = handCF
	else
		setMag(true)
		if st.ReloadU then
			-- no mag (shotgun, revolver): the hand works at the receiver, loading
			local u = st.ReloadU
			local load = gunCF * CFrame.new(0.12 * s, 0.2 * s, -0.4 * s)
			local w = smooth((u - 0.1) / 0.1) * (1 - smooth((u - 0.78) / 0.12))
			leftHand = supportCF:Lerp(load * CFrame.new(0, 0, math.sin(u * math.pi * 8) * 0.05), w)
		end
	end
	local arms = vm.Arms
	arms.RHand.CFrame = rightHand
	arms.LHand.CFrame = leftHand
	solveArm("R", rShoulder, rightHand.Position, rightPole)
	solveArm("L", lShoulder, leftHand.Position, leftPole)
end

local function setHidden(hidden)
	if vm.Hidden == hidden then
		return
	end
	vm.Hidden = hidden
	for _, p in vm.Parts do
		p.LocalTransparencyModifier = if hidden then 1 else 0
	end
end

local function setToolHidden(tool, hidden)
	if not tool then
		return
	end
	for _, d in tool:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

local function update(dt)
	dt = math.min(dt, 0.1)
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local active = Controllers.CameraController:IsActive() and tool ~= nil
	-- hide the real tool locally while first person is on; restore it otherwise
	if hiddenTool and hiddenTool ~= tool then
		setToolHidden(hiddenTool, false)
		hiddenTool = nil
	end
	if not active then
		if hiddenTool then
			setToolHidden(hiddenTool, false)
			hiddenTool = nil
		end
		if vm then
			destroyModel()
		end
		aim, lastCamCF = 0, nil
		return
	end
	setToolHidden(tool, true)
	hiddenTool = tool

	local weaponId = tool:GetAttribute("WeaponId") or player:GetAttribute("WeaponId")
	local tier = player:GetAttribute("WeaponTier") or 1
	if not weaponId then
		return
	end
	if not vm or vm.Key ~= weaponId .. "#" .. tier or not vm.Model.Parent then
		build(weaponId, tier, workspace.CurrentCamera)
		Controllers.SoundController:Play("Equip")
	end

	local now = os.clock()
	local camera = workspace.CurrentCamera
	local camCF = camera.CFrame
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	local reloadU = reload and (now - reload.Start) / reload.Duration
	if reloadU and reloadU >= 1 then
		reload, reloadU = nil, nil
	end
	local throwT = throw and now - throw.Start
	if throw and throwT >= throw.Duration then
		if throw.Grenade then
			throw.Grenade:Destroy()
		end
		throw, throwT = nil, nil
	end

	-- aim down sights
	local wantAim = Controllers.WeaponController:IsAimHeld() and not reloadU and not throwT and humanoid ~= nil and humanoid.Health > 0
	aim += ((if wantAim then 1 else 0) - aim) * math.min(1, dt * Cam.AimSpeed)
	if aim < 0.002 then
		aim = 0
	end
	local free = 1 - 0.85 * aim -- how much sway/bob survives while aiming

	-- sway: the gun lags behind quick camera turns (normalised to 60 fps)
	local swayTarget = Vector3.zero
	if lastCamCF then
		local rx, ry = lastCamCF:ToObjectSpace(camCF):ToEulerAnglesYXZ()
		local f = 1 / math.max(dt * 60, 0.25)
		swayTarget = Vector3.new(math.clamp(-rx * f * 1.5, -0.1, 0.1), math.clamp(-ry * f * 1.5, -0.1, 0.1), math.clamp(-ry * f, -0.08, 0.08))
	end
	lastCamCF = camCF
	swayRot:Step(swayTarget, dt)

	-- walk bob, breathing, strafe tilt, vertical lag, landing dip
	local vel = if root then root.AssemblyLinearVelocity else Vector3.zero
	local grounded = humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air
	local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local moveAmt = if grounded then math.clamp(speed / 16, 0, 1.4) else 0
	bobT += dt * (4 + 7 * moveAmt)
	local bobPos = Vector3.new(math.sin(bobT) * 0.028, -math.abs(math.cos(bobT)) * 0.024, 0) * moveAmt
		+ Vector3.new(0, math.sin(now * 1.7) * 0.005, 0)
	local bobRot = Vector3.new(0, 0, math.sin(bobT) * 0.025 * moveAmt)
	if not grounded then
		airVelY = vel.Y
	elseif not wasGrounded then
		moveSpring.V += Vector3.new(0, -1.8 * math.clamp(-airVelY / 60, 0.25, 1), 0)
	end
	wasGrounded = grounded
	local localVel = camCF:VectorToObjectSpace(vel)
	local mv = moveSpring:Step(Vector3.new(-localVel.X * 0.003, math.clamp(-vel.Y * 0.004, -0.09, 0.09), 0), dt)

	kickPos:Step(Vector3.zero, dt)
	kickRot:Step(Vector3.zero, dt)

	-- wall tuck: pull the gun back and up when something is right in front of you
	local tuckTarget = 0
	if aim < 0.5 then
		local filter = { character, camera }
		for _, name in { "Effects", "ClientEffects", "Zombies" } do
			local f = workspace:FindFirstChild(name)
			if f then
				table.insert(filter, f)
			end
		end
		tuckParams.FilterDescendantsInstances = filter
		local hit = workspace:Raycast(camCF.Position, camCF.LookVector * 2.2, tuckParams)
		tuckTarget = if hit then math.clamp(1 - (hit.Distance - 0.6) / 1.6, 0, 1) else 0
	end
	tuck += (tuckTarget - tuck) * math.min(1, dt * 12)

	local sway = swayRot.P
	compose(camCF, {
		Offset = (bobPos + Vector3.new(mv.X - sway.Y * 0.25, mv.Y + sway.X * 0.25, 0)) * free + kickPos.P * (1 - 0.25 * aim),
		Rot = (sway + bobRot + Vector3.new(0, 0, mv.X * 2.5)) * free + kickRot.P * (1 - 0.3 * aim),
		Aim = aim,
		Equip = smooth((now - equipStart) / 0.4),
		Tuck = tuck,
		ReloadU = reloadU,
		ThrowT = throwT,
		ThrowWindup = throw and throw.Windup,
		ThrowDuration = throw and throw.Duration,
	})
	if throw then
		throw.Hand = vm.RightHand.Position
		if throw.Grenade then
			if throwT < throw.Windup then
				throw.Grenade:PivotTo(vm.RightHand * CFrame.new(0, 0.06, -0.2))
			else
				throw.Grenade:Destroy() -- released: the Projectile effect takes over from here
				throw.Grenade = nil
			end
		end
	end
	setHidden(ViewmodelController:IsScoped()) -- the scope overlay replaces the gun
end

function ViewmodelController:Init(controllers)
	Controllers = controllers
	-- after the camera + recoil (Camera+3), so the gun sits exactly where the view ends up
	RunService:BindToRenderStep("SAMZ_Viewmodel", Enum.RenderPriority.Camera.Value + 4, update)
	player.CharacterRemoving:Connect(destroyModel)
end

-- Edit-mode visual check (MCP execute_luau, Edit). Clone the module first (the command bar caches
-- modules), then screen_capture from the same eye position:
--   local VM = require(clone)
--   VM.Preview(CFrame.lookAt(eye, target), "AssaultRifle", 3, { Aim = 0, ReloadU = 0.3, ThrowT = 0.2, Tuck = 0, Equip = 1 })
-- Builds Workspace.__VMPreview (delete it afterwards).
function ViewmodelController.Preview(camCF, weaponId, tier, pose)
	pose = pose or {}
	local old = workspace:FindFirstChild("__VMPreview")
	if old then
		old:Destroy()
	end
	vm = nil
	build(weaponId, tier or 1, workspace)
	vm.Model.Name = "__VMPreview"
	compose(camCF, {
		Offset = Vector3.zero,
		Rot = Vector3.zero,
		Aim = pose.Aim or 0,
		Equip = pose.Equip or 1,
		Tuck = pose.Tuck or 0,
		ReloadU = pose.ReloadU,
		ThrowT = pose.ThrowT,
		ThrowWindup = 0.32,
		ThrowDuration = 0.8,
	})
	local model = vm.Model
	vm = nil
	return model
end

return ViewmodelController
