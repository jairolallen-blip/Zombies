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
-- Best waves also go to an OrderedDataStore (BEST_STORE) for the Commons' TOP SURVIVORS board:
-- :GetTopBestWaves(n) -> {{UserId, Wave}} best first, or nil when DataStores are unavailable.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Classes = require(Shared.Config.Classes)
local Weapons = require(Shared.Config.Weapons)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)
local Achievements = require(Shared.Config.Achievements)
local Bounties = require(Shared.Config.Bounties)
local Zombies = require(Shared.Config.Zombies)
local Levels = require(Shared.Config.Levels)

-- Session lock: a run moves players between servers (QueueService), so two servers can hold the same
-- profile for a moment. Each saved profile carries _Lock = {JobId, Time}: a server only loads a profile
-- no other live server holds, and never saves over one another server took. Autosaves refresh it.
local LOCK_TTL = 120 -- a claim older than this (its server crashed) can be taken over
local LOCK_WAIT = 30 -- longest a joining server waits for the old one to let go, then takes over
local AUTOSAVE = 45 -- seconds between autosaves (also refreshes the lock)

-- UpdateAsync transforms, pure so they can be checked from the command bar (DataService.Lock)
local Lock = {}
function Lock.claim(old, jobId, now, waited)
	local lock = old and old._Lock
	if lock and lock.JobId ~= jobId and now - lock.Time < LOCK_TTL and waited < LOCK_WAIT then
		return nil, true -- held by another server: leave it as it is and try again soon
	end
	local value = old or {}
	value._Lock = { JobId = jobId, Time = now }
	return value, false
end
function Lock.stamp(old, data, jobId, now, release)
	local lock = old and old._Lock
	if lock and lock.JobId ~= jobId then
		return nil, true -- another server took this profile over: never write over its newer data
	end
	local value = table.clone(data)
	value._Lock = if release then nil else { JobId = jobId, Time = now }
	return value, false
end

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
	TutorialDone = false, -- first-time players get a solo training run before the lobby (QueueService)
	DailyStreak = 0, -- days in a row the daily rations were claimed (DailyService)
	DailyDay = 0, -- UTC day number of the last claim
	Receipts = {}, -- PurchaseIds of Robux products already paid (StoreService)
	StarterPack = false, -- bought the one-time Starter Pack
	Bounty = { Day = 0, Progress = {}, Done = {} }, -- today's bounties (Config/Bounties); Tracked = id or nil
	-- XP (total run XP, Config/Levels) is not defaulted here: load credits saves without it from their Stats
}

local DataService = {}
DataService.ProfileLoaded = Util.Signal.new() -- (player, profile)

local profiles = {} -- [Player] = profile table
local noSave = {} -- [Player] = true when the load failed (never overwrite their real data)
local store = nil
local BEST_STORE = "SAMZ_BestWave_v1"
local bestStore = nil -- OrderedDataStore: key "u_<UserId>" -> best wave

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
		local okBest, ordered = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, BEST_STORE)
		bestStore = if okBest then ordered else nil
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
	Remotes.ClaimIndex.OnServerEvent:Connect(function(player, typeId)
		self:ClaimIndex(player, typeId)
	end)
	Remotes.TrackBounty.OnServerEvent:Connect(function(player, id)
		self:TrackBounty(player, id)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:Save(player, true)
		profiles[player] = nil
		noSave[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE)
			for player in profiles do
				task.spawn(self.Save, self, player)
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				self:Save(player, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do -- Roblox allows 30s
			task.wait(0.2)
		end
	end)
end

function DataService:Load(player)
	local data = nil
	local loaded = store == nil
	if store then
		local failures, waited = 0, 0
		while player.Parent do
			local locked = false
			local ok, result = pcall(store.UpdateAsync, store, keyFor(player), function(old)
				local value
				value, locked = Lock.claim(old, game.JobId, os.time(), waited)
				return value, if value then { player.UserId } else nil
			end)
			if ok and not locked then
				data = result
				data._Lock = nil
				if next(data) == nil then
					data = nil -- a brand-new profile (only the lock was written)
				end
				loaded = true
				break
			end
			if ok then
				task.wait(2) -- another server is still saving this player (a teleport): wait for it
				waited += 2
			elseif isAccessError(result) then
				warn("[DataService] No DataStore access (enable 'Studio Access to API Services' to persist). Memory-only.")
				store = nil
				loaded = true
				break
			else
				failures += 1
				if failures >= 3 then
					break
				end
				task.wait(failures)
			end
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
	if isNew then
		self:Funnel(player, 1, "Joined")
	end
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
	data.XP = data.XP or Levels.Credit(stats) -- saves from before levels start where their history puts them
	if data.RunsPlayed > 0 then
		data.TutorialDone = true -- saves from before the tutorial existed
	end

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

	if data.BestWave > 0 then
		self:_submitBest(player, data.BestWave) -- also back-fills saves from before the board
	end
	self:Replicate(player)
	self.ProfileLoaded:Fire(player, data)
end

-- release = true lets go of the session lock (leaving, teleporting, shutting down).
-- Returns true once the profile is safely stored (always true in memory-only mode); StoreService relies on it.
function DataService:Save(player, release)
	local data = profiles[player]
	if not data or noSave[player] then
		return false
	end
	if not store then
		return true
	end
	for attempt = 1, 3 do
		local lost = false
		local ok, err = pcall(store.UpdateAsync, store, keyFor(player), function(old)
			local value
			value, lost = Lock.stamp(old, data, game.JobId, os.time(), release)
			return value, if value then { player.UserId } else nil
		end)
		if ok then
			if lost then
				warn("[DataService] Another server holds", player.Name, "'s profile; not saving over it.")
			end
			return not lost
		end
		warn("[DataService] Save failed for", player.Name, err)
		task.wait(attempt)
	end
	return false
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
	player:SetAttribute("XP", data.XP)
	player:SetAttribute("ClassId", data.EquippedClass)
	player:SetAttribute("LoadoutJson", HttpService:JSONEncode(data.Loadout))
	player:SetAttribute("OwnedJson", HttpService:JSONEncode({ Classes = data.OwnedClasses, Weapons = data.OwnedWeapons }))
	player:SetAttribute("AchievementsJson", HttpService:JSONEncode({ Stats = data.Stats, Claimed = data.Claimed }))
	player:SetAttribute("BountyJson", HttpService:JSONEncode(self:_bounty(data)))
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats["Best Wave"].Value = data.BestWave
	end
end

-- Run XP (Config/Levels). Returns the total before it was added (the run report animates from there).
function DataService:AddXP(player, amount)
	local data = profiles[player]
	if not data then
		return 0
	end
	local before = data.XP
	data.XP += math.max(0, math.floor(amount))
	player:SetAttribute("XP", data.XP)
	return before
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
	self:_bountyProgress(player, data, key, amount or 1, isMax)
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

-- Enemy index (lobby FIELD RESEARCH station): a zombie type is discovered once you've killed one
-- (Stats Kills_<type>); claiming it pays its Index.Gems once. Claims share the Claimed table as "Index_<type>".
function DataService:ClaimIndex(player, typeId)
	local data = profiles[player]
	local def = type(typeId) == "string" and Zombies.Types[typeId]
	local key = "Index_" .. tostring(typeId)
	if not data or not def or not def.Index or data.Claimed[key] or (data.Stats["Kills_" .. typeId] or 0) < 1 then
		return
	end
	data.Claimed[key] = true
	data.Gems += def.Index.Gems
	self:Replicate(player)
	Remotes.Notify:FireClient(player, "+◆" .. def.Index.Gems .. "  Discovered: " .. def.DisplayName, "Good")
	task.spawn(self.Save, self, player)
end

-- Bounties (Config/Bounties): the profile's Bounty table, reset when a new UTC day starts
function DataService:_bounty(data)
	local today = Bounties.Today(os.time())
	if data.Bounty.Day ~= today then
		data.Bounty = { Day = today, Progress = {}, Done = {} }
	end
	return data.Bounty
end

function DataService:TrackBounty(player, id)
	local data = profiles[player]
	if not data or type(id) ~= "string" then
		return
	end
	local bounty = self:_bounty(data)
	for _, def in Bounties.ForDay(bounty.Day) do
		if def.Id == id and not bounty.Done[id] then
			bounty.Tracked = id
			self:Replicate(player)
			return
		end
	end
end

-- only the tracked bounty counts; finishing it pays at once and frees the slot
function DataService:_bountyProgress(player, data, key, amount, isMax)
	local bounty = self:_bounty(data)
	local def = bounty.Tracked and Bounties.ById[bounty.Tracked]
	if not def or def.Stat ~= key then
		return
	end
	local before = bounty.Progress[def.Id] or 0
	bounty.Progress[def.Id] = math.min(def.Goal, if def.Max then math.max(before, amount) else before + amount)
	if bounty.Progress[def.Id] >= def.Goal then
		bounty.Done[def.Id] = true
		bounty.Tracked = nil
		data.Gems += def.Gems
		Remotes.Notify:FireClient(player, "BOUNTY DONE: " .. def.Name .. "  +◆" .. def.Gems, "Good")
		self:Replicate(player)
		task.spawn(self.Save, self, player)
	else
		player:SetAttribute("BountyJson", HttpService:JSONEncode(bounty))
	end
end

-- Called by MatchService at the end of a run. Returns true if this was a new best wave.
function DataService:RecordRun(player, waveReached, kills, gems)
	local data = profiles[player]
	if not data then
		return false
	end
	local newBest = waveReached > data.BestWave
	if newBest then
		self:_submitBest(player, waveReached)
	end
	data.BestWave = math.max(data.BestWave, waveReached)
	data.TotalKills += kills
	data.RunsPlayed += 1
	data.Gems += gems
	self:Replicate(player)
	task.spawn(self.Save, self, player)
	return newBest
end

function DataService:_submitBest(player, wave)
	if bestStore and store and not noSave[player] then
		task.spawn(pcall, bestStore.SetAsync, bestStore, keyFor(player), wave)
	end
end

function DataService:GetTopBestWaves(count)
	if not bestStore or not store then
		return nil
	end
	local ok, pages = pcall(bestStore.GetSortedAsync, bestStore, false, count)
	if not ok then
		return nil
	end
	local top = {}
	for _, entry in pages:GetCurrentPage() do
		table.insert(top, { UserId = tonumber(entry.key:sub(3)), Wave = entry.value })
	end
	return top
end

-- Onboarding funnel (Creator Dashboard > Analytics > Funnels): where new players stop. Roblox counts each
-- step once per player, so callers can log it every time. Steps:
--   1 Joined   2-9 tutorial steps 1-8   10 Finished the tutorial   11 Reached the lobby   12 Finished a squad run
function DataService:Funnel(player, step, name)
	pcall(AnalyticsService.LogOnboardingFunnelStepEvent, AnalyticsService, player, step, name)
end

-- how far runs get (Analytics > Custom events "WaveReached", value = the wave)
function DataService:LogWave(player, wave)
	pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, "WaveReached", wave)
end

DataService.Lock = Lock

return DataService
