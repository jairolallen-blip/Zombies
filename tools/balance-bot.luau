-- Balance-test bot (vault: Waves and Boss.md -> Balance pass). Plays a solo run like an average
-- player, no cheats: body shots only with aim error that grows with distance, normal weapon spread,
-- backs away from zombies within 14 studs while staying inside the city square, grenade into
-- clusters of 3+, ultimate when charged and 6+ are close, buys the next gun level as soon as it
-- can and Vitality only with cash left over beyond the next gun's price.
--
-- How to run (MCP):
--   1. start_stop_play(true)
--   2. execute_luau(Client): paste this file           -> "bot started"
--   3. get on a pad and fill the squad: execute_luau(Client) require(game.ReplicatedStorage.Shared.Remotes).QuickPlay:FireServer(),
--      then click LocalPlayer.PlayerGui.Lobby.Frame.Squad.Size1 with user_mouse_input
--   4. poll every ~55s (keep each execute_luau under ~60s or the MCP call times out and Studio may
--      drop the connection):
--        execute_luau(Client): task.wait(55) return game.Players.LocalPlayer:GetAttribute("BotLog")
--   A full 10-wave run takes ~6-7 minutes. The bot stops itself at Results; set the LocalPlayer
--   attribute BotOn = false to stop it early. Stop play afterwards (a new run auto-starts otherwise).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Util = require(Shared.Util)
local GameConfig = require(Shared.Config.GameConfig)
local R = RS:WaitForChild("Remotes")
local gs = RS:WaitForChild("GameState")
local p = Players.LocalPlayer
local CENTER = GameConfig.OurMap.ArenaCenter
p:SetAttribute("BotOn", true)
p:SetAttribute("BotLog", "")
local function log(line)
	p:SetAttribute("BotLog", p:GetAttribute("BotLog") .. line .. "\n")
end
local function spread(dir, deg)
	if deg <= 0 then
		return dir
	end
	local a = math.rad(deg) * math.sqrt(math.random())
	return (CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles(0, 0, math.random() * math.pi * 2) * CFrame.Angles(a, 0, 0)).LookVector
end

task.spawn(function()
	local nextShot, spin = 0, 0
	local lastPhase, waveStart, hpMin, waveNum, maxAlive = nil, os.clock(), math.huge, 0, 0
	local runStart = os.clock()
	while p:GetAttribute("BotOn") do
		local dt = task.wait()
		local now = os.clock()
		local phase = gs:GetAttribute("Phase")
		if phase ~= lastPhase then
			if lastPhase == "Wave" then
				log(string.format(
					"wave %d: %.0fs | lowest HP %d | most alive %d | cash %d | gun Lv%d %s | vit %d | kills %d",
					waveNum, now - waveStart, hpMin, maxAlive, p:GetAttribute("Cash") or 0, p:GetAttribute("WeaponTier") or 0,
					tostring(p:GetAttribute("WeaponId")), p:GetAttribute("VitalityLevel") or 0, p:GetAttribute("Kills") or 0
				))
			end
			if phase == "Wave" then
				waveStart, hpMin, waveNum, maxAlive = now, math.huge, gs:GetAttribute("Wave"), 0
			end
			if phase == "Results" then
				log(string.format("RESULT: %s at wave %d after %.0fs | boss HP left %s", if gs:GetAttribute("RunWon") then "VICTORY" else "OVERRUN", gs:GetAttribute("Wave"), now - runStart, tostring(gs:GetAttribute("BossHealth"))))
				p:SetAttribute("BotOn", false)
			end
			lastPhase = phase
		end
		if phase == "Wave" then
			maxAlive = math.max(maxAlive, #workspace.Zombies:GetChildren())
		end
		local char = p.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not (p:GetAttribute("InRun") and not p:GetAttribute("Deploying") and hum and root and hum.Health > 0) then
			continue
		end
		if phase == "Wave" then
			hpMin = math.min(hpMin, hum.Health)
		end
		-- shopping: next gun level first; Vitality only with cash beyond the next gun's price
		local cash = p:GetAttribute("Cash") or 0
		local tier = p:GetAttribute("WeaponTier") or 1
		local wCost = Util.GetUpgradeCost("Weapon", tier)
		local vCost = Util.GetUpgradeCost("Vitality", p:GetAttribute("VitalityLevel") or 0)
		if wCost and cash >= wCost then
			R.BuyUpgrade:FireServer("Weapon")
			task.wait(0.2)
		elseif vCost and cash >= vCost and (not wCost or cash - vCost >= wCost) then
			R.BuyUpgrade:FireServer("Vitality")
			task.wait(0.2)
		end
		-- threats
		local nearest, nd = nil, math.huge
		local sum, close = Vector3.zero, 0
		for _, z in workspace.Zombies:GetChildren() do
			local zr = z.PrimaryPart
			if zr and not zr.Anchored then
				local d = (zr.Position - root.Position).Magnitude
				if d < nd then
					nearest, nd = z, d
				end
				if d < 14 then
					sum += zr.Position
					close += 1
				end
			end
		end
		-- movement: back away from what's close, stay within 38 studs of the square's centre
		local move = Vector3.zero
		if close > 0 then
			local away = (root.Position - sum / close) * Vector3.new(1, 0, 1)
			if away.Magnitude > 0.1 then
				move = away.Unit
			end
		end
		local fromCenter = (root.Position - CENTER) * Vector3.new(1, 0, 1)
		if fromCenter.Magnitude > 38 then
			move = (move - fromCenter.Unit * 1.5).Unit
		end
		hum:Move(move)
		-- shooting (through the real FireWeapon remote, so the server validates everything)
		local weaponId = p:GetAttribute("WeaponId")
		local stats = weaponId and Util.GetWeaponStats(weaponId, tier)
		local tool = char:FindFirstChildOfClass("Tool")
		local muzzle = tool and tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild("Muzzle")
		if stats and stats.SpinUp then
			spin = math.clamp(spin + (if nearest then dt / stats.SpinUp else -dt), 0, 1)
		end
		if stats and muzzle and nearest and nd <= stats.Range then
			if (p:GetAttribute("Ammo") or 0) <= 0 and not p:GetAttribute("Reloading") then
				R.Reload:FireServer()
			elseif not p:GetAttribute("Reloading") and now >= nextShot then
				local torso = nearest:FindFirstChild("Torso") or nearest.PrimaryPart
				local aim = torso.Position + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * (0.6 + nd * 0.04)
				local origin = muzzle.WorldPosition
				local dir = (aim - origin).Unit
				local dirs = {}
				for i = 1, stats.Pellets do
					dirs[i] = spread(dir, stats.Spread)
				end
				R.FireWeapon:FireServer(origin, dirs)
				local rate = if stats.SpinUp then stats.FireRate * (0.3 + 0.7 * spin) else stats.FireRate
				nextShot = now + 1 / rate + 0.01
			end
		end
		-- abilities
		local serverNow = workspace:GetServerTimeNow()
		if close >= 3 and serverNow >= (p:GetAttribute("AbilityReadyAt") or 0) then
			R.UseAbility:FireServer("Ability", sum / close)
		end
		if close >= 6 and (p:GetAttribute("UltCharge") or 0) >= GameConfig.Ultimate.Max then
			R.UseAbility:FireServer("Ultimate", sum / close)
		end
	end
	local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if h then
		h:Move(Vector3.zero)
	end
end)
return "bot started"
