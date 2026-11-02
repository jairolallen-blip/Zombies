-- Studio -> repo export. Paste into execute_luau (datamodel Edit) while tools/receiver.ps1 is running.
-- Sends every script under the four code roots to the receiver, which writes src/<root>/... files
-- (Rojo suffixes: .server.luau Script, .client.luau LocalScript, .luau ModuleScript).
-- Clear src/ first (Remove-Item src -Recurse) so deleted/renamed scripts don't linger.
-- "problems" lists scripts outside the four roots (they would NOT be saved) and odd parents.
local Http = game:GetService("HttpService")
local maps = {
	{ game.ServerScriptService:FindFirstChild("Server"), "server" },
	{ game.ReplicatedStorage:FindFirstChild("Shared"), "shared" },
	{ game.StarterPlayer.StarterPlayerScripts:FindFirstChild("Client"), "client" },
	{ game.StarterPlayer.StarterCharacterScripts, "character" },
}
local suffix = { Script = ".server.luau", LocalScript = ".client.luau", ModuleScript = ".luau" }
local covered = {}
local n, bytes, problems = 0, 0, {}
for _, m in maps do
	local root, prefix = m[1], m[2]
	for _, d in root:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			covered[d] = true
			local parts, cur = {}, d
			while cur ~= root do
				table.insert(parts, 1, cur.Name)
				if cur ~= d and not cur:IsA("Folder") then
					table.insert(problems, "non-folder parent: " .. cur:GetFullName())
				end
				cur = cur.Parent
			end
			parts[#parts] = parts[#parts] .. suffix[d.ClassName]
			local rel = prefix .. "/" .. table.concat(parts, "/")
			local ok, res = pcall(function()
				return Http:PostAsync("http://localhost:34999/file", Http:JSONEncode({ path = rel, source = d.Source }), Enum.HttpContentType.ApplicationJson)
			end)
			if ok and res == "ok" then
				n += 1
				bytes += #d.Source
			else
				table.insert(problems, rel .. ": " .. tostring(res))
			end
		end
	end
end
for _, r in { game.ServerScriptService, game.ReplicatedStorage, game.StarterPlayer, game.ReplicatedFirst, game.StarterGui, game.ServerStorage, game.Workspace, game.StarterPack } do
	for _, d in r:GetDescendants() do
		if d:IsA("LuaSourceContainer") and not covered[d] then
			table.insert(problems, "outside export: " .. d:GetFullName())
		end
	end
end
pcall(function()
	Http:PostAsync("http://localhost:34999/done", "")
end)
return string.format("sent %d files, %d bytes\nproblems:\n%s", n, bytes, table.concat(problems, "\n"))
