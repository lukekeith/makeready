# media-page — parked
parked: 2026-10-31 20a56668 · by build (Task 8, agent mode)
kind: human-step
blocked: "d2m won't spec MediaBrowser or media-home until you apply its registry proposal and attach the reference doc in the d2m app [Task 8] — next: in d2m apply 'Mint MediaBrowser', attach docs/ui2/references/media-browser.md to MediaBrowser and media-home, run the two spec actions, then /builder:agent"

## What is stuck
Task 8 (Phase 4) is d2m's: it specs and builds the new MediaBrowser grid component and the media-home
screen, and Task 11 (the last task) wires the app container against those two views. The request went
through the d2m channel (`request_project_change`, change `cmvw0fg4m0001v00ab4dxfwv1`, subject
`media-home`, branch `builder/media-page`). d2m's chat ran for 25 s and ended `answered` — no change card,
nothing built. Its reply names three steps only the owner can take in the d2m app:

1. **Apply** its registry proposal *"Mint MediaBrowser: the zoomable, bottom-anchored photo grid that
   fills media-home"* (a registry row — builder never writes one).
2. **Attach** `docs/ui2/references/media-browser.md` (on main, 2c807640) as a markdown reference on
   MediaBrowser's page — and on media-home's, so the screen spec sees the chips, the five states and the
   Swift input names. "Chat runs can't attach files or read repo files"; without it the component spec
   is refused.
3. **Run** the queued action `/d2m:component:spec new:MediaBrowser`, then `/d2m:screen:spec media-home`
   (the screen spec can use its published Design 4).

Only after both specs will d2m's chat file the build ("ask for the build here and I'll file it").

## What was tried
- 2026-10-31 unpark retry: the old B1 cause (reference doc not on main) no longer holds — `media-browser.md` is in this worktree (2c807640). The build ran.
- Tasks 1–7, 9, 10 built, reviewed and committed (server phases 1–2 closed, contract frozen bc88a154; iPhone phase 3 closed; Tasks 9–10 of phase 5 done, iPhone gate PASS at 20a56668). Only Task 8 (d2m) and Task 11 (needs Task 8's views) remain.
- `request_project_change` with the full intent → refused (intent > 2000 chars); resent condensed, pointing d2m at `git show builder/media-page:docs/features/media-page/PLAN.md` Task 8 for the input names → `answered`, no card.
- Read d2m's reply from its own DB (read-only: `d2m-postgres` → `SubjectChatTurn cmvw0fg540006v00ajedvln6y`, its WorkItem `cmvw0fg580008v00a6wm265o4` events, `ChatProposal`) since the channel exposes no chat text.
- Not tried: requesting again — the reply says what is missing is an owner Apply and a file upload, which a re-request can't supply. Not tried: writing the registry row or the contract by hand — they belong to `/d2m-*`.
- The owner's main checkout is untouched (`git status` on the d2m paths = the pre-request snapshot: only the owner's own `EnrollmentSelectProgramScreen.swift` edit).

## Evidence
- `get_project_change cmvw0fg4m0001v00ab4dxfwv1` → `status: answered`, `next: "d2m's chat answered without a change card, so nothing was changed"`.
- d2m chat result: "I've filed two things for you to apply and run. I did not file a build step or a change card, because media-home isn't specced yet. 1. Registry card: mint a new row, MediaBrowser … 2. Action, waiting on that card: /d2m:component:spec new:MediaBrowser, then /d2m:screen:spec media-home … MediaBrowser has no source yet. Chat runs can't attach files or read repo files … attach media-browser.md on MediaBrowser's page after you apply the card and before you run step 1."
- `list_components search=MediaBrowser` → no row; `get_screen media-home` → `specced: false`, `buildBlockedReason: "media-home has no spec"`.

## Where to dig
- PLAN.md Task 8 Steps 3–8 (request → wait → carry d2m's files from the owner's checkout → restore it → build-check → commit → `report_project_change`); the Interfaces block there is what to paste into a markdown reference if d2m should use those input names.
- After the specs: request only the **build** (`request_project_change subject: media-home`, "build MediaBrowser then media-home"), then Task 11, phase 5's gate, the final review.
- Workspace ledger `.builder/media-page/progress.md` — every task, ruling and env note.

## Recommended next step
In the d2m app: apply the *Mint MediaBrowser* proposal, attach `docs/ui2/references/media-browser.md` to
MediaBrowser and to media-home, run `/d2m:component:spec new:MediaBrowser` and `/d2m:screen:spec media-home`;
then `/builder:agent --path docs/features/media-page` — the next run asks d2m for the build and finishes
Tasks 8 and 11.
Alternative: also run d2m's build of both yourself; the next run then only carries the files in.

## History
- 2026-10-31 parked — MediaBrowser reference doc uncommitted in the owner's checkout (B1)
- 2026-10-31 unparked by a person — named to /builder:agent or /builder:fleet
- 2026-10-31 retry — B1 cleared (doc committed in 2c807640); carried on to the plan
- 2026-10-31 resume (agent mode, unparked) — re-checked: `docs/ui2/references/media-browser.md` present in this worktree (2c807640 on main); state planned with go-ahead → build
- 2026-10-31 parked — build reached Task 8; d2m needs the owner's Apply + reference attachment + spec runs before it will build MediaBrowser/media-home
- 2026-10-31 owner: the d2m channel was upgraded — `request_project_change` now takes `references` (repo .md paths committed on `branch`, with `subjects` incl. `new:<Name>`) and runs the whole chain itself: mints the new component, attaches the references, specs and builds each subject, applies any card — no owner clicks in d2m. Steps 1–3 above are no longer the owner's: re-request Task 8 with `references: [{path: docs/ui2/references/media-browser.md, subjects: [new:MediaBrowser, media-home]}]`, then `wait_project_change`.
- 2026-10-31 unparked by a person — named to /builder:agent or /builder:fleet
