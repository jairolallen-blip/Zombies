-- TouchController: run controls for phones and gamepads (keyboard + mouse live in WeaponController and
-- InputController). Phones get on-screen buttons on the right while the run camera is on: FIRE (hold),
-- AIM (toggle), RELOAD, ABILITY (E) and ULTIMATE (F); drag anywhere else to look, the left stick moves.
-- The HUD's upgrade buttons are tappable already, and ProximityPrompts (supply crates) are tappable.
-- Gamepad: R2 fire, L2 aim, X reload, L1 ability, R1 ultimate, D-pad up gun upgrade, D-pad right
-- Vitality, Y opens a supply crate (its prompt).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local player = Players.LocalPlayer
local TouchController = {}
local Controllers

local function setAim(on) -- aim-down-sights exists only in WeaponController builds that have SetAim
	if Controllers.WeaponController.SetAim then
		Controllers.WeaponController:SetAim(on)
	end
end

local function ability(slot)
	Remotes.UseAbility:FireServer(slot, Controllers.InputController:GetAimPoint())
end

local PAD = {
	[Enum.KeyCode.ButtonL1] = function()
		ability("Ability")
	end,
	[Enum.KeyCode.ButtonR1] = function()
		ability("Ultimate")
	end,
	[Enum.KeyCode.DPadUp] = function()
		Remotes.BuyUpgrade:FireServer("Weapon")
	end,
	[Enum.KeyCode.DPadRight] = function()
		Remotes.BuyUpgrade:FireServer("Vitality")
	end,
	[Enum.KeyCode.ButtonX] = function()
		Controllers.WeaponController:Reload()
	end,
}

local function bindGamepad()
	UserInputService.InputBegan:Connect(function(input)
		if not player:GetAttribute("InRun") then
			return
		end
		if input.KeyCode == Enum.KeyCode.ButtonR2 then
			Controllers.WeaponController:SetTrigger(true)
		elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
			setAim(true)
		elseif PAD[input.KeyCode] then
			PAD[input.KeyCode]()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.ButtonR2 then
			Controllers.WeaponController:SetTrigger(false)
		elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
			setAim(false)
		end
	end)
end

-- a round button: onDown(true) when pressed, onDown(false) when let go (touch can slide off it)
local function roundButton(parent, name, text, size, position, color, onDown)
	local b = Instance.new("TextButton")
	b.Name = name
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = position
	b.Size = UDim2.fromOffset(size, size)
	b.BackgroundColor3 = color
	b.BackgroundTransparency = 0.35
	b.AutoButtonColor = false
	b.Font = Enum.Font.GothamBlack
	b.TextSize = math.floor(size * 0.22)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.Parent = parent
	UIKit.Corner(size).Parent = b
	UIKit.Stroke(Color3.new(1, 1, 1), 2).Parent = b
	local touches = {}
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			touches[input] = true
			b.BackgroundTransparency = 0.1
			onDown(true)
		end
	end)
	local function up(input)
		if touches[input] then
			touches[input] = nil
			b.BackgroundTransparency = 0.35
			onDown(false)
		end
	end
	b.InputEnded:Connect(up)
	UserInputService.InputEnded:Connect(up) -- a finger released after sliding off the button
	return b
end

local function buildTouch()
	local gui = UIKit.Screen("TouchControls")
	gui.Enabled = false
	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = gui
	UIKit.AutoScale(root)
	-- the cluster sits in the upper right: on a small landscape phone (UI scale 0.6) it ends above the HUD upgrade
	-- buttons (y ~ H - 152) and Roblox's jump button, and below the toasts
	local red, dark, gold = Color3.fromRGB(200, 60, 50), Color3.fromRGB(30, 34, 42), Color3.fromRGB(200, 150, 40)
	local aiming = false
	roundButton(root, "Fire", "FIRE", 110, UDim2.new(1, -110, 0.46, 0), red, function(down)
		Controllers.WeaponController:SetTrigger(down)
	end)
	local aim
	aim = roundButton(root, "Aim", "AIM", 70, UDim2.new(1, -215, 0.5, 0), dark, function(down)
		if down then
			aiming = not aiming
			setAim(aiming)
			aim.BackgroundColor3 = if aiming then Color3.fromRGB(70, 140, 220) else dark
		end
	end)
	roundButton(root, "Reload", "R", 60, UDim2.new(1, -195, 0.33, 0), dark, function(down)
		if down then
			Controllers.WeaponController:Reload()
		end
	end)
	roundButton(root, "Ability", "E", 66, UDim2.new(1, -130, 0.24, 0), Color3.fromRGB(60, 120, 200), function(down)
		if down then
			ability("Ability")
		end
	end)
	roundButton(root, "Ultimate", "F", 66, UDim2.new(1, -50, 0.28, 0), gold, function(down)
		if down then
			ability("Ultimate")
		end
	end)
	RunService.RenderStepped:Connect(function()
		local on = Controllers.CameraController:IsActive()
		if gui.Enabled and not on then
			Controllers.WeaponController:SetTrigger(false)
			if aiming then
				aiming = false
				setAim(false)
				aim.BackgroundColor3 = dark
			end
		end
		gui.Enabled = on
	end)
end

function TouchController:Init(controllers)
	Controllers = controllers
	bindGamepad()
	if UserInputService.TouchEnabled then
		buildTouch()
	end
end

return TouchController
