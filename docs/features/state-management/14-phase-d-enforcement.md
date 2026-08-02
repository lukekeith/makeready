# Phase D — Enforcement  ·  app: iphone

> Part of docs/features/state-management/. Preconditions: Phase C-b's **VERIFIED** block is signed —
> which means A, B, C-a and C-b are all signed.
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

- [ ] D.1 Add the custom rule — files: `iphone/.swiftlint.yml` (`custom_rules:`, `:32`) · spec:
      [enforcement.md](enforcement.md) § The new rule · tests: the deliberate-failure check below
      - the regex was **empirically validated 2026-08-01**: `included:` is supported inside
        `custom_rules`, and the pattern fires on 21 sites (19 real + 2 `#Preview` mocks)
- [ ] D.2 Regenerate the baseline — files: `iphone/.swiftlint-baseline.json` · spec:
      [enforcement.md](enforcement.md) § Procedure · tests: the grandfathering check below
      - `cd iphone && swiftlint lint --write-baseline .swiftlint-baseline.json`
      - **run this only after B, C-a and C-b are signed** — that is the entire reason this phase is
        last
- [ ] D.3 Add the human half — the review checklist — files: per
      [enforcement.md](enforcement.md) § Review checklist · tests: none (docs)
- [ ] D.4 **Own commit, own message.** The baseline regeneration touches many unrelated files; the
      commit message must explain that it is deliberate. Do not bundle it with D.1/D.3

## Phase gates (run fresh, record output)

- [ ] `cd iphone && swiftlint` — clean against the **regenerated** baseline
- [ ] `npm run ios:build-check`

## Verification checklist

- [ ] **Deliberate-failure check** ([enforcement.md](enforcement.md) § Procedure step 6) —
      introduce a violating `@State private var xs: [SomeModel] = []` in `Pages/`, confirm it
      fails, remove it
- [ ] **The baseline grandfathers only the deferred sites** — diff the regenerated baseline against
      the old one and confirm the sites B / C-a / C-b fixed are **gone** rather than baselined. A
      baselined entry for a site those phases were supposed to fix means the phase order was
      violated and the baseline must be regenerated after fixing it
- [ ] The 2 `#Preview` mocks are excluded or consciously baselined (the 21-vs-19 delta)
- [ ] Success criterion 3 holds end to end: a new offending collection fails the build
- [ ] Spec parity spot-check: the rule's message names the rule and points at the escape hatch

## VERIFIED

⬜ Not yet — this is the final phase. Signing it hands off to `/build-spec-verify`.
<!-- flip to: ✅ YYYY-MM-DD — gates output summarized, walk results, commit sha(s) -->
