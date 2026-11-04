-- TrailerDirector: a 60-second scripted gameplay trailer (owner 2026-11-04), to screen-record for the
-- experience page. DEV TOOL ONLY: nothing in the game requires it. It lives in ReplicatedStorage.DevTools.
-- Run in Play from the Client context (Studio command bar or execute_luau):
--   task.spawn(require(game.ReplicatedStorage.DevTools.TrailerDirector).Play)   -- or .Play(startAt) to test from a shot
-- Everything on screen is the real game: the Arena city, ZombiePreviews (the same models the server
-- builds), ClassFigures survivors, our sound library, plus APM "Growing Tension (a 60)" as the score
-- (Roblox requires video thumbnails to show real in-experience content; title cards are allowed).
-- The frame is a 16:9 box with black bars outside it, so the recording crops cleanly.
-- Shots: 1 empty foggy street  2 a lone zombie shambles in  3 they claw out of the ground  4 the
-- squad flies in over the roofs  5 survivors back to back at a crossroads, the horde from 3 sides
-- 6 crane up over the street packed with them  7 the Grave Titan  8 the Nightmare (Bloom Mother)
-- 9 title card. Everything it changes (camera, lighting, guis, sounds) is put back at the end.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared.Config.Sounds)
local ClassFigures = require(Shared.ClassFigures)

local TrailerDirector = {}

local MUSIC = 9040214335 -- "Growing Tension (a 60)", APM (licensed in the Roblox library), 61.6s
local CROSS = Vector3.new(1000, 1, 114) -- crossroads: ring road (z 114) meets the south avenue (x 1000)
local GROUND = 1

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local previews
local stage, gui, frame
local clock0 = 0
local cleanup = {}
local offsets = {} -- [type] = pivot height above the feet

local function now()
	return os.clock() - clock0
end

local function new(className, props)
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	inst.Parent = props.Parent
	return inst
end

local function sfx(name, volume, pitch)
	local def = Sounds.Library and Sounds.Library[name]
	if not def then
		return
	end
	local s = new("Sound", { SoundId = "rbxassetid://" .. def.Id, Volume = (def.Volume or 0.5) * (volume or 1), PlaybackSpeed = pitch or 1, Parent = SoundService })
	s:Play()
	task.delay(12, s.Destroy, s)
	return s
end

-- Puppets -------------------------------------------------------------------------------------------

local function puppet(id, pos, look)
	local template = previews:FindFirstChild(id)
	local m = template:Clone()
	local root = m:FindFirstChild("Root")
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d == root
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	if not offsets[id] then
		local cf, size = template:GetBoundingBox()
		offsets[id] = template:GetPivot().Y - (cf.Y - size.Y / 2)
	end
	m.Parent = stage
	local p = { Model = m, Id = id, Motors = {}, Pos = pos, Look = look or (pos + Vector3.new(0, 0, -1)), Phase = math.random() * 6, Lift = offsets[id] }
	for i, name in { "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
		p.Motors[i] = root and root:FindFirstChild(name)
	end
	return p
end

-- pose: "run" (arms reaching, legs striding), "rise" (arms up, clawing), "idle" (slow sway)
local function animate(p, pose, speed, extraY)
	local t = os.clock() * (speed or 1) * 6 + p.Phase
	local swing = math.sin(t)
	local bob = if pose == "run" then math.abs(swing) * 0.25 else 0
	local flat = Vector3.new(p.Look.X, p.Pos.Y, p.Look.Z)
	if (flat - p.Pos).Magnitude < 0.01 then
		flat = p.Pos + Vector3.new(0, 0, -1)
	end
	local base = Vector3.new(p.Pos.X, p.Pos.Y + p.Lift + bob + (extraY or 0), p.Pos.Z)
	p.Model:PivotTo(CFrame.lookAt(base, Vector3.new(flat.X, base.Y, flat.Z)) * (p.Tilt or CFrame.identity))
	for i, motor in p.Motors do
		if motor then
			local side = if i % 2 == 1 then 1 else -1
			if pose == "rise" then
				motor.Transform = if i <= 2 then CFrame.Angles(math.rad(-165) + swing * 0.35 * side, 0, side * 0.25) else CFrame.identity
			elseif pose == "idle" then
				motor.Transform = if i <= 2 then CFrame.Angles(math.rad(-70) + swing * 0.12 * side, 0, 0) else CFrame.identity
			else
				motor.Transform = if i <= 2 then CFrame.Angles(math.rad(-80) + swing * 0.3 * side, 0, 0) else CFrame.Angles(swing * 0.8 * side, 0, 0)
			end
		end
	end
end

-- a shot zombie topples back and sinks
local function topple(p)
	p.Dead = true
	local start = os.clock()
	task.spawn(function()
		while os.clock() - start < 0.55 and p.Model.Parent do
			local u = (os.clock() - start) / 0.55
			p.Tilt = CFrame.Angles(math.rad(-85) * u, 0, 0)
			animate(p, "idle", 0, -u * 1.2)
			RunService.RenderStepped:Wait()
		end
		p.Tilt = nil
		p.Dead = false
		p.Respawn = true
	end)
end

-- Survivors ------------------------------------------------------------------------------------------

local function survivor(classId, pos, face)
	local fig = ClassFigures.Build(classId)
	fig:PivotTo(CFrame.lookAt(pos + Vector3.new(0, 3, 0), Vector3.new(face.X, pos.Y + 3, face.Z)))
	for _, d in fig:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	fig.Parent = stage
	-- shoulder the rifle and aim it down the lane (the figures hold it at rest)
	local parts, barrel, stock, recv = {}, nil, nil, nil
	for _, d in fig:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "Receiver" or d.Name == "Stock" or d.Name == "Handguard" or d.Name == "Barrel" or d.Name == "Mag") then
			table.insert(parts, d)
			if d.Name == "Barrel" then barrel = d elseif d.Name == "Stock" then stock = d elseif d.Name == "Receiver" then recv = d end
		end
	end
	local s = { Model = fig, Aim = (Vector3.new(face.X, pos.Y, face.Z) - pos).Unit, Next = 0 }
	if barrel and stock and recv then
		local body = fig:GetPivot()
		local target = s.Aim + Vector3.new(0, 0.02, 0)
		local rot = CFrame.fromRotationBetweenVectors((barrel.Position - stock.Position).Unit, target.Unit)
		local pivot, newPivot = recv.Position, (body * CFrame.new(0.75, 0.95, -1)).Position
		for _, d in parts do
			d.CFrame = CFrame.new(newPivot) * rot * (CFrame.new(pivot):Inverse() * d.CFrame)
		end
		s.Tip = barrel.Position + target.Unit * (barrel.Size.Z / 2 + 0.1)
	else
		s.Tip = pos + Vector3.new(0, 5, 0) + s.Aim * 1.5
	end
	return s
end

local function shoot(s, at)
	local dir = (at - s.Tip).Unit
	local flash = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 225, 150), Size = Vector3.one * 0.9, CFrame = CFrame.new(s.Tip + dir * 0.4), Parent = stage })
	new("PointLight", { Color = Color3.fromRGB(255, 190, 110), Range = 14, Brightness = 4, Parent = flash })
	local length = (at - s.Tip).Magnitude
	local tracer = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 225, 150), Size = Vector3.new(0.09, 0.09, length), CFrame = CFrame.lookAt(s.Tip + dir * length / 2, at), Parent = stage })
	task.delay(0.05, flash.Destroy, flash)
	task.delay(0.07, tracer.Destroy, tracer)
end

-- Look -------------------------------------------------------------------------------------------------

local saved = {}
local function saveProps(inst, props)
	local t = {}
	for _, k in props do
		t[k] = inst[k]
	end
	table.insert(saved, { inst, t })
end

local function setLook(look)
	Lighting.ClockTime = look.Clock or 19.2
	Lighting.Brightness = look.Brightness or 1.3
	Lighting.Ambient = look.Ambient or Color3.fromRGB(50, 50, 80)
	Lighting.OutdoorAmbient = look.Outdoor or Color3.fromRGB(90, 100, 150)
	Lighting.ColorShift_Top = Color3.fromRGB(150, 160, 255)
	Lighting.ExposureCompensation = look.Exposure or 0.25
	for _, a in Lighting:GetChildren() do
		if a:IsA("Atmosphere") then
			a.Density, a.Haze, a.Glare, a.Offset = look.Density or 0.34, 1.5, 0.6, 0
			a.Color = look.Fog or Color3.fromRGB(120, 110, 160)
			a.Decay = look.Decay or Color3.fromRGB(60, 40, 80)
		end
	end
	local cc = Lighting:FindFirstChild("TRAILER_CC")
	cc.TintColor = look.Tint or Color3.fromRGB(255, 245, 240)
	cc.Saturation = look.Saturation or 0.18
end

-- UI: 16:9 safe frame, letterbox, captions ---------------------------------------------------------------

local function buildGui()
	gui = new("ScreenGui", { Name = "TRAILER", IgnoreGuiInset = true, DisplayOrder = 1000, ResetOnSpawn = false, Parent = player.PlayerGui })
	local vp = camera.ViewportSize
	local h = math.min(vp.Y, vp.X * 9 / 16)
	local w = h * 16 / 9
	local black = Color3.new(0, 0, 0)
	-- outside the 16:9 box
	new("Frame", { Size = UDim2.new(0, (vp.X - w) / 2, 1, 0), BackgroundColor3 = black, BorderSizePixel = 0, Parent = gui })
	new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, (vp.X - w) / 2, 1, 0), BackgroundColor3 = black, BorderSizePixel = 0, Parent = gui })
	frame = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1, ClipsDescendants = true, Parent = gui })
	-- cinematic bars inside it
	for _, top in { true, false } do
		new("Frame", { AnchorPoint = Vector2.new(0, if top then 0 else 1), Position = UDim2.fromScale(0, if top then 0 else 1), Size = UDim2.fromScale(1, 0.09), BackgroundColor3 = black, BorderSizePixel = 0, ZIndex = 5, Parent = frame })
	end
	frame:SetAttribute("H", h)
	-- full black for fades and the title card
	new("Frame", { Name = "Fade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = black, BorderSizePixel = 0, ZIndex = 8, Parent = frame })
end

local function fade(to, seconds)
	TweenService:Create(frame.Fade, TweenInfo.new(seconds), { BackgroundTransparency = to }):Play()
end

-- caption: fades in, drifts, fades out (all times in seconds from now)
local function caption(text, hold, props)
	props = props or {}
	local h = frame:GetAttribute("H")
	local size = (props.Size or 0.06) * h
	local label = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.fromScale(0.5, 0.78),
		Size = UDim2.new(1, 0, 0, size * 1.4),
		BackgroundTransparency = 1,
		Font = props.Font or Enum.Font.GothamBlack,
		Text = text,
		TextSize = size,
		TextColor3 = props.Color or Color3.fromRGB(240, 236, 228),
		TextTransparency = 1,
		ZIndex = 9,
		Parent = frame,
	})
	local stroke = new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = math.max(1, size * 0.05), Transparency = 1, Parent = label })
	local scale = new("UIScale", { Scale = props.From or 1.06, Parent = label })
	local inT = TweenInfo.new(props.In or 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, inT, { TextTransparency = 0 }):Play()
	TweenService:Create(stroke, inT, { Transparency = 0.3 }):Play()
	TweenService:Create(scale, TweenInfo.new(hold + 0.8, Enum.EasingStyle.Linear), { Scale = 1 }):Play()
	task.delay(hold, function()
		local out = TweenInfo.new(0.5)
		TweenService:Create(label, out, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, out, { Transparency = 1 }):Play()
		task.delay(0.55, label.Destroy, label)
	end)
	return label
end

-- Run --------------------------------------------------------------------------------------------------

local function lerp(a, b, u)
	return a + (b - a) * u
end
local function ease(u)
	return u * u * (3 - 2 * u)
end

-- camera move from (pos0 -> pos1) looking at (look0 -> look1) over [t0, t1]
local function move(t, t0, t1, pos0, pos1, look0, look1, shake)
	local u = ease(math.clamp((t - t0) / (t1 - t0), 0, 1))
	local pos, look = lerp(pos0, pos1, u), lerp(look0, look1, u)
	local cf = CFrame.lookAt(pos, look)
	if shake and shake > 0 then
		local n = os.clock() * 20
		cf *= CFrame.Angles(math.noise(n, 1) * shake, math.noise(n, 2) * shake, math.noise(n, 3) * shake * 0.5)
	end
	camera.CFrame = cf
end

function TrailerDirector.Play(startAt)
	previews = ReplicatedStorage:WaitForChild("ZombiePreviews", 15)
	assert(previews, "TrailerDirector: no ZombiePreviews (run it in Play)")

	-- take over: hide every gui and the core UI, mute the game's sounds, scriptable camera
	for _, g in player.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled then
			g.Enabled = false
			table.insert(cleanup, function() g.Enabled = true end)
		end
	end
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)
	pcall(StarterGui.SetCore, StarterGui, "TopbarEnabled", false)
	for _, s in SoundService:GetDescendants() do
		if s:IsA("Sound") and s.Playing then
			local v = s.Volume
			s.Volume = 0
			table.insert(cleanup, function() s.Volume = v end)
		end
	end
	saveProps(camera, { "CameraType", "FieldOfView" })
	camera.CameraType = Enum.CameraType.Scriptable
	saveProps(Lighting, { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "ColorShift_Top", "ExposureCompensation" })
	for _, a in Lighting:GetChildren() do
		if a:IsA("Atmosphere") then
			saveProps(a, { "Density", "Haze", "Glare", "Offset", "Color", "Decay" })
		elseif a:IsA("ColorCorrectionEffect") or a:IsA("DepthOfFieldEffect") or a.Name == "SAMZ_PostBloom" then
			-- the run grades stack and darken the night shots, and depth of field blurs the horde: off while it plays
			saveProps(a, { "Enabled" })
			a.Enabled = false
		end
	end
	local cc = new("ColorCorrectionEffect", { Name = "TRAILER_CC", Contrast = 0.25, Saturation = 0.18, Parent = Lighting })
	stage = new("Folder", { Name = "TRAILER_STAGE", Parent = workspace })
	buildGui()
	setLook({})

	-- fires along the streets, as in the icon
	local function fireAt(pos, size)
		local p = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Transparency = 1, Size = Vector3.one, Position = pos, Parent = stage })
		new("Fire", { Size = size, Heat = 12, Color = Color3.fromRGB(255, 120, 30), SecondaryColor = Color3.fromRGB(255, 60, 10), Parent = p })
		new("PointLight", { Color = Color3.fromRGB(255, 130, 50), Range = 26, Brightness = 1.8, Parent = p })
	end
	for _, f in { { 935, 104, 9 }, { 970, 126, 10 }, { 1012, 103, 12 }, { 1060, 125, 14 }, { 1006, 80, 10 }, { 993, 128, 8 } } do
		fireAt(Vector3.new(f[1], 2, f[2]), f[3])
	end

	-- the cast
	local lone = puppet("Shambler", Vector3.new(942, GROUND, 113), Vector3.new(1000, GROUND, 114))
	local risers = { puppet("Rotter", Vector3.new(936, GROUND, 111.5)), puppet("Shambler", Vector3.new(941, GROUND, 116)) }
	for _, r in risers do
		r.Look = Vector3.new(925, GROUND, 109)
		r.Model.Parent = nil
	end
	local squad = {
		survivor("Survivor", CROSS + Vector3.new(-1.2, 0, 0.4), CROSS + Vector3.new(-40, 0, 0)),
		survivor("Engineer", CROSS + Vector3.new(0.9, 0, 1.3), CROSS + Vector3.new(40, 0, 0)),
		survivor("Bruiser", CROSS + Vector3.new(0.3, 0, -1.3), CROSS + Vector3.new(0, 0, -40)),
	}
	for _, s in squad do
		s.Model.Parent = nil
	end
	-- horde lanes into the crossroads: west and east along the ring road, north down the avenue
	local lanes = {
		{ Dir = Vector3.new(-1, 0, 0), Side = Vector3.new(0, 0, 1), Shooter = 1, Count = 70, Far = 115 },
		{ Dir = Vector3.new(1, 0, 0), Side = Vector3.new(0, 0, 1), Shooter = 2, Count = 30, Far = 80 },
		{ Dir = Vector3.new(0, 0, -1), Side = Vector3.new(1, 0, 0), Shooter = 3, Count = 30, Far = 50 },
	}
	local mix = { "Shambler", "Shambler", "Runner", "Runner", "Bloater", "Brute", "Shambler" }
	local horde = {}
	for li, lane in lanes do
		for i = 1, lane.Count do
			local p = puppet(mix[math.random(#mix)], CROSS, CROSS)
			p.Lane, p.D, p.Lat, p.Hold = li, 12 + (i / lane.Count) * lane.Far + math.random() * 4, (math.random() - 0.5) * 11, 9 + math.random() * 4
			p.Speed = if p.Id == "Runner" then 11 elseif p.Id == "Brute" then 5 else 7
			p.Model.Parent = nil
			table.insert(horde, p)
		end
	end
	local titan = puppet("GraveTitan", Vector3.new(1094, GROUND, 114), Vector3.new(1000, GROUND, 114))
	local titanGlow = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Transparency = 1, Size = Vector3.one, Position = Vector3.new(1078, 6, 111), Parent = stage })
	new("PointLight", { Color = Color3.fromRGB(255, 120, 50), Range = 30, Brightness = 3, Parent = titanGlow })
	titan.Model.Parent = nil
	local mother = puppet("BloomMother", Vector3.new(1000, GROUND, 66), Vector3.new(1000, GROUND, 114))
	mother.Model.Parent = nil

	-- go
	local music = new("Sound", { SoundId = "rbxassetid://" .. MUSIC, Volume = 0.9, Parent = SoundService })
	local cues = {}
	local function at(t, fn)
		table.insert(cues, { T = t, Fn = fn })
	end
	at(0, function() fade(0, 0) fade(1, 2.2) end)
	at(1.4, function() caption("PORT HARROW", 3.6, { Size = 0.05, Position = UDim2.fromScale(0.5, 0.5) }) end)
	at(3.2, function() caption("41 DAYS AFTER THE BLOOM", 2.6, { Size = 0.028, Position = UDim2.fromScale(0.5, 0.58), Font = Enum.Font.GothamBold }) end)
	at(7.5, function() sfx("Groan1", 1.4, 0.9) end)
	at(8.6, function() caption("NO ONE CAME BACK.", 2.6) end)
	at(10.5, function() sfx("Groan2", 1.2, 0.8) end)
	at(12, function() lone.Model.Parent = nil for _, r in risers do r.Model.Parent = stage end sfx("Impact1", 1.2, 0.7) end)
	at(13.1, function() sfx("Groan3", 1.5, 0.85) end)
	local heli
	at(17, function() -- the ride in comes at dusk, the fight back at night
		heli = sfx("Helicopter", 1.2)
		setLook({ Clock = 18.1, Brightness = 1.8, Outdoor = Color3.fromRGB(150, 110, 120), Ambient = Color3.fromRGB(70, 55, 70), Fog = Color3.fromRGB(170, 125, 125), Decay = Color3.fromRGB(90, 60, 80), Exposure = 0.1 })
	end)
	at(19.2, function() caption("UNTIL NOW.", 2.4) end)
	at(23, function() setLook({}) if heli then heli:Destroy() end for _, s in squad do s.Model.Parent = stage end for _, p in horde do p.Model.Parent = stage end end)
	at(25, function() caption("HOLD THE LINE.", 2.6) end)
	at(34.4, function() caption("1,000,000 OF THEM.", 2.8, { Size = 0.07 }) end)
	at(38, function() -- the street empties for the Titan
		for _, p in horde do p.Model.Parent = nil end
		for _, s in squad do s.Model.Parent = nil end
		titan.Model.Parent = stage
	end)
	at(39.3, function() sfx("BossRoar", 1.3) end)
	at(41.2, function() caption("AND THEY'RE GETTING BIGGER.", 2.8) end)
	at(45, function()
		mother.Model.Parent = stage
		titan.Model.Parent = nil
		setLook({ Clock = 19.5, Brightness = 1, Ambient = Color3.fromRGB(45, 10, 12), Outdoor = Color3.fromRGB(90, 20, 25), Fog = Color3.fromRGB(150, 30, 35), Decay = Color3.fromRGB(70, 10, 15), Tint = Color3.fromRGB(255, 190, 190), Saturation = 0.3, Density = 0.4 })
		sfx("BloomRiser", 1)
	end)
	at(47, function() caption("SURVIVE THE NIGHTMARE.", 3, { Color = Color3.fromRGB(255, 90, 80) }) end)
	at(50.6, function() fade(0, 0.25) end)
	at(51.2, function()
		sfx("Explosion", 0.9, 0.8)
		caption("SURVIVE", 8.6, { Size = 0.05, Position = UDim2.fromScale(0.5, 0.38), From = 1.25, In = 0.2 })
		caption("1,000,000 ZOMBIES", 8.6, { Size = 0.12, Position = UDim2.fromScale(0.5, 0.5), From = 1.3, In = 0.15, Color = Color3.fromRGB(255, 70, 55) })
	end)
	at(54, function() caption("BRING YOUR SQUAD. HOLD THE LINE.", 5.8, { Size = 0.03, Position = UDim2.fromScale(0.5, 0.64), Font = Enum.Font.GothamBold }) end)
	at(56.2, function() caption("PLAY NOW", 3.6, { Size = 0.045, Position = UDim2.fromScale(0.5, 0.74), Color = Color3.fromRGB(255, 200, 70) }) end)
	table.sort(cues, function(a, b) return a.T < b.T end)

	music.TimePosition = startAt or 0
	music:Play()
	clock0 = os.clock() - (startAt or 0)
	local nextCue, lastShot = 1, 0
	local conn
	local done = false
	conn = RunService.RenderStepped:Connect(function(dt)
		local t = now()
		while cues[nextCue] and cues[nextCue].T <= t do
			task.spawn(cues[nextCue].Fn)
			nextCue += 1
		end

		-- camera per shot
		if t < 6.5 then -- 1: slow push down the empty foggy street
			camera.FieldOfView = 55
			move(t, 0, 6.5, Vector3.new(1112, 4.5, 112), Vector3.new(1088, 4.2, 113), Vector3.new(1000, 5, 114), Vector3.new(1000, 4, 114))
			lone.Pos = lone.Pos + Vector3.new(dt * 1.6, 0, 0)
			animate(lone, "run", 0.45)
		elseif t < 12 then -- 2: the lone zombie shambles up to a low camera
			camera.FieldOfView = 50
			move(t, 6.5, 12, Vector3.new(962, 1.7, 113.5), Vector3.new(959, 1.5, 113.6), Vector3.new(945, 4.5, 113), Vector3.new(945, 4.2, 113))
			lone.Pos = lone.Pos + Vector3.new(dt * 1.5, 0, 0)
			animate(lone, "run", 0.45)
		elseif t < 17 then -- 3: they claw out of the ground
			camera.FieldOfView = 48
			move(t, 12, 17, Vector3.new(929, 1.4, 107.5), Vector3.new(930.5, 1.6, 108.2), Vector3.new(937, 3, 113), Vector3.new(938, 4.2, 113.5))
			for i, r in risers do
				local u = math.clamp((t - 12 - (i - 1) * 1.2) / 2.6, 0, 1)
				animate(r, if u < 1 then "rise" else "idle", 0.7, (1 - u) * -5.5)
			end
		elseif t < 23 then -- 4: the squad flies in low over the roofs
			camera.FieldOfView = 70
			move(t, 17, 23, Vector3.new(1000, 80, -70), Vector3.new(1000, 34, 70), Vector3.new(1000, 20, 20), Vector3.new(1000, 2, 114), 0.012)
		elseif t < 38 then -- 5 + 6: the crossroads, then a crane up over the street
			if t < 29 then
				camera.FieldOfView = 60
				local a = math.rad(lerp(200, 255, (t - 23) / 6))
				local c = CROSS + Vector3.new(0, 2.5, 0)
				camera.CFrame = CFrame.lookAt(c + Vector3.new(math.cos(a) * 9, 1.8, math.sin(a) * 9), c + Vector3.new(0, 1, 0))
			elseif t < 33 then
				camera.FieldOfView = 52
				move(t, 29, 33, CROSS + Vector3.new(0.9, 6.3, -0.6), CROSS + Vector3.new(0.5, 6.1, -0.4), CROSS + Vector3.new(-40, 3, 0), CROSS + Vector3.new(-40, 3, 0.5), 0.004)
			else
				camera.FieldOfView = 60
				move(t, 33, 38, CROSS + Vector3.new(-8, 4, -3), CROSS + Vector3.new(4, 46, -6), CROSS + Vector3.new(-60, 2, 0), CROSS + Vector3.new(-70, 0, 0))
			end
			-- the horde comes on; the squad cuts down the front of each lane
			for _, p in horde do
				local lane = lanes[p.Lane]
				if p.Respawn then
					p.Respawn, p.D = false, lane.Far * (0.7 + math.random() * 0.3)
				end
				if not p.Dead then
					p.D = math.max(p.Hold, p.D - p.Speed * dt)
					p.Pos = CROSS + lane.Dir * p.D + lane.Side * p.Lat
					p.Look = CROSS + lane.Side * p.Lat * 0.3
					animate(p, "run", p.Speed / 9)
				end
			end
			if t - lastShot > 0.09 then
				lastShot = t
				for li, lane in lanes do
					local s = squad[lane.Shooter]
					local best
					for _, p in horde do
						if p.Lane == li and not p.Dead and p.D < 34 and (not best or p.D < best.D) then
							best = p
						end
					end
					if best and math.random() < 0.85 then
						shoot(s, best.Pos + Vector3.new(0, 3.5, 0))
						if math.random() < 0.55 then
							topple(best)
						end
					end
				end
				if math.random() < 0.6 then
					sfx(if math.random() < 0.5 then "Rifle" else "SMG", 0.45, 0.95 + math.random() * 0.1)
				end
			end
		elseif t < 45 then -- 7: the Grave Titan, from the ground
			camera.FieldOfView = 62
			local stepShake = math.max(0, math.sin((t - 38) * 2.2)) ^ 8 * 0.02
			move(t, 38, 45, Vector3.new(1068, 1.0, 111), Vector3.new(1064, 1.3, 111.5), Vector3.new(1094, 13, 114), Vector3.new(1084, 15, 114), stepShake)
			titan.Pos = titan.Pos + Vector3.new(-dt * 1.4, 0, 0)
			titanGlow.Position = titan.Pos + Vector3.new(-13, 7, -3) -- firelight on its face
			animate(titan, "run", 0.25)
		elseif t < 50.6 then -- 8: the Nightmare
			camera.FieldOfView = 58
			move(t, 45, 50.6, Vector3.new(1000, 3, 98), Vector3.new(1000, 4.5, 84), Vector3.new(1000, 12, 66), Vector3.new(1000, 13, 66), 0.003)
			animate(mother, "idle", 0.4)
			Lighting.ExposureCompensation = if math.random() < 0.025 then 1.4 else 0.15 -- lightning flicker
		else
			camera.CFrame = CFrame.new(1000, 300, 0) -- title card: black screen
		end
		if t > 61 and not done then
			done = true
			conn:Disconnect()
		end
	end)

	repeat
		task.wait(0.5)
	until done
	-- put everything back
	music:Destroy()
	stage:Destroy()
	gui:Destroy()
	cc:Destroy()
	for _, s in saved do
		for k, v in s[2] do
			s[1][k] = v
		end
	end
	for _, fn in cleanup do
		pcall(fn)
	end
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, true)
	pcall(StarterGui.SetCore, StarterGui, "TopbarEnabled", true)
	table.clear(saved)
	table.clear(cleanup)
	camera.CameraType = Enum.CameraType.Custom
end

return TrailerDirector
