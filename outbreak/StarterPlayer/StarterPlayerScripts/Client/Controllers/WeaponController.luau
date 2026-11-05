-- WeaponController: shooting input, client-side prediction (ammo, tracers, muzzle flash), and
-- sending FireWeapon to the server (which re-validates and applies damage — see CombatService).
-- Stats come from Util.GetWeaponStats(WeaponId, WeaponTier) — same formula as the server.
-- Feel (vault: Weapons.md): camera recoil kick (stats.Recoil), per-gun tracers/flash, ejected
-- shells, and SpinUp guns (minigun) that ramp their fire rate while the barrel hub spins.
--
-- First person: shots originate at the camera (eye) through the crosshair; the flash, tracers,
-- shells and recoil jolt come from ViewmodelController's gun. Sounds via SoundController.
-- Hold Keybinds.Aim (right mouse) to aim down sights: ViewmodelController blends the gun to the
-- centre and spread shrinks by GameConfig.Camera.AimSpreadMultiplier.
--
-- Public: WeaponController:GetState() -> { Stats, Ammo, Reloading }, :Reload(), :IsAimHeld()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer
local WeaponController = {}
local Controllers

local stats = nil
local ammo = 0
local reloading = false
local firing = false
local aimHeld = false
local lastShot = 0
local recoil = 0 -- current camera kick, radians (decays every frame)
local recoilYaw = 0
local punch = 0 -- fast snap on top of the climb (GameConfig.Camera.RecoilPunch)
local recoilRoll = 0 -- random roll shake per shot
local fovPunch = 0 -- degrees added to the FOV, read by CameraController
local spin = 0 -- 0..1 spin-up progress for SpinUp guns
local spinAngle = 0

function WeaponController:GetState()
	return { Stats = stats, Ammo = ammo, Reloading = reloading }
end

function WeaponController:IsAimHeld()
	return aimHeld and player:GetAttribute("InRun") == true
end

function WeaponController:GetFovPunch()
	return fovPunch
end

local function refreshStats()
	local weaponId = player:GetAttribute("WeaponId")
	if weaponId then
		stats = Util.GetWeaponStats(weaponId, player:GetAttribute("WeaponTier") or 1)
		ammo = player:GetAttribute("Ammo") or stats.MagSize
	end
end

local function alive()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid.Health > 0
end

local function spreadDirection(direction, degrees)
	if degrees <= 0 then
		return direction
	end
	local angle = math.rad(degrees) * math.sqrt(math.random())
	local roll = math.random() * math.pi * 2
	return (CFrame.lookAt(Vector3.zero, direction) * CFrame.Angles(0, 0, roll) * CFrame.Angles(angle, 0, 0)).LookVector
end

local function muzzlePosition()
	-- first person: effects come from the viewmodel gun in front of the camera
	local vmMuzzle = Controllers.ViewmodelController:GetMuzzle()
	if vmMuzzle then
		return vmMuzzle.WorldPosition, vmMuzzle
	end
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local muzzle = tool and tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild("Muzzle")
	if muzzle then
		return muzzle.WorldPosition, muzzle
	end
	local head = character and character:FindFirstChild("Head")
	return head and head.Position or Vector3.zero, nil
end

function WeaponController:Reload()
	if not stats or reloading or ammo >= stats.MagSize then
		return
	end
	reloading = true
	Remotes.Reload:FireServer()
	Controllers.ViewmodelController:PlayReload(stats.ReloadTime)
	Controllers.SoundController:PlayReload(stats.ReloadTime, Controllers.ViewmodelController:GetModel())
end

function WeaponController:TryFire()
	if not stats or not player:GetAttribute("InRun") or not alive() or reloading then
		return
	end
	if Controllers.ViewmodelController:IsThrowing() then
		return -- the gun is lowered for a grenade throw
	end
	if ammo <= 0 then
		self:Reload()
		return
	end
	local now = os.clock()
	local rate = if stats.SpinUp then stats.FireRate * (0.3 + 0.7 * spin) else stats.FireRate
	if now - lastShot < 1 / rate then
		return
	end
	lastShot = now
	ammo -= 1

	-- First person: shots start at the camera (the eye) and go through the crosshair, so what you
	-- aim at is what you hit; tracers/flash are drawn from the viewmodel muzzle.
	local from, muzzle = muzzlePosition()
	local origin = if Controllers.CameraController:IsActive() then workspace.CurrentCamera.CFrame.Position else from
	local aimPoint = Controllers.CameraController:GetAimPoint()
	local aimDir = aimPoint - origin
	if aimDir.Magnitude < 0.5 then
		aimDir = workspace.CurrentCamera.CFrame.LookVector
	end
	aimDir = aimDir.Unit
	local aim = Controllers.ViewmodelController:GetAim()
	local spread = stats.Spread * (1 + (GameConfig.Camera.AimSpreadMultiplier - 1) * aim)
	local dirs = table.create(stats.Pellets)
	for i = 1, stats.Pellets do
		dirs[i] = spreadDirection(aimDir, spread)
	end
	Remotes.FireWeapon:FireServer(origin, dirs)

	-- Local visuals
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, workspace:FindFirstChild("Effects"), workspace:FindFirstChild("ClientEffects") }
	local Effects = Controllers.EffectsController
	for _, dir in dirs do
		local result = workspace:Raycast(origin, dir * stats.Range, params)
		Effects:WeaponTracer(stats.Id, from, if result then result.Position else origin + dir * stats.Range)
	end
	-- the first-person gun is scaled down, so its flash and shells are too
	local vmScale = if Controllers.ViewmodelController:GetModel() then GameConfig.Camera.ViewmodelScale else 1
	Effects:MuzzleFlash(muzzle, from, (stats.Flash or 1) * vmScale, stats.FlashColor)
	local port = muzzle and muzzle.Parent:FindFirstChild("EjectPort")
	if port and not stats.NoShells then
		Effects:Shell(port.WorldPosition, workspace.CurrentCamera.CFrame.RightVector, vmScale)
		Controllers.SoundController:PlayShell()
	end
	Controllers.ViewmodelController:Kick(stats.Recoil, rate)
	Controllers.SoundController:PlayGunshot(stats.Id, from)
	local kick = math.rad(stats.Recoil or 1)
	local cam = GameConfig.Camera
	-- the camera only nudges (easy to aim); hipfire hides it behind the viewmodel kick, and
	-- ADS keeps almost all of it since the viewmodel is small on screen and can't sell it
	local steady = 1 - 0.1 * aim -- aiming down sights tames it a little
	recoil = math.min(recoil + kick * cam.RecoilCamera * (0.85 + math.random() * 0.3) * steady, math.rad(1.5))
	recoilYaw += kick * cam.RecoilCamera * (math.random() - 0.5) * 0.4
	punch = math.min(punch + kick * cam.RecoilPunch * steady, math.rad(3))
	recoilRoll += kick * (math.random() - 0.5) * cam.RecoilShake
	fovPunch = math.min(fovPunch + (stats.Recoil or 1) * cam.RecoilFovPunch, 4)
	Controllers.HUDController:KickCrosshair()
	if ammo <= 0 then
		self:Reload()
	end
end

-- the trigger and aim for touch buttons and gamepads (Client/Controllers/TouchController)
function WeaponController:SetTrigger(on)
	firing = on
	if on then
		self:TryFire()
	end
end

function WeaponController:SetAim(on)
	if on and not aimHeld and player:GetAttribute("InRun") then
		Controllers.SoundController:Play("Aim")
	end
	aimHeld = on
end

function WeaponController:Init(controllers)
	Controllers = controllers
	player:GetAttributeChangedSignal("WeaponId"):Connect(refreshStats)
	player:GetAttributeChangedSignal("WeaponTier"):Connect(refreshStats)
	player:GetAttributeChangedSignal("Ammo"):Connect(function()
		local serverAmmo = player:GetAttribute("Ammo") or 0
		-- Accept the server's number after a reload, or once we've stopped shooting for a moment
		if serverAmmo > ammo or os.clock() - lastShot > 0.4 then
			ammo = serverAmmo
		end
	end)
	player:GetAttributeChangedSignal("Reloading"):Connect(function()
		reloading = player:GetAttribute("Reloading") == true
		if not reloading then
			ammo = player:GetAttribute("Ammo") or ammo
		end
	end)
	refreshStats()

	UserInputService.InputBegan:Connect(function(input, processed)
		-- aim is read even if the camera marked the right button as processed
		if input.UserInputType == GameConfig.Keybinds.Aim then
			aimHeld = true
			if player:GetAttribute("InRun") then
				Controllers.SoundController:Play("Aim")
			end
			return
		end
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			firing = true
			self:TryFire()
		elseif input.KeyCode == GameConfig.Keybinds.Reload then
			self:Reload()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			firing = false
		elseif input.UserInputType == GameConfig.Keybinds.Aim then
			aimHeld = false
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		-- minigun-style spin-up: ramps while the trigger is held, winds down when released
		if stats and stats.SpinUp then
			local holding = firing and not reloading and player:GetAttribute("InRun") == true
			spin = math.clamp(spin + (if holding then dt / stats.SpinUp else -dt / 0.8), 0, 1)
		else
			spin = 0
		end
		local character = player.Character
		local tool = character and character:FindFirstChildOfClass("Tool")
		spinAngle += dt * spin * 45
		-- spin the barrels on both the real tool and the first-person viewmodel
		for _, gun in { tool, Controllers.ViewmodelController:GetModel() } do
			local hub = gun and gun:FindFirstChild("SpinHub")
			local spinWeld = hub and hub:FindFirstChild("SpinWeld")
			if spinWeld then
				spinWeld.C0 = hub:GetAttribute("BaseC0") * CFrame.Angles(0, 0, spinAngle)
			end
		end
		Controllers.SoundController:SetSpin(if stats and stats.SpinUp then spin else 0)
		if firing and stats and stats.Automatic then
			self:TryFire()
		end
	end)
	-- recoil: kick the camera after it updates; the default camera re-derives its CFrame every
	-- frame, so the offset never accumulates and decays smoothly back to the aim
	RunService:BindToRenderStep("SAMZ_Recoil", Enum.RenderPriority.Camera.Value + 3, function(dt)
		-- climb recovers steadily; the punch, roll shake and FOV kick snap back fast
		local decay = math.exp(-20 * dt)
		recoil *= decay
		recoilYaw *= decay
		punch *= math.exp(-45 * dt) -- snap: gone in ~70ms
		recoilRoll *= math.exp(-35 * dt)
		fovPunch *= math.exp(-35 * dt)
		if Controllers.CameraController:IsActive() and (recoil + punch > 1e-4 or math.abs(recoilYaw) + math.abs(recoilRoll) > 1e-4) then
			local camera = workspace.CurrentCamera
			camera.CFrame *= CFrame.Angles(recoil + punch, recoilYaw, recoilRoll)
		end
	end)
end

return WeaponController
