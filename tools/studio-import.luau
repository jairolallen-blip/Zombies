-- Repo -> Studio restore. Run tools/pack-scripts.ps1, serve the JSON with tools/serve.ps1, then
-- paste this into execute_luau (datamodel Edit). Writes every repo script into Studio (creating
-- missing ones and folders), and DELETES scripts under the five code roots that the repo doesn't
-- have. Use after someone overwrote the place, or to roll Studio back to a commit.
local Http = game:GetService("HttpService")
local SES = game:GetService("ScriptEditorService")
local files = Http:JSONDecode(Http:GetAsync("http://localhost:34998/"))
local roots = {
	server = game.ServerScriptService:FindFirstChild("Server"),
	shared = game.ReplicatedStorage:FindFirstChild("Shared"),
	client = game.StarterPlayer.StarterPlayerScripts:FindFirstChild("Client"),
	character = game.StarterPlayer.StarterCharacterScripts,
	first = game.ReplicatedFirst,
}
local wanted, written, created, unchanged = {}, 0, 0, 0
for rel, source in files do
	source = source:gsub("\r\n", "\n")
	local prefix, rest = rel:match("^(%w+)/(.+)$")
	local root = roots[prefix]
	assert(root, "no root for " .. rel)
	local segments = rest:split("/")
	local file = table.remove(segments)
	local class, name
	if file:match("%.server%.luau$") then
		class, name = "Script", file:gsub("%.server%.luau$", "")
	elseif file:match("%.client%.luau$") then
		class, name = "LocalScript", file:gsub("%.client%.luau$", "")
	else
		class, name = "ModuleScript", file:gsub("%.luau$", "")
	end
	local parent = root
	for _, seg in segments do
		local folder = parent:FindFirstChild(seg)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = seg
			folder.Parent = parent
		end
		parent = folder
	end
	local inst = parent:FindFirstChild(name)
	if inst and not inst:IsA(class) then
		inst:Destroy()
		inst = nil
	end
	if not inst then
		inst = Instance.new(class)
		inst.Name = name
		inst.Parent = parent
		created += 1
	end
	wanted[inst] = true
	if inst.Source:gsub("\r\n", "\n") ~= source then
		SES:UpdateSourceAsync(inst, function()
			return source
		end)
		written += 1
	else
		unchanged += 1
	end
end
local removed = {}
for _, root in roots do
	for _, d in root:GetDescendants() do
		if d:IsA("LuaSourceContainer") and not wanted[d] then
			table.insert(removed, d:GetFullName())
			d:Destroy()
		end
	end
end
return string.format("written %d, created %d, unchanged %d\nremoved: %s", written, created, unchanged, table.concat(removed, ", "))
