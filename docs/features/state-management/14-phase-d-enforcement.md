# Phase D — Enforcement  ·  app: iphone

> Part of docs/features/state-management/. Preconditions: Phase C-b's **VERIFIED** block is signed —
> which means A, B, C-a and C-b are all signed.
>
> ✅ **G11 settled before this phase (2026-08-01)** — the two join-request forks were fixed, not
> grandfathered, so the baseline below records only deliberate cases.
>
> 🔒 **This phase MUST be last, and the ordering is not negotiable.** The SwiftLint baseline is
> regenerated **wholesale** (currently 1,118 entries). Landing the rule before B/C baselines exactly
> the violations those phases delete — enshrining what was just fixed and leaving stale entries
> behind. See [README](README.md) § Ordering hazard.

## Goal

A new `@State` collection of server models inside `Pages/` fails the build, with the escape hatch
being a deliberate, reviewed baseline entry rather than silence.

## Companion skills

None.

## Tasks

- [x] D.1 Add the custom rule — files: `iphone/.swiftlint.yml` (`custom_rules:`, `:32`) · spec:
      [enforcement.md](enforcement.md) § The new rule · tests: the deliberate-failure check below
      - the regex was **empirically validated 2026-08-01**: `included:` is supported inside
        `custom_rules`. It fired on **21 sites** then; **it now fires on 11** (9 real + the
        same 2 `#Preview` mocks) — B/C-a/C-b deleted 8 and G11's join-request fix deleted 2 more.
        Expect 11, not 21 (G12)
- [x] D.2 Regenerate the baseline — files: `iphone/.swiftlint-baseline.json` · spec:
      [enforcement.md](enforcement.md) § Procedure · tests: the grandfathering check below
      - `cd iphone && swiftlint lint --write-baseline .swiftlint-baseline.json`
      - **run this only after B, C-a and C-b are signed** — that is the entire reason this phase is
        last
- [x] D.3 Add the human half — the review checklist — files: per
      [enforcement.md](enforcement.md) § Review checklist · tests: none (docs)
- [x] D.4 **Own commit, own message.** The baseline regeneration touches many unrelated files; the
      commit message must explain that it is deliberate. Do not bundle it with D.1/D.3

## Phase gates (run fresh, record output)

- [x] `cd iphone && swiftlint lint --baseline .swiftlint-baseline.json` — **0 violations,
      0 serious in 267 files (2026-08-01)**, against the regenerated baseline
- [x] `npm run ios:build-check` — **BUILD SUCCEEDED (2026-08-01)** with the rule active as a build
      phase

## Verification checklist

- [x] **Deliberate-failure check** ([enforcement.md](enforcement.md) § Procedure step 6) — a
      throwaway `@State private var junkProbe: [StudyProgram] = []` added to `MainHome.swift`
      produced `MainHome.swift:38:5: error: Server collection held in view @State` **against the
      regenerated baseline**, i.e. the baseline did not suppress it even though the adjacent
      `activityLogs` line IS baselined. Removed; gate back to 0 violations (2026-08-01)
- [x] **The baseline grandfathers only the deferred sites** — diff the regenerated baseline against
      the old one and confirm the sites B / C-a / C-b fixed are **gone** rather than baselined. A
      baselined entry for a site those phases were supposed to fix means the phase order was
      violated and the baseline must be regenerated after fixing it.
      **Confirmed 2026-08-01: exactly 11 entries** for the new rule (G12), down from 21. The
      baselined 11 are the 9 sites [audit.md](audit.md) dispositioned as screen-local
      (`suggestions`, `draggedItems`, `activityLogs`, `tags`, `exegesisHighlights`, `orderedBlocks`,
      `orderedLessons`, `editTags`, `originalEditTags`) **plus the 2 `#Preview` mocks**. None of the
      sites B / C-a / C-b fixed appears — they are gone, not grandfathered.
      **Baseline total 1,118 → 992.** The 126-entry drop is NOT this feature alone: a bare
      `swiftlint` reported 981 violations before the new rule was added and 992 after (+11 exactly),
      so the codebase simply carries ~137 fewer violations than when the baseline was last written
      on 2026-06-11. Regenerating wholesale re-syncs it to current code — which is the point
- [x] The 2 `#Preview` mocks are **consciously baselined**, not excluded (`GroupMembersPage.swift:523`,
      `:540` — the 11-vs-9 delta; line numbers moved by 3 when C1.5 removed the `joinRequests`
      declaration). Excluding them would need a path rule that also hides real page code, since they
      are declared inline in a page file rather than under `Preview Content`
- [x] **The two join-request forks are fixed rather than baselined** (G11, 2026-08-01) — so every
      one of the 9 real survivors is a case [audit.md](audit.md) deliberately dispositioned as
      screen-local. If a *tenth* appears in the regenerated baseline, something was missed
- [x] Success criterion 3 holds end to end: a new offending collection fails the build — proven by
      the deliberate-failure check above, with the rule running as an Xcode build phase
- [x] Spec parity spot-check: the rule's message points at
      `docs/features/state-management/README.md § The rule`, states that edit buffers and pure UI
      state are exempt, and says the escape hatch is a *deliberate* baseline entry. The human half
      (the three things a regex cannot check) is in `iphone/.claude/CLAUDE.md` beside the rule
      itself, not only in this suite

### Deferred deliberately, recorded so the baseline entry is a decision

`ProgramHomePage.orderedLessons` is now grandfathered, and [audit.md](audit.md):63 recommends
converting it to a computed property over `AppState.lessons` — *"as `@State` it can go stale"*.
That conversion was **not** done here: it is a within-screen ordering concern rather than a
demonstrated cross-screen inconsistency (unlike G11's join requests, which showed one), and
`ProgramHomePage` is heavily modified by the in-flight analytics work. Left as a follow-up with the
audit's recommendation attached, not as a silent baseline entry.

## VERIFIED

✅ **2026-08-01**

**Gates:** `npm run ios:build-check` BUILD SUCCEEDED with the rule active as a build phase ·
`swiftlint lint --baseline` 0 violations, 0 serious, 267 files.

**What was proven, not assumed:** the rule fires on exactly the 11 predicted sites; the baseline
grandfathers those 11 and none of the sites the migrations fixed; and a freshly-introduced
violation fails **against the regenerated baseline** rather than being absorbed by it. That last
one is the whole phase — a baseline that swallowed new violations would look identical to a
working gate until the day it mattered.

**Not machine-checkable, stated plainly:** whether each of the 9 grandfathered sites *should*
stay screen-local rests on [audit.md](audit.md)'s per-site dispositions, which were written by
reading the code, not by running anything. `orderedLessons` carries a known caveat (above).
<!-- flip to: ✅ YYYY-MM-DD — gates output summarized, walk results, commit sha(s) -->
