-- CutsceneController: the first-person drop-in at the start of a run (vault: Match Start.md).
-- While the player's "Deploying" attribute is true the server holds them above the arena; this
-- plays a client-side helicopter ride along GameState.DeployPath (MapService:GetDeployFlight: from
-- over the ocean, low over the waves, up over the rooftops, to a hover above the square), timed by
-- DeployStart/DeployDuration (server clock). You sit in the open cabin and look around (CAM_KEYS):
-- out the door at the sea, forward through the windshield at the skyline, down at the streets,
-- then at the pilot, who turns and gives a thumbs-up ("Good luck down there."), and out the door
-- as you jump. Then the camera goes first person on the character, who parachutes down
-- (MatchService:_parachute) until CameraController takes over on landing.
-- Sound + effects (ids in Shared/Config/Sounds, played through SoundController): cabin wind that
-- swells at the door, sea wash and rotor-wash spray while skimming the waves, faint radio chatter,
-- an intercom squelch before the pilot speaks, wind streaks past the door, a whoosh, shake and FOV
-- kick on the jump, then the chute snapping open and falling wind until you land.
-- The fall (dropView) stays scripted first person: freefall, the canopy opening with a jolt, a look
-- up at it, then a swaying descent holding the toggles, with your own body and gun hidden locally.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Sounds = require(Shared.Config.Sounds)
local GameState = require(Shared.GameState)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local player = Players.LocalPlayer
local CutsceneController = {}
local Controllers
local playing = false

-- one-shot sounds by cutscene progress: { t, library name }
local CUES = {
	{ 0.815, "Radio" }, -- the pilot keys his intercom
	{ 0.962, "JumpWhoosh" },
}

-- Helicopter in its local space (-Z = nose, +X = the open door side, origin = cabin centre).
-- { name, size, offset, color, motion?, props? }   motion: "Y"/"X" = spinning rotor, or a POSE group
local OLIVE = Color3.fromRGB(70, 78, 52)
local DARK = Color3.fromRGB(28, 30, 28)
local CABIN = Color3.fromRGB(52, 56, 48)
local STRAP = Color3.fromRGB(150, 110, 50)
local SKIN = Color3.fromRGB(205, 160, 125)
local VEST = Color3.fromRGB(46, 50, 40)
local GLASS = { Material = Enum.Material.Glass, Transparency = 0.75 }
local HELI = {
	-- cabin shell
	{ "Floor", Vector3.new(6.6, 0.3, 15), CFrame.new(0, -2.2, -1.5), DARK, nil, { Material = Enum.Material.DiamondPlate } },
	{ "Belly", Vector3.new(6, 1.2, 13), CFrame.new(0, -3, -1), OLIVE },
	{ "Roof", Vector3.new(6.6, 0.4, 15), CFrame.new(0, 2.8, -1.5), OLIVE },
	{ "BackWall", Vector3.new(6.6, 5, 0.4), CFrame.new(0, 0.3, 6), CABIN },
	{ "LeftWall", Vector3.new(0.4, 5, 9.5), CFrame.new(-3.3, 0.3, 1.25), CABIN },
	{ "RightRear", Vector3.new(0.4, 5, 2), CFrame.new(3.3, 0.3, 5), CABIN },
	{ "DoorPillar", Vector3.new(0.5, 5, 0.4), CFrame.new(3.3, 0.3, -3.5), DARK },
	{ "Header", Vector3.new(6.6, 0.4, 0.4), CFrame.new(0, 2.4, -3.5), DARK },
	{ "GrabRail", Vector3.new(0.2, 0.2, 7), CFrame.new(2.6, 2.35, 0.25), DARK },
	{ "Bench", Vector3.new(1.4, 0.5, 8), CFrame.new(-2.4, -1.5, 1.5), DARK, nil, { Material = Enum.Material.Fabric } },
	{ "Strap", Vector3.new(0.1, 4, 0.25), CFrame.new(-3.05, 0.3, 4), STRAP, nil, { Material = Enum.Material.Fabric } },
	{ "Lamp", Vector3.new(0.6, 0.2, 0.6), CFrame.new(0, 2.55, 1), Color3.fromRGB(255, 50, 40), nil, { Material = Enum.Material.Neon } },
	-- cockpit
	{ "CockpitLeft", Vector3.new(0.4, 2, 4.5), CFrame.new(-3.3, -1.2, -5.75), OLIVE },
	{ "CockpitRight", Vector3.new(0.4, 2, 4.5), CFrame.new(3.3, -1.2, -5.75), OLIVE },
	{ "SideWindow", Vector3.new(0.2, 2.8, 4.5), CFrame.new(-3.3, 1.2, -5.75), OLIVE, nil, GLASS },
	{ "SideWindow", Vector3.new(0.2, 2.8, 4.5), CFrame.new(3.3, 1.2, -5.75), OLIVE, nil, GLASS },
	{ "Nose", Vector3.new(6, 2.4, 2.6), CFrame.new(0, -1.1, -9.3), OLIVE },
	{ "NoseTop", Vector3.new(6, 0.4, 2), CFrame.new(0, 2.7, -7.6), OLIVE },
	{ "Windshield", Vector3.new(6, 3, 0.2), CFrame.new(0, 1.3, -8.3) * CFrame.Angles(-0.35, 0, 0), OLIVE, nil, GLASS },
	{ "Dash", Vector3.new(5, 1.2, 1), CFrame.new(0, -0.2, -7.5), DARK },
	{ "Screen", Vector3.new(1.2, 0.7, 0.05), CFrame.new(-1.2, 0, -6.98), Color3.fromRGB(90, 255, 120), nil, { Material = Enum.Material.Neon } },
	{ "Screen", Vector3.new(1.2, 0.7, 0.05), CFrame.new(1.4, 0, -6.98), Color3.fromRGB(255, 180, 60), nil, { Material = Enum.Material.Neon } },
	{ "Stick", Vector3.new(0.15, 1.4, 0.15), CFrame.new(1.4, -1.2, -6.2), DARK },
	{ "Seat", Vector3.new(1.8, 0.5, 1.8), CFrame.new(1.4, -1.7, -5.1), DARK },
	{ "SeatBack", Vector3.new(1.8, 1.8, 0.4), CFrame.new(1.4, -0.7, -4.1), DARK },
	{ "Seat", Vector3.new(1.8, 0.5, 1.8), CFrame.new(-1.4, -1.7, -5.1), DARK },
	{ "SeatBack", Vector3.new(1.8, 1.8, 0.4), CFrame.new(-1.4, -0.7, -4.1), DARK },
	-- exterior
	{ "Mast", Vector3.new(0.8, 1.4, 0.8), CFrame.new(0, 3.6, -1), DARK },
	{ "Blade", Vector3.new(1.2, 0.2, 34), CFrame.new(0, 4.4, -1), DARK, "Y" },
	{ "Blade", Vector3.new(34, 0.2, 1.2), CFrame.new(0, 4.4, -1), DARK, "Y" },
	{ "Boom", Vector3.new(1.6, 1.6, 12), CFrame.new(0, 1.4, 12), OLIVE },
	{ "Fin", Vector3.new(0.4, 4.5, 3), CFrame.new(0, 3.4, 17.5), OLIVE },
	{ "TailRotor", Vector3.new(0.2, 3.6, 0.5), CFrame.new(0.5, 3.4, 17.8), DARK, "X" },
	{ "Skid", Vector3.new(0.4, 0.4, 13), CFrame.new(3, -4.2, -1), DARK },
	{ "Skid", Vector3.new(0.4, 0.4, 13), CFrame.new(-3, -4.2, -1), DARK },
	{ "Strut", Vector3.new(0.3, 1.4, 0.3), CFrame.new(3, -3.6, -4.5), DARK },
	{ "Strut", Vector3.new(0.3, 1.4, 0.3), CFrame.new(-3, -3.6, -4.5), DARK },
	{ "Strut", Vector3.new(0.3, 1.4, 0.3), CFrame.new(3, -3.6, 2.5), DARK },
	{ "Strut", Vector3.new(0.3, 1.4, 0.3), CFrame.new(-3, -3.6, 2.5), DARK },
	-- the pilot (right seat): tactical vest, helmet, shades, headset
	{ "PilotTorso", Vector3.new(1.9, 2, 1), CFrame.new(1.4, -0.2, -5.1), VEST },
	{ "Pouch", Vector3.new(0.5, 0.5, 0.3), CFrame.new(1, -0.4, -5.7), OLIVE },
	{ "Pouch", Vector3.new(0.5, 0.5, 0.3), CFrame.new(1.8, -0.4, -5.7), OLIVE },
	{ "PilotLegs", Vector3.new(1.8, 0.8, 1.8), CFrame.new(1.4, -1.1, -5.9), Color3.fromRGB(50, 52, 45) },
	{ "RightArm", Vector3.new(0.6, 0.6, 1.8), CFrame.new(2.2, -0.3, -5.8), VEST },
	{ "Glove", Vector3.new(0.6, 0.6, 0.4), CFrame.new(2.2, -0.4, -6.8), DARK },
	{ "LeftArm", Vector3.new(0.6, 0.6, 1.8), CFrame.new(0.6, -0.3, -5.8), VEST, "Arm" },
	{ "Glove", Vector3.new(0.6, 0.6, 0.5), CFrame.new(0.6, -0.35, -6.8), DARK, "Arm" },
	{ "Thumb", Vector3.new(0.18, 0.4, 0.18), CFrame.new(0.82, -0.3, -7), DARK, "Arm" },
	{ "Head", Vector3.new(1.1, 1.2, 1.1), CFrame.new(1.4, 1.5, -5.1), SKIN, "Head" },
	{ "Helmet", Vector3.new(1.35, 0.75, 1.45), CFrame.new(1.4, 2.05, -5.05), Color3.fromRGB(62, 70, 50), "Head" },
	{ "HelmetBack", Vector3.new(1.35, 0.7, 0.3), CFrame.new(1.4, 1.65, -4.45), Color3.fromRGB(62, 70, 50), "Head" },
	{ "Visor", Vector3.new(1.3, 0.25, 0.5), CFrame.new(1.4, 1.9, -5.75), DARK, "Head" },
	{ "Shades", Vector3.new(1.05, 0.3, 0.08), CFrame.new(1.4, 1.6, -5.67), Color3.fromRGB(15, 15, 18), "Head", { Material = Enum.Material.SmoothPlastic, Reflectance = 0.15 } },
	{ "EarCup", Vector3.new(0.2, 0.55, 0.55), CFrame.new(0.82, 1.55, -5.1), DARK, "Head" },
	{ "EarCup", Vector3.new(0.2, 0.55, 0.55), CFrame.new(1.98, 1.55, -5.1), DARK, "Head" },
	{ "Mic", Vector3.new(0.08, 0.08, 0.6), CFrame.new(1.75, 1.25, -5.55) * CFrame.Angles(0, 0.5, 0), DARK, "Head" },
}
-- pose groups turn around these pivots (helicopter space)
local PIVOT = { Head = CFrame.new(1.4, 0.9, -5.1), Arm = CFrame.new(0.6, 0.4, -5) }

-- where you look, by cutscene progress: { t, yaw, pitch, seat offset }. yaw 0 = the nose, -pi/2 = the door
local SEAT = Vector3.new(-1.9, 1.3, 0.5)
local CAM_KEYS = {
	{ 0.00, -1.45, -0.28, SEAT }, -- out the door: the sea rushing past
	{ 0.16, -1.2, -0.12, SEAT },
	{ 0.30, -0.3, -0.06, SEAT }, -- forward through the windshield: the skyline
	{ 0.46, -0.2, -0.1, SEAT },
	{ 0.56, -1.5, -0.6, Vector3.new(1.2, 1.3, 0.5) }, -- lean out the door: the streets below
	{ 0.68, -1.3, -0.4, Vector3.new(1, 1.3, 0.5) },
	{ 0.78, -0.53, 0.03, SEAT }, -- the pilot
	{ 0.91, -0.53, 0.03, SEAT },
	{ 0.95, -1.57, -0.5, Vector3.new(1.4, 1.2, 0.5) }, -- to the door
	{ 1.00, -1.57, -1.1, Vector3.new(3.6, 0.8, 0.5) }, -- jump
}
local FLY_END = 0.78 -- flight progress reaches the hover point here; the rest is the hover + jump

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- 0 -> 1 over [a, b], back to 0 over [c, d]
local function window(t, a, b, c, d)
	return smooth((t - a) / (b - a)) * (1 - smooth((t - c) / (d - c)))
end

local function camPose(t)
	for i = 2, #CAM_KEYS do
		local k0, k1 = CAM_KEYS[i - 1], CAM_KEYS[i]
		if t <= k1[1] then
			local a = smooth((t - k0[1]) / (k1[1] - k0[1]))
			return k0[2] + (k1[2] - k0[2]) * a, k0[3] + (k1[3] - k0[3]) * a, k0[4]:Lerp(k1[4], a)
		end
	end
	local last = CAM_KEYS[#CAM_KEYS]
	return last[2], last[3], last[4]
end

-- Catmull-Rom through the path samples, s in [0, 1]
local function pathAt(points, s)
	local f = math.clamp(s, 0, 1) * (#points - 1)
	local i = math.min(math.floor(f) + 1, #points - 1)
	local u = f - (i - 1)
	local p0, p1, p2, p3 = points[math.max(i - 1, 1)], points[i], points[i + 1], points[math.min(i + 2, #points)]
	return 0.5 * ((2 * p1) + (p2 - p0) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (3 * p1 - p0 - 3 * p2 + p3) * u * u * u)
end

local function buildHelicopter()
	local folder = Instance.new("Folder")
	folder.Name = "DeployHelicopter"
	local parts = {}
	for _, def in HELI do
		local p = Instance.new("Part")
		p.Name = def[1]
		p.Size = def[2]
		p.Color = def[4]
		p.Material = Enum.Material.Metal
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		for key, value in def[6] or {} do
			p[key] = value
		end
		p.Parent = folder
		parts[#parts + 1] = { Part = p, Offset = def[3], Motion = def[5] }
	end
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 50
	light.Range = 60
	light.Brightness = 3
	light.Color = Color3.fromRGB(255, 240, 210)
	light.Parent = folder.Nose
	local lamp = Instance.new("PointLight")
	lamp.Color = Color3.fromRGB(255, 70, 50)
	lamp.Range = 14
	lamp.Brightness = 1.4
	lamp.Parent = folder.Lamp
	folder.Parent = workspace.CurrentCamera
	return folder, parts
end

local function placeHelicopter(parts, cframe, now, pose)
	for _, entry in parts do
		local cf
		local motion = entry.Motion
		if motion == "Y" then
			cf = cframe * entry.Offset * CFrame.Angles(0, now * 30, 0)
		elseif motion == "X" then
			cf = cframe * entry.Offset * CFrame.Angles(now * 40, 0, 0)
		elseif motion then
			local pivot = PIVOT[motion]
			cf = cframe * pivot * (pose[motion] or CFrame.identity) * pivot:Inverse() * entry.Offset
		else
			cf = cframe * entry.Offset
		end
		entry.Part.CFrame = cf
	end
end

-- letterbox bars, black fade, the title card and the pilot's subtitle (driven per frame by Play)
local function overlay()
	local gui = UIKit.Screen("Cutscene")
	gui.DisplayOrder = 20
	for _, top in { true, false } do
		local bar = UIKit.new("Frame", {
			AnchorPoint = Vector2.new(0, if top then 0 else 1),
			Position = UDim2.fromScale(0, if top then 0 else 1),
			Size = UDim2.new(1, 0, 0.11, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Parent = gui,
		})
		bar.Name = "Bar"
	end
	local o = { Gui = gui }
	o.Fade = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 5, Parent = gui })
	o.Title = UIKit.Label({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 40, 1, -26), Size = UDim2.fromOffset(600, 34), Text = "DROP ZONE — CITY SQUARE", TextSize = 30, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, ZIndex = 2, Parent = gui })
	o.Sub = UIKit.Label({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 40, 1, -60), Size = UDim2.fromOffset(600, 22), Text = "OPERATION LAST LIGHT", TextSize = 18, TextColor3 = UIKit.Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, ZIndex = 2, Parent = gui })
	o.Line = UIKit.Label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.89, -18), Size = UDim2.fromOffset(700, 30), Text = 'PILOT:  "Good luck down there."', TextSize = 26, TextStrokeTransparency = 0.4, TextTransparency = 1, ZIndex = 2, Parent = gui })
	return o
end

-- rotor-wash spray kicked up off the sea (moved under the helicopter each frame)
local function seaSpray()
	local attachment = Instance.new("Attachment")
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(225, 235, 240))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new(6, 20)
	e.Lifetime = NumberRange.new(1.2, 2)
	e.Speed = NumberRange.new(30, 50)
	e.SpreadAngle = Vector2.new(80, 80)
	e.Acceleration = Vector3.new(0, -6, 0)
	e.Drag = 1.5
	e.Rate = 0
	e.Parent = attachment
	attachment.Parent = workspace.Terrain
	return attachment, e
end

-- thin wind streaks rushing back past the open door
local function windStreaks(floor)
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(3.6, 3.4, -1.5) -- top of the door opening, in Floor space
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.new(1, 1, 1))
	e.LightEmission = 0.3
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.5), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new(0.25)
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Squash = NumberSequence.new(-2.5)
	e.EmissionDirection = Enum.NormalId.Back
	e.SpreadAngle = Vector2.new(25, 15)
	e.Speed = NumberRange.new(30, 45)
	e.Lifetime = NumberRange.new(0.25, 0.4)
	e.LockedToPart = true
	e.Rate = 0
	e.Parent = attachment
	attachment.Parent = floor
	return e
end

-- Hide every deploying character (they hang above the square during the flight)
local function setDeployersHidden(hidden)
	for _, other in Players:GetPlayers() do
		if other.Character and (not hidden or other:GetAttribute("Deploying")) then
			for _, d in other.Character:GetDescendants() do
				if d:IsA("BasePart") or d:IsA("Decal") then
					d.LocalTransparencyModifier = if hidden then 1 else 0
				end
			end
		end
	end
end

-- First person on the character from here on (CameraController re-applies all of this on landing)
local function handOff(camera)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	camera.FieldOfView = GameConfig.Camera.FieldOfView
	camera.CameraType = Enum.CameraType.Custom
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

-- Hands in camera space: arms spread in freefall, up on the steering toggles under the canopy
local HANDS = {
	{ Shoulder = Vector3.new(-0.7, -1.2, 0.5), Free = Vector3.new(-1.1, -0.4, -1.7), Toggle = Vector3.new(-0.7, 1.4, -1.6) },
	{ Shoulder = Vector3.new(0.7, -1.2, 0.5), Free = Vector3.new(1.1, -0.4, -1.7), Toggle = Vector3.new(0.7, 1.4, -1.6) },
}

-- Out of the door until the landing, in first person: freefall looking down at the square, then the
-- server opens the canopy (MatchService:_parachute) with a jolt, you look up at it, and sway down
-- holding the toggles. Your own body and gun are hidden locally (no third-person fall pose or Tool
-- in view); everyone else still sees you, canopy and all.
local function dropView(camera, doorDir, Sound)
	local character = player.Character
	local root = character:FindFirstChild("HumanoidRootPart")
	local facing = (doorDir * Vector3.new(1, 0, 1)).Unit
	local fall = Sound:Loop("FallWind")
	fall:Play()
	local arms = {}
	for i, hand in HANDS do
		local sleeve = UIKit.new("Part", { Size = Vector3.new(0.4, 0.4, 1), Color = OLIVE, Material = Enum.Material.Fabric, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Parent = camera })
		local glove = UIKit.new("Part", { Size = Vector3.new(0.27, 0.27, 0.32), Color = DARK, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Parent = camera })
		arms[i] = { Hand = hand, Sleeve = sleeve, Glove = glove }
	end
	local start, openedAt = os.clock(), nil

	local function land()
		RunService:UnbindFromRenderStep("SAMZ_Drop")
		for _, arm in arms do
			arm.Sleeve:Destroy()
			arm.Glove:Destroy()
		end
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = 0
			end
		end
		TweenService:Create(fall, TweenInfo.new(0.8), { Volume = 0 }):Play()
		task.delay(0.9, fall.Destroy, fall)
		handOff(camera)
	end

	RunService:BindToRenderStep("SAMZ_Drop", Enum.RenderPriority.Camera.Value + 2, function()
		local now = os.clock()
		if player:GetAttribute("Deploying") ~= true or player:GetAttribute("InRun") ~= true or not root.Parent or now - start > 15 then
			land()
			return
		end
		local canopy = character:FindFirstChild("ParachuteCanopy")
		for _, d in character:GetDescendants() do
			if (d:IsA("BasePart") or d:IsA("Decal")) and not (canopy and d:IsDescendantOf(canopy)) then
				d.LocalTransparencyModifier = 1
			end
		end
		if canopy and not openedAt then
			openedAt = now
			Sound:Play("ParachuteOpen")
		end

		local open = if openedAt then smooth((now - openedAt) / 0.3) else 0
		local o = if openedAt then now - openedAt else 0
		local up = if openedAt then window(o, 0, 0.35, 1.3, 2.1) else 0 -- look up at the canopy
		local pitch = -0.95 + open * (0.55 + 1.65 * up)
		local jolt = if openedAt then math.exp(-o * 5) * math.sin(o * 22) * 0.7 else 0
		local shake = 0.03 * (1 - open) + 0.005
		fall.Volume = Sounds.Library.FallWind.Volume * (1 - 0.6 * open)
		camera.FieldOfView = 86 - 10 * open
		local head = root.Position + Vector3.new(0, 1.5 + jolt, 0)
		local camCF = CFrame.lookAt(head, head + facing)
			* CFrame.Angles(0, math.sin(now * 0.5) * 0.1 * open + math.noise(now * 9, 3) * shake, 0)
			* CFrame.Angles(pitch + math.noise(now * 9, 4) * shake, 0, math.sin(now * 0.9) * 0.06 * open)
		camera.CFrame = camCF

		for _, arm in arms do
			local hand = camCF * arm.Hand.Free:Lerp(arm.Hand.Toggle, open)
			local shoulder = camCF * arm.Hand.Shoulder
			-- forearm only: a full arm passes right by the lens and fills the screen
			local elbow = hand + (shoulder - hand).Unit * 1.1
			arm.Sleeve.Size = Vector3.new(0.24, 0.24, 1.1)
			arm.Sleeve.CFrame = CFrame.lookAt((hand + elbow) / 2, hand)
			arm.Glove.CFrame = CFrame.lookAt(hand, hand + (hand - shoulder))
		end
	end)
end

function CutsceneController:Play()
	local start, duration = GameState:GetAttribute("DeployStart"), GameState:GetAttribute("DeployDuration")
	local ok, raw = pcall(HttpService.JSONDecode, HttpService, GameState:GetAttribute("DeployPath") or "")
	if playing or not ok or type(raw) ~= "table" or #raw < 4 or not start or not duration then
		return
	end
	playing = true
	local points = {}
	for i, p in raw do
		points[i] = Vector3.new(p[1], p[2], p[3])
	end

	local camera = workspace.CurrentCamera
	local folder, parts = buildHelicopter()
	local ui = overlay()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 70
	local heliCF = CFrame.lookAt(points[1], points[2])
	local pose = {}
	local Sound = Controllers.SoundController
	local loops = {}
	for _, name in { "CabinWind", "SeaWash", "PilotChatter" } do
		loops[name] = Sound:Loop(name)
		loops[name].Volume = 0
		loops[name]:Play()
	end
	local spray, sprayEmitter = seaSpray()
	local streaks = windStreaks(folder.Floor)
	local played = {} -- CUES already fired

	local function finish()
		RunService:UnbindFromRenderStep("SAMZ_Cutscene")
		setDeployersHidden(false)
		for _, loop in loops do
			loop:Destroy()
		end
		spray:Destroy()
		streaks.Enabled = false
		if player:GetAttribute("Deploying") and player.Character then
			dropView(camera, heliCF.RightVector, Sound)
		else
			handOff(camera)
		end
		for _, child in ui.Gui:GetChildren() do
			if child:IsA("Frame") then
				TweenService:Create(child, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
			elseif child:IsA("TextLabel") then
				child.TextTransparency = 1
			end
		end
		task.delay(0.7, function()
			ui.Gui:Destroy()
		end)
		-- the helicopter peels away and climbs out of sight
		local leaveStart = os.clock()
		local leaving
		leaving = RunService.Heartbeat:Connect(function()
			local age = os.clock() - leaveStart
			if age > 6 then
				leaving:Disconnect()
				folder:Destroy()
				return
			end
			local cf = heliCF * CFrame.Angles(0, -age * 0.25, 0) * CFrame.new(0, age * age * 1.5, -age * age * 4) * CFrame.Angles(-0.2, 0, 0)
			placeHelicopter(parts, cf, workspace:GetServerTimeNow(), pose)
		end)
		playing = false
	end

	RunService:BindToRenderStep("SAMZ_Cutscene", Enum.RenderPriority.Camera.Value + 2, function()
		local now = workspace:GetServerTimeNow()
		local t = math.clamp((now - start) / duration, 0, 1)
		if t >= 1 or player:GetAttribute("InRun") ~= true or player:GetAttribute("Deploying") ~= true then
			finish()
			return
		end
		setDeployersHidden(true)

		-- flight: already cruising at the start, easing into the hover at FLY_END
		local x = math.min(t / FLY_END, 1)
		local s = 1 - (1 - x) * (1 - x)
		local pos = pathAt(points, s)
		-- heading/turn from three distinct samples (capped so they never coincide at the hover point)
		local sc = math.min(s, 0.94)
		local a, b, c = pathAt(points, sc), pathAt(points, sc + 0.03), pathAt(points, sc + 0.06)
		local heading = ((b - a) * Vector3.new(1, 0, 1)).Unit
		local turn = heading:Cross(((c - b) * Vector3.new(1, 0, 1)).Unit).Y
		local speed = 1 - x -- 1 at the start, 0 in the hover
		local bob = Vector3.new(0, math.sin(now * 1.4) * 0.5 * (1 - speed), 0)
		heliCF = CFrame.lookAt(pos + bob, pos + bob + heading)
			* CFrame.Angles(-0.12 * speed, 0, math.clamp(turn * 4, -0.35, 0.35) + math.sin(now * 1.1) * 0.02)

		-- the pilot turns round, thumbs-up, turns back
		pose.Head = CFrame.Angles(0.15 * window(t, 0.79, 0.83, 0.92, 0.95), 2.1 * window(t, 0.79, 0.83, 0.92, 0.95), 0)
		local arm = window(t, 0.82, 0.85, 0.91, 0.94)
		pose.Arm = CFrame.Angles(1.3 * arm, 0.6 * arm, 0)
		placeHelicopter(parts, heliCF, now, pose)

		-- sound + effects: door wind swells while you lean out and at the jump, the sea while low
		local doorWind = window(t, 0.5, 0.56, 0.7, 0.76) + window(t, 0.93, 0.96, 1, 1.01)
		local seaNear = math.clamp((60 - pos.Y) / 35, 0, 1)
		loops.CabinWind.Volume = Sounds.Library.CabinWind.Volume * (0.5 + 0.5 * speed + doorWind)
		loops.CabinWind.PlaybackSpeed = 0.9 + 0.2 * speed
		loops.SeaWash.Volume = Sounds.Library.SeaWash.Volume * seaNear
		loops.PilotChatter.Volume = Sounds.Library.PilotChatter.Volume * window(t, 0.03, 0.08, 0.74, 0.79)
		spray.WorldPosition = Vector3.new(pos.X, 1, pos.Z)
		sprayEmitter.Rate = 140 * seaNear
		streaks.Rate = 30 * (speed + doorWind)
		for _, c in CUES do
			if t >= c[1] and t - c[1] < 0.02 and not played[c] then
				played[c] = true
				Sound:Play(c[2])
			end
		end

		local yaw, pitch, seat = camPose(t)
		local shake = 0.006 + 0.004 * speed + 0.012 * doorWind
		camera.FieldOfView = 70 + 12 * smooth((t - 0.95) / 0.05)
		camera.CFrame = heliCF
			* CFrame.new(seat)
			* CFrame.Angles(0, yaw + math.noise(now * 7, 1) * shake, 0)
			* CFrame.Angles(pitch + math.noise(now * 7, 2) * shake, 0, 0)

		ui.Fade.BackgroundTransparency = 1 - (1 - smooth(t / 0.05)) - smooth((t - 0.965) / 0.03)
		local titleIn = 1 - window(t, 0.28, 0.33, 0.52, 0.57)
		local lineIn = 1 - window(t, 0.82, 0.84, 0.93, 0.95)
		-- strokes ignore TextTransparency, so hidden labels are made invisible too
		for label, value in { [ui.Title] = titleIn, [ui.Sub] = titleIn, [ui.Line] = lineIn } do
			label.TextTransparency = value
			label.Visible = value < 0.98
		end
	end)
end

function CutsceneController:Init(controllers)
	Controllers = controllers
	player:GetAttributeChangedSignal("Deploying"):Connect(function()
		if player:GetAttribute("Deploying") then
			task.spawn(self.Play, self)
		end
	end)
end

return CutsceneController
