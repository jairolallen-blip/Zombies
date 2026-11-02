-- Radio: the commander's lines (vault: Match Start.md). PURE DATA.
-- MatchService picks a random line for an event and sends it to run players (Remotes.Radio);
-- Client/Controllers/RadioController shows it next to the commander's portrait.
-- "{wave}" is replaced with the wave number.

local Radio = {}

Radio.Speaker = { Name = "SGT. VOSS", Callsign = "OVERWATCH" }

Radio.Lines = {
	Deploy = {
		"Overwatch to squad. Wheels up — we're dropping you into the city square.",
		"Squad, this is Overwatch. Bird's in the air. Check your weapons.",
	},
	Drop = {
		"Green light! Go, go, go!",
		"Over the square — jump!",
	},
	Landed = {
		"Boots on the ground. That rotor noise will draw them in — find cover and get ready.",
		"You're down. Every infected in the city heard that chopper. Dig in.",
	},
	Incoming = {
		"Movement on every street. Here they come!",
		"Thermal is lighting up all around you. Get ready!",
	},
	FirstWave = {
		"Contact! They're coming from every direction — watch your backs!",
	},
	WaveStart = {
		"Wave {wave} inbound. Hold the square!",
		"Contact! Wave {wave}, multiple directions!",
		"They're pouring out of the alleys. Wave {wave}!",
		"Bigger group this time. Wave {wave}, stay together!",
	},
	Airdrop = {
		"Supply drop inbound! Red smoke marks the crate. Fight your way to it!",
		"Dropping you a care package. Watch the red smoke, it'll be swarmed!",
		"Crate's on the way down. Grab it before the horde does!",
	},
	WaveCleared = {
		"Wave {wave} down. Reload and spend that cash.",
		"Good work. Catch your breath — there's more coming.",
		"Area's quiet. Won't last. Upgrade while you can.",
	},
	BossIncoming = {
		"Seismic readings off the chart... something huge is digging up under the square. It's the Titan!",
		"Final wave. The big one's surfacing — put everything you've got into it!",
	},
	BossEnraged = {
		"It's enraged! It's calling the runners — watch your flanks!",
	},
	BossDown = {
		"The Titan is down! Mop up the rest!",
	},
	Victory = {
		"Area secured. Outstanding work, squad — bird's on its way to pull you out.",
	},
	Overrun = {
		"Squad's gone dark... Overwatch out.",
		"We lost them. Pull the bird back.",
	},
}

function Radio.Pick(event, vars)
	local lines = Radio.Lines[event]
	if not lines then
		return nil
	end
	local text = lines[math.random(1, #lines)]
	return (text:gsub("{(%w+)}", function(key)
		return tostring(vars and vars[key] or "")
	end))
end

return Radio
