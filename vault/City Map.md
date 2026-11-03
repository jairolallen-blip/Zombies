# City Map (phase 2): done

Part of the [[Roadmap]]. Our arena, centred at **x = 1000** (next to the [[Lobby]]). Built and playtested on 2026-11-01.

## Status
- **Built** by `Server/Map/OurCity`, which reads the tile plan below and bakes it into `Workspace.OurMap.Arena`: about 3,600 parts and 36 lights. To change the layout, edit `LAYOUT` and rebuild (instructions are in the module header).
- **Playtested:** `NavCheck` found a route from **all 12** zombie spawns to the square. In wave 1, all 10 zombies reached the player within about 9 seconds from across the city, with none stuck.
- **Spawn clearance:** the builder skips any car, tree, stall or barrier within 13 studs of a zombie spawn, so pads never end up under props.
- **Atmosphere:** a warm, hazy sunset (`GameConfig.OurMap.Atmosphere`) is applied at server start by `MapService:ApplyAtmosphere()`. Edit mode keeps the original map's lighting.
- **Zombie nav** now covers whichever arena is active (`MapService:GetNavBounds()`).

## Ideas for later passes
- More detail at street level: fire escapes, trash, posters, broken traffic lights, more overgrowth.
- Interiors: one enterable shop on the square, as in the shop reference.
- Swap procedural props for real models (cars, lamps) once there's a model pass.

## Look (from MAP REFERENCES)
A warm, hazy, sepia sunset. Brick and concrete buildings with shuttered storefronts, street lamps (the sagging power lines between them were removed on 2026-11-02: from above they read as gridlines over the map), abandoned cars and taxis, jersey barriers, a broken overpass, and overgrowth (grass, trees, vines).

## Layout rules
- **One big open city square** in the middle for mowing down zombies.
- **Every side area has at least 2 exits.** Each one loops back to the square through a street or the ring road, so there are **no dead ends** and the map never feels like a maze.
- **The floor is perfectly flat** (zombie navigation needs it). Sidewalks and markings are paint, not steps.
- **Props are chunky and convex.** Nothing narrower than 12 studs is walkable, so the horde doesn't jam.

## Tile plan
The map is a 23 × 23 grid of 12-stud tiles (276 studs across). North is up.
```
#######################
#.....................#    # building       . road
#.....................#    S city square    P park
#..####PPP...###A###..#    A alley          L parking lot
#..####PPP...###A###..#    M market
#..PPPPPPP...AAAAAAA..#
#..PPPPPPP...###A###..#
#..PP##SSSSSSSSSA###..#
#..PP##SSSSSSSSSA###..#
#..PP##SSSSSSSSSA###..#
#......SSSSSSSSS......#
#......SSSSSSSSS......#
#......SSSSSSSSS......#
#..##MMSSSSSSSSSLL##..#
#..##MMSSSSSSSSSLL##..#
#..##MMSSSSSSSSSLL##..#
#..##MMMMM...##LLLLL..#
#..##MMMMM...##LLLLL..#
#..MMMM###...##LLLLL..#
#..MMMM###...##LLLLL..#
#.....................#
#.....................#
#######################
```
- **City square** (108 × 108): a dry fountain in the centre, players spawn around it, and there's light cover near the edges.
- **Main streets** (N/S/E/W, 36 wide) run from the square to the **ring road**, which loops around the whole city.
- **NW park:** overgrown, with trees. It touches the ring road, the north street, the west street and the square.
- **NE alleys:** a grid of narrow alleys between brick buildings that connect the ring, the north street, the east street and the square.
- **SE parking lot:** wrecked cars as cover. It opens onto the square, the ring and the south-east.
- **SW market:** stalls and crates, connecting the west street, the south street and the ring.
- **Landmark:** a broken overpass across the north street.

## Spawns (for now)
- `PlayerSpawn` × 8 around the fountain.
- `ZombieSpawn` × 12 on the ring road and in the side areas, away from the square. These are replaced by random spawns with red warning circles in [[Spawning]] (phase 6).

## Run conditions (2026-11-02)
Each run rolls its weather ([[Conditions config]], [[ConditionsController]]): Sunset (most often), Heavy Fog, Nightfall (every player gets a flashlight) or Storm (rain). It makes one map feel like several until a second map exists. The tutorial is always Sunset.

## Code
[[OurCity]] builds it, [[MapService]] reads its markers and sets the atmosphere, and [[NavGrid]] maps it for the zombies.

Back to [[Home]].
