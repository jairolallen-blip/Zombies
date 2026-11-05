-- Server entry point. Requires every ModuleScript in Services, then calls
--   service:Init(Services)  on all (in ORDER)  -- create instances, connect remotes, no yielding
--   service:Start()         on all (in ORDER)  -- spawned in its own thread; may loop forever
-- Services reference each other through the Services table passed to Init.
-- New service? Drop a ModuleScript in Services/ — it is auto-loaded after the ordered ones.

local Players = game:GetService("Players")
Players.CharacterAutoLoads = false -- MatchService spawns characters manually

local folder = script.Parent:WaitForChild("Services")

local ORDER = {
	"DataService",
	"MapService",
	"EconomyService",
	"CombatService",
	"ZombieService",
	"AbilityService",
	"LobbyService",
	"MatchService",
}

local Services = {}
for _, name in ORDER do
	Services[name] = require(folder:WaitForChild(name))
end
for _, module in folder:GetChildren() do
	if module:IsA("ModuleScript") and not Services[module.Name] then
		Services[module.Name] = require(module)
		table.insert(ORDER, module.Name)
	end
end

for _, name in ORDER do
	local service = Services[name]
	if service.Init then
		service:Init(Services)
	end
end
for _, name in ORDER do
	local service = Services[name]
	if service.Start then
		task.spawn(service.Start, service)
	end
end

print("[SAMZ] Server started with services: " .. table.concat(ORDER, ", "))
