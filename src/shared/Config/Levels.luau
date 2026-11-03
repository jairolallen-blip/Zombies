-- Levels: account XP and levels (owner design 2026-11-03; vault: Levels.md). PURE DATA + math.
-- Each run pays XP for how it went (MatchService:_endRun -> DataService:AddXP); the profile keeps the
-- running total (XP) and the level is worked out from it. The welcome screen's run report fills the level
-- bar from before the run to now, levelling up on the way (WelcomeController).
--   Levels.RunXP(kills, wavesCleared, victory, nightmare)   XP one run pays
--   Levels.FromXP(xp) -> level, xp into that level, xp that level needs
--   Levels.Credit(stats)   starting XP for saves from before levels (from their Stats history)
--   Levels.Rank(level)     the rank title for a level (Levels.Ranks)

local Levels = {}

Levels.PerKill = 1
Levels.PerWave = 20 -- per wave cleared
Levels.Victory = 150
Levels.NightmareMult = 2 -- the whole run's XP, win or lose
Levels.Base = 100 -- XP from level 1 to 2
Levels.Step = 40 -- every level needs this much more than the one before

-- rank titles by level (our own, from the Port Harrow lore), shown next to LEVEL n
Levels.Ranks = {
	{ 1, "STRAY" },
	{ 3, "SCAVENGER" },
	{ 6, "LOOKOUT" },
	{ 10, "SURVIVOR" },
	{ 15, "SALVAGER" },
	{ 20, "WARDEN" },
	{ 30, "VETERAN" },
	{ 45, "HARBOR GHOST" },
	{ 60, "LEGEND OF PORT HARROW" },
}

function Levels.Rank(level)
	local name = Levels.Ranks[1][2]
	for _, r in Levels.Ranks do
		if level >= r[1] then
			name = r[2]
		end
	end
	return name
end

function Levels.Need(level)
	return Levels.Base + Levels.Step * (level - 1)
end

function Levels.FromXP(xp)
	local level = 1
	while xp >= Levels.Need(level) do
		xp -= Levels.Need(level)
		level += 1
	end
	return level, xp, Levels.Need(level)
end

function Levels.RunXP(kills, wavesCleared, victory, nightmare)
	local xp = kills * Levels.PerKill + wavesCleared * Levels.PerWave + (if victory then Levels.Victory else 0)
	return math.floor(xp * (if nightmare then Levels.NightmareMult else 1))
end

function Levels.Credit(stats)
	return Levels.RunXP(stats.Kills or 0, stats.WavesCleared or 0, false, false) + (stats.Victories or 0) * Levels.Victory
end

-- self-check: 100 XP is exactly level 2; 99 is 99 into level 1; 240 reaches level 3
assert(Levels.FromXP(100) == 2 and select(2, Levels.FromXP(99)) == 99 and Levels.FromXP(240) == 3, "Levels.FromXP")

return Levels
