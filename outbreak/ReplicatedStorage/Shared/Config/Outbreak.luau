-- Outbreak: the million-zombie mode. Pad 6 on the Flight Line (Map/ModePad) queues it; QueueService
-- takes its squad to THIS place (PlaceId below) in a fresh reserved server, where MatchService
-- tags Mode = "Outbreak" and runs the rules below. KillGoal is the win condition: the horde is
-- shared server-wide (GameState OutbreakKills), so every kill moves the squad toward a million.

local Outbreak = {
	Id = "Outbreak",
	Name = "OUTBREAK",
	Desc = "The horde is a million deep. Survive it.",
	PlaceId = 87622086122699, -- the mode's own place (created 2026-11-03)
	LobbyPlaceId = 110463048909417, -- the safehouse lobby; ReturnToLobby sends players back here

	-- the swarm (read by MatchService:_playWave when Mode = "Outbreak")
	TotalWaves = 999, -- effectively endless: the kill meter is the real win condition
	BaseCount = 40, -- was GameConfig.Waves.BaseCount (8)
	CountPerWave = 30, -- was 6
	CountMult = 3, -- extra horde multiplier on the wave math
	MaxAlive = 260, -- was ~70: the screen-filling crowd (tune down if phones struggle)
	HealthMult = 0.5, -- little health: 2-3 pistol hits on a Shambler (60 base -> 30), not one shot
	ZombieDamageMult = 0.085, -- just a little stronger (CombatService:DamagePlayer) — the horde is the threat, not the bites
	Scale = 0.8, -- a little smaller than regular
	ExtraPlayerMultiplier = 0.6, -- squads multiply the horde a bit less (it is already huge)

	-- the shared kill meter (read by ZombieService:Kill)
	KillGoal = 1000000, -- the millionth zombie wins the server
	Milestones = { 1000, 10000, 100000, 250000, 500000, 750000 },

	-- the guns (MatchService.PlayerDamageMult, read by ZombieService:Damage)
	PlayerDamageMult = 1, -- normal guns: zombies have little health but are NOT one shot (user request)
}

return Outbreak