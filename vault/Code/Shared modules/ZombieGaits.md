# ZombieGaits

> Made by `tools/vault-code-notes.js` from `src/shared/ZombieGaits.luau` (233 lines). Don't edit it here: rerun the script.

Part of [[Shared modules]].

## What it does

```text
ZombieGaits: keyframed walk cycles for the zombies (vault: Zombies.md). Pure data + sampling, no instances.
EffectsController plays them locally on each zombie's Motor6Ds (LeftArm, RightArm, LeftLeg, RightLeg,
Torso, Head), so a walk costs the server nothing.

A gait is one full stride, t = 0..1, looped. Each channel is a list of { t, value } keys in radians
(Bob in studs at Scale 1). Keys are smoothed through with a periodic cubic, then baked into a lookup
table, so sampling a gait is a table read however many zombies are on screen.
  LeftLeg, RightLeg    + forward
  LeftArm, RightArm    + up, 0 = the rig's rest (straight ahead; down on Crawler and Gaunt)
  ArmOut               arms out from the body (both, mirrored)
  BodyPitch            + back, - hunched forward       BodyRoll  + leans to its left
  BodyYaw              twist at the hips               Bob       up and down
  HeadPitch, HeadRoll  on top of the body, keyed late so the head follows through
Stride = studs walked per cycle at Scale 1, so feet don't skate (t advances with real ground speed).
  ZombieGaits.For(def)                         the gait for a Config/Zombies type
  ZombieGaits.Sample(gait, t, out)             fills out[channel] for t (any number; it wraps)
  ZombieGaits.Idle, ZombieGaits.Attack(u)      standing pose; the swipe curve for u = 0..1
```

## Uses

- (none)

## Used by

- [[EffectsController]]

## Mentions

- [[Zombies config]]

## Design notes

- [[Zombies]]
