# bible-verse-picker — parked
parked: 2026-11-11 de53bd0d · by agent-walk (fleet walk lane)
kind: human-step
blocked: "waiting for your walk — next: /builder:resume --path docs/features/bible-verse-picker"

## What is stuck
Nothing is broken. The build is finished (including the phase 6–9 revision: verse-number modes, page
inset, tall Bible page, style panel), and walk readiness passed at HEAD be39f31a. The test plan is
`walk=none · review=end · human=yes`: no agent walks it. The owner walks it on device, then signs off.

## What was tried
- 2026-11-11 walk lane, fresh attempt after an unpark: re-checked whether the park still holds. It does,
  because it is the test plan's own human step, not a fault.
- Walk readiness at be39f31a (de53bd0d): no migrations on this branch (`git diff --diff-filter=A
  main...HEAD -- server/atlas/migrations` is empty). The walk server on :3110 (pid 78705) was started from this
  worktree at 13:40:29, after the HEAD commit at 13:39:24, so it runs the SC6 zod change (scripture
  `verseNumbers`/`inset`; zod only, nothing to regenerate). API_BIBLE_KEY is present in its environment.
  agent_walk.smoke passes: health, :8102 and :9010 all respond. These all return 200: /api/bible/translations,
  /translations/ENGKJV/books, /ENGKJV/43/3, /ENGKJV/43/3/verses?start=16&end=18,
  /WEB/43/3/verses?start=1&end=36, /api/search/recent, POST /api/search/smart {"query":"John 3:16"}.
  .builder/walk-server.log has no errors ("Cached 38 Bible versions").
- Recorded: `state: built`, `ready: yes 2026-11-11 be39f31a`.

## Evidence
- .builder/bible-verse-picker/walk.md: 9 per-app items (6 [risk]) and cross-app E1–E9. E6–E8 cover the
  revision. The file is git-ignored; regenerate it with `node <builder>/scripts/walk-script.mjs docs/features/bible-verse-picker`.
- .builder/bible-verse-picker/handoff.md: the build's rulings and deferred minors. Two of them are for the walk:
  locked scripture opens the D12 menu, so restyling is reached only through the idle Bible tool bar (D28);
  the tool bar icons draw over scripture with no backing.
- Verifier: the phase tier was RED at d45d8e8 (1 regression, ruled the pre-existing client-tokenization guard;
  client/ is identical to main). The merge tier was ENV-BROKEN at 4a4497e. The fleet re-runs the merge tier.

## Where to dig
- Nothing to dig. Walk walk.md on device with the app pointed at a server running this branch.

## Recommended next step
Walk it on device, then `/builder:signoff --path docs/features/bible-verse-picker <your words>`.
`/builder:resume --path docs/features/bible-verse-picker` prints the walk script first.
The other option is to change the test plan to an agent walk (`/builder:revise`). That loses the
on-device walk you chose for this feature.

## History
- 2026-11-10 parked — d2m cannot create the four picker screens; the screens are the owner's /ui2-screen step
- 2026-11-11 parked — the four Bible picker screens do not exist in d2m, and only the owner's /ui2-screen can create them
- 2026-11-11 unparked by the fleet — automatic retry 1 of 2
- 2026-11-10 parked again (human-step) — re-verified: still no such screens, still no tool that creates one
- 2026-11-11 unparked by a person — named to /builder:agent or /builder:fleet
- 2026-11-11 unparked by the fleet for the walk lane; d2m screens now exist (old cause cleared)
- 2026-11-11 parked (human-step) — walk env has no API_BIBLE_KEY; every Bible surface 500s before the walk
- 2026-11-11 unparked by a person — named to /builder:agent or /builder:fleet
- 2026-11-11 cause cleared — the walk env restarted with API_BIBLE_KEY exported; readiness re-run at 4a4497ed: every Bible endpoint + smart search 200 on :3110; state → built
- 2026-11-11 parked (human-step) — readiness passed with the key present; walk=none · human=yes → waiting for your walk
- 2026-11-11 unparked by a person — named to /builder:agent or /builder:fleet
- 2026-11-11 readiness re-run at be39f31a (post-revision HEAD, SC6 live, all Bible endpoints 200); parked again (human-step) — walk=none · human=yes → waiting for your walk
