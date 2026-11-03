-- Nightmare: the hard mode (vault: Nightmare Mode.md). PURE DATA plus the unlock check.
-- Queued on its own pad on the Flight Line (Map/FlightLine builds it behind a chained gate; the pad
-- model has attribute Nightmare = true). QueueService only boards players who have unlocked it, and
-- MatchService plays the run with these multipliers, the Nightmare weather (Config/Conditions) and the
-- commander's "Nightmare<event>" lines (Config/Radio). Gems are paid only for a win.

local Nightmare = {
	WinsToUnlock = 3, -- normal-mode victories (profile Stats.Victories) before the gate opens
	TotalWaves = 10,
	CountMult = 1.3, -- zombies per wave
	ExtraPlayerMultiplier = 0.15, -- each extra player adds +15% zombies (Normal adds 60%: GameConfig.Waves)
	HealthMult = 1.5, -- zombie health (on top of the per-wave scaling)
	BossHealthMult = 1.5,
	ZombieDamageMult = 1.35, -- damage zombies deal to players (CombatService:DamagePlayer)
	GemsMult = 3, -- a win pays the normal formula x3; a loss pays nothing
	Music = { Id = 1837172508, Volume = 0.18 }, -- APM, "The Fear Within": a quiet loop under the run (NightmareController)
	-- "Heartbeat (loop)": louder and faster the more zombies are within Radius studs (Full of them = loudest)
	Heartbeat = { Id = 6202853067, Volume = 0.6, Radius = 22, Full = 6 },
	Lamps = { Dead = 0.35, Flicker = 0.3 }, -- share of the city's street lamps that are out / flickering (same for everyone)
}

-- stats: a profile's Stats table (server) or the Stats in AchievementsJson (client)
function Nightmare.Unlocked(stats)
	return (stats and stats.Victories or 0) >= Nightmare.WinsToUnlock
end

return Nightmare
