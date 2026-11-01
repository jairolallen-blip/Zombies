-- CameraController: run camera + the single source of truth for AIMING.
-- The mouse is free (never locked to the centre). Aim = a ray from the camera through the mouse
-- cursor; the character turns to face the aim point. Rotate the camera with right-click drag
-- (Roblox default). In the lobby the default camera + normal cursor return.
-- Tunables: GameConfig.Camera.
--
-- Public (used by WeaponController, InputController, HUDController):
--   CameraController:IsActive()
--   CameraController:GetMouseLocation() -> Vector2 (viewport pixels; matches IgnoreGuiInset GUIs)
--   CameraController:GetAimRay() -> Ray through the cursor
--   CameraController:GetAimPoint() -> Vector3 world point under the cursor

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.GameConfig)

local player = Players.LocalPlayer
local CameraController = {}
local active = false
local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude

function CameraController:IsActive()
	return active
end

function CameraController:GetMouseLocation()
	return UserInputService:GetMouseLocation()
end

function CameraController:GetAimRay()
	local mouse = UserInputService:GetMouseLocation()
	return workspace.CurrentCamera:ViewportPointToRay(mouse.X, mouse.Y)
end

function CameraController:GetAimPoint()
	local ray = self:GetAimRay()
	aimParams.FilterDescendantsInstances = { player.Character, workspace:FindFirstChild("Effects"), workspace:FindFirstChild("ClientEffects") }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 600, aimParams)
	return if result then result.Position else ray.Origin + ray.Direction * 300
end

local function getHumanoid()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid"), character and character:FindFirstChild("HumanoidRootPart")
end

local function enter(humanoid)
	active = true
	player.CameraMinZoomDistance = GameConfig.Camera.MinZoom
	player.CameraMaxZoomDistance = GameConfig.Camera.MaxZoom
	humanoid.AutoRotate = false
	humanoid.CameraOffset = GameConfig.Camera.ShoulderOffset
	UserInputService.MouseIconEnabled = false -- HUD draws a crosshair at the cursor instead
end

local function exit(humanoid)
	active = false
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 30
	if humanoid then
		humanoid.AutoRotate = true
		humanoid.CameraOffset = Vector3.zero
	end
	UserInputService.MouseIconEnabled = true
end

function CameraController:Init()
	RunService:BindToRenderStep("SAMZ_Camera", Enum.RenderPriority.Camera.Value + 1, function()
		local humanoid, root = getHumanoid()
		-- CutsceneController owns the camera while Deploying (helicopter + parachute)
		local shouldBeActive = player:GetAttribute("InRun") == true and player:GetAttribute("Deploying") ~= true and humanoid ~= nil and root ~= nil and humanoid.Health > 0
		if shouldBeActive and not active then
			enter(humanoid)
		elseif not shouldBeActive and active then
			exit(humanoid)
		end
		if active then
			humanoid.AutoRotate = false
			-- face the point under the cursor
			local aim = self:GetAimPoint()
			local flat = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
			if flat.Magnitude > 1 then
				root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
			end
		end
	end)
end

return CameraController
