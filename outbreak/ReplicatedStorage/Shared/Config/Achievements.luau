-- Achievements: lifetime goals that pay Gems, claimed at the Commendations board in the lobby
-- (vault: Lobby.md). Progress lives in the profile's Stats table (DataService:AddStat), claims in
-- Claimed; both reach the client as the AchievementsJson attribute.
--
-- Entry: { Id, Name, Desc, Stat, Goal, Gems }. Stat is a key of profile.Stats:
--   Kills, Kills_<zombie type> (Shambler, Runner, Bloater, Brute, GraveTitan), Headshots (headshot
--   kills), WavesCleared, BestWave (highest wave reached), Runs, Victories, Wins_<class id>,
--   Airdrops (supply crates opened), or the computed "ClassWins" (classes with at least one win).
-- Ids are saved in profiles: rename the Name freely, never an Id.

local Achievements = {}

Achievements.List = {
	-- the horde
	{ Id = "Kills100", Name = "First Blood", Desc = "Kill 100 zombies", Stat = "Kills", Goal = 100, Gems = 25 },
	{ Id = "Kills1000", Name = "Thinning the Herd", Desc = "Kill 1,000 zombies", Stat = "Kills", Goal = 1000, Gems = 100 },
	{ Id = "Kills5000", Name = "Exterminator", Desc = "Kill 5,000 zombies", Stat = "Kills", Goal = 5000, Gems = 300 },
	{ Id = "Kills25000", Name = "A Million Starts Somewhere", Desc = "Kill 25,000 zombies", Stat = "Kills", Goal = 25000, Gems = 1000 },
	{ Id = "Head50", Name = "Steady Aim", Desc = "Get 50 headshot kills", Stat = "Headshots", Goal = 50, Gems = 25 },
	{ Id = "Head500", Name = "Marksman", Desc = "Get 500 headshot kills", Stat = "Headshots", Goal = 500, Gems = 150 },
	{ Id = "Head2500", Name = "One Tap", Desc = "Get 2,500 headshot kills", Stat = "Headshots", Goal = 2500, Gems = 500 },
	-- specific zombies
	{ Id = "Runner200", Name = "Track Meet", Desc = "Kill 200 Runners", Stat = "Kills_Runner", Goal = 200, Gems = 75 },
	{ Id = "Bloater100", Name = "Pop Goes the Bloater", Desc = "Kill 100 Bloaters", Stat = "Kills_Bloater", Goal = 100, Gems = 75 },
	{ Id = "Brute50", Name = "Bigger They Are", Desc = "Kill 50 Brutes", Stat = "Kills_Brute", Goal = 50, Gems = 100 },
	{ Id = "Titan1", Name = "Titan Slayer", Desc = "Defeat the Grave Titan", Stat = "Kills_GraveTitan", Goal = 1, Gems = 150 },
	{ Id = "Titan10", Name = "Grave Robber", Desc = "Defeat the Grave Titan 10 times", Stat = "Kills_GraveTitan", Goal = 10, Gems = 500 },
	-- waves and runs
	{ Id = "Waves10", Name = "Holding the Line", Desc = "Clear 10 waves", Stat = "WavesCleared", Goal = 10, Gems = 25 },
	{ Id = "Waves100", Name = "Veteran", Desc = "Clear 100 waves", Stat = "WavesCleared", Goal = 100, Gems = 150 },
	{ Id = "Waves500", Name = "Old Guard", Desc = "Clear 500 waves", Stat = "WavesCleared", Goal = 500, Gems = 500 },
	{ Id = "Reach5", Name = "Halfway There", Desc = "Reach wave 5", Stat = "BestWave", Goal = 5, Gems = 25 },
	{ Id = "Runs10", Name = "Frequent Flyer", Desc = "Deploy 10 times", Stat = "Runs", Goal = 10, Gems = 50 },
	{ Id = "Win1", Name = "Last Light", Desc = "Survive all 10 waves", Stat = "Victories", Goal = 1, Gems = 200 },
	{ Id = "Win10", Name = "Legend of the City", Desc = "Survive all 10 waves 10 times", Stat = "Victories", Goal = 10, Gems = 750 },
	{ Id = "AllClasses", Name = "Jack of All Trades", Desc = "Win a run as every class", Stat = "ClassWins", Goal = 5, Gems = 750 },
	-- supply drops
	{ Id = "Drop1", Name = "Special Delivery", Desc = "Open a supply drop", Stat = "Airdrops", Goal = 1, Gems = 25 },
	{ Id = "Drop25", Name = "Scavenger", Desc = "Open 25 supply drops", Stat = "Airdrops", Goal = 25, Gems = 150 },
}

Achievements.ById = {}
for _, def in Achievements.List do
	Achievements.ById[def.Id] = def
end

-- Current progress toward def.Goal from a Stats table
function Achievements.Progress(def, stats)
	if def.Stat == "ClassWins" then
		local n = 0
		for key, value in stats do
			if key:sub(1, 5) == "Wins_" and value > 0 then
				n += 1
			end
		end
		return n
	end
	return stats[def.Stat] or 0
end

return Achievements
