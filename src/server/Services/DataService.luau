-- DataService: persistent player profiles (Gems, unlocks, equipped class, gun loadout, best wave).
-- Saved with DataStoreService. If DataStores are unavailable (Studio without API access) it
-- runs in memory-only mode and never overwrites real data.
--
-- Profile shape (DEFAULT_PROFILE). Add a field there and it is back-filled into old saves.
-- Replicated to the owning client as player attributes:
--   Gems, BestWave, ClassId, OwnedJson ('{"Classes":{...},"Weapons":{...}}'),
--   LoadoutJson ('["Pistol","SMG",...]' — one weapon id per Level),
--   AchievementsJson ('{"Stats":{...},"Claimed":{...}}'; Config/Achievements)
-- Achievements: :AddStat(player, key, amount, isMax) counts progress (toast when one completes);
-- the ClaimAchievement remote pays its Gems once.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Classes = require(Shared.Config.Classes)
local Weapons = require(Shared.Config.Weapons)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)
local Achievements = require(Shared.Config.Achievements)

local function freeWeapons()
	local owned = {}
	for id, def in Weapons.List do
		if def.GemCost == 0 then
			owned[id] = true
		end
	end
	return owned
end

local function defaultLoadout()
	local loadout = {}
	for level = 1, Weapons.Levels do
		loadout[level] = Weapons.DefaultFor(level)
	end
	return loadout
end

local DEFAULT_PROFILE = {
	Version = 1,
	Gems = 0,
	OwnedClasses = { [Classes.Default] = true },
	OwnedWeapons = freeWeapons(), -- reconcile() back-fills new free guns into old saves
	EquippedClass = Classes.Default,
	Loadout = defaultLoadout(), -- [level] = weapon id
	BestWave = 0,
	TotalKills = 0,
	RunsPlayed = 0,
	Stats = {}, -- achievement progress, [stat key] = number (Config/Achievements)
	Claimed = {}, -- [achievement id] = true
}

local DataService = {}
DataService.ProfileLoaded = Util.Signal.new() -- (player, profile)

local profiles = {} -- [Player] = profile table
local noSave = {} -- [Player] = true when the load failed (never overwrite their real data)
local store = nil

local function deepCopy(t)
	local copy = {}
	for k, v in t do
		copy[k] = if type(v) == "table" then deepCopy(v) else v
	end
	return copy
end

local function reconcile(data, template)
	for k, v in template do
		if data[k] == nil then
			data[k] = if type(v) == "table" then deepCopy(v) else v
		elseif type(v) == "table" and type(data[k]) == "table" then
			reconcile(data[k], v)
		end
	end
	return data
end

local function keyFor(player)
	return "u_" .. player.UserId
end

local function isAccessError(err)
	local msg = tostring(err)
	return msg:find("403") or msg:find("Studio") or msg:find("not allowed") or msg:find("publish")
end

function DataService:Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.Data.StoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStores unavailable, memory-only mode:", result)
	end
end

function DataService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:Load(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(self.Load, self, player)
	end
	Remotes.ClaimAchievement.OnServerEvent:Connect(function(player, id)
		self:ClaimAchievement(player, id)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:Save(player)
		profiles[player] = nil
		noSave[player] = nil
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(self.Save, self, player)
		end
		task.wait(2)
	end)
end

function DataService:Load(player)
	local data = nil
	local loaded = store == nil
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(store.GetAsync, store, keyFor(player))
			if ok then
				data = result
				loaded = true
				break
			end
			if isAccessError(result) then
				warn("[DataService] No DataStore access (enable 'Studio Access to API Services' to persist). Memory-only.")
				store = nil
				loaded = true
				break
			end
			task.wait(attempt)
		end
	end
	if not loaded then
		noSave[player] = true
		warn("[DataService] Failed to load profile for", player.Name, "- this session will not save.")
	end
	if not player.Parent then
		return
	end

	local isNew = data == nil
	data = reconcile(data or deepCopy(DEFAULT_PROFILE), DEFAULT_PROFILE)
	if isNew and RunService:IsStudio() then
		data.Gems = GameConfig.Data.StudioStartingGems
	end
	-- Equipped items must still exist in config (an item may have been removed/renamed)
	if not Classes.List[data.EquippedClass] then
		data.EquippedClass = Classes.Default
	end
	for level = 1, Weapons.Levels do
		local id = data.Loadout[level]
		local def = Weapons.List[id]
		if not def or def.Level ~= level or not data.OwnedWeapons[id] then
			data.Loadout[level] = Weapons.DefaultFor(level)
		end
	end

	-- credit progress from before achievements existed
	local stats = data.Stats
	stats.Kills = math.max(stats.Kills or 0, data.TotalKills)
	stats.Runs = math.max(stats.Runs or 0, data.RunsPlayed)
	stats.BestWave = math.max(stats.BestWave or 0, data.BestWave)

	profiles[player] = data

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local best = Instance.new("IntValue")
	best.Name = "Best Wave"
	best.Parent = leaderstats
	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Parent = leaderstats
	leaderstats.Parent = player

	self:Replicate(player)
	self.ProfileLoaded:Fire(player, data)
end

function DataService:Save(player)
	local data = profiles[player]
	if not data or not store or noSave[player] then
		return
	end
	for attempt = 1, 3 do
		local ok, err = pcall(store.SetAsync, store, keyFor(player), data, { player.UserId })
		if ok then
			return
		end
		warn("[DataService] Save failed for", player.Name, err)
		task.wait(attempt)
	end
end

function DataService:Get(player)
	return profiles[player]
end

-- Push profile fields to player attributes so the client UI can read them.
function DataService:Replicate(player)
	local data = profiles[player]
	if not data then
		return
	end
	player:SetAttribute("Gems", data.Gems)
	player:SetAttribute("BestWave", data.BestWave)
	player:SetAttribute("ClassId", data.EquippedClass)
	player:SetAttribute("LoadoutJson", HttpService:JSONEncode(data.Loadout))
	player:SetAttribute("OwnedJson", HttpService:JSONEncode({ Classes = data.OwnedClasses, Weapons = data.OwnedWeapons }))
	player:SetAttribute("AchievementsJson", HttpService:JSONEncode({ Stats = data.Stats, Claimed = data.Claimed }))
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats["Best Wave"].Value = data.BestWave
	end
end

function DataService:AddGems(player, amount)
	local data = profiles[player]
	if not data then
		return
	end
	data.Gems = math.max(0, data.Gems + math.floor(amount))
	self:Replicate(player)
end

-- Achievement progress: adds `amount` (default 1) to Stats[key], or keeps the max when isMax.
-- Toasts each achievement this completes; the client sees it on AchievementsJson.
function DataService:AddStat(player, key, amount, isMax)
	local data = profiles[player]
	if not data then
		return
	end
	local stats = data.Stats
	local before = {}
	for _, def in Achievements.List do
		before[def] = Achievements.Progress(def, stats)
	end
	stats[key] = if isMax then math.max(stats[key] or 0, amount) else (stats[key] or 0) + (amount or 1)
	for _, def in Achievements.List do
		if before[def] < def.Goal and Achievements.Progress(def, stats) >= def.Goal then
			Remotes.Notify:FireClient(player, "Achievement: " .. def.Name .. "! Claim ◆" .. def.Gems .. " at the board", "Good")
		end
	end
	player:SetAttribute("AchievementsJson", HttpService:JSONEncode({ Stats = stats, Claimed = data.Claimed }))
end

function DataService:ClaimAchievement(player, id)
	local data = profiles[player]
	local def = Achievements.ById[id]
	if not data or not def or data.Claimed[id] or Achievements.Progress(def, data.Stats) < def.Goal then
		return
	end
	data.Claimed[id] = true
	data.Gems += def.Gems
	self:Replicate(player)
	Remotes.Notify:FireClient(player, "+◆" .. def.Gems .. "  " .. def.Name, "Good")
	task.spawn(self.Save, self, player)
end

-- Called by MatchService at the end of a run. Returns true if this was a new best wave.
function DataService:RecordRun(player, waveReached, kills, gems)
	local data = profiles[player]
	if not data then
		return false
	end
	local newBest = waveReached > data.BestWave
	data.BestWave = math.max(data.BestWave, waveReached)
	data.TotalKills += kills
	data.RunsPlayed += 1
	data.Gems += gems
	self:Replicate(player)
	task.spawn(self.Save, self, player)
	return newBest
end

return DataService
