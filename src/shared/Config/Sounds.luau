-- Sounds: every sound in the game (pure data; played by Client/Controllers/SoundController).
-- All ids are public Creator Store audio that loads in this place (checked 2026-11-01 with
-- ContentProvider:PreloadAsync). Guns, reload parts, footsteps, impacts, grenade and explosion are
-- from the Roblox-licensed "ProSoundEffects" library (Pro Sound Effects); stingers from "APMOfficial".
-- Swap any id here to change a sound everywhere. Roblox's default walking/jumping sounds are
-- switched off (StarterPlayerScripts.RbxCharacterSounds is an empty override); footsteps below.
--
-- Library entry: { Id, Volume, Pitch = 1, PitchVar = 0 (random +/-), MaxDistance (3D roll-off), Looped }

local Sounds = {}

Sounds.Library = {
	-- guns (keys referenced by Sounds.Guns)
	Pistol = { Id = 9117402631, Volume = 0.55, PitchVar = 0.04, MaxDistance = 300 }, -- PSE, Pistol Single Shots 5
	Revolver = { Id = 3102797479, Volume = 0.6, PitchVar = 0.04, MaxDistance = 350 }, -- Heavy Pistol Gunshot (owner: keep this one, not the S&W 357)
	SMG = { Id = 9117399569, Volume = 0.42, Pitch = 1.12, PitchVar = 0.05, MaxDistance = 300 }, -- PSE, Pistol Single Shots 1
	Shotgun = { Id = 82651111765871, Volume = 0.65, PitchVar = 0.04, MaxDistance = 350 }, -- HM Shotgun Shot
	ShotgunPump = { Id = 9112913564, Volume = 0.6, PitchVar = 0.04 }, -- PSE, 12 Gauge Shotgun 9 (the pump rack; pump shotgun only)
	Rifle = { Id = 9113180776, Volume = 0.5, PitchVar = 0.05, MaxDistance = 400 }, -- PSE, Assault Rifle 9
	Marksman = { Id = 9118173988, Volume = 0.6, PitchVar = 0.03, MaxDistance = 500 }, -- PSE, Rifle Single Shots 3
	Sniper = { Id = 9118174272, Volume = 0.6, PitchVar = 0.03, MaxDistance = 500 }, -- PSE, Rifle Single Shots 5
	MinigunShot = { Id = 9116341721, Volume = 0.32, Pitch = 1.1, PitchVar = 0.06, MaxDistance = 350 }, -- PSE, Machine Gun 7
	MinigunSpin = { Id = 99254726606196, Volume = 0.5, Looped = true },
	Laser = { Id = 9116236630, Volume = 0.45, PitchVar = 0.05, MaxDistance = 300 }, -- PSE, Laser Cannon 1702

	-- gun handling (SoundController:PlayReload times these to the viewmodel reload)
	MagOut = { Id = 9113104176, Volume = 0.55, PitchVar = 0.04 }, -- PSE, Ammo Magazine 1
	MagIn = { Id = 9113104337, Volume = 0.6, PitchVar = 0.04 }, -- PSE, Ammo Magazine 3 (also shell loads, pitched up)
	Bolt = { Id = 9116357355, Volume = 0.5, PitchVar = 0.04 }, -- PSE, Machine Gun Bolt 2
	Equip = { Id = 9116362330, Volume = 0.45, PitchVar = 0.05 }, -- PSE, Machine Gun Movement 1
	Aim = { Id = 9113824230, Volume = 0.3, Pitch = 1.2, PitchVar = 0.08 }, -- PSE, Cloth Movement 24
	Shell = { Id = 9113849011, Volume = 0.12, Pitch = 1.6, PitchVar = 0.15 }, -- PSE, brass tink on the ground
	Reload = { Id = 117963160131194, Volume = 0.6 }, -- old one-shot reload (unused; kept for reference)

	-- player movement (footsteps for every character; jump/land for you)
	Step1 = { Id = 9114523161, Volume = 0.16, Pitch = 1.15, PitchVar = 0.08, MaxDistance = 45 }, -- PSE, Foot Stomp 1
	Step2 = { Id = 9114523351, Volume = 0.16, Pitch = 1.15, PitchVar = 0.08, MaxDistance = 45 }, -- PSE, Foot Stomp 2
	Step3 = { Id = 9114523345, Volume = 0.16, Pitch = 1.15, PitchVar = 0.08, MaxDistance = 45 }, -- PSE, Foot Stomp 3
	Step4 = { Id = 9114523358, Volume = 0.16, Pitch = 1.15, PitchVar = 0.08, MaxDistance = 45 }, -- PSE, Foot Stomp 4
	Step5 = { Id = 9114523612, Volume = 0.16, Pitch = 1.15, PitchVar = 0.08, MaxDistance = 45 }, -- PSE, Foot Stomp 6
	Jump = { Id = 9113823745, Volume = 0.25, Pitch = 1.1, PitchVar = 0.08 }, -- PSE, Cloth Movement 15
	Land = { Id = 9114523629, Volume = 0.35, PitchVar = 0.06 }, -- PSE, Foot Stomp 7

	-- grenade
	GrenadePin = { Id = 9114659833, Volume = 0.55, MaxDistance = 40 }, -- PSE, Grenade Pull Pin 2
	Throw = { Id = 9120972321, Volume = 0.45, PitchVar = 0.06, MaxDistance = 50 }, -- PSE, Wood Whoosh Quick Swings 4

	-- feedback
	Hit = { Id = 138148057831879, Volume = 0.35, PitchVar = 0.05 },
	Impact1 = { Id = 9117969584, Volume = 0.22, PitchVar = 0.1 }, -- PSE, Punch Kit Beefy Hit 1 (flesh thud under the hit tick)
	Impact2 = { Id = 9117970227, Volume = 0.22, PitchVar = 0.1 }, -- PSE, Punch Kit Beefy Hit 8
	Kill = { Id = 125235091454234, Volume = 0.5, Pitch = 0.9 },
	Hurt = { Id = 131125543405500, Volume = 0.6, PitchVar = 0.1 }, -- zombie swipe when you take damage
	Click = { Id = 88442833509532, Volume = 0.6 },
	UIHover = { Id = 139800881181209, Volume = 0.25 }, -- "ui-simple-button-hover" (AmbientSorcery), lobby menu tiles
	-- welcome screen level bar (WelcomeController; ids checked 2026-11-03)
	XPTick = { Id = 72644163309528, Volume = 0.18 }, -- Glockenspiel C6, ticked higher as the bar fills
	LevelUp = { Id = 132574644259001, Volume = 0.6 }, -- "Complete_Rare" (Draedon Studios), the level-up sting
	LevelUpSparkle = { Id = 79130903404606, Volume = 0.4 }, -- "crystal fx", a sparkle on top
	Radio = { Id = 75433529280871, Volume = 0.45 }, -- radio squelch before Sgt. Voss talks

	-- zombies / world (3D)
	Groan1 = { Id = 129294628821291, Volume = 0.55, PitchVar = 0.12, MaxDistance = 90 },
	Groan2 = { Id = 100949226522885, Volume = 0.55, PitchVar = 0.12, MaxDistance = 90 },
	Groan3 = { Id = 130156156621885, Volume = 0.55, PitchVar = 0.12, MaxDistance = 90 },
	Death1 = { Id = 135839328422285, Volume = 0.5, PitchVar = 0.12, MaxDistance = 120 },
	Death2 = { Id = 137298984843378, Volume = 0.45, PitchVar = 0.12, MaxDistance = 120 },
	Explosion = { Id = 9116973611, Volume = 0.9, PitchVar = 0.08, MaxDistance = 400 }, -- PSE, Mortar Explosion 3
	Slam = { Id = 91288569991875, Volume = 0.8, PitchVar = 0.05, MaxDistance = 300 },
	BossRoar = { Id = 9113980319, Volume = 0.8, Pitch = 0.85 }, -- PSE, creature roar

	-- music / ambience (2D)
	Ambience = { Id = 9112775414, Volume = 0.35, Looped = true }, -- PSE, Eerie Ambience 2
	Helicopter = { Id = 126966962086051, Volume = 0.6, Looped = true },
	WaveSting = { Id = 9039981895, Volume = 0.6 }, -- APM Music, "Hellish"
	Victory = { Id = 9067124098, Volume = 0.7 },

	-- final boss (BossController; ids checked 2026-11-02)
	BossMusic = { Id = 1837840355, Volume = 0.45, Looped = true }, -- APM Music, "Vengeful Attack" (fades in after the intro)
	BossIntroDrums = { Id = 1835248722, Volume = 0.6, Looped = true }, -- APM Music, "Stalking the Prey 60" (under the entrance)
	-- Bloom Mother's ultimate and death (BossController; APM "Horror Tools" / "Trailer Tools", ids checked 2026-11-03)
	BloomRiser = { Id = 9043343295, Volume = 0.8 }, -- "Reverse Noise Hard End 09" (4.1s), stretched to the burst windup
	BloomRumble = { Id = 9043356042, Volume = 0.55 }, -- "Airy Metal Rumble 01", under the windup
	BloomThump = { Id = 9043367738, Volume = 0.6 }, -- "Percussive Noise 12 - Distorted FX Kick", the quickening heartbeat
	BloomBlastTail = { Id = 9043355570, Volume = 0.7, MaxDistance = 500 }, -- "One Shot - Low Drone 05", the boom's tail
	BloomDeathGroan = { Id = 9043357191, Volume = 0.6 }, -- "Bassbend Down 05", as it staggers
	BloomDeathRiser = { Id = 9040281024, Volume = 0.75 }, -- "Amplified Expanse" (5.7s), ends on the death burst

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
	AutoShotgun = { "Shotgun", 1.1 },
	Rifle = { "Marksman", 1 },
	Minigun = { "MinigunShot", 1 },
	LaserRifle = { "Laser", 1 },
	AutoSniper = { "Sniper", 1.05 },
}

Sounds.Groans = { "Groan1", "Groan2", "Groan3" }
Sounds.Deaths = { "Death1", "Death2" }
Sounds.Steps = { "Step1", "Step2", "Step3", "Step4", "Step5" }
Sounds.Impacts = { "Impact1", "Impact2" }

-- Ambient zombie groans: every GroanInterval seconds a random zombie within GroanRange groans.
Sounds.GroanInterval = { 1.2, 3 }
Sounds.GroanRange = 80

-- Footsteps: one step every StepStride studs walked (so faster = quicker steps).
Sounds.StepStride = 5.2

return Sounds
