-- ConditionsController: the client side of a run's weather (Shared/Config/Conditions, GameState Condition).
--   Rain         streaks falling around the camera (a non-colliding emitter part that follows it)
--   Flashlights  a spotlight on every player's head, client-only, so nothing replicates
-- Everything clears when the Condition attribute does (MatchService resets it after a run).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameState = require(Shared.GameState)
local Conditions = require(Shared.Config.Conditions)

local ConditionsController = {}

local rain = nil -- the emitter part while it rains
local lights = {} -- [Character] = SpotLight

local function makeRain()
	local part = Instance.new("Part")
	part.Name = "Rain"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(90, 1, 90)
	local emitter = Instance.new("ParticleEmitter")
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Rate = 900
	emitter.Lifetime = NumberRange.new(0.9, 1.1)
	emitter.Speed = NumberRange.new(70, 80)
	emitter.Size = NumberSequence.new(0.09)
	emitter.Squash = NumberSequence.new(-3) -- long thin streaks
	emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	emitter.Color = ColorSequence.new(Color3.fromRGB(190, 205, 225))
	emitter.Transparency = NumberSequence.new(0.45)
	emitter.LightInfluence = 1
	emitter.Parent = part
	part.Parent = workspace:FindFirstChild("ClientEffects") or workspace
	return part
end

local function setLight(character, on)
	if on and not lights[character] then
		local head = character:FindFirstChild("Head")
		if head then
			local light = Instance.new("SpotLight")
			light.Name = "Flashlight"
			light.Face = Enum.NormalId.Front
			light.Angle = 55
			light.Range = 50
			light.Brightness = 3
			light.Shadows = true
			light.Parent = head
			lights[character] = light
		end
	elseif not on and lights[character] then
		lights[character]:Destroy()
		lights[character] = nil
	end
end

function ConditionsController:Start()
	RunService.RenderStepped:Connect(function()
		local condition = Conditions.ById[GameState:GetAttribute("Condition") or ""]
		local wantRain = condition ~= nil and condition.Rain == true
		if wantRain and not rain then
			rain = makeRain()
		elseif not wantRain and rain then
			rain:Destroy()
			rain = nil
		end
		if rain then
			rain.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position + Vector3.new(0, 40, 0))
		end
		local wantLights = condition ~= nil and condition.Flashlights == true
		for _, other in Players:GetPlayers() do
			local character = other.Character
			if character then
				setLight(character, wantLights and other:GetAttribute("InRun") == true)
			end
		end
		for character in lights do
			if not character.Parent then
				lights[character] = nil
			end
		end
	end)
end

return ConditionsController
