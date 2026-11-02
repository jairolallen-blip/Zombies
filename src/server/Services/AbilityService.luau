-- AbilityService: class Abilities [E] (cooldown) and Ultimates [F] (charge from kills).
-- Class -> ability mapping is data in Config.Classes; behaviour is a handler in `Handlers` below,
-- keyed by Ability.Type. To add a new ability type: add Handlers.MyType = function(ctx) ... end,
-- then reference Type = "MyType" from a class in Config.Classes.
--
-- ctx passed to a handler:
--   ctx.Player, ctx.Character, ctx.Root (HumanoidRootPart), ctx.Params (from config),
--   ctx.Target (aim point on the ground, already clamped to Params.Range), ctx.Services
--
-- Player attributes: AbilityReadyAt (server time), UltCharge (written by EconomyService on kills)

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Classes = require(Shared.Config.Classes)
local Remotes = require(Shared.Remotes)
local GameState = require(Shared.GameState)

local AbilityService = {}
local Services
local turrets = {} -- active turret models (cleaned up at run end)

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function healPlayer(player, amount)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
	end
end

local function spawnTurret(owner, position, p)
	local groundY = Services.MapService.GroundY
	local model = Instance.new("Model")
	model.Name = "Turret"
	local function tPart(name, size, color, cf, material)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.CFrame = cf
		part.Material = material or Enum.Material.Metal
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Parent = model
		return part
	end
	local base = Vector3.new(position.X, groundY, position.Z)
	tPart("Base", Vector3.new(1.2, 3, 3), Color3.fromRGB(70, 70, 75), CFrame.new(base + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)))
	tPart("Post", Vector3.new(0.6, 2, 0.6), Color3.fromRGB(50, 50, 55), CFrame.new(base + Vector3.new(0, 2, 0)))
	local head = tPart("Head", Vector3.new(1.6, 1.2, 2.2), Color3.fromRGB(255, 190, 70), CFrame.new(base + Vector3.new(0, 3.4, 0)))
	local barrel = tPart("Barrel", Vector3.new(0.3, 0.3, 1.6), Color3.fromRGB(30, 30, 30), head.CFrame * CFrame.new(0, 0, -1.8))
	tPart("Light", Vector3.new(0.4, 0.4, 0.1), Color3.fromRGB(255, 60, 40), head.CFrame * CFrame.new(0, 0.2, -1.11), Enum.Material.Neon)
	model.PrimaryPart = head
	model.Parent = Services.CombatService.EffectsFolder
	table.insert(turrets, model)

	local expires = os.clock() + p.Duration
	task.spawn(function()
		while model.Parent and os.clock() < expires do
			local best, bestDist = nil, math.huge
			for _, entry in Services.ZombieService:GetInRadius(head.Position, p.Range) do
				if entry.Distance < bestDist then
					best, bestDist = entry, entry.Distance
				end
			end
			if best then
				local aim = Vector3.new(best.Position.X, head.Position.Y, best.Position.Z)
				local cf = CFrame.lookAt(head.Position, aim)
				head.CFrame = cf
				barrel.CFrame = cf * CFrame.new(0, 0, -1.8)
				model.Light.CFrame = cf * CFrame.new(0, 0.2, -1.11)
				Remotes.Effect:FireAllClients("Tracer", { From = (cf * CFrame.new(0, 0, -2.6)).Position, To = best.Position })
				Services.ZombieService:Damage(best.Model, p.Damage, owner)
			end
			task.wait(1 / p.FireRate)
		end
		model:Destroy()
	end)
end

local Handlers = {}

-- Grenade: a "Throw" effect plays the throw animation on every client (ThrowController), then the
-- grenade leaves the hand at the release point of the swing (GameConfig.Throw.Windup).
Handlers.Grenade = function(ctx)
	local p = ctx.Params
	local throw = GameConfig.Throw
	Remotes.Effect:FireAllClients("Throw", { Character = ctx.Character, Windup = throw.Windup, Duration = throw.Duration })
	task.delay(throw.Windup, function()
		if not ctx.Root.Parent then
			return
		end
		local from = (ctx.Root.CFrame * CFrame.new(1, 2.5, -1)).Position -- right hand, over the shoulder
		local to = ctx.Target
		local travel = math.clamp((to - from).Magnitude / 70, 0.3, 1.1)
		Remotes.Effect:FireAllClients("Projectile", { From = from, To = to, Time = travel, Color = Color3.fromRGB(60, 90, 50), Grenade = true, Owner = ctx.Player.UserId })
		task.delay(travel, function()
			Services.CombatService:Explode(to, p.Radius, p.Damage, ctx.Player)
		end)
	end)
end

Handlers.Airstrike = function(ctx)
	local p = ctx.Params
	local delay = p.Delay or 1
	Remotes.Effect:FireAllClients("Marker", { Position = ctx.Target, Radius = p.Spread, Time = delay })
	task.delay(delay, function()
		for _ = 1, p.Count do
			local offset = Vector3.new((math.random() * 2 - 1) * p.Spread, 0, (math.random() * 2 - 1) * p.Spread)
			Services.CombatService:Explode(ctx.Target + offset, p.Radius, p.Damage, ctx.Player)
			task.wait(p.Interval)
		end
	end)
end

Handlers.HealPulse = function(ctx)
	local p = ctx.Params
	Remotes.Effect:FireAllClients("Heal", { Position = ctx.Root.Position, Radius = p.Radius })
	for _, player in Services.MatchService:GetRunPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - ctx.Root.Position).Magnitude <= p.Radius then
			healPlayer(player, p.Heal)
		end
	end
end

Handlers.Revive = function(ctx)
	Services.MatchService:ReviveDead(ctx.Root.CFrame)
	Remotes.Effect:FireAllClients("Heal", { Position = ctx.Root.Position, Radius = 40 })
	for _, player in Services.MatchService:GetRunPlayers() do
		healPlayer(player, math.huge)
	end
end

Handlers.Turret = function(ctx)
	local p = ctx.Params
	for i = 1, p.Count do
		local angle = (i / p.Count) * math.pi * 2
		local offset = if p.Count == 1 then ctx.Root.CFrame.LookVector * 5 else Vector3.new(math.cos(angle), 0, math.sin(angle)) * 7
		spawnTurret(ctx.Player, ctx.Root.Position + offset, p)
	end
end

Handlers.Stomp = function(ctx)
	local p = ctx.Params
	local position = ctx.Root.Position
	Remotes.Effect:FireAllClients("Shockwave", { Position = position, Radius = p.Radius })
	for _, entry in Services.ZombieService:GetInRadius(position, p.Radius) do
		local killed = Services.ZombieService:Damage(entry.Model, p.Damage, ctx.Player)
		if not killed then
			Services.ZombieService:Knockback(entry.Model, position, p.Knockback or 50)
		end
	end
	if p.InvulnTime then
		local field = Instance.new("ForceField")
		field.Visible = true
		field.Parent = ctx.Character
		Debris:AddItem(field, p.InvulnTime)
	end
end

Handlers.Dash = function(ctx)
	-- The character is client-owned, so the client applies the impulse.
	Remotes.Effect:FireClient(ctx.Player, "Dash", { Speed = ctx.Params.Speed, Duration = ctx.Params.Duration })
end

AbilityService.Handlers = Handlers

local function clampTarget(origin, target, range)
	local groundY = Services.MapService.GroundY
	if typeof(target) ~= "Vector3" or target ~= target then -- NaN check
		target = origin
	end
	local flat = Vector3.new(target.X - origin.X, 0, target.Z - origin.Z)
	if flat.Magnitude > range then
		flat = flat.Unit * range
	end
	return Vector3.new(origin.X + flat.X, groundY, origin.Z + flat.Z)
end

function AbilityService:Init(services)
	Services = services
	Remotes.UseAbility.OnServerEvent:Connect(function(player, slot, aimPosition)
		self:Use(player, slot, aimPosition)
	end)
end

function AbilityService:Use(player, slot, aimPosition)
	if slot ~= "Ability" and slot ~= "Ultimate" then
		return
	end
	if not Services.MatchService:IsAliveInRun(player) then
		return
	end
	local class = Classes.List[player:GetAttribute("ClassId")]
	local ability = class and class[slot]
	if not ability then
		return
	end
	local handler = Handlers[ability.Type]
	if not handler then
		warn("[AbilityService] No handler for ability type", ability.Type)
		return
	end
	if slot == "Ability" then
		if serverNow() < (player:GetAttribute("AbilityReadyAt") or 0) then
			return
		end
		local early = ability.EarlyWaves and (GameState:GetAttribute("Wave") or 0) <= ability.EarlyWaves
		player:SetAttribute("AbilityReadyAt", serverNow() + (if early then ability.EarlyCooldown else ability.Cooldown))
	else
		if (player:GetAttribute("UltCharge") or 0) < GameConfig.Ultimate.Max then
			return
		end
		player:SetAttribute("UltCharge", 0)
		Remotes.Notify:FireClient(player, ability.Name .. "!", "Good")
	end

	local character = player.Character
	local root = character.HumanoidRootPart
	local params = ability.Params or {}
	handler({
		Player = player,
		Character = character,
		Root = root,
		Params = params,
		Target = clampTarget(root.Position, aimPosition, params.Range or 60),
		Services = Services,
	})
end

function AbilityService:Cleanup()
	for _, model in turrets do
		model:Destroy()
	end
	table.clear(turrets)
end

return AbilityService
