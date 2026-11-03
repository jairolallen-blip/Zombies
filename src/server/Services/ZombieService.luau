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
--   ZombieService:PickType(wave, nightmare?) -> typeId (weighted by MinWave/Weight; a Nightmare run picks only
--     the Nightmare types, a normal run never does)
-- Nightmare extras (Config/Zombies): Split (the Husk's halves crawl out in Kill), Wail (_wail: a scream that
-- calls the horde; clients blur and play it in NightmareController), Burrow (_burrow: the Skitter goes under
-- and comes up behind a player).
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
	self:_buildPreviews()
end

-- One still copy of each zombie type in ReplicatedStorage.ZombiePreviews (anchored, non-colliding, facing
-- -Z, feet near y = 0) for the lobby's enemy index and the welcome screen (Client ShopController,
-- WelcomeController). Their clothes are picked at random once per server.
function ZombieService:_buildPreviews()
	local previews = Instance.new("Folder")
	previews.Name = "ZombiePreviews"
	for typeId, def in Zombies.Types do
		local model, _, lv, ao = ZombieModels.Build(typeId, def, CFrame.new(0, 2.5 * (def.Scale or 1), 0))
		lv:Destroy()
		ao:Destroy()
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
			end
		end
		model.Name = typeId
		model.Parent = previews
	end
	previews.Parent = ReplicatedStorage
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

function ZombieService:Spawn(typeId, position, healthMult, riseTime, faceTowards)
	local def = Zombies.Types[typeId]
	assert(def, "Unknown zombie type: " .. tostring(typeId))
	local s = def.Scale or 1
	local cf = CFrame.new(position.X, Services.MapService.GroundY + 2.5 * s + 0.05, position.Z)
		* CFrame.Angles(0, math.random() * math.pi * 2, 0)
	if faceTowards then
		cf = CFrame.lookAt(cf.Position, Vector3.new(faceTowards.X, cf.Position.Y, faceTowards.Z))
	end
	local model, root, lv, ao = ZombieModels.Build(typeId, def, cf)
	if riseTime then -- start buried and hunched forward: it claws its way up and straightens (the client's "Rise"
		-- pose; GroundFxController churns up the dirt)
		root.Anchored = true
		root.CFrame = (cf - Vector3.new(0, 5 * s, 0)) * CFrame.Angles(-0.7, 0, 0)
		model:SetAttribute("Pose", "Rise")
		model:SetAttribute("PoseAt", workspace:GetServerTimeNow())
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
				model:SetAttribute("Pose", nil)
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
	if z.MarkedUntil and os.clock() < z.MarkedUntil then
		amount *= z.MarkMult
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

-- Scout's Hunter's Mark: takes `mult` x damage for `duration` seconds, outlined red meanwhile
-- (shortcut: Roblox draws at most 31 Highlights per client, so a huge horde shows only some outlines)
function ZombieService:Mark(model, duration, mult)
	local z = alive[model]
	if not z or z.Dead then
		return
	end
	local untilTime = os.clock() + duration
	z.MarkedUntil, z.MarkMult = untilTime, mult
	local glow = model:FindFirstChild("Marked") or Instance.new("Highlight")
	glow.Name = "Marked"
	glow.FillColor = Color3.fromRGB(255, 60, 40)
	glow.FillTransparency = 0.75
	glow.OutlineColor = Color3.fromRGB(255, 90, 60)
	glow.Parent = model
	task.delay(duration, function()
		if z.MarkedUntil == untilTime and glow.Parent then
			glow:Destroy()
		end
	end)
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
	if def.Death then -- a boss with a death scene: its body stays for the clients to burst (MatchService:_bossDeath)
		z.Corpse = model:Clone()
	end
	model:Destroy()
	if def.Explode then
		local e = def.Explode
		local playerDamage = if attacker then e.Damage * e.ShotPlayerDamageMult else e.Damage
		Services.CombatService:Explode(position, e.Radius, e.Damage, attacker, { PlayerDamage = playerDamage })
	end
	if def.Split then -- a Husk: its halves crawl out where it fell, as tough as it was for this wave
		for i = 1, def.Split.Count do
			local side = (i - (def.Split.Count + 1) / 2) * 3
			self:Spawn(def.Split.Into, position + Vector3.new(side, 0, 0), z.MaxHealth / def.Health)
		end
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

function ZombieService:PickType(wave, nightmare)
	local pool, total = {}, 0
	for typeId, def in Zombies.Types do
		if not def.Boss and (def.Nightmare == true) == (nightmare == true) and (def.MinWave or 1) <= wave and (def.Weight or 0) > 0 then
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

-- Surround slot around `target` for a zombie arriving from angle `approach`: the least-taken of 8 sides
-- (preferring its own), so a chasing pack spreads around the player instead of piling onto one side. One
-- zombie per side in the inner ring; later arrivals take the rings behind it (SlotRing 1, 2: 4 and 8 studs
-- further out) and wait their turn.
local function pickSlot(z, target, approach)
	local best, bestScore, bestTaken = approach, math.huge, 0
	for k = -3, 4 do
		local a = approach + k * math.pi / 4
		local taken = 0
		for _, other in alive do
			if other ~= z and other.Target == target and other.Slot then
				if math.abs((other.Slot - a + math.pi) % (2 * math.pi) - math.pi) < math.pi / 6 then
					taken += 1
				end
			end
		end
		local score = taken + math.abs(k) * 0.3
		if score < bestScore then
			best, bestScore, bestTaken = a, score, taken
		end
	end
	z.SlotRing = math.min(bestTaken, 2)
	return best + (math.random() - 0.5) * 0.3
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
		-- crowd check: a push away from zombies right next to it (Sep, added to its steering in _step), and one
		-- of a clump of 3+ swings wide to come at the player from another side (Flank); Skitters burrow instead
		-- and the boss stays itself
		if not z.Def.Burrow and not z.Def.Boss then
			local crowd, sep = 0, Vector3.zero
			for _, other in alive do
				if other ~= z then
					local off = root.Position - other.Root.Position
					off = Vector3.new(off.X, 0, off.Z)
					local d = off.Magnitude
					if d < 5 * s then
						crowd += 1
					end
					if d > 0.05 and d < 4 * s then
						sep += off / d * (1 - d / (4 * s))
					end
				end
			end
			z.Sep = sep
			if crowd >= 3 then
				z.Flank = z.Flank or (if math.random() < 0.5 then -1 else 1) * (0.7 + math.random() * 0.6)
			elseif crowd == 0 then
				z.Flank = nil
			end
		end
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
	z.NextSpecial = now + slam.Windup + (z.Def.SpecialGap or 0)
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

-- red telegraph part flat on the ground (removed by the caller)
local function telegraph(size, cframe)
	local p = Instance.new("Part")
	p.Name = "BossTelegraph"
	p.Size = size
	p.CFrame = cframe
	p.Color = Color3.fromRGB(255, 50, 40)
	p.Material = Enum.Material.Neon
	p.Transparency = 0.5
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = Services.CombatService.EffectsFolder
	return p
end

local function specialCooldown(z, seconds)
	return seconds * (if z.Enraged then z.Def.Enrage.SlamCooldownMult else 1)
end

-- players own their characters' physics, so their client applies the shove (BossController)
local function knock(root, from, power)
	local player = Players:GetPlayerFromCharacter(root.Parent)
	local away = Vector3.new(root.Position.X - from.X, 0, root.Position.Z - from.Z)
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
	if player then
		Remotes.Effect:FireClient(player, "BossKnock", { Velocity = away * power + Vector3.new(0, power * 0.45, 0) })
	end
end

-- Charge: stand still behind a red lane for Windup, then run it at Speed (see _step), hitting
-- each player in the lane once.
local function doCharge(z, now, targetPos)
	local c = z.Def.Charge
	z.Slamming = true -- busy: no steering or other attacks
	z.NextCharge = now + specialCooldown(z, c.Cooldown)
	z.NextSpecial = now + c.Windup + z.Def.SpecialGap
	local from = z.Root.Position
	local dir = Vector3.new(targetPos.X - from.X, 0, targetPos.Z - from.Z).Unit
	z.AO.CFrame = CFrame.lookAt(Vector3.zero, dir)
	local groundY = Services.MapService.GroundY
	local lane = telegraph(Vector3.new(c.Width, 0.2, c.Distance), CFrame.lookAt(Vector3.new(from.X, groundY + 0.1, from.Z), Vector3.new(from.X + dir.X, groundY + 0.1, from.Z + dir.Z)) * CFrame.new(0, 0, -c.Distance / 2))
	Remotes.Effect:FireAllClients("BossCharge", { Position = from })
	task.delay(c.Windup, function()
		lane:Destroy()
		z.Slamming = false
		if z.Dead then
			return
		end
		z.ChargeDir = dir
		z.ChargeUntil = os.clock() + c.Distance / c.Speed
		z.ChargeHit = {}
	end)
end

-- Leap: crouch over a red ring at the target's spot, arc through the air onto it, shockwave on landing.
local function doLeap(z, now, targetPos)
	local l = z.Def.Leap
	z.Slamming = true
	z.NextLeap = now + specialCooldown(z, l.Cooldown)
	z.NextSpecial = now + l.Windup + l.AirTime + z.Def.SpecialGap
	local groundY = Services.MapService.GroundY
	local landing = Vector3.new(targetPos.X, groundY, targetPos.Z)
	local ring = telegraph(Vector3.new(0.2, l.Radius * 2, l.Radius * 2), CFrame.new(landing + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)))
	ring.Shape = Enum.PartType.Cylinder
	Remotes.Effect:FireAllClients("BossLeap", { Position = z.Root.Position, Landing = landing })
	task.delay(l.Windup, function()
		local root = z.Root
		if z.Dead or not root.Parent then
			ring:Destroy()
			z.Slamming = false
			return
		end
		local start = root.Position
		local rootHeight = start.Y - groundY
		local flat = Vector3.new(landing.X - start.X, 0, landing.Z - start.Z)
		local face = if flat.Magnitude > 0.1 then flat.Unit else Vector3.zAxis
		root.Anchored = true
		local t0 = os.clock()
		local fly
		fly = RunService.Heartbeat:Connect(function()
			local u = math.min((os.clock() - t0) / l.AirTime, 1)
			local pos = start:Lerp(landing + Vector3.new(0, rootHeight, 0), u) + Vector3.new(0, l.Height * 4 * u * (1 - u), 0)
			if root.Parent then
				root.CFrame = CFrame.lookAt(pos, pos + face)
			end
			if u < 1 then
				return
			end
			fly:Disconnect()
			ring:Destroy()
			z.Slamming = false
			if z.Dead or not root.Parent then
				return
			end
			root.Anchored = false
			root:SetNetworkOwner(nil)
			Remotes.Effect:FireAllClients("Shockwave", { Position = landing, Radius = l.Radius })
			for _, player in Services.MatchService:GetRunPlayers() do
				local proot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if proot and Util.FlatDistance(proot.Position, landing) <= l.Radius then
					Services.CombatService:DamagePlayer(player, l.Damage)
					knock(proot, landing, 55)
				end
			end
		end)
	end)
end

-- Skitter burrow (Def.Burrow): it sinks into the street (out of reach of bullets) and stays under, then a
-- red warning circle opens behind the nearest player (or beside them, if that spot is blocked) and it rises
-- out of it there, facing them.
function ZombieService:_burrow(z)
	local b = z.Def.Burrow
	local W = GameConfig.Waves
	local s = z.Def.Scale or 1
	local root = z.Root
	local groundY = Services.MapService.GroundY
	z.Burrowed = true
	z.StunnedUntil = math.huge -- no moves or attacks while it travels underground
	z.LV.Enabled = false
	root.Anchored = true
	-- it pitches head first into the street, digging (the client's "Burrow" pose; GroundFxController throws the dirt)
	Remotes.Effect:FireAllClients("Burrow", { Position = Vector3.new(root.Position.X, groundY, root.Position.Z), Radius = 2.4 * s })
	z.Model:SetAttribute("Pose", "Burrow")
	z.Model:SetAttribute("PoseAt", workspace:GetServerTimeNow())
	TweenService:Create(root, TweenInfo.new(b.Down, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = (root.CFrame - Vector3.new(0, 5 * s, 0)) * CFrame.Angles(-0.9, 0, 0) }):Play()
	task.delay(b.Down + b.Under, function()
		if z.Dead then
			return
		end
		local prey = findTarget(root.Position)
		local spot = root.Position
		if prey then
			local back = -prey.CFrame.LookVector * Vector3.new(1, 0, 1)
			back = if back.Magnitude > 0.1 then back.Unit else Vector3.xAxis
			for _, turn in { 0, 0.6, -0.6, 1.2, -1.2, math.pi } do
				local try = prey.Position + rotateFlat(back, turn) * b.Behind
				if NavGrid.IsWalkable(try) then
					spot = try
					break
				end
			end
		end
		Remotes.Effect:FireAllClients("SpawnWarning", { Position = Vector3.new(spot.X, groundY, spot.Z), Radius = 2.4 * s, Time = W.SpawnWarning })
		task.delay(W.SpawnWarning, function()
			if z.Dead or not root.Parent then
				return
			end
			local up = CFrame.new(spot.X, groundY + 2.5 * s + 0.05, spot.Z)
			if prey and prey.Parent then
				up = CFrame.lookAt(up.Position, Vector3.new(prey.Position.X, up.Position.Y, prey.Position.Z))
			end
			root.CFrame = (up - Vector3.new(0, 5 * s, 0)) * CFrame.Angles(-0.7, 0, 0)
			z.Model:SetAttribute("Pose", "Rise")
			z.Model:SetAttribute("PoseAt", workspace:GetServerTimeNow())
			local rise = TweenService:Create(root, TweenInfo.new(W.RiseTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = up })
			rise.Completed:Connect(function()
				if root.Parent and not z.Dead then
					root.Anchored = false
					root:SetNetworkOwner(nil)
					z.Burrowed = false
					z.Model:SetAttribute("Pose", nil)
					z.StunnedUntil = 0
					z.LastPos = root.Position
					z.NextBurrow = os.clock() + b.Cooldown
				end
			end)
			rise:Play()
		end)
	end)
end

-- Bloom Mother spore volley (Def.Spores; see Config/Zombies BloomMother). Clients draw the pods and clouds
-- (BossController "SporeVolley"); the red circles and the damage are here.
function ZombieService:_spores(z, now)
	local sp = z.Def.Spores
	z.NextSpores = now + specialCooldown(z, sp.Cooldown)
	z.NextSpecial = now + sp.Windup + z.Def.SpecialGap
	z.StunnedUntil = math.max(z.StunnedUntil, now + sp.Windup)
	local targets = {}
	for _, player in Services.MatchService:GetRunPlayers() do
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if r and Util.FlatDistance(r.Position, z.Root.Position) <= sp.Range then
			table.insert(targets, r)
		end
	end
	if #targets == 0 then
		return
	end
	local groundY = Services.MapService.GroundY
	local landings, rings = {}, {}
	for i = 1, if z.Enraged then sp.EnragedCount else sp.Count do
		local r = targets[(i - 1) % #targets + 1]
		-- the first pod at each player lands where they're heading; the rest scatter around them
		local lead = r.AssemblyLinearVelocity * Vector3.new(1, 0, 1) * (sp.Windup + sp.Flight) * 0.5
		local off = if i <= #targets then Vector3.zero else Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 2 * sp.Spread
		local spot = r.Position + lead + off
		spot = Vector3.new(spot.X, groundY, spot.Z)
		table.insert(landings, spot)
		local ring = telegraph(Vector3.new(0.2, sp.Radius * 2, sp.Radius * 2), CFrame.new(spot + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)))
		ring.Shape = Enum.PartType.Cylinder
		table.insert(rings, ring)
	end
	Remotes.Effect:FireAllClients("SporeVolley", { Model = z.Model, Landings = landings, Windup = sp.Windup, Flight = sp.Flight, Radius = sp.Radius, Cloud = sp.Cloud })
	local gen = generation
	task.delay(sp.Windup + sp.Flight, function()
		for _, ring in rings do
			ring:Destroy()
		end
		local function hurt(damage)
			for _, player in Services.MatchService:GetRunPlayers() do
				local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				for _, spot in landings do
					if r and Util.FlatDistance(r.Position, spot) <= sp.Radius then
						Services.CombatService:DamagePlayer(player, damage)
					end
				end
			end
		end
		hurt(sp.Damage)
		for _ = 1, sp.Cloud * 2 do -- the poison clouds (pods keep working after it dies, until the run clears)
			task.wait(0.5)
			if gen ~= generation then
				return
			end
			hurt(sp.CloudDamage)
		end
	end)
end

-- Bloom Burst (Def.Burst): it roots itself and swells for Windup inside a red ring (BossController draws the
-- danger filling in and the countdown), then everyone still inside takes Damage and is thrown clear, and the
-- spore field it leaves (b.Field) hurts anyone in it until it thins out or the boss dies.
function ZombieService:_bloomBurst(z, now)
	local b = z.Def.Burst
	z.Slamming = true
	z.NextBurst = now + b.Windup + specialCooldown(z, b.Cooldown)
	z.NextSpecial = now + b.Windup + z.Def.SpecialGap
	local center = Vector3.new(z.Root.Position.X, Services.MapService.GroundY, z.Root.Position.Z)
	local ring = telegraph(Vector3.new(0.2, b.Radius * 2, b.Radius * 2), CFrame.new(center + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)))
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.75
	Remotes.Effect:FireAllClients("BloomBurst", { Model = z.Model, Position = center, Radius = b.Radius, Windup = b.Windup })
	task.delay(b.Windup, function()
		ring:Destroy()
		z.Slamming = false
		if z.Dead then
			return
		end
		Remotes.Effect:FireAllClients("BloomBlast", { Position = center, Radius = b.Radius, Field = b.Field })
		for _, player in Services.MatchService:GetRunPlayers() do
			local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if r and Util.FlatDistance(r.Position, center) <= b.Radius then
				Services.CombatService:DamagePlayer(player, b.Damage)
				knock(r, center, b.Knockback)
			end
		end
		local f, gen = b.Field, generation
		for _ = 1, if f then math.floor(f.Time / f.Every) else 0 do
			task.wait(f.Every)
			if gen ~= generation then
				return
			end
			for _, player in Services.MatchService:GetRunPlayers() do
				local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if r and Util.FlatDistance(r.Position, center) <= f.Radius then
					Services.CombatService:DamagePlayer(player, f.Damage)
				end
			end
		end
	end)
end

-- The Nightmare boss fell: everything it grew dies with it (no rewards) and nothing more rises (MatchService)
function ZombieService:Collapse()
	generation += 1
	pendingCount = 0
	for model, z in alive do
		Remotes.Effect:FireAllClients("ZombieDeath", { Position = z.Root.Position, Color = z.Def.Look.Skin, Scale = z.Def.Scale or 1 })
		self:Remove(model)
	end
end

-- Wailer scream (Def.Wail): it stands still and screams for Windup ("WailStart": clients play the scream),
-- then players within Radius get their sight blurred ("Wail") and every zombie within Pull of it rushes the
-- nearest player for RushTime.
function ZombieService:_wail(z)
	local w = z.Def.Wail
	z.NextWail = os.clock() + w.Cooldown
	z.StunnedUntil = math.max(z.StunnedUntil, os.clock() + w.Windup)
	-- it throws its head back, arms up and shaking (the client's "Scream" pose)
	z.Model:SetAttribute("Pose", "Scream")
	z.Model:SetAttribute("PoseAt", workspace:GetServerTimeNow())
	z.AO.CFrame = z.AO.CFrame * CFrame.Angles(0.3, 0, 0)
	Remotes.Effect:FireAllClients("WailStart", { Model = z.Model, Time = w.Windup })
	task.delay(w.Windup + 0.4, function()
		if not z.Dead then
			z.Model:SetAttribute("Pose", nil)
		end
	end)
	task.delay(w.Windup, function()
		if z.Dead then
			return
		end
		local origin = z.Root.Position
		local prey = findTarget(origin)
		Remotes.Effect:FireAllClients("Wail", { Position = origin, Radius = w.Radius, Blur = w.Blur, Stun = w.Stun, Model = z.Model })
		if not prey then
			return
		end
		local now = os.clock()
		for _, other in alive do
			if other ~= z and not other.Def.Boss and (other.Root.Position - origin).Magnitude <= w.Pull then
				other.Target = prey
				other.NextRetarget = now + w.RushTime
				other.RushUntil, other.RushMult = now + w.RushTime, w.RushMult
			end
		end
	end)
end

-- Keep a zombie standing still (no moves, no attacks) for `seconds` (the boss during its intro)
function ZombieService:Hold(model, seconds)
	local z = alive[model]
	if z then
		z.StunnedUntil = math.max(z.StunnedUntil, os.clock() + seconds)
	end
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
		if z.ChargeUntil then -- mid-charge: run the lane, flatten whoever is in it (once each)
			if now < z.ChargeUntil then
				local c = def.Charge
				velocity = Vector2.new(z.ChargeDir.X, z.ChargeDir.Z) * c.Speed
				for _, player in Services.MatchService:GetRunPlayers() do
					local proot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					if proot and not z.ChargeHit[player] and Util.FlatDistance(proot.Position, root.Position) <= c.Width * 0.5 + 2 then
						z.ChargeHit[player] = true
						Services.CombatService:DamagePlayer(player, c.Damage)
						knock(proot, root.Position, c.Knockback)
					end
				end
				z.LV.Enabled = true
				z.LV.PlaneVelocity = velocity
				continue
			end
			z.ChargeUntil = nil
		end
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
					z.Slot = z.Slot or pickSlot(z, target, math.atan2(-dir.Z, -dir.X))
					goal = target.Position + Vector3.new(math.cos(z.Slot), 0, math.sin(z.Slot)) * (z.SlotRing or 0) * 4 + Vector3.new(math.cos(z.Slot), 0, math.sin(z.Slot)) * reach * 0.7
					local toGoal = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z)
					goalDist = toGoal.Magnitude
					if goalDist > 0.05 then
						dir = toGoal / goalDist
					end
				elseif dist > SURROUND_RANGE * 1.5 then
					z.Slot = nil -- lost them: pick a fresh slot next time
				end
				if z.Flank and dist >= 8 and not def.Boss then
					-- spread out: head for a point off to the player's side instead of following the blob
					goal = target.Position + rotateFlat(-dir, z.Flank) * math.min(dist * 0.6, 24)
					local toGoal = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z)
					goalDist = toGoal.Magnitude
					if goalDist > 0.05 then
						dir = toGoal / goalDist
					end
				end
				local wantsMove = dist > reach * 0.6 and goalDist > 0.6
				local moveDir = if wantsMove then navigate(z, dir, goalDist, goal, now) else flat / dist
				local spread = if wantsMove and z.Sep then moveDir + z.Sep * 0.9 else nil
				if spread and spread.Magnitude > 0.2 then
					moveDir = spread.Unit -- ease away from the zombies pressing in on it
				end
				z.AO.CFrame = CFrame.lookAt(Vector3.zero, if wantsMove then moveDir else flat / dist)
				if wantsMove then
					local speed = def.Speed * z.SpeedMult
					if now < (z.RushUntil or 0) then
						speed *= z.RushMult -- called in by a Wailer's scream (_wail)
					end
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
			if def.Wail then
				z.NextWail = z.NextWail or now + 2
				if now >= z.NextWail and dist <= def.Wail.Range then
					self:_wail(z)
				end
			end
			if def.Burrow and not z.Burrowed then
				z.NextBurrow = z.NextBurrow or now + 3
				if now >= z.NextBurrow and dist >= def.Burrow.MinRange then
					self:_burrow(z)
				end
			end
			if def.Slam and now >= z.NextSlam and dist <= def.Slam.TriggerRange and now >= (z.NextSpecial or 0) then
				doSlam(z, now)
			elseif def.Boss and now >= (z.NextSpecial or 0) then
				z.NextCharge = z.NextCharge or now + 3
				z.NextLeap = z.NextLeap or now + 6
				z.NextSpores = z.NextSpores or now + 3
				z.NextBurst = z.NextBurst or now + (if def.Burst then def.Burst.First else 0)
				if def.Burst and now >= z.NextBurst and dist <= def.Burst.Radius then
					self:_bloomBurst(z, now)
				elseif def.Spores and now >= z.NextSpores and dist <= def.Spores.Range then
					self:_spores(z, now)
				elseif def.Charge and now >= z.NextCharge and dist >= def.Charge.MinRange and dist <= def.Charge.MaxRange and z.HasLOS then
					doCharge(z, now, target.Position)
				elseif def.Leap and now >= z.NextLeap and dist >= def.Leap.MinRange then
					doLeap(z, now, target.Position)
				end
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
