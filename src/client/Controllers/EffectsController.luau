-- EffectsController: all client-side visuals. Parts go in Workspace.ClientEffects (non-queryable).
--   * Server effects arrive via Remotes.Effect(kind, data) and dispatch to EffectsController.Handlers[kind]
--   * Damage numbers from Remotes.HitConfirm
--   * Zombie animation: plays keyframed gaits (Shared/ZombieGaits) on each zombie's Motor6Ds locally (no server cost)
--   * Zombie hit reaction: "ZombieHit" makes the zombie flinch and flash red (animateZombies)
-- To add an effect: add Handlers.MyEffect = function(data) ... end and fire it from the server with
--   Remotes.Effect:FireAllClients("MyEffect", { ... })

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Weapons = require(Shared.Config.Weapons)
local Zombies = require(Shared.Config.Zombies)
local ZombieGaits = require(Shared.ZombieGaits)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local player = Players.LocalPlayer
local EffectsController = {}
local Handlers = {}
EffectsController.Handlers = Handlers
local folder

local function fxPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = folder
	return p
end

local function tween(inst, time, goal, style)
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function ring(position, radius, color, time, startTransparency)
	local p = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 1, 1),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = startTransparency or 0.3,
	})
	tween(p, time, { Size = Vector3.new(0.3, radius * 2, radius * 2), Transparency = 1 })
	Debris:AddItem(p, time)
	return p
end

-- width / fade: per-gun look (Weapons.List[id].Tracer); thick tracers (>= 0.25) also glow
function EffectsController:Tracer(from, to, color, width, fade)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	width = width or 0.12
	fade = fade or 0.1
	local p = fxPart({
		Size = Vector3.new(width, width, length),
		CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2),
		Color = color or Color3.fromRGB(255, 230, 150),
		Transparency = 0.2,
	})
	if width >= 0.25 then
		local glow = fxPart({ Size = Vector3.new(width * 2.4, width * 2.4, length), CFrame = p.CFrame, Color = p.Color, Transparency = 0.75 })
		tween(glow, fade, { Transparency = 1 })
		Debris:AddItem(glow, fade + 0.02)
	end
	tween(p, fade, { Transparency = 1, Size = Vector3.new(width * 0.3, width * 0.3, length) })
	Debris:AddItem(p, fade + 0.02)
end

-- Tracer styled for a weapon id
function EffectsController:WeaponTracer(weaponId, from, to)
	local style = Weapons.List[weaponId] and Weapons.List[weaponId].Tracer
	if style then
		self:Tracer(from, to, style.Color, style.Width, style.Fade)
	else
		self:Tracer(from, to)
	end
end

-- A star-shaped flash: bright core, a spike out of the barrel and four petals at a random roll.
-- `attachment` (the Muzzle) gives the barrel direction; gone in a couple of frames.
function EffectsController:MuzzleFlash(attachment, position, scale, color)
	scale = scale or 1
	color = color or Color3.fromRGB(255, 200, 90)
	local base = if attachment then CFrame.new(position) * attachment.WorldCFrame.Rotation else CFrame.new(position)
	local core = fxPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.6 * scale,
		Position = position,
		Color = color,
		Transparency = 0.05,
	})
	local parts = { core }
	if attachment then
		table.insert(parts, fxPart({ Size = Vector3.new(0.16, 0.16, 1.2) * scale, CFrame = base * CFrame.new(0, 0, -0.55 * scale), Color = color, Transparency = 0.2 }))
		local roll = math.random() * math.pi
		for i = 0, 3 do
			local petal = base * CFrame.Angles(0, 0, roll + i * math.pi / 2) * CFrame.new(0, 0.32 * scale, -0.12 * scale)
			table.insert(parts, fxPart({ Size = Vector3.new(0.1, 0.6, 0.1) * scale, CFrame = petal, Color = color, Transparency = 0.25 }))
		end
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 12 * math.max(scale, 0.6)
	light.Brightness = 3
	light.Parent = core
	for _, p in parts do
		tween(p, 0.05, { Transparency = 1 })
		Debris:AddItem(p, 0.06)
	end
end

-- A brass casing flicked out to the right of the gun (scale < 1 for the first-person viewmodel)
function EffectsController:Shell(position, right, scale)
	scale = scale or 1
	local shell = fxPart({
		Size = Vector3.new(0.08, 0.08, 0.2) * scale,
		Position = position,
		Color = Color3.fromRGB(200, 160, 60),
		Material = Enum.Material.Metal,
		Anchored = false,
		CanCollide = true,
	})
	shell.AssemblyLinearVelocity = right * (8 + math.random() * 4) + Vector3.new(0, 10 + math.random() * 4, 0)
	shell.AssemblyAngularVelocity = Vector3.new(math.random(-20, 20), math.random(-20, 20), math.random(-20, 20))
	Debris:AddItem(shell, 1.2)
end

function EffectsController:DamageNumber(position, amount, headshot, killed)
	local anchor = fxPart({ Size = Vector3.new(0.1, 0.1, 0.1), Position = position, Transparency = 1 })
	local gui = UIKit.new("BillboardGui", {
		Size = UDim2.fromOffset(80, 30),
		AlwaysOnTop = true,
		StudsOffset = Vector3.new(math.random(-10, 10) / 10, 1, 0),
		Adornee = anchor,
		Parent = anchor,
	})
	local label = UIKit.Label({
		Size = UDim2.fromScale(1, 1),
		Text = tostring(amount),
		TextSize = if headshot then 26 else 20,
		TextColor3 = if killed then Color3.fromRGB(255, 90, 70) elseif headshot then Color3.fromRGB(255, 220, 60) else Color3.new(1, 1, 1),
		Parent = gui,
	})
	tween(gui, 0.6, { StudsOffset = gui.StudsOffset + Vector3.new(0, 2.5, 0) })
	tween(label, 0.6, { TextTransparency = 1 }, Enum.EasingStyle.Quint)
	Debris:AddItem(anchor, 0.65)
end

Handlers.Tracer = function(data)
	if data.WeaponId then
		EffectsController:WeaponTracer(data.WeaponId, data.From, data.To)
	else
		EffectsController:Tracer(data.From, data.To)
	end
end

Handlers.Explosion = function(data)
	local r = data.Radius
	local ball = fxPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2,
		Position = data.Position,
		Color = Color3.fromRGB(255, 150, 50),
		Transparency = 0.1,
	})
	tween(ball, 0.3, { Size = Vector3.one * r * 2, Transparency = 1, Color = Color3.fromRGB(255, 70, 30) })
	Debris:AddItem(ball, 0.32)
	ring(data.Position, r * 1.2, Color3.fromRGB(255, 200, 120), 0.35)
	for _ = 1, 8 do
		local chunk = fxPart({
			Size = Vector3.one * (0.4 + math.random() * 0.6),
			Position = data.Position + Vector3.new(0, 1, 0),
			Color = Color3.fromRGB(90, 85, 80),
			Material = Enum.Material.Concrete,
			Anchored = false,
			CanCollide = true,
		})
		chunk.AssemblyLinearVelocity = Vector3.new(math.random(-30, 30), math.random(25, 50), math.random(-30, 30))
		Debris:AddItem(chunk, 1.5)
	end
	-- Camera shake scaled by distance
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local strength = math.clamp(1 - (root.Position - data.Position).Magnitude / (r * 4), 0, 1)
		if strength > 0 then
			EffectsController:Shake(strength * 0.6, 0.25)
		end
	end
end

Handlers.ZombieDeath = function(data)
	local s = data.Scale or 1
	for _ = 1, 6 do
		local chunk = fxPart({
			Size = Vector3.one * (0.5 + math.random() * 0.5) * s,
			Position = data.Position + Vector3.new(math.random() - 0.5, math.random(), math.random() - 0.5) * 2 * s,
			Color = data.Color,
			Material = Enum.Material.SmoothPlastic,
			Anchored = false,
			CanCollide = true,
		})
		chunk.AssemblyLinearVelocity = Vector3.new(math.random(-20, 20), math.random(15, 35), math.random(-20, 20))
		chunk.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
		task.delay(0.8, function()
			if chunk.Parent then
				tween(chunk, 0.4, { Transparency = 1 })
			end
		end)
		Debris:AddItem(chunk, 1.3)
	end
end

Handlers.Shockwave = function(data)
	ring(data.Position, data.Radius, Color3.fromRGB(255, 120, 80), 0.4, 0.2)
	EffectsController:Shake(0.4, 0.2)
end

Handlers.Heal = function(data)
	ring(data.Position - Vector3.new(0, 2.5, 0), data.Radius, Color3.fromRGB(90, 255, 140), 0.6, 0.2)
end

Handlers.Marker = function(data)
	local p = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.25, data.Radius * 2, data.Radius * 2),
		CFrame = CFrame.new(data.Position + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 60, 40),
		Transparency = 0.6,
	})
	tween(p, data.Time, { Transparency = 0.3 })
	Debris:AddItem(p, data.Time + 0.5)
end

-- Zombie about to rise here (ZombieService:SpawnWarned): a red disc fades in while a ring closes on
-- it, then a burst of dirt as the zombie breaks through.
Handlers.SpawnWarning = function(data)
	local up = CFrame.Angles(0, 0, math.rad(90))
	local at = CFrame.new(data.Position + Vector3.new(0, 0.12, 0)) * up
	local d = data.Radius * 2
	local disc = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, d, d), CFrame = at, Color = Color3.fromRGB(255, 40, 30), Transparency = 0.85 })
	tween(disc, data.Time, { Transparency = 0.35 }, Enum.EasingStyle.Linear)
	local ringPart = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, d * 2.2, d * 2.2), CFrame = at * CFrame.new(0.02, 0, 0), Color = Color3.fromRGB(255, 90, 70), Transparency = 0.5 })
	tween(ringPart, data.Time, { Size = Vector3.new(0.15, d, d), Transparency = 0.2 }, Enum.EasingStyle.Linear)
	task.delay(data.Time, function()
		disc:Destroy()
		ringPart:Destroy()
		for _ = 1, 7 do
			local chunk = fxPart({
				Size = Vector3.one * (0.3 + math.random() * 0.5),
				Position = data.Position + Vector3.new((math.random() - 0.5) * d, 0.5, (math.random() - 0.5) * d),
				Color = Color3.fromRGB(70 + math.random(0, 30), 58, 46),
				Material = Enum.Material.Concrete,
				Anchored = false,
				CanCollide = true,
			})
			chunk.AssemblyLinearVelocity = Vector3.new(math.random(-12, 12), math.random(18, 30), math.random(-12, 12))
			Debris:AddItem(chunk, 1)
		end
	end)
end

-- Optional hooks set by ThrowController: ThrowOrigin() -> Vector3? (your first-person throwing
-- hand) and MakeGrenade(parent) -> Model (grenade projectiles fly as the grenade model).
Handlers.Projectile = function(data)
	local from = data.From
	if data.Owner == player.UserId and EffectsController.ThrowOrigin then
		from = EffectsController.ThrowOrigin() or from
	end
	local p, grenade
	if data.Grenade and EffectsController.MakeGrenade then
		grenade = EffectsController.MakeGrenade(folder)
		grenade:PivotTo(CFrame.new(from))
	else
		p = fxPart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.9,
			Position = from,
			Color = data.Color or Color3.new(0.2, 0.2, 0.2),
			Material = Enum.Material.SmoothPlastic,
		})
	end
	local start = os.clock()
	local height = math.max(4, (data.To - from).Magnitude * 0.25)
	local spinAxis = (data.To - from).Unit:Cross(Vector3.yAxis)
	if spinAxis.Magnitude < 0.1 or spinAxis ~= spinAxis then
		spinAxis = Vector3.xAxis
	end
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - start) / data.Time, 0, 1)
		local pos = from:Lerp(data.To, t) + Vector3.new(0, math.sin(t * math.pi) * height, 0)
		if grenade then
			-- tumbles end over end along the arc
			grenade:PivotTo(CFrame.new(pos) * CFrame.fromAxisAngle(spinAxis.Unit, -(os.clock() - start) * 14))
		else
			p.Position = pos
		end
		if t >= 1 then
			conn:Disconnect()
			if grenade then
				grenade:Destroy()
			else
				p:Destroy()
			end
		end
	end)
end

Handlers.Dash = function(data)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local dir = humanoid.MoveDirection
	if dir.Magnitude < 0.1 then
		dir = root.CFrame.LookVector
	end
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local endTime = os.clock() + data.Duration
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if os.clock() >= endTime or not root.Parent then
			conn:Disconnect()
			return
		end
		root.AssemblyLinearVelocity = Vector3.new(dir.X * data.Speed, root.AssemblyLinearVelocity.Y, dir.Z * data.Speed)
	end)
	EffectsController:Tracer(root.Position, root.Position + dir * data.Speed * data.Duration, Color3.fromRGB(120, 220, 255))
end

-- Camera shake: offsets the camera a little each frame for `duration` seconds.
local shakeUntil, shakeStrength = 0, 0
function EffectsController:Shake(strength, duration)
	shakeStrength = math.max(shakeStrength, strength)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
end

-- Zombie animation (local only, no server cost). Each zombie plays a keyframed gait for its build
-- (Shared/ZombieGaits) that advances with its real ground speed, so feet don't skate, and fades into a
-- breathing idle when it stops. The body leans and lurches from the hips and the head follows, through the
-- Torso and Head motors; arms and head are carried with the body (motors.*A/*B move their joint into hip
-- space and back). Every zombie differs a little: its own limp side, phase and size of motion, so a crowd
-- doesn't march. One-shot moves from ZombieGaits sit on top: an attack for its build when the server stamps
-- "AttackAt" (ZombieService), and on a "ZombieHit" effect a flinch that leans away from the hit, a harder
-- snap on a headshot, plus a red flash.
local POSE_FADE = 12
local FLASH_TIME = 0.12
local FLASH_COLOR = Color3.fromRGB(255, 60, 40)
local motorCache = setmetatable({}, { __mode = "k" })
local function carried(motor, hip) -- turns a body move at the hips into the same move at this joint
	if not motor or not hip then
		return CFrame.identity, CFrame.identity
	end
	return motor.C0:Inverse() * hip.C0, hip.C0:Inverse() * motor.C0
end
local function getMotors(model)
	local motors = motorCache[model]
	if not motors then
		local root = model:FindFirstChild("Root")
		if not root then
			return nil
		end
		local id = model:GetAttribute("ZombieId") or 0
		local torso = root:FindFirstChild("Torso")
		motors = {
			Root = root,
			LeftLeg = root:FindFirstChild("LeftLeg"),
			RightLeg = root:FindFirstChild("RightLeg"),
			LeftArm = root:FindFirstChild("LeftArm"),
			RightArm = root:FindFirstChild("RightArm"),
			Torso = torso,
			Head = root:FindFirstChild("Head"),
			HeadPart = model:FindFirstChild("Head"),
			Def = Zombies.Types[model.Name],
			Gait = ZombieGaits.For(Zombies.Types[model.Name]),
			Phase = (id * 0.37) % 1,
			Mirror = id % 2 == 0, -- which side it limps on
			Size = 0.88 + (id * 0.61 % 1) * 0.24, -- how big its movements are
			Pace = 0.94 + (id * 0.83 % 1) * 0.12, -- how long its stride is
			IdleAt = id * 1.3,
			Moving = 0,
			Scale = root.Size.Y / 5,
			Held = {},
			PoseHeld = 0,
			FlashBase = {},
		}
		motors.HeadA, motors.HeadB = carried(motors.Head, torso)
		motors.LeftArmA, motors.LeftArmB = carried(motors.LeftArm, torso)
		motors.RightArmA, motors.RightArmB = carried(motors.RightArm, torso)
		motorCache[model] = motors
	end
	return motors
end
local walkPose, idlePose, livePose = {}, {}, {}
local function mix(channel, go, size, idleWeight) -- idle to walk by how fast it's moving
	local still = idlePose[channel] * idleWeight
	return (still + (walkPose[channel] - still) * go) * size
end
local function animateZombies(zombieFolder, dt)
	local t = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	local ease = math.min(1, dt * 7)
	for _, model in zombieFolder:GetChildren() do
		local motors = getMotors(model)
		if not motors then
			continue
		end
		local v = motors.Root.AssemblyLinearVelocity
		local speed = Vector2.new(v.X, v.Z).Magnitude
		local gait, scale = motors.Gait, motors.Scale
		motors.Phase = (motors.Phase + dt * speed / (gait.Stride * scale * motors.Pace)) % 1
		motors.Moving += (math.clamp(speed / (3 * scale), 0, 1) - motors.Moving) * ease
		local go, size = motors.Moving, motors.Size
		ZombieGaits.Sample(gait, motors.Phase, walkPose)
		ZombieGaits.Sample(ZombieGaits.Idle, (t + motors.IdleAt) / ZombieGaits.IdleSeconds, idlePose)
		local swap = if motors.Mirror then -1 else 1
		local pose = livePose
		pose.LeftLeg, pose.RightLeg = mix("LeftLeg", go, size, 1), mix("RightLeg", go, size, 1)
		pose.LeftArm, pose.RightArm = mix("LeftArm", go, size, gait.IdleArms), mix("RightArm", go, size, gait.IdleArms)
		if motors.Mirror then
			pose.LeftLeg, pose.RightLeg = pose.RightLeg, pose.LeftLeg
			pose.LeftArm, pose.RightArm = pose.RightArm, pose.LeftArm
		end
		pose.ArmOut = mix("ArmOut", go, size, 1)
		pose.BodyPitch, pose.BodyRoll, pose.BodyYaw = mix("BodyPitch", go, size, 1), mix("BodyRoll", go, size, 1) * swap, mix("BodyYaw", go, size, 1) * swap
		pose.Bob = mix("Bob", go, size, 1)
		pose.HeadPitch, pose.HeadRoll = mix("HeadPitch", go, size, 1), mix("HeadRoll", go, size, 1) * swap

		-- a new "AttackAt" stamp picks one of its build's attacks
		local attackAt = model:GetAttribute("AttackAt")
		if attackAt and attackAt ~= motors.AttackStamp then
			motors.AttackStamp = attackAt
			local list = gait.Attacks
			motors.AttackMove = list[math.floor(attackAt * 3) % #list + 1]
		end
		local attack = motors.AttackMove
		if attack then
			local u = (serverNow - attackAt) / attack.Time
			if u >= 0 and u < 1 then
				ZombieGaits.Add(attack, u, pose)
			end
		end
		local hit = motors.HitMove
		if hit then
			local u = (t - motors.HitAt) / hit.Time
			if u < 1 then
				ZombieGaits.Add(hit, u, pose, motors.HitFlip)
			else
				motors.HitMove = nil
			end
		end

		-- server-stamped poses (ZombieService, MatchService; model attributes Pose + PoseAt) take over: "Rise" reaches
		-- up and claws out of the ground, "Burrow" digs down into it, "Scream" (Wailer) flings the arms up, shaking.
		-- A boss rises, roars and rears up for its slam with held moves from ZombieGaits. They all fade in and out
		-- (POSE_FADE) so the arms don't whip through a half turn in one frame.
		local state = model:GetAttribute("Pose")
		local heldPose = motors.Held
		if state then
			local age = serverNow - (model:GetAttribute("PoseAt") or serverNow)
			local claw = math.sin(age * 16) * 0.45
			table.clear(heldPose)
			if state == "Rise" then
				local intro = motors.Def and motors.Def.Intro
				if intro then
					ZombieGaits.Set(ZombieGaits.Moves.BossRise, age / intro.RiseTime, heldPose)
				else
					heldPose.LeftArm, heldPose.RightArm = 1.9 + claw, 1.9 - claw
				end
			elseif state == "Burrow" then
				heldPose.LeftArm, heldPose.RightArm = -0.9 + claw, -0.9 - claw
			elseif state == "Scream" then
				local shake = math.sin(age * 45) * 0.08
				heldPose.LeftArm, heldPose.RightArm, heldPose.ArmOut = 1.4 + shake, 1.4 - shake, 0.45
				heldPose.BodyPitch, heldPose.HeadPitch = 0.22, 0.45
			elseif state == "Roar" then
				ZombieGaits.Set(ZombieGaits.Moves.BossRoar, age / ZombieGaits.Moves.BossRoar.Time, heldPose)
			elseif state == "Slam" then
				ZombieGaits.Set(ZombieGaits.Moves.BossSlam, age / motors.Def.Slam.Windup, heldPose)
			end
		end
		local held = motors.PoseHeld + ((if state then 1 else 0) - motors.PoseHeld) * math.min(1, dt * POSE_FADE)
		motors.PoseHeld = held
		if held > 0.005 then
			for channel, value in heldPose do
				pose[channel] += (value - pose[channel]) * held
			end
		end

		local body = CFrame.new(0, pose.Bob * scale, 0) * CFrame.Angles(pose.BodyPitch, pose.BodyYaw, pose.BodyRoll)
		if motors.Torso then
			motors.Torso.Transform = body
		end
		if motors.Head then
			motors.Head.Transform = motors.HeadA * body * motors.HeadB * CFrame.Angles(pose.HeadPitch, 0, pose.HeadRoll)
		end
		if motors.LeftLeg then
			motors.LeftLeg.Transform = CFrame.Angles(pose.LeftLeg, 0, 0)
		end
		if motors.RightLeg then
			motors.RightLeg.Transform = CFrame.Angles(pose.RightLeg, 0, 0)
		end
		if motors.LeftArm then
			motors.LeftArm.Transform = motors.LeftArmA * body * motors.LeftArmB * CFrame.Angles(pose.LeftArm, 0, -pose.ArmOut)
		end
		if motors.RightArm then
			motors.RightArm.Transform = motors.RightArmA * body * motors.RightArmB * CFrame.Angles(pose.RightArm, 0, pose.ArmOut)
		end
		-- damage flash: tint every visible part toward red, restore exactly when it expires
		if motors.FlashUntil then
			local f = math.clamp((motors.FlashUntil - t) / FLASH_TIME, 0, 1)
			if f <= 0 then
				for p, color in motors.FlashBase do
					if p.Parent then
						p.Color = color
					end
				end
				table.clear(motors.FlashBase)
				motors.FlashUntil = nil
			else
				for p, color in motors.FlashBase do
					if p.Parent then
						p.Color = color:Lerp(FLASH_COLOR, 0.65 * f)
					end
				end
			end
		end
	end
end

-- Hit reaction state is set here; animateZombies applies and restores it every frame.
Handlers.ZombieHit = function(data)
	local model = data.Model
	if typeof(model) ~= "Instance" or not model.Parent then
		return
	end
	local motors = getMotors(model)
	if not motors then
		return
	end
	local now = os.clock()
	if data.Flinch and (not motors.HitMove or now - motors.HitAt > motors.HitMove.Time * 0.5) then -- a stream of bullets doesn't freeze it at the start
		local at, root = data.Position or motors.Root.Position, motors.Root
		local head = motors.HeadPart
		motors.HitMove = ZombieGaits.Hit(motors.Gait, head ~= nil and at.Y > head.Position.Y - head.Size.Y * 0.6)
		motors.HitAt = now
		motors.HitFlip = (at - root.Position):Dot(root.CFrame.RightVector) < 0
	end
	if not motors.FlashUntil or now >= motors.FlashUntil then
		table.clear(motors.FlashBase) -- a flash already running: restart the snapshot
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") and p.Transparency < 1 then
				motors.FlashBase[p] = p.Color
			end
		end
	end
	motors.FlashUntil = now + FLASH_TIME
end

function EffectsController:Init()
	folder = Instance.new("Folder")
	folder.Name = "ClientEffects"
	folder.Parent = workspace

	Remotes.Effect.OnClientEvent:Connect(function(kind, data)
		local handler = Handlers[kind]
		if handler then
			handler(data)
		end
	end)
	Remotes.HitConfirm.OnClientEvent:Connect(function(hits)
		for _, hit in hits do
			self:DamageNumber(hit.Position, hit.Damage, hit.Headshot, hit.Killed)
		end
	end)

	RunService:BindToRenderStep("SAMZ_Shake", Enum.RenderPriority.Camera.Value + 2, function()
		local now = os.clock()
		if now < shakeUntil then
			local s = shakeStrength
			workspace.CurrentCamera.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * s * 4), math.rad((math.random() - 0.5) * s * 4), 0)
		else
			shakeStrength = 0
		end
	end)

	task.spawn(function()
		local zombieFolder = workspace:WaitForChild("Zombies")
		RunService.RenderStepped:Connect(function(dt)
			animateZombies(zombieFolder, dt)
		end)
	end)
end

return EffectsController
