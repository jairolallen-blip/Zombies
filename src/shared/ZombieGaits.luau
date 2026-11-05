-- ZombieGaits: keyframed walk cycles for the zombies (vault: Zombies.md). Pure data + sampling, no instances.
-- EffectsController plays them locally on each zombie's Motor6Ds (LeftArm, RightArm, LeftLeg, RightLeg,
-- Torso, Head), so a walk costs the server nothing.
--
-- A gait is one full stride, t = 0..1, looped. Each channel is a list of { t, value } keys in radians
-- (Bob in studs at Scale 1). Keys are smoothed through with a periodic cubic, then baked into a lookup
-- table, so sampling a gait is a table read however many zombies are on screen.
--   LeftLeg, RightLeg    + forward
--   LeftArm, RightArm    + up, 0 = the rig's rest (straight ahead; down on Crawler and Gaunt)
--   ArmOut               arms out from the body (both, mirrored)
--   BodyPitch            + back, - hunched forward       BodyRoll  + leans to its left
--   BodyYaw              twist at the hips               Bob       up and down
--   HeadPitch, HeadRoll  on top of the body, keyed late so the head follows through
-- Stride = studs walked per cycle at Scale 1, so feet don't skate (t advances with real ground speed).
--   ZombieGaits.For(def)                         the gait for a Config/Zombies type
--   ZombieGaits.Sample(gait, t, out)             fills out[channel] for t (any number; it wraps)
--   ZombieGaits.Idle                             standing pose
--   ZombieGaits.Moves, gait.Attacks              one-shot moves, and the attacks a gait picks from
--   ZombieGaits.Hit(gait, head)                  the flinch for a body or head hit
--   ZombieGaits.Add(move, u, pose, flip)         adds a move on top of pose, u = 0..1 over move.Time
--   ZombieGaits.Set(move, u, out)                writes a held move's absolute values into out

local ZombieGaits = {}

local SAMPLES = 64
local CHANNELS = { "LeftLeg", "RightLeg", "LeftArm", "RightArm", "ArmOut", "BodyPitch", "BodyRoll", "BodyYaw", "Bob", "HeadPitch", "HeadRoll" }

local GAITS = {
	-- Normal: a limp. The left leg drags through and buckles, the right steps quick to catch the fall; the
	-- body lurches over each foot, one arm reaches, the other hangs and swings late.
	Shamble = {
		Stride = 6.4,
		LeftLeg = { { 0, 0.22 }, { 0.12, 0.35 }, { 0.38, -0.1 }, { 0.62, -0.55 }, { 0.8, -0.3 }, { 0.95, 0.05 } },
		RightLeg = { { 0, 0.05 }, { 0.2, -0.5 }, { 0.42, 0.15 }, { 0.62, 0.55 }, { 0.8, 0.35 } },
		LeftArm = { { 0, -0.1 }, { 0.25, 0.08 }, { 0.6, -0.25 }, { 0.85, -0.05 } },
		RightArm = { { 0, -0.55 }, { 0.3, -0.78 }, { 0.6, -0.42 }, { 0.85, -0.7 } },
		ArmOut = { { 0, 0.06 }, { 0.5, 0.1 } },
		BodyPitch = { { 0, -0.14 }, { 0.3, -0.2 }, { 0.55, -0.28 }, { 0.8, -0.12 } },
		BodyRoll = { { 0.05, -0.05 }, { 0.32, 0.17 }, { 0.58, 0.1 }, { 0.82, -0.12 } },
		BodyYaw = { { 0.1, 0.1 }, { 0.65, -0.12 } },
		Bob = { { 0, 0 }, { 0.2, 0.07 }, { 0.5, -0.17 }, { 0.62, -0.12 }, { 0.85, 0.1 } },
		HeadPitch = { { 0, 0.14 }, { 0.4, 0.2 }, { 0.68, 0.06 } },
		HeadRoll = { { 0.15, 0.1 }, { 0.42, -0.14 }, { 0.72, -0.05 }, { 0.92, 0.15 } },
	},
	-- Lean: flat out and out of control. Long legs, arms thrown about, chest pitched into the run.
	Sprint = {
		Stride = 10,
		LeftLeg = { { 0, -0.9 }, { 0.25, 0.2 }, { 0.5, 0.9 }, { 0.75, 0.05 } },
		RightLeg = { { 0, 0.95 }, { 0.25, 0.1 }, { 0.5, -0.95 }, { 0.75, 0.15 } },
		LeftArm = { { 0, 0.3 }, { 0.25, -0.35 }, { 0.5, -0.75 }, { 0.75, -0.2 } },
		RightArm = { { 0, -0.8 }, { 0.25, -0.15 }, { 0.5, 0.35 }, { 0.75, -0.4 } },
		ArmOut = { { 0, 0.14 }, { 0.5, 0.2 } },
		BodyPitch = { { 0, -0.2 }, { 0.25, -0.3 }, { 0.5, -0.2 }, { 0.75, -0.3 } },
		BodyRoll = { { 0, 0.1 }, { 0.5, -0.1 } },
		BodyYaw = { { 0, -0.18 }, { 0.5, 0.18 } },
		Bob = { { 0, -0.1 }, { 0.25, 0.18 }, { 0.5, -0.1 }, { 0.75, 0.18 } },
		HeadPitch = { { 0, 0.3 }, { 0.25, 0.22 }, { 0.5, 0.3 }, { 0.75, 0.22 } },
		HeadRoll = { { 0.1, -0.08 }, { 0.6, 0.08 } },
	},
	-- Bloated: short steps and a heavy belly rolling from side to side, arms flopping a beat behind.
	Waddle = {
		Stride = 4.6,
		LeftLeg = { { 0, 0.34 }, { 0.5, -0.34 } },
		RightLeg = { { 0, -0.34 }, { 0.5, 0.34 } },
		LeftArm = { { 0.1, -0.5 }, { 0.6, -0.25 } },
		RightArm = { { 0.1, -0.25 }, { 0.6, -0.5 } },
		ArmOut = { { 0, 0.3 }, { 0.25, 0.22 }, { 0.5, 0.3 }, { 0.75, 0.22 } },
		BodyPitch = { { 0, 0.04 }, { 0.25, 0.08 }, { 0.5, 0.04 }, { 0.75, 0.08 } },
		BodyRoll = { { 0.02, 0.2 }, { 0.52, -0.2 } },
		BodyYaw = { { 0, -0.1 }, { 0.5, 0.1 } },
		Bob = { { 0, -0.1 }, { 0.25, 0.1 }, { 0.5, -0.1 }, { 0.75, 0.1 } },
		HeadPitch = { { 0, 0.05 }, { 0.5, 0.05 }, { 0.25, 0.1 } },
		HeadRoll = { { 0.14, -0.14 }, { 0.64, 0.14 } },
	},
	-- Hulk, Titan and bosses: weight. Each foot lands, the whole body sinks into it and holds a moment,
	-- then heaves up onto the next. Arms hang low and swing late, the head barely moves.
	Stomp = {
		Stride = 8,
		LeftLeg = { { 0, -0.5 }, { 0.1, -0.42 }, { 0.32, 0.36 }, { 0.5, 0.56 }, { 0.6, 0.5 }, { 0.85, -0.2 } },
		RightLeg = { { 0, 0.56 }, { 0.1, 0.5 }, { 0.35, -0.2 }, { 0.5, -0.5 }, { 0.6, -0.42 }, { 0.82, 0.36 } },
		LeftArm = { { 0.08, -0.45 }, { 0.58, -0.95 } },
		RightArm = { { 0.08, -0.95 }, { 0.58, -0.45 } },
		ArmOut = { { 0, 0.14 }, { 0.5, 0.14 }, { 0.25, 0.18 } },
		BodyPitch = { { 0, -0.1 }, { 0.12, -0.16 }, { 0.32, -0.07 }, { 0.5, -0.1 }, { 0.62, -0.16 }, { 0.82, -0.07 } },
		BodyRoll = { { 0.06, -0.12 }, { 0.32, 0 }, { 0.56, 0.12 }, { 0.82, 0 } },
		BodyYaw = { { 0.05, 0.08 }, { 0.55, -0.08 } },
		Bob = { { 0, -0.2 }, { 0.1, -0.26 }, { 0.3, 0.14 }, { 0.5, -0.2 }, { 0.6, -0.26 }, { 0.8, 0.14 } },
		HeadPitch = { { 0, 0.1 }, { 0.14, 0.16 }, { 0.5, 0.1 }, { 0.64, 0.16 } },
		HeadRoll = { { 0.15, 0.04 }, { 0.65, -0.04 } },
	},
	-- Gaunt: long unhurried strides, stooped, arms dangling to the knees; the head snaps on a twitch.
	Stalk = {
		Stride = 8.4,
		IdleArms = 0, -- its arms already hang down at rest
		LeftLeg = { { 0, -0.58 }, { 0.5, 0.58 } },
		RightLeg = { { 0, 0.58 }, { 0.5, -0.58 } },
		LeftArm = { { 0.1, 0.18 }, { 0.6, -0.18 } },
		RightArm = { { 0.1, -0.18 }, { 0.6, 0.18 } },
		ArmOut = { { 0, 0.05 }, { 0.5, 0.09 } },
		BodyPitch = { { 0, -0.2 }, { 0.25, -0.15 }, { 0.5, -0.2 }, { 0.75, -0.15 } },
		BodyRoll = { { 0.05, -0.05 }, { 0.55, 0.05 } },
		BodyYaw = { { 0, -0.12 }, { 0.5, 0.12 } },
		Bob = { { 0, -0.06 }, { 0.25, 0.08 }, { 0.5, -0.06 }, { 0.75, 0.08 } },
		HeadPitch = { { 0, 0.16 }, { 0.44, 0.18 }, { 0.52, -0.06 }, { 0.62, 0.16 } },
		HeadRoll = { { 0, 0.16 }, { 0.44, 0.14 }, { 0.52, -0.18 }, { 0.66, 0.12 } },
	},
	-- Crawler: on all fours, diagonal pairs moving together, spine snaking.
	Crawl = {
		Stride = 5,
		IdleArms = 0, -- its arms are its front legs
		LeftLeg = { { 0, 0.45 }, { 0.5, -0.45 } },
		RightLeg = { { 0, -0.45 }, { 0.5, 0.45 } },
		LeftArm = { { 0, -0.38 }, { 0.5, 0.38 } },
		RightArm = { { 0, 0.38 }, { 0.5, -0.38 } },
		ArmOut = { { 0, 0.08 }, { 0.5, 0.08 }, { 0.25, 0.12 } },
		BodyPitch = { { 0, -0.03 }, { 0.25, 0.03 }, { 0.5, -0.03 }, { 0.75, 0.03 } },
		BodyRoll = { { 0, 0.08 }, { 0.5, -0.08 } },
		BodyYaw = { { 0, 0.12 }, { 0.5, -0.12 } },
		Bob = { { 0, 0.05 }, { 0.25, -0.05 }, { 0.5, 0.05 }, { 0.75, -0.05 } },
		HeadPitch = { { 0, 0.05 }, { 0.25, -0.05 }, { 0.5, 0.05 }, { 0.75, -0.05 } },
		HeadRoll = { { 0.1, -0.08 }, { 0.6, 0.08 } },
	},
}

-- standing still: slow breathing and a head that sags and sways (one cycle is IDLE_SECONDS long)
ZombieGaits.IdleSeconds = 4
local IDLE = {
	LeftLeg = { { 0, 0.03 }, { 0.5, 0.03 } },
	RightLeg = { { 0, -0.05 }, { 0.5, -0.05 } },
	LeftArm = { { 0, -0.34 }, { 0.5, -0.46 } },
	RightArm = { { 0, -0.62 }, { 0.5, -0.5 } },
	ArmOut = { { 0, 0.06 }, { 0.5, 0.09 } },
	BodyPitch = { { 0, -0.1 }, { 0.5, -0.15 } },
	BodyRoll = { { 0, -0.03 }, { 0.5, 0.03 } },
	BodyYaw = { { 0, 0.04 }, { 0.5, -0.04 } },
	Bob = { { 0, 0 }, { 0.5, -0.04 } },
	HeadPitch = { { 0, -0.04 }, { 0.5, -0.14 } },
	HeadRoll = { { 0.1, 0.16 }, { 0.6, 0.05 } },
}

-- periodic cubic through the keys (tangents from the neighbours, uneven spacing allowed), baked to a table
local function bake(keys)
	table.sort(keys, function(a, b)
		return a[1] < b[1]
	end)
	local n = #keys
	assert(n >= 2, "a channel needs two keys")
	local function key(i) -- wraps past either end, shifting t by whole cycles
		local wrapped = (i - 1) % n
		local shift = (i - 1 - wrapped) / n
		return keys[wrapped + 1][1] + shift, keys[wrapped + 1][2]
	end
	local function tangent(i)
		local t0, v0 = key(i - 1)
		local t1, v1 = key(i + 1)
		return (v1 - v0) / (t1 - t0)
	end
	local out = table.create(SAMPLES)
	for s = 0, SAMPLES - 1 do
		local t = s / SAMPLES
		local i = n
		for k = 1, n do
			if keys[k][1] <= t then
				i = k
			end
		end
		local t0, v0 = key(i)
		if t < t0 then
			t += 1 -- before the first key: still in the segment wrapping round from the last one
		end
		local t1, v1 = key(i + 1)
		local h = t1 - t0
		local u = (t - t0) / h
		local u2, u3 = u * u, u * u * u
		out[s + 1] = (2 * u3 - 3 * u2 + 1) * v0 + (u3 - 2 * u2 + u) * h * tangent(i) + (-2 * u3 + 3 * u2) * v1 + (u3 - u2) * h * tangent(i + 1)
	end
	return out
end

local function bakeGait(name, def)
	local gait = { Name = name, Stride = def.Stride or 1, IdleArms = def.IdleArms or 1, Tables = {} }
	for _, channel in CHANNELS do
		gait.Tables[channel] = bake(assert(def[channel], name .. " has no " .. channel))
	end
	return gait
end

local BAKED = {}
for name, def in GAITS do
	BAKED[name] = bakeGait(name, def)
end
ZombieGaits.Idle = bakeGait("Idle", IDLE)

local BY_BUILD = { Normal = "Shamble", Lean = "Sprint", Bloated = "Waddle", Hulk = "Stomp", Titan = "Stomp", Gaunt = "Stalk", Crawler = "Crawl" }

function ZombieGaits.For(def)
	if def and def.Boss then
		return BAKED.Stomp
	end
	return BAKED[BY_BUILD[def and def.Look and def.Look.Build or "Normal"] or "Shamble"]
end

function ZombieGaits.Sample(gait, t, out)
	local f = (t % 1) * SAMPLES
	local i = math.floor(f)
	local frac = f - i
	local a, b = i + 1, (i + 1) % SAMPLES + 1
	for channel, values in gait.Tables do
		out[channel] = values[a] + (values[b] - values[a]) * frac
	end
	return out
end

-- One-shot moves. Time is in seconds and keys run t = 0..1 over it, always from 0 to 1. Added moves (hits, attacks)
-- sit on top of the walk, so they start and end at 0. Held moves (Boss*) replace the pose and fade in and out.
-- Attacks land at the stamp, so the windup stays short and the follow-through carries the weight.
local MOVES = {
	HitBody = {
		Time = 0.34,
		BodyPitch = { { 0, 0 }, { 0.22, 0.36 }, { 0.6, -0.07 }, { 1, 0 } },
		BodyRoll = { { 0, 0 }, { 0.22, 0.2 }, { 0.6, -0.05 }, { 1, 0 } },
		BodyYaw = { { 0, 0 }, { 0.22, 0.25 }, { 0.7, -0.05 }, { 1, 0 } },
		LeftArm = { { 0, 0 }, { 0.25, 0.7 }, { 0.7, 0.05 }, { 1, 0 } },
		RightArm = { { 0, 0 }, { 0.2, 0.5 }, { 0.65, 0.1 }, { 1, 0 } },
		LeftLeg = { { 0, 0 }, { 0.25, -0.22 }, { 1, 0 } },
		RightLeg = { { 0, 0 }, { 0.3, -0.16 }, { 1, 0 } },
		HeadPitch = { { 0, 0 }, { 0.3, 0.25 }, { 1, 0 } },
		HeadRoll = { { 0, 0 }, { 0.3, 0.18 }, { 1, 0 } },
	},
	HitHead = {
		Time = 0.42,
		HeadPitch = { { 0, 0 }, { 0.18, 0.85 }, { 0.55, -0.12 }, { 1, 0 } },
		HeadRoll = { { 0, 0 }, { 0.18, 0.3 }, { 0.6, -0.06 }, { 1, 0 } },
		BodyPitch = { { 0, 0 }, { 0.25, 0.22 }, { 0.65, -0.04 }, { 1, 0 } },
		LeftArm = { { 0, 0 }, { 0.25, 0.45 }, { 1, 0 } },
		RightArm = { { 0, 0 }, { 0.3, 0.4 }, { 1, 0 } },
	},
	HitHeavy = {
		Time = 0.24,
		BodyPitch = { { 0, 0 }, { 0.35, 0.1 }, { 1, 0 } },
		BodyRoll = { { 0, 0 }, { 0.35, 0.06 }, { 1, 0 } },
		HeadPitch = { { 0, 0 }, { 0.35, 0.14 }, { 1, 0 } },
	},
	AttackClawL = {
		Time = 0.5,
		LeftArm = { { 0, 0 }, { 0.22, 0.75 }, { 0.5, -1.1 }, { 1, 0 } },
		RightArm = { { 0, 0 }, { 0.3, 0.2 }, { 0.6, -0.2 }, { 1, 0 } },
		BodyYaw = { { 0, 0 }, { 0.22, 0.22 }, { 0.5, -0.3 }, { 1, 0 } },
		BodyPitch = { { 0, 0 }, { 0.22, 0.12 }, { 0.52, -0.28 }, { 1, 0 } },
		HeadPitch = { { 0, 0 }, { 0.22, 0.1 }, { 0.55, -0.15 }, { 1, 0 } },
	},
	AttackLungeL = {
		Time = 0.45,
		LeftArm = { { 0, 0 }, { 0.2, 0.3 }, { 0.42, 1.1 }, { 1, 0 } },
		RightArm = { { 0, 0 }, { 0.2, 0.2 }, { 0.42, 0.7 }, { 1, 0 } },
		BodyPitch = { { 0, 0 }, { 0.2, 0.12 }, { 0.42, -0.45 }, { 1, 0 } },
		Bob = { { 0, 0 }, { 0.42, -0.2 }, { 1, 0 } },
		HeadPitch = { { 0, 0 }, { 0.42, 0.3 }, { 1, 0 } },
		LeftLeg = { { 0, 0 }, { 0.42, 0.4 }, { 1, 0 } },
		RightLeg = { { 0, 0 }, { 0.42, -0.4 }, { 1, 0 } },
	},
	AttackSlam = {
		Time = 0.75,
		LeftArm = { { 0, 0 }, { 0.35, 1.9 }, { 0.55, -1.1 }, { 1, 0 } },
		RightArm = { { 0, 0 }, { 0.32, 1.9 }, { 0.53, -1.1 }, { 1, 0 } },
		BodyPitch = { { 0, 0 }, { 0.35, 0.3 }, { 0.55, -0.4 }, { 1, 0 } },
		Bob = { { 0, 0 }, { 0.35, 0.15 }, { 0.55, -0.3 }, { 1, 0 } },
		HeadPitch = { { 0, 0 }, { 0.35, 0.2 }, { 0.6, -0.2 }, { 1, 0 } },
	},
	AttackBelly = {
		Time = 0.55,
		BodyPitch = { { 0, 0 }, { 0.3, 0.25 }, { 0.55, -0.35 }, { 1, 0 } },
		Bob = { { 0, 0 }, { 0.3, -0.1 }, { 0.55, 0.08 }, { 1, 0 } },
		ArmOut = { { 0, 0 }, { 0.3, 0.4 }, { 0.55, 0.05 }, { 1, 0 } },
		HeadPitch = { { 0, 0 }, { 0.3, 0.2 }, { 0.6, -0.2 }, { 1, 0 } },
	},
	AttackLashL = {
		Time = 0.5,
		LeftArm = { { 0, 0 }, { 0.3, 1.7 }, { 0.55, 0.2 }, { 1, 0 } },
		RightArm = { { 0, 0 }, { 0.35, 0.3 }, { 1, 0 } },
		BodyYaw = { { 0, 0 }, { 0.3, 0.25 }, { 0.55, -0.3 }, { 1, 0 } },
		BodyPitch = { { 0, 0 }, { 0.3, 0.1 }, { 0.55, -0.2 }, { 1, 0 } },
		HeadPitch = { { 0, 0 }, { 0.3, 0.15 }, { 0.55, -0.1 }, { 1, 0 } },
	},
	AttackBite = {
		Time = 0.4,
		BodyPitch = { { 0, 0 }, { 0.35, 0.35 }, { 0.6, -0.2 }, { 1, 0 } },
		HeadPitch = { { 0, 0 }, { 0.35, 0.5 }, { 0.6, -0.6 }, { 1, 0 } },
		LeftArm = { { 0, 0 }, { 0.35, 0.5 }, { 0.6, -0.2 }, { 1, 0 } },
		RightArm = { { 0, 0 }, { 0.4, 0.5 }, { 0.65, -0.2 }, { 1, 0 } },
	},
	-- the boss claws out hand over hand, plants itself and straightens (over Intro.RiseTime)
	BossRise = {
		Held = true,
		Time = 3.2,
		LeftArm = { { 0, 2.4 }, { 0.15, 1.5 }, { 0.3, 2.5 }, { 0.45, 0.9 }, { 0.6, 0.3 }, { 0.75, -0.2 }, { 1, -0.5 } },
		RightArm = { { 0, 1.4 }, { 0.15, 2.5 }, { 0.3, 1.2 }, { 0.45, 2.2 }, { 0.6, 0.2 }, { 0.75, -0.3 }, { 1, -0.6 } },
		ArmOut = { { 0, 0.15 }, { 0.45, 0.2 }, { 0.7, 0.4 }, { 1, 0.15 } },
		BodyPitch = { { 0, -0.5 }, { 0.4, -0.45 }, { 0.7, -0.2 }, { 0.85, 0.05 }, { 1, -0.1 } },
		BodyRoll = { { 0, 0 }, { 0.15, 0.15 }, { 0.3, -0.15 }, { 0.45, 0.12 }, { 0.6, -0.08 }, { 1, 0 } },
		HeadPitch = { { 0, 0.5 }, { 0.6, 0.3 }, { 0.85, -0.1 }, { 1, 0.15 } },
		LeftLeg = { { 0, 0.5 }, { 0.6, 0.3 }, { 0.8, 0.1 }, { 1, 0 } },
		RightLeg = { { 0, -0.3 }, { 0.6, -0.2 }, { 0.8, 0 }, { 1, 0 } },
	},
	-- hunches to gather itself, then throws its chest out and its arms wide and holds the scream
	BossRoar = {
		Held = true,
		Time = 2.2,
		LeftArm = { { 0, -0.5 }, { 0.12, -1.1 }, { 0.25, 0.9 }, { 0.7, 0.75 }, { 1, -0.55 } },
		RightArm = { { 0, -0.6 }, { 0.12, -1.1 }, { 0.25, 0.9 }, { 0.7, 0.75 }, { 1, -0.55 } },
		ArmOut = { { 0, 0.2 }, { 0.12, 0.1 }, { 0.25, 1.1 }, { 0.7, 1 }, { 1, 0.2 } },
		BodyPitch = { { 0, -0.15 }, { 0.12, -0.5 }, { 0.25, 0.38 }, { 0.7, 0.3 }, { 1, -0.1 } },
		HeadPitch = { { 0, 0.1 }, { 0.12, -0.3 }, { 0.25, 0.7 }, { 0.7, 0.6 }, { 1, 0.1 } },
		Bob = { { 0, 0 }, { 0.12, -0.35 }, { 0.25, 0.25 }, { 0.7, 0.2 }, { 1, 0 } },
		LeftLeg = { { 0, 0 }, { 0.25, 0.2 }, { 1, 0 } },
		RightLeg = { { 0, 0 }, { 0.25, -0.2 }, { 1, 0 } },
	},
	-- rears up through the slam's windup (u runs over Slam.Windup) and drops on the shockwave
	BossSlam = {
		Held = true,
		Time = 1.3,
		LeftArm = { { 0, 0 }, { 0.25, 1.6 }, { 0.8, 2.6 }, { 0.93, 2.7 }, { 1, -1.2 } },
		RightArm = { { 0, 0 }, { 0.25, 1.6 }, { 0.8, 2.6 }, { 0.93, 2.7 }, { 1, -1.2 } },
		ArmOut = { { 0, 0.1 }, { 0.8, 0.25 }, { 1, 0.4 } },
		BodyPitch = { { 0, -0.05 }, { 0.8, 0.35 }, { 0.93, 0.38 }, { 1, -0.55 } },
		HeadPitch = { { 0, 0.1 }, { 0.8, 0.35 }, { 1, -0.2 } },
		Bob = { { 0, 0 }, { 0.8, 0.2 }, { 0.93, 0.22 }, { 1, -0.5 } },
	},
}

local function bakeOnce(keys)
	local n = #keys
	assert(keys[1][1] == 0 and keys[n][1] == 1, "a move's keys run from 0 to 1")
	local function tangent(i)
		if i == 1 or i == n then
			return 0
		end
		return (keys[i + 1][2] - keys[i - 1][2]) / (keys[i + 1][1] - keys[i - 1][1])
	end
	local out = table.create(SAMPLES + 1)
	for s = 0, SAMPLES do
		local t = s / SAMPLES
		local i = 1
		while i < n - 1 and keys[i + 1][1] <= t do
			i += 1
		end
		local t0, v0, t1, v1 = keys[i][1], keys[i][2], keys[i + 1][1], keys[i + 1][2]
		local h = t1 - t0
		local u = math.clamp((t - t0) / h, 0, 1)
		local u2, u3 = u * u, u * u * u
		out[s + 1] = (2 * u3 - 3 * u2 + 1) * v0 + (u3 - 2 * u2 + u) * h * tangent(i) + (-2 * u3 + 3 * u2) * v1 + (u3 - u2) * h * tangent(i + 1)
	end
	return out
end

local SWAP = { LeftArm = "RightArm", RightArm = "LeftArm", LeftLeg = "RightLeg", RightLeg = "LeftLeg" }
local SIDEWAYS = { BodyRoll = true, BodyYaw = true, HeadRoll = true }

local function mirrored(def)
	local out = { Time = def.Time }
	for channel, keys in def do
		if channel ~= "Time" then
			local copy = {}
			for i, key in keys do
				copy[i] = { key[1], if SIDEWAYS[channel] then -key[2] else key[2] }
			end
			out[SWAP[channel] or channel] = copy
		end
	end
	return out
end
MOVES.AttackClawR = mirrored(MOVES.AttackClawL)
MOVES.AttackLungeR = mirrored(MOVES.AttackLungeL)
MOVES.AttackLashR = mirrored(MOVES.AttackLashL)

ZombieGaits.Moves = {}
for name, def in MOVES do
	local move = { Name = name, Time = def.Time, Held = def.Held, Tables = {} }
	for channel, keys in def do
		if channel ~= "Time" and channel ~= "Held" then
			move.Tables[channel] = bakeOnce(keys)
		end
	end
	ZombieGaits.Moves[name] = move
end

local M = ZombieGaits.Moves
BAKED.Shamble.Attacks = { M.AttackClawL, M.AttackClawR }
BAKED.Sprint.Attacks = { M.AttackLungeL, M.AttackLungeR }
BAKED.Waddle.Attacks = { M.AttackBelly }
BAKED.Stomp.Attacks = { M.AttackSlam }
BAKED.Stalk.Attacks = { M.AttackLashL, M.AttackLashR }
BAKED.Crawl.Attacks = { M.AttackBite }

function ZombieGaits.Hit(gait, head)
	if gait == BAKED.Stomp then
		return M.HitHeavy
	end
	return if head then M.HitHead else M.HitBody
end

local function read(values, u)
	local f = math.clamp(u, 0, 1) * SAMPLES
	local i = math.min(math.floor(f), SAMPLES - 1)
	return values[i + 1] + (values[i + 2] - values[i + 1]) * (f - i)
end

function ZombieGaits.Add(move, u, pose, flip)
	for channel, values in move.Tables do
		local v = read(values, u)
		pose[channel] += if flip and SIDEWAYS[channel] then -v else v
	end
end

function ZombieGaits.Set(move, u, out)
	for channel, values in move.Tables do
		out[channel] = read(values, u)
	end
end

-- self-check: every cycle loops without a jump, and added moves start and end at rest
for name, gait in BAKED do
	for channel, values in gait.Tables do
		assert(math.abs(values[1] - values[SAMPLES]) < 0.2, name .. " " .. channel .. " jumps at the loop")
	end
end
for name, move in ZombieGaits.Moves do
	if not move.Held then
		for channel, values in move.Tables do
			assert(math.abs(values[1]) < 1e-6 and math.abs(values[SAMPLES + 1]) < 1e-6, name .. " " .. channel .. " must start and end at 0")
		end
	end
end

return ZombieGaits
