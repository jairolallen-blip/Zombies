-- NavGrid: flow-field navigation for the zombie horde (cheap enough for 70+ zombies, unlike
-- per-zombie PathfindingService calls).
--
-- 1. Build(): scans the arena once into a grid of CellSize cells. A cell is blocked if any
--    CanCollide part (fence, terrace wall, prop...) overlaps it between knee and head height.
-- 2. A "flow field" for a target cell = walking distance from every cell to that cell (Dijkstra,
--    8 directions, no corner cutting). The map is static, so a field never changes: fields are
--    cached per target cell (LRU, MAX_FIELDS) and only computed when a player enters a new cell.
-- 3. GetDirection(from, target): step toward the neighbouring cell with the lowest distance.
-- Zombies use it only when they have no clear line to the player (see ZombieService).
--
-- Public:
--   NavGrid.Build(center, halfSize, cellSize, groundY, ignore, lattice?)
--       ignore = instances to skip in the scan; lattice = a corner of the map's ground cell grid
--       (MapService:GetNavBounds()) so nav cells line up with terrace/graveyard cells
--   NavGrid.GetDirection(fromPos, targetPos) -> unit Vector3 (flat) or nil (no grid / no route / arrived)
--   NavGrid.IsWalkable(pos) -> boolean
--   NavGrid.Stats() -> string

local NavGrid = {}

local MAX_FIELDS = 48
local DIAG = math.sqrt(2)
local NEIGHBORS = {
	{ 1, 0, 1 }, { -1, 0, 1 }, { 0, 1, 1 }, { 0, -1, 1 },
	{ 1, 1, DIAG }, { 1, -1, DIAG }, { -1, 1, DIAG }, { -1, -1, DIAG },
}

local N = 0 -- cells per side
local cs, minX, minZ, groundY = 4, 0, 0, 0
local walkable = {} -- [index] = boolean
local fields = {} -- [targetIndex] = { Dist = {...}, Used = os.clock() }
local fieldCount = 0
local built = false

local function index(i, j)
	return j * N + i + 1
end

local function cellOf(pos)
	local i = math.floor((pos.X - minX) / cs)
	local j = math.floor((pos.Z - minZ) / cs)
	if i < 0 or j < 0 or i >= N or j >= N then
		return nil
	end
	return i, j
end

local function center(i, j)
	return Vector3.new(minX + (i + 0.5) * cs, groundY, minZ + (j + 0.5) * cs)
end

-- Can we step from (i,j) by (di,dj)? Diagonals need both orthogonal cells open (no corner cutting).
local function canStep(i, j, di, dj)
	local ni, nj = i + di, j + dj
	if ni < 0 or nj < 0 or ni >= N or nj >= N or not walkable[index(ni, nj)] then
		return false
	end
	if di ~= 0 and dj ~= 0 then
		return walkable[index(i + di, j)] and walkable[index(i, j + dj)]
	end
	return true
end

function NavGrid.Build(centerPos, halfSize, cellSize, ground, ignore, lattice)
	cs = cellSize
	minX, minZ = centerPos.X - halfSize, centerPos.Z - halfSize
	if lattice then
		-- snap to the map's cell lattice so cell edges coincide with ground/terrace cell edges
		minX = lattice.X + math.floor((minX - lattice.X) / cs) * cs
		minZ = lattice.Z + math.floor((minZ - lattice.Z) / cs) * cs
	end
	N = math.ceil((centerPos.X + halfSize - minX) / cs)
	groundY = ground
	table.clear(walkable)
	table.clear(fields)
	fieldCount = 0

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	params.RespectCanCollide = true
	local blocked = 0
	for j = 0, N - 1 do
		for i = 0, N - 1 do
			local c = center(i, j)
			-- cell box (minus a hair so parts merely touching an edge don't count), from 1 stud
			-- above the floor (skips the ground) to head height
			local hits = workspace:GetPartBoundsInBox(CFrame.new(c.X, ground + 2.5, c.Z), Vector3.new(cs - 0.2, 3, cs - 0.2), params)
			local open = #hits == 0
			walkable[index(i, j)] = open
			if not open then
				blocked += 1
			end
		end
	end
	built = true
	return N * N, blocked
end

-- Dijkstra from the target cell over walkable cells (binary heap, lazy deletion).
local function computeField(ti, tj)
	local total = N * N
	local dist = table.create(total, math.huge)
	local heapCost, heapIdx = {}, {}
	local size = 0
	local function push(cost, idx)
		size += 1
		local k = size
		heapCost[k], heapIdx[k] = cost, idx
		while k > 1 do
			local parent = k // 2
			if heapCost[parent] <= heapCost[k] then
				break
			end
			heapCost[parent], heapCost[k] = heapCost[k], heapCost[parent]
			heapIdx[parent], heapIdx[k] = heapIdx[k], heapIdx[parent]
			k = parent
		end
	end
	local function pop()
		local cost, idx = heapCost[1], heapIdx[1]
		heapCost[1], heapIdx[1] = heapCost[size], heapIdx[size]
		heapCost[size], heapIdx[size] = nil, nil
		size -= 1
		local k = 1
		while true do
			local l, r, smallest = k * 2, k * 2 + 1, k
			if l <= size and heapCost[l] < heapCost[smallest] then
				smallest = l
			end
			if r <= size and heapCost[r] < heapCost[smallest] then
				smallest = r
			end
			if smallest == k then
				break
			end
			heapCost[smallest], heapCost[k] = heapCost[k], heapCost[smallest]
			heapIdx[smallest], heapIdx[k] = heapIdx[k], heapIdx[smallest]
			k = smallest
		end
		return cost, idx
	end

	local start = index(ti, tj)
	dist[start] = 0
	push(0, start)
	while size > 0 do
		local cost, idx = pop()
		if cost <= dist[idx] then
			local i, j = (idx - 1) % N, (idx - 1) // N
			for _, nb in NEIGHBORS do
				if canStep(i, j, nb[1], nb[2]) then
					local nIdx = index(i + nb[1], j + nb[2])
					local nCost = cost + nb[3]
					if nCost < dist[nIdx] then
						dist[nIdx] = nCost
						push(nCost, nIdx)
					end
				end
			end
		end
	end
	return dist
end

local function getField(ti, tj)
	local key = index(ti, tj)
	local entry = fields[key]
	if not entry then
		if fieldCount >= MAX_FIELDS then
			local oldestKey, oldest = nil, math.huge
			for k, e in fields do
				if e.Used < oldest then
					oldestKey, oldest = k, e.Used
				end
			end
			fields[oldestKey] = nil
			fieldCount -= 1
		end
		entry = { Dist = computeField(ti, tj) }
		fields[key] = entry
		fieldCount += 1
	end
	entry.Used = os.clock()
	return entry.Dist
end

function NavGrid.GetDirection(fromPos, targetPos)
	if not built then
		return nil
	end
	local ti, tj = cellOf(targetPos)
	local fi, fj = cellOf(fromPos)
	if not ti or not fi then
		return nil
	end
	local dist = getField(ti, tj)
	local best, bestCost = nil, dist[index(fi, fj)]
	for _, nb in NEIGHBORS do
		if canStep(fi, fj, nb[1], nb[2]) then
			local nIdx = index(fi + nb[1], fj + nb[2])
			if dist[nIdx] < bestCost then
				best, bestCost = nb, dist[nIdx]
			end
		end
	end
	if not best then
		return nil
	end
	local step = center(fi + best[1], fj + best[2]) - fromPos
	step = Vector3.new(step.X, 0, step.Z)
	if step.Magnitude < 0.05 then
		return nil
	end
	return step.Unit
end

function NavGrid.IsWalkable(pos)
	local i, j = cellOf(pos)
	return i ~= nil and walkable[index(i, j)] == true
end

function NavGrid.Stats()
	local blocked = 0
	for _, open in walkable do
		if not open then
			blocked += 1
		end
	end
	return string.format("NavGrid %dx%d cells of %d studs, %d blocked, %d cached fields", N, N, cs, blocked, fieldCount)
end

return NavGrid
