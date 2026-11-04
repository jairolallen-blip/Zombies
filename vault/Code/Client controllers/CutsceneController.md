# CutsceneController

> Made by `tools/vault-code-notes.js` from `src/client/Controllers/CutsceneController.luau` (550 lines). Don't edit it here: rerun the script.

Part of [[Client controllers]].

## What it does

```text
CutsceneController: the first-person drop-in at the start of a run (vault: Match Start.md).
While the player's "Deploying" attribute is true the server holds them above the arena; this
plays a client-side helicopter ride along GameState.DeployPath (MapService:GetDeployFlight: from
over the ocean, low over the waves, up over the rooftops, to a hover above the square), timed by
DeployStart/DeployDuration (server clock). You sit in the open cabin and look around (CAM_KEYS):
out the door at the sea, forward through the windshield at the skyline, down at the streets,
then at the pilot, who turns and gives a thumbs-up ("Good luck down there."), and out the door
as you jump. Then the camera goes first person on the character, who parachutes down
(MatchService:_parachute) until CameraController takes over on landing.
Sound + effects (ids in Shared/Config/Sounds, played through SoundController): cabin wind that
swells at the door, sea wash and rotor-wash spray while skimming the waves, faint radio chatter,
an intercom squelch before the pilot speaks, wind streaks past the door, a whoosh, shake and FOV
kick on the jump, then the chute snapping open and falling wind until you land.
The fall (dropView) stays scripted first person: freefall, the canopy opening with a jolt, a look
up at it, then a swaying descent holding the toggles, with your own body and gun hidden locally.
```

## Uses

- [[GameConfig]]
- [[GameState]]
- [[SoundController]]
- [[Sounds config]]
- [[UIKit]]

## Used by

- (none)

## Design notes

- [[Match Start]]
