-- LobbyService: lobby-only actions — equip class, put a gun in its Loadout slot (one per Level),
-- unlock with Gems, Ready toggle.
-- All requests are rejected while the player is in a run.
-- Player attribute: Ready (boolean) — read by MatchService for the countdown.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Classes = require(Shared.Config.Classes)
local Weapons = require(Shared.Config.Weapons)
local Remotes = require(Shared.Remotes)

local LobbyService = {}
local Services

-- kind -> where it lives in config and in the profile
local KINDS = {
	Class = { List = Classes.List, Owned = "OwnedClasses", Equipped = "EquippedClass" },
	Weapon = { List = Weapons.List, Owned = "OwnedWeapons" }, -- equipped = profile.Loadout[def.Level]
}

local function setEquipped(profile, kind, id)
	if kind == "Weapon" then
		profile.Loadout[Weapons.List[id].Level] = id
	else
		profile[KINDS[kind].Equipped] = id
	end
end

local function notify(player, text, kind)
	Remotes.Notify:FireClient(player, text, kind or "Info")
end

function LobbyService:Init(services)
	Services = services
	Remotes.SelectClass.OnServerEvent:Connect(function(player, id)
		self:Equip(player, "Class", id)
	end)
	Remotes.SelectWeapon.OnServerEvent:Connect(function(player, id)
		self:Equip(player, "Weapon", id)
	end)
	Remotes.UnlockItem.OnServerEvent:Connect(function(player, kind, id)
		self:Unlock(player, kind, id)
	end)
	Remotes.SetReady.OnServerEvent:Connect(function(player, ready)
		if not Services.MatchService:IsInRun(player) then
			player:SetAttribute("Ready", ready == true)
		end
	end)
end

local function validate(player, kind, id)
	local info = KINDS[kind]
	if not info or type(id) ~= "string" or not info.List[id] then
		return nil
	end
	if Services.MatchService:IsInRun(player) then
		return nil
	end
	local profile = Services.DataService:Get(player)
	if not profile then
		return nil
	end
	return info, profile
end

function LobbyService:Equip(player, kind, id)
	local info, profile = validate(player, kind, id)
	if not info then
		return
	end
	if not profile[info.Owned][id] then
		return notify(player, "Unlock it first", "Danger")
	end
	setEquipped(profile, kind, id)
	Services.DataService:Replicate(player)
end

function LobbyService:Unlock(player, kind, id)
	local info, profile = validate(player, kind, id)
	if not info then
		return
	end
	local def = info.List[id]
	if profile[info.Owned][id] then
		return self:Equip(player, kind, id)
	end
	if profile.Gems < def.GemCost then
		return notify(player, "Not enough Gems", "Danger")
	end
	profile.Gems -= def.GemCost
	profile[info.Owned][id] = true
	setEquipped(profile, kind, id)
	Services.DataService:Replicate(player)
	task.spawn(Services.DataService.Save, Services.DataService, player)
	notify(player, "Unlocked " .. def.DisplayName .. "!", "Good")
end

return LobbyService
