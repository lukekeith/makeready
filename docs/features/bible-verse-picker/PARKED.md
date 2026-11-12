# bible-verse-picker — parked
parked: 2026-11-12 6d7f3eae · by the fleet (the run that parked it wrote no record)
kind: human-step
blocked: "revising — next: /builder:revise --path docs/features/bible-verse-picker"

## What is stuck
revising

## What was tried
- 12 fleet run(s) in all — `git log --oneline -- docs/features/bible-verse-picker` lists what each changed

## Evidence
- the run that parked it: /Users/lukekeith/www/makeready/.builder/fleet/logs/bible-verse-picker-12.log — its last lines:

```
· The latest revision of the Bible verse picker (Tasks 23–25) is built and committed, and it's now waiting for the fleet's walk lane. The old park reason ("waiting for your walk") no longer applied, because you'd revised the spec and approved three new phases since then.

**What landed (all iPhone, 3 phases, 3 tasks)**
- **Phase 13 · Task 23 (`b842babd`)**: the Bible reference (D34) is now ordinary text above the passage, without the translation code. It can be edited, moved and restyled like any text, and it's no longer locked or counted in the page height. Change passage updates it only while you haven't edited it.
- **Phase 14 · Task 24 (`16b30ce9`)**: d2m added a light/dark tool bar tone setting to the editor screen. It asked one question (how to recolour the icon buttons, which set their own colour) and I gave its recommended answer: an optional icon colour, off by default.
- **Phase 15 · Task 25 (`32d67a86`)**: on text and Bible activities, the tool bar icons turn dark when the page background is light (D35). Image and video backgrounds keep white icons.
- **Final review fixes (`84165195`)**: an honest test name and assertions, the spec's test steps updated for D34/D35, new walk steps E10–E11, outdated code comments refreshed, superseded decisions marked, and tests for "Song of Solomon" and "1 John" when Change passage updates the reference.

**Tests**: every phase passed the verifier, and the last run, on `84165195`, passed all 55 iPhone test files with one known flaky test. No server code changed, and the contract is unchanged (still frozen since 2026-11-11). I skipped walk readiness, as `--no-dev-env` requires; the manifest says the dev environment is pending for the walk lane (`6d7f3eae`).

**Decisions I made, and what each costs if wrong**
1. **Deleting the reference**: I didn't add a way to delete it. D34 says it behaves "exactly like text on a text activity", and an existing text object can't be deleted there either. Today, emptying the reference leaves an invisible empty object on the page. **Your question for the walk:** should emptying any existing text object remove it on Done, on both text and Bible activities?
2. **Deleting the scripture**: the reference stays, since it's now independent text, and the delete confirmation no longer mentions it. If wrong, it's a wording change.
3. **Reference position**: the test checks the box centre (top at 40 pt plus half a line), because positions are stored by centre and D34 fixes the top. If wrong, the test needs re-anchoring.
4. **Tool bar labels**: the tool bar has only icons, so the tone covers every icon. Selected and disabled tools keep their usual look. If a label stays white somewhere, that's another d2m request.
5. **Gradient brightness**: I averaged the base colour and every blob colour; a hidden gradient counts as its solid colour. If wrong, a gradient heavy with blobs could get the wrong tone near the threshold.

**Left for later**
- The d2m editor previews still show the old locked reference ending in "ENGKJV". This affects preview samples only and needs a d2m request.
- Two things to check during the walk: whether the reference at 40 pt hides under the player's top bar, and whether dark icons are readable on a mid-grey page just past the threshold.
- d2m's edits landed uncommitted in your main checkout again (`/Users/lukekeith/www/makeready`, now including `IconButton.swift`). I copied them here and left that checkout as it was.

The walk script (`.builder/bible-verse-picker/walk.md`) now covers E1–E11. I reworded the hand-written iPhone steps that still described the old reference.

📍 bible-verse-picker: all phases closed at `84165195`, waiting for the fleet's walk lane — next: /builder:resume --path docs/features/bible-verse-picker
```
- the walk env's start log: /Users/lukekeith/www/makeready/.builder/fleet/logs/bible-verse-picker-start.log

## Where to dig
- start from the run's last lines above and the evidence it names; nothing has been ruled out yet

## Your choices
1. Revise it — `/builder:revise --path docs/features/bible-verse-picker`
2. Leave it for now

## Recommended next step
/builder:revise --path docs/features/bible-verse-picker

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
- 2026-11-12 parked — revising
- 2026-11-12 unparked by a person — named to /builder:agent or /builder:fleet
