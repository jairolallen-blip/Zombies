-- BossController: the client side of the final boss (vault: Waves and Boss.md, Nightmare Mode.md).
--   intro      Effect "BossIntro" (MatchService:_bossIntro): letterboxed camera shots while the boss
--              claws out of the ground at the BossSpawn marker, a close-up roar with shake, FOV punch,
--              red flash and title card, then a fade back to first person. CameraController stands down
--              while the player has the BossIntro attribute. Intro.Style "Bloom" (the Nightmare boss) also
--              turns the sky sick green and has it tear out of a giant pulsing pod.
--   music      tense drums under the intro; the boss track fades in when the intro ends and fades out
--              when the boss dies or the run ends (GameState BossName)
--   attacks    roar on "BossCharge" / "BossLeap"; "BossKnock" shoves your character (you own its physics).
--              Bloom Mother (ZombieService:_spores, :_bloomBurst): "SporeVolley" lobs glowing pods that burst
--              into poison clouds; "BloomBurst" fills its red ring in from the middle with a countdown over
--              its head and GET CLEAR on screen while you're inside; "BloomBlast" is the explosion.
--   death      Effect "BossDeath" (MatchService:_bossDeath): circles the swelling body, which bursts into a
--              column of spores at BurstAt while the green sky clears, then hands the camera back.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared.Config.Sounds)
local Zombies = require(Shared.Config.Zombies)
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)
local GameState = require(Shared.GameState)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local player = Players.LocalPlayer
local BossController = {}
local Controllers
local music -- boss track (looped Sound from SoundController)

local POD = Color3.fromRGB(205, 255, 90)
local FLAT = CFrame.Angles(0, 0, math.rad(90)) -- lays a cylinder flat on the ground

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function fade(sound, volume, seconds)
	TweenService:Create(sound, TweenInfo.new(seconds), { Volume = volume }):Play()
end

-- local effect part (anchored, no collision); parent defaults to the camera
local function fxPart(props, parent)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent or workspace.CurrentCamera
	return p
end

local function sporeEmitter(parent, rate)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(205, 245, 115), Color3.fromRGB(110, 140, 60))
	e.LightEmission = 0.45
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.55), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new(2, 6)
	e.Lifetime = NumberRange.new(2, 4)
	e.Rate = rate
	e.Speed = NumberRange.new(2, 6)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, 2, 0)
	e.Parent = parent
	return e
end

-- chunks flung out of a burst (unanchored local parts; they fall and roll, then go)
local function fling(center, color, count, size, speed)
	for i = 1, count do
		local a = i / count * math.pi * 2
		local chunk = fxPart({ Size = Vector3.new(1, 0.7, 0.9) * size * (0.6 + math.random() * 0.8), CFrame = CFrame.new(center + Vector3.new(math.cos(a), 0.5, math.sin(a)) * size), Color = color, Material = Enum.Material.SmoothPlastic }, workspace)
		chunk.Anchored, chunk.CanCollide = false, true
		chunk.AssemblyLinearVelocity = Vector3.new(math.cos(a), 0.9 + math.random() * 0.8, math.sin(a)) * speed
		chunk.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 12
		task.delay(3.5, function()
			TweenService:Create(chunk, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end)
		task.delay(4.1, chunk.Destroy, chunk)
	end
end

-- a sick green sky over the Nightmare boss fight; cleared at its death burst or when the run ends
local tint
local function setTint(on, seconds)
	if on and not tint then
		tint = Instance.new("ColorCorrectionEffect")
		tint.Name = "BloomTint"
		tint.Parent = Lighting
		TweenService:Create(tint, TweenInfo.new(seconds), { TintColor = Color3.fromRGB(205, 255, 175), Saturation = -0.15, Contrast = 0.08 }):Play()
	elseif not on and tint then
		local old = tint
		tint = nil
		TweenService:Create(old, TweenInfo.new(seconds), { TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0 }):Play()
		task.delay(seconds + 0.1, old.Destroy, old)
	end
end

local function overlay(title, sub)
	local gui = UIKit.Screen("BossIntro")
	gui.DisplayOrder = 20
	local o = { Gui = gui, Bars = {} }
	for _, top in { true, false } do
		table.insert(o.Bars, UIKit.new("Frame", {
			AnchorPoint = Vector2.new(0, if top then 0 else 1),
			Position = UDim2.fromScale(0, if top then 0 else 1),
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundColor3 = Color3.new(),
			BorderSizePixel = 0,
			Parent = gui,
		}))
	end
	o.Flash = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(170, 20, 10), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui })
	o.Fade = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5, Parent = gui })
	-- title card low, over the bottom letterbox bar, so it never covers the boss
	local text = UIKit.new("Frame", { BackgroundTransparency = 1, ZIndex = 2, Parent = gui })
	UIKit.AutoScale(text)
	o.Title = UIKit.Label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.86), Size = UDim2.fromOffset(900, 70), Text = title, TextSize = 60, TextColor3 = Color3.fromRGB(255, 70, 50), TextTransparency = 1, ZIndex = 2, Parent = text })
	o.Sub = UIKit.Label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.945), Size = UDim2.fromOffset(700, 30), Text = sub, TextSize = 24, TextTransparency = 1, ZIndex = 2, Parent = text })
	return o
end

-- every other screen (HUD, radio, crosshair) is off for a cutscene; returns them to turn back on
local function hideScreens(ui)
	local hidden = {}
	for _, gui in player:WaitForChild("PlayerGui"):GetChildren() do
		if gui:IsA("ScreenGui") and gui.Enabled and gui ~= ui.Gui then
			hidden[gui] = true
			gui.Enabled = false
		end
	end
	return hidden
end

-- end of a cutscene: first person again, levelled at P from the head (the default camera resumes from the
-- last CFrame, which may be pitched at the boss), screens back on, overlay faded out
local function handBack(P, hidden, ui)
	local camera = workspace.CurrentCamera
	camera.FieldOfView = GameConfig.Camera.FieldOfView
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local head = root.Position + Vector3.new(0, 1.5, 0)
		camera.CFrame = CFrame.lookAt(head, Vector3.new(P.X, head.Y, P.Z))
	end
	camera.CameraType = Enum.CameraType.Custom
	for gui in hidden do
		gui.Enabled = true
	end
	TweenService:Create(ui.Fade, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	task.delay(0.6, ui.Gui.Destroy, ui.Gui)
end

-- "Bloom" intro: the sky turns sick green, a giant pod pushes up out of the street, swelling and pulsing
-- faster, then splits open just as the boss starts to rise out of it (MatchService spawns it at RiseAt)
local function bloomIntro(data, H)
	local P = data.Position
	setTint(true, 2)
	local motes = fxPart({ Size = Vector3.new(60, 1, 60), CFrame = CFrame.new(P), Transparency = 1 })
	sporeEmitter(motes, 25)
	task.delay(data.Time + 2, motes.Destroy, motes)
	local r = H * 0.42
	local pod = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one, Color = Color3.fromRGB(84, 100, 52), Material = Enum.Material.SmoothPlastic })
	local light = Instance.new("PointLight")
	light.Color = POD
	light.Range = 40
	light.Parent = pod
	local glows = {}
	for i = 1, 10 do
		local dir = Vector3.new(math.cos(i * 2.4), -0.2 + (i % 4) * 0.35, math.sin(i * 2.4)).Unit
		table.insert(glows, { Dir = dir, Part = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * r * (0.22 + (i % 3) * 0.08), Color = POD, Material = Enum.Material.Neon }) })
	end
	local burstAt = data.RiseAt + 0.15
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local u = smooth(t / burstAt)
		local beat = 1 + 0.07 * math.max(0, math.sin(t * (5 + 10 * u))) -- a heartbeat that quickens
		local size = r * (0.75 + 0.35 * u) * beat
		local center = P + Vector3.new(0, -r * 1.2 + r * 1.35 * u, 0) -- pushes up out of the street
		pod.Size = Vector3.one * size * 2
		pod.CFrame = CFrame.new(center)
		for _, g in glows do
			g.Part.CFrame = CFrame.new(center + g.Dir * size * 0.93)
		end
		light.Brightness = 1.5 + 40 * (beat - 1)
		if t < burstAt then
			return
		end
		conn:Disconnect()
		-- it splits open: shell flung out, a cloud of spores, a wet blast
		pod:Destroy()
		for _, g in glows do
			g.Part:Destroy()
		end
		fling(center, Color3.fromRGB(84, 100, 52), 12, r * 0.5, 45)
		local burst = sporeEmitter(fxPart({ Size = Vector3.one, CFrame = CFrame.new(center), Transparency = 1 }), 0)
		burst.Speed = NumberRange.new(15, 35)
		burst.Size = NumberSequence.new(4, 12)
		burst:Emit(120)
		task.delay(5, burst.Parent.Destroy, burst.Parent)
		Controllers.SoundController:PlayAt("Explosion", center, { Pitch = 0.55 })
		Controllers.EffectsController:Shake(0.6, 0.6)
	end)
end

local skipIntro = nil -- set while an intro plays

function BossController:PlayIntro(data)
	local camera = workspace.CurrentCamera
	local Sound = Controllers.SoundController
	local def = Zombies.Types[data.TypeId or Zombies.BossOrder[1]]
	local bloom = def.Intro.Style == "Bloom"
	local ui = overlay(string.upper(def.DisplayName), if bloom then "NIGHTMARE  ·  KILL IT AND IT ALL DIES" else "FINAL WAVE  ·  BRING IT DOWN")
	local hidden = hideScreens(ui)
	local drums = Sound:Loop("BossIntroDrums")
	drums.Volume = 0
	drums:Play()
	fade(drums, Sounds.Library.BossIntroDrums.Volume, 1)

	local P = data.Position
	local C = GameConfig.OurMap.ArenaCenter
	local dir = Vector3.new(P.X - C.X, 0, P.Z - C.Z).Unit -- square -> boss
	local side = dir:Cross(Vector3.yAxis)
	local up = Vector3.yAxis
	local H = 5.5 * (def.Scale or 1) -- boss height
	if bloom then
		bloomIntro(data, H)
	end
	local start = os.clock()
	skipIntro = function() -- the squad skipped it: jump to the fade-out
		start = math.min(start, os.clock() - (data.Time - 0.4))
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local roared = false

	RunService:BindToRenderStep("SAMZ_BossIntro", Enum.RenderPriority.Camera.Value + 10, function()
		local t = os.clock() - start
		local rise = smooth((t - data.RiseAt) / data.RiseTime)
		local from, look
		if t < data.RiseAt then -- high over the square, pushing down the avenue
			local u = smooth(t / data.RiseAt)
			from = C + up * (30 - 6 * u) + dir * (-10 + 18 * u)
			look = P + up * 2
		elseif t < data.RoarAt - 0.4 then -- low in front as it claws out
			local u = (t - data.RiseAt) / (data.RoarAt - 0.4 - data.RiseAt)
			from = P - dir * (27 - 6 * u) + side * (7 - 3 * u) + up * (2.5 + u)
			look = P + up * (H * 0.65 * rise)
		else -- close-up on the roar
			from = P - dir * 24 + side * 3 + up * (H * 0.5)
			look = P + up * (H * 0.7)
		end
		local shake = 0.02 * rise + (if t >= data.RoarAt then 0.12 * math.max(0, 1 - (t - data.RoarAt) / 1.4) else 0)
		camera.CFrame = CFrame.lookAt(from, look)
			* CFrame.Angles(math.noise(t * 12, 1) * shake, math.noise(t * 12, 2) * shake, math.noise(t * 12, 3) * shake)
		camera.FieldOfView = 70 + 16 * (if t >= data.RoarAt then math.max(0, 1 - (t - data.RoarAt) / 0.6) else 0)

		local bars = smooth(t / 0.6) * (1 - smooth((t - data.Time + 0.3) / 0.3))
		for _, bar in ui.Bars do
			bar.Size = UDim2.new(1, 0, 0.11 * bars, 0)
		end
		ui.Flash.BackgroundTransparency = if t >= data.RoarAt then 0.45 + 0.55 * math.min(1, (t - data.RoarAt) / 0.5) else 1
		local title = 1 - smooth((t - data.RoarAt - 0.1) / 0.3) * (1 - smooth((t - data.Time + 0.7) / 0.4))
		ui.Title.TextTransparency, ui.Sub.TextTransparency = title, title
		ui.Title.Visible, ui.Sub.Visible = title < 0.98, title < 0.98
		ui.Fade.BackgroundTransparency = 1 - smooth((t - data.Time + 0.35) / 0.35)
		if t >= data.RoarAt and not roared then
			roared = true
			Controllers.EffectsController:Shake(1, 0.8)
		end
		if t >= data.Time then
			RunService:UnbindFromRenderStep("SAMZ_BossIntro")
			handBack(P, hidden, ui)
			fade(drums, 0, 1.2)
			task.delay(1.3, drums.Destroy, drums)
		end
	end)
end

-- Nightmare boss death (MatchService:_bossDeath): the camera circles the body as it swells and shudders,
-- it bursts into a column of spores at BurstAt, the camera follows them up as the green sky clears to dawn.
function BossController:PlayDeath(data)
	local camera = workspace.CurrentCamera
	local Sound = Controllers.SoundController
	local ui = overlay("THE BLOOM MOTHER IS DEAD", "AND EVERYTHING IT GREW DIES WITH IT")
	local hidden = hideScreens(ui)
	local P = data.Position
	local H = 5.5 * data.Scale
	local corpse = data.Corpse
	local pivot = corpse and corpse.Parent and corpse:GetPivot()
	local glow
	if pivot then
		glow = Instance.new("Highlight")
		glow.FillColor = POD
		glow.OutlineColor = Color3.fromRGB(255, 255, 200)
		glow.Parent = corpse
	end
	Sound:PlayAt("BossRoar", P, { Pitch = 0.55 }) -- its dying wail
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local away = if root then Vector3.new(root.Position.X - P.X, 0, root.Position.Z - P.Z) else Vector3.xAxis
	local angle0 = math.atan2(away.Z, away.X)
	local start = os.clock()
	local burst = false
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep("SAMZ_BossDeath", Enum.RenderPriority.Camera.Value + 10, function()
		local t = os.clock() - start
		local swell = smooth(t / data.BurstAt)
		local angle = angle0 + t * 0.22
		local orbit = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local from, look
		if t < data.BurstAt then -- circling as it swells and shudders
			from = P + orbit * H * (2.4 - 0.4 * swell) + Vector3.yAxis * H * 0.35
			look = P + Vector3.yAxis * H * 0.15
			if pivot and corpse.Parent then
				local j = 0.08 * swell * (data.Scale or 1)
				corpse:ScaleTo(1 + 0.3 * swell)
				corpse:PivotTo(pivot * CFrame.new(math.noise(t * 20, 1) * j, 0, math.noise(t * 20, 2) * j))
				glow.FillTransparency = 0.85 - 0.6 * swell + 0.15 * math.sin(t * (6 + 20 * swell))
			end
		else -- pull back and follow the spores up into the clearing sky
			local u = t - data.BurstAt
			from = P + orbit * H * (2 + 0.5 * u) + Vector3.yAxis * H * (0.35 + 0.15 * u)
			look = P + Vector3.yAxis * (H * 0.3 + u * 9)
		end
		local shake = 0.03 * swell + (if burst then 0.1 * math.max(0, 1 - (t - data.BurstAt) / 1.2) else 0)
		camera.CFrame = CFrame.lookAt(from, look) * CFrame.Angles(math.noise(t * 14, 1) * shake, math.noise(t * 14, 2) * shake, 0)
		if t >= data.BurstAt and not burst then
			burst = true
			if corpse and corpse.Parent then
				for _, d in corpse:GetDescendants() do
					if d:IsA("BasePart") then
						d.Transparency = 1
					elseif d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Highlight") then
						d.Enabled = false
					end
				end
			end
			fling(P, Color3.fromRGB(118, 128, 86), 14, 2.2, 55)
			local column = fxPart({ Size = Vector3.new(6, 1, 6), CFrame = CFrame.new(P), Transparency = 1 })
			local spores = sporeEmitter(column, 90)
			spores.EmissionDirection = Enum.NormalId.Top
			spores.SpreadAngle = Vector2.new(35, 35)
			spores.Speed = NumberRange.new(14, 34)
			spores.Drag = 0.5
			spores.Acceleration = Vector3.new(0, 5, 0)
			spores.Lifetime = NumberRange.new(5, 7)
			spores.Size = NumberSequence.new(4, 14)
			spores:Emit(160)
			task.delay(1.6, function()
				spores.Enabled = false
			end)
			task.delay(9, column.Destroy, column)
			local flash = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 6, CFrame = CFrame.new(P), Color = POD, Material = Enum.Material.Neon, Transparency = 0.2 })
			TweenService:Create(flash, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * 50, Transparency = 1 }):Play()
			task.delay(0.8, flash.Destroy, flash)
			Sound:PlayAt("Explosion", P, { Pitch = 0.5 })
			Controllers.EffectsController:Shake(1.2, 1)
			setTint(false, data.Time - data.BurstAt) -- the sky clears (MatchService fades the clock to dawn)
		end
		local bars = smooth(t / 0.5) * (1 - smooth((t - data.Time + 0.3) / 0.3))
		for _, bar in ui.Bars do
			bar.Size = UDim2.new(1, 0, 0.11 * bars, 0)
		end
		local title = 1 - smooth((t - data.BurstAt - 1.2) / 0.4) * (1 - smooth((t - data.Time + 0.7) / 0.4))
		ui.Title.TextTransparency, ui.Sub.TextTransparency = title, title
		ui.Title.Visible, ui.Sub.Visible = title < 0.98, title < 0.98
		ui.Fade.BackgroundTransparency = 1 - smooth((t - data.Time + 0.35) / 0.35)
		if t >= data.Time then
			RunService:UnbindFromRenderStep("SAMZ_BossDeath")
			handBack(P, hidden, ui)
		end
	end)
end

-- a spore pod lands: a wet burst, then a poison cloud over the red circle for `seconds`
local function sporeCloud(pos, radius, seconds)
	Controllers.SoundController:PlayAt("Slam", pos, { Pitch = 1.5, Volume = 0.6 })
	local holder = fxPart({ Size = Vector3.new(radius * 1.6, 2, radius * 1.6), CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0)), Transparency = 1 })
	local cloud = sporeEmitter(holder, 30)
	cloud.Speed = NumberRange.new(0.5, 2)
	cloud.Size = NumberSequence.new(3, 7)
	cloud.Lifetime = NumberRange.new(1.5, 2.5)
	cloud:Emit(40)
	local disc = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, radius * 2, radius * 2), CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)) * FLAT, Color = Color3.fromRGB(150, 200, 60), Material = Enum.Material.Neon, Transparency = 0.65 })
	task.delay(seconds, function()
		cloud.Enabled = false
		TweenService:Create(disc, TweenInfo.new(1), { Transparency = 1 }):Play()
	end)
	task.delay(seconds + 1.1, disc.Destroy, disc)
	task.delay(seconds + 3, holder.Destroy, holder)
end

-- it rears back with a shriek, then glowing pods arc out of its sac onto the red circles
local function sporeVolley(data)
	local model = data.Model
	if not (model and model.Parent) then
		return
	end
	local s = Zombies.Types[model.Name] and Zombies.Types[model.Name].Scale or 1
	Controllers.SoundController:PlayAt("BossRoar", model:GetPivot().Position, { Pitch = 1.35, Volume = 0.6 })
	task.wait(data.Windup)
	local from = (if model.Parent then model:GetPivot().Position else data.Landings[1]) + Vector3.new(0, 4.5 * s, 0)
	for _, land in data.Landings do
		local pod = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4, CFrame = CFrame.new(from), Color = POD, Material = Enum.Material.Neon })
		local trail = sporeEmitter(pod, 40)
		trail.Size = NumberSequence.new(1.5, 3)
		trail.Lifetime = NumberRange.new(0.6, 1)
		trail.Speed = NumberRange.new(0, 1)
		local height = 18 + (land - from).Magnitude * 0.25
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local u = math.min((os.clock() - t0) / data.Flight, 1)
			pod.CFrame = CFrame.new(from:Lerp(land, u) + Vector3.new(0, height * 4 * u * (1 - u), 0))
			if u < 1 then
				return
			end
			conn:Disconnect()
			pod.Transparency = 1
			trail.Enabled = false
			task.delay(1.2, pod.Destroy, pod)
			sporeCloud(land, data.Radius, data.Cloud)
		end)
	end
end

-- Bloom Burst windup: the danger fills its red ring from the middle, it swells inside a pulsing glow, a
-- countdown hangs over it, and GET CLEAR flashes on your screen while you're inside the ring
local function bloomBurst(data)
	local model = data.Model
	if not (model and model.Parent and model.PrimaryPart) then
		return
	end
	local Sound = Controllers.SoundController
	local P, R, W = data.Position, data.Radius, data.Windup
	local s = Zombies.Types[model.Name] and Zombies.Types[model.Name].Scale or 1
	local fill = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.18, 1, 1), CFrame = CFrame.new(P + Vector3.new(0, 0.18, 0)) * FLAT, Color = Color3.fromRGB(255, 110, 40), Material = Enum.Material.Neon, Transparency = 0.55 })
	local swell = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one, Color = POD, Material = Enum.Material.Neon, Transparency = 0.8 })
	local glow = Instance.new("Highlight")
	glow.FillColor = POD
	glow.OutlineColor = Color3.fromRGB(255, 90, 40)
	glow.Parent = model
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(160, 120)
	board.AlwaysOnTop = true
	board.StudsOffsetWorldSpace = Vector3.new(0, 6.5 * s, 0)
	board.Adornee = model.PrimaryPart
	board.Parent = player:WaitForChild("PlayerGui")
	local count = UIKit.Label({ Size = UDim2.fromScale(1, 1), TextSize = 96, TextColor3 = Color3.fromRGB(255, 80, 40), Parent = board })
	local warn = UIKit.Screen("BloomWarning")
	local text = UIKit.new("Frame", { BackgroundTransparency = 1, Parent = warn })
	UIKit.AutoScale(text)
	local label = UIKit.Label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(700, 60), Text = "GET CLEAR!", TextSize = 54, TextColor3 = Color3.fromRGB(255, 80, 40), Visible = false, Parent = text })
	Sound:PlayAt("BossRoar", P, { Pitch = 0.7 })
	local t0, shown = os.clock(), nil
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local u = math.min(t / W, 1)
		local pulse = math.sin(t * (5 + 22 * u))
		fill.Size = Vector3.new(0.18, R * 2 * u, R * 2 * u)
		if model.Parent then
			swell.Size = Vector3.one * (5 + 4 * u + 0.6 * pulse) * s
			swell.CFrame = CFrame.new(model:GetPivot().Position + Vector3.new(0, 0.5 * s, 0))
		end
		glow.FillTransparency = math.clamp(0.75 - 0.5 * u + 0.15 * pulse, 0, 1)
		local n = math.ceil(W - t)
		if n ~= shown and n > 0 then
			shown = n
			count.Text = tostring(n)
			Sound:PlayAt("Click", P, { Pitch = 0.7 })
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		label.Visible = root ~= nil and Vector3.new(root.Position.X - P.X, 0, root.Position.Z - P.Z).Magnitude <= R and pulse > -0.3
		if u >= 1 or not model.Parent then
			conn:Disconnect()
			fill:Destroy()
			swell:Destroy()
			glow:Destroy()
			board:Destroy()
			warn:Destroy()
		end
	end)
end

-- the Bloom Burst goes off: a green blast filling the ring and a ring of spores rolling out
local function bloomBlast(data)
	local P, R = data.Position, data.Radius
	Controllers.SoundController:PlayAt("Explosion", P, { Pitch = 0.6 })
	local ball = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 6, CFrame = CFrame.new(P), Color = POD, Material = Enum.Material.Neon, Transparency = 0.3 })
	TweenService:Create(ball, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * R * 2, Transparency = 1 }):Play()
	task.delay(0.6, ball.Destroy, ball)
	local holder = fxPart({ Size = Vector3.new(R * 1.6, 1, R * 1.6), CFrame = CFrame.new(P + Vector3.new(0, 1, 0)), Transparency = 1 })
	local dust = sporeEmitter(holder, 0)
	dust.Speed = NumberRange.new(4, 12)
	dust.Size = NumberSequence.new(4, 10)
	dust:Emit(70)
	task.delay(5, holder.Destroy, holder)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local near = root and (root.Position - P).Magnitude <= R * 1.6
	Controllers.EffectsController:Shake(if near then 1.2 else 0.4, if near then 0.7 else 0.4)
end

function BossController:Init(controllers)
	Controllers = controllers
	Remotes.Effect.OnClientEvent:Connect(function(kind, data)
		if type(data) ~= "table" then
			return
		end
		if kind == "BossIntro" then
			task.spawn(self.PlayIntro, self, data)
		elseif kind == "BossDeath" then
			task.spawn(self.PlayDeath, self, data)
		elseif kind == "CutsceneSkip" and data.Kind == "BossIntro" and skipIntro then
			skipIntro()
		elseif kind == "BossCharge" or kind == "BossLeap" then
			Controllers.SoundController:PlayAt("BossRoar", data.Position, { Pitch = if kind == "BossLeap" then 1.15 else 1 })
		elseif kind == "SporeVolley" then
			task.spawn(sporeVolley, data)
		elseif kind == "BloomBurst" then
			bloomBurst(data)
		elseif kind == "BloomBlast" then
			bloomBlast(data)
		elseif kind == "BossKnock" then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				root.AssemblyLinearVelocity = data.Velocity
			end
		end
	end)
end

function BossController:Start()
	RunService.Heartbeat:Connect(function()
		local bossAlive = (GameState:GetAttribute("BossName") or "") ~= "" and player:GetAttribute("InRun") == true
		if bossAlive and not music and player:GetAttribute("BossIntro") ~= true then
			music = Controllers.SoundController:Loop("BossMusic")
			music.Volume = 0
			music:Play()
			fade(music, Sounds.Library.BossMusic.Volume, 3)
		elseif music and not bossAlive then
			local old = music
			music = nil
			fade(old, 0, 2.5)
			task.delay(2.6, old.Destroy, old)
		end
		-- the green sky outlives the boss only for its death scene (which clears it); a lost run clears it too
		if tint and (GameState:GetAttribute("Phase") ~= "Wave" or player:GetAttribute("InRun") ~= true) then
			setTint(false, 2)
		end
	end)
end

return BossController
