-- ViewmodelController: the first-person gun + arms you see while CameraController:IsActive().
-- Builds a client-only copy of the equipped gun with GunModels.BuildTool (same model as the real
-- Tool), parents it to the camera, and positions it every frame in camera space
-- (GameConfig.Camera.ViewmodelOffset) with recoil jolt, mouse sway and walk bob. Two blocky arms
-- (character arm colours) reach the grip and the barrel. The real third-person Tool is hidden
-- LOCALLY only (other players still see it).
--
-- Public (used by WeaponController):
--   ViewmodelController:GetMuzzle()   -> Attachment? (viewmodel Handle.Muzzle; nil when inactive)
--   ViewmodelController:GetEjectPort() -> Attachment?
--   ViewmodelController:GetModel()    -> Model? (has SpinHub/SpinWeld for spinning guns)
--   ViewmodelController:Kick(recoilDegrees)
-- Public (used by ThrowController / WeaponController):
--   ViewmodelController:PlayThrow(windup, duration) -- gun dips, right arm throws a grenade
--   ViewmodelController:IsThrowing() -> bool (firing is blocked meanwhile)
--   ViewmodelController:GetThrowHand() -> Vector3? (grenade hand while throwing, for the projectile)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Util = require(Shared.Util)
local GunModels = require(Shared.GunModels)

local player = Players.LocalPlayer
local ViewmodelController = {}
local Controllers

local model = nil -- Model under the camera
local handle = nil
local muzzle, ejectPort = nil, nil
local arms = {}
local builtKey = nil -- WeaponId..tier the model was built for
local kick = 0 -- current jolt (0..1+), decays
local sway = Vector2.zero
local bobT = 0
local hiddenTool = nil
local throw = nil -- { Start, Windup, Duration, Grenade, Hand }

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Throwing hand path in camera space: low ready -> cocked over the right shoulder -> snapped
-- forward at release (Windup) -> drops out of view. Returns hand offset, gun dip (0..1).
local THROW_READY = Vector3.new(0.7, -1.6, -1.2)
local THROW_COCKED = Vector3.new(1.0, 0.35, 0.3)
local THROW_RELEASE = Vector3.new(0.15, -0.5, -2.4)
local THROW_DOWN = Vector3.new(0.8, -2.8, -0.8)
local function throwPose(t, windup, duration)
	local swing = 0.16
	local hand
	if t < windup then
		local a = t / windup
		hand = if a < 0.3 then THROW_DOWN:Lerp(THROW_READY, smooth(a / 0.3)) else THROW_READY:Lerp(THROW_COCKED, smooth((a - 0.3) / 0.7))
	elseif t < windup + swing then
		local a = (t - windup) / swing
		hand = THROW_COCKED:Lerp(THROW_RELEASE, 1 - (1 - a) ^ 3)
	else
		hand = THROW_RELEASE:Lerp(THROW_DOWN, smooth((t - windup - swing) / math.max(duration - windup - swing, 0.05)))
	end
	local dip = math.min(1, t / 0.1) * math.clamp((duration - t) / 0.2, 0, 1)
	return hand, smooth(dip)
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
	if model and Controllers.ThrowController then
		throw.Grenade = Controllers.ThrowController.MakeGrenade(model)
	end
end

function ViewmodelController:GetMuzzle()
	return if model then muzzle else nil
end

function ViewmodelController:GetEjectPort()
	return if model then ejectPort else nil
end

function ViewmodelController:GetModel()
	return model
end

function ViewmodelController:Kick(recoilDegrees)
	kick = math.min(kick + 0.35 + (recoilDegrees or 1) * 0.12, 1.6)
end

local function destroyModel()
	if model then
		model:Destroy()
	end
	model, handle, muzzle, ejectPort = nil, nil, nil, nil
	table.clear(arms)
	if throw then
		throw.Grenade = nil -- was parented to the model
	end
	builtKey = nil
end

local function armColor()
	local character = player.Character
	local part = character and (character:FindFirstChild("RightLowerArm") or character:FindFirstChild("Right Arm"))
	return if part then part.Color else Color3.fromRGB(240, 200, 160)
end

local function sleeveColor()
	local character = player.Character
	local part = character and (character:FindFirstChild("RightUpperArm") or character:FindFirstChild("Torso"))
	return if part then part.Color else Color3.fromRGB(70, 80, 95)
end

local function newArmPart(name, size, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = model
	return p
end

local function build(weaponId, tier)
	destroyModel()
	local stats = Util.GetWeaponStats(weaponId, tier)
	local tool = GunModels.BuildTool(stats)
	model = Instance.new("Model")
	model.Name = "SAMZ_Viewmodel"
	for _, child in tool:GetChildren() do
		child.Parent = model
	end
	tool:Destroy()
	handle = model:FindFirstChild("Handle")
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CastShadow = false
			d.CanQuery = false
			d.CanCollide = false
		end
	end
	handle.Anchored = true -- everything else is welded to it (or to the spin hub)
	muzzle = handle:FindFirstChild("Muzzle")
	ejectPort = handle:FindFirstChild("EjectPort")
	-- arms: forearm (skin) + sleeve, right to the grip, left under the barrel
	local skin, sleeve = armColor(), sleeveColor()
	arms.RightForearm = newArmPart("RightForearm", Vector3.new(0.5, 0.5, 1.4), skin)
	arms.RightSleeve = newArmPart("RightSleeve", Vector3.new(0.62, 0.62, 1.6), sleeve)
	arms.LeftForearm = newArmPart("LeftForearm", Vector3.new(0.5, 0.5, 1.4), skin)
	arms.LeftSleeve = newArmPart("LeftSleeve", Vector3.new(0.62, 0.62, 1.6), sleeve)
	-- throwing arm (only shown during a grenade throw)
	arms.ThrowForearm = newArmPart("ThrowForearm", Vector3.new(0.5, 0.5, 1.4), skin)
	arms.ThrowSleeve = newArmPart("ThrowSleeve", Vector3.new(0.62, 0.62, 1.6), sleeve)
	arms.ThrowFist = newArmPart("ThrowFist", Vector3.new(0.55, 0.55, 0.55), skin)
	model.Parent = workspace.CurrentCamera
	builtKey = weaponId .. "#" .. tier
end

-- Place a two-segment arm from a shoulder point (camera space) to a hand point (world).
local function placeArm(forearm, sleeve, shoulder, hand)
	local elbow = shoulder:Lerp(hand, 0.55) + (shoulder - hand).Unit:Cross(Vector3.yAxis) * 0.05 - Vector3.yAxis * 0.25
	sleeve.CFrame = CFrame.lookAt((shoulder + elbow) / 2, elbow)
	sleeve.Size = Vector3.new(0.62, 0.62, (elbow - shoulder).Magnitude + 0.2)
	forearm.CFrame = CFrame.lookAt((elbow + hand) / 2, hand)
	forearm.Size = Vector3.new(0.5, 0.5, (hand - elbow).Magnitude + 0.25)
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

function ViewmodelController:Init(controllers)
	Controllers = controllers
	local lastCamCF = nil
	-- after the camera + recoil (Camera+3), so the gun sits exactly where the view ends up
	RunService:BindToRenderStep("SAMZ_Viewmodel", Enum.RenderPriority.Camera.Value + 4, function(dt)
		local character = player.Character
		local tool = character and character:FindFirstChildOfClass("Tool")
		local active = Controllers.CameraController:IsActive() and tool ~= nil
		local throwT = throw and os.clock() - throw.Start
		if throw and (throwT >= throw.Duration or not active) then
			if throw.Grenade then
				throw.Grenade:Destroy()
			end
			throw, throwT = nil, nil
		end
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
			if model then
				destroyModel()
			end
			return
		end
		setToolHidden(tool, true)
		hiddenTool = tool

		local weaponId = tool:GetAttribute("WeaponId") or player:GetAttribute("WeaponId")
		local tier = player:GetAttribute("WeaponTier") or 1
		if not weaponId then
			return
		end
		if builtKey ~= weaponId .. "#" .. tier or not (model and model.Parent) then
			build(weaponId, tier)
		end

		local camera = workspace.CurrentCamera
		local camCF = camera.CFrame
		-- sway: lag behind quick camera turns
		if lastCamCF then
			local delta = lastCamCF:ToObjectSpace(camCF)
			local rx, ry = delta:ToEulerAnglesYXZ()
			sway = sway:Lerp(Vector2.new(math.clamp(ry, -0.1, 0.1), math.clamp(rx, -0.1, 0.1)), math.min(1, dt * 12))
		else
			sway = Vector2.zero
		end
		lastCamCF = camCF
		sway *= math.exp(-6 * dt)
		-- walk bob
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local moving = humanoid and humanoid.MoveDirection.Magnitude > 0.1
		bobT += dt * (if moving then 9 else 2)
		local bobAmp = if moving then 0.06 else 0.015
		local bob = Vector3.new(math.sin(bobT * 0.5) * bobAmp, math.abs(math.sin(bobT)) * bobAmp, 0)
		-- recoil jolt
		kick *= math.exp(-12 * dt)
		local k = kick * GameConfig.Camera.ViewmodelKick

		local offset = GameConfig.Camera.ViewmodelOffset
		local gunCF = camCF
			* CFrame.new(offset + bob + Vector3.new(-sway.X * 2, sway.Y * 2, k))
			* CFrame.Angles(k * 0.6 + sway.Y, sway.X, 0)
		local throwHand, dip = nil, 0
		if throw then
			throwHand, dip = throwPose(throwT, throw.Windup, throw.Duration)
			-- the gun drops down/left, held by the left hand, out of the throwing arm's way
			gunCF *= CFrame.new(-0.35 * dip, -1.3 * dip, 0.5 * dip) * CFrame.Angles(-0.7 * dip, 0, 0.45 * dip)
		end
		handle.CFrame = gunCF

		-- arms: shoulders below/behind the camera; hands at the grip and under the barrel
		local gripHand = (gunCF * CFrame.new(0, -0.15, 0.15)).Position
		local barrelLen = if muzzle then math.abs(muzzle.Position.Z) else 1.2
		local supportHand = (gunCF * CFrame.new(0, 0.15, -math.clamp(barrelLen * 0.55, 0.5, 1.8))).Position
		local rightShoulder = (camCF * CFrame.new(1.35, -1.9, 0.6)).Position
		local leftShoulder = (camCF * CFrame.new(-1.15, -1.9, 0.6)).Position
		placeArm(arms.LeftForearm, arms.LeftSleeve, leftShoulder, supportHand)
		local throwing = throwHand ~= nil
		for _, name in { "RightForearm", "RightSleeve" } do
			arms[name].Transparency = if throwing then 1 else 0
		end
		for _, name in { "ThrowForearm", "ThrowSleeve", "ThrowFist" } do
			arms[name].Transparency = if throwing then 0 else 1
		end
		if throwing then
			local hand = (camCF * CFrame.new(throwHand)).Position
			local throwShoulder = (camCF * CFrame.new(1.25, -2.0, 0.7)).Position
			placeArm(arms.ThrowForearm, arms.ThrowSleeve, throwShoulder, hand)
			arms.ThrowFist.CFrame = arms.ThrowForearm.CFrame * CFrame.new(0, 0, -arms.ThrowForearm.Size.Z / 2)
			throw.Hand = hand
			if throw.Grenade then
				if throwT < throw.Windup then
					throw.Grenade:PivotTo(arms.ThrowFist.CFrame * CFrame.new(0, 0.2, -0.35))
				else
					throw.Grenade:Destroy() -- released: the Projectile effect takes over from here
					throw.Grenade = nil
				end
			end
		else
			placeArm(arms.RightForearm, arms.RightSleeve, rightShoulder, gripHand)
		end
	end)
	player.CharacterRemoving:Connect(destroyModel)
end

return ViewmodelController
