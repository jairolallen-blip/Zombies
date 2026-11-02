-- TutorialController: the objective card during a first-time player's training run (left side,
-- below the radio panel). Server/Services/TutorialService sets the player attributes it reads:
--   TutorialObjective (text, "" = hidden), TutorialObjectiveDone (turns it green with a tick),
--   TutorialStep / TutorialSteps (the "TRAINING 3 / 8" counter). Steps are in Shared/Config/Tutorial.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UIKit = require(script.Parent.Parent.UI.UIKit)

local T = UIKit.Theme
local player = Players.LocalPlayer

local TutorialController = {}
local ui = {}

function TutorialController:Refresh()
	local text = player:GetAttribute("TutorialObjective") or ""
	local done = player:GetAttribute("TutorialObjectiveDone") == true
	ui.Card.Visible = text ~= ""
	ui.Counter.Text = string.format("TRAINING  %d / %d", player:GetAttribute("TutorialStep") or 0, player:GetAttribute("TutorialSteps") or 0)
	ui.Text.Text = if done then "✓  " .. text else text
	ui.Text.TextColor3 = if done then T.Cash else T.Text
end

function TutorialController:Init()
	local gui = UIKit.Screen("Tutorial")
	local root = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	UIKit.AutoScale(root)
	ui.Card = UIKit.Panel({ Name = "Objective", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.56, 0), Size = UDim2.fromOffset(330, 96), Visible = false, Parent = root })
	UIKit.Padding(12).Parent = ui.Card
	UIKit.new("Frame", { Size = UDim2.new(0, 4, 1, 0), Position = UDim2.fromOffset(-12, 0), BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = ui.Card })
	ui.Counter = UIKit.Label({ Size = UDim2.new(1, 0, 0, 20), TextSize = 16, TextColor3 = T.Accent, TextXAlignment = Enum.TextXAlignment.Left, Parent = ui.Card })
	ui.Text = UIKit.Label({ Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 1, -24), TextSize = 20, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = ui.Card })
	ui.Scale = UIKit.new("UIScale", { Parent = ui.Card })
	for _, attr in { "TutorialObjective", "TutorialObjectiveDone", "TutorialStep", "TutorialSteps" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			self:Refresh()
		end)
	end
	-- a small pop each time a new objective arrives
	player:GetAttributeChangedSignal("TutorialObjective"):Connect(function()
		ui.Scale.Scale = 1.12
		TweenService:Create(ui.Scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)
	self:Refresh()
end

return TutorialController
