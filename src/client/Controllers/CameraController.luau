-- CameraController: FIRST-PERSON run camera + the single source of truth for AIMING.
-- In a run (not while the deploy cutscene owns the camera) the view is a SCRIPTABLE first-person
-- camera: we rotate it ourselves from the mouse delta, because Roblox's MouseDeltaSensitivity does
-- NOT affect the default camera scripts — owning the rotation is the only way to get a real ADS
-- sensitivity. The mouse is locked to the screen centre; aim = a ray through the centre.
-- Hold Left Alt to free the cursor (e.g. to click HUD buttons); look rotation pauses while held.
-- Phones look by dragging on open screen (TouchStarted not processed by a button/stick); gamepads
-- look with the right stick. Both feed the same delta as the mouse, so ADS sensitivity applies.
-- In the lobby the default third-person camera + normal cursor return.
-- The gun you see in first person is drawn by ViewmodelController (the real Tool is hidden locally).
-- Aiming down sights (ViewmodelController:GetAim) zooms the FOV and slows the look speed.
-- Tunables: GameConfig.Camera (LookSensitivity, AimSensitivity, FieldOfView).
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
local Controllers
local active = false
local freeCursor = false -- Left Alt held
local resultsCursor = false -- the results panel is open (LobbyController)
local lookYaw, lookPitch = 0, 0 -- radians; pitch is clamped
local MAX_PITCH = math.rad(80)
local RAD_PER_PIXEL = 0.0045 -- base look speed in radians per mouse pixel
local TOUCH_SCALE = 0.8 -- touch drags cover more pixels than mouse moves, so they turn a bit slower
local PAD_LOOK_SPEED = math.rad(220) -- right-stick look speed at full tilt, radians per second
local PAD_DEADZONE = 0.15
-- touch look: the finger that started on open screen (not on a button or the move stick) turns the view
local lookTouch = nil
local touchDelta = Vector2.zero
local padStick = Vector2.zero
local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude

function CameraController:IsActive()
	return active
end

function CameraController:GetMouseLocation()
	if active and not (freeCursor or resultsCursor) then
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

-- adopt the current camera orientation so taking over doesn't snap the view
local function syncFromCamera()
	local cam = workspace.CurrentCamera
	local look = cam.CFrame.LookVector
	lookPitch = math.asin(math.clamp(look.Y, -1, 1))
	lookYaw = math.atan2(-look.X, -look.Z)
end

local function setHidden(character, hidden)
	-- the default first-person camera hid the character; scriptable must do it itself
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			d.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

local function enter(humanoid)
	active = true
	resultsCursor = false
	syncFromCamera()
	workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable -- we own the rotation
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 0.5
	humanoid.AutoRotate = false -- the character turns with our yaw instead
	humanoid.CameraOffset = Vector3.zero
	if humanoid.Parent then setHidden(humanoid.Parent, true) end
	workspace.CurrentCamera.FieldOfView = GameConfig.Camera.FieldOfView
	UserInputService.MouseIconEnabled = false -- HUD draws the crosshair
end

local function exit(humanoid)
	active = false
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = GameConfig.Camera.LobbyMaxZoom
	if humanoid then
		humanoid.AutoRotate = true
		humanoid.CameraOffset = Vector3.zero
		if humanoid.Parent then setHidden(humanoid.Parent, false) end
	end
	workspace.CurrentCamera.FieldOfView = 70
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

function CameraController:Init(controllers)
	Controllers = controllers
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
	-- phones: the default camera used to turn on a drag; the scriptable run camera has to do it itself.
	-- Touches that land on a button or the thumbstick arrive as processed, so they never steer.
	UserInputService.TouchStarted:Connect(function(touch, processed)
		if not processed and lookTouch == nil then
			lookTouch = touch
		end
	end)
	UserInputService.TouchMoved:Connect(function(touch)
		if touch == lookTouch then
			touchDelta += Vector2.new(touch.Delta.X, touch.Delta.Y)
		end
	end)
	UserInputService.TouchEnded:Connect(function(touch)
		if touch == lookTouch then
			lookTouch = nil
		end
	end)
	-- gamepads: the right stick looks (the default camera did this before the run camera was scriptable)
	UserInputService.InputChanged:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			padStick = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			padStick = Vector2.zero
		end
	end)
	RunService:BindToRenderStep("SAMZ_Camera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local humanoid, root = getHumanoid()
		-- CutsceneController owns the camera while Deploying (helicopter + parachute)
		local shouldBeActive = player:GetAttribute("InRun") == true and player:GetAttribute("Deploying") ~= true and player:GetAttribute("BossIntro") ~= true and humanoid ~= nil and root ~= nil and humanoid.Health > 0
		if shouldBeActive and not active then
			enter(humanoid)
		elseif not shouldBeActive and active then
			exit(humanoid)
		end
		if active then
			-- the results panel (LobbyController) needs a clickable cursor even before the run camera exits
			local Lobby = Controllers.LobbyController
			resultsCursor = Lobby ~= nil and Lobby.IsResultsOpen ~= nil and Lobby:IsResultsOpen()
			local cursorFree = freeCursor or resultsCursor
			UserInputService.MouseBehavior = if cursorFree then Enum.MouseBehavior.Default else Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = cursorFree
			-- aim down sights: zoom + slower look
			local Viewmodel = Controllers.ViewmodelController
			local a = Viewmodel:GetAim()
			a = a * a * (3 - 2 * a)
			local cfg = GameConfig.Camera
			-- plus the per-shot FOV kick from recoil
			workspace.CurrentCamera.FieldOfView = cfg.FieldOfView + (Viewmodel:GetAimFieldOfView() - cfg.FieldOfView) * a + Controllers.WeaponController:GetFovPunch()
			-- look speed: LookSensitivity at the hip, blending down to AimSensitivity as ADS settles
			-- in (scoped weapons cut further). This is now the REAL sensitivity — see header.
			local lookMul = cfg.LookSensitivity * (1 + (cfg.AimSensitivity - 1) * a) * (if Viewmodel:IsScoped() then 0.6 else 1)
			if not cursorFree then
				local delta = UserInputService:GetMouseDelta() + touchDelta * TOUCH_SCALE
				touchDelta = Vector2.zero
				if padStick.Magnitude > PAD_DEADZONE then
					-- stick tilt -> pixels this frame, so it shares the sensitivity maths below (stick up = look up)
					local tilt = padStick * ((padStick.Magnitude - PAD_DEADZONE) / (1 - PAD_DEADZONE) / padStick.Magnitude)
					delta += Vector2.new(tilt.X, -tilt.Y) * PAD_LOOK_SPEED * dt / RAD_PER_PIXEL
				end
				if delta.X ~= 0 or delta.Y ~= 0 then
					lookYaw = lookYaw - delta.X * RAD_PER_PIXEL * lookMul
					lookPitch = math.clamp(lookPitch - delta.Y * RAD_PER_PIXEL * lookMul, -MAX_PITCH, MAX_PITCH)
				end
				-- first-person view from the head; the character follows the yaw (movement keys
				-- are relative to the camera, so they steer with the view automatically)
				local head = humanoid.Parent and humanoid.Parent:FindFirstChild("Head")
				local origin = if head then head.Position else root.Position + Vector3.new(0, 1.5, 0)
				workspace.CurrentCamera.CFrame = CFrame.fromEulerAnglesYXZ(lookPitch, lookYaw, 0) + origin
				root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, lookYaw, 0)
			end
		end
	end)
end

return CameraController
