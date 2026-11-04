-- Outbreak: the million-zombie mode. Pad 6 on the Flight Line (Map/ModePad) queues it; QueueService
-- takes its squad to THIS place (PlaceId below) in a fresh reserved server, where MatchService runs
-- the match tagged Mode = "Outbreak" (GameState.Mode). The mode's own rules (half-size swarms,
-- million-kill meter, overpowered guns) live here as the design lands.

local Outbreak = {
	Id = "Outbreak",
	Name = "OUTBREAK",
	Desc = "The horde is a million deep. Survive it.",
	PlaceId = 87622086122699, -- the mode's own place (created 2026-11-03)
	LobbyPlaceId = 110463048909417, -- the safehouse lobby; ReturnToLobby sends players back here
}

return Outbreak