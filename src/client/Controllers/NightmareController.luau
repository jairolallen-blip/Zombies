-- NightmareController: the client side of the Nightmare pad on the Flight Line (Map/FlightLine
-- buildNightmare; Config/Nightmare). For a player who has unlocked Nightmare (Stats.Victories in
-- AchievementsJson) the cage's chained gate opens locally: no collision, chains and panels hidden. The
-- character is client-owned, so walking through works; everyone else still hits the gate, and
-- QueueService refuses to board them anyway. The gate sign shows this player's progress or the pad's squad.
-- During a Nightmare run it also fades in a quiet music loop (Nightmare.Music), dropped while the boss
-- is up so its own music plays alone (BossController), a heartbeat that rises as zombies close in
-- (Nightmare.Heartbeat), and the city's street lamps go out or flicker (Nightmare.Lamps; local only, picked
-- by lamp position so every player sees the same ones; restored when the run ends).
-- The Wailer's scream (ZombieService:_wail): "WailStart" plays the scream from it and swells its throat sac,
-- "Wail" rolls out a shockwave ring, and players within its Radius get blurred sight, ringing ears and are
-- rooted for Stun seconds.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameState = require(Shared.GameState)
local Remotes = require(Shared.Remotes)
local Nightmare = require(Shared.Config.Nightmare)

local player = Players.LocalPlayer
local PAD_ID = 5

local NightmareController = {}

local function decode(attr)
	local ok, value = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute(attr) or GameState:GetAttribute(attr) or "")
	return if ok and type(value) == "table" then value else {}
end

local function inNightmareRun()
	return player:GetAttribute("InRun") == true and GameState:GetAttribute("Difficulty") == "Nightmare"
end

local music = nil -- the Sound while it plays

local function updateMusic()
	local boss = player:GetAttribute("BossIntro") or (GameState:GetAttribute("BossName") or "") ~= ""
	local want = inNightmareRun() and not boss
	if want and not music then
		music = Instance.new("Sound")
		music.Name = "NightmareMusic"
		music.SoundId = "rbxassetid://" .. Nightmare.Music.Id
		music.Looped = true
		music.Volume = 0
		music.Parent = SoundService
		music:Play()
		TweenService:Create(music, TweenInfo.new(4), { Volume = Nightmare.Music.Volume }):Play()
	elseif not want and music then
		local old = music
		music = nil
		TweenService:Create(old, TweenInfo.new(2), { Volume = 0 }):Play()
		task.delay(2, old.Destroy, old)
	end
end

local heart = nil -- the heartbeat Sound while it's audible
local heartLevel = 0 -- 0..1, eased towards how many zombies are close

local function updateHeart(dt)
	local cfg = Nightmare.Heartbeat
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local zombies = workspace:FindFirstChild("Zombies")
	local target = 0
	if root and zombies and inNightmareRun() then
		local near = 0
		for _, z in zombies:GetChildren() do
			if z:IsA("Model") and (z:GetPivot().Position - root.Position).Magnitude < cfg.Radius then
				near += 1
			end
		end
		target = math.min(near / cfg.Full, 1)
	end
	heartLevel += (target - heartLevel) * math.min(dt * 2, 1)
	if heartLevel > 0.02 and not heart then
		heart = Instance.new("Sound")
		heart.Name = "NightmareHeartbeat"
		heart.SoundId = "rbxassetid://" .. cfg.Id
		heart.Looped = true
		heart.Parent = SoundService
		heart:Play()
	elseif heartLevel <= 0.02 and heart then
		heart:Destroy()
		heart = nil
	end
	if heart then
		heart.Volume = heartLevel * cfg.Volume
		heart.PlaybackSpeed = 1 + 0.35 * heartLevel
	end
end

local lamps = {} -- [StreetLamp Head] = { Light, Kind, Color, Material, On }
local lampConn = nil -- Arena.DescendantAdded while a Nightmare run plays (lamps stream in)

local function setLamp(head, entry, on)
	if entry.On ~= on then
		entry.On = on
		entry.Light.Enabled = on
		head.Material = if on then entry.Material else Enum.Material.Metal
		head.Color = if on then entry.Color else Color3.fromRGB(58, 58, 60)
	end
end

local function addLamp(head)
	local light = head.Parent and head.Parent.Name == "StreetLamp" and head.Name == "Head" and head:FindFirstChildOfClass("PointLight")
	if not light or lamps[head] then
		return
	end
	local roll = Random.new(math.floor(head.Position.X) * 7919 + math.floor(head.Position.Z)):NextNumber()
	local kind = if roll < Nightmare.Lamps.Dead then "Dead" elseif roll < Nightmare.Lamps.Dead + Nightmare.Lamps.Flicker then "Flicker" else "Steady"
	lamps[head] = { Light = light, Kind = kind, Color = head.Color, Material = head.Material, On = true }
	if kind == "Dead" then
		setLamp(head, lamps[head], false)
	end
end

local function updateLamps()
	local arena = workspace:FindFirstChild("OurMap") and workspace.OurMap:FindFirstChild("Arena")
	if inNightmareRun() and arena and not lampConn then
		for _, d in arena:GetDescendants() do
			addLamp(d)
		end
		lampConn = arena.DescendantAdded:Connect(addLamp)
	elseif not inNightmareRun() and lampConn then
		lampConn:Disconnect()
		lampConn = nil
		for head, entry in lamps do
			setLamp(head, entry, true)
		end
		table.clear(lamps)
	end
	for head, entry in lamps do
		if entry.Kind == "Flicker" then -- mostly on, with short stutters
			setLamp(head, entry, not ((not entry.On and math.random() < 0.6) or math.random() < 0.04))
		end
	end
end

local function onEffect(kind, data)
	if kind == "WailStart" then
		local throat = data.Model and data.Model:FindFirstChild("Throat")
		if not throat then
			return
		end
		local scream = Instance.new("Sound")
		scream.SoundId = "rbxassetid://" .. Nightmare.WailSound.Id
		scream.Volume = Nightmare.WailSound.Volume
		scream.RollOffMaxDistance = 220
		scream.Parent = throat
		scream:Play()
		task.delay(6, scream.Destroy, scream)
		local base = throat:GetAttribute("BaseSize") or throat.Size -- swells for the scream, then settles back
		throat:SetAttribute("BaseSize", base)
		local swell = TweenService:Create(throat, TweenInfo.new(data.Time, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = base * 1.8 })
		swell.Completed:Connect(function()
			TweenService:Create(throat, TweenInfo.new(0.6), { Size = base }):Play()
		end)
		swell:Play()
	elseif kind == "Wail" then
		-- the roar rolls out as a pale shockwave everyone can see
		local ring = Instance.new("Part")
		ring.Shape = Enum.PartType.Cylinder
		ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(170, 215, 255)
		ring.Transparency = 0.35
		ring.Size = Vector3.new(0.3, 4, 4)
		ring.CFrame = CFrame.new(data.Position.X, data.Position.Y - 2, data.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
		ring.Parent = workspace.CurrentCamera
		TweenService:Create(ring, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.3, data.Radius * 2, data.Radius * 2), Transparency = 1 }):Play()
		task.delay(0.6, ring.Destroy, ring)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or (root.Position - data.Position).Magnitude > data.Radius then
			return
		end
		-- caught in it: rooted to the spot for a moment, ears ringing (the character is ours to move)
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and data.Stun and not humanoid:GetAttribute("WailStun") then -- an overlapping roar doesn't save 0
			humanoid:SetAttribute("WailStun", true)
			local speed, jump = humanoid.WalkSpeed, humanoid.JumpPower
			humanoid.WalkSpeed, humanoid.JumpPower = 0, 0
			task.delay(data.Stun, function()
				humanoid:SetAttribute("WailStun", nil)
				if humanoid.Parent and humanoid.WalkSpeed == 0 then -- unless the server set a new speed meanwhile
					humanoid.WalkSpeed, humanoid.JumpPower = speed, jump
				end
			end)
		end
		local ringing = Instance.new("Sound")
		ringing.SoundId = "rbxassetid://" .. Nightmare.RingSound.Id
		ringing.Volume = Nightmare.RingSound.Volume
		ringing.Parent = SoundService
		ringing:Play()
		TweenService:Create(ringing, TweenInfo.new(data.Blur + 1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Volume = 0 }):Play()
		task.delay(data.Blur + 1.6, ringing.Destroy, ringing)
		local blur = Instance.new("BlurEffect")
		blur.Name = "WailBlur"
		blur.Size = 22
		blur.Parent = Lighting
		TweenService:Create(blur, TweenInfo.new(data.Blur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = 0 }):Play()
		task.delay(data.Blur, blur.Destroy, blur)
	end
end

function NightmareController:Start()
	Remotes.Effect.OnClientEvent:Connect(onEffect)
	task.spawn(function()
		local last = os.clock()
		while true do
			local now = os.clock()
			updateHeart(now - last)
			updateLamps()
			last = now
			task.wait(0.08)
		end
	end)
	while true do
		updateMusic()
		local lobby = workspace:FindFirstChild("OurMap") and workspace.OurMap:FindFirstChild("Lobby")
		local cage = lobby and lobby:FindFirstChild("FlightLine") and lobby.FlightLine:FindFirstChild("Nightmare")
		if cage then -- streamed in
			local wins = decode("AchievementsJson").Stats
			wins = wins and wins.Victories or 0
			local open = Nightmare.Unlocked({ Victories = wins })
			local gate = cage:FindFirstChild("Gate")
			for _, p in if gate then gate:GetChildren() else {} do
				p.CanCollide = not open and p.Name == "Panel"
				p.Transparency = if open then 1 elseif p.Name == "Panel" then 0.2 else 0
			end
			local label = cage:FindFirstChild("Sign") and cage.Sign:FindFirstChild("Text", true)
			if label then
				local pad = decode("Pad" .. PAD_ID)
				label.Text = if not open then string.format("LOCKED  ·  NIGHTMARE · %d/%d WINS", math.min(wins, Nightmare.WinsToUnlock), Nightmare.WinsToUnlock)
					elseif (pad.Count or 0) > 0 then string.format("NIGHTMARE · %d/%d", pad.Count, pad.Size)
					else "NIGHTMARE · OPEN"
			end
		end
		task.wait(0.5)
	end
end

return NightmareController
