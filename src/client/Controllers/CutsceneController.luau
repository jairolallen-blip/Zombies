-- CutsceneController: the drop-in at the start of a run (vault: Match Start.md).
-- While the player's "Deploying" attribute is true the server holds them above the arena; this
-- plays a client-side helicopter flight from GameState.DeployFrom (lobby helipad) to above
-- GameState.DeployTo (arena spawns), timed by DeployStart/DeployDuration (server clock), with
-- three camera shots (lift-off, chase, overhead) and letterbox bars. Then the camera returns to
-- the character, who parachutes down (MatchService:_parachute).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local GameState = require(Shared.GameState)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local player = Players.LocalPlayer
local CutsceneController = {}
local playing = false

-- Helicopter parts in its local space (-Z = nose). Spin = axis the part rotates around.
local OLIVE = Color3.fromRGB(70, 78, 52)
local DARK = Color3.fromRGB(28, 30, 28)
local HELI = {
	{ "Body", Vector3.new(6, 5, 11), CFrame.new(0, 0, 0), OLIVE },
	{ "Nose", Vector3.new(5.4, 4, 3), CFrame.new(0, -0.3, -6.5), OLIVE },
	{ "Glass", Vector3.new(5, 2.6, 0.3), CFrame.new(0, 0.6, -8.05), Color3.fromRGB(40, 50, 55) },
	{ "Door", Vector3.new(0.2, 3.4, 4), CFrame.new(3.05, -0.2, -1), DARK },
	{ "Door", Vector3.new(0.2, 3.4, 4), CFrame.new(-3.05, -0.2, -1), DARK },
	{ "Boom", Vector3.new(1.6, 1.6, 12), CFrame.new(0, 1, 11.5), OLIVE },
	{ "Fin", Vector3.new(0.4, 4.5, 3), CFrame.new(0, 3, 17), OLIVE },
	{ "Mast", Vector3.new(0.8, 1.4, 0.8), CFrame.new(0, 3.2, 0), DARK },
	{ "Skid", Vector3.new(0.4, 0.4, 12), CFrame.new(2.8, -3.6, 0), DARK },
	{ "Skid", Vector3.new(0.4, 0.4, 12), CFrame.new(-2.8, -3.6, 0), DARK },
	{ "Strut", Vector3.new(0.3, 1.4, 0.3), CFrame.new(2.8, -3, -3), DARK },
	{ "Strut", Vector3.new(0.3, 1.4, 0.3), CFrame.new(-2.8, -3, -3), DARK },
	{ "Strut", Vector3.new(0.3, 1.4, 0.3), CFrame.new(2.8, -3, 3), DARK },
	{ "Strut", Vector3.new(0.3, 1.4, 0.3), CFrame.new(-2.8, -3, 3), DARK },
	{ "Blade", Vector3.new(1.2, 0.2, 32), CFrame.new(0, 4, 0), DARK, "Y" },
	{ "Blade", Vector3.new(32, 0.2, 1.2), CFrame.new(0, 4, 0), DARK, "Y" },
	{ "TailRotor", Vector3.new(0.2, 3.6, 0.5), CFrame.new(0.5, 3, 17.3), DARK, "X" },
}

local function buildHelicopter()
	local folder = Instance.new("Folder")
	folder.Name = "DeployHelicopter"
	local parts = {}
	for _, def in HELI do
		local p = Instance.new("Part")
		p.Name = def[1]
		p.Size = def[2]
		p.Color = def[4]
		p.Material = if def[1] == "Glass" then Enum.Material.SmoothPlastic else Enum.Material.Metal
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = folder
		table.insert(parts, { Part = p, Offset = def[3], Spin = def[5] })
	end
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 50
	light.Range = 60
	light.Brightness = 3
	light.Color = Color3.fromRGB(255, 240, 210)
	light.Parent = parts[2].Part
	folder.Parent = workspace.CurrentCamera
	return folder, parts
end

local function placeHelicopter(parts, cframe, now)
	for _, entry in parts do
		local cf = cframe * entry.Offset
		if entry.Spin == "Y" then
			cf *= CFrame.Angles(0, now * 30, 0)
		elseif entry.Spin == "X" then
			cf *= CFrame.Angles(now * 40, 0, 0)
		end
		entry.Part.CFrame = cf
	end
end

local function bezier(p0, p1, p2, p3, t)
	local u = 1 - t
	return p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t)
end

local function letterbox()
	local gui = UIKit.Screen("Cutscene")
	gui.DisplayOrder = 20
	local bars = {}
	for _, top in { true, false } do
		local bar = UIKit.new("Frame", {
			AnchorPoint = Vector2.new(0, if top then 0 else 1),
			Position = UDim2.fromScale(0, if top then 0 else 1),
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Parent = gui,
		})
		TweenService:Create(bar, TweenInfo.new(0.6), { Size = UDim2.new(1, 0, 0.11, 0) }):Play()
		table.insert(bars, bar)
	end
	local title = UIKit.Label({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 40, 1, -26), Size = UDim2.fromOffset(600, 34), Text = "DROP ZONE — CITY SQUARE", TextSize = 30, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, ZIndex = 2, Parent = gui })
	local sub = UIKit.Label({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 40, 1, -60), Size = UDim2.fromOffset(600, 22), Text = "OPERATION LAST LIGHT", TextSize = 18, TextColor3 = UIKit.Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, ZIndex = 2, Parent = gui })
	task.delay(1.2, function()
		TweenService:Create(title, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
		TweenService:Create(sub, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
	end)
	return function()
		for _, bar in bars do
			TweenService:Create(bar, TweenInfo.new(0.5), { Size = UDim2.new(1, 0, 0, 0) }):Play()
		end
		TweenService:Create(title, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		TweenService:Create(sub, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		task.delay(0.6, function()
			gui:Destroy()
		end)
	end
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

function CutsceneController:Play()
	local from, to = GameState:GetAttribute("DeployFrom"), GameState:GetAttribute("DeployTo")
	local start, duration = GameState:GetAttribute("DeployStart"), GameState:GetAttribute("DeployDuration")
	if playing or typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or not start or not duration then
		return
	end
	playing = true
	local cfg = GameConfig.Deploy
	local p0 = from + Vector3.new(0, 4, 0)
	local p1 = from + Vector3.new(0, cfg.CruiseHeight * 0.7, 0)
	local p2 = Vector3.new((from.X + to.X) / 2, cfg.CruiseHeight + 10, (from.Z + to.Z) / 2)
	local p3 = to + Vector3.new(0, cfg.DropHeight + 12, 0)
	local heading = Vector3.new(to.X - from.X, 0, to.Z - from.Z).Unit

	local camera = workspace.CurrentCamera
	local folder, parts = buildHelicopter()
	local closeLetterbox = letterbox()
	camera.CameraType = Enum.CameraType.Scriptable
	local heliCF = CFrame.lookAt(p0, p0 + heading)

	local function finish()
		RunService:UnbindFromRenderStep("SAMZ_Cutscene")
		closeLetterbox()
		setDeployersHidden(false)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		camera.CameraType = Enum.CameraType.Custom
		if humanoid then
			camera.CameraSubject = humanoid
		end
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
			placeHelicopter(parts, cf, workspace:GetServerTimeNow())
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
		local s = t * t * (3 - 2 * t)
		local pos = bezier(p0, p1, p2, p3, s)
		local ahead = bezier(p0, p1, p2, p3, math.min(s + 0.02, 1))
		local flat = Vector3.new(ahead.X - pos.X, 0, ahead.Z - pos.Z)
		local speed = math.clamp(flat.Magnitude / 2.5, 0, 1)
		local level = CFrame.lookAt(pos, pos + heading)
		heliCF = level * CFrame.Angles(-0.22 * speed, 0, math.sin(now * 1.3) * 0.03)
		placeHelicopter(parts, heliCF, now)

		if t < 0.22 then -- lift-off, low and to the side of the helipad
			camera.CFrame = CFrame.lookAt(from + Vector3.new(22, 6, 26), pos + Vector3.new(0, 2, 0))
		elseif t < 0.72 then -- chase over the rooftops
			camera.CFrame = CFrame.lookAt((level * CFrame.new(14, 9, 34)).Position, pos + heading * 20)
		else -- overhead on the square as the bird arrives
			camera.CFrame = CFrame.lookAt(to + Vector3.new(46, 130, 64), to + Vector3.new(0, 20, 0))
		end
	end)
end

function CutsceneController:Init()
	player:GetAttributeChangedSignal("Deploying"):Connect(function()
		if player:GetAttribute("Deploying") then
			task.spawn(self.Play, self)
		end
	end)
end

return CutsceneController
