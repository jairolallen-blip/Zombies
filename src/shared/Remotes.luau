-- Remotes: every RemoteEvent in the game, by name. Server creates them; clients wait for them.
-- Usage:  local Remotes = require(Shared.Remotes);  Remotes.FireWeapon:FireServer(...)
-- To add a remote: add its name to NAMES and document the payload below.
--
-- Client -> Server
--   FireWeapon(origin: Vector3, directions: {Vector3})   one shot (one direction per pellet)
--   Reload()
--   UseAbility(slot: "Ability" | "Ultimate", aimPosition: Vector3)
--   BuyUpgrade(upgradeId: "Weapon" | "Vitality")
--   SelectClass(classId: string)            lobby only
--   SelectWeapon(weaponId: string)          lobby only
--   UnlockItem(kind: "Class" | "Weapon", id: string)   spend Gems, lobby only
-- Server -> Client
--   Notify(text: string, kind: "Info" | "Good" | "Danger")     toast message
--   HitConfirm(hits: {{Position, Damage, Headshot, Killed}})   shooter-only hit feedback
--   Effect(kind: string, data: table)                          visual effect; see EffectsController.Handlers
--   RunResults({Wave, WavesCleared, Kills, Gems, NewBest})     end-of-run summary
--   Radio(text: string, event: string)                         commander line (Config/Radio)

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NAMES = {
	"FireWeapon",
	"Reload",
	"UseAbility",
	"BuyUpgrade",
	"SelectClass",
	"SelectWeapon",
	"UnlockItem",
	"Notify",
	"HitConfirm",
	"Effect",
	"RunResults",
	"Radio",
}

local Remotes = {}
local isServer = RunService:IsServer()

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if isServer and not folder then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
elseif not folder then
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

for _, name in NAMES do
	if isServer then
		local remote = folder:FindFirstChild(name) or Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		Remotes[name] = remote
	else
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes
