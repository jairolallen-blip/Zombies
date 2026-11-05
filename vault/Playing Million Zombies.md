# Playing Million Zombies

How to play and test Survive a Million Zombies. General Roblox methods are in [[Playing Roblox Games]]. Back to [[Home]].

## Ids

- Main place: 110463048909417
- Outbreak place: 87622086122699
- Keep this guide's numbers in step with `GameConfig`. If they differ, the config is right.

## Controls

| Input | Action |
|---|---|
| W A S D, Space | Move, jump |
| Left mouse | Fire |
| Right mouse, held | Aim down sights |
| R | Reload |
| E | Class ability |
| F | Ultimate, when charged |
| 1 | Buy the next gun level |
| 2 | Buy Vitality: more max HP and a full heal |
| Left Alt, held | Free the mouse in first person, to click the HUD |
| Space, held | Skip a cutscene |
| Enter | Enter Safehouse on the welcome screen |
| Backspace | Close the Trader and the walk-up shops |
| 1 to 4 in shops | Switch tabs |

Runs are first person. The lobby is third person. Phone and gamepad controls are in [[Phones and Gamepads]].

## A normal run

1. The welcome screen shows level and stats. Click ENTER SAFEHOUSE, at about 1538, 926 on 1920x1080.
2. The store may open from that same click. Press Backspace. Never click the green R$ buttons.
3. Click QUICK PLAY, at about 960, 1018. It moves you onto a pad.
4. On the pad, the host picks squad size and map. Take-off is 15 seconds, or 4 with a full squad. A size 1 squad fills it at once.
5. You move to a private match server. In the log this is a new `! Joining game` line.
6. The helicopter ride takes about 20 seconds. Hold Space to skip it.
7. You land at the plaza with a Level 1 gun and $0. Wave 1 starts after a short countdown.
8. Clear 10 waves. The last is the boss wave.
9. Victory or Overrun shows a report, then you go back to a lobby server with a Run Report screen.

## How to survive

- Standing still loses. An idle player went down during wave 1 within about 40 seconds of landing.
- Intermission between waves is about 10 seconds. Reload then.
- Zombies come from every direction and rise out of the ground, 22 to 75 studs away. A red circle warns you first.
- Keep moving and keep your back clear.
- Headshots count extra. Hits on `Head` parts and `Eye` parts are headshots.
- Kills pay Cash, and a combo raises the multiplier.
- HP doesn't regenerate during a wave, but clearing a wave heals you fully. So Vitality (2) is an emergency heal as well as more max HP. Buy it when you're low mid-wave, not between waves.
- Buy gun levels (1) at $500, $2,500 and $10,000.
- Use E on cooldown and F when it's ready. The bottom-left slots glow when they're ready.
- Red smoke marks a supply crate. See [[Supply Drops]].
- Enemy details are in [[Zombies]], and wave details are in [[Waves and Boss]].

## A winning run

The owner's solo Engineer win from 2026-11-05: 10 waves, 337 kills, +217 Gems, 7:40 from the lobby. Times are approximate, read from frames 5 seconds apart.

| Wave | Starts | Zombies | Cash when cleared | What the owner did |
|---|---|---|---|---|
| 1 | 0:50 | 14 | $460 | Hand Cannon, no damage |
| 2 | 1:30 | 19 | $1,145 | Down to 70/100 |
| 3 | 2:05 | 22 | $2,155 | Down to 72/100 |
| 4 | 2:45 | 29 | $2,825 | Bought Pump Shotgun mid-fight at 35/100 |
| 5 | 3:20 | 34 | $1,378 | Vitality twice at about 60 HP, then Auto Shotgun at 56/140 |
| 6 | 4:00 | 39 | $3,063 | Sentry Nest at 62/140 cleared 4 zombies in half a second |
| 7 | 4:35 | 43 | $5,293 | Down to 52/140 |
| 8 | 5:25 | 49 | $7,718 | Took no damage: fought from the raised fountain rim |
| 9 | 6:10 | 54 | $10,503 | Took no damage from the same spot |
| 10 | 6:50 | 24 plus the Titan | $4,150 | Laser Rifle at the start, Vitality at 36/140, then mopped up |

What worked:

- Saved Cash through waves 6 to 9, then bought the $10,000 Laser Rifle right before the boss.
- Spent nothing between waves unless needed, because the wave clear heals you for free.
- Stood on the fountain rim from wave 7. Zombies had to come up in a line.
- Used F when in trouble, then E as cover. Both come back quickly.
- Each wave pays more on clear, $250 for wave 1 up to $1,450 for wave 9.
- The Titan enrages at about half health and calls more zombies. Red ground marks its slam.
- Zombie hits are small but constant: about 10 HP a hit, so a crowd takes 100 HP in seconds.

## Fast testing in Studio

- `game.ServerStorage.SAMZ_Debug:Invoke(cmd, ...)` from the Server data model. `Help` lists the commands. Useful ones: `God`, `Spawn type n`, `KillAll`, `SkipToWave n`, `State`, `GiveCash`, `Airdrop`.
- From Client: `require(ReplicatedStorage.Shared.Remotes).QuickPlay:FireServer()` starts a run in about 17 seconds, and `Remotes.SkipCutscene:FireServer()` skips the ride.
- The Outbreak place starts a run by itself when you press Play.
- `ReplicatedStorage.ZombiePreviews` holds one model of each type, ready to clone for pose sheets.
- A clone placed in `workspace.Zombies` plays the real animation loop. Set `ZombieId`, `Pose` and `PoseAt` on it.
- Studio API access is on, so a finished Studio run can reach the real profile. The owner allows that.
- Zombies stream in, so a client may see a zombie with no `Root` yet. Check before using it.

## Testing live

Timing for a capture, counted from the `! Joining game` line after take-off:

| Seconds | What happens |
|---|---|
| 0 to 20 | Ride |
| 20 to 30 | Landing, Sgt. Voss talks, Wave 0 |
| 30 to 35 | WAVE 1 banner, 14 zombies solo |
| 35 and later | Zombies reach you |

Use `tools/roblox-input.ps1 -Action sheet` from about 30 seconds in. Each tool call is slow, so join and capture from one script.

## Permissions

- The owner's own progress may change. Kill bosses and finish runs freely.
- Publish without asking once a change is tested and confirmed ready. Publish both places when shared code changed.
- Avoid anything that reaches other players. That includes the Outbreak kill meter, which is shared by the whole server.

## Known oddities

- Outbreak holds its own copy of the scripts, and 19 shared scripts differ from main. Patch by exact text, and don't copy whole files.
- Outbreak gives nearby zombies to the closest player, so a packed horde costs client physics. See `CLAUDE.md`.
- Welcome screen zombies use a simpler older animation than the ones in a run.
- The Studio menu bar can vanish from a window. Alt+P still publishes.
