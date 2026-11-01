-- MapService: generates "Graveside Isle" — the arena island, the lobby island, ocean and lighting —
-- in the stud style (docs/ART_STYLE.md; bricks from Shared/Bricks.lua, props from Server/Map/Props.lua),
-- and answers "where do things spawn". Numbers live in GameConfig.Map.
--
-- The map is BAKED into the place (MapService:Build() in Edit mode) so it can be hand-edited; at
-- runtime an existing Workspace.Map is used untouched and only generated if missing.
--
-- Arena island (top-down):
--   * ground = grid of CellSize cells classified by noise into Grass / GrassDark / GrassLight /
--     Path (dirt) / Grave (dark dirt) / Sand, greedy-merged into rectangles (flat top at GroundY)
--   * plaza + well at the centre, jagged dirt paths along the axes and diagonals
--   * 8 graveyards at the edge (corners + side midpoints) with a hidden "ZombieSpawn" part each
--   * EdgeDepth band: cottages, trees, rocks, bushes behind a broken red fence
--   * interior cover: seeded trees, rocks, crate stacks, bushes, stalls, a campfire
--   * sand beach with a jagged outline, Terrain water ocean, invisible walls at the arena edge
--   Zombies steer straight and slide along cover (no pathfinding): props stay chunky and convex,
--   ~20 studs apart, and the playable floor is perfectly flat.
--
-- GameConfig.ActiveMap = "Ours" switches the lobby (and later the arena) to Workspace.OurMap; see
-- ourPart() below. The original map stays untouched either way.
--
-- Public:
--   MapService.GroundY, MapService:Build(), MapService:GetLobbySpawnCFrame(),
--   MapService:GetArenaSpawnCFrame(index?), MapService:GetZombieSpawnPosition()

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Bricks = require(Shared.Bricks)
local Props = require(script.Parent.Parent:WaitForChild("Map"):WaitForChild("Props"))

local M = GameConfig.Map
local P = Bricks.Palette

local MapService = {}
MapService.GroundY = 1

local zombiePads = {}

-- Parts named `partName` inside Workspace.<OurMap.Folder>.<section>, or nil when ActiveMap is not
-- "Ours" or that section has none (callers then fall back to the original map).
local function ourParts(section, partName)
	if GameConfig.ActiveMap ~= "Ours" then
		return nil
	end
	local root = workspace:FindFirstChild(GameConfig.OurMap.Folder)
	local folder = root and root:FindFirstChild(section)
	if not folder then
		return nil
	end
	local parts = {}
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") and d.Name == partName then
			table.insert(parts, d)
		end
	end
	return if #parts > 0 then parts else nil
end

-- Ground cell types: colour + loose-tile colours scattered at their borders
local CELL = {
	Grass = { Color = P.Grass },
	GrassDark = { Color = P.GrassDark },
	GrassLight = { Color = P.GrassLight },
	Path = { Color = P.Dirt, Loose = { P.Dirt, P.DirtDark } },
	Grave = { Color = P.DirtDark, Loose = { P.DirtDark, P.Dirt } },
	Sand = { Color = P.Sand, Loose = { P.Sand, P.SandLight } },
	-- Raised grass-capped dirt terrace (non-playable edge band). Raise = whole studs above GroundY.
	-- Gets grass patches on exposed walls and a tall invisible Blocker so nobody stands on it.
	Terrace = { Color = P.Grass, Body = P.Dirt, Raise = 5, Blocker = true },
	-- Walkable lobby plateau tiers (reached by stairs)
	Plateau1 = { Color = P.Grass, Body = P.Dirt, Raise = 2 },
	Plateau2 = { Color = P.GrassLight, Body = P.Dirt, Raise = 4 },
	-- Underwater sand shelf around islands (turquoise shallows). TopAbs = absolute top Y (whole stud).
	Shore = { Color = P.SandLight, TopAbs = math.floor(M.WaterLevel - 1) },
}
local CAP = 1 -- grass cap thickness on raised cells (whole stud so cap sides keep their studs)

local function isFlatWalkable(t)
	local info = t and CELL[t]
	return info ~= nil and not info.Raise and not info.TopAbs
end

local function noise(x, z, scale, salt)
	return math.noise(x / scale, z / scale, M.Seed * 0.013 + (salt or 0))
end

-- Builds ground from cells. classify(dx, dz) -> cell type name or nil (water), relative to origin.
-- Same-type cells are greedy-merged into rectangles. Returns the grid for later queries.
-- skipPatch(x, z, dx, dz) (optional): return true to leave a wall without grass patches (e.g.
-- where stairs lean against it).
local function buildCells(parent, origin, extent, classify, rng, skipPatch)
	local cs = M.CellSize
	local n = math.ceil(extent * 2 / cs)
	local grid = table.create(n)
	for i = 0, n - 1 do
		local column = {}
		for j = 0, n - 1 do
			column[j] = classify(-extent + (i + 0.5) * cs, -extent + (j + 0.5) * cs) or false
		end
		grid[i] = column
	end

	local g = MapService.GroundY
	local bottom = math.floor(M.WaterLevel - 5) -- whole stud, so island side walls keep full studs
	local used = {}
	for j = 0, n - 1 do
		for i = 0, n - 1 do
			local t = grid[i][j]
			if t and not used[i * n + j] then
				local w = 1
				while i + w < n and grid[i + w][j] == t and not used[(i + w) * n + j] do
					w += 1
				end
				local h = 1
				while j + h < n do
					local ok = true
					for k = 0, w - 1 do
						if grid[i + k][j + h] ~= t or used[(i + k) * n + j + h] then
							ok = false
							break
						end
					end
					if not ok then
						break
					end
					h += 1
				end
				for a = 0, w - 1 do
					for b = 0, h - 1 do
						used[(i + a) * n + j + b] = true
					end
				end
				local x0, z0 = -extent + i * cs, -extent + j * cs
				local info = CELL[t]
				local top = info.TopAbs or (g + (info.Raise or 0))
				local cx, cz = origin.X + x0 + w * cs / 2, origin.Z + z0 + h * cs / 2
				if info.Body then
					Bricks.Part({ Name = t .. "Body", Size = Vector3.new(w * cs, top - CAP - bottom, h * cs), Position = Vector3.new(cx, (top - CAP + bottom) / 2, cz), Color = info.Body, Parent = parent })
					Bricks.Part({ Name = t, Size = Vector3.new(w * cs, CAP, h * cs), Position = Vector3.new(cx, top - CAP / 2, cz), Color = info.Color, Parent = parent })
				else
					Bricks.Part({ Name = t, Size = Vector3.new(w * cs, top - bottom, h * cs), Position = Vector3.new(cx, (top + bottom) / 2, cz), Color = info.Color, Parent = parent })
				end
				if info.Blocker then
					Bricks.Part({
						Name = "Blocker",
						Size = Vector3.new(w * cs, 50, h * cs), -- exact footprint: never overhangs walkable ground
						Position = Vector3.new(cx, top + 25, cz),
						Transparency = 1,
						CanQuery = false,
						CanTouch = false,
						CastShadow = false,
						Parent = parent,
					})
				end
			end
		end
	end

	-- Raised cells: whole-stud grass patches spilling down every exposed wall (like the reference
	-- terraces), plus occasional moss patches lower down. A patch stays inside its own cell's
	-- 4-stud span on the stud grid and sits 0.4 proud of the wall, so patches line up with the
	-- wall's studs and can never overlap each other (no z-fighting). Decor only: no collision.
	local patches = Instance.new("Folder")
	patches.Name = "GrassPatches"
	local dirs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	local function patch(alongX, planePos, spanStart, w, yTop, h, color)
		local along = spanStart + w / 2
		Bricks.Part({
			Name = "GrassPatch",
			Size = if alongX then Vector3.new(w, h, 0.4) else Vector3.new(0.4, h, w),
			Position = if alongX then Vector3.new(along, yTop - h / 2, planePos) else Vector3.new(planePos, yTop - h / 2, along),
			Color = color,
			CanCollide = false,
			CanQuery = false,
			Parent = patches,
		})
	end
	local function raisedAtLeast(ii, jj, raise)
		local tt = ii >= 0 and ii < n and jj >= 0 and jj < n and grid[ii][jj]
		return tt and (CELL[tt].Raise or 0) >= raise
	end
	for i = 0, n - 1 do
		for j = 0, n - 1 do
			local t = grid[i][j]
			local info = t and CELL[t]
			if info and info.Raise then
				local top = g + info.Raise
				local x0, z0 = origin.X - extent + i * cs, origin.Z - extent + j * cs
				for _, d in dirs do
					local ni, nj = i + d[1], j + d[2]
					local neighbor = if ni >= 0 and ni < n and nj >= 0 and nj < n then grid[ni][nj] else false
					local nInfo = neighbor and CELL[neighbor]
					local floorY = if nInfo then (nInfo.TopAbs or g + (nInfo.Raise or 0)) else bottom
					local wallH = top - floorY
					if wallH >= 1 and not (skipPatch and skipPatch(x0 + cs / 2, z0 + cs / 2, d[1], d[2])) then
						local alongX = d[1] == 0 -- wall runs along X when stepping in Z
						local spanStart = if alongX then x0 else z0
						local wallPlane = if d[1] == 1 then x0 + cs elseif d[1] == -1 then x0 elseif d[2] == 1 then z0 + cs else z0
						local planePos = wallPlane + (d[1] + d[2]) * 0.2 -- centre of a 0.4-thick plate on the wall
						-- Inside corners: if the cell diagonally out-and-along is raised, a perpendicular
						-- wall meets this one there; keep 1 stud clear so the two walls' patches can't overlap.
						local ti, tj = (if d[2] ~= 0 then 1 else 0), (if d[1] ~= 0 then 1 else 0)
						local lo = if raisedAtLeast(i - ti + d[1], j - tj + d[2], info.Raise) then 1 else 0
						local hi = cs - (if raisedAtLeast(i + ti + d[1], j + tj + d[2], info.Raise) then 1 else 0)
						local room = hi - lo
						local topH = 0
						if room >= 1 and rng:NextNumber() < 0.65 then
							local w = rng:NextInteger(1, room)
							topH = math.min(rng:NextInteger(1, 3), wallH)
							patch(alongX, planePos, spanStart + lo + rng:NextInteger(0, room - w), w, top, topH, Bricks.Pick(rng, { info.Color, P.GrassDark }))
						end
						if room >= 1 and wallH - topH >= 4 and rng:NextNumber() < 0.3 then
							local w, h = rng:NextInteger(1, math.min(2, room)), rng:NextInteger(1, 2)
							local yTop = top - topH - rng:NextInteger(1, math.max(1, wallH - topH - h - 1))
							patch(alongX, planePos, spanStart + lo + rng:NextInteger(0, room - w), w, yTop, h, P.GrassDark)
						end
					end
				end
			end
		end
	end
	patches.Parent = parent

	-- Loose tiles along borders between different cell types (the jagged "crumbs" look).
	-- Snapped to the stud grid, axis-aligned, never overlapping each other, and lifted 0.01 so
	-- their undersides never coincide with prop bottoms.
	local loose = Instance.new("Folder")
	loose.Name = "LooseTiles"
	local taken = {}
	for i = 1, n - 2 do
		for j = 1, n - 2 do
			local t = grid[i][j]
			local info = t and CELL[t]
			if info and info.Loose and rng:NextNumber() < 0.25 then
				local ni, nj = i + rng:NextInteger(-1, 1), j + rng:NextInteger(-1, 1)
				local other = grid[ni][nj]
				if other and other ~= t and isFlatWalkable(other) then
					local a, b = rng:NextInteger(1, 2), rng:NextInteger(1, 2)
					local tx = origin.X - extent + ni * cs + rng:NextInteger(0, cs - a)
					local tz = origin.Z - extent + nj * cs + rng:NextInteger(0, cs - b)
					local free = true
					for xx = tx - 1, tx + a do
						for zz = tz - 1, tz + b do
							if taken[xx .. "," .. zz] then
								free = false
							end
						end
					end
					if free then
						for xx = tx, tx + a - 1 do
							for zz = tz, tz + b - 1 do
								taken[xx .. "," .. zz] = true
							end
						end
						Bricks.Part({
							Name = "Tile",
							Size = Vector3.new(a, 0.3, b),
							Position = Vector3.new(tx + a / 2, g + 0.2, tz + b / 2), -- underside 0.05 above ground
							Color = Bricks.Pick(rng, info.Loose),
							CanCollide = false,
							CanQuery = false,
							CastShadow = false,
							Parent = loose,
						})
					end
				end
			end
		end
	end
	loose.Parent = parent
	return grid
end

local function padPositions(c, half)
	local list = {}
	local inset = half - 10
	for i = 1, M.ZombieSpawnCount do
		local angle = (i / M.ZombieSpawnCount) * math.pi * 2
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local pos = c + dir * (inset / math.max(math.abs(dir.X), math.abs(dir.Z)))
		table.insert(list, Vector3.new(pos.X, MapService.GroundY, pos.Z))
	end
	return list
end

-- Arena -----------------------------------------------------------------------------------------

local function classifyArena(pads, half)
	return function(x, z)
		local edge = math.max(math.abs(x), math.abs(z))
		local n = noise(x, z, 23)
		local coast = half + M.BeachWidth + n * 10
		if edge > coast + 10 + noise(x, z, 7, 2) * 4 then
			return nil
		elseif edge > coast then
			return "Shore"
		end
		if edge > half + 3 + n * 4 then
			return "Sand"
		end
		for _, pad in pads do
			local dx, dz = x - pad.X, z - pad.Z
			if math.sqrt(dx * dx + dz * dz) < M.GraveyardRadius + noise(x, z, 9, 3) * 5 then
				return "Grave"
			end
			-- Exit lane from the graveyard toward the arena centre, so every graveyard (corners
			-- included) opens through the terrace/fence line. Lane = capsule around pad -> pad*0.78.
			local ax, az = pad.X, pad.Z
			local bx, bz = pad.X * 0.78, pad.Z * 0.78
			local vx, vz = bx - ax, bz - az
			local tLane = math.clamp(((x - ax) * vx + (z - az) * vz) / (vx * vx + vz * vz), 0, 1)
			local lx, lz = ax + vx * tLane - x, az + vz * tLane - z
			if math.sqrt(lx * lx + lz * lz) < 8 + noise(x, z, 6, 5) * 2 then
				return "Grave"
			end
		end
		-- Raised terrace behind the fence (fence sits at half - EdgeDepth - 1)
		if edge > half - M.EdgeDepth + 1 + noise(x, z, 8, 4) * 2 then
			return "Terrace"
		end
		local r = math.sqrt(x * x + z * z)
		local wobble = noise(x, z, 11, 7) * 3
		if r < M.PlazaRadius + wobble * 1.5 then
			return "Path"
		end
		if edge < half - M.EdgeDepth + 2 then
			if math.abs(x) < 3.5 + wobble or math.abs(z) < 3.5 + wobble then
				return "Path"
			end
			if math.abs(math.abs(x) - math.abs(z)) < 3 + wobble then
				return "Path"
			end
		end
		local v = noise(x, z, 14, 11)
		if v > 0.3 then
			return "GrassLight"
		elseif v < -0.3 then
			return "GrassDark"
		end
		return "Grass"
	end
end

local function nearPad(pos, pads, radius)
	for _, pad in pads do
		if (Vector3.new(pos.X, pad.Y, pos.Z) - pad).Magnitude < radius then
			return true
		end
	end
	return false
end

local function buildEdge(parent, rng, c, half, pads, classify)
	local folder = Instance.new("Folder")
	folder.Name = "Edge"
	local depth = M.EdgeDepth
	local clear = M.GraveyardRadius + 4
	-- Surface height at a world position (terrace top or ground)
	local function surfaceAt(pos)
		local info = CELL[classify(pos.X - c.X, pos.Z - c.Z) or "Grass"]
		return MapService.GroundY + (info and info.Raise or 0)
	end
	local function onSurface(pos)
		return Vector3.new(pos.X, surfaceAt(pos), pos.Z)
	end
	for sideIndex, n in { Vector3.new(0, 0, -1), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0) } do
		local t = Vector3.new(-n.Z, 0, n.X)
		local bandCenter = c + n * (half - depth / 2 + 1)
		-- one landmark tower per side, alternating which half it sits in
		local towerAt = (if sideIndex % 2 == 0 then 1 else -1) * half * 0.45
		local towerPos = onSurface(bandCenter + t * towerAt)
		Props.Tower(folder, rng, CFrame.lookAt(towerPos, towerPos - n))
		local function isBlocked(pos, radius)
			return nearPad(pos, pads, radius) or (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(towerPos.X, 0, towerPos.Z)).Magnitude < 11
		end

		local cursor = -half + 4
		while cursor < half - 4 do
			local pos = bandCenter + t * cursor
			if isBlocked(pos, clear) then
				cursor += 4
				continue
			end
			local roll = rng:NextNumber()
			local ground = onSurface(pos)
			local inward = CFrame.lookAt(ground, ground - n)
			local w = rng:NextInteger(14, 18)
			local mid = bandCenter + t * (cursor + w / 2)
			if roll < 0.35 and cursor + w < half - 2 and not isBlocked(bandCenter + t * (cursor + w), clear) and not isBlocked(mid, clear) then
				local midGround = onSurface(mid)
				Props.Cottage(folder, rng, CFrame.lookAt(midGround, midGround - n) * CFrame.new(0, 0, 1), w, 12)
				cursor += w + 3
			elseif roll < 0.55 then
				Props.Tree(folder, rng, inward * CFrame.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-3, 3)))
				cursor += rng:NextInteger(8, 11)
			elseif roll < 0.65 then
				Props.PineTree(folder, rng, inward * CFrame.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-3, 3)))
				cursor += rng:NextInteger(7, 9)
			elseif roll < 0.7 then
				Props.AutumnTree(folder, rng, inward * CFrame.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-3, 3)))
				cursor += rng:NextInteger(9, 11)
			elseif roll < 0.82 then
				Props.Rock(folder, rng, inward * CFrame.new(0, 0, rng:NextNumber(-3, 3)), rng:NextNumber(5, 8))
				cursor += 8
			elseif roll < 0.9 then
				Props.Mushroom(folder, rng, inward * CFrame.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-4, 4)))
				Props.Bush(folder, rng, inward * CFrame.new(rng:NextNumber(-2, 2) + 3, 0, rng:NextNumber(-4, 4)), false)
				cursor += 7
			else
				Props.Bush(folder, rng, inward * CFrame.new(0, 0, rng:NextNumber(-4, 4)))
				cursor += 6
			end
		end
		-- Broken fence along the inner edge of the band, with gaps at the graveyards
		local fenceLine = c + n * (half - depth - 1)
		-- Gaps wherever graveyard dirt (incl. its exit lane) is within 3 studs, or near a pad.
		-- Each run ends at the LAST open point so no post stands inside a gap.
		local function isGrave(p)
			return classify(p.X - c.X, p.Z - c.Z) == "Grave"
		end
		local from, last = nil, nil
		local function flush()
			if from and last and (last - from).Magnitude > 3 then
				Props.Fence(folder, rng, Vector3.new(from.X, MapService.GroundY, from.Z), Vector3.new(last.X, MapService.GroundY, last.Z))
			end
			from, last = nil, nil
		end
		for s = -half + 2, half - 2, 2 do
			local p = fenceLine + t * s
			local blocked = nearPad(p, pads, clear + 2) or isGrave(p) or isGrave(p + t * 3) or isGrave(p - t * 3)
			if blocked then
				flush()
			else
				from = from or p
				last = p
			end
		end
		flush()
	end
	folder.Parent = parent
end

local function buildGraveyards(parent, rng, c, pads, classify)
	local folder = Instance.new("Folder")
	folder.Name = "Graveyards"
	for _, pad in pads do
		local outward = (pad - Vector3.new(c.X, pad.Y, c.Z)).Unit
		-- items only on graveyard dirt, with a 3-stud margin so nothing pokes into the terrace
		Props.Graveyard(folder, rng, pad, M.GraveyardRadius, outward, function(pos)
			for _, o in { Vector3.zero, Vector3.new(3, 0, 0), Vector3.new(-3, 0, 0), Vector3.new(0, 0, 3), Vector3.new(0, 0, -3) } do
				if classify(pos.X + o.X - c.X, pos.Z + o.Z - c.Z) ~= "Grave" then
					return false
				end
			end
			return true
		end)
		Bricks.Part({
			Name = "ZombieSpawn",
			Size = Vector3.new(6, 1, 6),
			Position = pad + Vector3.new(0, 0.5, 0),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Parent = folder,
		})
	end
	folder.Parent = parent
end

local COVER = {
	{ Weight = 3, Build = function(f, rng, cf) Props.Tree(f, rng, cf) end },
	{ Weight = 2, Build = function(f, rng, cf) Props.Rock(f, rng, cf) end },
	{ Weight = 2, Build = function(f, rng, cf) Props.CrateStack(f, rng, cf) end },
	{ Weight = 2, Build = function(f, rng, cf) Props.Bush(f, rng, cf) end },
	{ Weight = 1, Max = 2, Build = function(f, rng, cf) Props.Stall(f, rng, cf) end },
	{ Weight = 1, Max = 1, Build = function(f, rng, cf) Props.Campfire(f, rng, cf) end },
	{ Weight = 1, Build = function(f, rng, cf) Props.LampPost(f, rng, cf) end },
	{ Weight = 1, Build = function(f, rng, cf) Props.Log(f, rng, cf) end },
	{ Weight = 1, Max = 2, Build = function(f, rng, cf) Props.AutumnTree(f, rng, cf) end },
}

local function buildCover(parent, rng, c, half, pads, classify)
	local folder = Instance.new("Folder")
	folder.Name = "Cover"
	local limit = half - M.EdgeDepth - 8
	local placed, counts, attempts = {}, {}, 0
	local total = 0
	for _, entry in COVER do
		total += entry.Weight
	end
	while #placed < M.CoverCount and attempts < 1000 do
		attempts += 1
		local pos = c + Vector3.new(rng:NextNumber(-limit, limit), 0, rng:NextNumber(-limit, limit))
		local ok = (pos - c).Magnitude > M.CoverClearRadius and not nearPad(pos, pads, M.GraveyardRadius + 8)
		for _, other in placed do
			if (pos - other).Magnitude < 22 then
				ok = false
				break
			end
		end
		if ok then
			local roll = rng:NextNumber() * total
			local choice
			for _, entry in COVER do
				roll -= entry.Weight
				if roll <= 0 then
					choice = entry
					break
				end
			end
			if choice.Max and (counts[choice] or 0) >= choice.Max then
				continue
			end
			counts[choice] = (counts[choice] or 0) + 1
			table.insert(placed, pos)
			local ground = Vector3.new(pos.X, MapService.GroundY, pos.Z)
			-- face the plaza (stalls/lamps read nicely), with a little jitter
			choice.Build(folder, rng, CFrame.lookAt(ground, Vector3.new(c.X, ground.Y, c.Z)) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0))
		end
	end
	-- Decor: flower clusters + a few mushrooms on open grass (flowers have no collision)
	local grass = { Grass = true, GrassDark = true, GrassLight = true }
	local decor, tries = 0, 0
	while decor < 70 and tries < 2000 do
		tries += 1
		local pos = c + Vector3.new(rng:NextNumber(-limit - 2, limit + 2), 0, rng:NextNumber(-limit - 2, limit + 2))
		if grass[classify(pos.X - c.X, pos.Z - c.Z)] and (pos - c).Magnitude > M.PlazaRadius + 4 then
			local clear = true
			for _, other in placed do
				if (pos - other).Magnitude < 7 then
					clear = false
					break
				end
			end
			if clear then
				decor += 1
				local cf = CFrame.new(pos.X, MapService.GroundY, pos.Z)
				if decor % 12 == 0 then
					Props.Mushroom(folder, rng, cf)
					table.insert(placed, pos)
				else
					Props.Flowers(folder, rng, cf)
				end
			end
		end
	end
	folder.Parent = parent
end

local function buildPlaza(parent, rng, c)
	local folder = Instance.new("Folder")
	folder.Name = "Plaza"
	local ground = Vector3.new(c.X, MapService.GroundY, c.Z)
	Props.Well(folder, rng, CFrame.new(ground) * CFrame.Angles(0, math.rad(45), 0))
	for i = 1, 4 do
		local a = (i / 4) * math.pi * 2 + math.pi / 4
		local pos = ground + Vector3.new(math.cos(a), 0, math.sin(a)) * (M.PlazaRadius - 3)
		Props.LampPost(folder, rng, CFrame.lookAt(pos, ground))
	end
	folder.Parent = parent
end

local function buildWalls(parent, c, half)
	local h = 60
	for _, spec in
		{
			{ Vector3.new(0, 0, -half - 1), Vector3.new(half * 2 + 4, h, 2) },
			{ Vector3.new(0, 0, half + 1), Vector3.new(half * 2 + 4, h, 2) },
			{ Vector3.new(-half - 1, 0, 0), Vector3.new(2, h, half * 2 + 4) },
			{ Vector3.new(half + 1, 0, 0), Vector3.new(2, h, half * 2 + 4) },
		}
	do
		Bricks.Part({
			Name = "InvisibleWall",
			Size = spec[2],
			Position = c + spec[1] + Vector3.new(0, MapService.GroundY + h / 2, 0),
			Transparency = 1,
			CanQuery = false,
			CastShadow = false,
			Parent = parent,
		})
	end
end

local function buildArena(parent)
	local arena = Instance.new("Model")
	arena.Name = "Arena"
	arena.Parent = parent
	local rng = Random.new(M.Seed)
	local c, half = M.ArenaCenter, M.ArenaSize / 2
	local pads = padPositions(c, half)

	local ground = Instance.new("Model")
	ground.Name = "Ground"
	local classify = classifyArena(pads, half)
	buildCells(ground, Vector3.new(c.X, 0, c.Z), MapService:GetArenaCellExtent(), classify, rng)
	ground.Parent = arena
	task.wait()
	buildWalls(arena, c, half)
	buildGraveyards(arena, rng, c, pads, classify)
	buildPlaza(arena, rng, c)
	task.wait()
	buildEdge(arena, rng, c, half, pads, classify)
	task.wait()
	buildCover(arena, rng, c, half, pads, classify)
	-- Palms + rocks on the beach outside the walls (decor)
	local beach = Instance.new("Folder")
	beach.Name = "Beach"
	for i = 1, 20 do
		local a = (i / 20) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local pos = c + dir * ((half + 11) / math.max(math.abs(dir.X), math.abs(dir.Z)))
		if classify(pos.X - c.X, pos.Z - c.Z) ~= "Sand" then
			continue
		end
		local cf = CFrame.new(pos.X, MapService.GroundY, pos.Z)
		if i % 3 == 0 then
			Props.Rock(beach, rng, cf, rng:NextNumber(3, 5))
		else
			Props.PalmTree(beach, rng, cf)
		end
	end
	beach.Parent = arena
end

-- Lobby island ----------------------------------------------------------------------------------

local function buildLobby(parent)
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	lobby.Parent = parent
	local rng = Random.new(M.Seed + 1)
	local c, half = M.LobbyCenter, M.LobbySize / 2
	local g = MapService.GroundY
	-- Two walkable plateau tiers in the middle (like the layered plateau reference), reached by
	-- stairs on the south side; a watchtower stands on top. Tier edges sit on the 4-stud lattice.
	local tier1, tier2 = M.LobbyTier1, M.LobbyTier2
	local function classifyLobby(x, z)
		local edge = math.max(math.abs(x), math.abs(z))
		local n = noise(x + 500, z, 17)
		local coast = half + 12 + n * 8
		if edge > coast + 9 + noise(x, z, 7, 9) * 4 then
			return nil
		elseif edge > coast then
			return "Shore"
		end
		if edge > half - 4 + n * 5 then
			return "Sand"
		end
		if edge < tier2 then
			return "Plateau2"
		end
		-- tier 1 with its outer corners knocked off for a less boxy silhouette
		if edge < tier1 and not (math.abs(x) > tier1 - 4 and math.abs(z) > tier1 - 4) then
			return "Plateau1"
		end
		if math.abs(x) < 4 + n * 2 then
			return "Path"
		end
		return if noise(x, z, 12, 5) > 0.3 then "GrassLight" else "Grass"
	end
	-- no grass patches on the south walls where the stairs lean
	buildCells(lobby, Vector3.new(c.X, 0, c.Z), half + 32, classifyLobby, rng, function(x, _z, _dx, dz)
		return dz == -1 and math.abs(x - c.X) < 5
	end)

	local function surface(x, z)
		local info = CELL[classifyLobby(x, z) or "Grass"]
		return g + (info.Raise or 0)
	end
	local function at(x, z)
		return CFrame.new(c.X + x, surface(x, z), c.Z + z)
	end
	local function facing(x, z)
		local p = Vector3.new(c.X + x, surface(x, z), c.Z + z)
		return CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z))
	end

	-- stairs up the south faces (climbing toward +Z = toward the centre)
	Props.Stairs(lobby, rng, CFrame.new(c.X, g, c.Z - tier1 - 1), 2, 6)
	Props.Stairs(lobby, rng, CFrame.new(c.X, g + 2, c.Z - tier2 - 1), 2, 6)
	Props.Tower(lobby, rng, CFrame.new(c.X, g + 4, c.Z))
	for _, spot in { { -9, -9 }, { 9, -9 } } do
		Props.LampPost(lobby, rng, facing(spot[1], spot[2]))
	end
	Props.Campfire(lobby, rng, at(-13, -15))
	Props.CrateStack(lobby, rng, facing(14, -14))
	Props.Bush(lobby, rng, at(-15, 13))
	Props.Mushroom(lobby, rng, at(15, 14), true)

	Props.Stall(lobby, rng, facing(-30, 0), { Text = "CLASSES", Color = P.FlowerBlue })
	Props.Stall(lobby, rng, facing(30, 0), { Text = "WEAPONS", Color = P.Red })
	local signCf = facing(0, half - 6)
	Props.Sign(lobby, signCf * CFrame.new(0, 12, 0), "SURVIVE A MILLION ZOMBIES", 30, 7)
	for _, x in { -11, 11 } do
		Bricks.Part({ Name = "SignPost", Size = Vector3.new(2, 10, 2), CFrame = signCf * CFrame.new(x, 5, 1.8), Color = P.WoodDark, Parent = lobby })
	end
	for _, spot in { { -30, -30 }, { 30, -30 }, { -30, 30 }, { 30, 30 }, { -35, 17 }, { 35, -17 } } do
		Props.PalmTree(lobby, rng, at(spot[1], spot[2]))
	end
	for _, spot in { { -20, 30 }, { 22, 28 }, { -27, -20 }, { 27, 18 } } do
		Props.Bush(lobby, rng, at(spot[1], spot[2]))
	end
	Props.Rock(lobby, rng, at(31, -20), 5)
	Props.Log(lobby, rng, at(-24, 24))
	-- keep players on the island
	for _, spec in
		{
			{ Vector3.new(0, 0, -half - 14), Vector3.new(half * 2 + 30, 40, 2) },
			{ Vector3.new(0, 0, half + 14), Vector3.new(half * 2 + 30, 40, 2) },
			{ Vector3.new(-half - 14, 0, 0), Vector3.new(2, 40, half * 2 + 30) },
			{ Vector3.new(half + 14, 0, 0), Vector3.new(2, 40, half * 2 + 30) },
		}
	do
		Bricks.Part({ Name = "InvisibleWall", Size = spec[2], Position = c + spec[1] + Vector3.new(0, g + 20, 0), Transparency = 1, CanQuery = false, CastShadow = false, Parent = lobby })
	end
end

-- Ocean, lighting, baseplate --------------------------------------------------------------------

local function buildOcean()
	local terrain = workspace.Terrain
	terrain.WaterColor = Color3.fromRGB(40, 150, 210)
	terrain.WaterTransparency = 0.4
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8
	local top, depth = M.WaterLevel, 16
	terrain:FillBlock(CFrame.new(M.ArenaCenter.X, top - depth / 2, (M.ArenaCenter.Z + M.LobbyCenter.Z) / 2), Vector3.new(1200, depth, 1400), Enum.Material.Water)
end

local function setupLighting()
	Lighting.ClockTime = 13.5
	Lighting.Brightness = 3.2
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 165)
	Lighting.Ambient = Color3.fromRGB(95, 95, 110)
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.ShadowSoftness = 0.15
	-- Built-in dynamic clouds (fluffy daytime sky like the references; no third-party asset)
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.7
	clouds.Color = Color3.fromRGB(255, 255, 255)
	clouds.Parent = workspace.Terrain
	local function ensure(className, name)
		local inst = Lighting:FindFirstChild(name) or Instance.new(className)
		inst.Name = name
		inst.Parent = Lighting
		return inst
	end
	local atmosphere = ensure("Atmosphere", "SAMZ_Atmosphere")
	atmosphere.Density = 0.22
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(200, 225, 255)
	atmosphere.Decay = Color3.fromRGB(150, 180, 220)
	atmosphere.Glare = 0
	atmosphere.Haze = 0.4
	local bloom = ensure("BloomEffect", "SAMZ_Bloom")
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 1.8
	local cc = ensure("ColorCorrectionEffect", "SAMZ_Color")
	cc.Saturation = 0.2
	cc.Contrast = 0.08
	cc.Brightness = 0.02
	cc.TintColor = Color3.fromRGB(255, 252, 245)
	local rays = ensure("SunRaysEffect", "SAMZ_SunRays")
	rays.Intensity = 0.03
end

-- The place's default Baseplate becomes the sandy seabed under the ocean.
local function styleBaseplate()
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		Bricks.Style(baseplate)
		baseplate.Color = P.Sand
		baseplate.Position = Vector3.new(baseplate.Position.X, M.WaterLevel - 16 - baseplate.Size.Y / 2, baseplate.Position.Z)
		for _, child in baseplate:GetChildren() do
			if child:IsA("Texture") or child:IsA("Decal") then
				child.Transparency = 1
			end
		end
	end
end

-- Generates Workspace.Map from scratch (replacing any existing one) + ocean + lighting + seabed.
-- Run in EDIT mode to bake (require a CLONE of this module in Edit — Studio caches modules):
--   local m = game.ServerScriptService.Server.Services.MapService
--   local c = m:Clone(); c.Parent = m.Parent; require(c):Build(); c:Destroy()
function MapService:Build()
	local existing = workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end
	table.clear(zombiePads)
	local mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"
	mapFolder.Parent = workspace
	buildArena(mapFolder)
	task.wait()
	buildLobby(mapFolder)
	buildOcean()
	setupLighting()
	styleBaseplate()
	self:_collectPads(mapFolder)
	return mapFolder
end

function MapService:_collectPads(map)
	table.clear(zombiePads)
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "ZombieSpawn" then
			table.insert(zombiePads, d.Position)
		end
	end
	if #zombiePads == 0 then
		warn("[MapService] Workspace.Map has no parts named 'ZombieSpawn'; zombies will spawn at the arena centre")
		table.insert(zombiePads, M.ArenaCenter + Vector3.new(0, self.GroundY, 0))
	end
end

-- At server start: a baked Workspace.Map is used as-is (hand edits are kept); only generate one
-- if the place has none. Zombie spawns = every BasePart named "ZombieSpawn" inside the map.
function MapService:Init()
	local map = workspace:FindFirstChild("Map")
	if map then
		self:_collectPads(map)
	else
		self:Build()
	end
end

-- Half-size of the arena's ground cell grid. Its lattice starts at ArenaCenter - extent; the
-- NavGrid aligns to the same lattice so terrace/graveyard cell edges line up exactly.
function MapService:GetArenaCellExtent()
	return M.ArenaSize / 2 + M.BeachWidth + 24
end

function MapService:GetArenaCellOrigin()
	local extent = self:GetArenaCellExtent()
	return Vector3.new(M.ArenaCenter.X - extent, 0, M.ArenaCenter.Z - extent)
end

function MapService:GetLobbySpawnCFrame()
	local pads = ourParts("Lobby", "LobbySpawn")
	if pads then
		local pad = pads[math.random(1, #pads)]
		local offset = Vector3.new(math.random(-3, 3), pad.Size.Y / 2 + 3, math.random(-3, 3))
		return CFrame.new(pad.Position + offset) * pad.CFrame.Rotation
	end
	-- open lobby ground: outside the plateau tiers, inside the beach, away from the side stalls
	local c = M.LobbyCenter
	local pos
	for _ = 1, 50 do
		local x, z = math.random(-26, 26), math.random(-26, 26)
		local edge = math.max(math.abs(x), math.abs(z))
		if edge > M.LobbyTier1 + 2 and not (math.abs(x) > 22 and math.abs(z) < 8) then
			pos = c + Vector3.new(x, self.GroundY + 3, z)
			break
		end
	end
	pos = pos or c + Vector3.new(0, self.GroundY + 3, -M.LobbyTier1 - 6)
	return CFrame.lookAt(pos, Vector3.new(c.X, pos.Y, c.Z))
end

function MapService:GetArenaSpawnCFrame(index)
	local c = M.ArenaCenter
	local angle = (index or math.random(1, 12)) * (math.pi * 2 / 8)
	local radius = M.WellRadius + 7
	local pos = c + Vector3.new(math.cos(angle) * radius, self.GroundY + 3, math.sin(angle) * radius)
	return CFrame.lookAt(pos, Vector3.new(c.X, pos.Y, c.Z) + (pos - c) * 2) -- face outward
end

function MapService:GetZombieSpawnPosition()
	local pad = zombiePads[math.random(1, #zombiePads)]
	return Vector3.new(pad.X + math.random(-4, 4), self.GroundY, pad.Z + math.random(-4, 4))
end

return MapService
