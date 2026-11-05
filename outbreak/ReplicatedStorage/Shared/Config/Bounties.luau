-- Bounties: daily tasks on the BOUNTY BOARD by the Flight Line gate (vault: Bounties.md). PURE DATA + the
-- daily pick. Every UTC day the same three bounties come up for everyone (Bounties.ForDay). A player tracks
-- one at a time; only the tracked one counts progress (Server/Services/DataService, profile Bounty), and
-- finishing it pays its Gems straight away. Progress is kept per bounty, so switching doesn't lose it.
--
-- Entry: { Id, Name, Desc, Stat, Goal, Gems, Max? }. Stat is a key DataService:AddStat counts (see
-- Config/Achievements); Max = the stat reports a best value (BestWave), so progress is the highest seen.
-- Ids are saved in profiles: rename the Name freely, never an Id.

local Bounties = {}

Bounties.PerDay = 3
Bounties.Day = 86400

Bounties.Pool = {
	{ Id = "Herd", Name = "THIN THE HERD", Desc = "Kill 150 zombies.", Stat = "Kills", Goal = 150, Gems = 150 },
	{ Id = "Runners", Name = "FAST TALKERS", Desc = "Kill 40 Runners.", Stat = "Kills_Runner", Goal = 40, Gems = 150 },
	{ Id = "Bloaters", Name = "POP GOES THE BLOOM", Desc = "Kill 20 Bloaters.", Stat = "Kills_Bloater", Goal = 20, Gems = 175 },
	{ Id = "Brutes", Name = "BIG GAME", Desc = "Kill 15 Brutes.", Stat = "Kills_Brute", Goal = 15, Gems = 250 },
	{ Id = "Headshots", Name = "CLEAN SHOTS", Desc = "Get 60 headshot kills.", Stat = "Headshots", Goal = 60, Gems = 200 },
	{ Id = "Waves", Name = "HOLD THE LINE", Desc = "Clear 15 waves.", Stat = "WavesCleared", Goal = 15, Gems = 150 },
	{ Id = "Wave8", Name = "DEEP DROP", Desc = "Reach wave 8 in one run.", Stat = "BestWave", Goal = 8, Gems = 200, Max = true },
	{ Id = "Crates", Name = "SUPPLY RUN", Desc = "Open 2 supply crates.", Stat = "Airdrops", Goal = 2, Gems = 175 },
	{ Id = "Victory", Name = "TITAN SLAYER", Desc = "Win a run.", Stat = "Victories", Goal = 1, Gems = 400 },
}

Bounties.ById = {}
for _, b in Bounties.Pool do
	Bounties.ById[b.Id] = b
end

function Bounties.Today(serverTime)
	return math.floor(serverTime / Bounties.Day)
end

-- the day's bounties, the same on every server and client (seeded by the day number)
function Bounties.ForDay(day)
	local rng = Random.new(day)
	local ids = {}
	for _, b in Bounties.Pool do
		table.insert(ids, b.Id)
	end
	local picked = {}
	for _ = 1, Bounties.PerDay do
		table.insert(picked, Bounties.ById[table.remove(ids, rng:NextInteger(1, #ids))])
	end
	return picked
end

return Bounties
