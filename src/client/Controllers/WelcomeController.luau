-- WelcomeController: the "welcome back" screen a returning player sees when they reach a lobby server (once
-- per join, after the tutorial: profile Stats.Runs >= 1). Behind it, a ViewportFrame scene of a ruined Port
-- Harrow street at dusk: broken buildings with a few lit windows against a low sun, burning wrecks with
-- smoke and embers, your avatar idling on the left and a horde (ReplicatedStorage.ZombiePreviews, built by
-- ZombieService) running past right to left. ViewportFrames draw no particles or lights, so fire, smoke and
-- embers are neon / translucent parts animated each frame, and distance is faked by fading colours toward
-- the sky. On the right: your stats, the tracked bounty, and ENTER SAFEHOUSE (also Enter / gamepad A).
-- Run report (2026-11-03): after every run the same screen comes back as a report once you're at the
-- safehouse: VICTORY / OVERRUN / TRAINING DONE and that run's wave, kills, Gems and waves cleared. The
-- results come from Remotes.RunResults when the run played on this server (Studio), or from the teleport
-- data a match server sends back (MatchService.LastResults via QueueService:ReturnToLobby).
-- Level header (Config/Levels) under the headline: LEVEL n, its rank title and the XP bar; the run report
-- adds the run's +XP, chips breaking it down, and fills the bar from before the run (results.XPBefore) to
-- now with LEVEL UP! and a pop at each level gained. The wave tile gets a gold NEW BEST tag.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameState = require(Shared.GameState)
local Remotes = require(Shared.Remotes)
local Zombies = require(Shared.Config.Zombies)
local Bounties = require(Shared.Config.Bounties)
local Survivors = require(Shared.Config.Survivors)
local Util = require(Shared.Util)
local Levels = require(Shared.Config.Levels)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local T = UIKit.Theme
local player = Players.LocalPlayer
local WelcomeController = {}

local HORDE = 12 -- runners in the background
local SPAN = 34 -- they run from x = -SPAN to +SPAN (screen right to left)
local SKY = Color3.fromRGB(150, 70, 50) -- far things fade toward this
local FIRE = { Color3.fromRGB(255, 120, 30), Color3.fromRGB(255, 180, 60), Color3.fromRGB(255, 80, 20) }

local function decode(attr)
	local ok, data = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute(attr) or "{}")
	return if ok and type(data) == "table" then data else {}
end

local function block(parent, size, cframe, color, material, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	for k, v in props or {} do
		p[k] = v
	end
	p.Parent = parent
	return p
end

-- depth: 0 = near, 1 = far (melts into the sky)
local function haze(color, depth)
	return color:Lerp(SKY, math.clamp(depth, 0, 1) * 0.75)
end

-- a ruined block: a tower with a broken, stepped top and a few lit windows
local function ruin(world, rng, x, z, w, h, depth)
	local wall = haze(Color3.fromRGB(58, 44, 42), depth)
	block(world, Vector3.new(w, h, 8), CFrame.new(x, h / 2, z), wall)
	-- broken top: a few chunks of different heights, some missing
	local chunks = math.max(2, math.floor(w / 4))
	for i = 1, chunks do
		if rng:NextNumber() < 0.7 then
			local cw = w / chunks
			local ch = rng:NextNumber(1, 6)
			block(world, Vector3.new(cw, ch, 8), CFrame.new(x - w / 2 + cw * (i - 0.5), h + ch / 2, z) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-8, 8))), wall)
		end
	end
	-- windows: dark grid, a few still lit
	for row = 1, math.floor((h - 4) / 4) do
		for col = 1, math.floor(w / 3.5) do
			local lit = rng:NextNumber() < 0.12
			local color = if lit then Color3.fromRGB(255, 170, 80) else haze(Color3.fromRGB(20, 16, 18), depth)
			block(world, Vector3.new(1.4, 1.8, 0.2), CFrame.new(x - w / 2 + col * 3.5 - 1, row * 4, z - 4.05), color, if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic)
		end
	end
end

-- a burnt-out car with flames (returned for the animation)
local function wreck(world, flames, cf, scale)
	local body = Color3.fromRGB(38, 32, 30)
	block(world, Vector3.new(4.6, 1.3, 2.2) * scale, cf * CFrame.new(0, 1 * scale, 0), body, Enum.Material.CorrodedMetal)
	block(world, Vector3.new(2.4, 1, 2) * scale, cf * CFrame.new(-0.3 * scale, 2.1 * scale, 0) * CFrame.Angles(0, 0, math.rad(-4)), Color3.fromRGB(26, 22, 22), Enum.Material.CorrodedMetal)
	for _, x in { -1.5, 1.5 } do
		for _, z in { -1.1, 1.1 } do
			block(world, Vector3.new(0.6, 1.2, 1.2) * scale, cf * CFrame.new(x * scale, 0.6 * scale, z * scale) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(18, 18, 18), nil, { Shape = Enum.PartType.Cylinder })
		end
	end
	for i = 1, 6 do
		local base = cf * CFrame.new((i - 3.5) * 0.7 * scale, 2.4 * scale, 0)
		table.insert(flames, {
			Part = block(world, Vector3.one, base, FIRE[(i - 1) % 3 + 1], Enum.Material.Neon),
			Base = base,
			Size = scale * (0.8 + (i % 3) * 0.35),
			Phase = i * 1.7,
		})
	end
end

local function buildScene(parent)
	local vp = UIKit.new("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Ambient = Color3.fromRGB(160, 115, 100),
		LightColor = Color3.fromRGB(255, 160, 100),
		LightDirection = Vector3.new(0.6, -0.45, -0.65),
		Parent = parent,
	})
	UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 22, 30)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(180, 80, 50)),
		ColorSequenceKeypoint.new(0.62, Color3.fromRGB(240, 150, 80)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 22, 22)),
	}), Parent = vp })
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 4, -13), Vector3.new(0, 5, 4)) -- tilted up a little: the sunset sky shows over the ruins
	camera.Parent = vp
	vp.CurrentCamera = camera
	local rng = Random.new(7)

	-- low sun behind the skyline, and the street
	block(world, Vector3.new(26, 26, 26), CFrame.new(-8, 16, 130), Color3.fromRGB(255, 190, 110), Enum.Material.Neon, { Shape = Enum.PartType.Ball })
	block(world, Vector3.new(220, 1, 120), CFrame.new(0, -0.5, 40), Color3.fromRGB(44, 36, 36), Enum.Material.Asphalt)
	for i = -6, 6 do -- faded lane dashes
		block(world, Vector3.new(4, 0.05, 0.4), CFrame.new(i * 9, 0.03, 22), Color3.fromRGB(120, 100, 60))
	end
	block(world, Vector3.new(220, 0.6, 3), CFrame.new(0, 0.3, 32), Color3.fromRGB(70, 58, 54)) -- far curb

	-- skyline: a near row and a far row of ruins
	for _, row in { { Z = 42, Depth = 0.3, Min = 7, Max = 15 }, { Z = 72, Depth = 0.7, Min = 13, Max = 27 } } do
		local x = -80
		while x < 80 do
			local w = rng:NextNumber(8, 16)
			ruin(world, rng, x + w / 2, row.Z + rng:NextNumber(-2, 2), w, rng:NextNumber(row.Min, row.Max), row.Depth)
			x += w + rng:NextNumber(0, 3)
		end
	end

	-- burning wrecks: one behind you, one across the street, one far off
	local flames = {}
	wreck(world, flames, CFrame.new(15, 0, 15) * CFrame.Angles(0, math.rad(20), 0), 0.9)
	wreck(world, flames, CFrame.new(-16, 0, 30) * CFrame.Angles(0, math.rad(-35), math.rad(6)), 1.2)
	wreck(world, flames, CFrame.new(26, 0, 34) * CFrame.Angles(0, math.rad(70), 0), 1.1)
	-- rubble in the foreground
	for i = 1, 10 do
		local s = rng:NextNumber(0.3, 0.9)
		block(world, Vector3.new(s * 1.6, s, s * 1.2), CFrame.new(rng:NextNumber(-16, 16), s / 2, rng:NextNumber(3, 12)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 6), rng:NextNumber(0, 1)), Color3.fromRGB(64, 56, 54), Enum.Material.Slate)
	end

	-- smoke over each fire and embers drifting up, recycled as they fade
	local smoke, embers = {}, {}
	for i = 1, 12 do
		local fire = flames[(i - 1) % #flames + 1].Base.Position
		table.insert(smoke, { Part = block(world, Vector3.one, CFrame.new(fire), Color3.fromRGB(90, 76, 74), nil, { Shape = Enum.PartType.Ball }), Origin = fire, T = i / 12 })
	end
	for i = 1, 30 do
		local fire = flames[(i - 1) % #flames + 1].Base.Position
		table.insert(embers, { Part = block(world, Vector3.new(0.15, 0.15, 0.15), CFrame.new(fire), FIRE[i % 3 + 1], Enum.Material.Neon), Origin = fire, T = rng:NextNumber(), Drift = rng:NextNumber(-1, 1) })
	end

	-- your avatar, on the left of the screen (screen-left is +X here), turned a little toward the horde
	local character = player.Character
	if character then
		character.Archivable = true
		local avatar = character:Clone()
		character.Archivable = false
		for _, d in avatar:GetDescendants() do
			if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Tool") or d:IsA("BillboardGui") then
				d:Destroy()
			end
		end
		local idle = character:FindFirstChild("Animate") and character.Animate:FindFirstChild("idle")
		idle = idle and idle:FindFirstChildOfClass("Animation")
		local root = avatar:FindFirstChild("HumanoidRootPart")
		if root then
			root.Anchored = true
		end
		avatar:PivotTo(CFrame.lookAt(Vector3.new(4.5, 3, 0), Vector3.new(3.2, 3, -1)))
		avatar.Parent = world
		local humanoid = avatar:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and (humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid))
		if animator and idle then
			pcall(function()
				animator:LoadAnimation(idle):Play()
			end)
		end
	end

	-- the horde: preview zombies (not the boss) with their limbs swinging as they run
	local runners = {}
	local previews = ReplicatedStorage:WaitForChild("ZombiePreviews", 10)
	local pool = {}
	for id, def in Zombies.Types do
		if not def.Boss and not def.Nightmare and previews and previews:FindFirstChild(id) then -- Nightmare stays a surprise
			table.insert(pool, id)
		end
	end
	for i = 1, if #pool > 0 then HORDE else 0 do
		local id = pool[(i - 1) % #pool + 1]
		local model = previews[id]:Clone()
		local root = model:FindFirstChild("Root")
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = part == root
			end
		end
		model.Parent = world
		table.insert(runners, {
			Model = model,
			Motors = { root and root:FindFirstChild("LeftArm"), root and root:FindFirstChild("RightArm"), root and root:FindFirstChild("LeftLeg"), root and root:FindFirstChild("RightLeg") },
			X = -SPAN + (i - 1) * (2 * SPAN / HORDE) + math.random() * 3,
			Z = 15 + math.random() * 12, -- well behind you, so they read as a crowd, not a wall
			Speed = Zombies.Types[id].Speed * 0.55,
			Base = model:GetPivot().Y,
			Phase = math.random() * 6,
		})
	end

	return function(dt)
		local t = os.clock()
		for _, r in runners do
			r.X += r.Speed * dt
			if r.X > SPAN then
				r.X -= 2 * SPAN
			end
			local stride = t * r.Speed * 0.7 + r.Phase
			r.Model:PivotTo(CFrame.lookAt(Vector3.new(r.X, r.Base + math.abs(math.sin(stride)) * 0.25, r.Z), Vector3.new(r.X + 1, r.Base, r.Z)))
			local swing = math.sin(stride) * 0.8
			for i, motor in r.Motors do
				if motor then
					local side = if i % 2 == 1 then 1 else -1
					-- arms reach forward like the in-game shamble; legs alternate
					motor.Transform = if i <= 2 then CFrame.Angles(math.rad(-80) + swing * 0.3 * side, 0, 0) else CFrame.Angles(swing * side, 0, 0)
				end
			end
		end
		for _, f in flames do -- flicker: each tongue stretches and sways on its own beat
			local n = math.noise(t * 3, f.Phase)
			local h = f.Size * (1.6 + n * 0.9)
			f.Part.Size = Vector3.new(f.Size * 0.7, h, f.Size * 0.7)
			f.Part.CFrame = f.Base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, t + f.Phase, math.rad(n * 12))
			f.Part.Transparency = 0.1 + math.abs(n) * 0.4
		end
		for _, s in smoke do -- puffs rise, swell and fade, then start over
			s.T = (s.T + dt * 0.12) % 1
			local size = 1.5 + s.T * 7
			s.Part.Size = Vector3.one * size
			s.Part.CFrame = CFrame.new(s.Origin + Vector3.new(s.T * 4, 2 + s.T * 18, s.T * 3))
			s.Part.Transparency = 0.5 + s.T * 0.5
		end
		for _, e in embers do
			e.T = (e.T + dt * 0.3) % 1
			e.Part.CFrame = CFrame.new(e.Origin + Vector3.new(math.sin(t * 2 + e.Drift * 5) * 1.2 + e.Drift * e.T * 4, 1 + e.T * 14, 0))
			e.Part.Transparency = e.T
		end
	end
end

-- a stat tile: coloured edge, small caps label, big value
local function tile(parent, label, value, color, order)
	local f = UIKit.new("Frame", { LayoutOrder = order, BackgroundColor3 = Color3.fromRGB(14, 12, 14), BackgroundTransparency = 0.2, BorderSizePixel = 0, Parent = parent })
	UIKit.Corner(6).Parent = f
	UIKit.Stroke(Color3.fromRGB(70, 56, 52), 1).Parent = f
	UIKit.new("Frame", { Size = UDim2.new(0, 5, 1, 0), BackgroundColor3 = color, BorderSizePixel = 0, Parent = f })
	UIKit.new("TextLabel", { Text = label, Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -28, 0, 18), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, Parent = f })
	UIKit.new("TextLabel", { Text = value, Position = UDim2.fromOffset(18, 30), Size = UDim2.new(1, -28, 0, 40), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 34, TextColor3 = Color3.fromRGB(245, 240, 235), TextXAlignment = Enum.TextXAlignment.Left, Parent = f })
	return f
end

-- results: a finished run's RunResults (the run report), or nil for the plain welcome
function WelcomeController:Show(results)
	local gui = UIKit.Screen("Welcome")
	gui.DisplayOrder = 60
	local step = buildScene(gui)
	-- darken the right side so the panel reads over the scene, and frame the whole thing
	UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(), BorderSizePixel = 0, Parent = gui }, {
		UIKit.new("UIGradient", { Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.45, 1),
			NumberSequenceKeypoint.new(1, 0.25),
		}) }),
	})
	for _, top in { true, false } do -- letterbox bars
		UIKit.new("Frame", { AnchorPoint = Vector2.new(0, if top then 0 else 1), Position = UDim2.fromScale(0, if top then 0 else 1), Size = UDim2.new(1, 0, 0.07, 0), BackgroundColor3 = Color3.fromRGB(8, 6, 8), BorderSizePixel = 0, Parent = gui })
	end
	local root = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	UIKit.AutoScale(root)

	local panel = UIKit.new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -48, 0.5, 0), Size = UDim2.fromOffset(470, 682), BackgroundTransparency = 1, Parent = root })
	local fade = {} -- everything that fades in
	local function text(props)
		props.BackgroundTransparency = 1
		props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
		props.Parent = props.Parent or panel
		local l = UIKit.new("TextLabel", props)
		table.insert(fade, l)
		return l
	end
	if results then -- run report: the outcome is the headline, your name goes on the line above it
		local mode = if results.Tutorial then "TRAINING" elseif results.Nightmare then "NIGHTMARE" else "PORT HARROW"
		local outcome, color = "OVERRUN", T.Danger
		if results.Tutorial then
			outcome, color = "TRAINING DONE", T.Accent
		elseif results.Victory then
			outcome, color = if results.Nightmare then "NIGHTMARE CLEARED" else "VICTORY", T.Cash
		end
		text({ Text = "RUN REPORT  //  " .. mode, Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = Color3.fromRGB(255, 170, 90) })
		text({ Text = "WELCOME BACK, " .. string.upper(player.DisplayName), Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 30), Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = Color3.fromRGB(230, 220, 210) })
		text({ Text = outcome, Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 62), Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = color })
	else
		text({ Text = "SAFEHOUSE  //  PORT HARROW", Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = Color3.fromRGB(255, 170, 90) })
		text({ Text = "WELCOME BACK,", Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 30), Font = Enum.Font.GothamBold, TextSize = 26, TextColor3 = Color3.fromRGB(230, 220, 210) })
		text({ Text = string.upper(player.DisplayName), Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 62), Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.fromRGB(255, 255, 255) })
	end
	UIKit.new("Frame", { Position = UDim2.fromOffset(0, 124), Size = UDim2.fromOffset(90, 4), BackgroundColor3 = T.Cash, BorderSizePixel = 0, Parent = panel })

	-- level header: LEVEL n + rank, the run's +XP, the bar (XP inside it), and chips breaking the XP down
	local GOLD = Color3.fromRGB(255, 200, 70)
	local xpNow = player:GetAttribute("XP") or 0
	local xpFrom = math.min(if results and results.XPBefore then results.XPBefore else xpNow, xpNow)
	local lvl = UIKit.new("Frame", { Position = UDim2.fromOffset(0, 140), Size = UDim2.fromOffset(470, 80), BackgroundTransparency = 1, Parent = panel })
	local lvlText = text({ Parent = lvl, Size = UDim2.fromOffset(150, 30), Font = Enum.Font.GothamBlack, TextSize = 30, TextColor3 = Color3.fromRGB(255, 255, 255) })
	local pop = UIKit.new("UIScale", { Parent = lvlText })
	local rankText = text({ Parent = lvl, Position = UDim2.fromOffset(152, 9), Size = UDim2.fromOffset(170, 18), Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = Color3.fromRGB(255, 170, 90) })
	if results and (results.XP or 0) > 0 then
		text({ Parent = lvl, Text = "+" .. Util.FormatNumber(results.XP) .. " XP", Position = UDim2.fromOffset(300, 0), Size = UDim2.fromOffset(170, 30), Font = Enum.Font.GothamBlack, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = GOLD })
	end
	local track = UIKit.new("Frame", { Position = UDim2.fromOffset(0, 36), Size = UDim2.fromOffset(470, 21), BackgroundColor3 = Color3.fromRGB(14, 12, 14), BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = lvl })
	UIKit.Corner(4).Parent = track
	UIKit.Stroke(GOLD, 1).Parent = track
	local fill = UIKit.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = GOLD, BorderSizePixel = 0, Parent = track })
	UIKit.Corner(4).Parent = fill
	local xpText = text({ Parent = track, Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(255, 255, 255), TextStrokeTransparency = 0.3, ZIndex = 2 })
	if results then -- where the XP came from (Levels.RunXP)
		local chips = UIKit.new("Frame", { Position = UDim2.fromOffset(0, 60), Size = UDim2.fromOffset(470, 20), BackgroundTransparency = 1, Parent = lvl })
		UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = chips })
		local parts = { { "KILLS", "+" .. Util.FormatNumber((results.Kills or 0) * Levels.PerKill) }, { "WAVES", "+" .. Util.FormatNumber((results.WavesCleared or 0) * Levels.PerWave) } }
		if results.Victory and not results.Tutorial then
			table.insert(parts, { "VICTORY", "+" .. Levels.Victory })
		end
		if results.Nightmare then
			table.insert(parts, { "NIGHTMARE", "x" .. Levels.NightmareMult })
		end
		for _, part in parts do
			local chip = UIKit.new("TextLabel", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), BackgroundColor3 = Color3.fromRGB(14, 12, 14), BackgroundTransparency = 0.15, BorderSizePixel = 0, RichText = true, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.fromRGB(200, 190, 180), Text = part[1] .. "  <font color=\"#8CE65A\">" .. part[2] .. "</font>", Parent = chips })
			UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = chip })
			UIKit.Stroke(Color3.fromRGB(70, 90, 60), 1).Parent = chip
		end
	end
	local function showXP(xp)
		local level, into, need = Levels.FromXP(xp)
		lvlText.Text = "LEVEL " .. level
		rankText.Text = Levels.Rank(level)
		xpText.Text = Util.FormatNumber(math.floor(into)) .. " / " .. Util.FormatNumber(need) .. " XP"
		fill.Size = UDim2.fromScale(into / need, 1)
		return level
	end
	showXP(xpFrom)
	if xpNow > xpFrom then
		task.delay(0.9, function() -- after the panel slides in
			local last = Levels.FromXP(xpFrom)
			local seconds = math.clamp(1 + (Levels.FromXP(xpNow) - last) * 0.7, 1.2, 4)
			local t0 = os.clock()
			while lvl.Parent do
				local u = math.min((os.clock() - t0) / seconds, 1)
				local level = showXP(xpFrom + (xpNow - xpFrom) * (1 - (1 - u) ^ 2))
				if level > last then -- level up: the bar flashes white, the level pops, LEVEL UP! rises off the bar
					last = level
					fill.BackgroundColor3 = Color3.new(1, 1, 1)
					TweenService:Create(fill, TweenInfo.new(0.5), { BackgroundColor3 = GOLD }):Play()
					pop.Scale = 1.4
					TweenService:Create(pop, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
					local up = UIKit.new("TextLabel", { Text = "LEVEL UP!", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, 36), Size = UDim2.fromOffset(240, 30), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 28, TextColor3 = GOLD, TextStrokeTransparency = 0.4, ZIndex = 3, Parent = lvl })
					TweenService:Create(up, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, -6), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
					task.delay(1.3, up.Destroy, up)
				end
				if u >= 1 then
					break
				end
				task.wait()
			end
		end)
	end

	-- stats
	local grid = UIKit.new("Frame", { Position = UDim2.fromOffset(0, 228), Size = UDim2.fromOffset(470, 270), BackgroundTransparency = 1, Parent = panel })
	UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(227, 80), CellPadding = UDim2.fromOffset(16, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	local s = decode("AchievementsJson").Stats or {}
	local studied, total = 0, 0
	for id, def in Zombies.Types do
		if def.Index then -- the index's cards (not the Husk's halves)
			total += 1
			studied += if (s["Kills_" .. id] or 0) > 0 then 1 else 0
		end
	end
	local tiles = if results then {
		tile(grid, "WAVE REACHED", tostring(results.Wave or 0), Color3.fromRGB(255, 170, 70), 1),
		tile(grid, "ZOMBIES KILLED", Util.FormatNumber(results.Kills or 0), Color3.fromRGB(255, 90, 80), 2),
		tile(grid, "GEMS EARNED", if results.Nightmare and not results.Victory and not results.Tutorial then "NONE" else "+◆ " .. Util.FormatNumber(results.Gems or 0), T.Gem, 3),
		tile(grid, "WAVES CLEARED", tostring(results.WavesCleared or 0), T.Cash, 4),
		tile(grid, "GEMS", "◆ " .. Util.FormatNumber(player:GetAttribute("Gems") or 0), T.Gem, 5),
		tile(grid, "ENEMIES STUDIED", studied .. " / " .. total, Color3.fromRGB(150, 255, 110), 6),
	} else {
		tile(grid, "GEMS", "◆ " .. Util.FormatNumber(player:GetAttribute("Gems") or 0), T.Gem, 1),
		tile(grid, "BEST WAVE", tostring(player:GetAttribute("BestWave") or 0), Color3.fromRGB(255, 170, 70), 2),
		tile(grid, "RUNS", Util.FormatNumber(s.Runs or 0), Color3.fromRGB(110, 170, 255), 3),
		tile(grid, "ZOMBIES KILLED", Util.FormatNumber(s.Kills or 0), Color3.fromRGB(255, 90, 80), 4),
		tile(grid, "VICTORIES", Util.FormatNumber(s.Victories or 0), T.Cash, 5),
		tile(grid, "ENEMIES STUDIED", studied .. " / " .. total, Color3.fromRGB(150, 255, 110), 6),
	}
	if results and results.NewBest and not results.Tutorial then -- a gold tag on the wave tile's corner
		UIKit.new("TextLabel", { Text = "NEW BEST", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.fromOffset(86, 20), BackgroundColor3 = GOLD, BorderSizePixel = 0, Font = Enum.Font.GothamBlack, TextSize = 13, TextColor3 = Color3.fromRGB(30, 20, 10), ZIndex = 3, Parent = tiles[1] })
	end

	-- tracked bounty (or a nudge toward the board)
	local strip = UIKit.new("Frame", { Position = UDim2.fromOffset(0, 514), Size = UDim2.fromOffset(470, 56), BackgroundColor3 = Color3.fromRGB(14, 12, 14), BackgroundTransparency = 0.2, BorderSizePixel = 0, Parent = panel })
	UIKit.Corner(6).Parent = strip
	UIKit.Stroke(Color3.fromRGB(255, 200, 70), 1).Parent = strip
	local bounty = decode("BountyJson")
	local tracked = bounty.Day == Bounties.Today(workspace:GetServerTimeNow()) and bounty.Tracked and Bounties.ById[bounty.Tracked]
	text({ Text = "TRACKED BOUNTY", Parent = strip, Position = UDim2.fromOffset(14, 7), Size = UDim2.new(1, -28, 0, 16), Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.fromRGB(255, 200, 70) })
	if tracked then
		local n = math.min((bounty.Progress or {})[tracked.Id] or 0, tracked.Goal)
		text({ Text = tracked.Name .. "  ·  " .. n .. " / " .. tracked.Goal .. "  ·  ◆ " .. tracked.Gems, Parent = strip, Position = UDim2.fromOffset(14, 26), Size = UDim2.new(1, -28, 0, 22), Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Color3.fromRGB(240, 235, 230) })
	else
		text({ Text = "None yet. Pick one at the Bounty Board by the gate.", Parent = strip, Position = UDim2.fromOffset(14, 26), Size = UDim2.new(1, -28, 0, 22), Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Color3.fromRGB(190, 180, 170) })
	end

	local done = false
	local enter = UIKit.new("TextButton", { Name = "Enter", Position = UDim2.fromOffset(0, 588), Size = UDim2.fromOffset(470, 78), BackgroundColor3 = Color3.fromRGB(255, 255, 255), AutoButtonColor = false, Text = "ENTER SAFEHOUSE   →", Font = Enum.Font.GothamBlack, TextSize = 30, TextColor3 = Color3.fromRGB(16, 30, 16), Parent = panel })
	UIKit.Corner(6).Parent = enter
	UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(170, 255, 120), Color3.fromRGB(90, 200, 70)), Parent = enter })
	local enterScale = UIKit.new("UIScale", { Parent = enter })
	enter.MouseEnter:Connect(function()
		TweenService:Create(enterScale, TweenInfo.new(0.12), { Scale = 1.03 }):Play()
	end)
	enter.MouseLeave:Connect(function()
		TweenService:Create(enterScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	enter.Activated:Connect(function()
		done = true
	end)
	local keys = UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA then
			done = true
		end
	end)

	-- a line from one of the safehouse people, bottom-left
	local who = Survivors.List[math.random(1, #Survivors.List)]
	local quote = text({ Text = "\"" .. who.Lines[math.random(1, #who.Lines)] .. "\"   — " .. who.Name, Parent = root, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 48, 1, -80), Size = UDim2.fromOffset(620, 40), Font = Enum.Font.GothamMedium, TextSize = 17, TextWrapped = true, TextColor3 = Color3.fromRGB(235, 215, 200) })
	quote.TextYAlignment = Enum.TextYAlignment.Bottom

	-- entrance: the panel slides in, the tiles pop in one after another
	panel.Position = UDim2.new(1, 40, 0.5, 0)
	TweenService:Create(panel, TweenInfo.new(0.6, Enum.EasingStyle.Quint), { Position = UDim2.new(1, -48, 0.5, 0) }):Play()
	for _, l in fade do
		l.TextTransparency = 1
		TweenService:Create(l, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
	end
	for i, t in tiles do
		local scale = UIKit.new("UIScale", { Scale = 0.6, Parent = t })
		task.delay(0.25 + i * 0.07, function()
			TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end)
	end

	local conn = RunService.RenderStepped:Connect(step)
	while not done and not player:GetAttribute("InRun") and gui.Parent do
		task.wait(0.1)
	end
	keys:Disconnect()
	-- exit: fade to black, drop the screen, fade back in on the safehouse
	local cover = UIKit.Screen("WelcomeFade")
	cover.DisplayOrder = 61
	local black = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = cover })
	TweenService:Create(black, TweenInfo.new(0.35), { BackgroundTransparency = 0 }):Play()
	task.wait(0.4)
	conn:Disconnect()
	gui:Destroy()
	TweenService:Create(black, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	task.delay(0.7, cover.Destroy, cover)
end

function WelcomeController:Start()
	-- lobby servers only, once per join, and only for players past the tutorial
	if GameState:GetAttribute("ServerKind") == "Match" then
		return
	end
	-- a run played on this server (Studio): the report once you're back at the safehouse
	Remotes.RunResults.OnClientEvent:Connect(function(results)
		while player:GetAttribute("InRun") do
			task.wait(0.3)
		end
		if not player.Character then
			player.CharacterAdded:Wait()
		end
		task.wait(0.8) -- the character is placed and dressed in the lobby
		self:Show(results)
	end)
	-- just back from a match server: its report rides on the teleport data
	local ok, data = pcall(TeleportService.GetLocalPlayerTeleportData, TeleportService)
	local report = ok and type(data) == "table" and type(data.Results) == "table" and data.Results[tostring(player.UserId)] or nil
	local started = os.clock()
	while not player:GetAttribute("AchievementsJson") and os.clock() - started < 15 do
		task.wait(0.2)
	end
	if (not report and ((decode("AchievementsJson").Stats or {}).Runs or 0) < 1) or player:GetAttribute("InRun") then
		return
	end
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	task.wait(0.5) -- let the avatar's clothes and accessories load
	self:Show(if type(report) == "table" then report else nil)
end

return WelcomeController
