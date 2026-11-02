-- AirdropController: client side of supply drops (Server/Services/AirdropService).
--   buff chip   top centre, under the wave counter: the active buff's name, effect and seconds left
--               (player attributes Buff + BuffUntil)
--   marker      the crate's "SUPPLY DROP" tag also shows how far away it is

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Airdrops = require(Shared.Config.Airdrops)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local player = Players.LocalPlayer
local AirdropController = {}
local ui = {}

function AirdropController:Init()
	local gui = UIKit.Screen("Airdrop")
	ui.Chip = UIKit.Panel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 92), Size = UDim2.fromOffset(300, 34), Visible = false, Parent = gui })
	ui.Stroke = UIKit.Stroke(Color3.new(1, 1, 1), 2)
	ui.Stroke.Parent = ui.Chip
	ui.Text = UIKit.Label({ Size = UDim2.fromScale(1, 1), TextSize = 17, Parent = ui.Chip })
end

function AirdropController:Start()
	RunService.RenderStepped:Connect(function()
		local reward = Airdrops.ById[player:GetAttribute("Buff") or ""]
		local left = (player:GetAttribute("BuffUntil") or 0) - workspace:GetServerTimeNow()
		ui.Chip.Visible = reward ~= nil and left > 0
		if ui.Chip.Visible then
			ui.Text.Text = string.format("%s  ·  %s  ·  %ds", reward.Name, reward.Desc, math.ceil(left))
			ui.Text.TextColor3 = reward.Color
			ui.Stroke.Color = reward.Color
		end

		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local effects = workspace:FindFirstChild("Effects")
		local crate = effects and effects:FindFirstChild("SupplyDrop")
		local label = crate and crate.PrimaryPart and crate.PrimaryPart:FindFirstChild("Marker")
		if label and root then
			label.Text.Text = string.format("SUPPLY DROP  %dm", math.floor((crate.PrimaryPart.Position - root.Position).Magnitude / 3.57))
		end
	end)
end

return AirdropController
