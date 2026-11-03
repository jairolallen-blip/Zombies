# Client controllers

> Made by `tools/vault-code-notes.js`. Don't edit it here: rerun the script.

Client systems. Client Main loads them and calls Init, then Start.

Back to [[Home]].

- [[AirdropController]]: client side of supply drops (Server/Services/AirdropService).
- [[BossController]]: the client side of the final boss (vault: Waves and Boss.md, Nightmare Mode.md).
- [[CameraController]]: FIRST-PERSON run camera + the single source of truth for AIMING.
- [[Client Main]]: Client entry point. Requires every ModuleScript in Controllers, then calls
- [[ConditionsController]]: the client side of a run's weather (Shared/Config/Conditions, GameState Condition).
- [[CutsceneController]]: the first-person drop-in at the start of a run (vault: Match Start.md).
- [[EffectsController]]: all client-side visuals. Parts go in Workspace.ClientEffects (non-queryable).
- [[GroundFxController]]: disturbed earth where zombies break through the street (local only, nothing replicates).
- [[HUDController]]: the in-run HUD. Visible only while the player attribute InRun is true.
- [[InputController]]: keyboard actions other than shooting — abilities and in-run upgrades.
- [[LobbyAudioController]]: the safehouse's sound (ids and volumes in Shared/Config/Sounds).
- [[LobbyController]]: lobby screen (visible while InRun is false) and the end-of-run results card.
- [[LobbyMenu]]: the lobby's main screen (owner 2026-11-03: "bare and boring, and it's the first impression").
- [[NightmareController]]: the client side of the Nightmare pad on the Flight Line (Map/FlightLine
- [[RadioController]]: the commander's radio panel on the left side of the screen (vault: Match Start.md).
- [[ReadyFx]]: makes a ready Ability / Ultimate hard to miss without shouting (owner 2026-11-03: "I always forget
- [[ShopController]]: the lobby's two shops (vault: Lobby.md), opened by walking up to them and pressing
- [[SkipController]]: "hold to skip" for the deploy ride and the boss intro (Server/Services/MatchService
- [[SoundController]]: all game audio, client-side (ids + volumes in Shared/Config/Sounds).
- [[StoreController]]: the Robux shop (vault: Store.md; catalogue in Shared/Config/Store, purchases granted by
- [[SurvivorController]]: the safehouse people talk (Server/Map/Survivors places them; lines in
- [[ThrowController]]: the grenade throw animation (server sends Remotes.Effect "Throw" from
- [[TouchController]]: run controls for phones and gamepads (keyboard + mouse live in WeaponController and
- [[TutorialController]]: the objective card during a first-time player's training run (left side,
- [[UIKit]]: tiny helpers for building UI in code with one consistent theme.
- [[ViewmodelController]]: the first-person gun + arms you see while CameraController:IsActive().
- [[WeaponController]]: shooting input, client-side prediction (ammo, tracers, muzzle flash), and
- [[WelcomeController]]: the "welcome back" screen a returning player sees when they reach a lobby server (once
