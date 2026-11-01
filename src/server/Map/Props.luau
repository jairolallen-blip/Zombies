-- Props: library of stud-style prop builders (see docs/ART_STYLE.md). Every function builds a Model
-- from studded bricks (Shared/Bricks.lua), parents it, and returns it.
--
-- Conventions:
--   * `cf` is a CFrame AT GROUND LEVEL (bottom centre of the prop). LookVector = the prop's front.
--   * `rng` is a Random — the same seed always builds the same prop (stable baked maps).
--   * Chunky masses (walls, canopies, rocks, panels) use whole-stud faces so their studs line up.
--     DETAILS use 1/2, 1/4, 1/8 stud parts (timbers, trims, bars, hinges, plates) — Bricks renders
--     any fractional face smooth, so fine detail reads as clean trim with no cut-off studs.
--   * NO z-fighting: overlapping parts never share a plane facing the same way. Trims sit +0.2/+0.25
--     proud of the surface under them; stacked parts only touch top-to-bottom; parts that overlap
--     get different yaw/heights. Verify with tools/zfight.luau after changes.
--   * Foliage/roofs that players walk under use CanCollide=false; solid bodies collide.
--
-- Catalogue:
--   Tree(parent, rng, cf, opts?)            stepped-canopy voxel tree; opts.Big, opts.Colors, opts.TrunkColor
--   AutumnTree(parent, rng, cf)             orange/red canopy variant
--   DeadTree(parent, rng, cf)               bare spooky branches
--   PineTree(parent, rng, cf)               stacked shrinking needle tiers
--   PalmTree(parent, rng, cf)               thick twisted ring trunk + long drooping fronds
--   Mushroom(parent, rng, cf, big?)         red spotted toadstool
--   Flowers(parent, rng, cf)                small stem + bloom cluster (decor, no collision)
--   Rock(parent, rng, cf, size?)            stacked angular stone chunks (+ moss sometimes)
--   Bush(parent, rng, cf, flowers?)         2–4 leafy cubes, optional flower dots
--   Crate(parent, rng, cf, size?)           framed crate: 12 trimmed edges, recessed panels, X on 4 sides
--   CrateStack(parent, rng, cf)             2–3 crates
--   Log(parent, rng, cf)                    fallen square log
--   Fence(parent, rng, a, b, opts?)         posts every 4 studs + 2 rails, a..b ground points; opts.Color, opts.Broken
--   Tombstone / Cross / Grave / Bones / Stake(parent, rng, cf)
--   Graveyard(parent, rng, center, radius, outward)   graves/bones/stakes/tree around a spot (non-overlapping)
--   Well(parent, rng, cf)                   stone well with striped roof
--   Stall(parent, rng, cf, opts?)           market stall; opts.Text, opts.Color (awning stripe colour)
--   Sign(parent, cf, text, width, height)   plank board + frame, chunky text (cf = board centre)
--   Stairs(parent, rng, cf, steps, width)   wooden steps climbing toward +Z with stone cube posts
--   Cottage(parent, rng, cf, width, depth)  stone base, plaster walls, timber frame, gable roof, chimney
--   Tower(parent, rng, cf)                  landmark watchtower
--   LampPost(parent, rng, cf)               post + arm + glowing lantern cube
--   Campfire(parent, rng, cf)
--   Scatter(parent, rng, center, radius, count, colors)   loose flat stud tiles (decor)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local B = require(ReplicatedStorage:WaitForChild("Shared").Bricks)
local P = B.Palette

local Props = {}

local function newModel(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function brick(model, name, size, cf, color, extra)
	local props = { Name = name, Size = size, CFrame = cf, Color = color, Parent = model }
	if extra then
		for k, v in extra do
			props[k] = v
		end
	end
	return B.Part(props)
end

local function wedge(model, name, size, cf, color, extra)
	local props = { Name = name, Size = size, CFrame = cf, Color = color, Parent = model }
	if extra then
		for k, v in extra do
			props[k] = v
		end
	end
	return B.Wedge(props)
end

local NO_COLLIDE = { CanCollide = false }
local DECOR = { CanCollide = false, CanQuery = false, CastShadow = false }
local AUTUMN = { Color3.fromRGB(230, 130, 50), Color3.fromRGB(210, 90, 45), Color3.fromRGB(240, 170, 60), Color3.fromRGB(190, 70, 50) }

local function yaw(a)
	return CFrame.Angles(0, a, 0)
end

-- Loose props get a tiny lift from a rotating set of 9 heights (0.03..0.27). Whole-stud sizing puts
-- every top/bottom face at whole-stud heights, so two props that touch would otherwise share
-- horizontal planes; props built one after another (= usually neighbours) always differ.
local liftSlot = 0
local function lift(_rng, cf)
	liftSlot = (liftSlot % 9) + 1
	return cf * CFrame.new(0, liftSlot * 0.03, 0)
end

-- Foliage ---------------------------------------------------------------------------------------

-- Stepped canopy (layers of different widths, like the references) + rotated side clusters.
function Props.Tree(parent, rng, cf, opts)
	opts = opts or {}
	local m = newModel("Tree", parent)
	cf = lift(rng, cf) * yaw(rng:NextNumber(0, math.pi * 2))
	local big = if opts.Big ~= nil then opts.Big else rng:NextNumber() < 0.4
	local trunkH = rng:NextInteger(6, 8) + (if big then 2 else 0)
	local tw = if big then 3 else 2
	brick(m, "Root", Vector3.new(tw + 2, 1, tw + 2), cf * CFrame.new(0, 0.5, 0) * yaw(math.rad(45)), P.WoodDark)
	brick(m, "Trunk", Vector3.new(tw, trunkH, tw), cf * CFrame.new(0, 1 + trunkH / 2, 0), opts.TrunkColor or P.Wood)
	if rng:NextNumber() < 0.6 then
		local branch = cf * CFrame.new(0, 1 + trunkH * 0.6, 0) * yaw(rng:NextNumber(0, math.pi * 2)) * CFrame.Angles(math.rad(40), 0, 0)
		brick(m, "Branch", Vector3.new(1, 1, 3), branch * CFrame.new(0, 0, -(tw / 2 + 1)), opts.TrunkColor or P.Wood)
	end

	local colors = opts.Colors or B.LeafColors
	local main = B.Pick(rng, colors)
	local W = if big then 11 else 8
	-- canopy starts on a half-stud so its layer tops never coincide with the trunk top
	local y0 = trunkH + 0.5
	local y = y0
	-- underside steps -> bulk -> rounded top; all widths differ, so no side faces share a plane
	local layers = { { W - 4, 1 }, { W - 2, 1 }, { W, 3 }, { W - 1, 2 }, { W - 3, 1 } }
	for k, layer in layers do
		local h = layer[2]
		brick(m, "Leaves", Vector3.new(layer[1], h, layer[1]), cf * CFrame.new(0, y + h / 2, 0), B.Shade(main, (k - 3) * 0.04), NO_COLLIDE)
		y += h
	end
	-- side clusters: distinct yaw each, tops at y0 + n + 0.4 + i*0.07 (never on a layer boundary)
	for i = 1, rng:NextInteger(2, 4) do
		local size = rng:NextInteger(4, if big then 6 else 5)
		local a = (i / 4) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local r = W / 2 - 0.5
		local topY = y0 + rng:NextInteger(3, 6) + 0.4 + i * 0.07
		brick(m, "Leaves", Vector3.new(size, size - 1, size), cf * CFrame.new(math.cos(a) * r, topY - (size - 1) / 2, math.sin(a) * r) * yaw(a + math.rad(17 * i)), B.Shade(main, rng:NextNumber(-0.1, 0.1)), NO_COLLIDE)
	end
	return m
end

function Props.AutumnTree(parent, rng, cf)
	local m = Props.Tree(parent, rng, cf, { Colors = AUTUMN, TrunkColor = P.WoodDark })
	m.Name = "AutumnTree"
	return m
end

function Props.DeadTree(parent, rng, cf)
	local m = newModel("DeadTree", parent)
	cf = cf * yaw(rng:NextNumber(0, math.pi * 2))
	local h = rng:NextInteger(8, 11)
	brick(m, "Trunk", Vector3.new(2, h, 2), cf * CFrame.new(0, h / 2, 0) * B.Jitter(rng, 6), P.WoodDark)
	for i = 1, rng:NextInteger(3, 4) do
		local y = h * rng:NextNumber(0.5, 0.95)
		local len = rng:NextInteger(3, 4)
		local branch = cf * CFrame.new(0, y, 0) * yaw((i / 4) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)) * CFrame.Angles(math.rad(rng:NextNumber(30, 55)), 0, 0)
		brick(m, "Branch", Vector3.new(1, 1, len), branch * CFrame.new(0, 0, -(1 + len / 2)), P.WoodDark)
		brick(m, "Twig", Vector3.new(1, 1, 2), branch * CFrame.new(0, 0, -(1 + len)) * CFrame.Angles(math.rad(35), 0, 0) * CFrame.new(0, 0, -1), P.Wood)
	end
	return m
end

function Props.PineTree(parent, rng, cf)
	local m = newModel("PineTree", parent)
	cf = lift(rng, cf) * yaw(rng:NextNumber(0, math.pi * 2))
	local trunkH = rng:NextInteger(3, 4)
	brick(m, "Trunk", Vector3.new(2, trunkH, 2), cf * CFrame.new(0, trunkH / 2, 0), P.WoodDark)
	local color = B.Pick(rng, { P.LeafDark, P.LeafDark, P.Leaf })
	local y = trunkH - 0.5 -- half-stud offset: tier faces never land on whole-stud heights
	local widths = { 9, 7, 5, 3 }
	for tier, w in widths do
		brick(m, "Needles", Vector3.new(w, 2, w), cf * CFrame.new(0, y + 1, 0) * yaw(math.rad(tier * 15)), B.Shade(color, (tier - 2) * 0.05), NO_COLLIDE)
		y += 2
	end
	brick(m, "Tip", Vector3.new(1, 2, 1), cf * CFrame.new(0, y + 1, 0) * yaw(math.rad(70)), color, NO_COLLIDE)
	return m
end

-- Thick trunk of twisted rings leaning one way; fronds = 3 chunky segments curving down.
function Props.PalmTree(parent, rng, cf)
	local m = newModel("PalmTree", parent)
	cf = cf * yaw(rng:NextNumber(0, math.pi * 2))
	local seg = cf
	local widths = { 5, 4, 4, 4, 3, 3, 3, 3 }
	for i, w in widths do
		brick(m, "Trunk", Vector3.new(w, 2, w), seg * CFrame.new(0, 1, 0), if i % 2 == 0 then P.Wood else B.Shade(P.Wood, -0.1))
		seg = seg * CFrame.new(0.5, 2, 0) * CFrame.Angles(0, math.rad(9), -math.rad(3))
	end
	brick(m, "Crown", Vector3.new(3, 2, 3), seg * CFrame.new(0, 1, 0) * yaw(math.rad(30)), P.PalmLeaf, NO_COLLIDE)
	-- 5 fronds (odd): no two are exactly opposite, so their side faces never share a plane
	for i = 1, 5 do
		local frond = seg * CFrame.new(0, 1.6 + i * 0.07, 0) * yaw((i / 5) * math.pi * 2 + rng:NextNumber(-0.25, 0.25)) * CFrame.Angles(math.rad(12), 0, 0)
		local color = if i % 2 == 0 then P.PalmLeaf else P.Leaf
		local widths2, lengths = { 4, 3, 2 }, { 5, 5, 4 } -- distinct widths: segment sides never share a plane
		for k = 1, 3 do
			brick(m, "Frond", Vector3.new(widths2[k], 1, lengths[k]), frond * CFrame.new(0, 0, -lengths[k] / 2), B.Shade(color, (k - 2) * 0.06), NO_COLLIDE)
			frond = frond * CFrame.new(0, 0, -lengths[k]) * CFrame.Angles(math.rad(-28), 0, 0)
		end
	end
	for i = 1, rng:NextInteger(2, 3) do
		brick(m, "Coconut", Vector3.new(0.75, 0.75, 0.75), seg * CFrame.new((i - 2) * 1.2, -0.4 - i * 0.13, rng:NextNumber(-0.8, 0.8)) * yaw(i * 0.6), P.WoodDark, NO_COLLIDE)
	end
	return m
end

function Props.Mushroom(parent, rng, cf, big)
	local m = newModel("Mushroom", parent)
	cf = lift(rng, cf) * yaw(rng:NextNumber(0, math.pi * 2))
	big = if big ~= nil then big else rng:NextNumber() < 0.35
	local stemW, stemH, capW, capH, topW = 1, 2, 4, 1, 2
	if big then
		stemW, stemH, capW, capH, topW = 2, 3, 6, 2, 4
	end
	brick(m, "Stem", Vector3.new(stemW, stemH, stemW), cf * CFrame.new(0, stemH / 2, 0), P.Plaster)
	brick(m, "Cap", Vector3.new(capW, capH, capW), cf * CFrame.new(0, stemH + capH / 2, 0), P.Red)
	brick(m, "CapTop", Vector3.new(topW, 1, topW), cf * CFrame.new(0, stemH + capH + 0.5, 0), P.Red)
	-- white spot plates on the cap's top corners (outside the CapTop footprint) and sides
	local r = (capW + topW) / 4
	for _, s in { { 1, 1 }, { -1, -1 }, { 1, -1 } } do
		brick(m, "Spot", Vector3.new(0.5, 0.25, 0.5), cf * CFrame.new(s[1] * r, stemH + capH + 0.125, s[2] * r), P.White, NO_COLLIDE)
	end
	for k = 0, 1 do
		brick(m, "SideSpot", Vector3.new(0.5, 0.5, 0.125), cf * yaw(k * math.pi) * CFrame.new(0, stemH + capH / 2, -(capW / 2 + 0.0625)), P.White, NO_COLLIDE)
	end
	return m
end

function Props.Flowers(parent, rng, cf)
	local m = newModel("Flowers", parent)
	cf = lift(rng, cf)
	local color = B.Pick(rng, B.FlowerColors)
	for i = 1, rng:NextInteger(3, 5) do
		local a = (i / 5) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local off = Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(0.6, 1.8)
		local h = rng:NextInteger(1, 2) + 0.15 + i * 0.04 -- stems are smooth anyway; off-grid heights
		brick(m, "Stem", Vector3.new(0.25, h, 0.25), cf * CFrame.new(off + Vector3.new(0, h / 2 + 0.03, 0)) * yaw(a), P.LeafDark, DECOR)
		brick(m, "Bloom", Vector3.new(0.75, 0.5, 0.75), cf * CFrame.new(off + Vector3.new(0, h + 0.28 + i * 0.03, 0)) * yaw(a + 0.4), color, DECOR)
		brick(m, "BloomCore", Vector3.new(0.25, 0.125, 0.25), cf * CFrame.new(off + Vector3.new(0, h + 0.6 + i * 0.03, 0)) * yaw(a + 0.4), P.Yellow, DECOR)
	end
	return m
end

function Props.Bush(parent, rng, cf, flowers)
	local m = newModel("Bush", parent)
	cf = lift(rng, cf)
	local color = B.Pick(rng, { P.LeafDark, P.Leaf, P.GrassDark, P.LeafLime })
	local tops = {}
	for i = 1, rng:NextInteger(2, 4) do
		local size = rng:NextInteger(2, 4)
		local a = rng:NextNumber(0, math.pi * 2)
		local offset = Vector3.new(math.cos(a) * rng:NextNumber(0, 1.6), size / 2 + i * 0.03, math.sin(a) * rng:NextNumber(0, 1.6))
		local cube = cf * CFrame.new(offset) * yaw(math.rad(23 * i) + rng:NextNumber(-0.15, 0.15))
		brick(m, "Leaves", Vector3.new(size, size, size), cube, B.Shade(color, rng:NextNumber(-0.1, 0.1)))
		table.insert(tops, { cube, size })
	end
	if flowers ~= false and rng:NextNumber() < 0.7 then
		local flower = B.Pick(rng, B.FlowerColors)
		for k, t in tops do
			-- one flower dot on a side face of each cube (proud by 0.15)
			local cube, size = t[1], t[2]
			brick(m, "Flower", Vector3.new(0.5, 0.5, 0.125), cube * yaw((k % 4) * math.pi / 2) * CFrame.new(0.5, size / 2 - 0.75, -(size / 2 + 0.0625)), flower, NO_COLLIDE)
			brick(m, "Flower", Vector3.new(0.5, 0.5, 0.125), cube * yaw((k % 4) * math.pi / 2) * CFrame.new(-0.5, size / 2 - 1.5, -(size / 2 + 0.0625)), flower, NO_COLLIDE)
		end
	end
	return m
end

-- Stone & wood ----------------------------------------------------------------------------------

function Props.Rock(parent, rng, cf, size)
	size = math.max(3, math.floor(size or rng:NextInteger(4, 7)))
	local m = newModel("Rock", parent)
	cf = lift(rng, cf)
	local y, s = 0, size
	for i = 1, rng:NextInteger(2, 4) do
		local h = math.max(1, math.floor(s * rng:NextNumber(0.45, 0.7)))
		local offset = Vector3.new(rng:NextNumber(-0.25, 0.25) * s, y + h / 2 + i * 0.05, rng:NextNumber(-0.25, 0.25) * s)
		local color = if i == 1 then P.StoneDark else B.Pick(rng, { P.Stone, P.StoneLight, P.Stone })
		brick(m, "Rock", Vector3.new(s, h, math.max(2, s - rng:NextInteger(0, 1))), cf * CFrame.new(offset) * yaw(rng:NextNumber(0, math.pi)) * B.Jitter(rng, 18), color)
		y += h * 0.8
		s = math.max(2, s - rng:NextInteger(1, 2))
	end
	if rng:NextNumber() < 0.6 then
		local c = math.max(2, math.floor(size * 0.4))
		brick(m, "Chunk", Vector3.new(c, c - 1, c), cf * CFrame.new(size * 0.6, (c - 1) / 2 + 0.13, rng:NextNumber(-1, 1)) * yaw(rng:NextNumber(0, math.pi)) * B.Jitter(rng, 25), P.Stone)
	end
	if rng:NextNumber() < 0.4 then
		brick(m, "Moss", Vector3.new(math.max(2, size - 2), 0.4, math.max(2, size - 3)), cf * CFrame.new(0, y + 0.17, 0) * yaw(rng:NextNumber(0, math.pi)), P.GrassDark, NO_COLLIDE)
	end
	return m
end

-- Framed crate (reference: dark trim on every edge, lighter recessed panel, X brace on each side).
-- size = whole studs >= 3. 1/2-stud trim on all 12 edges, flush with the outer box; studded
-- (size-1)x(size-1) panels sit 1/4 deep; each X = two 0.4-wide planks at different depths.
function Props.Crate(parent, rng, cf, size)
	size = math.max(3, math.floor(size or 4))
	local m = newModel("Crate", parent)
	cf = lift(rng, cf)
	local s, h, t = size, size / 2, 0.5
	local c = cf * CFrame.new(0, h, 0)
	local inner = s - 2 * t -- whole studs, so the panels keep their studs
	local frameColor = B.Shade(P.CrateFrame, rng:NextNumber(-0.05, 0.05))
	local panelColor = B.Shade(P.CratePanel, rng:NextNumber(-0.05, 0.05))
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			brick(m, "Post", Vector3.new(t, s, t), c * CFrame.new(x * (h - t / 2), 0, z * (h - t / 2)), frameColor)
		end
	end
	local diag = inner * math.sqrt(2) - 0.6
	for side = 0, 3 do
		local face = c * yaw(side * math.pi / 2)
		for _, y in { -1, 1 } do
			brick(m, "Beam", Vector3.new(inner, t, t), face * CFrame.new(0, y * (h - t / 2), -(h - t / 2)), frameColor)
		end
		brick(m, "Panel", Vector3.new(inner, inner, 0.24), face * CFrame.new(0, 0, -(h - 0.37)), panelColor)
		brick(m, "Brace", Vector3.new(diag, 0.4, 0.15), face * CFrame.new(0, 0, -(h - 0.175)) * CFrame.Angles(0, 0, math.rad(45)), frameColor)
		brick(m, "Brace", Vector3.new(diag, 0.4, 0.08), face * CFrame.new(0, 0, -(h - 0.17)) * CFrame.Angles(0, 0, math.rad(-45)), frameColor)
	end
	brick(m, "Panel", Vector3.new(inner, 0.24, inner), c * CFrame.new(0, h - 0.37, 0), panelColor)
	brick(m, "Panel", Vector3.new(inner, 0.24, inner), c * CFrame.new(0, -(h - 0.37), 0), panelColor)
	return m
end

function Props.CrateStack(parent, rng, cf)
	local m = newModel("CrateStack", parent)
	Props.Crate(m, rng, cf * CFrame.new(-2.2, 0, 0) * yaw(rng:NextNumber(-0.12, 0.12)), 4)
	Props.Crate(m, rng, cf * CFrame.new(2.2, 0, 0.5) * yaw(rng:NextNumber(0.15, 0.3)), 4)
	if rng:NextNumber() < 0.7 then
		Props.Crate(m, rng, cf * CFrame.new(0, 4, 0.2) * yaw(rng:NextNumber(0.4, 0.7)), 3)
	end
	return m
end

function Props.Log(parent, rng, cf)
	local m = newModel("Log", parent)
	local len = rng:NextInteger(6, 9)
	brick(m, "Log", Vector3.new(2, 2, len), lift(rng, cf) * yaw(rng:NextNumber(0, math.pi)) * CFrame.new(0, 1, 0), P.Wood)
	return m
end

-- Fence from ground point a to b: posts every 4 studs (+ one at the end), two 1x1 rails between
-- post faces. Rails touch posts end-to-side only (no overlap). opts.Broken = chance a rail is
-- missing or fallen.
function Props.Fence(parent, rng, a, b, opts)
	opts = opts or {}
	local m = newModel("Fence", parent)
	local color = opts.Color or P.WoodRed
	local broken = opts.Broken or 0.12
	local length = (b - a).Magnitude
	if length < 2 then
		return m
	end
	local base = CFrame.lookAt(a, Vector3.new(b.X, a.Y, b.Z))
	local stations = {}
	for d = 0, length - 1, 4 do
		table.insert(stations, d)
	end
	if length - stations[#stations] >= 2 then
		table.insert(stations, length)
	end
	-- 3/4 posts with a 1x1/2 cap; 1/2 x 1/2 rails run between post faces (centred, so their sides
	-- sit 1/8 inside the post faces and never share a plane)
	for _, d in stations do
		brick(m, "Post", Vector3.new(0.75, 3, 0.75), base * CFrame.new(0, 1.5, -d), color)
		brick(m, "Cap", Vector3.new(1, 0.5, 1), base * CFrame.new(0, 3.25, -d), B.Shade(color, 0.15))
	end
	for k = 1, #stations - 1 do
		local gap = stations[k + 1] - stations[k] - 0.75
		if gap >= 1 then
			local mid = base * CFrame.new(0, 0, -(stations[k] + stations[k + 1]) / 2)
			for _, y in { 1.25, 2.5 } do
				local roll = rng:NextNumber()
				if roll < broken * 0.5 then
					continue -- missing rail
				elseif roll < broken then
					brick(m, "Rail", Vector3.new(0.5, 0.5, gap), mid * CFrame.new(if y > 2 then -0.9 else 0.9, 0.37, 0) * CFrame.Angles(math.rad(rng:NextNumber(-15, 15)), rng:NextNumber(-0.4, 0.4), 0), B.Shade(color, -0.1))
				else
					brick(m, "Rail", Vector3.new(0.5, 0.5, gap), mid * CFrame.new(0, y, 0), B.Shade(color, -0.1))
				end
			end
		end
	end
	return m
end

-- Graveyard pieces (all whole-stud, stacked so parts only touch top-to-bottom) ----------------

-- Stepped plinth, studded 3x3 slab, stepped rounded top, engraved cross plate (1/8 proud).
function Props.Tombstone(parent, rng, cf)
	local m = newModel("Tombstone", parent)
	cf = lift(rng, cf) * B.Jitter(rng, 10)
	local color = B.Pick(rng, { P.Stone, P.StoneLight, P.Stone })
	brick(m, "Plinth", Vector3.new(4, 0.5, 2), cf * CFrame.new(0, 0.25, 0), P.StoneDark)
	brick(m, "Plinth2", Vector3.new(3.5, 0.5, 1.5), cf * CFrame.new(0, 0.75, 0), P.StoneLight)
	brick(m, "Slab", Vector3.new(3, 3, 0.75), cf * CFrame.new(0, 2.5, 0), color)
	brick(m, "Shoulder", Vector3.new(2, 0.5, 0.75), cf * CFrame.new(0, 4.25, 0), color)
	brick(m, "Crown", Vector3.new(1, 0.5, 0.75), cf * CFrame.new(0, 4.75, 0), color)
	-- engraved cross: vertical bar + two half arms (so nothing overlaps in the same plane)
	local ink = B.Shade(color, -0.25)
	brick(m, "Engrave", Vector3.new(0.25, 1.5, 0.125), cf * CFrame.new(0, 2.6, -0.4375), ink, NO_COLLIDE)
	for _, x in { -1, 1 } do
		brick(m, "Engrave", Vector3.new(0.375, 0.25, 0.125), cf * CFrame.new(x * 0.3125, 2.85, -0.4375), ink, NO_COLLIDE)
	end
	if rng:NextNumber() < 0.5 then
		brick(m, "Moss", Vector3.new(1, 0.25, 0.75), cf * CFrame.new(rng:NextNumber(-0.8, 0.8), 1.15, -0.5) * yaw(0.1), P.GrassDark, NO_COLLIDE)
	end
	return m
end

function Props.Cross(parent, rng, cf)
	local m = newModel("Cross", parent)
	cf = lift(rng, cf) * B.Jitter(rng, 12)
	brick(m, "Base", Vector3.new(2.5, 0.5, 1.5), cf * CFrame.new(0, 0.25, 0), P.StoneDark)
	brick(m, "Base2", Vector3.new(1.5, 0.5, 1), cf * CFrame.new(0, 0.75, 0), P.StoneLight)
	brick(m, "Upright", Vector3.new(0.75, 4.5, 0.75), cf * CFrame.new(0, 3.25, 0), P.StoneLight)
	for _, x in { -1, 1 } do
		brick(m, "Arm", Vector3.new(1, 0.75, 0.75), cf * CFrame.new(x * 0.875, 4.125, 0), P.StoneLight) -- beside the upright
	end
	return m
end

function Props.Grave(parent, rng, cf)
	local m = newModel("Grave", parent)
	cf = lift(rng, cf) * B.Jitter(rng, 8)
	brick(m, "Mound", Vector3.new(3, 0.75, 6), cf * CFrame.new(0, 0.375, 0), P.DirtDark)
	if rng:NextNumber() < 0.65 then
		local coffin = cf * CFrame.new(0, 0.75, 0) * yaw(rng:NextNumber(-0.15, 0.15))
		brick(m, "Coffin", Vector3.new(2, 0.75, 4), coffin * CFrame.new(0, 0.375, 0.25), P.WoodLight)
		brick(m, "CoffinHead", Vector3.new(1.5, 0.75, 1), coffin * CFrame.new(0, 0.375, -2.25), P.WoodLight)
		brick(m, "Lid", Vector3.new(1.5, 0.25, 3), coffin * CFrame.new(0, 0.875, 0.25), P.Wood)
	end
	return m
end

function Props.Bones(parent, rng, cf)
	local m = newModel("Bones", parent)
	cf = lift(rng, cf) * yaw(rng:NextNumber(0, math.pi * 2))
	brick(m, "Shaft", Vector3.new(0.5, 0.5, 2.5), cf * CFrame.new(0, 0.25, 0), P.Bone, DECOR)
	for _, z in { -1, 1 } do
		for _, x in { -1, 1 } do
			brick(m, "Knob", Vector3.new(0.5, 0.625, 0.5), cf * CFrame.new(x * 0.375, 0.3125, z * 1.5), P.Bone, DECOR)
		end
	end
	return m
end

function Props.Stake(parent, rng, cf)
	local m = newModel("Stake", parent)
	local h = rng:NextInteger(2, 3) * 0.5
	brick(m, "Stake", Vector3.new(0.5, h, 0.5), cf * CFrame.new(0, h / 2, 0) * B.Jitter(rng, 20), P.Wood)
	return m
end

-- Non-overlapping graves/bones/stakes around `center`, biased to the `outward` side (away from the
-- play area) so zombies spawning at the centre have an open route into the arena.
-- isValid(pos) (optional) rejects spots, e.g. off the graveyard dirt / inside the terrace.
function Props.Graveyard(parent, rng, center, radius, outward, isValid)
	local m = newModel("Graveyard", parent)
	local items = { Props.Tombstone, Props.Cross, Props.Grave, Props.Tombstone, Props.Grave, Props.Tombstone, Props.Cross }
	local baseYaw = math.atan2(-outward.X, -outward.Z)
	local placed = {}
	local function spot(minDist, spacing)
		for _ = 1, 30 do
			local a = baseYaw + rng:NextNumber(-1.9, 1.9)
			local dist = rng:NextNumber(minDist, radius - 1)
			local pos = center + Vector3.new(-math.sin(a) * dist, 0, -math.cos(a) * dist)
			local ok = isValid == nil or isValid(pos)
			for _, p in placed do
				if (p - pos).Magnitude < spacing then
					ok = false
					break
				end
			end
			if ok then
				table.insert(placed, pos)
				return pos
			end
		end
		return nil
	end
	for _, build in items do
		local pos = spot(6, 5.5)
		if pos then
			build(m, rng, CFrame.lookAt(pos, pos - outward))
		end
	end
	for _ = 1, 3 do
		local pos = spot(4, 5)
		if pos then
			Props.Bones(m, rng, CFrame.new(pos))
		end
	end
	for _ = 1, 4 do
		local pos = spot(radius - 3, 2.5)
		if pos then
			Props.Stake(m, rng, CFrame.new(pos))
		end
	end
	local treePos = spot(radius - 4, 6)
	if treePos then
		if rng:NextNumber() < 0.5 then
			Props.DeadTree(m, rng, CFrame.new(treePos))
		else
			Props.AutumnTree(m, rng, CFrame.new(treePos))
		end
	end
	return m
end

-- Structures ------------------------------------------------------------------------------------

-- Plank board (alternating plank shades) inside a 1/2-stud frame; text on an invisible front plate.
function Props.Sign(parent, cf, text, width, height)
	local m = newModel("Sign", parent)
	width, height = math.floor(width), math.floor(height)
	for row = 0, height - 1 do
		brick(m, "Plank", Vector3.new(width, 1, 0.75), cf * CFrame.new(0, -height / 2 + row + 0.5, 0), if row % 2 == 0 then P.Wood else B.Shade(P.Wood, 0.1))
	end
	for _, y in { -1, 1 } do
		brick(m, "Frame", Vector3.new(width + 1, 0.5, 1), cf * CFrame.new(0, y * (height / 2 + 0.25), 0), P.WoodDark)
	end
	for _, x in { -1, 1 } do
		brick(m, "Frame", Vector3.new(0.5, height, 1), cf * CFrame.new(x * (width / 2 + 0.25), 0, 0), P.WoodDark)
	end
	-- nail heads in the frame corners
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			brick(m, "Nail", Vector3.new(0.25, 0.25, 0.125), cf * CFrame.new(x * (width / 2 + 0.25), y * (height / 2 + 0.25), -0.5625), P.StoneLight, { Smooth = true, CanCollide = false })
		end
	end
	local plate = brick(m, "TextPlate", Vector3.new(width, height, 0.1), cf * CFrame.new(0, 0, -0.45), Color3.new(), { Transparency = 1, CanCollide = false, CanQuery = false, Smooth = true })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.3
	gui.MaxDistance = 250
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(30, 20, 15)
	stroke.Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.1, 0)
	pad.PaddingBottom = UDim.new(0.1, 0)
	pad.Parent = label
	label.Parent = gui
	gui.Parent = plate
	return m
end

function Props.Well(parent, rng, cf)
	local m = newModel("Well", parent)
	for _, z in { -1, 1 } do
		brick(m, "Wall", Vector3.new(6, 3, 1), cf * CFrame.new(0, 1.5, z * 2.5), P.Stone)
		brick(m, "Wall", Vector3.new(1, 3, 4), cf * CFrame.new(z * 2.5, 1.5, 0), P.Stone)
	end
	-- 1/2-stud coping on top of the ring, overhanging 1/4
	for _, z in { -1, 1 } do
		brick(m, "Coping", Vector3.new(6.5, 0.5, 1.5), cf * CFrame.new(0, 3.25, z * 2.5), P.StoneLight)
		brick(m, "Coping", Vector3.new(1.5, 0.5, 3.5), cf * CFrame.new(z * 2.5, 3.25, 0), P.StoneLight)
	end
	for _, x in { -1, 1 } do
		brick(m, "Post", Vector3.new(0.5, 5.5, 0.5), cf * CFrame.new(x * 2.5, 3.5 + 2.75, 0), P.WoodDark)
	end
	brick(m, "Axle", Vector3.new(4.5, 0.25, 0.25), cf * CFrame.new(0, 7.5, 0), P.WoodDark, { CanCollide = false })
	brick(m, "Rope", Vector3.new(0.125, 2.5, 0.125), cf * CFrame.new(0, 6.125, 0), P.Tan, { Smooth = true, CanCollide = false })
	brick(m, "Bucket", Vector3.new(0.75, 0.75, 0.75), cf * CFrame.new(0, 4.5, 0) * yaw(0.4), P.Wood, NO_COLLIDE)
	brick(m, "BucketRim", Vector3.new(0.875, 0.125, 0.875), cf * CFrame.new(0, 4.9, 0) * yaw(0.4), P.StoneDark, { Smooth = true, CanCollide = false })
	brick(m, "Water", Vector3.new(4, 0.3, 4), cf * CFrame.new(0, 2.4, 0), P.Water, { Smooth = true, Material = Enum.Material.Glass, Transparency = 0.2, CanCollide = false })
	-- striped gable roof: 4 x 2-stud segments per side, alternating colours, 1/2-stud ridge
	local roofY = 9 + 0.5
	for side = -1, 1, 2 do
		for k = 0, 3 do
			local color = if (k + (side + 1) / 2) % 2 == 0 then P.RoofRed else P.White
			wedge(m, "Roof", Vector3.new(2, 1.5, 2.5), cf * CFrame.new(-3 + k * 2, roofY - 0.25, side * 1.25) * yaw(if side == -1 then 0 else math.pi), color, NO_COLLIDE)
		end
	end
	brick(m, "Ridge", Vector3.new(8.5, 0.5, 0.5), cf * CFrame.new(0, roofY + 0.75, 0), P.WoodDark, NO_COLLIDE)
	return m
end

function Props.Stall(parent, rng, cf, opts)
	opts = opts or {}
	local m = newModel("Stall", parent)
	local w, d = 10, 6
	local stripe = opts.Color or B.Pick(rng, B.AwningColors)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			brick(m, "Post", Vector3.new(0.5, 8, 0.5), cf * CFrame.new(x * (w / 2 - 0.25), 4, z * (d / 2 - 0.25)), P.WoodDark)
		end
	end
	-- counter + back wall fit BETWEEN the posts (no shared faces); 1/2-stud top overhangs 1/4
	brick(m, "Counter", Vector3.new(w - 1, 3, 2), cf * CFrame.new(0, 1.5, -(d / 2 - 1)), P.Wood)
	brick(m, "CounterTop", Vector3.new(w - 1, 0.5, 2.5), cf * CFrame.new(0, 3.25, -(d / 2 - 1.05)), P.WoodLight)
	brick(m, "Back", Vector3.new(w - 1, 7, 1), cf * CFrame.new(0, 3.5, d / 2 - 0.5), P.WoodDark)
	for k = -1, 1 do
		brick(m, "PlankLine", Vector3.new(0.125, 2.5, 0.125), cf * CFrame.new(k * 2.5, 1.5, -(d / 2 + 0.0625)), P.WoodDark, { Smooth = true, CanCollide = false })
	end
	local stripes = 5
	for k = 0, stripes - 1 do
		local x = -w / 2 + (k + 0.5) * (w / stripes)
		local color = if k % 2 == 0 then stripe else P.White
		wedge(m, "Awning", Vector3.new(w / stripes, 2, d + 2), cf * CFrame.new(x, 9, -0.5), color, NO_COLLIDE)
		-- scalloped valance hanging under the front edge
		brick(m, "Valance", Vector3.new(w / stripes - 0.5, 0.75, 0.125), cf * CFrame.new(x, 7.625, -(d / 2 + 1.4)), color, NO_COLLIDE)
	end
	if opts.Text then
		Props.Sign(m, cf * CFrame.new(0, 11.75, 2), opts.Text, w - 2, 2)
	end
	for k = 1, 3 do
		brick(m, "Goods", Vector3.new(0.75, 0.75, 0.75), cf * CFrame.new(-w / 2 + k * (w / 4), 3.875 + k * 0.03, -(d / 2 - 1.2)) * yaw(k * 0.5), B.Pick(rng, B.FlowerColors))
	end
	return m
end

-- Steps climb toward +Z (lowest step at the front, -Z). Stone cube posts flank both sides.
function Props.Stairs(parent, rng, cf, steps, width)
	local m = newModel("Stairs", parent)
	for i = 1, steps do
		local z = -steps / 2 + i - 0.5
		brick(m, "Step", Vector3.new(width, i, 1), cf * CFrame.new(0, i / 2, z), if i % 2 == 0 then P.Wood else P.WoodDark)
		brick(m, "Nosing", Vector3.new(width, 0.25, 0.25), cf * CFrame.new(0, i - 0.125, z - 0.625), P.WoodLight, { CanCollide = false })
		for _, x in { -1, 1 } do
			brick(m, "Post", Vector3.new(1, i + 1, 1), cf * CFrame.new(x * (width / 2 + 0.5), (i + 1) / 2, z), if i % 2 == 0 then P.Stone else P.StoneDark)
		end
	end
	return m
end

-- Window: studs-free detail built from 1/2, 1/4, 1/8 parts, on a wall whose outer face is at
-- local z = -wallFace (the timber plane; plaster is 1/4 behind it). Glass + frame bars reach back to
-- the plaster; frame 0.4 proud, mullions 0.25 proud, sill/flower box 0.75 proud, shutters 1/8.
local function addWindow(m, rng, f, x, y, wallFace, glow, shutterColor, flowerBox, neon)
	local z0 = -wallFace
	brick(m, "Glass", Vector3.new(2, 2, 0.35), f * CFrame.new(x, y, z0 + 0.075), if glow then Color3.fromRGB(255, 214, 140) else Color3.fromRGB(60, 80, 110), { Smooth = true, Material = if glow and neon then Enum.Material.Neon else Enum.Material.SmoothPlastic })
	-- frame: top/bottom bars full width, side bars between them
	for _, s in { -1, 1 } do
		brick(m, "FrameBar", Vector3.new(3, 0.5, 0.65), f * CFrame.new(x, y + s * 1.25, z0 - 0.075), P.WoodDark)
		brick(m, "FrameBar", Vector3.new(0.5, 2, 0.65), f * CFrame.new(x + s * 1.25, y, z0 - 0.075), P.WoodDark)
	end
	-- cross mullion: vertical bar + two horizontal halves (no overlap)
	brick(m, "Mullion", Vector3.new(0.25, 2, 0.15), f * CFrame.new(x, y, z0 - 0.175), P.WoodDark)
	for _, s in { -1, 1 } do
		brick(m, "Mullion", Vector3.new(0.875, 0.25, 0.15), f * CFrame.new(x + s * 0.5625, y, z0 - 0.175), P.WoodDark)
	end
	brick(m, "Sill", Vector3.new(3.5, 0.25, 0.75), f * CFrame.new(x, y - 1.625, z0 - 0.375), P.StoneLight)
	if shutterColor then
		for _, s in { -1, 1 } do
			brick(m, "Shutter", Vector3.new(0.75, 2.5, 0.125), f * CFrame.new(x + s * 1.875, y, z0 - 0.0625), shutterColor)
		end
	end
	if flowerBox then
		brick(m, "FlowerBox", Vector3.new(3, 0.5, 0.75), f * CFrame.new(x, y - 2, z0 - 0.375), P.WoodDark)
		local flower = B.Pick(rng, B.FlowerColors)
		for k = -1, 1 do
			brick(m, "BoxFlower", Vector3.new(0.5, 0.5, 0.5), f * CFrame.new(x + k * 0.9, y - 1.5 + 0.05 * (k + 2), z0 - 0.4) * yaw(k * 0.4), if k == 0 then P.Leaf else flower, NO_COLLIDE)
		end
	end
end

-- Half-timbered cottage. width/depth whole studs (depth even).
-- Chunky studded masses (stone base, plaster walls, roof) + 1/2-stud detail: timbers 1/4 proud of
-- the plaster, Tudor diagonal braces 0.2 proud, framed windows with mullions/shutters/flower boxes,
-- planked door with hinges and frame, stone steps, eave fascia and barge boards.
function Props.Cottage(parent, rng, cf, width, depth)
	local m = newModel("Cottage", parent)
	local w, d = math.floor(width), math.floor(depth)
	local H = rng:NextInteger(10, 12)
	local mid = math.floor(H / 2)
	local baseH = 3
	local wallY = baseH
	local timber = P.WoodDark
	local accent = B.Pick(rng, { P.FlowerBlue, P.Red, P.Leaf, P.Yellow })
	brick(m, "Base", Vector3.new(w, baseH, d), cf * CFrame.new(0, baseH / 2, 0), P.Stone)
	brick(m, "BaseCap", Vector3.new(w + 0.5, 0.5, d + 0.5), cf * CFrame.new(0, baseH - 0.25 + 0.03, 0), P.StoneLight)
	brick(m, "Walls", Vector3.new(w - 1, H, d - 1), cf * CFrame.new(0, wallY + H / 2, 0), P.Plaster)
	local wx, wz = (w - 1) / 2, (d - 1) / 2 -- plaster faces
	-- corner posts (1/2 wide, 1/4 proud on both faces)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			brick(m, "Post", Vector3.new(0.5, H - 0.25, 0.5), cf * CFrame.new(x * wx, wallY + (H - 0.25) / 2 + 0.05, z * wz), timber)
		end
	end
	-- belt beams (1/2 tall, 1/4 proud) on all sides, between the posts
	for _, by in { 0.25, mid, H - 0.5 } do
		for _, z in { -1, 1 } do
			brick(m, "Beam", Vector3.new(w - 1.5, 0.5, 0.25), cf * CFrame.new(0, wallY + by, z * (wz + 0.125)), timber)
			brick(m, "Beam", Vector3.new(0.25, 0.5, d - 1.5), cf * CFrame.new(z * (wx + 0.125), wallY + by, 0), timber)
		end
	end
	-- front/back vertical studs between belts, and Tudor diagonals in the end panels
	local sx = math.floor(w / 2) - 3
	local lowH, highH = mid - 0.75, H - mid - 1 -- studs stop at the belt beams (no overlap)
	for _, zs in { -1, 1 } do
		local face = cf * yaw(if zs == -1 then 0 else math.pi)
		for _, x in { -sx, sx } do
			for _, xs in { -1.75, 1.75 } do
				brick(m, "Stud", Vector3.new(0.5, lowH, 0.25), face * CFrame.new(x + xs, wallY + 0.5 + lowH / 2, -(wz + 0.125)), timber)
				brick(m, "Stud", Vector3.new(0.5, highH, 0.25), face * CFrame.new(x + xs, wallY + mid + 0.25 + highH / 2, -(wz + 0.125)), timber)
			end
		end
		-- diagonal braces in the outermost lower panels
		local panelW = wx - 0.25 - (sx + 2)
		if panelW >= 1.5 then
			local cx = (wx - 0.25 + sx + 2) / 2
			local len = math.sqrt(panelW ^ 2 + lowH ^ 2) - 0.5
			local ang = math.atan2(lowH, panelW)
			for _, s in { -1, 1 } do
				brick(m, "Brace", Vector3.new(len, 0.5, 0.2), face * CFrame.new(s * cx, wallY + 0.5 + lowH / 2, -(wz + 0.1)) * CFrame.Angles(0, 0, s * ang), timber)
			end
		end
	end
	-- door: planked slab 0.3 proud, 1/8 plank grooves, 1/4 hinges, 1/2 frame, knob
	local doorZ = -(wz)
	brick(m, "Door", Vector3.new(3, 5, 0.25), cf * CFrame.new(0, wallY + 2.5 + 0.02, doorZ - 0.175), P.Wood)
	for _, x in { -0.5, 0.5 } do
		brick(m, "Groove", Vector3.new(0.125, 4.75, 0.05), cf * CFrame.new(x, wallY + 2.5, doorZ - 0.325), P.WoodDark, { Smooth = true, CanCollide = false })
	end
	for _, y in { 1, 4 } do
		brick(m, "Hinge", Vector3.new(1, 0.25, 0.08), cf * CFrame.new(-1, wallY + y, doorZ - 0.37), P.Black, { Smooth = true, CanCollide = false })
	end
	brick(m, "DoorKnob", Vector3.new(0.25, 0.25, 0.25), cf * CFrame.new(1, wallY + 2.5, doorZ - 0.425), P.Yellow, { Smooth = true, CanCollide = false })
	brick(m, "Lintel", Vector3.new(4, 0.5, 0.45), cf * CFrame.new(0, wallY + 5.25 + 0.02, doorZ - 0.275), timber)
	for _, x in { -1.75, 1.75 } do
		brick(m, "Jamb", Vector3.new(0.5, 5, 0.45), cf * CFrame.new(x, wallY + 2.5 + 0.02, doorZ - 0.275), timber)
	end
	-- stone steps down the front of the base
	brick(m, "Step", Vector3.new(4, 1, 1), cf * CFrame.new(0, baseH - 0.5, -(d / 2 + 0.5)), P.StoneLight)
	brick(m, "Step", Vector3.new(4, 1, 1), cf * CFrame.new(0, baseH - 1.5, -(d / 2 + 1.5)), P.Stone)
	-- windows
	local glow = rng:NextNumber() < 0.25 -- warm lit glass (not neon, so it does not blow out in daylight)
	local winX = math.floor(w / 2) - 3
	local lowY = wallY + 0.5 + lowH / 2 + 0.25
	local highY = wallY + mid + 0.25 + highH / 2 + 0.25
	local front = cf
	addWindow(m, rng, front, -winX, lowY, wz + 0.25, glow, accent, true)
	addWindow(m, rng, front, winX, lowY, wz + 0.25, glow, accent, true)
	addWindow(m, rng, front, -winX, highY, wz + 0.25, glow, accent, false)
	addWindow(m, rng, front, winX, highY, wz + 0.25, glow, accent, false)
	if w >= 17 then -- only wide cottages have room for a middle window
		addWindow(m, rng, front, 0, highY, wz + 0.25, glow, nil, false)
	end
	addWindow(m, rng, cf * yaw(math.pi / 2), 0, highY, wx + 0.25, glow, nil, false)
	addWindow(m, rng, cf * yaw(-math.pi / 2), 0, highY, wx + 0.25, glow, nil, false)
	-- gable roof (ridge parallel to the front), 1-stud overhang, studded wedges
	local roofColor = B.Pick(rng, { P.Roof, P.RoofRed, P.RoofBlue, P.Roof })
	local roofH = d / 2
	local top = wallY + H
	local slopeD = d / 2 + 1
	for _, side in { -1, 1 } do
		wedge(m, "Roof", Vector3.new(w + 2, roofH, slopeD), cf * CFrame.new(0, top + roofH / 2, side * slopeD / 2) * yaw(if side == -1 then 0 else math.pi), roofColor)
		-- eave fascia under the low edge
		brick(m, "Fascia", Vector3.new(w + 2.5, 0.5, 0.5), cf * CFrame.new(0, top - 0.25, side * (slopeD + 0.25)), B.Shade(roofColor, -0.25))
		-- barge boards following the slope on both gable ends
		local len = math.sqrt(roofH ^ 2 + slopeD ^ 2)
		local ang = math.atan2(roofH, slopeD)
		for _, x in { -1, 1 } do
			brick(m, "Barge", Vector3.new(0.5, 0.5, len + 0.5), cf * CFrame.new(x * (w / 2 + 1.25 + (if side == 1 then 0.06 else 0)), top + roofH / 2 + 0.25, side * slopeD / 2) * CFrame.Angles(side * ang, 0, 0), B.Shade(roofColor, -0.25))
		end
	end
	brick(m, "Ridge", Vector3.new(w + 2.5, 0.5, 1), cf * CFrame.new(0, top + roofH + 0.25, 0), B.Shade(roofColor, -0.2))
	local chimX = math.floor(w / 2) - 3
	brick(m, "Chimney", Vector3.new(2, roofH + 3, 2), cf * CFrame.new(chimX, top + (roofH + 3) / 2 + 0.01, 1.5), P.StoneDark)
	brick(m, "ChimneyCap", Vector3.new(2.5, 0.5, 2.5), cf * CFrame.new(chimX, top + roofH + 3.25, 1.5), P.Stone)
	return m
end

function Props.Tower(parent, rng, cf)
	local m = newModel("Tower", parent)
	local baseW, baseH = 8, 12
	brick(m, "Base", Vector3.new(baseW, baseH, baseW), cf * CFrame.new(0, baseH / 2, 0), P.Stone)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			-- 1/4 proud quoins, lifted so top/bottom faces never coincide
			brick(m, "Quoin", Vector3.new(1, baseH - 1, 1), cf * CFrame.new(x * (baseW / 2 - 0.25), (baseH - 1) / 2 + 0.05, z * (baseW / 2 - 0.25)), P.StoneLight)
		end
	end
	brick(m, "Door", Vector3.new(3, 5, 0.3), cf * CFrame.new(0, 2.5 + 0.02, -(baseW / 2 + 0.15)), P.Wood)
	brick(m, "Lintel", Vector3.new(4, 0.5, 0.5), cf * CFrame.new(0, 5.25 + 0.02, -(baseW / 2 + 0.25)), P.StoneLight)
	brick(m, "Ledge", Vector3.new(baseW + 2, 1, baseW + 2), cf * CFrame.new(0, baseH + 0.5, 0), P.WoodDark)
	local upW, upH, upY = 8, 8, baseH + 1
	brick(m, "Upper", Vector3.new(upW, upH - 1, upW), cf * CFrame.new(0, upY + (upH - 1) / 2, 0), P.Plaster)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			brick(m, "Post", Vector3.new(1, upH, 1), cf * CFrame.new(x * (upW / 2 - 0.25), upY + upH / 2 + 0.05, z * (upW / 2 - 0.25)), P.WoodDark)
		end
	end
	for face = 0, 3 do
		local f = cf * yaw(face * math.pi / 2)
		brick(m, "Beam", Vector3.new(upW - 2, 1, 0.5), f * CFrame.new(0, upY + upH - 0.5, -(upW / 2)), P.WoodDark)
		addWindow(m, rng, f, 0, upY + 3.25, upW / 2, true, nil, false, true)
	end
	-- stepped roof
	local roofColor = B.Pick(rng, { P.Roof, P.RoofRed, P.RoofBlue })
	local y = upY + upH
	for tier, w in { 10, 8, 6, 4 } do
		brick(m, "Roof", Vector3.new(w, 2, w), cf * CFrame.new(0, y + 1, 0), B.Shade(roofColor, (tier % 2) * -0.1))
		y += 2
	end
	brick(m, "Spire", Vector3.new(0.5, 3, 0.5), cf * CFrame.new(0, y + 1.5, 0), P.WoodDark)
	brick(m, "Flag", Vector3.new(0.125, 1, 2), cf * CFrame.new(0, y + 2.5, -1.25), P.Red, NO_COLLIDE)
	return m
end

-- Slim post on a stepped stone base, arm, and a small framed lantern with a glowing core.
function Props.LampPost(parent, rng, cf)
	local m = newModel("LampPost", parent)
	brick(m, "Base", Vector3.new(1.5, 0.5, 1.5), cf * CFrame.new(0, 0.25, 0), P.Stone)
	brick(m, "Base2", Vector3.new(1, 0.5, 1), cf * CFrame.new(0, 0.75, 0), P.StoneLight)
	brick(m, "Post", Vector3.new(0.5, 7, 0.5), cf * CFrame.new(0, 4.5, 0), P.WoodDark)
	brick(m, "Arm", Vector3.new(0.25, 0.25, 1.75), cf * CFrame.new(0, 7.875, -1.125), P.WoodDark, NO_COLLIDE)
	local lx = -1.75
	brick(m, "LanternCap", Vector3.new(1, 0.25, 1), cf * CFrame.new(0, 7.625, lx), P.Black, NO_COLLIDE)
	local core = brick(m, "Lantern", Vector3.new(0.5, 0.75, 0.5), cf * CFrame.new(0, 7.125, lx), P.Lamp, { Smooth = true, Material = Enum.Material.Neon, CanCollide = false })
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			brick(m, "LanternBar", Vector3.new(0.125, 0.75, 0.125), cf * CFrame.new(x * 0.375, 7.125, lx + z * 0.375), P.Black, { Smooth = true, CanCollide = false })
		end
	end
	brick(m, "LanternBase", Vector3.new(0.875, 0.125, 0.875), cf * CFrame.new(0, 6.6875, lx), P.Black, { Smooth = true, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Color = P.Lamp
	light.Range = 14
	light.Brightness = 0.6
	light.Parent = core
	return m
end

function Props.Campfire(parent, rng, cf)
	local m = newModel("Campfire", parent)
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2
		brick(m, "Stone", Vector3.new(0.75, 0.75, 0.75), cf * CFrame.new(math.cos(a) * 2, 0.375 + i * 0.02, math.sin(a) * 2) * yaw(a + rng:NextNumber(-0.3, 0.3)), B.Pick(rng, { P.Stone, P.StoneDark }))
	end
	for i = 1, 3 do
		brick(m, "Log", Vector3.new(0.75, 0.75, 3), cf * CFrame.new(0, 0.5 + i * 0.05, 0) * yaw((i / 3) * math.pi) * CFrame.Angles(math.rad(12), 0, 0), P.Wood)
	end
	local fire = brick(m, "Fire", Vector3.new(1.25, 1.5, 1.25), cf * CFrame.new(0, 1.5, 0) * yaw(math.rad(45)), P.Fire, { Smooth = true, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
	brick(m, "Flame", Vector3.new(0.625, 1, 0.625), cf * CFrame.new(0, 2.6, 0) * yaw(math.rad(20)), P.Yellow, { Smooth = true, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
	local light = Instance.new("PointLight")
	light.Color = P.Fire
	light.Range = 18
	light.Brightness = 2
	light.Parent = fire
	return m
end

function Props.Scatter(parent, rng, center, radius, count, colors)
	local m = newModel("Scatter", parent)
	local used = {}
	for _ = 1, count do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber()) * radius
		local x0, z0 = math.floor(center.X + math.cos(a) * r), math.floor(center.Z + math.sin(a) * r)
		local key = x0 .. "," .. z0
		if not used[key] then
			used[key] = true
			brick(m, "Tile", Vector3.new(1, 0.3, 1), CFrame.new(x0 + 0.5, center.Y + 0.16, z0 + 0.5), B.Pick(rng, colors), DECOR)
		end
	end
	return m
end

return Props
