# Phase A — The rule  ·  app: iphone (docs only)

> Part of docs/features/state-management/. Preconditions: none — first phase.

## Goal

`iphone/.claude/CLAUDE.md` states where server-derived data must live, so a developer (or an agent)
can classify a new collection without inferring the answer from which types happen to have an
`EntityStore`. Nothing in the app changes.

## Companion skills

None — this is a documentation phase.

## Tasks

- [x] A.1 *(2026-08-01)* Add the rule to `iphone/.claude/CLAUDE.md`, beside the existing "WRONG patterns" block —
      files: `iphone/.claude/CLAUDE.md` · spec: [README](README.md) § The rule · tests: none (docs)
      - state all four clauses: what must live in `AppState`; an Action mutates state rather than
        returning collections; a mutation refreshes derived state in the same call; genuinely
        screen-local state stays local
      - include the two counter-examples verbatim so the rule can't be over-applied:
        `ProgramHomePage.editTags` (in-flight edit buffer) and `Dragula.draggedItems` (pure UI
        state) are **correct** as `@State`
      - name the two hosting shapes: `EntityStore` when the data has identity, a plain
        `@Observable` property when it is a reference list (`AppState.swift:339-358`)
      - **add the clearing clause** — every new `AppState` collection is cleared in
        `clearInMemory()` (`AppState.swift:736-776`); org-scoped data left behind leaks across
        sign-out (this is what G2 found)

## Phase gates

- [x] None — no code changes, nothing compiled changed. `ios:build-check` deliberately **not** run
      (it would prove nothing about a markdown edit and costs a simulator build).

## Verification checklist

- [x] A reader with no context can take a new `@State private var xs: [SomeModel] = []` and decide
      from the doc alone whether it must move — the **3-step test** (is it server data? can another
      screen read it? can any screen mutate it?) is stated explicitly at
      `iphone/.claude/CLAUDE.md:297+`
- [x] The two counter-examples are present verbatim (`editTags`, `draggedItems`) with ✅ CORRECT
      markers, so the rule reads as a boundary rather than "migrate everything"
- [x] The clearing clause is present — the part the codebase's own exemplar (`textThemes`) gets
      wrong
- [x] Both hosting shapes are shown as code (`EntityStore` vs plain `@Observable`), so the reader
      doesn't have to infer which to use
- [x] Placement: immediately after the **❌ WRONG Patterns** block, where a reader hitting
      "don't store app data in local `@State`" next reads "…so where does it go?"
- [x] Spec parity spot-check — **drift found and fixed**: the shipped doc gained a clearing clause
      that [README](README.md) § The rule didn't have. Rather than dropping it, the spec was updated
      (dated, attributed to G2/D2) so the contract and the shipped text agree. Verified by reading
      both side by side

## VERIFIED

✅ **2026-08-01** — Task A.1 complete. No gates applicable (docs-only phase; no compile, no
simulator). All six verification items walked against the shipped file. One finding during the walk:
spec-vs-shipped drift on the clearing clause, resolved by adding the clause to
[README](README.md) § The rule rather than removing it from the app doc — the audit had established
it (G2) and a decision had accepted it (D2), so the spec was the thing that was behind.

**Commit:** offered, not yet taken — see the ledger.
