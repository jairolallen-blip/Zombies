-- AirdropService: mid-run supply drops (tunables + rewards: Shared/Config/Airdrops).
-- When a wave starts (GameState Phase = "Wave") it may schedule one crate. The crate falls under a
-- parachute onto a street away from the squad (MapService:GetZombieSpawnPosition), lands with red
-- smoke and a light pillar, and guards rise around it (they count toward the wave). Holding its
-- ProximityPrompt opens it: a random reward for every living squad member within ShareRadius.
-- Timed buffs live on player attributes Buff (reward Id) + BuffUntil (server time), which
-- Client/Controllers/AirdropController shows; CombatService asks :DamageMult(player).
-- Crates and buffs are cleared when the run ends.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Classes = require(Shared.Config.Classes)
local Airdrops = require(Shared.Config.Airdrops)
local GameState = require(Shared.GameState)
local Remotes = require(Shared.Remotes)

local AirdropService = {}
local Services
local crate = nil -- the crate on the field (one at a time)
local dropToken = nil -- the pending drop; replaced or cleared to cancel it

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function activeBuff(player)
	local reward = Airdrops.ById[player:GetAttribute("Buff") or ""]
	if reward and serverNow() < (player:GetAttribute("BuffUntil") or 0) then
		return reward
	end
	return nil
end

function AirdropService:DamageMult(player)
	local buff = activeBuff(player)
	return if buff and buff.Kind == "Damage" then buff.Mult else 1
end

local function baseSpeed(player)
	local class = Classes.List[player:GetAttribute("ClassId")] or Classes.List[Classes.Default]
	return GameConfig.Player.BaseWalkSpeed + class.SpeedBonus
end

local function clearBuff(player)
	if player:GetAttribute("Buff") == nil then
		return
	end
	local reward = Airdrops.ById[player:GetAttribute("Buff")]
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if reward and reward.Kind == "Speed" and humanoid then
		humanoid.WalkSpeed = baseSpeed(player)
	end
	player:SetAttribute("Buff", nil)
	player:SetAttribute("BuffUntil", nil)
end

local function giveBuff(player, reward)
	clearBuff(player)
	local untilTime = serverNow() + reward.Duration
	player:SetAttribute("Buff", reward.Id)
	player:SetAttribute("BuffUntil", untilTime)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if reward.Kind == "Speed" and humanoid then
		humanoid.WalkSpeed = baseSpeed(player) * reward.Mult
		humanoid.Health = humanoid.MaxHealth
	end
	task.delay(reward.Duration, function()
		if player:GetAttribute("BuffUntil") == untilTime then
			clearBuff(player)
		end
	end)
end

local function pickReward()
	local total = 0
	for _, reward in Airdrops.Rewards do
		total += reward.Weight
	end
	local roll = math.random() * total
	for _, reward in Airdrops.Rewards do
		roll -= reward.Weight
		if roll <= 0 then
			return reward
		end
	end
	return Airdrops.Rewards[1]
end

local function buildCrate(position)
	local model = Instance.new("Model")
	model.Name = "SupplyDrop"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- visible from anywhere on the map
	local function add(name, size, cframe, color, material, props)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cframe
		p.Color = color
		p.Material = material or Enum.Material.Metal
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		for key, value in props or {} do
			p[key] = value
		end
		p.Parent = model
		return p
	end
	local base = CFrame.new(position + Vector3.new(0, 1.5, 0))
	local box = add("Crate", Vector3.new(4, 3, 4), base, Color3.fromRGB(78, 88, 54), Enum.Material.WoodPlanks, { CanCollide = true, CanQuery = true })
	for _, y in { -1.1, 1.1 } do
		add("Band", Vector3.new(4.1, 0.35, 4.1), base * CFrame.new(0, y, 0), Color3.fromRGB(40, 42, 40))
	end
	add("Stripe", Vector3.new(4.12, 0.5, 1.2), base * CFrame.new(0, 0, 0), Color3.fromRGB(230, 70, 50), Enum.Material.SmoothPlastic)
	add("Beacon", Vector3.new(0.6, 0.4, 0.6), base * CFrame.new(0, 1.7, 0), Color3.fromRGB(255, 60, 40), Enum.Material.Neon)
	-- light pillar so the squad can find it
	add("Pillar", Vector3.new(1.2, 260, 1.2), base * CFrame.new(0, 131, 0), Color3.fromRGB(255, 80, 60), Enum.Material.Neon, { Transparency = 0.55, CastShadow = false })
	-- parachute (removed on landing)
	local chute = Instance.new("Model")
	chute.Name = "Chute"
	chute.Parent = model
	for i = -3, 3 do
		local a = i * 0.22
		add("Canopy", Vector3.new(1.7, 0.3, 6), base * CFrame.new(math.sin(a) * 9, 7 + math.cos(a) * 9, 0) * CFrame.Angles(0, 0, -a), if i % 2 == 0 then Color3.fromRGB(230, 70, 50) else Color3.fromRGB(235, 230, 220), Enum.Material.Fabric).Parent = chute
	end
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local top = base.Position + Vector3.new(x * 5.5, 14, z * 2.6)
			local corner = base.Position + Vector3.new(x * 2, 1.5, z * 2)
			add("Line", Vector3.new(0.06, 0.06, (top - corner).Magnitude), CFrame.lookAt((top + corner) / 2, top), Color3.fromRGB(210, 210, 200), Enum.Material.SmoothPlastic).Parent = chute
		end
	end
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(255, 60, 40)
	smoke.Opacity = 0.35
	smoke.RiseVelocity = 9
	smoke.Size = 6
	smoke.Enabled = false
	smoke.Parent = box
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 70, 50)
	light.Range = 22
	light.Brightness = 2
	light.Parent = box
	local tag = Instance.new("BillboardGui")
	tag.Name = "Marker"
	tag.AlwaysOnTop = true
	tag.Size = UDim2.fromOffset(160, 44)
	tag.StudsOffset = Vector3.new(0, 5, 0)
	tag.Parent = box
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 110, 80)
	label.TextStrokeTransparency = 0.3
	label.Text = "SUPPLY DROP"
	label.Parent = tag
	model.PrimaryPart = box
	return model, box, smoke, chute
end

function AirdropService:_open(player)
	if not crate or not Services.MatchService:IsAliveInRun(player) then
		return
	end
	local position = crate.PrimaryPart.Position
	crate:Destroy()
	crate = nil
	local reward = pickReward()
	local wave = GameState:GetAttribute("Wave") or 1
	local got = {}
	for _, other in Services.MatchService:GetRunPlayers() do
		local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if Services.MatchService:IsAliveInRun(other) and root and (root.Position - position).Magnitude <= Airdrops.ShareRadius then
			table.insert(got, other.Name)
			if reward.Duration then
				giveBuff(other, reward)
			elseif reward.Kind == "Ult" then
				Services.EconomyService:AddUltCharge(other, reward.Amount)
			elseif reward.Kind == "Cash" then
				Services.EconomyService:AddCash(other, reward.PerWave * wave)
			elseif reward.Kind == "Gems" then
				Services.DataService:AddGems(other, reward.Amount)
			end
			Services.DataService:AddStat(other, "Airdrops")
		end
	end
	local text = string.format("SUPPLY DROP: %s (%s) for %s", reward.Name, reward.Desc, table.concat(got, ", "))
	for _, other in Services.MatchService:GetRunPlayers() do
		Remotes.Notify:FireClient(other, text, "Good")
	end
	Remotes.Effect:FireAllClients("Heal", { Position = position, Radius = Airdrops.ShareRadius })
end

function AirdropService:Drop(wave)
	if crate then
		return
	end
	local ground = Services.MapService:GetZombieSpawnPosition()
	local model, box, smoke, chute = buildCrate(ground)
	crate = model
	local landed = model:GetPivot()
	model:PivotTo(landed + Vector3.new(0, Airdrops.DropHeight, 0))
	model.Parent = Services.CombatService.EffectsFolder
	Services.MatchService:_radio("Airdrop")

	local start = os.clock()
	local fall
	fall = RunService.Heartbeat:Connect(function()
		if crate ~= model then
			fall:Disconnect()
			return
		end
		local u = math.min((os.clock() - start) / Airdrops.FallTime, 1)
		model:PivotTo((landed + Vector3.new(0, Airdrops.DropHeight * (1 - u), 0)) * CFrame.Angles(0, 0, math.sin(os.clock() * 1.3) * 0.06 * (1 - u)))
		if u < 1 then
			return
		end
		fall:Disconnect()
		chute:Destroy()
		smoke.Enabled = true
		local healthMult = 1 + GameConfig.Waves.HealthScalePerWave * (wave - 1)
		for i = 1, Airdrops.Guards + math.floor(wave / Airdrops.GuardsEvery) do
			local angle = i * 2.4
			local spot = ground + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (7 + math.random() * 6)
			Services.ZombieService:SpawnWarned(Services.ZombieService:PickType(wave), spot, healthMult)
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open"
		prompt.ObjectText = "SUPPLY DROP"
		prompt.HoldDuration = Airdrops.OpenTime
		prompt.KeyboardKeyCode = Enum.KeyCode.G -- E is the class ability during a run
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = box
		prompt.Triggered:Connect(function(player)
			self:_open(player)
		end)
	end)
end

function AirdropService:Clear()
	dropToken = nil
	if crate then
		crate:Destroy()
		crate = nil
	end
	for _, player in Players:GetPlayers() do
		clearBuff(player)
	end
end

function AirdropService:Init(services)
	Services = services
end

function AirdropService:Start()
	GameState:GetAttributeChangedSignal("Phase"):Connect(function()
		local phase = GameState:GetAttribute("Phase")
		if phase == "Wave" then
			local wave = GameState:GetAttribute("Wave") or 0
			if wave >= Airdrops.FirstWave and not crate and math.random() < Airdrops.Chance then
				local token = {}
				dropToken = token
				task.delay(Airdrops.Delay[1] + math.random() * (Airdrops.Delay[2] - Airdrops.Delay[1]), function()
					if dropToken == token and GameState:GetAttribute("Phase") == "Wave" then
						self:Drop(wave)
					end
				end)
			end
		elseif phase ~= "Break" then
			self:Clear() -- run over (Results / Lobby / Deploy)
		end
	end)
end

return AirdropService
