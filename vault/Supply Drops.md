# Supply Drops

Mid-run crates you fight to reach (added 2026-11-02). Back to [[Home]]. Server [[AirdropService]], data [[Airdrops config]], client [[AirdropController]].

- **When:** from wave 2, each wave has a 65% chance of one crate parachuting onto a street away from the squad. Red smoke, a light pillar and a `SUPPLY DROP · Nm` marker show where it is.
- **The fight:** guards rise around it, and they count toward the wave (see [[Spawning]]).
- **Opening:** hold G (E is the class ability). Every living squad member within 30 studs gets a random reward.
- **Rewards:** Overcharge (+50% gun damage, 30s), Adrenaline (+35% speed and a full heal, 30s), Ult Surge (+50%), Cash Stash and Gem Cache (+25).
- **Buffs:** stored on the `Buff` and `BuffUntil` player attributes. [[CombatService]] asks `AirdropService:DamageMult`.
- **In the tutorial:** random drops are off; [[Tutorial]] step 5 drops one on purpose.
- **Gotcha:** prompts only show when their part is on screen, so face the crate.
- **Saved for later:** blackout and extraction events, for a possible Nightmare mode.
