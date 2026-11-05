-- InputController: keyboard actions other than shooting — abilities and in-run upgrades.
-- Keys come from GameConfig.Keybinds. (Shooting/reload input lives in WeaponController.)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer
local InputController = {}

local Controllers

-- World point under the mouse cursor (used to aim grenades/airstrikes).
function InputController:GetAimPoint()
	return Controllers.CameraController:GetAimPoint()
end

function InputController:Init(controllers)
	Controllers = controllers
	local binds = GameConfig.Keybinds
	local actions = {
		[binds.Ability] = function()
			Remotes.UseAbility:FireServer("Ability", self:GetAimPoint())
		end,
		[binds.Ultimate] = function()
			Remotes.UseAbility:FireServer("Ultimate", self:GetAimPoint())
		end,
		[binds.UpgradeWeapon] = function()
			Remotes.BuyUpgrade:FireServer("Weapon")
		end,
		[binds.UpgradeVitality] = function()
			Remotes.BuyUpgrade:FireServer("Vitality")
		end,
	}
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not player:GetAttribute("InRun") then
			return
		end
		local action = actions[input.KeyCode]
		if action then
			action()
		end
	end)
end

return InputController
