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
- Fewer but tougher zombies than before: 16 on wave 1 and 54 on wave 10 solo, at most 45 alive (2026-11-03; it got too crowded late).
- Squads: each extra player adds only 15% more zombies (Normal adds 60%), because Nightmare already has 30% more.
- **Commander:** Sgt. Voss has lost contact with every other team and stops pretending there's a plan. The radio breaks into static. At the boss the signal dies; he only comes back if the Titan falls ("I'd stopped writing your names down...").
- **Rewards:** win = the normal Gems x3. Die = nothing ("NO GEMS THIS TIME"). Kills still count toward the enemy index even on a loss, so a failed run still teaches you something.

## Next steps
1. ~~Mode, unlock, queue, rewards, harder numbers, radio, dark weather~~ (done).
2. ~~**Mood:** red dusk ride, background music, heartbeat as the horde closes in, dead and flickering street lamps~~ (done 2026-11-02).
3. ~~**Twisted counterparts**~~ (done 2026-11-02; models from the owner's reference pictures: a gaunt pale zombie with long clawed arms, a rotting face with an open mouth, a flayed muscle-and-bone body, a blocky zombie with ribs and wounds, and one with an exposed bone). Each has a new look and behaviour, in its own **NIGHTMARE row** under the normal index row:
   - Shambler -> **Rotter:** kept simple (it's the common zombie): tougher (80 HP), faster, and nastier-looking: a rotting face with sunken red-rimmed eyes, a rotted-out nose, the jaw hanging open on yellow teeth, a cheek rotted through, ribs through the shirt, a bone through one arm. Not the "only moves when you look away" idea (too much for the common type).
   - Runner -> **Skitter:** flayed red muscle with a bone skull face and ribcage, on all fours. **The ambusher** (redesigned 2026-11-03: fast Runners were already hard to hit, so it isn't a faster one): it crawls slowly and is easy to shoot in the open, but from a distance it burrows into the street, out of reach, and bursts up behind you through a red circle. Comes in pairs. The danger is awareness: check your back.
   - Brute -> **Husk:** bone armour (spiked shoulder plates, a split breastplate, horns, tusks) over a glowing seam; when it dies it splits into two crawling halves that keep fighting.
   - Bloater -> **Wailer:** tall, pale and gaunt, arms to the knees with long talons, blind white eyes. Its throat sac swells, it leans back with its arms thrown up and screams: a pale shockwave rolls out, your sight blurs, your ears ring, you're rooted for a moment (0.4s), the Wailer that got you glows through walls for a few seconds so you know what to shoot, and every zombie nearby rushes you. It only roars from close (20 studs, reaching 24) and never spawns within 50 studs of a player, so it can't rise and stun you at once (2026-11-03).
   - No Mimic: every zombie must die to end a wave, so a disguised one only stalls.
4. ~~**New boss**~~ (done 2026-11-03): **The Bloom Mother** (the owner picked a spore boss over the "Warden" idea). See below.

## The Bloom Mother (Nightmare boss)
Where the Bloom began: a huge swollen spore-mother (scale 3.6, the Bloated build) with a spore sac on its back studded with glowing green pods, a belly split open down the middle into a fanged maw with a glowing core, dark eye pits with a cluster of small glowing eyes over the brow, a hanging jaw with tendrils, shelf fungus on its shoulders, spores drifting off it and a sick green glow. Only Nightmare runs get it; Normal keeps the Grave Titan.
- **Health:** 16,000 x1.5 Nightmare = 24,000 solo (+60% per extra player). Slow (speed 7).
- **Entrance (8s):** the sky turns sick green, the street tears open and a giant pod pushes up out of it, pulsing faster like a heartbeat, then splits open (shell flung out, a spore burst) as it rises out; the roar, then "THE BLOOM MOTHER · NIGHTMARE · KILL IT AND IT ALL DIES". The green sky stays for the fight.
- **Spore volley** (every 4.5s, within 90 studs): it rears back with a shriek and lobs 3 glowing pods (5 in phase 2) onto red circles: one on each player (led a little toward where you're running), the rest scattered. Each hits for 18 (x1.35) and leaves a poison cloud for 4s that hurts every half second. Keep moving.
- **Bloom Burst** (first after 14s, then about every 25s, only with someone within 30 studs): it roots itself and swells inside a pulsing glow, a red ring marks the blast, the danger fills in from the middle, a 3-2-1 countdown hangs over it and **GET CLEAR!** flashes on your screen while you're inside. Then it blows: 75 (x1.35, about 101: lethal without Vitality) and you're thrown out. The point is to run.
- **Phase 2 at 50%:** faster, every attack comes sooner, and 6 Rotters climb out around it.
- **Death scene (8s):** everything it grew dies with it (the whole horde drops at once), the camera circles the body as it swells and shudders, glowing brighter, then it bursts into a column of spores that drift up into the sky while the green clears and the clock runs from midnight to dawn: "THE BLOOM MOTHER IS DEAD · AND EVERYTHING IT GREW DIES WITH IT". Then the Victory. (Before this the sky just snapped back to sunset when the run ended.)
- Index: 400 Gems, in the NIGHTMARE row.

## Code
Boss: data in [[Zombies config]] (BloomMother), attacks in [[ZombieService]] (_spores, _bloomBurst, Collapse), intro and death scene in [[MatchService]] (_bossIntro, _bossDeath) and [[BossController]], model in [[ZombieModels]] (horror "Bloom"). Data in [[Nightmare config]], pad and gate in [[FlightLine]], gate and sign on the client in [[NightmareController]], boarding in [[QueueService]], the run in [[MatchService]], damage in [[CombatService]], weather in [[Conditions config]], lines in [[Radio config]].
