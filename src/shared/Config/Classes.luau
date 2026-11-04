-- Classes: playable roles, unlocked with Gems and chosen in the lobby.
-- PURE DATA. Each class has one cooldown Ability [E] and one charge-based Ultimate [F].
--
-- Ability/Ultimate.Type must match a handler in ServerScriptService.Server.Services.AbilityService
-- (Handlers table). Existing types and their Params:
--   Grenade   { Radius, Damage, Range }                     thrown explosive at aim point
--   Airstrike { Count, Radius, Damage, Spread, Interval, Delay, Range }  explosions around aim point
--   HealPulse { Radius, Heal }                              heals nearby teammates (and self)
--   Revive    { }                                           respawns dead teammates + full heal
--   Turret    { Count, Duration, Damage, FireRate, Range }  auto-firing sentries near caster
--   Stomp     { Radius, Damage, Knockback, InvulnTime? }    damage + knockback around caster
--   Dash      { Speed, Duration }                           burst of movement (client-applied)
--   Mark      { Radius, Duration, Mult }                    zombies near the caster glow red and take
--                                                           Mult x damage from everyone for Duration
--
-- Class fields: DisplayName, Description, GemCost (0 = default), Order, Color,
--   HealthBonus (added max HP), SpeedBonus (added WalkSpeed), DamageTakenMult (1 = normal)
-- Optional: Ability.EarlyCooldown + EarlyWaves (longer cooldown up to that wave),
--   Ultimate.ChargeMult (ult charge gain multiplier; 0.5 = needs twice the kills)

local Classes = {}

Classes.Default = "Survivor"

Classes.List = {
	Survivor = {
		DisplayName = "Survivor",
		Description = "All-rounder. Grenades for crowds, an airstrike for emergencies.",
		GemCost = 0,
		Order = 1,
		Color = Color3.fromRGB(235, 228, 205),
		HealthBonus = 0,
		SpeedBonus = 0,
		DamageTakenMult = 1,
		Ability = { Name = "Frag Grenade", Type = "Grenade", Cooldown = 9, Params = { Radius = 14, Damage = 140, Range = 90 } },
		Ultimate = {
			Name = "Airstrike",
			Type = "Airstrike",
			Params = { Count = 10, Radius = 13, Damage = 260, Spread = 22, Interval = 0.12, Delay = 1.0, Range = 140 },
		},
	},
	Scout = {
		DisplayName = "Scout",
		Description = "Fastest survivor. Dashes out of trouble constantly.",
		GemCost = 350,
		Order = 2,
		Color = Color3.fromRGB(120, 180, 220),
		HealthBonus = -10,
		SpeedBonus = 5,
		DamageTakenMult = 1,
		Ability = { Name = "Dash", Type = "Dash", Cooldown = 3.5, Params = { Speed = 90, Duration = 0.22 } },
		Ultimate = {
			Name = "Hunter's Mark",
			Type = "Mark",
			Params = { Radius = 70, Duration = 10, Mult = 1.75 },
		},
	},
	Medic = {
		DisplayName = "Medic",
		Description = "Keeps the squad alive. Ultimate brings fallen teammates back.",
		GemCost = 500,
		Order = 3,
		Color = Color3.fromRGB(122, 194, 82),
		HealthBonus = 0,
		SpeedBonus = 1,
		DamageTakenMult = 1,
		Ability = { Name = "Heal Pulse", Type = "HealPulse", Cooldown = 12, Params = { Radius = 32, Heal = 45 } },
		Ultimate = { Name = "Second Wind", Type = "Revive", Params = {} },
	},
	Engineer = {
		DisplayName = "Engineer",
		Description = "Drops sentry turrets that shred anything in range.",
		GemCost = 750,
		Order = 4,
		Color = Color3.fromRGB(245, 200, 60),
		HealthBonus = 0,
		SpeedBonus = 0,
		DamageTakenMult = 1,
		Ability = {
			Name = "Sentry",
			Type = "Turret",
			Cooldown = 22,
			EarlyCooldown = 42, -- waves 1-4: sentries out-shot the weak early zombies
			EarlyWaves = 4,
			Params = { Count = 1, Duration = 18, Damage = 14, FireRate = 6, Range = 30 }, -- Range = how close a zombie must be before it fires
		},
		Ultimate = {
			Name = "Sentry Nest",
			Type = "Turret",
			ChargeMult = 0.5, -- twice the kills of other ultimates
			Params = { Count = 4, Duration = 25, Damage = 18, FireRate = 7, Range = 35 },
		},
	},
	Bruiser = {
		DisplayName = "Bruiser",
		Description = "Tough as nails. Stomps the horde back and shrugs off hits.",
		GemCost = 750,
		Order = 5,
		Color = Color3.fromRGB(255, 110, 90),
		HealthBonus = 60,
		SpeedBonus = -1,
		DamageTakenMult = 0.75,
		Ability = { Name = "Shockwave", Type = "Stomp", Cooldown = 8, Params = { Radius = 16, Damage = 90, Knockback = 70 } },
		Ultimate = {
			Name = "Unstoppable",
			Type = "Stomp",
			Params = { Radius = 32, Damage = 400, Knockback = 120, InvulnTime = 6 },
		},
	},
}

return Classes
