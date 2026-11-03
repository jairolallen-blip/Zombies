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
--              into poison clouds; "BloomBurst" (its ultimate) is a riser, rumble and quickening thumps while
--              spores stream in and its red ring fills with a countdown and GET CLEAR; "BloomBlast" is the
--              explosion (core flash, shockwaves, spore column and ring) and the spore field it leaves.
--   death      Effect "BossDeath" (MatchService:_bossDeath): it staggers to its knees while bits of it burst
--              off, then goes up in a huge spore explosion at BurstAt as the green sky clears.

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

-- a chunk of the body bursts off (death scene): a green pop, a puff of spores, a few bits flung, a wet crack
local function pop(pos, size)
	local Sound = Controllers.SoundController
	local ball = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = CFrame.new(pos), Color = POD, Material = Enum.Material.Neon, Transparency = 0.1 })
	TweenService:Create(ball, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * size * 3.2, Transparency = 1 }):Play()
	task.delay(0.4, ball.Destroy, ball)
	local puff = sporeEmitter(fxPart({ Size = Vector3.one, CFrame = CFrame.new(pos), Transparency = 1 }), 0)
	puff.Speed = NumberRange.new(6, 16)
	puff.Size = NumberSequence.new(2, 6)
	puff:Emit(30)
	task.delay(4.5, puff.Parent.Destroy, puff.Parent)
	fling(pos, Color3.fromRGB(118, 128, 86), 5, size * 0.35, 30)
	Sound:PlayAt("Slam", pos, { Pitch = 1.6, Volume = 0.7 })
	Sound:PlayAt("Explosion", pos, { Pitch = 1.45, Volume = 0.45 })
	Controllers.EffectsController:Shake(0.35, 0.25)
end

-- Nightmare boss death (MatchService:_bossDeath), owner design 2026-11-03: it staggers and sways, sinking to its
-- knees, while bits of it burst off one after another (pops, spores, flung chunks), each one quicker than the
-- last; a rising roar of noise sucks it in tight, then at BurstAt it goes up in a huge spore explosion (white
-- flash, shockwaves, a spore column and a rolling ring of spores) and the camera follows the spores up as the
-- green sky clears to dawn.
local POPS = { 0.2, 0.33, 0.44, 0.54, 0.62, 0.69, 0.75, 0.8, 0.85, 0.89, 0.92 } -- fractions of BurstAt
function BossController:PlayDeath(data)
	local camera = workspace.CurrentCamera
	local Sound = Controllers.SoundController
	local ui = overlay("THE BLOOM MOTHER IS DEAD", "AND EVERYTHING IT GREW DIES WITH IT")
	ui.Flash.BackgroundColor3 = Color3.fromRGB(235, 255, 215)
	local hidden = hideScreens(ui)
	local P = data.Position
	local H = 5.5 * data.Scale
	local B = data.BurstAt
	local corpse = data.Corpse
	local pivot = corpse and corpse.Parent and corpse:GetPivot()
	local glow, bits, limbs = nil, {}, {}
	local corpseRoot = corpse and corpse:FindFirstChild("Root")
	local scale0 = pivot and corpse:GetScale()
	if pivot then
		-- the server anchored every part, so the body would hold its walk pose (arms straight out); each frame
		-- the limbs are placed by hand through their Motor6D (C0 * pose * C1^-1), with the parts welded to them
		if corpseRoot then
			for _, n in { "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
				local motor = corpseRoot:FindFirstChild(n)
				local limb = motor and motor:IsA("Motor6D") and motor.Part1
				if limb then
					local attached = {}
					for _, d in corpse:GetDescendants() do
						local other = if not d:IsA("JointInstance") then nil elseif d.Part0 == limb then d.Part1 elseif d.Part1 == limb then d.Part0 else nil
						if other and other ~= corpseRoot then
							table.insert(attached, { Part = other, Offset = limb.CFrame:ToObjectSpace(other.CFrame) })
						end
					end
					limbs[n] = { Motor = motor, Limb = limb, Attached = attached }
				end
			end
		end
		glow = Instance.new("Highlight")
		glow.FillColor = POD
		glow.OutlineColor = Color3.fromRGB(255, 255, 200)
		glow.Parent = corpse
		for _, d in corpse:GetDescendants() do -- the small parts (pods, tendrils, fungus) are what bursts off
			if d:IsA("BasePart") and d.Transparency < 1 and math.max(d.Size.X, d.Size.Y, d.Size.Z) < H * 0.3 then
				table.insert(bits, d)
			end
		end
	end
	Sound:PlayAt("BossRoar", P, { Pitch = 0.55 }) -- its dying wail
	task.delay(0.4, Sound.Play, Sound, "BloomDeathGroan")
	task.delay(math.max(0, B - 5.75), Sound.Play, Sound, "BloomDeathRiser") -- its hard end lands on the burst
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local away = if root then Vector3.new(root.Position.X - P.X, 0, root.Position.Z - P.Z) else Vector3.xAxis
	local angle0 = math.atan2(away.Z, away.X)
	local start = os.clock()
	local burst, popped, jolt, kick = false, 0, 0, 0
	local last = start
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep("SAMZ_BossDeath", Enum.RenderPriority.Camera.Value + 10, function()
		local now = os.clock()
		local t, dt = now - start, now - last
		last = now
		jolt = math.max(0, jolt - dt * 4)
		kick = math.max(0, kick - dt * 3)
		local swell = smooth(t / B)
		local angle = angle0 + t * 0.22
		local orbit = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local from, look
		if t < B then -- circling as it staggers, sinks and bursts apart
			local close = smooth((t - B + 1.2) / 1.2) -- pushes in on it for the last moments
			from = P + orbit * H * (2.4 - 0.4 * swell - 0.5 * close) + Vector3.yAxis * H * 0.35
			look = P + Vector3.yAxis * H * 0.15
			while popped < #POPS and t >= POPS[popped + 1] * B do
				popped += 1
				jolt, kick = 1, 1
				local pos
				if #bits > 0 then
					local bit = table.remove(bits, math.random(#bits))
					pos = bit.Position
					bit.Transparency = 1
				elseif corpse and corpse.Parent then
					local cf, size = corpse:GetBoundingBox()
					pos = (cf * CFrame.new((math.random() - 0.5) * size.X * 0.7, (math.random() - 0.3) * size.Y * 0.6, (math.random() - 0.5) * size.Z * 0.7)).Position
				end
				if pos then
					pop(pos, 2 + 2.5 * popped / #POPS)
				end
			end
			if pivot and corpse.Parent then
				local s = data.Scale or 1
				local sway = math.sin(t * 2.3) * (0.4 + 0.6 * swell)
				local sink = smooth((t - B * 0.45) / (B * 0.4))
				local squeeze = smooth((t - B + 0.6) / 0.6) -- it pulls in tight just before it goes
				corpse:ScaleTo(1 + 0.3 * swell - 0.12 * squeeze + 0.05 * jolt)
				corpse:PivotTo(pivot
					* CFrame.new(sway * 0.35 * s + math.noise(t * 25, 1) * 0.12 * jolt * s, -sink * H * 0.16, math.noise(t * 25, 2) * 0.12 * jolt * s)
					* CFrame.Angles(0.22 * sink + 0.08 * jolt - 0.4 * squeeze, 0, 0.12 * sway))
				-- arms: thrown up flailing at first, then clutching its gut, flung out by every pop, and spread
				-- wide as it arches back just before it bursts; legs stagger, then the knees give
				local flail = 1 - smooth((t - B * 0.25) / (B * 0.15))
				local k = corpse:GetScale() / scale0
				local function pose(name, rot)
					local L = limbs[name]
					if not L then
						return
					end
					local cf = corpseRoot.CFrame * L.Motor.C0 * rot * L.Motor.C1:Inverse()
					L.Limb.CFrame = cf
					for _, a in L.Attached do
						a.Part.CFrame = cf * (a.Offset - a.Offset.Position + a.Offset.Position * k)
					end
				end
				for i, side in { -1, 1 } do
					local arm = if side < 0 then "LeftArm" else "RightArm"
					do
						local x = (1.7 + 0.5 * math.sin(t * 9 + i * 2)) * flail + (-0.5 + 0.25 * math.sin(t * 14 + i)) * (1 - flail)
						local z = side * (0.5 * flail - 0.6 * (1 - flail))
						x += jolt * 2.2 * math.noise(popped * 1.3, i)
						z += jolt * side * 0.5
						x += (2.3 + 0.15 * math.sin(t * 30) - x) * squeeze
						z += (side * 1 - z) * squeeze
						pose(arm, CFrame.Angles(x, 0, z))
					end
					local step = 0.35 * math.sin(t * 2.3) * side * (1 - sink)
					pose(if side < 0 then "LeftLeg" else "RightLeg", CFrame.Angles(step + 1.1 * sink * (1 - 0.5 * squeeze), 0, side * 0.15 * sink))
				end
				glow.FillTransparency = math.clamp(0.85 - 0.5 * swell + 0.12 * math.sin(t * (6 + 24 * swell)) - 0.15 * jolt, 0.3, 1) -- never a flat silhouette
			end
		else -- pull back and follow the spores up into the clearing sky
			local u = t - B
			from = P + orbit * H * (2 + 0.6 * u) + Vector3.yAxis * H * (0.35 + 0.18 * u)
			look = P + Vector3.yAxis * (H * 0.3 + u * 9)
		end
		local shake = 0.03 * swell + 0.04 * jolt + (if burst then 0.14 * math.max(0, 1 - (t - B) / 1.5) else 0)
		camera.CFrame = CFrame.lookAt(from, look) * CFrame.Angles(math.noise(t * 14, 1) * shake, math.noise(t * 14, 2) * shake, 0)
		camera.FieldOfView = 70 + 4 * kick + (if burst then 14 * math.max(0, 1 - (t - B) / 0.8) else 0)
		if t >= B and not burst then
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
			fling(P, Color3.fromRGB(118, 128, 86), 26, 2.6, 70)
			fling(P, POD, 10, 1.6, 55)
			-- the spore column, a mushroom of spores at its top and a ring rolling out along the street
			local column = fxPart({ Size = Vector3.new(8, 1, 8), CFrame = CFrame.new(P), Transparency = 1 })
			local spores = sporeEmitter(column, 120)
			spores.EmissionDirection = Enum.NormalId.Top
			spores.SpreadAngle = Vector2.new(30, 30)
			spores.Speed = NumberRange.new(18, 42)
			spores.Drag = 0.5
			spores.Acceleration = Vector3.new(0, 5, 0)
			spores.Lifetime = NumberRange.new(5, 7)
			spores.Size = NumberSequence.new(5, 16)
			spores:Emit(220)
			task.delay(2, function()
				spores.Enabled = false
			end)
			local ring = sporeEmitter(fxPart({ Size = Vector3.new(6, 1, 6), CFrame = CFrame.new(P + Vector3.new(0, 1.5, 0)), Transparency = 1 }), 0)
			ring.EmissionDirection = Enum.NormalId.Top
			ring.SpreadAngle = Vector2.new(88, 88)
			ring.Speed = NumberRange.new(45, 70)
			ring.Drag = 1.6
			ring.Acceleration = Vector3.new(0, -2, 0)
			ring.Size = NumberSequence.new(5, 12)
			ring:Emit(160)
			task.delay(7, ring.Parent.Destroy, ring.Parent)
			task.delay(9, column.Destroy, column)
			local core = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 10, CFrame = CFrame.new(P + Vector3.new(0, H * 0.3, 0)), Color = Color3.fromRGB(245, 255, 225), Material = Enum.Material.Neon })
			TweenService:Create(core, TweenInfo.new(0.25), { Size = Vector3.one * 30, Transparency = 1 }):Play()
			task.delay(0.3, core.Destroy, core)
			local flash = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 8, CFrame = CFrame.new(P), Color = POD, Material = Enum.Material.Neon, Transparency = 0.15 })
			TweenService:Create(flash, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * 90, Transparency = 1 }):Play()
			task.delay(1, flash.Destroy, flash)
			for i, reach in { 110, 70 } do -- two shockwave rings along the ground
				local wave = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 6, 6), CFrame = CFrame.new(P + Vector3.new(0, 0.3 * i, 0)) * FLAT, Color = if i == 1 then Color3.fromRGB(235, 255, 200) else POD, Material = Enum.Material.Neon, Transparency = 0.25 })
				TweenService:Create(wave, TweenInfo.new(0.6 + 0.3 * i, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = Vector3.new(0.3, reach, reach), Transparency = 1 }):Play()
				task.delay(1.3, wave.Destroy, wave)
			end
			local light = Instance.new("PointLight")
			light.Color, light.Range, light.Brightness = POD, 60, 12
			light.Parent = column
			TweenService:Create(light, TweenInfo.new(2.5), { Brightness = 0 }):Play()
			ui.Flash.BackgroundTransparency = 0.05
			TweenService:Create(ui.Flash, TweenInfo.new(0.9), { BackgroundTransparency = 1 }):Play()
			Sound:PlayAt("Explosion", P, { Pitch = 0.42, Volume = 1.2 })
			task.delay(0.12, Sound.PlayAt, Sound, "Explosion", P, { Pitch = 0.6 })
			task.delay(0.3, Sound.PlayAt, Sound, "Slam", P, { Pitch = 0.45 })
			Sound:Play("BloomBlastTail")
			Controllers.EffectsController:Shake(1.6, 1.2)
			setTint(false, data.Time - B) -- the sky clears (MatchService fades the clock to dawn)
		end
		local bars = smooth(t / 0.5) * (1 - smooth((t - data.Time + 0.3) / 0.3))
		for _, bar in ui.Bars do
			bar.Size = UDim2.new(1, 0, 0.11 * bars, 0)
		end
		local title = 1 - smooth((t - B - 1.4) / 0.4) * (1 - smooth((t - data.Time + 0.7) / 0.4))
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

-- Bloom Burst windup (its ultimate): a rising roar of noise and a low rumble under heartbeat thumps that
-- quicken, spores streaming in from the edge of the red ring, the danger filling the ring from the middle while
-- it swells and glows, a countdown over its head and GET CLEAR on your screen while you're inside
local function bloomBurst(data)
	local model = data.Model
	if not (model and model.Parent and model.PrimaryPart) then
		return
	end
	local Sound = Controllers.SoundController
	local P, R, W = data.Position, data.Radius, data.Windup
	local s = Zombies.Types[model.Name] and Zombies.Types[model.Name].Scale or 1
	local fill = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.18, 1, 1), CFrame = CFrame.new(P + Vector3.new(0, 0.18, 0)) * FLAT, Color = Color3.fromRGB(255, 110, 40), Material = Enum.Material.Neon, Transparency = 0.55 })
	local edge = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, R * 2 + 1, R * 2 + 1), CFrame = CFrame.new(P + Vector3.new(0, 0.14, 0)) * FLAT, Color = Color3.fromRGB(255, 60, 30), Material = Enum.Material.Neon, Transparency = 0.6 })
	local swell = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one, Color = POD, Material = Enum.Material.Neon, Transparency = 0.8 })
	local light = Instance.new("PointLight")
	light.Color, light.Range = POD, R
	light.Parent = swell
	local glow = Instance.new("Highlight")
	glow.FillColor = POD
	glow.OutlineColor = Color3.fromRGB(255, 90, 40)
	glow.Parent = model
	-- spores drawn in from the ring's edge toward it
	local motes = {}
	for i = 1, 18 do
		local m = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2, Color = POD, Material = Enum.Material.Neon, Transparency = 0.3 })
		table.insert(motes, { Part = m, Angle = i / 18 * math.pi * 2, Phase = math.random() })
	end
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
	local riser = Sound:Loop("BloomRiser") -- a 4.1s reverse swell with a hard end, stretched so the end is the blast
	riser.PlaybackSpeed = 4.13 / W
	riser:Play()
	local rumble = Sound:Loop("BloomRumble")
	rumble.Volume = 0
	rumble:Play()
	fade(rumble, Sounds.Library.BloomRumble.Volume, W * 0.6)
	local t0, shown, nextThump = os.clock(), nil, 0
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local u = math.min(t / W, 1)
		local pulse = math.sin(t * (5 + 22 * u))
		fill.Size = Vector3.new(0.18, R * 2 * u, R * 2 * u)
		edge.Transparency = 0.6 - 0.35 * math.max(0, pulse)
		local center = if model.Parent then model:GetPivot().Position else P
		swell.Size = Vector3.one * (4 + 3.5 * u + 0.5 * pulse) * s
		swell.CFrame = CFrame.new(center + Vector3.new(0, 0.5 * s, 0))
		light.Brightness = 0.5 + 2.5 * u + 0.8 * pulse
		for _, m in motes do
			local k = (t * (0.8 + 1.2 * u) + m.Phase) % 1 -- each mote runs edge -> centre, faster as it builds
			local dir = Vector3.new(math.cos(m.Angle + k * 0.6), 0, math.sin(m.Angle + k * 0.6))
			m.Part.CFrame = CFrame.new(P + dir * R * (1 - k) + Vector3.new(0, 1 + k * 3 * s, 0))
			m.Part.Transparency = 0.2 + 0.8 * k
		end
		glow.FillTransparency = math.clamp(0.75 - 0.55 * u + 0.15 * pulse, 0, 1)
		if t >= nextThump and u < 1 then -- heartbeat thumps, 0.8s apart down to 0.15s
			nextThump = t + 0.8 - 0.65 * u
			Sound:Play("BloomThump", { Pitch = 0.8 + 0.5 * u, Volume = 0.6 + 0.6 * u })
		end
		local n = math.ceil(W - t)
		if n ~= shown and n > 0 then
			shown = n
			count.Text = tostring(n)
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		label.Visible = root ~= nil and Vector3.new(root.Position.X - P.X, 0, root.Position.Z - P.Z).Magnitude <= R and pulse > -0.3
		if u >= 1 or not model.Parent then
			conn:Disconnect()
			for _, m in motes do
				m.Part:Destroy()
			end
			fill:Destroy()
			edge:Destroy()
			swell:Destroy()
			glow:Destroy()
			board:Destroy()
			warn:Destroy()
			fade(rumble, 0, 0.6)
			task.delay(0.7, rumble.Destroy, rumble)
			if u < 1 then -- it died mid-windup: cut the swell short
				riser:Destroy()
			else
				task.delay(1, riser.Destroy, riser)
			end
		end
	end)
end

-- the Bloom Burst goes off: a white-hot core, a green blast filling the ring, two shockwaves along the ground,
-- a spore column and a ring of spores rolling out, flung chunks and a deep double boom; then a spore field
-- hangs over the ring for Field.Time (ZombieService hurts anyone inside it)
local function bloomBlast(data)
	local Sound = Controllers.SoundController
	local P, R, F = data.Position, data.Radius, data.Field
	Sound:PlayAt("Explosion", P, { Pitch = 0.45, Volume = 1.2 })
	task.delay(0.1, Sound.PlayAt, Sound, "Explosion", P, { Pitch = 0.7 })
	Sound:PlayAt("Slam", P, { Pitch = 0.5 })
	Sound:PlayAt("BloomBlastTail", P)
	local core = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 8, CFrame = CFrame.new(P + Vector3.new(0, 3, 0)), Color = Color3.fromRGB(245, 255, 225), Material = Enum.Material.Neon })
	TweenService:Create(core, TweenInfo.new(0.2), { Size = Vector3.one * 24, Transparency = 1 }):Play()
	task.delay(0.25, core.Destroy, core)
	local ball = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 6, CFrame = CFrame.new(P), Color = POD, Material = Enum.Material.Neon, Transparency = 0.25 })
	TweenService:Create(ball, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * R * 2, Transparency = 1 }):Play()
	task.delay(0.6, ball.Destroy, ball)
	for i, reach in { R * 2.4, R * 1.6 } do
		local wave = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 4, 4), CFrame = CFrame.new(P + Vector3.new(0, 0.3 * i, 0)) * FLAT, Color = if i == 1 then Color3.fromRGB(235, 255, 200) else POD, Material = Enum.Material.Neon, Transparency = 0.2 })
		TweenService:Create(wave, TweenInfo.new(0.45 + 0.25 * i, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = Vector3.new(0.3, reach, reach), Transparency = 1 }):Play()
		task.delay(1.1, wave.Destroy, wave)
	end
	local holder = fxPart({ Size = Vector3.new(6, 1, 6), CFrame = CFrame.new(P + Vector3.new(0, 1, 0)), Transparency = 1 })
	local column = sporeEmitter(holder, 0)
	column.EmissionDirection = Enum.NormalId.Top
	column.SpreadAngle = Vector2.new(25, 25)
	column.Speed = NumberRange.new(20, 40)
	column.Drag = 0.6
	column.Size = NumberSequence.new(4, 12)
	column:Emit(90)
	local roll = sporeEmitter(holder, 0)
	roll.EmissionDirection = Enum.NormalId.Top
	roll.SpreadAngle = Vector2.new(88, 88)
	roll.Speed = NumberRange.new(R * 1.2, R * 1.8)
	roll.Drag = 2
	roll.Size = NumberSequence.new(4, 10)
	roll:Emit(120)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = POD, R * 1.5, 10
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(1.5), { Brightness = 0 }):Play()
	task.delay(7, holder.Destroy, holder)
	fling(P, Color3.fromRGB(118, 128, 86), 16, 2, 60)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local near = root and (root.Position - P).Magnitude <= R * 1.5
	Controllers.EffectsController:Shake(if near then 1.5 else 0.6, if near then 0.9 else 0.5)
	if near then -- a blinding flash on your own screen
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Brightness, cc.TintColor = 0.5, Color3.fromRGB(225, 255, 200)
		cc.Parent = Lighting
		TweenService:Create(cc, TweenInfo.new(0.8), { Brightness = 0, TintColor = Color3.new(1, 1, 1) }):Play()
		task.delay(0.9, cc.Destroy, cc)
	end
	if F then -- the spore field left behind: a sick glow on the street under a low churning cloud
		local disc = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, F.Radius * 2, F.Radius * 2), CFrame = CFrame.new(P + Vector3.new(0, 0.16, 0)) * FLAT, Color = Color3.fromRGB(110, 160, 40), Material = Enum.Material.Neon, Transparency = 0.72 })
		local mist = fxPart({ Size = Vector3.new(F.Radius * 1.7, 3, F.Radius * 1.7), CFrame = CFrame.new(P + Vector3.new(0, 2, 0)), Transparency = 1 })
		local cloud = sporeEmitter(mist, 70)
		cloud.Speed = NumberRange.new(0.5, 2.5)
		cloud.Size = NumberSequence.new(4, 9)
		cloud.Lifetime = NumberRange.new(1.5, 3)
		cloud:Emit(80)
		local t0 = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local t = os.clock() - t0
			disc.Transparency = 0.72 + 0.1 * math.sin(t * 5) + 0.28 * smooth((t - F.Time + 1) / 1)
			if t >= F.Time then
				conn:Disconnect()
				cloud.Enabled = false
				disc:Destroy()
				task.delay(3, mist.Destroy, mist)
			end
		end)
	end
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
