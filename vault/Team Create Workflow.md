# Team Create Workflow

How to edit the shared Studio place without breaking a friend's work. The full version is in `CLAUDE.md` §2, §5 and §6. Back to [[Home]].

- **Studio is the live truth; the repo is a mirror.** Code is written in Studio, then exported to `src/` and committed.
- **Shared with AnimatedSL.** Their live files (OurLobby, GameConfig, Sounds, HUDController and others) get **targeted edits only**. Never commit their Studio-only work in progress.
- **Before writing:** check the markers in `CLAUDE.md` §2, and compare Studio's current source with the repo.
- **Never do a full import.** One overwrote a live GameConfig edit on 2026-11-02. Push only the files you changed.
- **Three places to update on every task:**
  - `ServerStorage.README_AI_GUIDE` in the place (the shared guide with the friend's agent)
  - `CLAUDE.md`
  - this vault: the design note, plus `node tools/vault-code-notes.js` for the code notes
- **Map builders** run on a clone from the command bar, because its module cache goes stale (see [[Map builders]]).
- **Test commands:** [[DebugService]].
