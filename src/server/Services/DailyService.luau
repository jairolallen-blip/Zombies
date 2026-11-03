-- DailyService: the DAILY RATIONS cache by the lobby flag (vault: Lobby.md; built by Server/Map/DailyCache).
-- Holding its "Claim" prompt (attribute Daily) once per UTC day pays Gems. Claiming on consecutive days
-- grows a streak up to 7 (REWARDS), which then starts over; missing a day resets it to day 1.
-- Profile fields DailyStreak and DailyDay (DataService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)

local DailyService = {}
local Services

local REWARDS = { 40, 60, 80, 100, 125, 150, 250 } -- Gems for day 1..7 of a streak
local DAY = 86400

-- pure: (profile fields, today) -> new streak, Gems, or nil when already claimed today
function DailyService.Next(streak, lastDay, today)
	if lastDay == today then
		return nil
	end
	local day = if lastDay == today - 1 then streak % #REWARDS + 1 else 1
	return day, REWARDS[day]
end

function DailyService:Init(services)
	Services = services
end

function DailyService:Start()
	local lobby = workspace:WaitForChild(GameConfig.OurMap.Folder):WaitForChild("Lobby")
	local cache = lobby:WaitForChild("DailyCache", 10)
	local prompt = cache and cache:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Triggered:Connect(function(player)
			self:Claim(player)
		end)
	end
end

function DailyService:Claim(player)
	local profile = Services.DataService:Get(player)
	if not profile or Services.MatchService:IsInRun(player) then
		return
	end
	local now = os.time()
	local today = now // DAY
	local streak, gems = DailyService.Next(profile.DailyStreak, profile.DailyDay, today)
	if not streak then
		local left = (today + 1) * DAY - now
		return Remotes.Notify:FireClient(player, string.format("Already claimed today. Fresh rations in %dh %dm.", left // 3600, left % 3600 // 60), "Info")
	end
	profile.DailyStreak = streak
	profile.DailyDay = today
	Services.DataService:AddGems(player, gems)
	local tail = if streak < #REWARDS then string.format(" Tomorrow: +%d.", REWARDS[streak + 1]) else " Full week! The streak starts over tomorrow."
	Remotes.Notify:FireClient(player, string.format("DAILY RATIONS day %d: +%d Gems!", streak, gems) .. tail, "Good")
end

return DailyService
