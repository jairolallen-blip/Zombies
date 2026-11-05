---
tags: [zone-working]
cssclasses: [zone-working]
samz-zone: working
---

# Servers and Teleports

Added 2026-11-02 so a real playerbase doesn't cram into one city. Back to [[Home]].

## Two kinds of server, one place
- **Lobby server:** the safehouse ([[Lobby]]). Squads form on the 4 Flight Line pads ([[FlightLine]], [[QueueService]]). Live lobby servers delete the Arena.
- **Match server:** a reserved server of the same place holding one squad. A reserved server has `game.PrivateServerId ~= ""` and `PrivateServerOwnerId == 0`, but so does a **Team Test** server (and Team Test's server says it isn't Studio). So since 2026-11-03 [[MatchService]] waits for the first player: arriving with our squad teleport data (`Squad`) means a match server; arriving without it means Team Test.

## A squad's trip
1. The first player on an empty pad is its **host**. They pick squad size, difficulty and map on the squad panel ([[LobbyController]], remote `SetPadOptions` in [[Remotes]]; choices in `GameConfig.Lobby`, see [[GameConfig]]).
2. The countdown runs while anyone is on the pad: 15s, or 4s once the squad is full.
3. At 0 the squad is teleported together (`TeleportOptions.ShouldReserveServer`, with TeleportData holding the squad and options). Profiles are saved first ([[DataService]]).
4. The match server waits for the squad (`SquadWaitTime`), plays one run (`MatchService:RunMatch`), then `QueueService:ReturnToLobby` sends everyone back (3 tries, then a kick).

## First-time players
Profiles with `TutorialDone = false` skip the lobby and go straight into a solo [[Tutorial]] run.

## Saves stay safe across servers (2026-11-02)
Every saved profile carries a session lock ([[DataService]]). A server loads a profile only when no other live server holds it: it waits up to 30s for the old server to let go after a teleport, and takes over a lock older than 120s (a crashed server). It never writes over a profile another server took, autosaves every 45s, and lets go on leaving, teleporting and shutdown.

## Where players stop
The onboarding funnel (Creator Dashboard > Analytics > Funnels) logs: 1 Joined, 2-9 tutorial steps, 10 Finished the tutorial, 11 Reached the lobby, 12 Finished a squad run. A WaveReached custom event shows how far squad runs get.

## In Studio
Studio can't teleport, so a take-off plays the run inside the lobby server, one pad at a time. **Team Test** works the same way (`MatchService.LocalRuns`): lobby and welcome screen first, runs on the same server, back to the lobby afterwards. Before 2026-11-03 Team Test was mistaken for a match server: it skipped the lobby, started a run at once and then failed to teleport everyone back. The teleports have only been tested in the published game.
