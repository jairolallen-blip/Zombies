---
tags: [zone-world]
cssclasses: [zone-world]
samz-zone: world
---

# Match Start (phase 3): done

Part of the [[Roadmap]]. Connects the [[Lobby]] to the [[City Map]]. Built and playtested on 2026-11-01.

## Status
- Playtested timeline: Lobby → **Deploy at 3.6s** → **Break at 14.7s** (helicopter plus parachute, about 11s) → **Wave 1 at 27.4s** (12s intermission) → cleared → wave 2 break. No errors.
- Code: `MatchService:_deploy`, `:_parachute` and `:_radio`. On the client, `CutsceneController` (helicopter, camera, letterbox) and `RadioController` (portrait panel). `MapService:GetDeployPoints()` uses Flight Line pad 1 and the centre of the arena spawns. Since 2026-11-02 a run is started by `MatchService:RunMatch` from a squad's pad: on a live server it plays in the squad's own reserved server (see [[Lobby]]).
- **Bug fixed along the way:** the phase 1 wave-clear bonus called a helper before it was defined, which crashed the match loop after wave 1. Clearing a wave is now part of the playtest.

## Sequence
1. **Deploy (first-person cutscene, 18s, revamped 2026-11-02).** You ride in the open cabin of the helicopter, with letterbox bars.
   - **The ride:** it fades in already **over the ocean** north of the city, so the city feels far from the lobby. It skims the waves, then climbs over the coast and the rooftops, and slows to a hover above the square.
   - **Where you look:** out the door at the sea, forward through the windshield at the skyline (the "OPERATION LAST LIGHT / DROP ZONE" card), and leaning out the door at the streets.
   - **The pilot:** helmet, shades, headset and tactical vest. He turns round, gives a thumbs-up and says "Good luck down there."
   - **The jump:** you step out of the door, a quick fade, then the fall, all in first person (2026-11-02). It starts with about 0.5s of freefall, arms out, looking down at the square. Then the ram-air canopy (7 striped cells plus lines) snaps open with a jolt. You look up at it and sway down with your arms up on the toggles (full-length arms that fill the screen edges). Control comes back the moment you touch down, because the server clears your `Deploying` on landing. Your own body and gun are hidden locally, and other players see your canopy.
   - **No clipping:** the server builds the path (`MapService:GetDeployFlight`) by raycasting every roof under the rotor span, then keeps a slope-limited clearance above them. A check of a 34×10×34 box along the whole path found zero overlaps.
   - **Sound + effects:** cabin wind (louder at the door), sea wash and rotor-wash spray while low over the waves, faint radio chatter, an intercom squelch before the pilot, wind streaks past the door, a whoosh, shake and FOV kick on the jump, the chute opening, and falling wind until landing.
   - **The sea** is terrain water baked all round the map. The old `Baseplate` is sunk under it and made invisible.
2. **Drop.** The commander yells "Green light!" Players fall from the helicopter under parachutes and land around the fountain.
   - **First-person fall (fixed 2026-11-02):** the camera faces the way the body faces, because the server builds the canopy off the root; facing the door showed it turned sideways. Only thin forearms are drawn, since the whole arm filled the screen sides.
3. **Intermission (12s).** The commander warns that the noise will draw the horde. The HUD shows "Zombies inbound in Xs". With 3s left: "Movement on every street…"
4. **Wave 1.** The commander calls contact as the zombies appear.
5. **Every wave** gets a commander line when it starts and when it's cleared, and there's a sign-off if the squad is overrun.

## Commander radio
- A panel on the **left side of the screen** with a **portrait** of a 3D helmeted soldier that "talks" while the text types out. It shows his name, **SGT. VOSS · OVERWATCH**, and a blinking LIVE light.
- The lines live in `Shared/Config/Radio` (several variants per event, with `{wave}` placeholders) and are easy to rewrite.
- The server sends them over the `Radio` remote to run players only.
- The panel is 420 × 100 and scales with the screen. It hides during the boss intro, but stays on during the drop-in, where it carries the Deploy and Drop lines.

## Tunables
`GameConfig.Deploy`: `FlightTime`, `DropHeight` (110), `FreefallTime` (0.5), `FallSpeed` (22), `OceanStart`, `FinalApproach`, `SeaAltitude`, `CruiseHeight`, `Clearance`, `MaxClimbPerSample`. Camera shots are the `CAM_KEYS` table in `CutsceneController`. `GameConfig.Waves.FirstBreakTime` is the intermission.

## Later
- A real voice line for the pilot (it's a subtitle plus a squelch for now).
- Players who respawn mid-run skip the cutscene and appear normally.

## Skipping (2026-11-02)
Players who have finished a run can hold Space (gamepad X, or the on-screen button) to vote to skip the deploy ride and the boss intro ([[SkipController]]). It skips once everyone in the run has voted, so a first-timer in the squad always sees it in full. A skipped ride jumps to the door, then the jump and parachute play as usual.

## Code
[[MatchService]] runs the deploy, [[CutsceneController]] plays it, and [[RadioController]] shows [[Radio config]] lines. Sound: [[SoundController]] and [[Sounds config]].

Back to [[Home]].

**Late-loading squad members** (2026-11-04): on a live match server the drop starts once every profile has loaded, which can be before a slow client finishes loading. `CutsceneController:Start` checks for a ride already under way and joins it at the right moment, so nobody hangs above the map waiting for the drop. The ride is timed on each player's own clock, since a client's server clock can be seconds off just after joining a server; the console shows `[Cutscene] ride starts (...)` on every ride.

**Outbreak place:** Outbreak runs in its own place (87622086122699) with its own copy of the scripts. Fixes to shared code, like this one, have to be copied there too, and that place is published on its own.
