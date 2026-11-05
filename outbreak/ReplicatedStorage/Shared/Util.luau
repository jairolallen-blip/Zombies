-- Util: shared helpers with no game state (Signal, weapon/upgrade math, formatting).
-- Formulas here are used by BOTH server (authoritative) and client (UI), so they always agree.

local Config = script.Parent:WaitForChild("Config")
local GameConfig = require(Config.GameConfig)
local Weapons = require(Config.Weapons)

local Util = {}

-- Minimal signal. Handlers run in their own threads.
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn)
	table.insert(self._handlers, fn)
	local handlers = self._handlers
	return {
		Disconnect = function()
			local index = table.find(handlers, fn)
			if index then
				table.remove(handlers, index)
			end
		end,
	}
end

function Signal:Fire(...)
	for _, fn in table.clone(self._handlers) do
		task.spawn(fn, ...)
	end
end

Util.Signal = Signal

-- Final stats for a weapon at a run tier (base stats * GameConfig.WeaponTiers[tier]).
function Util.GetWeaponStats(weaponId, tier)
	local base = Weapons.List[weaponId] or Weapons.List[Weapons.Default]
	local t = math.clamp(tier or 1, 1, #GameConfig.WeaponTiers)
	local mult = GameConfig.WeaponTiers[t]
	local stats = table.clone(base)
	stats.Id = Weapons.List[weaponId] and weaponId or Weapons.Default
	stats.Tier = t
	stats.Damage = base.Damage * mult.Damage
	stats.FireRate = base.FireRate * mult.FireRate
	stats.MagSize = math.max(1, math.floor(base.MagSize * mult.MagSize + 0.5))
	stats.ReloadTime = base.ReloadTime * mult.ReloadTime
	stats.TierColor = mult.Color
	return stats
end

-- Cost of the next level of an in-run upgrade, or nil when maxed.
-- level = current WeaponTier (starts 1) or VitalityLevel (starts 0).
function Util.GetUpgradeCost(upgradeId, level)
	local cfg = GameConfig.Upgrades[upgradeId]
	if not cfg then
		return nil
	end
	if upgradeId == "Weapon" then
		return cfg.Costs[level]
	end
	if level >= cfg.MaxLevel then
		return nil
	end
	return math.floor(cfg.BaseCost * cfg.CostGrowth ^ level)
end

function Util.FlatDistance(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- 12345 -> "12,345"
function Util.FormatNumber(n)
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""):gsub("^%-,", "-"))
end

return Util
