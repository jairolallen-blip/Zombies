---
tags: [zone-shared]
cssclasses: [zone-shared]
---

# Remotes

> Made by `tools/vault-code-notes.js` from `src/shared/Remotes.luau` (76 lines). Don't edit it here: rerun the script.

Part of [[Shared modules]].

## What it does

```text
Remotes: every RemoteEvent in the game, by name. Server creates them; clients wait for them.
Usage:  local Remotes = require(Shared.Remotes);  Remotes.FireWeapon:FireServer(...)
To add a remote: add its name to NAMES and document the payload below.

Client -> Server
  FireWeapon(origin: Vector3, directions: {Vector3})   one shot (one direction per pellet)
  Reload()
  UseAbility(slot: "Ability" | "Ultimate", aimPosition: Vector3)
  BuyUpgrade(upgradeId: "Weapon" | "Vitality")
  SelectClass(classId: string)            lobby only
  SelectWeapon(weaponId: string)          lobby only
  UnlockItem(kind: "Class" | "Weapon", id: string)   spend Gems, lobby only
  ClaimAchievement(id: string)            pay a completed achievement's Gems once (DataService)
  SetPadOptions({Size?, Difficulty?, Map?})   pad host picks the mission (QueueService; GameConfig.Lobby)
  SkipCutscene()                        vote to skip the deploy ride / boss intro (players with CanSkip)
  QuickPlay()                           lobby: put me on the fullest pad that has room (QueueService)
  ClaimIndex(typeId: string)              lobby: claim the Gems for a discovered zombie (DataService)
  SetGift(userId: number?)                the next Gem pack I buy goes to this player (StoreService)
  TrackBounty(id: string)                 lobby: track one of today's bounties (DataService)
Server -> Client
  Notify(text: string, kind: "Info" | "Good" | "Danger")     toast message
  HitConfirm(hits: {{Position, Damage, Headshot, Killed}})   shooter-only hit feedback
  Effect(kind: string, data: table)                          visual effect; see EffectsController.Handlers
  RunResults({Wave, WavesCleared, Kills, Gems, NewBest})     end-of-run summary
  Radio(text: string, event: string)                         commander line (Config/Radio)
```

## Uses

- (none)

## Used by

- [[AbilityService]]
- [[AirdropService]]
- [[BossController]]
- [[CombatService]]
- [[CommonsService]]
- [[DailyService]]
- [[DataService]]
- [[EconomyService]]
- [[EffectsController]]
- [[GroundFxController]]
- [[HUDController]]
- [[InputController]]
- [[LobbyController]]
- [[LobbyMenu]]
- [[LobbyService]]
- [[MatchService]]
- [[NightmareController]]
- [[QueueService]]
- [[RadioController]]
- [[ShopController]]
- [[SkipController]]
- [[SoundController]]
- [[StoreController]]
- [[StoreService]]
- [[TouchController]]
- [[TutorialService]]
- [[WeaponController]]
- [[WelcomeController]]
- [[ZombieService]]

## Mentions

- [[Radio config]]
