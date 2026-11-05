-- Survivors: places the safehouse's people (Shared/Config/Survivors) in the lobby as figures from
-- Shared/ClassFigures, each with a name tag and a "Talk" prompt (attribute Survivor = their Id;
-- Client/Controllers/SurvivorController shows what they say). Baked into Workspace.OurMap.Lobby.Survivors.
-- OurLobby.Build calls this last. Safe to re-run: it replaces the Survivors model.
--   local m = game.ServerScriptService.Server.Map.Survivors
--   local c = m:Clone(); c.Parent = m.Parent; require(c).Build(workspace.OurMap.Lobby); c:Destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local SurvivorsConfig = require(Shared.Config.Survivors)
local ClassFigures = require(Shared.ClassFigures)

local Survivors = {}

local GROUND_Y = 1

local function nameTag(head, def)
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromScale(5, 1.25) -- studs, like the speech bubble (SurvivorController)
	gui.StudsOffset = Vector3.new(0, 2.2, 0)
	gui.MaxDistance = 40
	gui.Parent = head
	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0.6, 0)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBlack
	name.TextScaled = true
	name.TextColor3 = Color3.fromRGB(150, 255, 90)
	name.TextStrokeTransparency = 0.4
	name.Text = def.Name
	name.Parent = gui
	local title = name:Clone()
	title.Position = UDim2.fromScale(0, 0.6)
	title.Size = UDim2.new(1, 0, 0.4, 0)
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(220, 220, 215)
	title.Text = def.Title
	title.Parent = gui
end

function Survivors.Build(lobby)
	local origin = GameConfig.OurMap.LobbyCenter
	local old = lobby:FindFirstChild("Survivors")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Model")
	folder.Name = "Survivors"
	for _, def in SurvivorsConfig.List do
		local figure = ClassFigures.Build(def.Class)
		figure.Name = def.Id
		local pos = Vector3.new(origin.X + def.Spot.X, GROUND_Y + 3, origin.Z + def.Spot.Y) -- pivot = torso, 3 up
		local face = Vector3.new(origin.X + def.Face.X, pos.Y, origin.Z + def.Face.Y)
		figure:PivotTo(CFrame.lookAt(pos, face))
		local head = figure:FindFirstChild("Head")
		nameTag(head, def)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Talk"
		prompt.ObjectText = def.Name
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt:SetAttribute("Survivor", def.Id)
		prompt.Parent = head
		figure.Parent = folder
	end
	folder.Parent = lobby
	return folder
end

return Survivors
