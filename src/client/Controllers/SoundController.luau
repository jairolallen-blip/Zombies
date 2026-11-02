-- SoundController: all game audio, client-side (ids + volumes in Shared/Config/Sounds).
-- Nothing on the server changes: sounds hang off events the client already receives.
--   your gun          WeaponController -> :PlayGunshot (2D), :SetSpin (minigun loop), reload
--   others' guns      Remotes.Effect "Tracer" (WeaponId) -> 3D gunshot at the muzzle
--   hits / kills      Remotes.HitConfirm -> hitmarker / kill tick
--   zombies           ambient groans from nearby zombies, "ZombieDeath" death cries,
--                     "SpawnWarning" groan as one rises, hurt swipe when your health drops
--   explosions        "Explosion" boom, "Shockwave" ground slam (boss slam, Bruiser stomp)
--   match             Remotes.Radio event names: radio squelch on every line, wave sting on
--                     WaveStart/FirstWave, boss roar on BossIncoming/BossEnraged, Victory jingle,
--                     low sting on Overrun
--   loops             helicopter while Deploying, eerie ambience during the run
--   UI                click on every GuiButton
--
-- Public: :Play(name, opts?) 2D, :PlayAt(name, position, opts?) 3D, :PlayGunshot(weaponId, pos),
--         :SetSpin(0..1), :PlayUI(name)
--         :Loop(name) -> a looped Sound for the caller to drive (CutsceneController's deploy audio)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared.Config.Sounds)
local Remotes = require(Shared.Remotes)
local GameState = require(Shared.GameState)

local player = Players.LocalPlayer
local SoundController = {}
local Controllers

local group -- SoundGroup for everything
local loops = {} -- [name] = Sound (persistent looped sounds)
local lastPlayed = {} -- [name] = os.clock() for throttling

local function newSound(name, parent)
	local def = Sounds.Library[name]
	if not def then
		warn("[SoundController] unknown sound", name)
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = "rbxassetid://" .. def.Id
	s.Volume = def.Volume or 0.5
	s.Looped = def.Looped == true
	s.SoundGroup = group
	if def.MaxDistance then
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 8
		s.RollOffMaxDistance = def.MaxDistance
	end
	s.Parent = parent
	return s, def
end

local function throttled(name, gap)
	local now = os.clock()
	if lastPlayed[name] and now - lastPlayed[name] < gap then
		return true
	end
	lastPlayed[name] = now
	return false
end

local function fire(s, def, opts)
	opts = opts or {}
	local var = def.PitchVar or 0
	s.PlaybackSpeed = (def.Pitch or 1) * (opts.Pitch or 1) * (1 + (math.random() * 2 - 1) * var)
	s.Volume *= opts.Volume or 1
	s:Play()
	task.delay(math.max(s.TimeLength, 0.5) / s.PlaybackSpeed + 0.5, function()
		if s.Parent and s.Parent:IsA("Attachment") then
			s.Parent:Destroy()
		else
			s:Destroy()
		end
	end)
end

-- 2D (non-positional) one-shot
function SoundController:Play(name, opts)
	local s, def = newSound(name, SoundService)
	if s then
		fire(s, def, opts)
	end
end

-- 3D one-shot at a world position
function SoundController:PlayAt(name, position, opts)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	local s, def = newSound(name, attachment)
	if s then
		fire(s, def, opts)
	else
		attachment:Destroy()
	end
end

-- A looped library sound in the game's SoundGroup, not playing yet (the caller drives + destroys it)
function SoundController:Loop(name)
	return (newSound(name, SoundService))
end

function SoundController:PlayUI(name)
	self:Play(name)
end

function SoundController:PlayGunshot(weaponId, _position)
	local map = Sounds.Guns[weaponId] or Sounds.Guns.Pistol
	self:Play(map[1], { Pitch = map[2] })
end

-- Minigun barrel spin loop: volume + pitch follow the spin-up (0..1)
function SoundController:SetSpin(spin)
	local loop = loops.MinigunSpin
	if not loop then
		return
	end
	if spin > 0.02 then
		loop.Volume = Sounds.Library.MinigunSpin.Volume * math.min(1, spin * 1.5)
		loop.PlaybackSpeed = 0.6 + 0.6 * spin
		if not loop.IsPlaying then
			loop:Play()
		end
	elseif loop.IsPlaying then
		loop:Stop()
	end
end

local function pick(list)
	return list[math.random(1, #list)]
end

local function localRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function setLoop(name, on)
	local loop = loops[name]
	if on and not loop.IsPlaying then
		loop:Play()
	elseif not on and loop.IsPlaying then
		loop:Stop()
	end
end

function SoundController:Init(controllers)
	Controllers = controllers
	group = Instance.new("SoundGroup")
	group.Name = "SAMZ_Sounds"
	group.Volume = 1
	group.Parent = SoundService
	for _, name in { "MinigunSpin", "Ambience", "Helicopter" } do
		loops[name] = newSound(name, SoundService)
	end

	-- world events (same remote the visual effects use)
	Remotes.Effect.OnClientEvent:Connect(function(kind, data)
		if type(data) ~= "table" then
			return
		end
		if kind == "Tracer" and data.From then
			local map = Sounds.Guns[data.WeaponId or ""] or Sounds.Guns.SMG
			self:PlayAt(map[1], data.From, { Pitch = map[2], Volume = 0.8 })
		elseif kind == "Explosion" and data.Position then
			self:PlayAt("Explosion", data.Position)
		elseif kind == "Shockwave" and data.Position then
			self:PlayAt("Slam", data.Position)
		elseif kind == "ZombieDeath" and data.Position then
			if not throttled("ZombieDeath", 0.12) then
				self:PlayAt(pick(Sounds.Deaths), data.Position, { Pitch = 1 / math.sqrt(data.Scale or 1) })
			end
		elseif kind == "SpawnWarning" and data.Position then
			if math.random() < 0.5 then
				task.delay(data.Time or 1.2, function()
					self:PlayAt(pick(Sounds.Groans), data.Position, { Volume = 0.8 })
				end)
			end
		end
	end)

	Remotes.HitConfirm.OnClientEvent:Connect(function(hits)
		local killed = false
		for _, hit in hits do
			killed = killed or hit.Killed
		end
		if killed then
			self:Play("Kill")
		elseif not throttled("Hit", 0.05) then
			self:Play("Hit")
		end
	end)

	Remotes.Radio.OnClientEvent:Connect(function(_text, event)
		self:Play("Radio")
		if event == "WaveStart" or event == "FirstWave" then
			self:Play("WaveSting")
		elseif event == "BossIncoming" or event == "BossEnraged" then
			self:Play("BossRoar")
		elseif event == "Victory" then
			self:Play("Victory")
		elseif event == "Overrun" then
			self:Play("WaveSting", { Pitch = 0.6 })
		end
	end)

	-- hurt swipe when your health drops
	local function watchCharacter(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then
			return
		end
		local last = humanoid.Health
		humanoid.HealthChanged:Connect(function(health)
			if health < last - 0.5 and health > 0 and player:GetAttribute("InRun") and not throttled("Hurt", 0.35) then
				self:Play("Hurt")
			end
			last = health
		end)
	end
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)

	-- UI clicks on every button in PlayerGui
	local playerGui = player:WaitForChild("PlayerGui")
	local function hookButton(d)
		if d:IsA("GuiButton") then
			d.Activated:Connect(function()
				self:Play("Click")
			end)
		end
	end
	for _, d in playerGui:GetDescendants() do
		hookButton(d)
	end
	playerGui.DescendantAdded:Connect(hookButton)
end

function SoundController:Start()
	local nextGroan = os.clock() + 2
	RunService.Heartbeat:Connect(function()
		local inRun = player:GetAttribute("InRun") == true
		local deploying = player:GetAttribute("Deploying") == true
		setLoop("Helicopter", deploying)
		setLoop("Ambience", inRun and not deploying)
		-- ambient groans from a random nearby zombie
		local now = os.clock()
		if inRun and now >= nextGroan then
			nextGroan = now + Sounds.GroanInterval[1] + math.random() * (Sounds.GroanInterval[2] - Sounds.GroanInterval[1])
			local root = localRoot()
			local folder = workspace:FindFirstChild("Zombies")
			if root and folder then
				local near = {}
				for _, z in folder:GetChildren() do
					local pivot = z:IsA("Model") and z:GetPivot()
					if pivot and (pivot.Position - root.Position).Magnitude < Sounds.GroanRange then
						table.insert(near, pivot.Position)
					end
				end
				if #near > 0 then
					local scale = 1
					self:PlayAt(pick(Sounds.Groans), pick(near), { Pitch = scale })
				end
			end
		end
	end)
end

return SoundController
