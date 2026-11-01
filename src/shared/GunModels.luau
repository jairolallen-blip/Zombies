-- GunModels: blocky low-poly gun models built from parts, one per weapon id (vault: Weapons.md;
-- style from MODEL REFERENCES). GunModels.BuildTool(stats) -> Tool used by CombatService.
--
-- Gun space: the grip ("Handle") sits at the origin, the gun points along -Z, +Y is up.
-- Spec entries: { name, size, position or CFrame, color, opts? }
--   color  = a COLORS key, or "LEVEL" for the level stripe (stats.TierColor, neon)
--   opts   = { Tube = true }  cylinder along Z (size = Vector3.new(diameter, diameter, length))
--            { Drum = true }   cylinder along X (size = Vector3.new(thickness, diameter, diameter))
--            { Neon = true, Hub = true (child of the minigun's spinning hub), Transparency = n }
-- Each spec also has Muzzle (Vector3) and optionally Hub (Vector3) for spinning barrels.

local GunModels = {}

local COLORS = {
	Black = Color3.fromRGB(34, 34, 37),
	Gun = Color3.fromRGB(64, 66, 72),
	Steel = Color3.fromRGB(150, 150, 156),
	Wood = Color3.fromRGB(118, 70, 38),
	Olive = Color3.fromRGB(84, 92, 62),
	White = Color3.fromRGB(205, 208, 214),
	Cyan = Color3.fromRGB(70, 220, 255),
	Red = Color3.fromRGB(255, 60, 50),
	Brass = Color3.fromRGB(200, 160, 60),
}

local V = Vector3.new
local function tilt(position, x)
	return CFrame.new(position) * CFrame.Angles(x, 0, 0)
end

local SPECS = {
	Pistol = {
		Muzzle = V(0, 0.68, -1.05),
		{ "Handle", V(0.3, 0.8, 0.42), V(0, 0, 0), "Black" },
		{ "Frame", V(0.28, 0.24, 1.0), V(0, 0.42, -0.32), "Gun" },
		{ "Slide", V(0.3, 0.3, 1.25), V(0, 0.68, -0.38), "Black" },
		{ "Guard", V(0.08, 0.22, 0.35), V(0, 0.2, -0.38), "Black" },
		{ "SightF", V(0.06, 0.08, 0.06), V(0, 0.86, -0.95), "Black" },
		{ "SightR", V(0.16, 0.08, 0.06), V(0, 0.86, 0.18), "Black" },
		{ "Stripe", V(0.32, 0.06, 0.5), V(0, 0.6, -0.5), "LEVEL" },
	},
	Revolver = {
		Muzzle = V(0, 0.68, -1.92),
		{ "Handle", V(0.3, 0.85, 0.44), V(0, 0, 0.05), "Wood" },
		{ "Frame", V(0.28, 0.42, 0.7), V(0, 0.5, -0.25), "Steel" },
		{ "Cylinder", V(0.56, 0.56, 0.55), V(0, 0.55, -0.4), "Gun", { Tube = true } },
		{ "Barrel", V(0.24, 0.24, 1.3), V(0, 0.68, -1.25), "Steel", { Tube = true } },
		{ "Rib", V(0.12, 0.1, 1.3), V(0, 0.82, -1.25), "Steel" },
		{ "Hammer", V(0.1, 0.2, 0.15), V(0, 0.8, 0.08), "Black" },
		{ "Guard", V(0.08, 0.22, 0.35), V(0, 0.2, -0.3), "Steel" },
		{ "Stripe", V(0.3, 0.06, 0.4), V(0, 0.38, -0.25), "LEVEL" },
	},
	SMG = {
		Muzzle = V(0, 0.52, -2.08),
		{ "Handle", V(0.26, 0.7, 0.36), V(0, 0, 0.05), "Black" },
		{ "Receiver", V(0.32, 0.42, 1.5), V(0, 0.48, -0.45), "Black" },
		{ "Handguard", V(0.36, 0.36, 0.55), V(0, 0.45, -1.4), "Gun" },
		{ "Barrel", V(0.14, 0.14, 0.45), V(0, 0.52, -1.85), "Black", { Tube = true } },
		{ "Mag", V(0.2, 0.85, 0.32), tilt(V(0, -0.15, -0.75), 0.25), "Gun" },
		{ "StockTop", V(0.08, 0.08, 0.9), V(0, 0.62, 0.55), "Steel" },
		{ "StockBottom", V(0.08, 0.08, 0.9), V(0, 0.32, 0.55), "Steel" },
		{ "Butt", V(0.12, 0.42, 0.08), V(0, 0.47, 1.0), "Black" },
		{ "Sight", V(0.1, 0.18, 0.1), V(0, 0.75, -1.5), "Black" },
		{ "Stripe", V(0.34, 0.06, 0.6), V(0, 0.6, -0.4), "LEVEL" },
	},
	Shotgun = {
		Muzzle = V(0, 0.62, -3.1),
		{ "Handle", V(0.26, 0.65, 0.36), V(0, 0, 0.1), "Black" },
		{ "Receiver", V(0.32, 0.46, 0.95), V(0, 0.48, -0.25), "Gun" },
		{ "Barrel", V(0.2, 0.2, 2.4), V(0, 0.62, -1.9), "Black", { Tube = true } },
		{ "MagTube", V(0.18, 0.18, 1.8), V(0, 0.4, -1.6), "Black", { Tube = true } },
		{ "Pump", V(0.32, 0.3, 0.75), V(0, 0.4, -1.5), "Wood" },
		{ "Stock", V(0.3, 0.5, 1.4), tilt(V(0, 0.32, 0.95), 0.12), "Wood" },
		{ "Bead", V(0.06, 0.06, 0.06), V(0, 0.75, -3.05), "Brass" },
		{ "Stripe", V(0.34, 0.06, 0.5), V(0, 0.6, -0.25), "LEVEL" },
	},
	AssaultRifle = {
		Muzzle = V(0, 0.5, -2.82),
		{ "Handle", V(0.26, 0.7, 0.36), V(0, 0, 0.08), "Black" },
		{ "Receiver", V(0.32, 0.5, 1.5), V(0, 0.48, -0.35), "Gun" },
		{ "DustCover", V(0.3, 0.12, 1.2), V(0, 0.78, -0.35), "Black" },
		{ "Handguard", V(0.36, 0.42, 0.95), V(0, 0.46, -1.55), "Wood" },
		{ "GasTube", V(0.14, 0.14, 0.8), V(0, 0.78, -1.6), "Gun" },
		{ "Barrel", V(0.14, 0.14, 0.8), V(0, 0.5, -2.4), "Black", { Tube = true } },
		{ "FrontSight", V(0.08, 0.3, 0.08), V(0, 0.75, -2.55), "Black" },
		{ "Mag", V(0.24, 1.0, 0.42), tilt(V(0, -0.18, -0.65), 0.3), "Black" },
		{ "Stock", V(0.3, 0.55, 1.25), tilt(V(0, 0.35, 1.1), 0.08), "Wood" },
		{ "Stripe", V(0.34, 0.06, 0.6), V(0, 0.62, -0.2), "LEVEL" },
	},
	AutoShotgun = {
		Muzzle = V(0, 0.62, -2.22),
		{ "Handle", V(0.3, 0.7, 0.38), V(0, 0, 0.15), "Black" },
		{ "Body", V(0.46, 0.7, 2.4), V(0, 0.55, -0.55), "Black" },
		{ "Stock", V(0.42, 0.6, 0.8), V(0, 0.45, 1.0), "Gun" },
		{ "Drum", V(0.45, 1.1, 1.1), V(0, -0.25, -0.9), "Gun", { Drum = true } },
		{ "Barrel", V(0.24, 0.24, 0.5), V(0, 0.62, -1.95), "Gun", { Tube = true } },
		{ "CarryHandle", V(0.12, 0.12, 0.9), V(0, 1.12, -0.4), "Black" },
		{ "HandlePostF", V(0.1, 0.3, 0.1), V(0, 0.98, -0.8), "Black" },
		{ "HandlePostR", V(0.1, 0.3, 0.1), V(0, 0.98, 0), "Black" },
		{ "Stripe", V(0.48, 0.08, 0.8), V(0, 0.7, -0.3), "LEVEL" },
	},
	Rifle = {
		Muzzle = V(0, 0.56, -3.32),
		{ "Handle", V(0.26, 0.7, 0.36), V(0, 0, 0.08), "Olive" },
		{ "Receiver", V(0.3, 0.42, 1.3), V(0, 0.5, -0.35), "Olive" },
		{ "Barrel", V(0.14, 0.14, 2.1), V(0, 0.56, -2.05), "Black", { Tube = true } },
		{ "Brake", V(0.22, 0.22, 0.3), V(0, 0.56, -3.15), "Black" },
		{ "Scope", V(0.32, 0.32, 1.5), V(0, 0.98, -0.4), "Black", { Tube = true } },
		{ "ScopeBell", V(0.42, 0.42, 0.2), V(0, 0.98, -1.15), "Black", { Tube = true } },
		{ "MountF", V(0.12, 0.22, 0.12), V(0, 0.78, -0.8), "Black" },
		{ "MountR", V(0.12, 0.22, 0.12), V(0, 0.78, 0), "Black" },
		{ "Bolt", V(0.35, 0.08, 0.08), V(0.2, 0.6, -0.05), "Steel" },
		{ "Stock", V(0.3, 0.6, 1.5), tilt(V(0, 0.36, 1.0), 0.06), "Olive" },
		{ "Cheek", V(0.3, 0.15, 0.6), V(0, 0.72, 0.8), "Olive" },
		{ "Mag", V(0.22, 0.4, 0.4), V(0, 0.15, -0.55), "Black" },
		{ "Stripe", V(0.32, 0.06, 0.5), V(0, 0.62, -0.5), "LEVEL" },
	},
	Minigun = {
		Muzzle = V(0, 0.6, -3.15),
		Hub = V(0, 0.6, -0.9),
		{ "Handle", V(0.3, 0.7, 0.4), V(0, 0, 0.1), "Black" },
		{ "Motor", V(0.75, 0.75, 0.9), V(0, 0.6, 0.25), "Gun" },
		{ "Housing", V(0.95, 0.95, 0.7), V(0, 0.6, -0.5), "Gun", { Tube = true } },
		{ "TopHandle", V(0.12, 0.12, 0.8), V(0, 1.15, -0.1), "Black" },
		{ "HandlePostF", V(0.1, 0.3, 0.1), V(0, 1.0, -0.4), "Black" },
		{ "HandlePostR", V(0.1, 0.3, 0.1), V(0, 1.0, 0.2), "Black" },
		{ "AmmoBox", V(0.5, 0.7, 0.8), V(0.62, 0.2, 0.2), "Olive" },
		{ "Belt", V(0.15, 0.12, 0.5), V(0.42, 0.55, -0.2), "Brass" },
		{ "Stripe", V(0.77, 0.08, 0.5), V(0, 0.85, 0.25), "LEVEL" },
		-- spinning barrel cluster (positions relative to the hub)
		{ "FrontRing", V(0.85, 0.85, 0.12), V(0, 0, -2.0), "Gun", { Tube = true, Hub = true } },
		{ "MidRing", V(0.8, 0.8, 0.1), V(0, 0, -1.0), "Gun", { Tube = true, Hub = true } },
	},
	LaserRifle = {
		Muzzle = V(0, 0.55, -2.3),
		{ "Handle", V(0.26, 0.7, 0.36), V(0, 0, 0.08), "Gun" },
		{ "Body", V(0.36, 0.55, 2.0), V(0, 0.52, -0.55), "White" },
		{ "Strip", V(0.38, 0.08, 1.6), V(0, 0.6, -0.6), "Cyan", { Neon = true } },
		{ "Emitter", V(0.3, 0.3, 0.7), V(0, 0.55, -1.9), "Black", { Tube = true } },
		{ "EmitterRing", V(0.38, 0.38, 0.08), V(0, 0.55, -2.15), "Cyan", { Tube = true, Neon = true } },
		{ "Cell", V(0.28, 0.5, 0.4), V(0, 0.05, -0.55), "Cyan", { Neon = true, Transparency = 0.2 } },
		{ "Stock", V(0.3, 0.45, 0.95), V(0, 0.45, 0.85), "White" },
		{ "Sight", V(0.16, 0.18, 0.4), V(0, 0.9, -0.4), "Black" },
		{ "SightLens", V(0.1, 0.1, 0.02), V(0, 0.9, -0.61), "Red", { Neon = true } },
		{ "Stripe", V(0.38, 0.06, 0.4), V(0, 0.32, -0.9), "LEVEL" },
	},
	AutoSniper = {
		Muzzle = V(0, 0.55, -3.6),
		{ "Handle", V(0.26, 0.7, 0.36), V(0, 0, 0.08), "Black" },
		{ "Receiver", V(0.32, 0.48, 1.5), V(0, 0.5, -0.35), "Black" },
		{ "Handguard", V(0.34, 0.4, 1.0), V(0, 0.5, -1.55), "Gun" },
		{ "Barrel", V(0.15, 0.15, 1.4), V(0, 0.55, -2.6), "Black", { Tube = true } },
		{ "Brake", V(0.26, 0.24, 0.35), V(0, 0.55, -3.4), "Gun" },
		{ "Scope", V(0.32, 0.32, 1.5), V(0, 1.0, -0.4), "Black", { Tube = true } },
		{ "ScopeBell", V(0.42, 0.42, 0.2), V(0, 1.0, -1.15), "Black", { Tube = true } },
		{ "MountF", V(0.12, 0.22, 0.12), V(0, 0.8, -0.8), "Black" },
		{ "MountR", V(0.12, 0.22, 0.12), V(0, 0.8, 0), "Black" },
		{ "BoxMag", V(0.24, 0.65, 0.5), V(0, -0.05, -0.6), "Gun" },
		{ "Stock", V(0.3, 0.6, 1.3), tilt(V(0, 0.38, 1.05), 0.06), "Black" },
		{ "Stripe", V(0.34, 0.06, 0.6), V(0, 0.62, -0.4), "LEVEL" },
	},
}

-- the minigun's six barrels, generated around the hub
for n = 0, 5 do
	local a = n * math.pi / 3
	table.insert(SPECS.Minigun, { "SpinBarrel", V(0.16, 0.16, 2.4), V(math.cos(a) * 0.27, math.sin(a) * 0.27, -1.2), "Black", { Tube = true, Hub = true } })
end

local function makePart(def, levelColor)
	local name, size, place, colorKey, opts = def[1], def[2], def[3], def[4], def[5] or {}
	local p = Instance.new("Part")
	p.Name = name
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local cf = if typeof(place) == "CFrame" then place else CFrame.new(place)
	if opts.Tube then
		p.Shape = Enum.PartType.Cylinder
		p.Size = V(size.Z, size.Y, size.X) -- length along the cylinder's X axis
		cf *= CFrame.Angles(0, math.rad(90), 0)
	elseif opts.Drum then
		p.Shape = Enum.PartType.Cylinder
		p.Size = size
	else
		p.Size = size
	end
	if colorKey == "LEVEL" then
		p.Color = levelColor
		p.Material = Enum.Material.Neon
	else
		p.Color = COLORS[colorKey]
		p.Material = if opts.Neon then Enum.Material.Neon elseif colorKey == "Wood" then Enum.Material.Wood else Enum.Material.Metal
	end
	p.Transparency = opts.Transparency or 0
	return p, cf, opts.Hub == true
end

local function weld(part0, part1, c0)
	local w = Instance.new("Weld")
	w.Part0 = part0
	w.Part1 = part1
	w.C0 = c0
	w.Parent = part1
	return w
end

function GunModels.Has(weaponId)
	return SPECS[weaponId] ~= nil
end

-- Tool for a weapon (stats from Util.GetWeaponStats). Handle = grip; Handle.Muzzle = muzzle
-- attachment; spinning guns get a "SpinHub" part whose Weld ("SpinWeld") the client rotates.
function GunModels.BuildTool(stats)
	local spec = SPECS[stats.Id] or SPECS.Pistol
	local tool = Instance.new("Tool")
	tool.Name = stats.DisplayName
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = true
	tool:SetAttribute("WeaponId", stats.Id)

	local handle, handleCF
	for _, def in spec do
		if def[1] == "Handle" then
			handle, handleCF = makePart(def, stats.TierColor)
			handle.Massless = false
			handle.Parent = tool
			break
		end
	end
	local origin = handleCF:Inverse() -- gun space -> handle space

	local hub
	if spec.Hub then
		hub = Instance.new("Part")
		hub.Name = "SpinHub"
		hub.Size = V(0.2, 0.2, 0.2)
		hub.Transparency = 1
		hub.CanCollide = false
		hub.CanQuery = false
		hub.CanTouch = false
		hub.Massless = true
		local hubC0 = origin * CFrame.new(spec.Hub)
		hub.CFrame = handle.CFrame * hubC0
		local w = weld(handle, hub, hubC0)
		w.Name = "SpinWeld"
		hub:SetAttribute("BaseC0", hubC0)
		hub.Parent = tool
	end

	for _, def in spec do
		if def[1] ~= "Handle" then
			local p, cf, onHub = makePart(def, stats.TierColor)
			if onHub and hub then
				p.CFrame = hub.CFrame * cf
				weld(hub, p, cf)
			else
				local c0 = origin * cf
				p.CFrame = handle.CFrame * c0
				weld(handle, p, c0)
			end
			p.Parent = tool
		end
	end

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = (origin * CFrame.new(spec.Muzzle)).Position
	muzzle.Parent = handle
	-- shell ejection port: just behind the muzzle line on the right side of the receiver
	local port = Instance.new("Attachment")
	port.Name = "EjectPort"
	port.Position = (origin * CFrame.new(0.2, spec.Muzzle.Y, -0.2)).Position
	port.Parent = handle

	tool.Grip = CFrame.new(0, -0.1, 0)
	return tool
end

return GunModels
