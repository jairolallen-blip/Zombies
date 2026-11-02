# Match Start (phase 3): done

Part of the [[Roadmap]]. Connects the [[Lobby]] to the [[City Map]]. Built and playtested on 2026-11-01.

## Status
- Playtested timeline: Lobby → **Deploy at 3.6s** → **Break at 14.7s** (helicopter plus parachute, about 11s) → **Wave 1 at 27.4s** (12s intermission) → cleared → wave 2 break. No errors.
- Code: `MatchService:_deploy`, `:_parachute` and `:_radio`. On the client, `CutsceneController` (helicopter, camera, letterbox) and `RadioController` (portrait panel). `MapService:GetDeployPoints()` uses the lobby helipad's `Pad` part and the centre of the arena spawns.
- **Bug fixed along the way:** the phase 1 wave-clear bonus called a helper before it was defined, which crashed the match loop after wave 1. Clearing a wave is now part of the playtest.

## Sequence
1. **Deploy (first-person cutscene, 18s, revamped 2026-11-02).** You ride in the open cabin of the helicopter, with letterbox bars.
   - **The ride:** it fades in already **over the ocean** north of the city, so the city feels far from the lobby. It skims the waves, then climbs over the coast and the rooftops, and slows to a hover above the square.
   - **Where you look:** out the door at the sea, forward through the windshield at the skyline (the "OPERATION LAST LIGHT / DROP ZONE" card), and leaning out the door at the streets.
   - **The pilot:** helmet, shades, headset and tactical vest. He turns round, gives a thumbs-up and says "Good luck down there."
   - **The jump:** you step out of the door, a quick fade, then the parachute, all in first person.
   - **No clipping:** the server builds the path (`MapService:GetDeployFlight`) by raycasting every roof under the rotor span, then keeps a slope-limited clearance above them. A check of a 34×10×34 box along the whole path found zero overlaps.
   - **Sound + effects:** cabin wind (louder at the door), sea wash and rotor-wash spray while low over the waves, faint radio chatter, an intercom squelch before the pilot, wind streaks past the door, a whoosh, shake and FOV kick on the jump, the chute opening, and falling wind until landing.
   - **The sea** is terrain water baked all round the map. The old `Baseplate` is sunk under it and made invisible.
2. **Drop.** The commander yells "Green light!" Players fall from the helicopter under parachutes and land around the fountain.
3. **Intermission (12s).** The commander warns that the noise will draw the horde. The HUD shows "Zombies inbound in Xs". With 3s left: "Movement on every street…"
4. **Wave 1.** The commander calls contact as the zombies appear.
5. **Every wave** gets a commander line when it starts and when it's cleared, and there's a sign-off if the squad is overrun.

## Commander radio
- A panel on the **left side of the screen** with a **portrait** of a 3D helmeted soldier that "talks" while the text types out. It shows his name, **SGT. VOSS · OVERWATCH**, and a blinking LIVE light.
- The lines live in `Shared/Config/Radio` (several variants per event, with `{wave}` placeholders) and are easy to rewrite.
- The server sends them over the `Radio` remote to run players only.

## Tunables
`GameConfig.Deploy`: `FlightTime`, `DropHeight`, `FallSpeed`, `OceanStart`, `FinalApproach`, `SeaAltitude`, `CruiseHeight`, `Clearance`, `MaxClimbPerSample`. Camera shots are the `CAM_KEYS` table in `CutsceneController`. `GameConfig.Waves.FirstBreakTime` is the intermission.

## Later
- A real voice line for the pilot (it's a subtitle plus a squelch for now).
- Players who respawn mid-run skip the cutscene and appear normally.
