# bible-verse-picker — parked
parked: 2026-11-11 ac927896 · by the fleet (the run that parked it wrote no record)
kind: stuck
blocked: "the four Bible picker screens (books, chapters, verses, reader) do not exist in d2m, and only the owner's /ui2-screen can create them — next: /ui2-screen for bible-books, bible-chapters, bible-verses, bible-reader, then /builder:agent"

## What is stuck
the four Bible picker screens (books, chapters, verses, reader) do not exist in d2m, and only the owner's /ui2-screen can create them

## What was tried
- 3 fleet run(s) in all — `git log --oneline -- docs/features/bible-verse-picker` lists what each changed

## Evidence
- the run that parked it: /Users/lukekeith/www/makeready/.builder/fleet/logs/bible-verse-picker-03.log — its last lines:

```

**Needs your attention:** d2m wrote its output uncommitted into your main checkout (`/Users/lukekeith/www/makeready`, branch `feature/text-activity`). That's 8 files under `iphone/MakeReadyUI/`, `iphone/MakeReadyCaptureTests/` and `docs/ui2/design-system/tokens.md`. The same changes are committed on this branch, so once you've checked them you can revert them there with `git checkout --`. I left them alone.

**Every test tier showed one red check, but it isn't caused by this branch.** The client design-token check flags `group-members-page.scss`. `client/` is unchanged on this branch, and running that check on `main` (388d0abf) gives the same 16 hits. Each run blamed a different commit, so I closed the phases over it. It will show up again when this merges into `main`.

**Decisions I made, and what each costs if wrong:**
- **Build order changed:** I built Tasks 9 and 12–15 before 10–11, since none of them use the missing screens. Task 13's "open the picker" step may need a touch-up if the screens change the flow.
- **Two corrected values in the screen test data:** I used offset 28 instead of the plan's 9, which landed mid-word. The highlight covers "everlasting life", because the KJV text has no "eternal life". Wrong, it's a test-data tweak.
- **Invalid passages are dropped when saving:** an entry missing a required number is removed, because the server would refuse it anyway. Wrong, a malformed old passage is lost on first edit.
- **Book categories come from the spec's book ranges,** not a per-book field. No behaviour change either way.
- **Old search types renamed to `Legacy*`** so the new types own the names. Wrong, it's a rename back.
- **Empty search sends no request.** Wrong, it costs one request.
- **The text-fitting check that splits a long passage assumes a 1.2 line height,** because the plan gave none. Wrong, the split point could be off by a line.
- **Carried into Task 11:** a whole-verse selection must save with no end offset (the spec says "absent = whole verse"). Otherwise every whole-verse citation gets a wrong "a" marker, like "John 3:16a".

**Left for the final review to judge:**
- A Bible save that hits "not a draft" reports an error instead of reloading and retrying as the Text tile does.
- New Bible activities use the default background rather than a generated gradient.
- A locked scripture object can't be deleted from the screen; the delete works only in the model.
- "Add note" isn't wired.
- Change passage drops any per-object restyling.

The full record is in `docs/features/bible-verse-picker/PARKED.md`.

📍 bible-verse-picker: building, phase 4/5 (iphone), parked. The four picker screens don't exist in d2m, and only `/ui2-screen` can create them. Next: `/ui2-screen` for bible-books, bible-chapters, bible-verses and bible-reader, then `/builder:agent`.
```

## Where to dig
- start from the run's last lines above and the evidence it names; nothing has been ruled out yet

## Recommended next step
/ui2-screen for bible-books, bible-chapters, bible-verses, bible-reader, then /builder:agent

## History
- 2026-11-10 parked — d2m cannot create the four picker screens; the screens are the owner's /ui2-screen step
- 2026-11-11 parked — the four Bible picker screens (books, chapters, verses, reader) do not exist in d2m, and only the owner's /ui2-screen can create them
