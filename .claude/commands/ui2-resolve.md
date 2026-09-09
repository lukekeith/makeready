---
description: Resolve unresolved comments on a UI 2.0 component preview — one state (`C-034 default`) or every state (`C-034`). Figma is the reference; the SwiftUI preview view or its fixture is what changes. Edits, recaptures, verifies against the frozen snapshot, then replies + resolves. (Copied by the /components 2.0 UI's Prompt menu.)
argument-hint: <C-### [state-slug]  — e.g. C-034 default, or C-034 for every state>
---

# UI 2.0 resolve — $ARGUMENTS

Resolve the unresolved comments on **$ARGUMENTS** in the 2.0 component browser
(`http://localhost:5950/components/2.0`).

**This is not `/component-resolve`.** That command's reference is the iPhone render and its
subject is a shipping 1.0 component under `MakeReady/Components/`. Here the reference is the
component's **frozen Figma snapshot**, and the subject is its **preview** — a view under
`iphone/MakeReady/UI2Preview/` that is wired into no screen, route or flag. Everything in
`docs/ui2/preview-build.md` §3 still binds; this command may not break a rule that command
never had to think about.

**Read `docs/ui2/preview-build.md` §3 (binding rules) and the component's contract before
editing anything.** They decide what a comment is even allowed to change.

## 0. Resolve the scope

Split `$ARGUMENTS` into a registry id (`C-###`, required) and an optional **state slug**.

```bash
curl -s "localhost:5951/api/ui2/detail?id=<C-###>"
```

That gives `variants[]` with `name` (the DB key) and `slug` (what the URL and this command
take). **Map slug → name and key everything on the name** — a comment's `variantName` is the
name, never the slug (`preview-build.md`'s "Name ≠ slug").

- No contract file for the row (`docs/ui2/design-system/components/C-###-*.md`) → stop and
  point at `/ui2-component`.
- Unknown slug → list the row's slugs and stop.
- No fixture at `capture/fixtures/ui2/C-###.json` → the row is not built; nothing to comment
  on. Point at `/ui2-component-build C-###` and stop.

Then pull the comments:

```bash
curl -s "localhost:5951/api/compare/comparison/ui2-c-<###>/comments"
```

(or the `makeready-capture` MCP tool `list_unresolved_comments` with
`comparisonId: "ui2-c-<###>"`). Keep `resolved: false` only, and **filter to the one state
when a slug was given**. Zero unresolved → say so with the state count and stop.

## 1. Per comment, oldest first

**Read both images before deciding anything:**

- the **frozen Figma snapshot**, `docs/ui2/design-system/components/assets/<file>.png` (§1 of
  the contract names it) — the reference;
- the **built render** the pin was made on,
  `capture/fixtures/compare/_shots/ui2-c-<###>/design/iphone/<versionId>.png`, and the
  current one if they differ. A comment made on an older version is a *reference* against the
  current render, not a description of it.

A comment carries `targetLabel` when the commenter clicked an annotated part — that string is
a `.ui2Element` name from the view, i.e. §2's own anatomy vocabulary. Use it to go straight to
the right code. `position` (fraction + px) locates anything unannotated.

**Classify before you edit.** This is the step that matters, because most 2.0 comments are not
bugs in the view:

| Class | What it looks like | What to do |
|---|---|---|
| **Render defect** | The view disagrees with the snapshot and the contract says what it should be | Fix the view. |
| **Fixture/data** | Geometry is right, the sample content is wrong or unrepresentative | Edit `capture/fixtures/ui2/C-###.json`, not the view. |
| **Declared gap** | The comment asks about something the build already reported — a **stub** (`// STUB —`), a **flagged literal**, or a `GAP —` line | **Do not "fix" it.** Reply with what the gap is and the `/ui2-component` run (or Figma export) that closes it. Inventing the missing artwork or value is exactly what these markers exist to prevent. **Resolve only if the gap is tracked somewhere durable** — an OQ row in the contract, or a `tokens.md` line. A gap whose only record is a build report in a chat log is tracked by *this comment*: answer it and leave it OPEN, or the outstanding work vanishes with the comment. A comment that says "this should be X" is a change request, not a question, and stays open until X exists. |
| **Spec defect** | The contract does not determine the answer, or the comment asks for a state/prop/value the contract has no ruling on | Reply naming the contract line and the `/ui2-component` re-run that would settle it. Leave **unresolved**. Never improvise it in Swift. |
| **Undesigned state** | The comment asks to render a §3 row marked `undesigned` | Reply with the OQ it waits on. Leave unresolved (rule 7). |
| **Owner call** | A tradeoff, or it moves `tokens.md`, a token's value, or an OQ-PB default | Reply with the options. Leave unresolved. |

**When you do edit**, the same rules the build ran under still apply:

- Tokens by name (rule 4). A flagged literal stays a literal with its flag comment. A value
  that is neither tokened nor contract-traceable is a spec defect — stop, don't invent it.
- Every prop value traces to §4 × §3 (rule 6). Fixture variant **names** are never touched
  (rule 7) — they are the DB key for versions and comments.
- Never wire the view into anything (rule 1); never edit `Colors.swift`, `Typography.swift`,
  `Pages/`, `Services/Route.swift` (rule 2); never hand-edit `UI2Preview/Tokens.swift` — if a
  token must change, that is a `tokens.md` change plus `node capture/lib/ui2-tokens.mjs`.
- **Never nudge geometry to match the picture.** A render that cannot match is a gap to
  report, not a number to tune.
- This command **never edits `docs/ui2/`** — same boundary as `/ui2-component-build`.

## 2. Lint, then recapture

Lint first, and only if you edited Swift — it runs in a second, and the build phase enforces
it anyway, so a violation would otherwise fail the capture *after* `xcodebuild` had already
spent minutes. Never regenerate the baseline to silence one.

```bash
cd iphone && swiftlint lint --quiet --baseline .swiftlint-baseline.json
```

**Then recapture the states in scope — ALWAYS, before you reply to anything.** Not only the
states you changed: every run that processed at least one comment ends in a capture.

```bash
node capture/runners/ui2/capture.mjs C-### <state-slug>     # a slug was given
node capture/runners/ui2/capture.mjs C-### '*'              # no slug — every state
```

Scope in, scope out: the slug the run was invoked with is the slug it recaptures, and a
run with no slug recaptures `'*'`.

Why unconditionally, when a state you did not touch will render identically:

- **The reply has to be checkable.** "I changed X" is worth nothing next to a render from
  before the change. Capture is additive (`preview-build.md` §3 rule 8 — a Version per run,
  always), so the fresh version is what the reader opens and the pin-to-version history
  stays honest.
- **"I changed nothing" is a claim too.** A run that only classified and replied still
  asserts the render is current; a capture proves it rather than assuming it.
- **You are the least reliable judge of what you touched.** A token regen, a fixture edit on
  a shared value, a dependency's view — each reaches states you were not thinking about.
  Recapturing the scope removes that judgment call from the loop.

The one exception is a run that **stopped in §0** — no contract, no fixture, unknown slug, or
zero unresolved comments. Nothing was processed, so there is nothing to refresh: say so and
stop without burning a capture.

Run the runner **directly** — not `POST /api/ui2/capture`, which returns immediately and
streams over SSE for the browser, and would race you to the PNGs. It is covered by
`iphone/.claude/CLAUDE.md`'s named carve-out, so it needs no permission; **any other** build
command still does. Each state is minutes; budget for it.

Expected collateral: the run re-renders ~20 unrelated 1.0 baselines under
`capture/fixtures/iphone/*/screenshots/`. Leave them out of any commit
(`git checkout capture/fixtures/iphone`).

## 3. Verify, then reply + resolve

Read the new PNG beside the frozen snapshot and confirm the change is actually visible and
did not move anything else. On a run that changed nothing, confirm the fresh render still
matches what your replies say about it — a surprise there is a finding, not a formality. Check `<versionId>.elements.json` still names the parts you
touched — a renamed or dropped `.ui2Element` silently strips element context from every
future comment on that part.

Then, per comment: `reply_comment` saying exactly what changed (file + what, or why nothing
changed), and `resolve_comment` **only** for comments you actually acted on. A change that
did not take → reply saying so and leave it open.

## 4. Report

Per state: resolved / replied-and-left-open (with the class from §1's table) / failed
verification, the files touched, and the recapture — which states, and the version id per
state, so the reader can open exactly what you looked at. Then the URL:
`http://localhost:5950/components/2.0/C-###/<state-slug>`.

If any reply named a `/ui2-component` re-run or a missing Figma export, collect those into one
list at the end — they are the work this command deliberately did not do.

## Rules

- The invocation is the scope; everything else comes from the API and the contract at run time.
- Only ever touch `iphone/MakeReady/UI2Preview/`, `capture/fixtures/ui2/`, and — when a
  comment genuinely lands on the capture plumbing — the two test-target files
  `preview-build.md` §3 rule 3 permits (`ViewRegistry.swift`, `CaptureFixture.swift`, additive
  optional fields only, named in the report).
- Never touch `client/`, never run a web capture, never resolve a comment you did not act on.
- Commits stay the user's call — leave the working tree for review unless told otherwise.
