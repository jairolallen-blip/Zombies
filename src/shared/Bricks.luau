-- Bricks: the game's art style in one place — "stud style" (Grow a Garden / Survive a Million
-- Monkeys look): studs on ALL faces, chunky boxes and wedges, earthy-saturated two-tone colours,
-- small random rotations. Full rules: docs/ART_STYLE.md. Used by the map, props, zombies, guns,
-- turrets and client debris, so restyling the whole game = editing this file.
--
-- Studs come from SurfaceType.Studs. They only render on Material.Plastic (SmoothPlastic hides
-- them) and cost nothing extra — no Texture instances. A face gets studs only if both of its
-- dimensions are WHOLE studs (see ApplySurfaces) so studs always line up with part edges.
-- Building rules (also in docs/ART_STYLE.md):
--   * studded faces in whole-stud sizes; fractions only for depth/thickness (those faces go smooth)
--   * big axis-aligned structures on whole-stud world coordinates so studs line up across parts
--   * never let two visible faces share a plane and overlap (z-fighting): layer trims at a
--     different depth (e.g. +0.2) — check with tools/zfight.luau after every bake
--
--   Bricks.Style(part, smooth?)    apply the look to an existing part (smooth = no studs: glass,
--                                  water, fire/neon, eyes, text boards)
--   Bricks.Part(props)             new anchored studded Part (props may include Parent, Smooth)
--   Bricks.Wedge(props)            same, as a WedgePart
--   Bricks.Palette                 named colours (see docs/ART_STYLE.md §3)
--   Bricks.Pick(rng, list)         random entry from a list using a Random
--   Bricks.Jitter(rng, degrees)    random small rotation CFrame (yaw ±deg, tilt ±deg/3)
--   Bricks.Shade(color, amount)    lighten (+) / darken (-) a colour, e.g. Shade(c, -0.15)

local Bricks = {}

Bricks.Palette = {
	-- Ground
	Grass = Color3.fromRGB(96, 178, 72),
	GrassDark = Color3.fromRGB(78, 158, 64),
	GrassLight = Color3.fromRGB(122, 194, 82),
	Dirt = Color3.fromRGB(168, 100, 60),
	DirtDark = Color3.fromRGB(112, 70, 46),
	Sand = Color3.fromRGB(230, 200, 130),
	SandLight = Color3.fromRGB(240, 215, 160),
	-- Stone (slightly blue)
	Stone = Color3.fromRGB(122, 126, 140),
	StoneDark = Color3.fromRGB(88, 92, 106),
	StoneLight = Color3.fromRGB(168, 171, 182),
	-- Wood
	Wood = Color3.fromRGB(150, 90, 55),
	WoodDark = Color3.fromRGB(100, 58, 40),
	WoodRed = Color3.fromRGB(190, 85, 70),
	WoodLight = Color3.fromRGB(200, 150, 100),
	CrateFrame = Color3.fromRGB(120, 62, 42),
	CratePanel = Color3.fromRGB(170, 112, 88),
	Bone = Color3.fromRGB(235, 228, 205),
	-- Buildings
	Plaster = Color3.fromRGB(235, 220, 185),
	Roof = Color3.fromRGB(130, 75, 55),
	RoofRed = Color3.fromRGB(180, 60, 50),
	RoofBlue = Color3.fromRGB(70, 95, 140),
	-- Foliage
	Leaf = Color3.fromRGB(60, 150, 70),
	LeafDark = Color3.fromRGB(40, 115, 55),
	LeafLime = Color3.fromRGB(140, 200, 70),
	PalmLeaf = Color3.fromRGB(90, 160, 60),
	-- Accents (small areas only)
	FlowerRed = Color3.fromRGB(230, 60, 60),
	FlowerPink = Color3.fromRGB(240, 120, 190),
	FlowerYellow = Color3.fromRGB(250, 215, 70),
	FlowerBlue = Color3.fromRGB(90, 170, 240),
	FlowerPurple = Color3.fromRGB(170, 90, 220),
	White = Color3.fromRGB(240, 240, 235),
	Black = Color3.fromRGB(35, 35, 40),
	Red = Color3.fromRGB(200, 55, 50),
	Yellow = Color3.fromRGB(245, 200, 60),
	Water = Color3.fromRGB(70, 160, 220),
	Fire = Color3.fromRGB(255, 150, 40),
	Lamp = Color3.fromRGB(255, 210, 120),
}

local P = Bricks.Palette
Bricks.LeafColors = { P.Leaf, P.LeafDark, P.Leaf, P.LeafLime }
Bricks.FlowerColors = { P.FlowerRed, P.FlowerPink, P.FlowerYellow, P.FlowerBlue, P.FlowerPurple, P.White }
Bricks.AwningColors = { P.Red, P.FlowerBlue, P.Yellow, P.Leaf, P.FlowerPurple }

-- Which two Size axes span each face
local FACE_DIMS = {
	TopSurface = { "X", "Z" },
	BottomSurface = { "X", "Z" },
	FrontSurface = { "X", "Y" },
	BackSurface = { "X", "Y" },
	LeftSurface = { "Z", "Y" },
	RightSurface = { "Z", "Y" },
}

local function whole(n)
	return n >= 0.99 and math.abs(n - math.round(n)) < 0.01
end

-- Studs tile from a corner of each face, so a face only gets studs when BOTH of its dimensions are
-- whole studs (otherwise the last row/column would be cut off). Fractional faces (thin trims,
-- plate edges) are smooth — exactly like classic Roblox plates. Wedges/cylinders keep studs.
-- => Build studded faces in whole-stud sizes; use fractions only for depth/thickness.
function Bricks.ApplySurfaces(part, smooth)
	local isBlock = part:IsA("Part") and part.Shape == Enum.PartType.Block
	local size = part.Size
	for face, dims in FACE_DIMS do
		local studs = not smooth and (not isBlock or (whole(size[dims[1]]) and whole(size[dims[2]])))
		part[face] = if studs then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth
	end
end

function Bricks.Style(part, smooth)
	if smooth then
		if part.Material == Enum.Material.Plastic then
			part.Material = Enum.Material.SmoothPlastic
		end
	else
		part.Material = Enum.Material.Plastic
	end
	Bricks.ApplySurfaces(part, smooth)
	return part
end

local function make(className, props)
	local part = Instance.new(className)
	part.Anchored = true
	part.Material = if props.Smooth then Enum.Material.SmoothPlastic else Enum.Material.Plastic
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" and key ~= "Smooth" then
			part[key] = value
		end
	end
	Bricks.ApplySurfaces(part, props.Smooth) -- after Size is known
	part.Parent = parent
	return part
end

function Bricks.Part(props)
	return make("Part", props)
end

function Bricks.Wedge(props)
	return make("WedgePart", props)
end

function Bricks.Pick(rng, list)
	return list[rng:NextInteger(1, #list)]
end

function Bricks.Jitter(rng, degrees)
	local d = math.rad(degrees)
	return CFrame.Angles(rng:NextNumber(-d, d) / 3, rng:NextNumber(-d, d), rng:NextNumber(-d, d) / 3)
end

function Bricks.Shade(color, amount)
	if amount >= 0 then
		return color:Lerp(Color3.new(1, 1, 1), amount)
	end
	return color:Lerp(Color3.new(0, 0, 0), -amount)
end

return Bricks
