# Match Start (phase 3): done

Part of the [[Roadmap]]. Connects the [[Lobby]] to the [[City Map]]. Built and playtested on 2026-11-01.

## Status
- Playtested timeline: Lobby → **Deploy at 3.6s** → **Break at 14.7s** (helicopter plus parachute, about 11s) → **Wave 1 at 27.4s** (12s intermission) → cleared → wave 2 break. No errors.
- Code: `MatchService:_deploy`, `:_parachute` and `:_radio`. On the client, `CutsceneController` (helicopter, camera, letterbox) and `RadioController` (portrait panel). `MapService:GetDeployPoints()` uses the lobby helipad's `Pad` part and the centre of the arena spawns.
- **Bug fixed along the way:** the phase 1 wave-clear bonus called a helper before it was defined, which crashed the match loop after wave 1. Clearing a wave is now part of the playtest.

## Sequence
1. **Deploy (cutscene, about 8s).** A helicopter lifts off the lobby's Deploy Zone helipad, flies over the rooftops and hovers above the city square. The camera cuts between a lift-off shot, a chase shot and an overhead shot, with letterbox bars and a "drop zone" caption. The HUD is hidden.
2. **Drop.** The commander yells "Green light!" Players fall from the helicopter under parachutes and land around the fountain.
3. **Intermission (12s).** The commander warns that the noise will draw the horde. The HUD shows "Zombies inbound in Xs". With 3s left: "Movement on every street…"
4. **Wave 1.** The commander calls contact as the zombies appear.
5. **Every wave** gets a commander line when it starts and when it's cleared, and there's a sign-off if the squad is overrun.

## Commander radio
- A panel on the **left side of the screen** with a **portrait** of a 3D helmeted soldier that "talks" while the text types out. It shows his name, **SGT. VOSS · OVERWATCH**, and a blinking LIVE light.
- The lines live in `Shared/Config/Radio` (several variants per event, with `{wave}` placeholders) and are easy to rewrite.
- The server sends them over the `Radio` remote to run players only.

## Tunables
`GameConfig.Deploy`: `FlightTime`, `DropHeight`, `FallSpeed`. `GameConfig.Waves.FirstBreakTime` is the intermission.

## Later
- Sounds (rotor, radio static, parachute) once audio assets are picked.
- Players who respawn mid-run skip the cutscene and appear normally.
