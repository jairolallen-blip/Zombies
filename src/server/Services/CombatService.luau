-- CombatService: weapons (server-validated hitscan), reloads, explosions, and damage to players.
--
-- Flow of a shot: client WeaponController raycasts for visuals and sends FireWeapon(origin, dirs)
-- -> _onFire validates (alive, ammo, fire rate, origin near head, pellet count)
-- -> re-raycasts each direction on the server (with Pierce) -> ZombieService:Damage
-- -> HitConfirm to the shooter, Tracer effect to everyone else.
--
-- Player attributes written here: WeaponId, Ammo, MagSize, Reloading
-- Public:
--   CombatService:EquipLoadout(player)   give the equipped weapon at current WeaponTier, full ammo
--   CombatService:RefreshWeapon(player)  re-apply after a tier upgrade
--   CombatService:Reload(player)
--   CombatService:DamagePlayer(player, amount)          applies class DamageTakenMult
--   CombatService:Explode(position, radius, damage, attacker?, { PlayerDamage = n? })
--   CombatService.EffectsFolder          Workspace.Effects (non-queryable server visuals)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Classes = require(Shared.Config.Classes)
local Weapons = require(Shared.Config.Weapons)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local CombatService = {}
local Services
local weaponState = {} -- [Player] = { Stats, Ammo, ReloadingUntil, ReloadToken, LastShot }

function CombatService:Init(services)
	Services = services
	local folder = Instance.new("Folder")
	folder.Name = "Effects"
	folder.Parent = workspace
	self.EffectsFolder = folder

	Remotes.FireWeapon.OnServerEvent:Connect(function(player, origin, dirs)
		self:_onFire(player, origin, dirs)
	end)
	Remotes.Reload.OnServerEvent:Connect(function(player)
		self:Reload(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		weaponState[player] = nil
	end)
end

local function buildTool(stats)
	local look = stats.Look
	local tool = Instance.new("Tool")
	tool.Name = stats.DisplayName
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = true

	local function gunPart(name, size, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		return p
	end

	-- Handle is the grip; the body extends forward along -Z.
	local handle = gunPart("Handle", Vector3.new(0.35, 0.9, 0.45), look.Color)
	handle.Parent = tool
	local bodyLength = look.Length
	local body = gunPart("Body", Vector3.new(0.4, 0.5, bodyLength), look.Color, Enum.Material.Metal)
	local barrel = gunPart("Barrel", Vector3.new(0.2, 0.2, bodyLength * 0.5), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
	local stripe = gunPart("TierStripe", Vector3.new(0.42, 0.12, bodyLength * 0.6), stats.TierColor, Enum.Material.Neon)
	local bodyOffset = CFrame.new(0, 0.5, -bodyLength / 2 + 0.25)
	local parts = {
		{ body, bodyOffset },
		{ barrel, bodyOffset * CFrame.new(0, 0.08, -bodyLength / 2 - bodyLength * 0.25) },
		{ stripe, bodyOffset * CFrame.new(0, 0.2, 0) },
	}
	for _, entry in parts do
		local p, offset = entry[1], entry[2]
		p.CFrame = handle.CFrame * offset
		local weld = Instance.new("Weld")
		weld.Part0 = handle
		weld.Part1 = p
		weld.C0 = offset
		weld.Parent = p
		p.Parent = tool
	end
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = (bodyOffset * CFrame.new(0, 0.08, -bodyLength / 2 - bodyLength * 0.5)).Position
	muzzle.Parent = handle

	-- Grip: hold the handle so the body points forward out of the hand
	tool.Grip = CFrame.new(0, -0.1, 0)
	return tool
end

function CombatService:EquipLoadout(player)
	local profile = Services.DataService:Get(player)
	local weaponId = profile and profile.EquippedWeapon or Weapons.Default
	local stats = Util.GetWeaponStats(weaponId, player:GetAttribute("WeaponTier") or 1)
	weaponState[player] = { Stats = stats, Ammo = stats.MagSize, ReloadingUntil = 0, LastShot = 0 }
	player:SetAttribute("WeaponId", stats.Id)
	player:SetAttribute("MagSize", stats.MagSize)
	player:SetAttribute("Ammo", stats.MagSize)
	player:SetAttribute("Reloading", false)

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			child:Destroy()
		end
	end
	player.Backpack:ClearAllChildren()
	local tool = buildTool(stats)
	tool.Parent = player.Backpack
	humanoid:EquipTool(tool)
end

function CombatService:RefreshWeapon(player)
	self:EquipLoadout(player)
end

function CombatService:Reload(player)
	local ws = weaponState[player]
	if not ws then
		return
	end
	local now = os.clock()
	if now < ws.ReloadingUntil or ws.Ammo >= ws.Stats.MagSize then
		return
	end
	ws.ReloadingUntil = now + ws.Stats.ReloadTime
	local token = {}
	ws.ReloadToken = token
	player:SetAttribute("Reloading", true)
	task.delay(ws.Stats.ReloadTime, function()
		if weaponState[player] == ws and ws.ReloadToken == token then
			ws.Ammo = ws.Stats.MagSize
			player:SetAttribute("Ammo", ws.Ammo)
			player:SetAttribute("Reloading", false)
		end
	end)
end

local function excludeList()
	local list = { CombatService.EffectsFolder }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	return list
end

-- One ray with pierce. Appends hit records to `hits`; returns the end point.
function CombatService:_traceShot(player, origin, dir, stats, hits)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList()
	local ZombieService = Services.ZombieService
	local pierceLeft = stats.Pierce or 1
	local start, remaining = origin, stats.Range
	while remaining > 0 do
		local result = workspace:Raycast(start, dir * remaining, params)
		if not result then
			return start + dir * remaining
		end
		local model = ZombieService:GetZombieFromPart(result.Instance)
		if not model then
			return result.Position
		end
		local partName = result.Instance.Name
		local headshot = partName == "Head" or partName == "Eye"
		local damage = stats.Damage * (if headshot then stats.HeadshotMultiplier else 1)
		local killed = ZombieService:Damage(model, damage, player)
		table.insert(hits, { Position = result.Position, Damage = math.floor(damage + 0.5), Headshot = headshot, Killed = killed })
		pierceLeft -= 1
		if pierceLeft <= 0 then
			return result.Position
		end
		params:AddToFilter(model)
		remaining -= (result.Position - start).Magnitude
		start = result.Position
	end
	return start
end

function CombatService:_onFire(player, origin, dirs)
	if typeof(origin) ~= "Vector3" or type(dirs) ~= "table" then
		return
	end
	local ws = weaponState[player]
	if not ws or not Services.MatchService:IsAliveInRun(player) then
		return
	end
	local stats = ws.Stats
	local now = os.clock()
	if now < ws.ReloadingUntil or ws.Ammo <= 0 then
		return
	end
	if now - ws.LastShot < (1 / stats.FireRate) * (1 - GameConfig.Combat.FireRateTolerance) then
		return
	end
	local head = player.Character:FindFirstChild("Head")
	if not head or (head.Position - origin).Magnitude > GameConfig.Combat.MaxOriginOffset then
		return
	end
	ws.LastShot = now
	ws.Ammo -= 1
	player:SetAttribute("Ammo", ws.Ammo)

	local hits = {}
	local firstEnd = nil
	for i = 1, math.min(#dirs, stats.Pellets) do
		local dir = dirs[i]
		if typeof(dir) == "Vector3" and dir.Magnitude > 0.5 then
			local endPoint = self:_traceShot(player, origin, dir.Unit, stats, hits)
			firstEnd = firstEnd or endPoint
		end
	end
	if #hits > 0 then
		Remotes.HitConfirm:FireClient(player, hits)
	end
	if firstEnd then
		local tool = player.Character:FindFirstChildOfClass("Tool")
		local muzzle = tool and tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild("Muzzle")
		local from = if muzzle then muzzle.WorldPosition else head.Position
		for _, other in Players:GetPlayers() do
			if other ~= player then
				Remotes.Effect:FireClient(other, "Tracer", { From = from, To = firstEnd })
			end
		end
	end
	if ws.Ammo <= 0 then
		self:Reload(player)
	end
end

function CombatService:DamagePlayer(player, amount)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local class = Classes.List[player:GetAttribute("ClassId")]
	local mult = if class then class.DamageTakenMult else 1
	humanoid:TakeDamage(amount * mult) -- TakeDamage is ignored while a ForceField is present
end

function CombatService:Explode(position, radius, damage, attacker, opts)
	opts = opts or {}
	Remotes.Effect:FireAllClients("Explosion", { Position = position, Radius = radius })
	for _, entry in Services.ZombieService:GetInRadius(position, radius) do
		local falloff = 1 - math.clamp(entry.Distance / radius, 0, 1) * 0.5
		Services.ZombieService:Damage(entry.Model, damage * falloff, attacker)
	end
	local playerDamage = opts.PlayerDamage or 0
	if playerDamage > 0 then
		for _, player in Services.MatchService:GetRunPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - position).Magnitude <= radius then
				self:DamagePlayer(player, playerDamage)
			end
		end
	end
end

return CombatService
