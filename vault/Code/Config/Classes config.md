# Classes config

> Made by `tools/vault-code-notes.js` from `src/shared/Config/Classes.luau` (113 lines). Don't edit it here: rerun the script.

Part of [[Config]].

## What it does

```text
Classes: playable roles, unlocked with Gems and chosen in the lobby.
PURE DATA. Each class has one cooldown Ability [E] and one charge-based Ultimate [F].

Ability/Ultimate.Type must match a handler in ServerScriptService.Server.Services.AbilityService
(Handlers table). Existing types and their Params:
  Grenade   { Radius, Damage, Range }                     thrown explosive at aim point
  Airstrike { Count, Radius, Damage, Spread, Interval, Delay, Range }  explosions around aim point
  HealPulse { Radius, Heal }                              heals nearby teammates (and self)
  Revive    { }                                           respawns dead teammates + full heal
  Turret    { Count, Duration, Damage, FireRate, Range }  auto-firing sentries near caster
  Stomp     { Radius, Damage, Knockback, InvulnTime? }    damage + knockback around caster
  Dash      { Speed, Duration }                           burst of movement (client-applied)
  Mark      { Radius, Duration, Mult }                    zombies near the caster glow red and take
                                                          Mult x damage from everyone for Duration

Class fields: DisplayName, Description, GemCost (0 = default), Order, Color,
  HealthBonus (added max HP), SpeedBonus (added WalkSpeed), DamageTakenMult (1 = normal)
Optional: Ability.EarlyCooldown + EarlyWaves (longer cooldown up to that wave),
  Ultimate.ChargeMult (ult charge gain multiplier; 0.5 = needs twice the kills)
```

## Uses

- (none)

## Used by

- [[AbilityService]]
- [[AirdropService]]
- [[ClassFigures]]
- [[CombatService]]
- [[DataService]]
- [[EconomyService]]
- [[HUDController]]
- [[LobbyController]]
- [[LobbyMenu]]
- [[LobbyService]]
- [[OurLobby]]
- [[ShopController]]
