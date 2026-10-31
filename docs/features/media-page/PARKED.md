# media-page — parked
parked: 2026-10-31 a561aa48 · by resume (audit exit, agent mode)
kind: human-step
blocked: "MediaBrowser's reference doc is only an uncommitted file in your main checkout, so d2m can't spec the grid [B1] — next: commit docs/ui2/references/media-browser.md to main, then /builder:agent"

## What is stuck
The Media page's grid (MediaBrowser) is specced by d2m from `docs/ui2/references/media-browser.md`
(SPEC D9, D11; program P2/P3). That doc is in git on no branch (`git log --all -- docs/ui2/references/media-browser*`
→ nothing). It exists only as an untracked file in the owner's main checkout:
`/Users/lukekeith/www/makeready/docs/ui2/references/media-browser.md` (16 362 bytes, 2026-10-30 23:12,
`?? docs/ui2/references/media-browser.md` in that checkout's `git status`). The fleet worktree can't see it,
and builder never writes design input, so the plan step refuses while SPEC §Findings B1 stands.

## What was tried
- Audit pass 1 (server + iphone agents) and pass 2 (cover-image routes) — done and committed (a561aa48); B1 is the only blocked row.
- Copying the owner's uncommitted file into this worktree — not done: it is the owner's in-progress design input, and builder never writes the design source.

## Evidence
- `ls docs/ui2/references/` in the worktree → `image-viewer-zoom-dismiss.md` only.
- main checkout: `?? docs/ui2/references/media-browser.md`; first line "# Media browser — zoomable library grid (reference)".

## Where to dig
- SPEC §Findings B1, R1 — after B1, the iPhone phase's first task requests MediaBrowser then media-home through the d2m channel.

## Recommended next step
Commit `docs/ui2/references/media-browser.md` on main (it is the reference the program already cites), then
`/builder:agent --path docs/features/media-page` — the fleet merges main into this worktree and the plan runs.
Alternatives: move the doc's content elsewhere and repoint D9/D11 (more work, same result).

## History
- 2026-10-31 parked — MediaBrowser reference doc uncommitted in the owner's checkout (B1)
