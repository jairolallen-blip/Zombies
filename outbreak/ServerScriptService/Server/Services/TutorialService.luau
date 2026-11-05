-- TutorialService: walks a first-time player through the game during their training run
-- (MatchService:RunMatch with Tutorial; steps and lines in Shared/Config/Tutorial).
-- Each step: Setup helper (if any), a radio line from Overwatch, and an objective the client shows
-- (Client/Controllers/TutorialController) until its Done check passes.
--
-- Writes player attributes TutorialObjective (text, "" = none), TutorialObjectiveDone (bool),
-- TutorialStep / TutorialSteps (numbers for the "2 / 8" counter).
--
-- Public:
--   TutorialService:Run(player)   returns when the tutorial run is over (GameState Tutorial = false)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Tutorial = require(Shared.Config.Tutorial)
local Remotes = require(Shared.Remotes)
local GameState = require(Shared.GameState)

local TutorialService = {}
local Services

local PHASE_RANK = { Break = 1, Wave = 2 }

-- how far the run is: wave * 10 + phase rank; Results is past everything
local function progress(wave, phase)
	return if phase == "Results" then math.huge else wave * 10 + (PHASE_RANK[phase] or 0)
end

local function now()
	return progress(GameState:GetAttribute("Wave") or 0, GameState:GetAttribute("Phase"))
end

-- Setup helpers: make sure the step can be done right away
local SETUP = {
	CashForUpgrade = function(player)
		local cost = GameConfig.Upgrades.Weapon.Costs[player:GetAttribute("WeaponTier") or 1]
		local short = (cost or 0) - (player:GetAttribute("Cash") or 0)
		if short > 0 then
			Services.EconomyService:AddCash(player, short)
		end
	end,
	CashForVitality = function(player)
		local v = GameConfig.Upgrades.Vitality
		local cost = math.floor(v.BaseCost * v.CostGrowth ^ (player:GetAttribute("VitalityLevel") or 0))
		local short = cost - (player:GetAttribute("Cash") or 0)
		if short > 0 then
			Services.EconomyService:AddCash(player, short)
		end
	end,
	DropCrate = function()
		task.delay(3, function()
			if GameState:GetAttribute("Phase") == "Wave" then
				Services.AirdropService:Drop(GameState:GetAttribute("Wave") or 1)
			end
		end)
	end,
	FillUltimate = function(player)
		Services.EconomyService:AddUltCharge(player, math.huge)
	end,
}

-- Done checks. base = what the check recorded when the step started.
local CHECKS = {
	WaveCleared = function(_, step)
		return (GameState:GetAttribute("Wave") or 0) > step.Start[1]
	end,
	Upgraded = function(player)
		return (player:GetAttribute("WeaponTier") or 1) >= 2
	end,
	Vitality = function(player)
		return (player:GetAttribute("VitalityLevel") or 0) >= 1
	end,
	Ability = function(player, _, base)
		return player:GetAttribute("AbilityReadyAt") ~= base.AbilityReadyAt
	end,
	Airdrop = function(player, _, base)
		local profile = Services.DataService:Get(player)
		return profile ~= nil and (profile.Stats.Airdrops or 0) > base.Airdrops
	end,
	Ultimate = function(player)
		return (player:GetAttribute("UltCharge") or 0) < GameConfig.Ultimate.Max
	end,
	RunOver = function()
		return GameState:GetAttribute("Phase") == "Results"
	end,
}

function TutorialService:Init(services)
	Services = services
end

function TutorialService:Run(player)
	local steps = Tutorial.Steps
	local index, base = 0, nil
	player:SetAttribute("TutorialSteps", #steps)
	local function startOf(step)
		return progress(step.Start[1], step.Start[2])
	end
	while player.Parent and GameState:GetAttribute("Tutorial") do
		local current = steps[index]
		local done = current ~= nil and current.Done ~= nil and CHECKS[current.Done](player, current, base)
		if done then
			player:SetAttribute("TutorialObjectiveDone", true)
		end
		-- the next step once this one's done; or, if the run has moved on to a later wave or phase,
		-- the first step of the latest start reached (dropping this one and any waiting behind it)
		local target
		if (not current or done) and steps[index + 1] and now() >= startOf(steps[index + 1]) then
			target = index + 1
		elseif current then
			for j = index + 1, #steps do
				local at = startOf(steps[j])
				if now() >= at and at > startOf(current) and (not target or at > startOf(steps[target])) then
					target = j
				end
			end
		end
		if target then
			index = target
			local upcoming = steps[index]
			if upcoming.Setup then
				SETUP[upcoming.Setup](player)
			end
			local profile = Services.DataService:Get(player)
			base = { AbilityReadyAt = player:GetAttribute("AbilityReadyAt"), Airdrops = profile and profile.Stats.Airdrops or 0 }
			local shown = index
			task.delay(upcoming.Delay or 0, function()
				if index == shown and player.Parent and GameState:GetAttribute("Tutorial") then
					player:SetAttribute("TutorialStep", shown)
					Services.DataService:Funnel(player, 1 + shown, "Tutorial step " .. shown)
					player:SetAttribute("TutorialObjective", upcoming.Objective)
					player:SetAttribute("TutorialObjectiveDone", false)
					Remotes.Radio:FireClient(player, upcoming.Say, "Tutorial")
				end
			end)
		end
		task.wait(0.2)
	end
	player:SetAttribute("TutorialObjective", "")
end

return TutorialService
