-- GroundFxController: disturbed earth where zombies break through the street (local only, nothing replicates).
--   "SpawnWarning" (ZombieService:SpawnWarned, every rising zombie; the red circle itself is EffectsController's):
--     when the zombie breaks through, a dark patch of churned dirt, a ring of broken rubble around the hole
--     and a burst of dust, with a second puff as it hauls itself up; it all settles and fades after a few seconds
--   "Burrow" (ZombieService:_burrow, a Skitter going under): clods of dirt thrown up, dust and the same patch
-- The zombie's own crawl (reaching up and clawing) is the "Rise" / "Burrow" pose in EffectsController.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local GameConfig = require(Shared.Config.GameConfig)

local GroundFxController = {}

local DIRT = { Color3.fromRGB(58, 44, 34), Color3.fromRGB(74, 58, 44), Color3.fromRGB(46, 36, 30) }
local LINGER = 4 -- seconds the patch and rubble stay before they settle away

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		p[key] = value
	end
	p.Parent = workspace.CurrentCamera
	return p
end

local function dust(position, radius, amount)
	local holder = part({ Size = Vector3.new(radius * 2, 0.2, radius * 2), CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)), Transparency = 1 })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(92, 76, 60))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 4.5) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.8, 1.6)
	e.Speed = NumberRange.new(3, 9)
	e.SpreadAngle = Vector2.new(70, 70)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -2, 0)
	e.Drag = 2
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Rotation = NumberRange.new(0, 360)
	e.LightInfluence = 1
	e.Enabled = false
	e.Parent = holder
	e:Emit(amount)
	Debris:AddItem(holder, 2)
end

-- clods of dirt and broken asphalt thrown up out of the hole
local function clods(position, radius, count, force)
	for _ = 1, count do
		local c = part({
			Size = Vector3.one * (0.25 + math.random() * 0.45),
			CFrame = CFrame.new(position + Vector3.new((math.random() - 0.5) * radius, 0.4, (math.random() - 0.5) * radius)) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
			Color = DIRT[math.random(#DIRT)],
			Material = if math.random() < 0.7 then Enum.Material.Ground else Enum.Material.Asphalt,
			Anchored = false,
			CanCollide = true,
		})
		c.CollisionGroup = "Zombies" -- never trips the players
		c.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 16, force * (0.7 + math.random() * 0.5), (math.random() - 0.5) * 16)
		Debris:AddItem(c, 1.4)
	end
end

-- a dark patch of churned dirt with broken rubble around its edge; settles into the street and fades
local function patch(position, radius)
	local ground = position + Vector3.new(0, 0.05, 0)
	local d = radius * 2.4
	local p = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, d, d), CFrame = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90)), Color = DIRT[3], Material = Enum.Material.Ground, Transparency = 0.05 })
	local inner = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, d * 0.55, d * 0.55), CFrame = CFrame.new(ground + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(30, 22, 18), Material = Enum.Material.Ground })
	local pieces = { p, inner }
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2 + math.random() * 0.5
		local r = radius * (1 + math.random() * 0.25)
		local size = Vector3.new(0.5 + math.random() * 0.7, 0.25 + math.random() * 0.35, 0.4 + math.random() * 0.6)
		table.insert(pieces, part({
			Size = size,
			CFrame = CFrame.new(ground + Vector3.new(math.cos(a) * r, size.Y * 0.3, math.sin(a) * r)) * CFrame.Angles((math.random() - 0.5) * 0.8, a, (math.random() - 0.5) * 0.8),
			Color = if i % 3 == 0 then Color3.fromRGB(70, 70, 74) else DIRT[math.random(#DIRT)],
			Material = if i % 3 == 0 then Enum.Material.Asphalt else Enum.Material.Ground,
		}))
	end
	task.delay(LINGER, function()
		for _, piece in pieces do
			TweenService:Create(piece, TweenInfo.new(1.5), { Transparency = 1, CFrame = piece.CFrame - Vector3.new(0, 0.3, 0) }):Play()
			Debris:AddItem(piece, 1.6)
		end
	end)
end

function GroundFxController:Start()
	local rise = GameConfig.Waves.RiseTime
	Remotes.Effect.OnClientEvent:Connect(function(kind, data)
		if kind == "SpawnWarning" then
			task.delay(data.Time, function() -- the zombie breaks through
				patch(data.Position, data.Radius)
				dust(data.Position, data.Radius, 22)
				clods(data.Position, data.Radius, 5, 14)
				task.delay(rise * 0.5, dust, data.Position, data.Radius, 10) -- hauling itself up
			end)
		elseif kind == "Burrow" then
			patch(data.Position, data.Radius)
			dust(data.Position, data.Radius, 26)
			clods(data.Position, data.Radius, 9, 20)
		end
	end)
end

return GroundFxController
