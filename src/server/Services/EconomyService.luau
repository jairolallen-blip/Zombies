-- EconomyService: per-run Cash, kills, Ultimate charge and the in-run upgrades (Weapon tier, Vitality).
-- All run stats live on player attributes (server-authoritative, readable by the client HUD):
--   Cash, Kills, WeaponTier (1..), VitalityLevel (0..), UltCharge (0..GameConfig.Ultimate.Max),
--   AbilityReadyAt (workspace:GetServerTimeNow() timestamp; written by AbilityService)
-- Upgrade prices/effects: GameConfig.Upgrades + Util.GetUpgradeCost.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Classes = require(Shared.Config.Classes)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local EconomyService = {}
local Services

function EconomyService:Init(services)
	Services = services
	Remotes.BuyUpgrade.OnServerEvent:Connect(function(player, upgradeId)
		if type(upgradeId) == "string" then
			self:TryUpgrade(player, upgradeId)
		end
	end)
end

function EconomyService:ResetRun(player)
	player:SetAttribute("Cash", GameConfig.Economy.StartingCash)
	player:SetAttribute("Kills", 0)
	player:SetAttribute("WeaponTier", 1)
	player:SetAttribute("VitalityLevel", 0)
	player:SetAttribute("UltCharge", 0)
	player:SetAttribute("AbilityReadyAt", 0)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Kills.Value = 0
	end
end

function EconomyService:AddCash(player, amount)
	player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + math.floor(amount))
end

function EconomyService:AddUltCharge(player, amount)
	local max = GameConfig.Ultimate.Max
	player:SetAttribute("UltCharge", math.min(max, (player:GetAttribute("UltCharge") or 0) + amount))
end

-- Called by ZombieService when a player (or their turret/explosion) kills a zombie.
function EconomyService:OnZombieKilled(player, zombie)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or not player.Parent then
		return
	end
	local def = zombie.Def
	self:AddCash(player, def.Cash)
	local kills = (player:GetAttribute("Kills") or 0) + 1
	player:SetAttribute("Kills", kills)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Kills.Value = kills
	end
	self:AddUltCharge(player, if def.Boss then GameConfig.Ultimate.BossKillCharge else GameConfig.Ultimate.ChargePerKill)

	local share = def.Cash * GameConfig.Economy.TeamShare
	if share >= 1 then
		for _, other in Services.MatchService:GetRunPlayers() do
			if other ~= player and Services.MatchService:IsAliveInRun(other) then
				self:AddCash(other, share)
			end
		end
	end
end

function EconomyService:GetMaxHealth(player)
	local class = Classes.List[player:GetAttribute("ClassId")] or Classes.List[Classes.Default]
	local vitality = player:GetAttribute("VitalityLevel") or 0
	return GameConfig.Player.BaseHealth + class.HealthBonus + vitality * GameConfig.Upgrades.Vitality.HealthPerLevel
end

-- Apply class + upgrade stats to the current character (called on every arena spawn).
function EconomyService:ApplyCharacterStats(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local class = Classes.List[player:GetAttribute("ClassId")] or Classes.List[Classes.Default]
	local maxHealth = self:GetMaxHealth(player)
	humanoid.MaxHealth = maxHealth
	humanoid.Health = maxHealth
	humanoid.WalkSpeed = GameConfig.Player.BaseWalkSpeed + class.SpeedBonus
end

local function notify(player, text, kind)
	Remotes.Notify:FireClient(player, text, kind or "Info")
end

function EconomyService:TryUpgrade(player, upgradeId)
	local cfg = GameConfig.Upgrades[upgradeId]
	if not cfg then
		return
	end
	if not Services.MatchService:IsAliveInRun(player) then
		return
	end
	local levelAttr = if upgradeId == "Weapon" then "WeaponTier" else "VitalityLevel"
	local level = player:GetAttribute(levelAttr) or 0
	local cost = Util.GetUpgradeCost(upgradeId, level)
	if not cost then
		return notify(player, cfg.DisplayName .. " is maxed out", "Info")
	end
	local cash = player:GetAttribute("Cash") or 0
	if cash < cost then
		return notify(player, "Need $" .. Util.FormatNumber(cost - cash) .. " more", "Danger")
	end
	player:SetAttribute("Cash", cash - cost)
	player:SetAttribute(levelAttr, level + 1)

	if upgradeId == "Weapon" then
		Services.CombatService:RefreshWeapon(player)
		notify(player, "Weapon upgraded to Tier " .. (level + 1), "Good")
	elseif upgradeId == "Vitality" then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.MaxHealth = self:GetMaxHealth(player)
			humanoid.Health = humanoid.MaxHealth
		end
		notify(player, "Vitality " .. (level + 1) .. ": max HP up, fully healed", "Good")
	end
end

return EconomyService
