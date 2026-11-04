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
local T = UIKit.Theme

local player = Players.LocalPlayer
local AirdropController = {}
local ui = {}

function AirdropController:Init()
	local gui = UIKit.Screen("Airdrop")
	local root = UIKit.new("Frame", { BackgroundTransparency = 1, Parent = gui })
	UIKit.AutoScale(root)
	ui.Chip = UIKit.Panel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 92), Size = UDim2.fromOffset(340, 56), Visible = false, Parent = root })
	ui.Stroke = UIKit.Stroke(Color3.new(1, 1, 1), 1.5)
	ui.Stroke.Parent = ui.Chip
	-- two-line chip: name + countdown / effect — one line at 17pt was ~450px in a 300px box (clipped)
	ui.Name = UIKit.Label({ Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -70, 0, 22), TextSize = 20, Font = T.FontTitle, TextXAlignment = Enum.TextXAlignment.Left, Parent = ui.Chip })
	ui.Time = UIKit.Label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 6), Size = UDim2.fromOffset(56, 22), TextSize = 20, Font = T.FontTitle, TextXAlignment = Enum.TextXAlignment.Right, Parent = ui.Chip })
	ui.Desc = UIKit.Label({ Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -28, 0, 20), TextSize = 15, TextColor3 = T.N300, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = ui.Chip })
end

function AirdropController:Start()
	RunService.RenderStepped:Connect(function()
		local reward = Airdrops.ById[player:GetAttribute("Buff") or ""]
		local left = (player:GetAttribute("BuffUntil") or 0) - workspace:GetServerTimeNow()
		ui.Chip.Visible = reward ~= nil and left > 0
		if ui.Chip.Visible then
			ui.Name.Text = reward.Name
			ui.Name.TextColor3 = reward.Color
			ui.Time.Text = math.ceil(left) .. "s"
			ui.Time.TextColor3 = reward.Color
			ui.Desc.Text = reward.Desc
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
