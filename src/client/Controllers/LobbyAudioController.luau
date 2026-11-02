-- LobbyAudioController: the safehouse's sound (ids and volumes in Shared/Config/Sounds).
--   music     Sounds.LobbyPlaylist in order, quiet, with a pause between tracks; fades in while you're in
--             the lobby (InRun false, not a match server's waiting screen) and out when a run starts
--   ambience  a soft sea wash and a faint eerie bed under it, same fade
--   3D loops  Sounds named "LobbyAmbient" in the lobby map (fire crackle, radio chatter; placed by
--             Server/Map/Commons) are started as they stream in; their roll-off keeps them local

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared.Config.Sounds)
local GameConfig = require(Shared.Config.GameConfig)
local GameState = require(Shared.GameState)

local player = Players.LocalPlayer
local LobbyAudioController = {}

local TRACK_GAP = 20 -- seconds of quiet between music tracks
local FADE = 2.5

local function newSound(key)
	local def = Sounds.Library[key]
	local s = Instance.new("Sound")
	s.Name = "Lobby_" .. key
	s.SoundId = "rbxassetid://" .. def.Id
	s.Looped = def.Looped == true
	s.Volume = 0
	s:SetAttribute("Target", def.Volume)
	s.Parent = SoundService
	return s
end

local function inLobby()
	return player:GetAttribute("InRun") ~= true and GameState:GetAttribute("ServerKind") ~= "Match"
end

local function startAmbient(s)
	if s:IsA("Sound") and s.Name == "LobbyAmbient" and not s.IsPlaying then
		s.TimePosition = math.random() * 20 -- so neighbouring fires don't crackle in sync
		s:Play()
	end
end

function LobbyAudioController:Start()
	local beds = { newSound("LobbySea"), newSound("LobbyEerie") }
	local tracks = {}
	for _, key in Sounds.LobbyPlaylist do
		table.insert(tracks, newSound(key))
	end
	local level = 0 -- 0..1 lobby mix, faded in and out
	local function apply(target)
		for _, s in beds do
			TweenService:Create(s, TweenInfo.new(FADE), { Volume = s:GetAttribute("Target") * target }):Play()
		end
		for _, s in tracks do
			TweenService:Create(s, TweenInfo.new(FADE), { Volume = s:GetAttribute("Target") * target }):Play()
		end
		level = target
	end
	for _, s in beds do
		s:Play()
	end

	-- 3D loops in the lobby map (it streams in, so watch for new ones)
	local root = workspace:WaitForChild(GameConfig.OurMap.Folder)
	for _, d in root:GetDescendants() do
		startAmbient(d)
	end
	root.DescendantAdded:Connect(startAmbient)

	-- playlist: one track at a time, a pause, the next
	task.spawn(function()
		local i = 0
		while true do
			i = i % #tracks + 1
			local track = tracks[i]
			track.TimePosition = 0
			track:Play()
			track.Ended:Wait()
			task.wait(TRACK_GAP)
		end
	end)

	while true do
		local want = if inLobby() then 1 else 0
		if want ~= level then
			apply(want)
		end
		task.wait(0.5)
	end
end

return LobbyAudioController
