-- DebugService: STUDIO-ONLY test commands, exposed as ServerStorage.SAMZ_Debug (BindableFunction).
-- Lets a developer or an AI agent drive the game from the Command Bar / MCP execute_luau (Server):
--   game.ServerStorage.SAMZ_Debug:Invoke("Help")
--   game.ServerStorage.SAMZ_Debug:Invoke("Spawn", "GraveTitan", 1)
-- Not created in live servers. Add a command by adding a function to Commands.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zombies = require(ReplicatedStorage:WaitForChild("Shared").Config.Zombies)

local DebugService = {}
local Services

local function firstPlayer(name)
	if name then
		return Players:FindFirstChild(name)
	end
	return Players:GetPlayers()[1]
end

local Commands = {}

Commands.Help = function()
	local names = {}
	for name in Commands do
		table.insert(names, name)
	end
	table.sort(names)
	return "Commands: " .. table.concat(names, ", ")
end

-- Spawn(typeId, count?, healthMult?) — spawns at random spawn pads
Commands.Spawn = function(typeId, count, healthMult)
	assert(Zombies.Types[typeId], "unknown zombie type " .. tostring(typeId))
	for _ = 1, count or 1 do
		Services.ZombieService:Spawn(typeId, Services.MapService:GetZombieSpawnPosition(), healthMult)
	end
	return "spawned " .. (count or 1) .. " " .. typeId
end

Commands.KillAll = function()
	local n = 0
	for _, entry in Services.ZombieService:GetInRadius(Vector3.zero, math.huge) do
		Services.ZombieService:Kill(entry.Model, nil)
		n += 1
	end
	return "killed " .. n
end

-- SkipToWave(n) — next wave started will be n (use KillAll to end the current one)
Commands.SkipToWave = function(n)
	Services.MatchService.DebugNextWave = n
	return "next wave will be " .. n
end

Commands.GiveCash = function(amount, playerName)
	local player = firstPlayer(playerName)
	Services.EconomyService:AddCash(player, amount or 10000)
	return player.Name .. " cash = " .. player:GetAttribute("Cash")
end

Commands.GiveGems = function(amount, playerName)
	local player = firstPlayer(playerName)
	Services.DataService:AddGems(player, amount or 5000)
	return player.Name .. " gems = " .. player:GetAttribute("Gems")
end

Commands.ChargeUlt = function(playerName)
	local player = firstPlayer(playerName)
	Services.EconomyService:AddUltCharge(player, math.huge)
	return "ult charged"
end

-- God(on?) — huge max health for the first player (current character only)
Commands.God = function(on, playerName)
	local player = firstPlayer(playerName)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = if on == false then 100 else 1e6
		humanoid.Health = humanoid.MaxHealth
	end
	return "god " .. tostring(on ~= false)
end

-- NavCheck() — verifies every ZombieSpawn has a flow-field route to the arena centre
Commands.NavCheck = function()
	local NavGrid = require(script.Parent.Parent:WaitForChild("Map"):WaitForChild("NavGrid"))
	local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
	local centre = GameConfig.Map.ArenaCenter + Vector3.new(14, Services.MapService.GroundY, 14)
	local lines = { NavGrid.Stats() }
	for _, d in workspace.Map:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "ZombieSpawn" then
			-- walk the field from the pad to the centre (max 200 steps of ~3 studs)
			local pos = Vector3.new(d.Position.X, Services.MapService.GroundY, d.Position.Z)
			local steps, ok = 0, false
			while steps < 200 do
				if (pos - centre).Magnitude < 6 then
					ok = true
					break
				end
				local dir = NavGrid.GetDirection(pos, centre)
				if not dir then
					break
				end
				pos += dir * 3
				steps += 1
			end
			table.insert(lines, string.format("pad (%d,%d): %s in %d steps", d.Position.X, d.Position.Z, if ok then "ROUTE OK" else "NO ROUTE", steps))
		end
	end
	return table.concat(lines, "\n")
end

-- State() — one-line summary of GameState + first player's run stats
Commands.State = function()
	local gs = ReplicatedStorage.GameState
	local player = firstPlayer()
	local hum = player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return string.format(
		"phase=%s wave=%d left=%d alive=%d boss=%s | %s inRun=%s hp=%s cash=%s kills=%s tier=%s class=%s",
		gs:GetAttribute("Phase"),
		gs:GetAttribute("Wave"),
		gs:GetAttribute("ZombiesLeft"),
		Services.ZombieService:GetAliveCount(),
		gs:GetAttribute("BossName"),
		player and player.Name or "-",
		tostring(player and player:GetAttribute("InRun")),
		tostring(hum and math.floor(hum.Health)),
		tostring(player and player:GetAttribute("Cash")),
		tostring(player and player:GetAttribute("Kills")),
		tostring(player and player:GetAttribute("WeaponTier")),
		tostring(player and player:GetAttribute("ClassId"))
	)
end

function DebugService:Init(services)
	Services = services
	if not RunService:IsStudio() then
		return
	end
	local fn = ServerStorage:FindFirstChild("SAMZ_Debug") or Instance.new("BindableFunction")
	fn.Name = "SAMZ_Debug"
	fn.OnInvoke = function(command, ...)
		local handler = Commands[command]
		if not handler then
			return "unknown command '" .. tostring(command) .. "'. " .. Commands.Help()
		end
		local ok, result = pcall(handler, ...)
		return if ok then result else "error: " .. tostring(result)
	end
	fn.Parent = ServerStorage
end

return DebugService
