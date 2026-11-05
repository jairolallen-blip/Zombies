-- SurvivorController: the safehouse people talk (Server/Map/Survivors places them; lines in
-- Shared/Config/Survivors). Pressing a "Talk" prompt (attribute Survivor = Id) shows their next line in
-- a speech bubble over their head, typed out, for a few seconds. Each person goes through their lines
-- in order, starting from a random one. Client-only: nobody else sees your conversation.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Survivors = require(ReplicatedStorage:WaitForChild("Shared").Config.Survivors)

local player = Players.LocalPlayer
local SurvivorController = {}

local byId = {}
local nextLine = {} -- [Id] = index of the line they say next
local talking = {} -- [Id] = token of the bubble showing (a newer one replaces it)

local function bubble(head, text, id)
	local token = {}
	talking[id] = token
	local old = head:FindFirstChild("Speech")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Speech"
	-- sized in studs (not pixels), so it always takes the same space: Server/Map/Survivors keeps that space
	-- (about 9 x 3.2 studs, 3-6 studs over the head) clear of roofs and signs
	gui.Size = UDim2.fromScale(9, 3.2)
	gui.StudsOffset = Vector3.new(0, 4.6, 0)
	gui.MaxDistance = 45
	gui.Parent = head
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.fromScale(0.5, 1)
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	panel.BackgroundTransparency = 0.15
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	local pad = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		pad[side] = UDim.new(0, 8)
	end
	pad.Parent = panel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.Text = text
	label.MaxVisibleGraphemes = 0
	label.Parent = panel
	local length = utf8.len(text) or #text
	for shown = 1, length, 2 do
		if talking[id] ~= token then
			return
		end
		label.MaxVisibleGraphemes = shown
		task.wait(0.03)
	end
	label.MaxVisibleGraphemes = -1
	task.wait(3 + length * 0.04)
	if talking[id] == token then
		gui:Destroy()
	end
end

function SurvivorController:Init()
	for _, def in Survivors.List do
		byId[def.Id] = def
		nextLine[def.Id] = math.random(1, #def.Lines)
	end
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		local id = prompt:GetAttribute("Survivor")
		local def = id and byId[id]
		if not def or who ~= player then
			return
		end
		local i = nextLine[id]
		nextLine[id] = i % #def.Lines + 1
		task.spawn(bubble, prompt.Parent, def.Lines[i], id)
	end)
end

return SurvivorController
