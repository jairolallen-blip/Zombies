# Playing Roblox Games

How an AI agent can play and test any Roblox game. For Survive a Million Zombies itself, see [[Playing Million Zombies]]. Back to [[Home]].

Everything here was tried on Windows on 2026-11-05 unless it says otherwise.

## Pick the right way in

| What you need to check | Use |
|---|---|
| Game logic, numbers, errors, spawning | Studio Play with `execute_luau` |
| Poses, cameras, single moments | Studio Play with `screen_capture` |
| What a real player sees, joining, teleports, real servers | The live client with `tools/roblox-input.ps1` |
| How motion feels | Record it (OBS), or ask a person |

Test in Studio first. It's faster and you can read any value. Go to the live client last, to confirm.

## Roblox Studio

- Call `list_roblox_studios` first. Each open window has an id, and the id changes when Studio restarts.
- `start_stop_play` starts and stops Play. In Play the data models are `Client` and `Server`, and `Edit` isn't available until you stop.
- Keep each `execute_luau` call under about 60 seconds, or the connection can drop. Spawn long work and poll for it.
- Edits made during Play are lost, so stop Play before you change scripts.
- A `require` from `execute_luau` gets a fresh copy of the module, not the one the game is running.
- `user_mouse_input` clicks by `instance_path`, not by screen position.
- `execute_luau` can't make web requests now, including to localhost. Push changes as text inside the code, patch with a plain find, then compare the byte size with the file on disk.
- The MCP resets the camera after each command. To hold a camera, bind it with `BindToRenderStep` from `execute_luau`.
- Turn off post effects before judging shots: `DepthOfFieldEffect`, `BloomEffect`, `ColorCorrectionEffect` and `SunRaysEffect`. Game code may turn them back on, so switch them off every frame.

### Testing methods that worked

- **Frozen pose sheet:** clone models into a row in the sky, with the root anchored and the limbs not, then set each `Motor6D.Transform` by hand. One screenshot shows a whole animation cycle.
- **Real code at a frozen moment:** if an animation reads a time attribute, put a clone where the real loop runs and rewrite that attribute every frame. You see the shipped code path at an exact moment.
- **Measure before trusting your eyes:** perspective can make a correct pose look broken. Read the part's `LookVector` and work out the angle.
- **On and off test:** add a temporary attribute check that skips a system, then alternate it in one Play session and compare `Stats` values. Remove the check afterwards and confirm the file size.
- **Where the frame time goes:** read `Stats.FrameTime`, `RenderCPUFrameTime`, `RenderGPUFrameTime`, `PhysicsStepTime` and `MovingPrimitivesCount`. Check `GetNetworkOwner()` too, because client-owned parts move physics cost to the player.
- **Comparing two places:** hash every script in each Studio window and compare the lists.

## The live Roblox client

- Join with `Start-Process "roblox://placeId=<id>"`. The player opens already signed in.
- Drive it with `tools/roblox-input.ps1`: `click`, `key`, `shot` and `sheet`. Studio's input tools can't reach this client.
- Roblox ignores a cursor that just appears on a button. Real moves come first, then a pause, then the click. The tool does this.
- A click may need a moment. Quick Play took a few seconds to show a result, so wait before clicking again.
- Read the log for script output and errors, in `%LOCALAPPDATA%\Roblox\logs`. The newest file with `Player` in its name is the current one.
  - `[FLog::CreatorOutput]` lines are script output.
  - `! Joining game` marks each server change, which is the easiest way to time captures.
  - `Connection` and `LoadingScript` stacks at a teleport come from Roblox itself, not the game.
- A click can land on two things when one screen closes and another opens under it. Take a screenshot before and after.
- Tool calls are slow compared with the game. Put a whole sequence in one script, or you'll miss the moment.
- The live client has no `execute_luau`, so you can't read game values. Use the screen and the log.

### Be careful

- Never click a Robux price button. Check screenshots before any click near one. Backspace or a close button is safer.
- Other people may be in the server, so leave them undisturbed.
- Check whether the owner is playing before you send input. If the game is moving in ways you didn't cause, stop and leave the controls alone.
- Don't confuse the owner's progress with shared data. Ask the owner what may change, and treat anything other players see as off limits.

## Publishing

- Alt+P in a Studio window publishes it, even when the File menu is missing. `tools/studio-key.ps1` sends it.
- Wait about 4 seconds for "Published. Eligible players can play now." The message appears on the monitor holding that window.
- `GetProductInfo().Updated` lags by minutes, so it doesn't prove a publish.
- Running servers keep the old version until they empty or are restarted.
- In Team Create, a publish includes everything in the place at that moment, including other people's edits.

## Learning a game from video

The owner puts recordings in `D:CLAUDE WORKVideos`.

1. Read the length with ffprobe.
2. Make whole-run sheets: `ffmpeg -i video.mp4 -vf "fps=1/5,scale=640:-1,tile=4x4" -q:v 3 sheet-%02d.jpg`. Each sheet covers 80 seconds.
3. The HUD tells most of the story, so read wave, HP, Cash and ammo across frames.
4. Zoom in on a moment with `-ss <seconds> -t 2 -vf "fps=10,scale=640:-1,tile=4x4"`.
5. Check what you find against the code. A 7:50 video corrected a wrong note about healing this way.

Frames show what happened, but not why. Five seconds between frames hides fast movement. Use Earshot for the audio, and ask the player about their choices.

## General game controls

These hold in most Roblox games unless a game rebinds them.

| Input | Action |
|---|---|
| W A S D | Move |
| Space | Jump |
| Mouse | Look, with the right button held in third person |
| Mouse wheel, I, O | Zoom |
| E | Usual key for proximity prompts |
| Escape | Roblox menu |
| / | Chat |
| F9 | Developer console |
| Shift+F5 | Performance stats |

Windows virtual keys for `-Key`: 08 Backspace, 0D Enter, 1B Escape, 20 Space, 30-39 number keys, 41-5A letters.
