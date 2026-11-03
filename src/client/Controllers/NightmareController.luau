-- NightmareController: the client side of the Nightmare pad on the Flight Line (Map/FlightLine
-- buildNightmare; Config/Nightmare). For a player who has unlocked Nightmare (Stats.Victories in
-- AchievementsJson) the cage's chained gate opens locally: no collision, chains and panels hidden. The
-- character is client-owned, so walking through works; everyone else still hits the gate, and
-- QueueService refuses to board them anyway. The gate sign shows this player's progress or the pad's squad.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameState = require(Shared.GameState)
local Nightmare = require(Shared.Config.Nightmare)

local player = Players.LocalPlayer
local PAD_ID = 5

local NightmareController = {}

local function decode(attr)
	local ok, value = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute(attr) or GameState:GetAttribute(attr) or "")
	return if ok and type(value) == "table" then value else {}
end

function NightmareController:Start()
	while true do
		local lobby = workspace:FindFirstChild("OurMap") and workspace.OurMap:FindFirstChild("Lobby")
		local cage = lobby and lobby:FindFirstChild("FlightLine") and lobby.FlightLine:FindFirstChild("Nightmare")
		if cage then -- streamed in
			local wins = decode("AchievementsJson").Stats
			wins = wins and wins.Victories or 0
			local open = Nightmare.Unlocked({ Victories = wins })
			local gate = cage:FindFirstChild("Gate")
			for _, p in if gate then gate:GetChildren() else {} do
				p.CanCollide = not open and p.Name == "Panel"
				p.Transparency = if open then 1 elseif p.Name == "Panel" then 0.2 else 0
			end
			local label = cage:FindFirstChild("Sign") and cage.Sign:FindFirstChild("Text", true)
			if label then
				local pad = decode("Pad" .. PAD_ID)
				label.Text = if not open then string.format("🔒 NIGHTMARE · %d/%d WINS", math.min(wins, Nightmare.WinsToUnlock), Nightmare.WinsToUnlock)
					elseif (pad.Count or 0) > 0 then string.format("NIGHTMARE · %d/%d", pad.Count, pad.Size)
					else "NIGHTMARE · OPEN"
			end
		end
		task.wait(0.5)
	end
end

return NightmareController
