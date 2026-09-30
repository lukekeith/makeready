---
name: d2m-resolve
description: Resolve unresolved comments on a component preview — one state (`C-034 default`) or every state (`C-034`). Figma is the reference; the preview view, its fixture, or — when the comment is an owner ruling — its contract is what changes. Edits, recaptures, verifies against the frozen snapshot, then replies + resolves. (Copied by the workbench's Prompt menu.)
argument-hint: <C-###> [state-slug] [--project <slug>] [--era <key>]  — e.g. C-034 default, or C-034 for every state
---

# Resolve — $ARGUMENTS

Resolve the unresolved comments on **$ARGUMENTS** in the d2m workbench.

**The reference is the component's frozen Figma snapshot**, and the subject is its **preview** —
a view under `project.previewDir` that is wired into no screen, route or flag. Everything
`/d2m-component-build`'s Hard rules block binds still binds here; this skill may not break a
rule that skill never had to think about.

**Read `/d2m-component-build`'s Hard rules and the component's contract before editing
anything.** They decide what a comment is even allowed to change.

`--project <slug>` / `--era <key>` override the pinned scope, and every command the workbench
copies carries them. **Pass them through to every tool call**, and **state the project and era
you resolved in your first report line.**

## 0. Resolve the scope

Split `$ARGUMENTS` into a registry id (`C-###`, required) and an optional **state slug**.

1. `project_info()` — the scope line, plus `previewDir`, `lintCmd` and `captureAdapter`. An
   adapter of `noop` means **there is no render lane**: you can still classify and reply, but
   §2's recapture is impossible and every reply must say so rather than implying a fresh render
   exists.
2. `get_component(code)` → `variants[]` with the state **label** (the identity d2m keys a thread
   on) and the **slug** (what the URL and this skill take). **Map slug → state and key everything
   on the state, never on the slug.**

Stop if:

- **No contract** for the row → point at `/d2m-component` and stop.
- **Unknown slug** → list the row's slugs and stop.
- **Not built** (`build_status(code)`) → the row has no preview; nothing to comment on. Point at
  `/d2m-component-build C-###` and stop.

Then pull the comments: `list_unresolved_comments(...)` for this component's subject, filtered to
the one state when a slug was given, and `get_comment(comment: <id>)` for each one you are about to act on.
Zero unresolved → say so with the state count and stop.

## 1. Per comment, oldest first

**Read both images before deciding anything:**

- the **frozen Figma snapshot** — `get_component(code)`'s `snapshot` — the reference;
- the **built render the pin was made on**, from that state's `versions[]`, and the current one
  if they differ. A comment made on an older version is a *reference* against the current render,
  not a description of it.

A comment carries `targetLabel` when the commenter clicked an annotated part — that string is an
element name from the view, i.e. §2's own anatomy vocabulary. Use it to go straight to the right
code. The pin's position (fraction + px) locates anything unannotated.

**Classify before you edit.** This is the step that matters, because most comments are not bugs
in the view:

| Class | What it looks like | What to do |
|---|---|---|
| **Render defect** | The view disagrees with the snapshot and the contract says what it should be | Fix the view. |
| **Fixture/data** | Geometry is right, the sample content is wrong or unrepresentative | `put_fixture` — edit the props, not the view. |
| **Declared gap** | The comment asks about something the build already reported — a **stub** (`// STUB —`), a **flagged literal**, or a `GAP —` line | **Do not "fix" it.** Reply with what the gap is and the `/d2m-component` run (or Figma export) that closes it. Inventing the missing artwork or value is exactly what these markers exist to prevent. **Resolve only if the gap is tracked somewhere durable** — an OQ on the contract, or a token row. A gap whose only record is a build report in a chat log is tracked by *this comment*: answer it and leave it OPEN, or the outstanding work vanishes with the comment. A comment that says "this should be X" is a change request, not a question, and stays open until X exists. |
| **Owner ruling** | The comment **tells you what the component should do** — a new state, a changed value, a different order, a prop that should exist. "we need a way to…", "this should be…", "make it…" | **ACT ON IT — this is the default reading of a comment.** §1a: amend the contract, then build it. Do NOT hand it back to `/d2m-component`. |
| **Spec defect** | The contract does not determine the answer **and neither does the comment** — the two disagree, or acting would contradict a *different* row's contract | Ask the owner: `reply_comment(subject, comment, text, questions: [{ question, options, recommended }])` — the contract line in `text`, one question per decision, your proposal as an option and recommended. Leave **unresolved**. Never improvise it in code. |
| **Undesigned state** | The comment **asks about** a §3 row marked `undesigned` without saying what it should be | Ask the owner with `reply_comment` + `questions` (what it should be, with options), naming the OQ it waits on in `text`. Leave unresolved. A comment that *says* what it should be is an **Owner ruling**, not this. |
| **Owner call** | It moves the token register, a token's value, or a lane-wide default — i.e. it changes something **outside this component** that other rows depend on | Ask the owner with `reply_comment` + `questions`: each option says its blast radius. Leave unresolved. |

**The default is to act.** A comment is how the owner changes this component; treating one as a
question to be routed elsewhere is the failure mode this skill exists to avoid. Reach for "leave
unresolved" only when acting would require *you* to invent something the owner has not said — not
merely because Figma has not drawn it yet.

**How to ask the owner, always:** `reply_comment(subject, comment, text, questions: [{ question, options, recommended }])`
— every question that thread needs in ONE reply, each with the answers it offers (your proposal
first, marked `recommended`), and `text` one line naming what you are waiting on. The questions
land on your reply as cards the owner answers with a click. Never ask in prose — a prose question
is never answered. Finish every other thread in the queue first, then end your turn once; the
owner's answers resume this session.

**On resume**, the prompt carries each answer by code (`OQ-C-###-r<N> — <answer>`). Read them as
rulings — an **Owner ruling** each — apply them per §1a, and reply on each thread with what changed.
An answer that reads `comment deleted` means the thread was deleted while its question was open:
drop that question — do not apply it as a ruling, and do not reply (the thread is gone).

### 1a. Acting on an owner ruling

The owner is the person every `OQ-C-###-#` is addressed to. **When they state what a component
should do, that IS the ruling the OQ was waiting for** — it is not an invention. The rule that
bars *you* from inventing a state has never barred the owner from deciding one.

What that rule still binds is **where the decision lands**: the contract stays the single source
of truth, so a ruling is written into d2m and the build follows the contract as it always does.
Never encode a ruling only in code — that leaves the view contradicting its own contract, and the
next reader "fixes" it back.

1. **Amend the contract** with `upsert_component` — the one case where this skill writes spec
   content:
   - a **new state** → a row in §3's matrix, plus whatever §2/§4 it needs;
   - a **changed value or order** → the §2 line, not a magic number in the view;
   - a **new prop** → a §4 row with a type and a default;
   - add a **§1 deviation** saying the state is owner-ruled and **not drawn in Figma**, with the
     comment's timestamp. This is what stops a later run diffing it against a snapshot that
     cannot contain it and "correcting" it away;
   - add an **OQ** for what is still open — typically "does this get a Figma symbol?" and any
     tidier model you deliberately did not take.
2. **⚠️ Never lose an existing state.** d2m keys versions and comments on a state's **id**, with
   the slug fixed at birth and the label free to change — so a relabel no longer silently re-keys
   a thread. What still orphans history is a state *disappearing* from the §3 matrix, which
   adding a column or a row makes easy to do by accident. Snapshot the state labels and slugs from
   `get_fixture(code)` **before** touching the contract, re-read after the write, and fail loudly
   if one is gone. `upsert_component` helps: a state present in the contract and absent from the
   `states` array you send is left in place and reported as a **warning** rather than dropped —
   read those warnings, and strike a state only deliberately, with `removeStates`. The guard is
   what turns that warning into a check:

   > `DB KEY LOST: "<label>" — versions and comments would orphan`

   An empty qualifier cell (`—`) keeps a row's existing identity, which is usually how to add a
   sibling state without disturbing the one beside it.
3. **Then build it** exactly as `/d2m-component-build` would: `put_fixture` for the props of the
   new or changed states, extend the view, add any decoding field (additive optional only), pass
   it at the capture call site in `project.registryCasePath`, then §2's lint + recapture.
4. **Say so in the reply and in the run report** — what the contract now says, which state is
   owner-ruled rather than designed, and which OQ carries the rest.

**When you do edit**, the same rules the build ran under still apply:

- Tokens by name. A flagged literal stays a literal with its flag comment. A value that is
  neither tokened nor contract-traceable is a spec defect — stop, don't invent it.
- Every prop value traces to §4 × §3, and its **type** is §4's: `3` and `"3"` generate different
  code. State labels are the contract's; `put_fixture` writes props only, and naming a state the
  fixture does not have is an error, never an insert.
- Never wire the view into anything; never edit the project's shipping colour, typography, page
  or routing sources; never hand-edit the generated token file — if a token must change, that is
  an `upsert_tokens` change plus a regeneration, and it is an **Owner call**, not a render fix.
- **Never nudge geometry to match the picture.** A render that cannot match is a gap to report,
  not a number to tune.
- This skill writes spec content **only to record an owner ruling** (§1a) — never to re-measure
  Figma, re-spec a row, or change the registry or the token register. Everything else is
  `/d2m-component`'s. A ruling that would move a token or another row is an **Owner call**: ask
  it per §1's *How to ask the owner, always* — `reply_comment` + `questions`, each option naming
  its blast radius — and leave it open.

## 2. Lint, then recapture

Lint first, and only if you edited code — `project.lintCmd` runs in about a second, and the
project's build enforces it anyway, so a violation would otherwise fail the render *after* the
build had already spent minutes. Never regenerate a lint baseline to silence one.

**Then recapture the states in scope — ALWAYS, before you reply to anything.** Not only the
states you changed: every run that processed at least one comment ends in a capture.

```
capture(component: "C-###", state: "<state-slug>", wait: true)   # a slug was given
capture(component: "C-###", state: "*", wait: true)              # no slug — every state
```

`capture` answers a handle, not a result. `wait: true` follows the run for up to 10 minutes and
reports its final state and the tail of its log (a single state is ~30s of renderer time; `*` is
one run per state). If it still comes back `timedOut: true`, call `capture_status(runId)` every
~30s until `state` is not `running` — never poll the filesystem or the renderer's logs by hand.
Do not reply to a comment on the strength of a run you have not seen finish.

Scope in, scope out: the slug the run was invoked with is the slug it recaptures, and a run with
no slug recaptures every state.

Why unconditionally, when a state you did not touch will render identically:

- **The reply has to be checkable.** "I changed X" is worth nothing next to a render from before
  the change. Capture is additive — a version per run, always — so the fresh version is what the
  reader opens and the pin-to-version history stays honest.
- **"I changed nothing" is a claim too.** A run that only classified and replied still asserts the
  render is current; a capture proves it rather than assuming it.
- **You are the least reliable judge of what you touched.** A token regeneration, a fixture edit
  on a shared value, a dependency's view — each reaches states you were not thinking about.
  Recapturing the scope removes that judgment call from the loop.

Two exceptions, and only two:

- a run that **stopped in §0** — no contract, no fixture, unknown slug, or zero unresolved
  comments. Nothing was processed, so there is nothing to refresh: say so and stop without burning
  a capture;
- a project with **no render lane** (`captureAdapter: noop`). There is nothing to run. Say it in
  the report and in every reply, so nobody reads a reply as evidence from a render.

`capture` needs no permission here — the skill's invocation is the permission, and it is the
renderer d2m is configured to run, nothing else. Each state is minutes; budget for it. A project
whose renderer re-runs a whole harness suite will rewrite unrelated baselines in its repo; leave
those out of any commit.

## 3. Verify, then reply + resolve

Read the new render beside the frozen snapshot and confirm the change is actually visible and did
not move anything else. On a run that changed nothing, confirm the fresh render still matches what
your replies say about it — a surprise there is a finding, not a formality. Check the render's
element map still names the parts you touched — a renamed or dropped annotation silently strips
element context from every future comment on that part.

Then, per comment: `reply_comment` (subject + comment id + text) saying exactly what changed
(file + what, or why nothing changed), then `resolve_comment` — **only** for comments you
actually acted on, and always after the reply, so the commenter can see what happened without
reading a diff. A change that did not take → reply saying so and leave it open. A reply
deliberately REOPENS a resolved thread: answering a closed comment means it was not finished.
A thread still waiting on the owner's answer stays open; its reply is the `reply_comment` +
`questions` call from §1.

## 4. Report

Project + era first. Then per state: resolved / replied-and-left-open (with the class from §1's
table) / failed verification, the files touched, and the recapture — which states, and the version
id per state, so the reader can open exactly what you looked at. Then the workbench path:
`/<project>/<era>/C-###/<state-slug>`.

If any reply named a `/d2m-component` re-run or a missing Figma export, collect those into one
list at the end — they are the work this skill deliberately did not do.

## Rules

- The invocation is the scope; everything else comes from the tools and the contract at run time.
- **A comment is how the component changes.** Acting on one is the point; routing it to another
  skill is the last resort, not the first.
- The contract is where a ruling lands, and the build follows the contract — so an owner-ruled
  state is visible to every later run instead of living as an unexplained special case in code.
- Only ever touch files under `project.previewDir`, the fixture through `put_fixture`, the
  target's own contract through `upsert_component` (§1a only), and — when a comment genuinely
  lands on the capture plumbing — `project.registryCasePath` and its decoding struct (additive
  optional fields only, named in the report).
- Never touch the rest of the project repo, never resolve a comment you did not act on.
- Commits stay the user's call — leave the working tree for review unless told otherwise.
