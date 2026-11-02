-- CameraController: FIRST-PERSON run camera + the single source of truth for AIMING.
-- In a run (not while the deploy cutscene owns the camera) the camera is locked to first person
-- with the mouse locked to the screen centre; aim = a ray through the centre of the screen.
-- Hold Left Alt to free the cursor (e.g. to click HUD buttons); aim then follows the cursor.
-- In the lobby the default third-person camera + normal cursor return.
-- The gun you see in first person is drawn by ViewmodelController (the real Tool is hidden locally).
-- Tunables: GameConfig.Camera.
--
-- Public (used by WeaponController, InputController, HUDController, ViewmodelController):
--   CameraController:IsActive()          true while the first-person run camera is on
--   CameraController:GetMouseLocation()  Vector2 (viewport pixels; screen centre while locked)
--   CameraController:GetAimRay()         Ray through the aim point on screen
--   CameraController:GetAimPoint()       Vector3 world point under the crosshair

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.GameConfig)

local player = Players.LocalPlayer
local CameraController = {}
local active = false
local freeCursor = false
local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude

function CameraController:IsActive()
	return active
end

function CameraController:GetMouseLocation()
	if active and not freeCursor then
		local size = workspace.CurrentCamera.ViewportSize
		return Vector2.new(size.X / 2, size.Y / 2)
	end
	return UserInputService:GetMouseLocation()
end

function CameraController:GetAimRay()
	local point = self:GetMouseLocation()
	return workspace.CurrentCamera:ViewportPointToRay(point.X, point.Y)
end

function CameraController:GetAimPoint()
	local ray = self:GetAimRay()
	aimParams.FilterDescendantsInstances = { player.Character, workspace.CurrentCamera, workspace:FindFirstChild("Effects"), workspace:FindFirstChild("ClientEffects") }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 600, aimParams)
	return if result then result.Position else ray.Origin + ray.Direction * 300
end

local function getHumanoid()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid"), character and character:FindFirstChild("HumanoidRootPart")
end

local function enter(humanoid)
	active = true
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 0.5
	humanoid.CameraOffset = Vector3.zero
	humanoid.AutoRotate = true -- first-person camera turns the character with the view
	workspace.CurrentCamera.FieldOfView = GameConfig.Camera.FieldOfView
	UserInputService.MouseIconEnabled = false -- HUD draws the crosshair
end

local function exit(humanoid)
	active = false
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = GameConfig.Camera.LobbyMaxZoom
	if humanoid then
		humanoid.AutoRotate = true
		humanoid.CameraOffset = Vector3.zero
	end
	workspace.CurrentCamera.FieldOfView = 70
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

function CameraController:Init()
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == GameConfig.Keybinds.FreeCursor then
			freeCursor = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == GameConfig.Keybinds.FreeCursor then
			freeCursor = false
		end
	end)
	RunService:BindToRenderStep("SAMZ_Camera", Enum.RenderPriority.Camera.Value + 1, function()
		local humanoid, root = getHumanoid()
		-- CutsceneController owns the camera while Deploying (helicopter + parachute)
		local shouldBeActive = player:GetAttribute("InRun") == true and player:GetAttribute("Deploying") ~= true and player:GetAttribute("BossIntro") ~= true and humanoid ~= nil and root ~= nil and humanoid.Health > 0
		if shouldBeActive and not active then
			enter(humanoid)
		elseif not shouldBeActive and active then
			exit(humanoid)
		end
		if active then
			-- runs after the camera module, so this wins for the frame
			UserInputService.MouseBehavior = if freeCursor then Enum.MouseBehavior.Default else Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = freeCursor
		end
	end)
end

return CameraController
