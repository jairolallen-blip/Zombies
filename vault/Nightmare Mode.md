# Nightmare Mode

The hard mode (started 2026-11-02, the owner's design). Back to [[Home]]. Tunables in [[Nightmare config]]; the pad is built by [[FlightLine]]; the run is played by [[MatchService]].

## The idea
A second mode for players who've beaten the normal game: tougher, darker, and scary. You only get paid if you survive, so every run feels like it matters. It also grows the enemy index with a new row of zombies.

## Unlock and queue
- Unlocks after **3 normal wins** (Normal is 10 waves, so 3 wins means real experience).
- Its own **caged red pad** in the middle of the Flight Line, behind a chained gate with a padlock. Locked players see the gate shut and a sign with their own progress ("🔒 NIGHTMARE · 2/3 WINS"), so the goal is always in view. Once unlocked, the chains are gone for them and the sign reads "NIGHTMARE · OPEN" or the squad count.
- The normal pads no longer have a difficulty choice; the pad you stand on decides.
- Everyone in the squad must have unlocked it. Quick Play never puts you on it.

## The run (step 1, done)
- 10 waves like Normal, but 30% more zombies, 50% more zombie and Titan health, and zombies hit 35% harder.
- The helicopter ride in is a red dusk; once you land, night falls over 5 seconds: midnight with a red haze, flashlights on.
- A quiet eerie music loop (APM "The Fear Within") under the whole run; it fades out while the boss is up so the boss music plays alone.
- A heartbeat that gets louder and faster the more zombies are close.
- About a third of the street lamps are dead and another third flicker (the same ones for every player).
- Squads: each extra player adds only 15% more zombies (Normal adds 60%), because Nightmare already has 30% more.
- **Commander:** Sgt. Voss has lost contact with every other team and stops pretending there's a plan. The radio breaks into static. At the boss the signal dies; he only comes back if the Titan falls ("I'd stopped writing your names down...").
- **Rewards:** win = the normal Gems x3. Die = nothing ("NO GEMS THIS TIME"). Kills still count toward the enemy index even on a loss, so a failed run still teaches you something.

## Next steps
1. ~~Mode, unlock, queue, rewards, harder numbers, radio, dark weather~~ (done).
2. ~~**Mood:** red dusk ride, background music, heartbeat as the horde closes in, dead and flickering street lamps~~ (done 2026-11-02).
3. ~~**Twisted counterparts**~~ (done 2026-11-02; models from the owner's reference pictures: a gaunt pale zombie with long clawed arms, a rotting face with an open mouth, a flayed muscle-and-bone body, a blocky zombie with ribs and wounds, and one with an exposed bone). Each has a new look and behaviour, in its own **NIGHTMARE row** under the normal index row:
   - Shambler -> **Rotter:** kept simple (it's the common zombie): tougher (80 HP), faster, and nastier-looking: a rotting face with sunken red-rimmed eyes, a rotted-out nose, the jaw hanging open on yellow teeth, a cheek rotted through, ribs through the shirt, a bone through one arm. Not the "only moves when you look away" idea (too much for the common type).
   - Runner -> **Skitter:** flayed red muscle with a bone skull face and ribcage, on all fours; fast (21), comes in packs of three, lunges. (Not quieter than the others yet: zombie sounds live in AnimatedSL's SoundController.)
   - Brute -> **Husk:** bone armour (spiked shoulder plates, a split breastplate, horns, tusks) over a glowing seam; when it dies it splits into two crawling halves that keep fighting.
   - Bloater -> **Wailer:** tall, pale and gaunt, arms to the knees with long talons, blind white eyes. Its throat sac swells and it screams: your sight blurs and every zombie nearby rushes you.
   - No Mimic: every zombie must die to end a wave, so a disguised one only stalls.
4. **New boss** ("The Warden" idea): moves between light sources; the arena's lights die one by one.

## Code
Data in [[Nightmare config]], pad and gate in [[FlightLine]], gate and sign on the client in [[NightmareController]], boarding in [[QueueService]], the run in [[MatchService]], damage in [[CombatService]], weather in [[Conditions config]], lines in [[Radio config]].
