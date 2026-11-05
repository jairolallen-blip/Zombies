-- SkipController: "hold to skip" for the deploy ride and the boss intro (Server/Services/MatchService
-- :_skippableWait). Shown while GameState SkipOpen is set and you have CanSkip (you've finished a run
-- before). Hold Space, gamepad X, or press and hold the button (touch / mouse) to vote; the cutscene ends
-- once the whole squad has voted (GameState SkipVotes = "votes/players").

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameState = require(Shared.GameState)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local player = Players.LocalPlayer
local SkipController = {}

local HOLD = 0.6 -- seconds to hold

function SkipController:Init()
	local gui = UIKit.Screen("Skip")
	gui.DisplayOrder = 50 -- over the cutscene letterbox
	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = gui
	UIKit.AutoScale(root)
	local button = Instance.new("TextButton")
	button.Name = "SkipButton"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -24, 1, -24)
	button.Size = UDim2.fromOffset(230, 44)
	button.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	button.BackgroundTransparency = 0.25
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBold
	button.TextSize = 18
	button.TextColor3 = Color3.fromRGB(240, 240, 240)
	button.Parent = root
	UIKit.Corner(10).Parent = button
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(0, 1)
	bar.BackgroundColor3 = Color3.fromRGB(150, 255, 90)
	bar.BackgroundTransparency = 0.6
	bar.BorderSizePixel = 0
	bar.ZIndex = 0
	bar.Parent = button
	UIKit.Corner(10).Parent = bar

	local holding, held, voted = false, 0, false
	local function setHolding(on)
		holding = on
	end
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setHolding(true)
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setHolding(false)
		end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonX then
			setHolding(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonX then
			setHolding(false)
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local open = GameState:GetAttribute("SkipOpen") ~= nil and player:GetAttribute("CanSkip") == true
		gui.Enabled = open
		if not open then
			holding, held, voted = false, 0, false
			return
		end
		if voted then
			button.Text = "WAITING FOR SQUAD  " .. (GameState:GetAttribute("SkipVotes") or "")
			bar.Size = UDim2.fromScale(1, 1)
			return
		end
		held = if holding then held + dt else 0
		bar.Size = UDim2.fromScale(math.clamp(held / HOLD, 0, 1), 1)
		local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		button.Text = if touch then "HOLD TO SKIP" else "HOLD SPACE TO SKIP"
		if held >= HOLD then
			voted = true
			Remotes.SkipCutscene:FireServer()
		end
	end)
end

return SkipController
