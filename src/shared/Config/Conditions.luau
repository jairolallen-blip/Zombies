-- Conditions: the weather and time of day each run gets, picked at random (vault: City Map.md). PURE DATA.
-- MatchService:RunMatch picks one by Weight (the tutorial is always the first) and sets GameState Condition;
-- MapService:ApplyAtmosphere lays its Atmosphere fields over GameConfig.OurMap.Atmosphere (fields left out
-- keep the sunset values). Client/Controllers/ConditionsController draws Rain around the camera and puts a
-- flashlight on every player while Flashlights is set. PostFXController's sunset grade only runs on Sunset.
-- OFF for now (2026-11-02, the owner prefers the sunset look): every weather but Sunset has Weight 0.
-- "Nightmare" is never rolled: MatchService uses it for every Nightmare run (Config/Nightmare).

local Conditions = {}

Conditions.List = {
	{ Id = "Sunset", Name = "SUNSET", Desc = "Clear skies over Port Harrow.", Weight = 3, Atmosphere = {} },
	{
		Id = "Fog",
		Name = "HEAVY FOG",
		Desc = "You won't see them coming. Listen.",
		Weight = 0, -- off for now (was 2)
		Atmosphere = {
			ClockTime = 16,
			Brightness = 1.6,
			Ambient = Color3.fromRGB(110, 110, 112),
			OutdoorAmbient = Color3.fromRGB(150, 152, 156),
			Density = 0.62,
			Haze = 3,
			AtmosphereColor = Color3.fromRGB(190, 192, 196),
			HazeColor = Color3.fromRGB(130, 134, 140),
			TintColor = Color3.fromRGB(235, 238, 242),
			Saturation = -0.35,
		},
	},
	{
		Id = "Night",
		Name = "NIGHTFALL",
		Desc = "Flashlights on. Stay together.",
		Weight = 0, -- off for now (was 2)
		Flashlights = true,
		Atmosphere = {
			ClockTime = 0.3,
			Brightness = 1,
			Ambient = Color3.fromRGB(60, 66, 86),
			OutdoorAmbient = Color3.fromRGB(90, 100, 130),
			Density = 0.4,
			Haze = 1.4,
			AtmosphereColor = Color3.fromRGB(70, 82, 115),
			HazeColor = Color3.fromRGB(30, 36, 55),
			TintColor = Color3.fromRGB(200, 212, 255),
			Saturation = -0.25,
		},
	},
	{
		Id = "Rain",
		Name = "STORM",
		Desc = "Rain all run. Keep your footing.",
		Weight = 0, -- off for now (was 2)
		Rain = true,
		Atmosphere = {
			ClockTime = 14.5,
			Brightness = 1.3,
			Ambient = Color3.fromRGB(90, 96, 104),
			OutdoorAmbient = Color3.fromRGB(125, 132, 142),
			Density = 0.48,
			Haze = 2.2,
			AtmosphereColor = Color3.fromRGB(150, 158, 168),
			HazeColor = Color3.fromRGB(95, 104, 115),
			TintColor = Color3.fromRGB(210, 220, 235),
			Saturation = -0.35,
		},
	},
	{
		Id = "Nightmare",
		Name = "NIGHTMARE",
		Desc = "Survive all 10 waves for 3x Gems. Fall and you leave with nothing.",
		Weight = 0, -- Nightmare runs only
		Flashlights = true,
		Atmosphere = {
			ClockTime = 0,
			Brightness = 0.6,
			Ambient = Color3.fromRGB(46, 30, 32),
			OutdoorAmbient = Color3.fromRGB(78, 48, 50),
			Density = 0.55,
			Haze = 2.2,
			AtmosphereColor = Color3.fromRGB(96, 44, 42),
			HazeColor = Color3.fromRGB(32, 12, 14),
			TintColor = Color3.fromRGB(255, 205, 200),
			Saturation = -0.4,
			Contrast = 0.15,
		},
	},
}

Conditions.ById = {}
for _, c in Conditions.List do
	Conditions.ById[c.Id] = c
end

function Conditions.Pick()
	local total = 0
	for _, c in Conditions.List do
		total += c.Weight
	end
	local roll = math.random() * total
	for _, c in Conditions.List do
		roll -= c.Weight
		if roll <= 0 then
			return c
		end
	end
	return Conditions.List[1]
end

return Conditions
