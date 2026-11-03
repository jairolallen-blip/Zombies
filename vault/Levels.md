# Levels and XP

Account levels (2026-11-03, the owner's idea). Back to [[Home]]. Numbers in [[Levels config]]; XP is paid by [[MatchService]] and stored by [[DataService]]; the bar is drawn by [[WelcomeController]].

## How you earn XP
Every run pays XP for how it went, win or lose:
- **1 per kill**
- **20 per wave cleared**
- **+150 for a victory** (not the tutorial)
- **Nightmare doubles the whole run** (win or lose, unlike its Gems)

A good Normal win (about 200 kills) is about 550 XP; the same in Nightmare is about 1,100.

## Levels
Level 1 to 2 needs 100 XP, and every level needs 40 more than the one before (level 12 needs 540). The profile keeps only the total (`XP`); the level comes from it.

**Ranks** (our own titles, from the Port Harrow lore): Stray (1), Scavenger (3), Lookout (6), Survivor (10), Salvager (15), Warden (20), Veteran (30), Harbor Ghost (45), Legend of Port Harrow (60).

**Old saves** start where their history puts them: kills, waves cleared and wins are counted with the same rates (the owner's account came out at level 12 with 3,697 XP).

## The level header (welcome screen)
Under the headline: **LEVEL n** with the rank title, and a gold bar with the XP inside it. On the run report it also shows the run's **+XP** in big gold letters and chips breaking it down (KILLS +n, WAVES +n, VICTORY +150, NIGHTMARE x2), then fills the bar from where you were before the run to now. Each level gained flashes the bar white, pops the level number and floats a **LEVEL UP!** off the bar. The wave tile gets a gold **NEW BEST** tag on a new best wave.

The owner's reference was a results screen from another game; we took the ideas (big level header with +XP, a breakdown, NEW BEST tags) and kept our own look.

## Not done (ideas)
- Rewards for levelling up (Gems, cosmetics, titles to show off in the lobby).
- A level tag over heads in the lobby, next to BEST WAVE.
