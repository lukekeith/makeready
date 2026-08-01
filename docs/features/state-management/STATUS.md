# Status — Application State Standardization

**Nothing built yet.** Spec written 2026-08-01. Read [README.md](README.md) first, then this file.

## Phase checklist

| Phase | Scope | Status |
|---|---|---|
| **A** | The rule → `iphone/.claude/CLAUDE.md` | ☐ not started |
| **B** | Mode 1 — homeless domains (tags, media tags, leaders) → **fixes ticket 12668501065 sub-issue J** | ☐ not started |
| **C** | Mode 2 — forked copies (posts, members, enrollments) | ☐ not started |
| **D** | Enforcement — SwiftLint rule + baseline | ☐ not started · **must be last** |

## Decisions already made

- **Order is fixed: A → B → C → D.** Phase D last because the SwiftLint baseline is regenerated
  wholesale; running it earlier would enshrine the violations B and C delete. See
  [enforcement.md](enforcement.md) § "Why last".
- **Owner direction (2026-08-01): fix the architecture before the ticket.** Sub-issue J is fixed as
  a *consequence* of Phase B rather than as a local patch, so J becomes the first worked example of
  the new rule.
- **Web is out of scope** — audited and conformant (14 Pinia stores, zero component API calls).
- **Do not migrate all 19 sites.** Eight have a demonstrated problem; seven are correct as written;
  four need a judgment call. Dispositions in [audit.md](audit.md).
- **Build vs. buy settled (2026-08-01): build.** Researched TCA, swift-sharing, Verge, OneWay,
  SQLiteData, and SwiftData — see [library-evaluation.md](library-evaluation.md). Decisive finding:
  **iOS has no TanStack Query equivalent**, which is the category this bug lives in, so "adopt a
  library and it goes away" was never available. Everything that exists is a state *container*, and
  MakeReady already has a working one. Only database-as-source-of-truth (SQLiteData) would
  structurally kill the bug class, and that is a client data-layer re-platform — disproportionate to
  8 sites. **Revisit triggers are listed in that doc; check them before re-litigating.**
- **The earlier fix sketch for J is superseded.** `docs/monday/tickets/12668501065.md` originally
  proposed "refresh `allTags` in `.onAppear`". That treats the symptom; Phase B replaces it.

## Pick-up-here notes

**Before writing any code in this repo, know these two things:**

1. **Never run a build, `xcodebuild`, or any simulator command without asking first.** This is an
   absolute rule in `iphone/.claude/CLAUDE.md` — not even to check that something compiles. Verify
   with SwiftLint and code review, and state plainly what remains unverified.
2. **The working tree is dirty with ~164 unrelated modified files** from in-flight analytics work.
   Stage surgically; never `git add -A`. In particular **`iphone/MakeReady/State/AppState.swift`
   carries a foreign uncommitted hunk** (`programAnalyticsById`, which references the *untracked*
   `AnalyticsModels.swift`) — and Phase B edits that same file. Staging it wholesale sweeps in
   unrelated WIP *and* produces a non-compiling commit. Filter hunks with
   `git diff -- <file> | awk '/^@@ -<line>/{exit} {print}' > patch && git apply --cached patch`,
   then verify with `git diff --cached`.

**Separate commits per phase.** The rule/doc, each migration, and the build-gate change must not
share a commit — the enforcement commit in particular needs its own message explaining the
deliberate baseline regeneration.

## Verification per phase

- **A** — docs only; no verification beyond review.
- **B** — SwiftLint clean against baseline; then the J repro: edit a program's tags, return to
  Library → Programs, open `All tags`, confirm the new tag is listed **without** toggling a filter.
  Requires a device/simulator build (ask first).
- **C** — SwiftLint clean; then confirm a post/member/enrollment change made on one screen is
  reflected on the other without a manual reload.
- **D** — the deliberate-failure check in [enforcement.md](enforcement.md) § Procedure step 6.

## Related

- `docs/monday/tickets/12668501065.md` — sub-issue J (the motivating bug) and the original
  analysis this spec was extracted from. **Update its resolution log when Phase B lands.**
- `docs/features/analytics/` — the spec-layout convention this feature follows.
