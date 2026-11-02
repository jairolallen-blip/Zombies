-- GameState: the one replicated Configuration instance holding match-wide state as attributes.
-- Server writes it (mostly MatchService); clients read with GetAttribute / GetAttributeChangedSignal.
-- require() returns the Instance itself:  GameState:GetAttribute("Wave")
--
-- Attributes:
--   Phase          "Lobby" | "Deploy" | "Break" | "Wave" | "Results"
--   DeployPath (JSON [[x,y,z],...]), DeployStart (server time), DeployDuration   drop-in cutscene
--     (MapService:GetDeployFlight -> CutsceneController)
--   Wave           current wave number (0 in lobby)
--   Timer          seconds left in the Break countdown
--   ZombiesLeft    zombies still to spawn + alive this wave
--   RunWon         true when the last run cleared every wave (read during "Results")
--   BossEnraged    true once the boss passed its enrage threshold
--   BossName       "" when no boss alive
--   BossHealth, BossMaxHealth
--   ServerKind     "Lobby" | "Match" (a squad's reserved server; MatchService.IsMatchServer)
--   Difficulty, MapId, Tutorial   the current run's mission (MatchService:RunMatch)
--   Pad1..Pad4     JSON state of each Flight Line pad (QueueService)

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DEFAULTS = {
	Phase = "Lobby",
	Wave = 0,
	Timer = 0,
	ZombiesLeft = 0,
	BossName = "",
	BossHealth = 0,
	BossMaxHealth = 0,
	ServerKind = "Lobby",
	Difficulty = "Normal",
	MapId = "City",
	Tutorial = false,
}

local state
if RunService:IsServer() then
	state = ReplicatedStorage:FindFirstChild("GameState") or Instance.new("Configuration")
	state.Name = "GameState"
	for key, value in DEFAULTS do
		if state:GetAttribute(key) == nil then
			state:SetAttribute(key, value)
		end
	end
	state.Parent = ReplicatedStorage
else
	state = ReplicatedStorage:WaitForChild("GameState")
end

return state
