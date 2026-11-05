-- Client entry point. Requires every ModuleScript in Controllers, then calls
--   controller:Init(Controllers)  on all  -- build UI, connect events
--   controller:Start()            on all  -- spawned in its own thread
-- Controllers can reach each other through the table passed to Init (e.g. Controllers.HUDController).

local folder = script.Parent:WaitForChild("Controllers")

local Controllers = {}
for _, module in folder:GetChildren() do
	if module:IsA("ModuleScript") then
		Controllers[module.Name] = require(module)
	end
end
for _, controller in Controllers do
	if controller.Init then
		controller:Init(Controllers)
	end
end
for _, controller in Controllers do
	if controller.Start then
		task.spawn(controller.Start, controller)
	end
end
