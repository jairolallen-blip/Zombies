-- LobbyService: lobby-only actions — equip class, put a gun in its Loadout slot (one per Level),
-- unlock with Gems. (Taking off = standing on a Flight Line pad; QueueService.)
-- All requests are rejected while the player is in a run.

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
-- "BEST WAVE n" over every player's head while they're in the lobby, so strong players stand out
local function bestWaveTag(player, character)
	local head = character:WaitForChild("Head", 10)
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "BestWaveTag"
	gui.Size = UDim2.fromScale(4, 0.7) -- studs
	gui.StudsOffset = Vector3.new(0, 3.2, 0) -- above Roblox's own name
	gui.MaxDistance = 60
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 200, 70)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	local function refresh()
		local best = player:GetAttribute("BestWave") or 0
		label.Text = (if player:GetAttribute("Pass_VIP") then "VIP  ·  " else "") .. (if best > 0 then "BEST WAVE " .. best else "NEW SURVIVOR")
		gui.Enabled = not player:GetAttribute("InRun")
	end
	refresh()
	gui.Parent = head
	local a = player:GetAttributeChangedSignal("InRun"):Connect(refresh)
	local b = player:GetAttributeChangedSignal("BestWave"):Connect(refresh)
	local c = player:GetAttributeChangedSignal("Pass_VIP"):Connect(refresh)
	gui.Destroying:Connect(function()
		a:Disconnect()
		b:Disconnect()
		c:Disconnect()
	end)
end

function LobbyService:Init(services)
	Services = services
	local Players = game:GetService("Players")
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			bestWaveTag(player, character)
		end)
	end)
	Remotes.SelectClass.OnServerEvent:Connect(function(player, id)
		self:Equip(player, "Class", id)
	end)
	Remotes.SelectWeapon.OnServerEvent:Connect(function(player, id)
		self:Equip(player, "Weapon", id)
	end)
	Remotes.UnlockItem.OnServerEvent:Connect(function(player, kind, id)
		self:Unlock(player, kind, id)
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
