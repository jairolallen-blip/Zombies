-- GameState: the one replicated Configuration instance holding match-wide state as attributes.
-- Server writes it (mostly MatchService); clients read with GetAttribute / GetAttributeChangedSignal.
-- require() returns the Instance itself:  GameState:GetAttribute("Wave")
--
-- Attributes:
--   Phase          "Lobby" | "Deploy" | "Break" | "Wave" | "Results"
--   DeployFrom, DeployTo (Vector3), DeployStart (server time), DeployDuration   drop-in cutscene
--   Wave           current wave number (0 in lobby)
--   Timer          seconds left in Lobby countdown or Break
--   ZombiesLeft    zombies still to spawn + alive this wave
--   BossName       "" when no boss alive
--   BossHealth, BossMaxHealth
--   PlayerCount, ReadyCount   lobby readiness

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
	PlayerCount = 0,
	ReadyCount = 0,
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
