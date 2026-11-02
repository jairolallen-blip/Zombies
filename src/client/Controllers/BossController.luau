-- BossController: the client side of the final boss (vault: Waves and Boss.md).
--   intro      Effect "BossIntro" (MatchService:_bossIntro): letterboxed camera shots while the boss
--              claws out of the ground at the BossSpawn marker, a close-up roar with shake, FOV punch,
--              red flash and title card, then a fade back to first person. CameraController stands down
--              while the player has the BossIntro attribute.
--   music      tense drums under the intro; the boss track fades in when the intro ends and fades out
--              when the boss dies or the run ends (GameState BossName)
--   attacks    roar on "BossCharge" / "BossLeap"; "BossKnock" shoves your character (you own its physics)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
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

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function fade(sound, volume, seconds)
	TweenService:Create(sound, TweenInfo.new(seconds), { Volume = volume }):Play()
end

local function overlay()
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
	o.Title = UIKit.Label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.86), Size = UDim2.fromOffset(900, 70), Text = string.upper(Zombies.Types[Zombies.BossOrder[1]].DisplayName), TextSize = 60, TextColor3 = Color3.fromRGB(255, 70, 50), TextTransparency = 1, ZIndex = 2, Parent = text })
	o.Sub = UIKit.Label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.945), Size = UDim2.fromOffset(700, 30), Text = "FINAL WAVE  ·  BRING IT DOWN", TextSize = 24, TextTransparency = 1, ZIndex = 2, Parent = text })
	return o
end

function BossController:PlayIntro(data)
	local camera = workspace.CurrentCamera
	local Sound = Controllers.SoundController
	local ui = overlay()
	local hidden = {} -- every other screen (HUD, radio, crosshair) is off for the shot
	for _, gui in player:WaitForChild("PlayerGui"):GetChildren() do
		if gui:IsA("ScreenGui") and gui.Enabled and gui ~= ui.Gui then
			hidden[gui] = true
			gui.Enabled = false
		end
	end
	local drums = Sound:Loop("BossIntroDrums")
	drums.Volume = 0
	drums:Play()
	fade(drums, Sounds.Library.BossIntroDrums.Volume, 1)

	local P = data.Position
	local C = GameConfig.OurMap.ArenaCenter
	local dir = Vector3.new(P.X - C.X, 0, P.Z - C.Z).Unit -- square -> boss
	local side = dir:Cross(Vector3.yAxis)
	local up = Vector3.yAxis
	local H = 5.5 * (Zombies.Types[Zombies.BossOrder[1]].Scale or 1) -- boss height
	local start = os.clock()
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
			camera.FieldOfView = GameConfig.Camera.FieldOfView
			-- level look at the boss from the head: the default camera resumes from the last CFrame,
			-- which was pitched up at the boss's chest
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local head = root.Position + Vector3.new(0, 1.5, 0)
				camera.CFrame = CFrame.lookAt(head, Vector3.new(P.X, head.Y, P.Z))
			end
			camera.CameraType = Enum.CameraType.Custom
			for gui in hidden do
				gui.Enabled = true
			end
			fade(drums, 0, 1.2)
			task.delay(1.3, drums.Destroy, drums)
			TweenService:Create(ui.Fade, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
			task.delay(0.6, ui.Gui.Destroy, ui.Gui)
		end
	end)
end

function BossController:Init(controllers)
	Controllers = controllers
	Remotes.Effect.OnClientEvent:Connect(function(kind, data)
		if type(data) ~= "table" then
			return
		end
		if kind == "BossIntro" then
			task.spawn(self.PlayIntro, self, data)
		elseif kind == "BossCharge" or kind == "BossLeap" then
			Controllers.SoundController:PlayAt("BossRoar", data.Position, { Pitch = if kind == "BossLeap" then 1.15 else 1 })
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
	end)
end

return BossController
