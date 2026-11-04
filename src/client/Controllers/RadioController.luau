-- RadioController: the commander's radio panel on the left side of the screen (vault: Match Start.md).
-- Remotes.Radio(text) lines are queued; each slides in next to a 3D portrait (ViewportFrame) whose
-- mouth moves while the text types out, holds, then slides away. Shown during a run, and in the lobby
-- while a radio-shack broadcast is up.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Radio = require(Shared.Config.Radio)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local T = UIKit.Theme
local player = Players.LocalPlayer
local RadioController = {}
local ui = {}
local queue = {}

local SHOWN = UDim2.new(0, 20, 0.36, 0)
local HIDDEN = UDim2.new(0, -450, 0.36, 0)
local CHARS_PER_SECOND = 45

-- Blocky soldier bust facing -Z. Returns the mouth part so it can be animated.
local function buildPortrait(viewport)
	local model = Instance.new("Model")
	local function piece(size, position, color, material, shape)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = CFrame.new(position)
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		p.Parent = model
		return p
	end
	local skin = Color3.fromRGB(190, 142, 108)
	local olive = Color3.fromRGB(78, 88, 56)
	piece(Vector3.new(4.4, 2.6, 2.2), Vector3.new(0, -2.4, 0.2), olive, Enum.Material.Fabric) -- shoulders
	piece(Vector3.new(1.2, 0.6, 1.2), Vector3.new(0, -1.15, 0), skin) -- neck
	piece(Vector3.new(2, 2, 2), Vector3.new(0, 0, 0), skin) -- head
	piece(Vector3.new(2.4, 1, 2.4), Vector3.new(0, 1.15, 0.05), olive:Lerp(Color3.new(), 0.2), Enum.Material.Fabric) -- helmet
	piece(Vector3.new(2.6, 0.22, 2.8), Vector3.new(0, 0.68, -0.05), olive:Lerp(Color3.new(), 0.3), Enum.Material.Fabric) -- brim
	piece(Vector3.new(2.12, 0.42, 2.12), Vector3.new(0, 0.95, 0), Color3.fromRGB(25, 25, 25)) -- goggle strap
	for _, x in { -0.45, 0.45 } do
		piece(Vector3.new(0.6, 0.4, 0.12), Vector3.new(x, 0.95, -1.1), Color3.fromRGB(255, 150, 60), Enum.Material.Neon) -- goggles
		piece(Vector3.new(0.28, 0.26, 0.06), Vector3.new(x, 0.12, -1.02), Color3.fromRGB(30, 26, 24)) -- eyes
		piece(Vector3.new(0.5, 0.1, 0.06), Vector3.new(x, 0.38, -1.02), Color3.fromRGB(70, 50, 36)) -- brows
	end
	piece(Vector3.new(1.5, 0.5, 0.08), Vector3.new(0, -0.62, -1.0), skin:Lerp(Color3.fromRGB(60, 50, 40), 0.35)) -- stubble
	local mouth = piece(Vector3.new(0.7, 0.12, 0.06), Vector3.new(0, -0.55, -1.05), Color3.fromRGB(40, 20, 18))
	piece(Vector3.new(0.25, 0.9, 0.9), Vector3.new(1.1, 0, -0.1), Color3.fromRGB(30, 30, 30)) -- headset ear cup
	piece(Vector3.new(0.08, 0.08, 1.1), Vector3.new(1.0, -0.45, -0.6), Color3.fromRGB(30, 30, 30)) -- mic arm
	piece(Vector3.new(0.22, 0.22, 0.22), Vector3.new(0.85, -0.5, -1.15), Color3.fromRGB(30, 30, 30), nil, Enum.PartType.Ball) -- mic
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 34
	camera.CFrame = CFrame.lookAt(Vector3.new(1.7, 0.2, -5.4), Vector3.new(0, -0.35, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return mouth
end

function RadioController:Init()
	local gui = UIKit.Screen("Radio")
	gui.DisplayOrder = 5
	ui.Gui = gui
	local root = UIKit.new("Frame", { BackgroundTransparency = 1, Parent = gui })
	UIKit.AutoScale(root)
	ui.Panel = UIKit.Panel({ AnchorPoint = Vector2.new(0, 0.5), Position = HIDDEN, Size = UDim2.fromOffset(420, 100), BackgroundTransparency = 0.08, Parent = root }) -- near-solid: dialogue over busy walls
	UIKit.Stroke(T.N600, 1.5).Parent = ui.Panel
	local viewport = UIKit.new("ViewportFrame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(80, 80),
		BackgroundColor3 = Color3.fromRGB(44, 52, 40),
		Ambient = Color3.fromRGB(150, 140, 125),
		LightColor = Color3.fromRGB(255, 225, 190),
		LightDirection = Vector3.new(-0.6, -0.5, 1),
		Parent = ui.Panel,
	})
	UIKit.Corner(8).Parent = viewport
	ui.Mouth = buildPortrait(viewport)
	UIKit.Label({ Text = Radio.Speaker.Name .. "  ·  " .. Radio.Speaker.Callsign, Position = UDim2.fromOffset(100, 8), Size = UDim2.new(1, -180, 0, 22), TextSize = 15, TextColor3 = T.N400, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = ui.Panel })
	ui.Live = UIKit.Label({ Text = "● LIVE", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(70, 22), TextSize = 15, TextColor3 = T.Danger, TextXAlignment = Enum.TextXAlignment.Right, Parent = ui.Panel })
	ui.Text = UIKit.Label({
		Position = UDim2.fromOffset(100, 32),
		Size = UDim2.new(1, -112, 0, 62),
		TextSize = 18,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = ui.Panel,
	})
	Remotes.Radio.OnClientEvent:Connect(function(text)
		table.insert(queue, text)
	end)
end

function RadioController:_say(text)
	local panel, label, mouth = ui.Panel, ui.Text, ui.Mouth
	label.Text = text
	label.MaxVisibleGraphemes = 0
	if panel.Position ~= SHOWN then
		TweenService:Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = SHOWN }):Play()
		task.wait(0.25)
	end
	local length = utf8.len(text) or #text
	local started = os.clock()
	while true do
		local shown = math.floor((os.clock() - started) * CHARS_PER_SECOND)
		label.MaxVisibleGraphemes = math.min(shown, length)
		mouth.Size = Vector3.new(0.7, if shown % 6 < 3 then 0.32 else 0.12, 0.06)
		if shown >= length then
			break
		end
		task.wait()
	end
	label.MaxVisibleGraphemes = -1
	mouth.Size = Vector3.new(0.7, 0.12, 0.06)
	task.wait(2.2 + length * 0.025)
	if #queue == 0 then
		TweenService:Create(panel, TweenInfo.new(0.3), { Position = HIDDEN }):Play()
	end
end

function RadioController:Start()
	task.spawn(function()
		while true do
			ui.Live.TextTransparency = if ui.Live.TextTransparency == 0 then 0.7 else 0
			-- off during the boss intro (BossController hides every screen, but this loop would switch it
			-- back on); it stays on during the drop-in, where it carries the Deploy/Drop briefing. In the
			-- lobby it shows only while a line is up (the radio shack's broadcasts: CommonsService)
			local busy = ui.Panel.Position ~= HIDDEN or #queue > 0
			ui.Gui.Enabled = player:GetAttribute("BossIntro") ~= true and (player:GetAttribute("InRun") == true or busy)
			task.wait(0.5)
		end
	end)
	while true do
		if #queue > 0 then
			self:_say(table.remove(queue, 1))
		else
			task.wait(0.1)
		end
	end
end

return RadioController
