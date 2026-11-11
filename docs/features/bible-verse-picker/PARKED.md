# bible-verse-picker — parked
parked: 2026-11-11 b74801fd · by agent-walk (fleet walk lane)
kind: human-step
blocked: "waiting for your walk — next: /builder:resume --path docs/features/bible-verse-picker"

## What is stuck
Nothing is broken. The build is finished, including revision 2 (SC7 scripture vertical alignment on the
server, the d2m Figma glyphs and the reorganised Bible tool bar, and the container wiring for them).
The final review's fix wave landed at ee3a6bd5, and walk readiness passed at HEAD b74801fd. The test plan
is `walk=none · review=end · human=yes`, so no agent walks it. The owner walks it on device, then signs off.

## What was tried
- 2026-11-11 walk lane, fresh attempt after an unpark: checked whether the park still holds. It does,
  because it is the test plan's own human step, not a fault.
- Walk readiness at b74801fd: this branch adds no migrations (`git diff --diff-filter=A main...HEAD --
  server/atlas/migrations` is empty), and main is an ancestor of HEAD. The walk server on :3110 (pid 25922)
  runs from this worktree's server/ and started at 15:57:57, after the HEAD commit at 15:56:57. That
  means it runs SC7's zod change in services/activity-document.ts, which needs nothing regenerated.
  API_BIBLE_KEY is set in its environment. agent_walk.smoke passes on health, :8102 and :9010. These
  all return 200: /api/bible/translations, /translations/ENGKJV/books, /ENGKJV/43/3,
  /ENGKJV/43/3/verses?start=16&end=18, /WEB/43/3/verses?start=1&end=36, /api/search/recent, and
  POST /api/search/smart {"query":"John 3:16"}. .builder/walk-server.log has no errors.
- Recorded `state: built` and `ready: yes 2026-11-11 b74801fd` (71f9c32b).

## Evidence
- Verifier: commit tier GREEN at 7534eea, phase tier GREEN at ee3a6bd (1 flake, 1 known), merge tier
  GREEN at be39f31 (2 flakes, 2 known).
- .builder/bible-verse-picker/walk.md lists per-app items plus cross-app E1–E9. Its iphone block carries
  R1–R4 for D32/D33 (vertical alignment, the tool bar), which SPEC §Testing predates. The file is git-ignored.
- .builder/bible-verse-picker/handoff.md holds the build's rulings. Three are for the walk:
  1. Locked scripture opens the D12 menu, so restyling is reached only through the idle Bible tool bar (D28).
  2. The idle tool bar icons draw over scripture with no backing.
  3. Bible save reports 409 NOT_DRAFT instead of reloading and retrying.

## Where to dig
- Nothing to dig. Walk walk.md on device, with the app pointed at a server that runs this branch.
  SC7 is a server change, so a docker dev server must be restarted (`docker restart makeready-server`).

## Your choices
1. Walk it yourself now: `/builder:resume --path docs/features/bible-verse-picker`
2. Leave it for now

## Recommended next step
Walk it on device, then run `/builder:signoff --path docs/features/bible-verse-picker <your words>`.
`/builder:resume --path docs/features/bible-verse-picker` prints the walk script first.

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
- 2026-11-11 unparked by a person — named to /builder:agent or /builder:fleet
- 2026-11-11 readiness re-run at b74801fd (revision 2 + final-review fixes, SC7 live, all Bible endpoints 200); walk=none · human=yes → parked again (human-step), waiting for your walk
- 2026-11-11 unparked by a person — named to /builder:agent or /builder:fleet
