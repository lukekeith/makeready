---
name: d2m-component-preview
description: Add one preview to a BUILT component from a sentence — `/d2m-component-preview <C-###> --slug <slug> --name "<name>" "<description>"`. It reads the component's contract, its existing previews and the rulebook, turns the description into values for the props the build already has, creates the preview and captures it. What the props cannot express it asks you in the terminal (await_answers on the run's own subject) — it never edits the component, its fixture or its contract. Queued by the "+" on a component's Previews column.
argument-hint: <C-###> --slug <slug> --name "<name>" "<description>" [--project <slug>] [--era <key>]
---

# Component preview — $ARGUMENTS

Make ONE new preview of one built component from the description **$ARGUMENTS** gives, and capture
it. `--project <slug>` and `--era <key>` override the scope this repo's `.mcp.json` pins. **Pass
`--project` and `--era` through to every tool call.**

## Arguments

Read them from $ARGUMENTS **outside double quotes only**:

- the **first positional** token is the component code, `C-###` (`<CODE>` below);
- `--slug <slug>` — one token, the slug the preview must take (`<slug>`);
- `--name "<name>"` — double-quoted, may hold spaces: the preview's label (`<name>`);
- the **remaining double-quoted text** is the description.

A `C-###`, `--slug` or `--name` *inside* the quoted name or description is part of that text, never
an argument. Missing code, `--slug` or `--name` → report which and stop, having written nothing.

## Hard rules (re-read before EVERY phase)

- **Two writes, in this order, each at most once:** `create_preview` in phase 4, then `capture` in
  phase 5. Nothing else writes — never the component's fixture, its contract, a preview rename or a
  preview delete, nothing in the repo, and no ruling on the contract.
- **Only the props the build has.** A key the build did not record decodes to nothing in the view's
  Swift decoding struct, so a preview that sets it renders exactly as if it did not. Use only the
  keys phase 1 lists.
- **The description never reaches a shell.** It goes only into your reasoning and tool arguments —
  never into `echo`, `printf`, a heredoc, a file name or any other bash command, because a `$`, a
  backtick or a quote in it would be expanded.
- **Never guess past the props.** What the description asks for that no prop can express is asked
  (phase 3), never approximated silently and never "fixed" by editing the component.

## 0. Scope

1. `project_info()`. **State the project slug, the era key, `<CODE>`, `<slug>` and `<name>` in your
   first report line.**
2. In a d2m run or a session? `echo "${D2M_WORK_ID:-}"` prints an id inside a run and nothing in a
   session. Phase 3 asks differently in each.

## 1. Read the component

1. `get_component(component: "<CODE>")` — its contract: §4 props (key, type, options, samples,
   purpose) and §3 states. Struck, or not built → report it and stop.
2. `get_previews(component: "<CODE>")` — every existing preview with its props: these are your
   examples of real values, and they list the **keys the build recorded** (with the fixture's own).
   **`<slug>` is already a preview → report "a preview <slug> already exists" and stop, creating
   nothing.**
3. `get_rules()` — the era's code-pattern rulings, so a value you choose (an option's spelling, an
   icon's name) follows them.

**Exit checklist 1:** contract read ✓ · the recordable keys listed ✓ · `<slug>` is free ✓ · rules
read ✓

## 2. Derive the props

Turn the description into one value per prop it touches, **keys from phase 1's list only**:

- an option prop takes one of its §4 options, spelled exactly;
- a list prop (items, rows, options) takes a list shaped like the existing previews' lists;
- a free string takes the description's own words where it gives them ("Invite Member, Send
  Message, …" are five item titles, in that order);
- a prop the description does not mention keeps the value the closest existing preview gives it, so
  the new preview differs only where it was asked to.

Write the bag out in your report before phase 3 or 4.

## 3. Out of reach → ask (preview-from-description D6)

When the description asks for something the §4 props cannot express (e.g. "without icons" on a
component with no prop that hides them), ask ONE question that names the missing prop, with options
that include making it without that part and stopping:

- **In a d2m run** (phase 0 found an id):
  `await_answers(subject: "<CODE>:preview:<slug>", questions: [{ question, options, recommended }])`
  — e.g. question "C-066 has no prop to hide its icons. Make the preview without hiding them, or
  stop?", options `["Make it without hiding the icons", "Stop"]`, `recommended: 0`. Then END YOUR
  TURN; the owner answers on this run's card in the terminal, and the run resumes with the answer.
  Never ask in prose — a prose question ends the run with nothing filed.
- **In a session:** ask the user directly and wait.

A §4 prop that phase 1's list of recorded keys does not include is out of reach too — setting it
would decode to nothing — so it is asked about the same way, naming the prop and saying the build
did not record it.

The answer **Stop** (or anything meaning it) ends the run having written nothing. Otherwise go on
with the bag the answer allows. Nothing out of reach → skip this phase.

## 4. Create

`create_preview(component: "<CODE>", label: "<name>", props: { … })` — the phase 2 bag, no
`stateSlug`, no `figmaUrl`. The answer names the slug the preview took. **It is not `<slug>` (a
preview took that slug meanwhile) → report both slugs and stop.** Never delete or rename anything
to make room.

## 5. Capture

`capture(component: "<CODE>", state: "<slug>", wait: true)`. It answers `timedOut: true` → call
`capture_status` with its run id until it is not. A capture refused because the project's capture
adapter is `noop` (no render lane) → report that the preview exists uncaptured, and stop. A failed
capture → report its error; the preview stays, and the owner can re-capture it from the workbench.

## 6. Report

One short block: the component, the preview's name and slug, the props set (and anything left out
by the owner's answer), and the capture's outcome.

**Exit checklist:** at most one `create_preview` ✓ · at most one `capture` ✓ · no other write ✓ ·
the description never in a shell command ✓
