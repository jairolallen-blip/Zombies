-- Sounds: every sound in the game (pure data; played by Client/Controllers/SoundController).
-- All ids are public Creator Store audio that loads in this place (checked 2026-11-01). Most are from
-- the Roblox-licensed libraries "ProSoundEffects" (Pro Sound Effects) and "APMOfficial" (APM
-- Music); swap any id here to change a sound everywhere.
--
-- Library entry: { Id, Volume, Pitch = 1, PitchVar = 0 (random +/-), MaxDistance (3D roll-off), Looped }

local Sounds = {}

Sounds.Library = {
	-- guns (keys referenced by Sounds.Guns)
	Pistol = { Id = 9114729252, Volume = 0.55, Pitch = 1.15, PitchVar = 0.05, MaxDistance = 300 }, -- Pro Sound Effects, Mini Uzi single
	Revolver = { Id = 3102797479, Volume = 0.6, Pitch = 1, PitchVar = 0.04, MaxDistance = 350 },
	SMG = { Id = 9114729298, Volume = 0.45, Pitch = 1.05, PitchVar = 0.06, MaxDistance = 300 }, -- Pro Sound Effects, Mini Uzi single
	Shotgun = { Id = 82651111765871, Volume = 0.65, Pitch = 1, PitchVar = 0.04, MaxDistance = 350 }, -- HM Shotgun Shot
	ShotgunPump = { Id = 9112913564, Volume = 0.6, PitchVar = 0.04 }, -- PSE, 12 Gauge Shotgun 9 (the pump rack; pump shotgun only)
	Rifle = { Id = 9114727430, Volume = 0.5, Pitch = 1, PitchVar = 0.05, MaxDistance = 400 }, -- Pro Sound Effects, AK-47 single
	Marksman = { Id = 9114725473, Volume = 0.6, Pitch = 1, PitchVar = 0.03, MaxDistance = 500 }, -- Pro Sound Effects, gun retort
	MinigunShot = { Id = 9114727096, Volume = 0.35, Pitch = 1.3, PitchVar = 0.06, MaxDistance = 350 }, -- Pro Sound Effects, AK-47 single
	MinigunSpin = { Id = 99254726606196, Volume = 0.5, Looped = true },
	Laser = { Id = 4400449399, Volume = 0.5, Pitch = 1, PitchVar = 0.05, MaxDistance = 300 },
	Reload = { Id = 117963160131194, Volume = 0.6 },

	-- feedback
	Hit = { Id = 138148057831879, Volume = 0.35, PitchVar = 0.05 },
	Kill = { Id = 125235091454234, Volume = 0.5, Pitch = 0.9 },
	Hurt = { Id = 131125543405500, Volume = 0.6, PitchVar = 0.1 }, -- zombie swipe when you take damage
	Click = { Id = 88442833509532, Volume = 0.6 },
	Radio = { Id = 75433529280871, Volume = 0.45 }, -- radio squelch before Sgt. Voss talks

	-- zombies / world (3D)
	Groan1 = { Id = 129294628821291, Volume = 0.55, PitchVar = 0.12, MaxDistance = 90 },
	Groan2 = { Id = 100949226522885, Volume = 0.55, PitchVar = 0.12, MaxDistance = 90 },
	Groan3 = { Id = 130156156621885, Volume = 0.55, PitchVar = 0.12, MaxDistance = 90 },
	Death1 = { Id = 135839328422285, Volume = 0.5, PitchVar = 0.12, MaxDistance = 120 },
	Death2 = { Id = 137298984843378, Volume = 0.45, PitchVar = 0.12, MaxDistance = 120 },
	Explosion = { Id = 138533090376585, Volume = 0.8, PitchVar = 0.08, MaxDistance = 400 },
	Slam = { Id = 91288569991875, Volume = 0.8, PitchVar = 0.05, MaxDistance = 300 },
	BossRoar = { Id = 9113980319, Volume = 0.8, Pitch = 0.85 }, -- Pro Sound Effects, creature roar

	-- music / ambience (2D)
	Ambience = { Id = 9112775414, Volume = 0.35, Looped = true }, -- Pro Sound Effects, eerie ambience loop
	Helicopter = { Id = 126966962086051, Volume = 0.6, Looped = true },
	WaveSting = { Id = 9039981895, Volume = 0.6 }, -- APM Music, "Hellish"
	Victory = { Id = 9067124098, Volume = 0.7 },

	-- final boss (BossController; ids checked 2026-11-02)
	BossMusic = { Id = 1837840355, Volume = 0.45, Looped = true }, -- APM Music, "Vengeful Attack" (fades in after the intro)
	BossIntroDrums = { Id = 1835248722, Volume = 0.6, Looped = true }, -- APM Music, "Stalking the Prey 60" (under the entrance)

	-- deploy cutscene (CutsceneController drives the loops' volume per frame; ids checked 2026-11-01)
	CabinWind = { Id = 85352789269452, Volume = 0.35, Looped = true }, -- loop_wind_01 (WhistleAcousticMan), wind through the open door
	SeaWash = { Id = 93281700241946, Volume = 0.5, Looped = true }, -- Calm Sea Beach Ambience, waves under the rotor wash
	PilotChatter = { Id = 7225461356, Volume = 0.18, Looped = true }, -- Vietnam War Radio Chatter - Briefing (3r5x4), faint cockpit radio
	JumpWhoosh = { Id = 12222095, Volume = 0.6, Pitch = 0.8 }, -- Roblox, Rocket whoosh 01
	ParachuteOpen = { Id = 157822167, Volume = 0.7 }, -- Parachute Open (DarpyAdultman)
	FallWind = { Id = 6544555787, Volume = 0.35, Looped = true }, -- Fierce howling loud wind (Festivereinhard2), under the chute

	-- lobby (Client/Controllers/LobbyAudioController; ids checked 2026-11-02). Quiet on purpose: music is a
	-- slow playlist (Sounds.LobbyPlaylist), and the 3D loops are placed in the lobby map (Server/Map/Commons)
	LobbyMusic1 = { Id = 9043586747, Volume = 0.2 }, -- APM, "Remembering You (c)", sparse piano
	LobbyMusic2 = { Id = 1838792473, Volume = 0.2 }, -- APM, "Dawn 2"
	LobbyMusic3 = { Id = 9042042586, Volume = 0.18 }, -- APM, "Eternal Ice (b)", soft string drones
	LobbySea = { Id = 93281700241946, Volume = 0.12, Looped = true }, -- Calm Sea Beach Ambience, the island's shore
	LobbyEerie = { Id = 9112775414, Volume = 0.07, Looped = true }, -- PSE, Eerie Ambience 2 (the in-run bed, much quieter)
	FireCrackle = { Id = 109494611784143, Volume = 0.45, MaxDistance = 26, Looped = true }, -- Kaminfeuer (DistrokidOfficial), fire crackle
	RadioChatter = { Id = 7225461356, Volume = 0.4, MaxDistance = 36, Looped = true }, -- the cutscene's radio chatter, from the radio shack

}

-- Lobby music, played in order with a pause between tracks (LobbyAudioController)
Sounds.LobbyPlaylist = { "LobbyMusic1", "LobbyMusic2", "LobbyMusic3" }


-- Weapon id (Config/Weapons) -> { library key, pitch multiplier, follow-up sound? }
Sounds.Guns = {
	Pistol = { "Pistol", 1 },
	Revolver = { "Revolver", 1 },
	SMG = { "SMG", 1 },
	Shotgun = { "Shotgun", 1, "ShotgunPump" }, -- optional 3rd: sound played 0.35s after the shot
	AssaultRifle = { "Rifle", 1 },
	AutoShotgun = { "Shotgun", 1.12 },
	Rifle = { "Marksman", 1 },
	Minigun = { "MinigunShot", 1 },
	LaserRifle = { "Laser", 1 },
	AutoSniper = { "Marksman", 1.1 },
}

Sounds.Groans = { "Groan1", "Groan2", "Groan3" }
Sounds.Deaths = { "Death1", "Death2" }

-- Ambient zombie groans: every GroanInterval seconds a random zombie within GroanRange groans.
Sounds.GroanInterval = { 1.2, 3 }
Sounds.GroanRange = 80

return Sounds
