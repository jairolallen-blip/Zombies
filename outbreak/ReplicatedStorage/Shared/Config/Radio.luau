-- Radio: the commander's lines (vault: Match Start.md). PURE DATA.
-- MatchService picks a random line for an event and sends it to run players (Remotes.Radio);
-- Client/Controllers/RadioController shows it next to the commander's portrait.
-- "{wave}" is replaced with the wave number. The tutorial's step lines live in Config/Tutorial.
-- Tutorial and Nightmare runs use "Tutorial<event>" / "Nightmare<event>" over "<event>" when it exists.

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
	-- First-time players' training run (MatchService uses "Tutorial<event>" over "<event>" when it exists)
	TutorialDeploy = {
		"Rookie, this is Overwatch. Training drop: three waves in the old city, then I bring you home.",
	},
	TutorialVictory = {
		"That's how it's done, rookie. Bird's coming to take you to the safehouse. Gear up there, then pick a pad on the Flight Line.",
	},
	-- Nightmare runs (Config/Nightmare): the radio breaks up and Voss stops pretending there's a plan.
	-- At the boss the signal dies; he only comes back if the Titan falls.
	NightmareDeploy = {
		"Overwatch to squad... we've lost contact with every other team. If you hear this, you're all that's left.",
		"This drop isn't on any map. Command stopped answering an hour ago. I'm flying you in anyway.",
	},
	NightmareDrop = {
		"Go. And... I'm sorry.",
		"Jump. Don't look down for long.",
	},
	NightmareLanded = {
		"You're down. The lights went out over the whole city. Whatever's out there can see better than you.",
		"Boots on the ground. The Bloom's been here too long. Nothing in there is what it used to be.",
	},
	NightmareIncoming = {
		"Thermal's whiting out. There are too many to count.",
	},
	NightmareFirstWave = {
		"They're coming. Don't waste a single round.",
	},
	NightmareWaveStart = {
		"Wave {wave}. ...I don't have anything else to tell you.",
		"Wave {wave}. They're bigger than they were yesterday.",
		"Signal's... *static* ...wave {wave}... *static*",
		"Wave {wave}. Keep each other alive. Nobody else will.",
	},
	NightmareWaveCleared = {
		"Wave {wave}... you're still breathing. I didn't think you would be.",
		"Quiet again. It won't be for long.",
		"*static* ...still reading you. Barely.",
	},
	NightmareAirdrop = {
		"Last crate on the carrier. Make it count.",
	},
	NightmareBossIncoming = {
		"Something's moving under the square... it's the Titan, but wrong. Bigger. I'm losing the sig— *static*",
	},
	NightmareBossEnraged = {
		"*static*",
	},
	NightmareBossDown = {
		"*static* ...squad? Squad, the reading's gone. Did you... did you actually kill it?",
	},
	NightmareVictory = {
		"I'd stopped writing your names down. Bird's coming. You're coming home.",
	},
	NightmareOverrun = {
		"...",
		"Overwatch... out.",
	},
	TutorialOverrun = {
		"Rough first day, rookie. Pulling you out to the safehouse. Gear up and try again from the Flight Line.",
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
