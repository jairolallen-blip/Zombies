-- WelcomeController: the "welcome back" screen a returning player sees when they reach a lobby server (once
-- per join, after the tutorial: profile Stats.Runs >= 1). Behind it, a ViewportFrame scene: your avatar
-- standing on the left playing its idle animation while a horde (ReplicatedStorage.ZombiePreviews, built by
-- ZombieService) runs past from right to left in the dusk. On the right: your stats and ENTER SAFEHOUSE.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameState = require(Shared.GameState)
local Zombies = require(Shared.Config.Zombies)
local Util = require(Shared.Util)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local T = UIKit.Theme
local player = Players.LocalPlayer
local WelcomeController = {}

local HORDE = 12 -- runners in the background
local SPAN = 34 -- they run from x = -SPAN to +SPAN (screen right to left)

local function stats()
	local ok, data = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("AchievementsJson") or "{}")
	return if ok and type(data) == "table" then data.Stats or {} else {}
end

-- the scene: avatar on the left, horde behind it; returns a step(dt) that animates it
local function buildScene(parent)
	local vp = UIKit.new("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(70, 34, 26),
		Ambient = Color3.fromRGB(120, 90, 80),
		LightColor = Color3.fromRGB(255, 170, 110),
		LightDirection = Vector3.new(0.7, -0.5, 0.6),
		Parent = parent,
	})
	UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 190, 140), Color3.fromRGB(60, 40, 50)), Parent = vp })
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local ground = Instance.new("Part")
	ground.Anchored = true
	ground.Size = Vector3.new(160, 1, 60)
	ground.CFrame = CFrame.new(0, -0.5, 20)
	ground.Color = Color3.fromRGB(46, 40, 38)
	ground.Material = Enum.Material.Asphalt
	ground.Parent = world
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 4, -13), Vector3.new(0, 3.2, 4))
	camera.Parent = vp
	vp.CurrentCamera = camera

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
		if not def.Boss and previews and previews:FindFirstChild(id) then
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
					local arm = i <= 2
					local side = if i % 2 == 1 then 1 else -1
					-- arms reach forward like the in-game shamble; legs alternate
					motor.Transform = if arm then CFrame.Angles(math.rad(-80) + swing * 0.3 * side, 0, 0) else CFrame.Angles(swing * side, 0, 0)
				end
			end
		end
	end
end

local function tile(parent, label, value, color, order)
	local f = UIKit.new("Frame", { LayoutOrder = order, Size = UDim2.fromOffset(200, 84), BackgroundColor3 = Color3.fromRGB(18, 18, 20), BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = parent })
	UIKit.Stroke(color, 3).Parent = f
	UIKit.Label({ Text = label, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 22), TextSize = 17, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, Parent = f })
	UIKit.Label({ Text = value, Position = UDim2.fromOffset(14, 32), Size = UDim2.new(1, -28, 0, 44), TextSize = 38, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = f })
end

function WelcomeController:Show()
	local gui = UIKit.Screen("Welcome")
	gui.DisplayOrder = 60
	local step = buildScene(gui)
	local root = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	UIKit.AutoScale(root)
	local panel = UIKit.new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -40, 0.5, 0), Size = UDim2.fromOffset(440, 560), BackgroundTransparency = 1, Parent = root })
	UIKit.Label({ Text = "WELCOME BACK", Size = UDim2.new(1, 0, 0, 30), TextSize = 26, TextColor3 = T.Sign, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	UIKit.Label({ Text = string.upper(player.DisplayName), Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 56), TextSize = 50, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	local grid = UIKit.new("Frame", { Position = UDim2.fromOffset(0, 104), Size = UDim2.fromOffset(440, 300), BackgroundTransparency = 1, Parent = panel })
	UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(212, 84), CellPadding = UDim2.fromOffset(16, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	local s = stats()
	local studied, total = 0, 0
	for id in Zombies.Types do
		total += 1
		studied += if (s["Kills_" .. id] or 0) > 0 then 1 else 0
	end
	tile(grid, "GEMS", "◆ " .. Util.FormatNumber(player:GetAttribute("Gems") or 0), T.Gem, 1)
	tile(grid, "BEST WAVE", tostring(player:GetAttribute("BestWave") or 0), T.Accent, 2)
	tile(grid, "RUNS", Util.FormatNumber(s.Runs or 0), Color3.fromRGB(110, 170, 255), 3)
	tile(grid, "ZOMBIES KILLED", Util.FormatNumber(s.Kills or 0), T.Danger, 4)
	tile(grid, "VICTORIES", Util.FormatNumber(s.Victories or 0), T.Cash, 5)
	tile(grid, "ENEMIES STUDIED", studied .. " / " .. total, Color3.fromRGB(150, 255, 110), 6)
	local done = false
	local enter = UIKit.Button({ Name = "Enter", Position = UDim2.fromOffset(0, 440), Size = UDim2.new(1, 0, 0, 84), Text = "ENTER SAFEHOUSE  →", TextSize = 34, BackgroundColor3 = T.Cash, TextColor3 = Color3.fromRGB(16, 30, 16), Parent = panel }, function()
		done = true
	end)
	enter.ZIndex = 2
	local conn = RunService.RenderStepped:Connect(step)
	while not done and not player:GetAttribute("InRun") and gui.Parent do
		task.wait(0.1)
	end
	conn:Disconnect()
	gui:Destroy()
end

function WelcomeController:Start()
	-- lobby servers only, once per join, and only for players past the tutorial
	if GameState:GetAttribute("ServerKind") == "Match" then
		return
	end
	local started = os.clock()
	while not player:GetAttribute("AchievementsJson") and os.clock() - started < 15 do
		task.wait(0.2)
	end
	if (stats().Runs or 0) < 1 or player:GetAttribute("InRun") then
		return
	end
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	task.wait(0.5) -- let the avatar's clothes and accessories load
	self:Show()
end

return WelcomeController
