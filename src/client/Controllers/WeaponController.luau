-- WeaponController: shooting input, client-side prediction (ammo, tracers, muzzle flash), and
-- sending FireWeapon to the server (which re-validates and applies damage — see CombatService).
-- Stats come from Util.GetWeaponStats(WeaponId, WeaponTier) — same formula as the server.
--
-- Public: WeaponController:GetState() -> { Stats, Ammo, Reloading }, :Reload()

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
local lastShot = 0

function WeaponController:GetState()
	return { Stats = stats, Ammo = ammo, Reloading = reloading }
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
end

function WeaponController:TryFire()
	if not stats or not player:GetAttribute("InRun") or not alive() or reloading then
		return
	end
	if ammo <= 0 then
		self:Reload()
		return
	end
	local now = os.clock()
	if now - lastShot < 1 / stats.FireRate then
		return
	end
	lastShot = now
	ammo -= 1

	-- Shots leave the gun and fly toward the point under the mouse cursor
	local from, muzzle = muzzlePosition()
	local origin = from
	local aimPoint = Controllers.CameraController:GetAimPoint()
	local aimDir = aimPoint - origin
	if aimDir.Magnitude < 0.5 then
		aimDir = workspace.CurrentCamera.CFrame.LookVector
	end
	aimDir = aimDir.Unit
	local dirs = table.create(stats.Pellets)
	for i = 1, stats.Pellets do
		dirs[i] = spreadDirection(aimDir, stats.Spread)
	end
	Remotes.FireWeapon:FireServer(origin, dirs)

	-- Local visuals
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, workspace:FindFirstChild("Effects"), workspace:FindFirstChild("ClientEffects") }
	local Effects = Controllers.EffectsController
	for _, dir in dirs do
		local result = workspace:Raycast(origin, dir * stats.Range, params)
		Effects:Tracer(from, if result then result.Position else origin + dir * stats.Range)
	end
	Effects:MuzzleFlash(muzzle, from)
	Controllers.HUDController:KickCrosshair()
	if ammo <= 0 then
		self:Reload()
	end
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
		end
	end)
	RunService.RenderStepped:Connect(function()
		if firing and stats and stats.Automatic then
			self:TryFire()
		end
	end)
end

return WeaponController
