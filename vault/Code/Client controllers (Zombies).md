---
tags: [zone-client]
cssclasses: [zone-client]
---

# Client controllers (Zombies)

> Made by `tools/vault-code-notes.js`. Don't edit it here: rerun the script.

Client systems. Client Main loads them and calls Init, then Start.

Back to [[Zombies Home]].

- [[AirdropController (Zombies)]]: client side of supply drops (Server/Services/AirdropService).
- [[BossController (Zombies)]]: the client side of the final boss (vault: Waves and Boss.md, Nightmare Mode.md).
- [[CameraController (Zombies)]]: FIRST-PERSON run camera + the single source of truth for AIMING.
- [[Client Main (Zombies)]]: Client entry point. Requires every ModuleScript in Controllers, then calls
- [[ConditionsController (Zombies)]]: the client side of a run's weather (Shared/Config/Conditions, GameState Condition).
- [[CutsceneController (Zombies)]]: the first-person drop-in at the start of a run (vault: Match Start.md).
- [[EffectsController (Zombies)]]: all client-side visuals. Parts go in Workspace.ClientEffects (non-queryable).
- [[GroundFxController (Zombies)]]: disturbed earth where zombies break through the street (local only, nothing replicates).
- [[HUDController (Zombies)]]: the in-run HUD. Visible only while the player attribute InRun is true.
- [[InputController (Zombies)]]: keyboard actions other than shooting — abilities and in-run upgrades.
- [[JoinCover (Zombies)]]: covers the screen from the first frame of a join, so nobody glimpses the world (their
- [[LobbyAudioController (Zombies)]]: the safehouse's sound (ids and volumes in Shared/Config/Sounds).
- [[LobbyController (Zombies)]]: lobby screen (visible while InRun is false) and the end-of-run results card.
- [[LobbyMenu (Zombies)]]: the lobby's main screen (owner 2026-11-03: "bare and boring, and it's the first impression").
- [[NightmareController (Zombies)]]: the client side of the Nightmare pad on the Flight Line (Map/FlightLine
- [[PostFXController (Zombies)]]: client-side "shaders" -- a moody, slightly more realistic, cinematic grade
- [[RadioController (Zombies)]]: the commander's radio panel on the left side of the screen (vault: Match Start.md).
- [[ReadyFx (Zombies)]]: makes a ready Ability / Ultimate hard to miss without shouting (owner 2026-11-03: "I always forget
- [[ShopController (Zombies)]]: the lobby's walk-up menus (vault: Lobby.md), opened by the ProximityPrompts (attribute
- [[SkipController (Zombies)]]: "hold to skip" for the deploy ride and the boss intro (Server/Services/MatchService
- [[SoundController (Zombies)]]: all game audio, client-side (ids + volumes in Shared/Config/Sounds).
- [[StoreController (Zombies)]]: the Robux shop (vault: Store.md; catalogue in Shared/Config/Store, purchases granted by
- [[SurvivorController (Zombies)]]: the safehouse people talk (Server/Map/Survivors places them; lines in
- [[ThrowController (Zombies)]]: the grenade throw animation (server sends Remotes.Effect "Throw" from
- [[TouchController (Zombies)]]: run controls for phones and gamepads (keyboard + mouse live in WeaponController and
- [[TutorialController (Zombies)]]: the objective card during a first-time player's training run (left side,
- [[UIKit (Zombies)]]: tiny helpers for building UI in code with one consistent theme.
- [[ViewmodelController (Zombies)]]: the first-person gun + arms you see while CameraController:IsActive().
- [[WeaponController (Zombies)]]: shooting input, client-side prediction (ammo, tracers, muzzle flash), and
- [[WelcomeController (Zombies)]]: the "welcome back" screen a returning player sees when they reach a lobby server (once
