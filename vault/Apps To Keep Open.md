---
tags: [zone-working]
cssclasses: [zone-working]
samz-zone: working
---

# Apps To Keep Open

The apps Claude wants running, and why. Back to [[Home]].

The owner has said to ask for anything that makes the work easier, including opening an app that got closed. Run `tools/app-check.ps1` at the start of work that needs these, then ask for what's missing as one short list. Ask, and don't launch a second copy: OBS can look closed when it's only in the tray, and a second copy starts with a crash warning.

## Always open

| App | Why | If it's closed |
|---|---|---|
| Roblox Studio, main place | All script edits, Play tests and publishing | Claude can't touch the game |
| OBS Studio | Records tests so fast action can be read frame by frame | Animations and cutscenes can't be checked in motion |
| Obsidian | Shows the vault and its graph to the owner | Vault files still work, but the owner can't browse them |

## Open when needed

| App | When |
|---|---|
| Roblox Studio, Outbreak place | Whenever shared code changes, since it holds its own copy of the scripts |
| Roblox player | Live checks. Claude can open it |

## Setup that helps

- Keep the main Studio window on the main monitor. OBS records that monitor only, and the test screenshots read it too.
- Outbreak can stay on the second monitor.
- Keep OBS at 30 fps. At 60 fps it skipped 92% of frames on this PC.
- OBS WebSocket stays on, port 4455 with no password.
- OBS saves into `D:\CLAUDE WORK\Videos`. Claude moves its own test clips out, so that folder holds only the owner's videos.
- Studio's "Restart to update" may bring back the missing menu bar on the main window. Do it between tasks.

## Seeing tests while they run

Claude can't watch a live stream. The closest thing is a short loop: start the action, record a few seconds with `tools/obs-record.js`, then read every frame with `tools/video-look.js strip`. See [[Playing Roblox Games]].
