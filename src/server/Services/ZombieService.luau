-- ZombieService: builds blocky zombie models from Config.Zombies, runs their AI every Heartbeat,
-- and owns zombie health/death. Zombies live in Workspace.Zombies.
--
-- Movement: each zombie is one physics assembly (invisible "Root" hitbox + welded/motor limbs).
-- A LinearVelocity (plane mode) drives it toward its target and an AlignOrientation faces it.
-- Physics handles zombie-vs-zombie and zombie-vs-cover collision for free. Zombies do NOT
-- collide with players (collision groups) so the horde can never permanently pin someone.
-- Routing: straight at the player when there's a clear line, otherwise down the flow field
-- (Server/Map/NavGrid.lua) around fences, terrace and props. See navigate().
--
-- Public:
--   ZombieService:Spawn(typeId, position, healthMult?) -> Model
--   ZombieService:Damage(model, amount, attacker?) -> killed: boolean
--   ZombieService:Kill(model, attacker?)
--   ZombieService:Knockback(model, fromPosition, power, stunTime?)
--   ZombieService:GetInRadius(position, radius) -> {{Model, State, Distance, Position}}
--   ZombieService:GetZombieFromPart(part) -> Model?
--   ZombieService:PickType(wave) -> typeId (weighted by MinWave/Weight)
--   ZombieService:GetAliveCount(), ZombieService:ClearAll()
--   ZombieService.Killed  Signal(state, attacker)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zombies = require(Shared.Config.Zombies)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)
local GameState = require(Shared.GameState)
local GameConfig = require(Shared.Config.GameConfig)
local NavGrid = require(script.Parent.Parent:WaitForChild("Map"):WaitForChild("NavGrid"))

local ZombieService = {}
ZombieService.Killed = Util.Signal.new()

local Services
local folder
local alive = {} -- [Model] = state (see Spawn)
local aliveCount = 0
local nextId = 0

local function ensureGroup(name)
	if not PhysicsService:IsCollisionGroupRegistered(name) then
		PhysicsService:RegisterCollisionGroup(name)
	end
end

function ZombieService:Init(services)
	Services = services
	ensureGroup("Zombies")
	ensureGroup("Players")
	PhysicsService:CollisionGroupSetCollidable("Zombies", "Players", false)
	folder = Instance.new("Folder")
	folder.Name = "Zombies"
	folder.Parent = workspace
end

function ZombieService:Start()
	-- Scan the (static) arena once for the flow-field navigation grid. Call again if the map changes.
	self:BuildNavGrid()
	RunService.Heartbeat:Connect(function(dt)
		self:_step(dt)
	end)
end

function ZombieService:BuildNavGrid()
	local center, halfSize, lattice = Services.MapService:GetNavBounds()
	local cells, blocked = NavGrid.Build(center, halfSize, GameConfig.Map.CellSize, Services.MapService.GroundY, {
		folder,
		Services.CombatService.EffectsFolder,
	}, lattice)
	print(string.format("[ZombieService] NavGrid built: %d cells, %d blocked", cells, blocked))
end

-- Model building -------------------------------------------------------------------------------

local function newPart(name, size, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.CollisionGroup = "Zombies"
	return p
end

local function buildModel(typeId, def, cf)
	local s = def.Scale or 1
	local look = def.Look
	local torsoMult = look.TorsoSize or Vector3.one
	local model = Instance.new("Model")
	model.Name = typeId

	local root = newPart("Root", Vector3.new(2.4, 5, 1.6) * s, Color3.new())
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	root.CustomPhysicalProperties = PhysicalProperties.new(1, 0, 0, 100, 100)
	root.CFrame = cf
	root.Parent = model
	model.PrimaryPart = root

	local function weld(p, offset)
		p.CFrame = cf * offset
		local w = Instance.new("Weld")
		w.Part0 = root
		w.Part1 = p
		w.C0 = offset
		w.Parent = p
		p.Parent = model
	end
	local function motor(p, joint, limbCenter)
		p.CFrame = cf * limbCenter
		local m = Instance.new("Motor6D")
		m.Name = p.Name
		m.Part0 = root
		m.Part1 = p
		m.C0 = joint
		m.C1 = limbCenter:Inverse() * joint
		m.Parent = root
		p.Parent = model
	end

	weld(newPart("Torso", Vector3.new(2, 2, 1) * s * torsoMult, look.Shirt), CFrame.new(0, 0.5 * s, 0))
	weld(newPart("Head", Vector3.new(1.25, 1.25, 1.25) * s, look.Skin), CFrame.new(0, 2.1 * s, 0))
	for _, x in { -0.28, 0.28 } do
		local eye = newPart("Eye", Vector3.new(0.28, 0.22, 0.1) * s, look.Eyes)
		eye.Material = Enum.Material.Neon
		weld(eye, CFrame.new(x * s, 2.25 * s, -0.63 * s))
	end
	local armX = 1 * s + 0.5 * s * torsoMult.X
	for _, side in { { "LeftArm", -1 }, { "RightArm", 1 } } do
		local x = armX * side[2]
		motor(newPart(side[1], Vector3.new(1, 1, 2.4) * s, look.Skin), CFrame.new(x, 1.0 * s, 0), CFrame.new(x, 1.0 * s, -1.1 * s))
	end
	for _, side in { { "LeftLeg", -0.5 }, { "RightLeg", 0.5 } } do
		local x = side[2] * s
		motor(newPart(side[1], Vector3.new(1, 2, 1) * s, look.Pants), CFrame.new(x, -0.5 * s, 0), CFrame.new(x, -1.5 * s, 0))
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "Move"
	attachment.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.PlaneVelocity = Vector2.zero
	lv.MaxForce = root:GetMass() * 250
	lv.Parent = root
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = attachment
	ao.Responsiveness = 25
	ao.MaxTorque = math.huge
	ao.CFrame = cf.Rotation
	ao.Parent = root

	return model, root, lv, ao
end

-- Lifecycle ------------------------------------------------------------------------------------

function ZombieService:Spawn(typeId, position, healthMult)
	local def = Zombies.Types[typeId]
	assert(def, "Unknown zombie type: " .. tostring(typeId))
	local s = def.Scale or 1
	local cf = CFrame.new(position.X, Services.MapService.GroundY + 2.5 * s + 0.05, position.Z)
		* CFrame.Angles(0, math.random() * math.pi * 2, 0)
	local model, root, lv, ao = buildModel(typeId, def, cf)
	nextId += 1
	model:SetAttribute("ZombieId", nextId)
	model:SetAttribute("Type", typeId)

	local maxHealth = def.Health * (healthMult or 1)
	local state = {
		Id = nextId,
		Type = typeId,
		Def = def,
		Model = model,
		Root = root,
		LV = lv,
		AO = ao,
		Health = maxHealth,
		MaxHealth = maxHealth,
		Target = nil, -- HumanoidRootPart being chased
		NextRetarget = 0,
		NextAttack = 0,
		StunnedUntil = 0,
		FuseAt = nil, -- Explode: time the fuse goes off
		NextSlam = os.clock() + 3,
		Slamming = false,
		-- navigation (see navigate())
		Side = if math.random() < 0.5 then -1 else 1, -- detour direction when stuck
		HasLOS = false, -- clear straight line to the target?
		NextSteer = 0,
		LastPos = position,
		StuckCount = 0,
		DetourUntil = 0,
	}
	model.Parent = folder
	root:SetNetworkOwner(nil)
	alive[model] = state
	aliveCount += 1

	if def.Boss then
		GameState:SetAttribute("BossName", def.DisplayName)
		GameState:SetAttribute("BossMaxHealth", maxHealth)
		GameState:SetAttribute("BossHealth", maxHealth)
	end
	return model
end

function ZombieService:Damage(model, amount, attacker)
	local z = alive[model]
	if not z or z.Dead then
		return false
	end
	z.Health -= amount
	if z.Def.Boss then
		GameState:SetAttribute("BossHealth", math.max(0, math.floor(z.Health)))
	end
	if z.Health <= 0 then
		self:Kill(model, attacker)
		return true
	end
	return false
end

function ZombieService:Kill(model, attacker)
	local z = alive[model]
	if not z or z.Dead then
		return
	end
	z.Dead = true
	alive[model] = nil
	aliveCount -= 1
	local def = z.Def
	local position = z.Root.Position
	Remotes.Effect:FireAllClients("ZombieDeath", { Position = position, Color = def.Look.Skin, Scale = def.Scale or 1 })
	if attacker then
		Services.EconomyService:OnZombieKilled(attacker, z)
	end
	if def.Boss then
		GameState:SetAttribute("BossName", "")
		GameState:SetAttribute("BossHealth", 0)
		GameState:SetAttribute("BossMaxHealth", 0)
	end
	model:Destroy()
	if def.Explode then
		local e = def.Explode
		local playerDamage = if attacker then e.Damage * e.ShotPlayerDamageMult else e.Damage
		Services.CombatService:Explode(position, e.Radius, e.Damage, attacker, { PlayerDamage = playerDamage })
	end
	self.Killed:Fire(z, attacker)
end

-- Remove without rewards/effects (fell out of the world, run reset)
function ZombieService:Remove(model)
	local z = alive[model]
	if z then
		z.Dead = true
		alive[model] = nil
		aliveCount -= 1
		if z.Def.Boss then
			GameState:SetAttribute("BossName", "")
			GameState:SetAttribute("BossMaxHealth", 0)
		end
	end
	model:Destroy()
end

function ZombieService:ClearAll()
	for model in alive do
		self:Remove(model)
	end
	folder:ClearAllChildren()
	aliveCount = 0
end

function ZombieService:GetAliveCount()
	return aliveCount
end

function ZombieService:GetZombieFromPart(part)
	local model = part and part:FindFirstAncestorOfClass("Model")
	if model and alive[model] then
		return model
	end
	return nil
end

function ZombieService:GetInRadius(position, radius)
	local results = {}
	for model, z in alive do
		local pos = z.Root.Position
		local distance = (pos - position).Magnitude - 1.2 * (z.Def.Scale or 1)
		if distance <= radius then
			table.insert(results, { Model = model, State = z, Distance = math.max(0, distance), Position = pos })
		end
	end
	return results
end

function ZombieService:Knockback(model, fromPosition, power, stunTime)
	local z = alive[model]
	if not z then
		return
	end
	local dir = (z.Root.Position - fromPosition) * Vector3.new(1, 0, 1)
	if dir.Magnitude < 0.1 then
		dir = Vector3.xAxis
	end
	z.StunnedUntil = os.clock() + (stunTime or 0.6)
	z.LV.Enabled = false
	z.Root.AssemblyLinearVelocity = dir.Unit * power / (z.Def.Scale or 1) + Vector3.new(0, power * 0.35, 0)
end

function ZombieService:PickType(wave)
	local pool, total = {}, 0
	for typeId, def in Zombies.Types do
		if not def.Boss and (def.MinWave or 1) <= wave and (def.Weight or 0) > 0 then
			table.insert(pool, { typeId, def.Weight })
			total += def.Weight
		end
	end
	local roll = math.random() * total
	for _, entry in pool do
		roll -= entry[2]
		if roll <= 0 then
			return entry[1]
		end
	end
	return pool[1] and pool[1][1] or "Shambler"
end

-- AI -------------------------------------------------------------------------------------------

-- Navigation (see Map/NavGrid.lua). Every NAV_INTERVAL each zombie spherecasts toward its target:
--   clear line  -> charge straight at the player
--   blocked     -> follow the flow field (walks around fences/terrace/props through the gaps)
-- Fallback: if it hasn't moved for ~0.6s while trying to, it detours sideways briefly.
local NAV_INTERVAL = 0.25
local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
losParams.RespectCanCollide = true
local nextFilterRefresh = 0

local function rotateFlat(v, angle)
	local c, s = math.cos(angle), math.sin(angle)
	return Vector3.new(v.X * c - v.Z * s, 0, v.X * s + v.Z * c)
end

local function navigate(z, dir, dist, targetPos, now)
	local root = z.Root
	local s = z.Def.Scale or 1
	if now >= z.NextSteer then
		z.NextSteer = now + NAV_INTERVAL * (0.8 + math.random() * 0.4)
		-- line of sight at body height, as wide as the zombie
		local hit = workspace:Spherecast(root.Position, 0.9 * s, dir * math.max(0, dist - 1), losParams)
		z.HasLOS = hit == nil
		-- stuck detection
		if (root.Position - z.LastPos).Magnitude < 0.6 then
			z.StuckCount += 1
			if z.StuckCount >= 3 then
				z.StuckCount = 0
				z.Side = -z.Side
				z.DetourUntil = now + 0.6 + math.random() * 0.5
			end
		else
			z.StuckCount = 0
		end
		z.LastPos = root.Position
	end
	local move = dir
	if not z.HasLOS then
		move = NavGrid.GetDirection(root.Position, targetPos) or dir
	end
	if now < z.DetourUntil then
		move = rotateFlat(move, z.Side * math.rad(70))
	end
	return move
end

local function findTarget(position)
	local best, bestDist = nil, math.huge
	for _, player in Players:GetPlayers() do
		if Services.MatchService:IsAliveInRun(player) then
			local root = player.Character.HumanoidRootPart
			local d = (root.Position - position).Magnitude
			if d < bestDist then
				best, bestDist = root, d
			end
		end
	end
	return best
end

local function startFuse(z)
	z.FuseAt = os.clock() + z.Def.Explode.Fuse
	local torso = z.Model:FindFirstChild("Torso")
	if torso then
		torso.Material = Enum.Material.Neon
	end
end

local function doSlam(z, now)
	local slam = z.Def.Slam
	z.Slamming = true
	z.NextSlam = now + slam.Cooldown
	local ground = Vector3.new(z.Root.Position.X, Services.MapService.GroundY + 0.1, z.Root.Position.Z)
	local ring = Instance.new("Part")
	ring.Name = "SlamTelegraph"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, slam.Radius * 2, slam.Radius * 2)
	ring.CFrame = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(255, 50, 40)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.55
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Parent = Services.CombatService.EffectsFolder
	task.delay(slam.Windup, function()
		ring:Destroy()
		z.Slamming = false
		if z.Dead then
			return
		end
		Remotes.Effect:FireAllClients("Shockwave", { Position = ground, Radius = slam.Radius })
		for _, player in Services.MatchService:GetRunPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and Util.FlatDistance(root.Position, ground) <= slam.Radius then
				Services.CombatService:DamagePlayer(player, slam.Damage)
			end
		end
	end)
end

function ZombieService:_step(_dt)
	local now = os.clock()
	if now >= nextFilterRefresh then
		-- line-of-sight casts ignore zombies, effects/turrets and players (targets, not obstacles)
		nextFilterRefresh = now + 1
		local ignore = { folder, Services.CombatService.EffectsFolder }
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(ignore, player.Character)
			end
		end
		losParams.FilterDescendantsInstances = ignore
	end
	local groundY = Services.MapService.GroundY
	for model, z in alive do
		local root = z.Root
		if not root.Parent or root.Position.Y < groundY - 40 then
			self:Remove(model)
			continue
		end
		if now >= z.NextRetarget or not (z.Target and z.Target.Parent) then
			z.Target = findTarget(root.Position)
			z.NextRetarget = now + 0.4 + math.random() * 0.3
		end

		local def = z.Def
		local s = def.Scale or 1
		local velocity = Vector2.zero
		local target = z.Target
		if target and target.Parent and now >= z.StunnedUntil and not z.Slamming then
			local offset = target.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local dist = flat.Magnitude
			local reach = def.AttackRange + 1.2 * s
			if dist > 0.05 then
				local dir = flat / dist
				local wantsMove = dist > reach * 0.6
				local moveDir = if wantsMove then navigate(z, dir, dist, target.Position, now) else dir
				z.AO.CFrame = CFrame.lookAt(Vector3.zero, moveDir)
				if wantsMove then
					velocity = Vector2.new(moveDir.X, moveDir.Z) * def.Speed
				end
			end
			if def.Damage > 0 and dist <= reach and math.abs(offset.Y) < 6 * s and now >= z.NextAttack then
				z.NextAttack = now + def.AttackCooldown
				local player = Players:GetPlayerFromCharacter(target.Parent)
				if player then
					Services.CombatService:DamagePlayer(player, def.Damage)
				end
			end
			if def.Explode and not z.FuseAt and dist <= def.Explode.TriggerRange then
				startFuse(z)
			end
			if def.Slam and now >= z.NextSlam and dist <= def.Slam.TriggerRange then
				doSlam(z, now)
			end
		end

		if z.FuseAt and now >= z.FuseAt then
			self:Kill(model, nil)
			continue
		end
		if now < z.StunnedUntil then
			z.LV.Enabled = false
		else
			z.LV.Enabled = true
			z.LV.PlaneVelocity = velocity
		end
	end
end

return ZombieService
