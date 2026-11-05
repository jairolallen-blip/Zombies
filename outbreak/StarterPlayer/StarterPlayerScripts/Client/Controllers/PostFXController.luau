-- PostFXController: client-side "shaders" -- a moody, slightly more realistic, cinematic grade
-- layered on top of the server's base sunset (MapService:ApplyAtmosphere). Darker exposure, warm
-- deep shadows, thicker dusty haze, more contrast, a little less saturation, extra bloom, autofocus
-- depth of field (focus follows the crosshair; stronger while aiming down sights) and a screen
-- vignette. Everything is local to this client (Lighting changes made by a client don't replicate).
--
-- OFF while Deploying: the base lighting is restored exactly, so the deploy cutscene looks as designed.
-- Tuning: GameConfig.PostFX (Enabled = false turns the whole thing off).
--
-- Public: PostFXController:IsActive()

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.GameConfig)

local player = Players.LocalPlayer
local PostFXController = {}
local Controllers

local FX = GameConfig.PostFX
local ATMOSPHERE_KEYS = { "Density", "Haze", "Glare", "Offset", "Color", "Decay" }

local active = false
local baseLighting = nil -- snapshot of the Lighting properties we override
local graded = {} -- [Atmosphere] = snapshot of its properties before we changed them
local effects = {} -- our own post effects (client-only instances under Lighting)
local vignette = nil
local focusParams = RaycastParams.new()
focusParams.FilterType = Enum.RaycastFilterType.Exclude

function PostFXController:IsActive()
	return active
end

local function newEffect(className, name, props)
	local e = Instance.new(className)
	e.Name = name
	for k, v in props do
		e[k] = v
	end
	e.Enabled = false
	e.Parent = Lighting
	return e
end

local function buildVignette()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SAMZ_Vignette"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -5 -- under the HUD
	gui.Enabled = false
	-- four edge gradients; the corners overlap and come out darkest, like a lens
	for _, edge in {
		{ "Top", UDim2.fromScale(1, 0.32), UDim2.fromScale(0, 0), 90 },
		{ "Bottom", UDim2.fromScale(1, 0.32), UDim2.fromScale(0, 0.68), -90 },
		{ "Left", UDim2.fromScale(0.22, 1), UDim2.fromScale(0, 0), 0 },
		{ "Right", UDim2.fromScale(0.22, 1), UDim2.fromScale(0.78, 0), 180 },
	} do
		local frame = Instance.new("Frame")
		frame.Name = edge[1]
		frame.Size = edge[2]
		frame.Position = edge[3]
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BorderSizePixel = 0
		frame.Parent = gui
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = edge[4]
		gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - FX.Vignette), NumberSequenceKeypoint.new(1, 1) })
		gradient.Parent = frame
	end
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

local function gradeAtmosphere(atmosphere)
	if graded[atmosphere] then
		return
	end
	local snapshot = {}
	for _, k in ATMOSPHERE_KEYS do
		snapshot[k] = atmosphere[k]
		atmosphere[k] = FX.Atmosphere[k]
	end
	graded[atmosphere] = snapshot
end

local function apply()
	baseLighting = {}
	for k, v in FX.Lighting do
		baseLighting[k] = Lighting[k]
		Lighting[k] = v
	end
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") then
			gradeAtmosphere(child)
		end
	end
	for _, e in effects do
		e.Enabled = true
	end
	vignette.Enabled = FX.Vignette > 0
end

local function restore()
	if baseLighting then
		for k, v in baseLighting do
			Lighting[k] = v
		end
		baseLighting = nil
	end
	for atmosphere, snapshot in graded do
		if atmosphere.Parent then
			for k, v in snapshot do
				atmosphere[k] = v
			end
		end
	end
	table.clear(graded)
	for _, e in effects do
		e.Enabled = false
	end
	vignette.Enabled = false
end

-- Depth of field focuses on what the crosshair is on (smoothly), so near zombies stay sharp and the
-- far city softens; while aiming, the background blurs a bit more.
local focus = 40
local function autofocus(dt)
	local dof = effects.DepthOfField
	local camera = workspace.CurrentCamera
	local filter = { camera }
	for _, inst in { player.Character, workspace:FindFirstChild("Effects"), workspace:FindFirstChild("ClientEffects") } do
		table.insert(filter, inst)
	end
	focusParams.FilterDescendantsInstances = filter
	local ray = Controllers.CameraController:GetAimRay()
	local hit = workspace:Raycast(ray.Origin, ray.Direction.Unit * FX.DepthOfField.MaxFocus, focusParams)
	local target = if hit then hit.Distance else FX.DepthOfField.MaxFocus
	focus += (target - focus) * math.min(1, dt * 6)
	local aim = Controllers.ViewmodelController:GetAim()
	dof.FocusDistance = focus
	-- wide in-focus band (and at least 40 studs) so distant zombies stay readable
	dof.InFocusRadius = math.clamp(focus * 1.5, 40, 200)
	dof.FarIntensity = FX.DepthOfField.FarIntensity + (FX.DepthOfField.AimFarIntensity - FX.DepthOfField.FarIntensity) * aim
end

function PostFXController:Init(controllers)
	Controllers = controllers
	if not FX or not FX.Enabled then
		return
	end
	effects.Grade = newEffect("ColorCorrectionEffect", "SAMZ_PostGrade", FX.Grade)
	effects.Bloom = newEffect("BloomEffect", "SAMZ_PostBloom", FX.Bloom)
	effects.DepthOfField = newEffect("DepthOfFieldEffect", "SAMZ_PostDOF", { FarIntensity = FX.DepthOfField.FarIntensity, NearIntensity = 0, FocusDistance = 40, InFocusRadius = 40 })
	vignette = buildVignette()
	-- the server may (re)build its Atmosphere after we start: grade new ones while active
	Lighting.ChildAdded:Connect(function(child)
		if active and child:IsA("Atmosphere") then
			gradeAtmosphere(child)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local want = player:GetAttribute("Deploying") ~= true and (require(game.ReplicatedStorage.Shared.GameState):GetAttribute("Condition") or "Sunset") == "Sunset" -- a run's other weather (Config/Conditions) keeps its own look -- the deploy cutscene keeps its own look
		if want and not active then
			active = true
			apply()
		elseif not want and active then
			active = false
			restore()
		end
		if active then
			autofocus(math.min(dt, 0.1))
		end
	end)
end

return PostFXController
