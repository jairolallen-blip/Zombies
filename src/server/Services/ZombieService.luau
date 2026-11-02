-- ZombieService: spawns zombies (models from Server/ZombieModels), runs their AI every Heartbeat,
-- and owns zombie health/death. Zombies live in Workspace.Zombies. Behaviour (vault: Zombies.md):
-- per-zombie speed variety, surround slots near the player, runner lunges, hit flinch, and an
-- "AttackAt" model attribute the client uses for the swipe animation.
--
-- Movement: each zombie is one physics assembly (invisible "Root" hitbox + welded/motor limbs).
-- A LinearVelocity (plane mode) drives it toward its target and an AlignOrientation faces it.
-- Physics handles zombie-vs-zombie and zombie-vs-cover collision for free. Zombies do NOT
-- collide with players (collision groups) so the horde can never permanently pin someone.
-- Routing: straight at the player when there's a clear line, otherwise down the flow field
-- (Server/Map/NavGrid.lua) around fences, terrace and props. See navigate().
--
-- Public:
--   ZombieService:Spawn(typeId, position, healthMult?, riseTime?) -> Model
--   ZombieService:SpawnWarned(typeId, position, healthMult?)   red circle first, then it rises (vault: Spawning.md)
--   ZombieService:GetPendingCount()   warned spawns that haven't risen yet
--   ZombieService:Damage(model, amount, attacker?) -> killed: boolean
--   ZombieService:Kill(model, attacker?)
--   ZombieService:Knockback(model, fromPosition, power, stunTime?)
--   ZombieService:GetInRadius(position, radius) -> {{Model, State, Distance, Position}}
--   ZombieService:GetZombieFromPart(part) -> Model?
--   ZombieService:PickType(wave) -> typeId (weighted by MinWave/Weight)
--   ZombieService:GetAliveCount(), ZombieService:ClearAll()
--   ZombieService.Killed  Signal(state, attacker)
--   ZombieService.BossEnraged  Signal(state)   boss crossed Def.Enrage.At (see _enrage)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zombies = require(Shared.Config.Zombies)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)
local GameState = require(Shared.GameState)
local GameConfig = require(Shared.Config.GameConfig)
local NavGrid = require(script.Parent.Parent:WaitForChild("Map"):WaitForChild("NavGrid"))
local ZombieModels = require(script.Parent.Parent:WaitForChild("ZombieModels"))

local ZombieService = {}
ZombieService.Killed = Util.Signal.new()
ZombieService.BossEnraged = Util.Signal.new()

local Services
local folder
local alive = {} -- [Model] = state (see Spawn)
local aliveCount = 0
local pendingCount = 0 -- SpawnWarned zombies still in their warning window
local generation = 0 -- bumped by ClearAll so warnings from a finished run never spawn
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
	local cells, blocked = NavGrid.Build(center, halfSize, GameConfig.OurMap.NavCellSize, Services.MapService.GroundY, {
		folder,
		Services.CombatService.EffectsFolder,
	}, lattice)
	print(string.format("[ZombieService] NavGrid built: %d cells, %d blocked", cells, blocked))
end

-- Lifecycle ------------------------------------------------------------------------------------

function ZombieService:Spawn(typeId, position, healthMult, riseTime)
	local def = Zombies.Types[typeId]
	assert(def, "Unknown zombie type: " .. tostring(typeId))
	local s = def.Scale or 1
	local cf = CFrame.new(position.X, Services.MapService.GroundY + 2.5 * s + 0.05, position.Z)
		* CFrame.Angles(0, math.random() * math.pi * 2, 0)
	local model, root, lv, ao = ZombieModels.Build(typeId, def, cf)
	if riseTime then -- start buried; _rise lifts it out, then hands it to physics
		root.Anchored = true
		root.CFrame = cf - Vector3.new(0, 5 * s, 0)
	end
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
		-- behaviour (see _step)
		SpeedMult = if def.Boss then 1 else 0.85 + math.random() * 0.3,
		Slot = nil, -- angle around the player this zombie closes in on (set when it gets near)
		FlinchUntil = 0,
		LungeUntil = 0,
		NextLunge = 0,
	}
	model.Parent = folder
	if riseTime then
		state.StunnedUntil = os.clock() + riseTime
		local tween = TweenService:Create(root, TweenInfo.new(riseTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = cf })
		tween.Completed:Connect(function()
			if root.Parent then
				root.Anchored = false
				root:SetNetworkOwner(nil)
			end
		end)
		tween:Play()
	else
		root:SetNetworkOwner(nil)
	end
	alive[model] = state
	aliveCount += 1

	if def.Boss then
		GameState:SetAttribute("BossEnraged", false)
		GameState:SetAttribute("BossName", def.DisplayName)
		GameState:SetAttribute("BossMaxHealth", maxHealth)
		GameState:SetAttribute("BossHealth", maxHealth)
	end
	return model
end

-- Red warning circle on the ground, then the zombie climbs out of it (GameConfig.Waves timings).
function ZombieService:SpawnWarned(typeId, position, healthMult)
	local W = GameConfig.Waves
	local s = Zombies.Types[typeId].Scale or 1
	local ground = Vector3.new(position.X, Services.MapService.GroundY, position.Z)
	Remotes.Effect:FireAllClients("SpawnWarning", { Position = ground, Radius = 2.4 * s, Time = W.SpawnWarning })
	pendingCount += 1
	local gen = generation
	task.delay(W.SpawnWarning, function()
		if gen ~= generation then
			return -- run ended (ClearAll) while this one was still a warning
		end
		pendingCount -= 1
		self:Spawn(typeId, position, healthMult, W.RiseTime)
	end)
end

function ZombieService:GetPendingCount()
	return pendingCount
end

function ZombieService:Damage(model, amount, attacker)
	local z = alive[model]
	if not z or z.Dead then
		return false
	end
	z.Health -= amount
	if not z.Def.Boss then
		z.FlinchUntil = os.clock() + 0.15
	end
	if z.Def.Boss then
		GameState:SetAttribute("BossHealth", math.max(0, math.floor(z.Health)))
	end
	if z.Health <= 0 then
		self:Kill(model, attacker)
		return true
	end
	local enrage = z.Def.Enrage
	if enrage and not z.Enraged and z.Health <= z.MaxHealth * enrage.At then
		self:_enrage(z)
	end
	return false
end

-- Boss rage: faster, slams more often, and a ring of summoned zombies rises around it.
function ZombieService:_enrage(z)
	local enrage = z.Def.Enrage
	z.Enraged = true
	z.SpeedMult *= enrage.SpeedMult
	z.NextSlam = math.min(z.NextSlam, os.clock() + 1)
	GameState:SetAttribute("BossEnraged", true)
	local center = z.Root.Position
	for i = 1, enrage.SummonCount do
		local angle = i / enrage.SummonCount * math.pi * 2
		local pos = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * enrage.SummonRadius
		if not NavGrid.IsWalkable(pos) then
			pos = Services.MapService:GetZombieSpawnPosition()
		end
		self:SpawnWarned(enrage.Summon, pos)
	end
	self.BossEnraged:Fire(z)
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
		GameState:SetAttribute("BossEnraged", false)
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
	generation += 1
	pendingCount = 0
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
local SURROUND_RANGE = 14 -- studs: inside this, zombies spread into slots around their target
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
	z.NextSlam = now + slam.Cooldown * (if z.Enraged then z.Def.Enrage.SlamCooldownMult else 1)
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
				local goal, goalDist = target.Position, dist
				-- surround: near the player, close in on an own slot around them instead of the centre
				if dist < SURROUND_RANGE and not def.Boss then
					z.Slot = z.Slot or math.atan2(-dir.Z, -dir.X) + (math.random() - 0.5) * 1.2
					goal = target.Position + Vector3.new(math.cos(z.Slot), 0, math.sin(z.Slot)) * reach * 0.7
					local toGoal = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z)
					goalDist = toGoal.Magnitude
					if goalDist > 0.05 then
						dir = toGoal / goalDist
					end
				elseif dist > SURROUND_RANGE * 1.5 then
					z.Slot = nil -- lost them: pick a fresh slot next time
				end
				local wantsMove = dist > reach * 0.6 and goalDist > 0.6
				local moveDir = if wantsMove then navigate(z, dir, goalDist, goal, now) else flat / dist
				z.AO.CFrame = CFrame.lookAt(Vector3.zero, if wantsMove then moveDir else flat / dist)
				if wantsMove then
					local speed = def.Speed * z.SpeedMult
					local lunge = def.Lunge
					if lunge and dist <= lunge.Range and now >= z.NextLunge then
						z.LungeUntil = now + lunge.Duration
						z.NextLunge = now + lunge.Cooldown
					end
					if now < z.LungeUntil then
						speed *= lunge.SpeedMult
					end
					if now < z.FlinchUntil then
						speed *= 0.4
					end
					velocity = Vector2.new(moveDir.X, moveDir.Z) * speed
				end
			end
			if def.Damage > 0 and dist <= reach and math.abs(offset.Y) < 6 * s and now >= z.NextAttack then
				z.NextAttack = now + def.AttackCooldown
				model:SetAttribute("AttackAt", workspace:GetServerTimeNow())
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
