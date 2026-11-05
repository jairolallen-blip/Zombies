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
--   ZombieGaits.Idle, ZombieGaits.Attack(u)      standing pose; the swipe curve for u = 0..1

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

-- The swipe: arms cock back up (anticipation), slam down fast, then recover slowly. u = 0..1 over the attack.
local WINDUP, STRIKE = 0.3, 0.55
function ZombieGaits.Attack(u)
	if u < WINDUP then
		local k = u / WINDUP
		return 0.7 * k * k * (3 - 2 * k)
	elseif u < STRIKE then
		local k = (u - WINDUP) / (STRIKE - WINDUP)
		return 0.7 - 1.9 * k * k
	end
	local k = (u - STRIKE) / (1 - STRIKE)
	return -1.2 * (1 - k * k * (3 - 2 * k))
end

-- self-check: every cycle loops without a jump, and the swipe starts and ends at rest
for name, gait in BAKED do
	for channel, values in gait.Tables do
		assert(math.abs(values[1] - values[SAMPLES]) < 0.2, name .. " " .. channel .. " jumps at the loop")
	end
end
assert(math.abs(ZombieGaits.Attack(0)) < 1e-6 and math.abs(ZombieGaits.Attack(1)) < 1e-6, "swipe must start and end at rest")

return ZombieGaits
