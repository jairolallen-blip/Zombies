# Classes and Abilities

Back to [[Home]]. Data in [[Classes config]]; behaviour in [[AbilityService]]; keys in [[InputController]]; shop in [[ShopController]]; figures from [[ClassFigures]].

- **Classes:** Survivor (free), Scout 350, Medic 500, Engineer 750 and Bruiser 750 Gems. Bought and equipped at the Barracks in the [[Lobby]].
- **Ability on E:** a cooldown. **Ultimate on F:** charged by kills ([[EconomyService]] writes `UltCharge`).
- **Adding one:** add a handler to `AbilityService.Handlers`, then set `Type` on a class in the config. Existing types: Grenade, Airstrike, HealPulse, Revive, Turret, Stomp, Dash and Mark.
- **Scout ultimate, Hunter's Mark:** zombies within 70 studs glow red and take ×1.75 damage for 10s ([[ZombieService]] `:Mark`).
- **Engineer balance (2026-11-02):** the Sentry has a 42s cooldown through wave 4, then 22s. Sentries reach 30 studs (35 for the Nest), and the Nest charges at half speed. Optional class fields: `Ability.EarlyCooldown`, `EarlyWaves` and `Ultimate.ChargeMult`.
- **Grenade throw animation:** [[ThrowController]].

**Ready cues** (2026-11-03, UI/ReadyFx): when your ability or ultimate becomes ready, its slot pops, a ring bursts off it and a small READY · key tag rises off it. While it stays ready, its outline breathes and a light sweeps across it, and every 15s unused it nudges again. No sound and no mid-screen text, on purpose.
