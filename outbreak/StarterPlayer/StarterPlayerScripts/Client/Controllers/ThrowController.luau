-- ThrowController: the grenade throw animation (server sends Remotes.Effect "Throw" from
-- AbilityService's Grenade handler; timings in GameConfig.Throw).
--   * Your own throw in first person -> ViewmodelController:PlayThrow (arm + grenade in view)
--   * Everyone else (and you in third person) -> the character's right arm winds up over the
--     shoulder and swings through, holding a client-only grenade until release. The arm is driven
--     by overriding the RightShoulder Motor6D.Transform after the Animator runs each frame, blended
--     in/out so it mixes with the tool-hold animation.
-- Also provides the grenade model (viewmodel hand + flying projectile) and the thrower's hand
-- position so your projectile visually leaves your first-person hand.
--
-- Public: ThrowController.MakeGrenade(parent) -> Model, ThrowController:IsThrowing(character)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local ThrowController = {}
local Controllers
local active = {} -- [character] = true while its third-person throw plays

local function gPart(model, name, size, color, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Anchored = true
	p.Parent = model
	return p
end

-- Blocky frag grenade: olive body, dark top fuse, steel lever. Model pivot = body centre.
function ThrowController.MakeGrenade(parent)
	local model = Instance.new("Model")
	model.Name = "Grenade"
	local body = gPart(model, "Body", Vector3.new(0.55, 0.65, 0.55), Color3.fromRGB(70, 92, 52))
	local band = gPart(model, "Band", Vector3.new(0.6, 0.12, 0.6), Color3.fromRGB(52, 70, 40))
	local fuse = gPart(model, "Fuse", Vector3.new(0.3, 0.2, 0.3), Color3.fromRGB(45, 45, 48))
	local lever = gPart(model, "Lever", Vector3.new(0.08, 0.5, 0.14), Color3.fromRGB(160, 160, 165))
	local ring = gPart(model, "Ring", Vector3.new(0.05, 0.22, 0.22), Color3.fromRGB(190, 190, 195))
	model.PrimaryPart = body
	local function place(cf)
		body.CFrame = cf
		band.CFrame = cf * CFrame.new(0, 0.05, 0)
		fuse.CFrame = cf * CFrame.new(0, 0.42, 0)
		lever.CFrame = cf * CFrame.new(0.32, 0.18, 0) * CFrame.Angles(0, 0, math.rad(-12))
		ring.CFrame = cf * CFrame.new(-0.2, 0.5, 0)
	end
	place(CFrame.new())
	model.Parent = parent
	return model
end

function ThrowController:IsThrowing(character)
	return active[character] == true
end

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function easeOut(x)
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) ^ 3
end

-- Right-shoulder pose over time (R15: rotation about the shoulder's X raises the arm forward/up;
-- 90 = pointing forward, 180 = straight up, ~205 = cocked back behind the head).
local function shoulderPose(t, windup, duration)
	local swing = 0.16
	local pitch, roll
	if t < windup then
		local a = smooth(t / windup)
		pitch, roll = 90 + 115 * a, -18 * a
	elseif t < windup + swing then
		local a = easeOut((t - windup) / swing)
		pitch, roll = 205 - 160 * a, -18 + 26 * a
	else
		pitch, roll = 45, 8
	end
	-- blend weight: in fast, out over the last 0.2s
	local w = math.min(1, t / 0.07) * math.clamp((duration - t) / 0.2, 0, 1)
	return CFrame.Angles(math.rad(pitch), 0, math.rad(roll)), w
end

function ThrowController:AnimateCharacter(character, windup, duration)
	if not character or active[character] then
		return
	end
	local upperArm = character:FindFirstChild("RightUpperArm")
	local motor = upperArm and upperArm:FindFirstChild("RightShoulder")
	local r6 = false
	if not motor then
		local torso = character:FindFirstChild("Torso")
		motor = torso and torso:FindFirstChild("Right Shoulder")
		r6 = motor ~= nil
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not motor or not hand then
		return
	end
	active[character] = true
	local grenade = ThrowController.MakeGrenade(workspace:FindFirstChild("ClientEffects") or workspace)
	local tool = character:FindFirstChildOfClass("Tool")
	local start = os.clock()
	local conn
	conn = RunService.PreSimulation:Connect(function()
		local t = os.clock() - start
		if t >= duration or not motor.Parent then
			conn:Disconnect()
			if grenade then
				grenade:Destroy()
			end
			active[character] = nil
			return
		end
		local pose, w = shoulderPose(t, windup, duration)
		if r6 then
			-- R6 shoulder joint is rotated 90 degrees: its raise-forward axis is Z
			local pitch = select(1, pose:ToEulerAnglesXYZ())
			pose = CFrame.Angles(0, 0, pitch)
		end
		-- runs after the Animator this frame, so this wins; Lerp keeps it blended with the hold pose
		motor.Transform = motor.Transform:Lerp(pose, w)
		if grenade and t < windup then
			grenade:PivotTo(hand.CFrame * CFrame.new(0, -0.55, -0.1))
		elseif grenade then
			grenade:Destroy() -- released: the server's Projectile takes over
			grenade = nil
		end
		-- the gun is in the throwing hand: hide it for the throw (local only)
		if tool and tool.Parent == character then
			local hidden = if t < duration - 0.15 then 1 else 0
			for _, d in tool:GetDescendants() do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = hidden
				end
			end
		end
	end)
end

function ThrowController:Init(controllers)
	Controllers = controllers
	local Effects = Controllers.EffectsController
	Effects.Handlers.Throw = function(data)
		local character = data.Character
		if not character then
			return
		end
		local windup, duration = data.Windup or 0.32, data.Duration or 0.8
		-- pin pull now, whoosh at release (2D for you, 3D at other throwers)
		local Sound = Controllers.SoundController
		local root = character:FindFirstChild("HumanoidRootPart")
		local function play(name)
			if character == player.Character then
				Sound:Play(name)
			elseif root and root.Parent then
				Sound:PlayAt(name, root.Position)
			end
		end
		play("GrenadePin")
		task.delay(windup * 0.85, play, "Throw")
		if character == player.Character and Controllers.CameraController:IsActive() then
			Controllers.ViewmodelController:PlayThrow(windup, duration)
		else
			self:AnimateCharacter(character, windup, duration)
		end
	end
	-- your projectile leaves your first-person hand; grenades fly as the grenade model
	Effects.ThrowOrigin = function()
		return Controllers.ViewmodelController:GetThrowHand()
	end
	Effects.MakeGrenade = ThrowController.MakeGrenade
end

return ThrowController
