---
tags: [zone-working]
cssclasses: [zone-working]
game-zone: working
---

# Team Create Workflow

How to edit the shared Studio place without breaking a friend's work. The full version is in `CLAUDE.md` §2, §5 and §6. Back to [[Home]].

- **Studio is the live truth; the repo is a mirror.** Code is written in Studio, then exported to `src/` and committed.
- **Shared with AnimatedSL.** Their live files (OurLobby, GameConfig, Sounds, HUDController and others) get **targeted edits only**. On 2026-11-04 the owner had everything in Studio exported to the repo (`52d955d`), so the repo matched Studio again that day; keep it that way by exporting after every task (`CLAUDE.md` §6).
- **Before writing:** check the markers in `CLAUDE.md` §2, and compare Studio's current source with the repo.
- **Never do a full import.** One overwrote a live GameConfig edit on 2026-11-02. Push only the files you changed.
- **Three places to update on every task:**
  - `ServerStorage.README_AI_GUIDE` in the place (the shared guide with the friend's agent)
  - `CLAUDE.md`
  - this vault: the design note, plus `node tools/vault-code-notes.js` for the code notes
- **Map builders** run on a clone from the command bar, because its module cache goes stale (see [[Map builders]]).
- **Test commands:** [[DebugService]].

## Two places, one codebase (packages)

Outbreak runs in its own place (87622086122699) with its own copy of every script. Copies drift: on 2026-11-04 its cutscene was a day behind. The fix is **Roblox packages**: each code folder becomes one package, both places use it, and a change is published once.

Roblox only creates packages from Studio's menu (no script can), so the owner does this once, in the **main** place:
1. Right-click each of these, then **Convert to Package**, with the game's owner as the package owner (the same owner for both places):
   - `ServerScriptService.Server`
   - `ReplicatedStorage.Shared`
   - `StarterPlayer.StarterPlayerScripts.Client`
   - `ReplicatedFirst.JoinCover`
2. In each new package, select its **PackageLink** and turn on **AutoUpdate**.
3. Publish the main place.
4. Open the Outbreak place. Delete its own `Server`, `Shared`, `Client` and `JoinCover`. From the Toolbox (Inventory, Packages) insert the four packages into the same spots, turn on AutoUpdate on each PackageLink, and publish the Outbreak place.

After that, the workflow for any code change in the main place:
- Edit as usual (agents still push with `UpdateSourceAsync`). Studio marks the package as changed.
- Right-click the changed package folder, then **Publish to Package**. No script can do this step, so agents must ask the owner.
- Open the Outbreak place (AutoUpdate pulls the new version in) and publish it. A live server only runs what was last published, in each place.

The repo stays the backup of both: `tools/studio-export.luau` covers the same five folders (ReplicatedFirst added 2026-11-04).

