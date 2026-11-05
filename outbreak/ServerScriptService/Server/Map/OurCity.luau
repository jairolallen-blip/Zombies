-- OurCity: builds our version's arena, an overgrown apocalyptic city at sunset (vault: City Map.md).
-- BAKED into Workspace.OurMap.Arena in Edit mode so it can be hand-edited afterwards:
--   local m = game.ServerScriptService.Server.Map.OurCity
--   local c = m:Clone(); c.Parent = m.Parent; require(c).Build(); c:Destroy()
--
-- The whole layout is the LAYOUT tile plan below (TILE studs per character, north = -Z):
--   # building   . road   S city square   P park   A alley   L parking lot   M market
-- Rules that keep the horde flowing (zombies use Map/NavGrid): the floor is perfectly flat (paint,
-- no steps), walkable gaps are >= 1 tile wide, every side area has 2+ exits, and decorative bits
-- (facades, canopies, foliage) are CanCollide = false so only real cover blocks the nav grid.
-- Parts named "PlayerSpawn" / "ZombieSpawn" / "BossSpawn" are read by MapService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local OurCity = {}

local TILE = 12
local GROUND_Y = 1 -- top of the floor (matches MapService.GroundY)
local LAYOUT = {
	"#######################",
	"#.....................#",
	"#.....................#",
	"#..####PPP...###A###..#",
	"#..####PPP...###A###..#",
	"#..PPPPPPP...AAAAAAA..#",
	"#..PPPPPPP...###A###..#",
	"#..PP##SSSSSSSSSA###..#",
	"#..PP##SSSSSSSSSA###..#",
	"#..PP##SSSSSSSSSA###..#",
	"#......SSSSSSSSS......#",
	"#......SSSSSSSSS......#",
	"#......SSSSSSSSS......#",
	"#..##MMSSSSSSSSSLL##..#",
	"#..##MMSSSSSSSSSLL##..#",
	"#..##MMSSSSSSSSSLL##..#",
	"#..##MMMMM...##LLLLL..#",
	"#..##MMMMM...##LLLLL..#",
	"#..MMMM###...##LLLLL..#",
	"#..MMMM###...##LLLLL..#",
	"#.....................#",
	"#.....................#",
	"#######################",
}
local N = #LAYOUT
local HALF = N * TILE / 2
local MID = (N - 1) / 2 -- centre tile index

-- zombie spawn markers (tile i, j): ring road corners/midpoints and the side areas
local ZOMBIE_TILES = {
	{ 2, 2 }, { 20, 2 }, { 2, 20 }, { 20, 20 }, { 11, 1 }, { 1, 11 }, { 21, 11 }, { 11, 21 },
	{ 16, 4 }, { 5, 5 }, { 17, 18 }, { 4, 18 },
}

local C = {
	Asphalt = Color3.fromRGB(52, 52, 55),
	Lot = Color3.fromRGB(64, 64, 66),
	Sidewalk = Color3.fromRGB(122, 116, 106),
	SquareA = Color3.fromRGB(150, 142, 128),
	SquareB = Color3.fromRGB(136, 128, 116),
	Alley = Color3.fromRGB(88, 84, 78),
	Market = Color3.fromRGB(128, 100, 80),
	Grass = Color3.fromRGB(92, 100, 56),
	Line = Color3.fromRGB(200, 170, 70),
	White = Color3.fromRGB(215, 212, 200),
	Walls = {
		Color3.fromRGB(122, 64, 48), Color3.fromRGB(104, 56, 44), Color3.fromRGB(140, 84, 60), -- brick
		Color3.fromRGB(176, 160, 128), Color3.fromRGB(150, 146, 136), Color3.fromRGB(120, 116, 108), -- concrete
		Color3.fromRGB(168, 140, 96),
	},
	Window = Color3.fromRGB(26, 24, 24),
	Lit = Color3.fromRGB(255, 176, 90),
	Board = Color3.fromRGB(112, 86, 58),
	Shutter = Color3.fromRGB(112, 112, 106),
	Awnings = { Color3.fromRGB(120, 40, 36), Color3.fromRGB(46, 70, 96), Color3.fromRGB(60, 88, 54), Color3.fromRGB(150, 120, 60) },
	Metal = Color3.fromRGB(58, 58, 60),
	Concrete = Color3.fromRGB(150, 146, 138),
	Leaves = { Color3.fromRGB(64, 84, 42), Color3.fromRGB(80, 96, 48), Color3.fromRGB(96, 98, 50) },
	Vine = Color3.fromRGB(58, 82, 40),
	Cars = { Color3.fromRGB(70, 86, 110), Color3.fromRGB(110, 46, 40), Color3.fromRGB(150, 150, 140), Color3.fromRGB(64, 70, 60), Color3.fromRGB(40, 40, 44) },
	Taxi = Color3.fromRGB(214, 168, 40),
	Tire = Color3.fromRGB(22, 22, 22),
	Wire = Color3.fromRGB(20, 20, 20),
	Lamp = Color3.fromRGB(255, 200, 130),
}

local origin -- arena centre (Vector3), set by Build
local rng

local function cell(i, j)
	if i < 0 or j < 0 or i >= N or j >= N then
		return "#"
	end
	return LAYOUT[j + 1]:sub(i + 1, i + 1)
end

-- world X/Z of a tile edge (i or j = tile index; fractional = inside the tile)
local function wx(i)
	return origin.X - HALF + i * TILE
end
local function wz(j)
	return origin.Z - HALF + j * TILE
end

-- CFrame at arena-relative x/z and ABSOLUTE y
local function at(x, y, z)
	return CFrame.new(origin.X + x, y, origin.Z + z)
end

local function part(parent, name, size, cframe, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props or {} do
		p[key] = value
	end
	p.Parent = parent
	return p
end

local DECOR = { CanCollide = false, CanTouch = false, CastShadow = true }
local PAINT = { CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false }

local function decor(parent, name, size, cframe, color, material)
	return part(parent, name, size, cframe, color, material, DECOR)
end

-- Vertical-axis cylinder (Roblox cylinders run along X, so roll it 90 degrees)
local function cylinder(parent, name, height, diameter, cframe, color, material, props)
	local p = part(parent, name, Vector3.new(height, diameter, diameter), cframe * CFrame.Angles(0, 0, math.rad(90)), color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(parent, name, diameter, cframe, color, material)
	local p = decor(parent, name, Vector3.one * diameter, cframe, color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

-- Zombie spawn pads keep a clear radius: props asking for a spot inside it are skipped.
local SPAWN_CLEARANCE = 13
local function nearZombieSpawn(x, z) -- arena-relative
	for _, t in ZOMBIE_TILES do
		local sx, sz = (t[1] + 0.5) * TILE - HALF, (t[2] + 0.5) * TILE - HALF
		if math.abs(x - sx) < SPAWN_CLEARANCE and math.abs(z - sz) < SPAWN_CLEARANCE then
			return true
		end
	end
	return false
end

-- Greedy-merge same-character tiles into rectangles {c, i0, j0, i1, j1}.
local function rects(match)
	local used, out = {}, {}
	for j = 0, N - 1 do
		for i = 0, N - 1 do
			local c = cell(i, j)
			if not used[j * N + i] and match(c) then
				local i1 = i
				while i1 + 1 < N and not used[j * N + i1 + 1] and cell(i1 + 1, j) == c do
					i1 += 1
				end
				local j1 = j
				while j1 + 1 < N do
					local ok = true
					for k = i, i1 do
						if used[(j1 + 1) * N + k] or cell(k, j1 + 1) ~= c then
							ok = false
							break
						end
					end
					if not ok then
						break
					end
					j1 += 1
				end
				for jj = j, j1 do
					for ii = i, i1 do
						used[jj * N + ii] = true
					end
				end
				table.insert(out, { c = c, i0 = i, j0 = j, i1 = i1, j1 = j1 })
			end
		end
	end
	return out
end

local function rectCenter(r, y)
	return CFrame.new((wx(r.i0) + wx(r.i1 + 1)) / 2, y, (wz(r.j0) + wz(r.j1 + 1)) / 2)
end

local function rectSize(r, h)
	return Vector3.new((r.i1 - r.i0 + 1) * TILE, h, (r.j1 - r.j0 + 1) * TILE)
end

-- Ground ------------------------------------------------------------------------------------------

local FLOORS = {
	P = { C.Grass, Enum.Material.Grass },
	A = { C.Alley, Enum.Material.Concrete },
	L = { C.Lot, Enum.Material.Asphalt },
	M = { C.Market, Enum.Material.Pavement },
}

local function buildGround(parent)
	local ground = model(parent, "Ground")
	part(ground, "Base", Vector3.new(N * TILE + 8, 2, N * TILE + 8), at(0, GROUND_Y - 1, 0), C.Asphalt, Enum.Material.Asphalt)
	for _, r in rects(function(c)
		return FLOORS[c] ~= nil
	end) do
		local f = FLOORS[r.c]
		part(ground, "Floor" .. r.c, rectSize(r, 0.1), rectCenter(r, GROUND_Y + 0.05), f[1], f[2], PAINT)
	end
	-- city square: checkered concrete slabs + a darker border
	for j = 0, N - 1 do
		for i = 0, N - 1 do
			if cell(i, j) == "S" then
				local shade = if (i + j) % 2 == 0 then C.SquareA else C.SquareB
				part(ground, "SquareSlab", Vector3.new(TILE - 0.3, 0.12, TILE - 0.3), CFrame.new(wx(i + 0.5), GROUND_Y + 0.06, wz(j + 0.5)), shade, Enum.Material.Concrete, PAINT)
			end
		end
	end
	-- sidewalks along buildings that face a road
	for j = 0, N - 1 do
		for i = 0, N - 1 do
			if cell(i, j) == "." then
				for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					if cell(i + d[1], j + d[2]) == "#" then
						local cx, cz = wx(i + 0.5) + d[1] * (TILE / 2 - 2), wz(j + 0.5) + d[2] * (TILE / 2 - 2)
						local size = if d[1] ~= 0 then Vector3.new(4, 0.14, TILE) else Vector3.new(TILE, 0.14, 4)
						part(ground, "Sidewalk", size, CFrame.new(cx, GROUND_Y + 0.07, cz), C.Sidewalk, Enum.Material.Concrete, PAINT)
					end
				end
			end
		end
	end
	-- faded dashed centre lines: main streets and the ring road
	local function dash(x, z, alongX)
		part(ground, "RoadLine", if alongX then Vector3.new(6, 0.05, 0.5) else Vector3.new(0.5, 0.05, 6), CFrame.new(x, GROUND_Y + 0.03, z), C.Line, Enum.Material.SmoothPlastic, { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Transparency = 0.3 })
	end
	for k = 0, N - 1 do
		if cell(MID, k) == "." and k > 2 and k < N - 3 then
			dash(wx(MID + 0.5), wz(k + 0.5), false)
		end
		if cell(k, MID) == "." and k > 2 and k < N - 3 then
			dash(wx(k + 0.5), wz(MID + 0.5), true)
		end
		if k >= 1 and k <= N - 2 then
			dash(wx(k + 0.5), wz(2), true)
			dash(wx(k + 0.5), wz(N - 2), true)
			dash(wx(2), wz(k + 0.5), false)
			dash(wx(N - 2), wz(k + 0.5), false)
		end
	end
	-- parking bays
	for _, r in rects(function(c)
		return c == "L"
	end) do
		if r.j1 - r.j0 >= 2 then
			for x = wx(r.i0) + 4, wx(r.i1 + 1) - 4, 10 do
				for _, zc in { wz(r.j0) + 13, wz(r.j1 + 1) - 13 } do
					part(ground, "BayLine", Vector3.new(0.4, 0.05, 14), CFrame.new(x, GROUND_Y + 0.12, zc), C.White, Enum.Material.SmoothPlastic, PAINT)
				end
			end
		end
	end
end

-- Buildings ---------------------------------------------------------------------------------------

-- side descriptors for a chunk rectangle: plane coordinate, outward sign, axis the face runs along
local function sides(r)
	return {
		{ axis = "z", plane = wz(r.j0), sign = -1, from = r.i0, to = r.i1, neighbor = function(k) return cell(k, r.j0 - 1) end, along = function(k) return wx(k + 0.5) end },
		{ axis = "z", plane = wz(r.j1 + 1), sign = 1, from = r.i0, to = r.i1, neighbor = function(k) return cell(k, r.j1 + 1) end, along = function(k) return wx(k + 0.5) end },
		{ axis = "x", plane = wx(r.i0), sign = -1, from = r.j0, to = r.j1, neighbor = function(k) return cell(r.i0 - 1, k) end, along = function(k) return wz(k + 0.5) end },
		{ axis = "x", plane = wx(r.i1 + 1), sign = 1, from = r.j0, to = r.j1, neighbor = function(k) return cell(r.i1 + 1, k) end, along = function(k) return wz(k + 0.5) end },
	}
end

-- a thin panel on a building face: `along` = position along the face, `out` = distance in front of it
local function facePanel(parent, name, side, along, y, width, height, out, thickness, color, material)
	local pos, size
	if side.axis == "z" then
		pos = Vector3.new(along, y, side.plane + side.sign * out)
		size = Vector3.new(width, height, thickness)
	else
		pos = Vector3.new(side.plane + side.sign * out, y, along)
		size = Vector3.new(thickness, height, width)
	end
	return decor(parent, name, size, CFrame.new(pos), color, material)
end

local function facadeTile(m, side, along, height, wall)
	local base = GROUND_Y
	-- ground floor: shutters, or a dark shop window under an awning
	if rng:NextNumber() < 0.5 then
		facePanel(m, "Shutter", side, along, base + 4, 9, 7, 0.15, 0.3, C.Shutter, Enum.Material.DiamondPlate)
	else
		facePanel(m, "ShopWindow", side, along, base + 4.2, 9, 6, 0.15, 0.3, C.Window, Enum.Material.Glass)
		facePanel(m, "Awning", side, along, base + 8.6, 10, 0.4, 1.6, 3, pick(C.Awnings), Enum.Material.Fabric)
	end
	facePanel(m, "Trim", side, along, base + 9.8, TILE, 0.8, 0.2, 0.4, wall:Lerp(Color3.new(), 0.3), Enum.Material.Concrete)
	-- upper floors: two windows per tile per floor
	local y = base + 15
	while y + 3 < base + height - 3 do
		for _, dx in { -3, 3 } do
			local roll = rng:NextNumber()
			if roll < 0.08 then
				local lit = facePanel(m, "LitWindow", side, along + dx, y, 3.2, 4.6, 0.12, 0.25, C.Lit, Enum.Material.Neon)
				lit.Transparency = 0.35
			elseif roll < 0.22 then
				facePanel(m, "Boarded", side, along + dx, y, 3.2, 4.6, 0.15, 0.3, C.Board, Enum.Material.WoodPlanks)
			elseif roll < 0.95 then
				facePanel(m, "Window", side, along + dx, y, 3.2, 4.6, 0.12, 0.25, C.Window, Enum.Material.Glass)
			end
		end
		y += 9
	end
	-- vines creeping up some walls
	if rng:NextNumber() < 0.18 then
		local h = rng:NextNumber(8, math.min(26, height - 2))
		facePanel(m, "Vines", side, along + rng:NextNumber(-4, 4), base + h / 2, rng:NextNumber(2, 4), h, 0.3, 0.4, C.Vine, Enum.Material.Grass)
	end
end

local function roofTop(m, r, height, wall)
	local top = GROUND_Y + height
	local size = rectSize(r, 1)
	part(m, "Cornice", size + Vector3.new(0.8, 0, 0.8), rectCenter(r, top + 0.5), wall:Lerp(Color3.new(), 0.25), Enum.Material.Concrete)
	local center = rectCenter(r, top).Position
	if rng:NextNumber() < 0.35 then
		-- broken: a chunk of the top floor has collapsed into rubble
		for _ = 1, rng:NextInteger(3, 6) do
			local s = rng:NextNumber(2, 5)
			part(m, "Rubble", Vector3.new(s, s * 0.6, s * 1.2), CFrame.new(center + Vector3.new(rng:NextNumber(-size.X / 2 + 3, size.X / 2 - 3), 1 + s * 0.3, rng:NextNumber(-size.Z / 2 + 3, size.Z / 2 - 3))) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)), wall, Enum.Material.Concrete)
		end
	elseif height > 40 and rng:NextNumber() < 0.4 then
		-- water tower
		for _, d in { { -2, -2 }, { 2, -2 }, { -2, 2 }, { 2, 2 } } do
			part(m, "TowerLeg", Vector3.new(0.5, 6, 0.5), CFrame.new(center + Vector3.new(d[1], 4, d[2])), C.Metal, Enum.Material.Metal)
		end
		cylinder(m, "Tank", 6, 7, CFrame.new(center + Vector3.new(0, 10, 0)), C.Board, Enum.Material.WoodPlanks)
	else
		for _ = 1, rng:NextInteger(1, 3) do
			part(m, "ACUnit", Vector3.new(3, 2, 3), CFrame.new(center + Vector3.new(rng:NextNumber(-size.X / 2 + 3, size.X / 2 - 3), 2, rng:NextNumber(-size.Z / 2 + 3, size.Z / 2 - 3))), C.Shutter, Enum.Material.Metal)
		end
	end
end

local function buildBuildings(parent)
	local buildings = model(parent, "Buildings")
	for _, r in rects(function(c)
		return c == "#"
	end) do
		local edge = r.i0 == 0 or r.j0 == 0 or r.i1 == N - 1 or r.j1 == N - 1
		-- split long runs into 1-2 tile chunks so the skyline varies
		local alongI = (r.i1 - r.i0) >= (r.j1 - r.j0)
		local k = if alongI then r.i0 else r.j0
		local last = if alongI then r.i1 else r.j1
		while k <= last do
			local len = math.min(rng:NextInteger(1, 2), last - k + 1)
			local chunk = if alongI then { i0 = k, i1 = k + len - 1, j0 = r.j0, j1 = r.j1 } else { i0 = r.i0, i1 = r.i1, j0 = k, j1 = k + len - 1 }
			k += len
			local height = if edge then rng:NextInteger(5, 8) * 9 - 2 else rng:NextInteger(3, 6) * 9 - 2
			local wall = pick(C.Walls)
			local brick = wall.R > wall.G * 1.4
			local m = model(buildings, "Building")
			part(m, "Body", rectSize(chunk, height), rectCenter(chunk, GROUND_Y + height / 2), wall, if brick then Enum.Material.Brick else Enum.Material.Concrete)
			for _, side in sides(chunk) do
				for t = side.from, side.to do
					if side.neighbor(t) ~= "#" then
						facadeTile(m, side, side.along(t), height, wall)
					end
				end
			end
			roofTop(m, chunk, height, wall)
		end
	end
end

-- Props -------------------------------------------------------------------------------------------

local function car(parent, x, z, rotDeg, kind)
	if nearZombieSpawn(x, z) then
		return
	end
	local m = model(parent, if kind == "bus" then "Bus" else "Car")
	local dims = ({
		sedan = { w = 7, h = 2.4, l = 14, cabH = 2.2, cabL = 7 },
		taxi = { w = 7, h = 2.4, l = 14, cabH = 2.2, cabL = 7 },
		van = { w = 7.4, h = 5.6, l = 16, cabH = 0, cabL = 0 },
		bus = { w = 9, h = 8, l = 32, cabH = 0, cabL = 0 },
	})[kind]
	local color = if kind == "taxi" then C.Taxi elseif kind == "bus" then Color3.fromRGB(176, 140, 50) else pick(C.Cars)
	color = color:Lerp(Color3.fromRGB(70, 60, 50), rng:NextNumber(0.1, 0.35)) -- grime
	local base = at(x, GROUND_Y + 0.8 + dims.h / 2, z) * CFrame.Angles(0, math.rad(rotDeg), rng:NextNumber(-0.03, 0.03))
	part(m, "Body", Vector3.new(dims.w, dims.h, dims.l), base, color, Enum.Material.Metal)
	if dims.cabH > 0 then
		part(m, "Cabin", Vector3.new(dims.w - 0.6, dims.cabH, dims.cabL), base * CFrame.new(0, dims.h / 2 + dims.cabH / 2, 0.5), color, Enum.Material.Metal)
		decor(m, "Glass", Vector3.new(dims.w - 0.8, dims.cabH - 0.4, 0.2), base * CFrame.new(0, dims.h / 2 + dims.cabH / 2, 0.5 - dims.cabL / 2 - 0.05), C.Window, Enum.Material.Glass)
	else
		local rows = math.floor(dims.l / 4) - 1
		for s = -1, 1, 2 do
			for w = 1, rows do
				decor(m, "Glass", Vector3.new(0.2, dims.h * 0.3, 2.6), base * CFrame.new(s * (dims.w / 2 + 0.05), dims.h * 0.2, -dims.l / 2 + w * 4), C.Window, Enum.Material.Glass)
			end
		end
	end
	if kind == "taxi" then
		decor(m, "TaxiSign", Vector3.new(2.4, 0.8, 1), base * CFrame.new(0, dims.h / 2 + dims.cabH + 0.4, 0.5), Color3.fromRGB(230, 220, 190), Enum.Material.SmoothPlastic)
	end
	for _, w in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local wheel = decor(m, "Wheel", Vector3.new(1, 2.4, 2.4), base * CFrame.new(w[1] * (dims.w / 2 - 0.4), -dims.h / 2 - 0.1, w[2] * (dims.l / 2 - 2.6)), C.Tire, Enum.Material.SmoothPlastic)
		wheel.Shape = Enum.PartType.Cylinder
	end
end

local function jersey(parent, x, z, rotDeg)
	if nearZombieSpawn(x, z) then
		return
	end
	local cf = at(x, GROUND_Y + 1.6, z) * CFrame.Angles(0, math.rad(rotDeg), 0)
	part(parent, "JerseyBarrier", Vector3.new(8, 3.2, 2), cf, C.Concrete, Enum.Material.Concrete)
	decor(parent, "Stripe", Vector3.new(8.05, 0.5, 2.05), cf * CFrame.new(0, 1, 0), Color3.fromRGB(190, 70, 50), Enum.Material.SmoothPlastic)
end

local lampHeads = {}

local function lamp(parent, x, z, facing, lit)
	local m = model(parent, "StreetLamp")
	cylinder(m, "Pole", 15, 0.7, at(x, GROUND_Y + 7.5, z), C.Metal, Enum.Material.Metal)
	local headPos = Vector3.new(origin.X + x, GROUND_Y + 15, origin.Z + z) + facing * 2.5
	decor(m, "Arm", Vector3.new(0.4, 0.4, 3), CFrame.lookAt(Vector3.new(origin.X + x, GROUND_Y + 15.2, origin.Z + z) + facing * 1.25, headPos + Vector3.new(0, 0.2, 0)), C.Metal, Enum.Material.Metal)
	local head = decor(m, "Head", Vector3.new(1.6, 0.6, 2.4), CFrame.lookAt(headPos, headPos + facing), if lit then C.Lamp else C.Metal, if lit then Enum.Material.Neon else Enum.Material.Metal)
	if lit then
		local light = Instance.new("PointLight")
		light.Color = C.Lamp
		light.Range = 24
		light.Brightness = 1.3
		light.Parent = head
	end
	table.insert(lampHeads, head)
	return head
end

local function buildStreets(parent)
	local streets = model(parent, "Streets")
	local lamps = model(streets, "Lamps")
	-- lamps along both sides of the main streets
	local function lampRow(points, facing)
		for n, p in points do
			lamp(lamps, p.X, p.Z, facing, n % 2 == 1)
		end
	end
	for _, s in { -1, 1 } do
		local ns, ew = {}, {}
		for k = 1, N - 2, 2 do
			if cell(MID + s, k) == "." and cell(MID - s, k) == "." then
				table.insert(ns, Vector3.new(s * 16.5, 0, wz(k + 0.5) - origin.Z))
			end
			if cell(k, MID + s) == "." and cell(k, MID - s) == "." then
				table.insert(ew, Vector3.new(wx(k + 0.5) - origin.X, 0, s * 16.5))
			end
		end
		lampRow(ns, Vector3.new(-s, 0, 0))
		lampRow(ew, Vector3.new(0, 0, -s))
		-- ring road, outer side
		local ringNS, ringEW = {}, {}
		for k = 2, N - 3, 2 do
			table.insert(ringNS, Vector3.new(s * (HALF - 13.5), 0, wz(k + 0.5) - origin.Z))
			table.insert(ringEW, Vector3.new(wx(k + 0.5) - origin.X, 0, s * (HALF - 13.5)))
		end
		lampRow(ringNS, Vector3.new(-s, 0, 0))
		lampRow(ringEW, Vector3.new(0, 0, -s))
	end

	-- wrecks and barricades (arena-relative x, z, rotation, kind)
	local vehicles = model(streets, "Vehicles")
	for _, v in {
		{ -7, -64, 8, "sedan" }, { 8, -100, -12, "taxi" }, { -40, -112, 80, "van" },
		{ 6, 72, 170, "sedan" }, { -9, 98, 200, "taxi" }, { 5, 118, 95, "sedan" },
		{ -70, -6, 92, "sedan" }, { -100, 7, 70, "van" }, { -118, -4, 4, "taxi" },
		{ 70, 6, -88, "taxi" }, { 98, -6, 100, "sedan" }, { 118, 5, 175, "sedan" },
		{ -60, -120, 90, "sedan" }, { 70, -118, 80, "taxi" }, { -122, 60, 2, "sedan" },
		{ 122, -50, 180, "van" }, { 60, 122, 268, "sedan" }, { -70, 120, 95, "taxi" },
	} do
		car(vehicles, v[1], v[2], v[3], v[4])
	end
	local barriers = model(streets, "Barriers")
	for _, b in { { -10, -80, 0 }, { -1, -80, 4 }, { 92, -12, 90 }, { -88, 14, 80 }, { 12, 88, 10 }, { -120, -96, 90 }, { 118, 96, 90 } } do
		jersey(barriers, b[1], b[2], b[3])
	end
end

local function buildOverpass(parent)
	-- broken highway overpass across the north street (pillars stand in the park and a building)
	local m = model(parent, "Overpass")
	local z, y = -90, GROUND_Y + 24
	for _, seg in { { -46, -6 }, { 6, 46 } } do
		local x0, x1 = seg[1], seg[2]
		part(m, "Deck", Vector3.new(x1 - x0, 3, 16), at((x0 + x1) / 2, y, z), C.Concrete, Enum.Material.Concrete)
		for _, rz in { -7.6, 7.6 } do
			decor(m, "Rail", Vector3.new(x1 - x0, 2.4, 0.6), at((x0 + x1) / 2, y + 2.7, z + rz), C.Concrete:Lerp(Color3.new(), 0.15), Enum.Material.Concrete)
		end
	end
	-- the snapped section hangs down toward the street (stays well above head height)
	part(m, "BrokenSlab", Vector3.new(9, 2.4, 14), at(-3, y - 4, z) * CFrame.Angles(0, 0, math.rad(-38)), C.Concrete, Enum.Material.Concrete)
	for n = 1, 5 do
		decor(m, "Rebar", Vector3.new(0.2, 0.2, rng:NextNumber(2, 4)), at(6 + rng:NextNumber(-0.3, 0.3), y - 0.5, z - 6 + n * 2) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), math.rad(90), 0), C.Wire, Enum.Material.Metal)
	end
	for _, px in { -24, 24 } do
		part(m, "Pillar", Vector3.new(4, y - GROUND_Y - 1.5, 6), at(px, GROUND_Y + (y - GROUND_Y - 1.5) / 2, z), C.Concrete:Lerp(Color3.new(), 0.1), Enum.Material.Concrete)
	end
	local sign = decor(m, "Sign", Vector3.new(14, 4, 0.4), at(26, y + 6, z - 8), Color3.fromRGB(40, 90, 60), Enum.Material.Metal)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "EXIT 14 → HARBOR"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = C.White
	label.Parent = gui
end

local function buildSquare(parent)
	local m = model(parent, "CitySquare")
	local c = at(0, GROUND_Y, 0)
	-- dry fountain (round = convex, the horde slides around it)
	cylinder(m, "FountainRim", 2.6, 22, c * CFrame.new(0, 1.3, 0), C.Concrete, Enum.Material.Concrete)
	cylinder(m, "Basin", 2.7, 19, c * CFrame.new(0, 1.3, 0), Color3.fromRGB(70, 66, 58), Enum.Material.Slate)
	cylinder(m, "Column", 8, 3.5, c * CFrame.new(0, 4, 0), C.Concrete, Enum.Material.Marble)
	cylinder(m, "Bowl", 1, 9, c * CFrame.new(0, 8.4, 0), C.Concrete, Enum.Material.Marble)
	decor(m, "Moss", Vector3.new(6, 0.3, 5), c * CFrame.new(-3, 2.75, 2), C.Vine, Enum.Material.Grass)
	-- light cover near the edges, centre stays open
	car(m, -30, 34, 24, "bus")
	car(m, 36, -32, -34, "sedan")
	car(m, 38, 36, 62, "taxi")
	for _, b in { { -6, -42, 0 }, { 3, -42, -6 }, { -42, -4, 90 }, { 44, 2, 84 } } do
		jersey(m, b[1], b[2], b[3])
	end
	for _, p in { { -46, -46 }, { 46, -46 }, { -46, 46 }, { 46, 46 } } do
		lamp(m, p[1], p[2], (Vector3.new(-p[1], 0, -p[2])).Unit, true)
	end
	-- spawn ring around the fountain, facing outward
	for n = 0, 7 do
		local a = n * math.pi / 4
		local pos = Vector3.new(origin.X + math.cos(a) * 18, GROUND_Y + 0.5, origin.Z + math.sin(a) * 18)
		part(m, "PlayerSpawn", Vector3.new(4, 1, 4), CFrame.lookAt(pos, pos + (pos - Vector3.new(origin.X, pos.Y, origin.Z))), C.White, Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	end
end

local function tree(parent, x, z)
	if nearZombieSpawn(x, z) then
		return
	end
	local m = model(parent, "Tree")
	local h = rng:NextNumber(9, 14)
	cylinder(m, "Trunk", h, rng:NextNumber(1.4, 2), at(x, GROUND_Y + h / 2, z), Color3.fromRGB(70, 56, 42), Enum.Material.Wood)
	for _ = 1, rng:NextInteger(2, 4) do
		ball(m, "Leaves", rng:NextNumber(7, 12), at(x + rng:NextNumber(-3, 3), GROUND_Y + h + rng:NextNumber(-1, 3), z + rng:NextNumber(-3, 3)), pick(C.Leaves), Enum.Material.Grass)
	end
end

local function buildDistricts(parent)
	local m = model(parent, "Districts")
	local park, alley, lot, market = model(m, "Park"), model(m, "Alleys"), model(m, "ParkingLot"), model(m, "Market")
	for j = 0, N - 1 do
		for i = 0, N - 1 do
			local c = cell(i, j)
			local x, z = wx(i + 0.5) - origin.X, wz(j + 0.5) - origin.Z
			if c == "P" then
				if rng:NextNumber() < 0.55 then
					tree(park, x + rng:NextNumber(-3, 3), z + rng:NextNumber(-3, 3))
				end
				for _ = 1, 3 do
					ball(park, "Bush", rng:NextNumber(2.5, 4.5), at(x + rng:NextNumber(-5, 5), GROUND_Y + 0.8, z + rng:NextNumber(-5, 5)), pick(C.Leaves), Enum.Material.Grass)
				end
			elseif c == "A" then
				-- dumpster against a wall, and trash
				for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					if cell(i + d[1], j + d[2]) == "#" and rng:NextNumber() < 0.25 and not nearZombieSpawn(x, z) then
						local cf = at(x + d[1] * 4.2, GROUND_Y + 1.6, z + d[2] * 4.2) * CFrame.Angles(0, if d[1] ~= 0 then math.rad(90) else 0, 0)
						part(alley, "Dumpster", Vector3.new(6, 3.2, 3), cf, Color3.fromRGB(46, 74, 52), Enum.Material.Metal)
						ball(alley, "TrashBag", 1.6, cf * CFrame.new(3.6, -0.8, 0.4), Color3.fromRGB(24, 24, 26), Enum.Material.Plastic)
						break
					end
				end
			elseif c == "M" and not nearZombieSpawn(x, z) then
				if rng:NextNumber() < 0.5 then
					local stall = model(market, "Stall")
					local rot = CFrame.Angles(0, if rng:NextNumber() < 0.5 then 0 else math.rad(90), 0)
					local base = at(x, GROUND_Y, z) * rot
					part(stall, "Counter", Vector3.new(7, 3, 3), base * CFrame.new(0, 1.5, 0), Color3.fromRGB(110, 82, 52), Enum.Material.WoodPlanks)
					for _, p in { { -3.4, -2 }, { 3.4, -2 }, { -3.4, 2 }, { 3.4, 2 } } do
						decor(stall, "Post", Vector3.new(0.3, 8, 0.3), base * CFrame.new(p[1], 4, p[2]), C.Metal, Enum.Material.Metal)
					end
					decor(stall, "Canopy", Vector3.new(8, 0.3, 6), base * CFrame.new(0, 8, 0) * CFrame.Angles(math.rad(8), 0, 0), pick(C.Awnings), Enum.Material.Fabric)
					for n = 1, 3 do
						decor(stall, "Goods", Vector3.new(1.2, 0.8, 1.2), base * CFrame.new(-2.4 + n * 1.4, 3.4, 0), pick(C.Awnings), Enum.Material.Fabric)
					end
				elseif rng:NextNumber() < 0.4 then
					part(market, "Crates", Vector3.new(3, 3, 3), at(x + rng:NextNumber(-3, 3), GROUND_Y + 1.5, z + rng:NextNumber(-3, 3)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), Color3.fromRGB(120, 92, 60), Enum.Material.WoodPlanks)
				end
			end
		end
	end
	for _, v in { { 59, 68, 0, "sedan" }, { 79, 70, 4, "sedan" }, { 99, 68, -6, "taxi" }, { 69, 96, 176, "sedan" }, { 101, 98, 184, "sedan" } } do
		car(lot, v[1], v[2], v[3], v[4])
	end
	-- overgrowth: grass tufts along building edges and road seams
	local growth = model(m, "Overgrowth")
	local placed = 0
	while placed < 160 do
		local i, j = rng:NextInteger(1, N - 2), rng:NextInteger(1, N - 2)
		local c = cell(i, j)
		if c ~= "#" and c ~= "S" then
			local x, z = wx(i) + rng:NextNumber(0, TILE), wz(j) + rng:NextNumber(0, TILE)
			local s = rng:NextNumber(0.8, 1.8)
			decor(growth, "Grass", Vector3.new(s * 1.6, s, s * 1.6), CFrame.new(x, GROUND_Y + s / 2, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), pick(C.Leaves), Enum.Material.Grass)
			placed += 1
		end
	end
end

local function buildMarkers(parent)
	local m = model(parent, "Markers")
	for _, t in ZOMBIE_TILES do
		assert(cell(t[1], t[2]) ~= "#", "ZombieSpawn inside a building")
		part(m, "ZombieSpawn", Vector3.new(6, 1, 6), CFrame.new(wx(t[1] + 0.5), GROUND_Y + 0.5, wz(t[2] + 0.5)), Color3.fromRGB(200, 40, 40), Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	end
	-- the final boss rises here: the open mouth of the south avenue, clear straight into the square
	part(m, "BossSpawn", Vector3.new(10, 1, 10), at(0, GROUND_Y + 0.5, 46), Color3.fromRGB(120, 255, 230), Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	for _, s in { -1, 1 } do
		part(m, "InvisibleWall", Vector3.new(2, 160, N * TILE), at(s * (HALF + 1), GROUND_Y + 80, 0), C.White, Enum.Material.SmoothPlastic, { Transparency = 1, CanQuery = false })
		part(m, "InvisibleWall", Vector3.new(N * TILE, 160, 2), at(0, GROUND_Y + 80, s * (HALF + 1)), C.White, Enum.Material.SmoothPlastic, { Transparency = 1, CanQuery = false })
	end
end

-- Builds (replacing) Workspace.<OurMap.Folder>.Arena around GameConfig.OurMap.ArenaCenter.
function OurCity.Build()
	origin = GameConfig.OurMap.ArenaCenter
	rng = Random.new(1406)
	table.clear(lampHeads)
	local root = workspace:FindFirstChild(GameConfig.OurMap.Folder)
	if not root then
		root = Instance.new("Folder")
		root.Name = GameConfig.OurMap.Folder
		root.Parent = workspace
	end
	local old = root:FindFirstChild("Arena")
	if old then
		old:Destroy()
	end
	local arena = Instance.new("Model")
	arena.Name = "Arena"
	buildGround(arena)
	task.wait()
	buildBuildings(arena)
	task.wait()
	buildStreets(arena)
	buildOverpass(arena)
	buildSquare(arena)
	buildDistricts(arena)
	buildMarkers(arena)
	arena.Parent = root
	return arena
end

-- Grid facts for MapService / NavGrid
OurCity.Tile = TILE
OurCity.HalfSize = HALF

return OurCity
