---
description: Spec ONE UI 2.0 component from a Figma component/set link — ingest every designed variant and state, resolve it against the program registry (mint a new C-### row or enrich an existing one), write the component's normative contract under docs/ui2/design-system/components/, and update the registry + tokens. The component-level sibling of /ui2-screen for when the user pastes a component link instead of a whole screen. Spec-writing only, no app code. Designed to run in a FRESH session.
argument-hint: [Figma component/set URL; optionally preceded by a C-### id or component name when amending a known row]
---

# UI 2.0 component spec — $ARGUMENTS

Spec the component **$ARGUMENTS** for the UI 2.0 program. This is the SPEC phase: output
is documentation under `docs/ui2/` only — never app code. Work ONE component (one Figma
component or variant set) per run; each phase ends with something verifiable.

**Arguments:** `<figma-url>` → spec the component at that node (mint or enrich — phase 0
decides which). `<C-### | name> <figma-url>` → target that registry row explicitly and
attach/refresh its Figma source. A URL pointing at a whole frame/screen → stop and tell
the user to run `/ui2-screen` instead; a URL pointing at ONE instance inside a frame →
resolve to its main component/set and spec that (say you did).

## How this differs from /ui2-screen

A screen run documents one *instantiation* and consumes components; this run documents
the *whole component*: every designed variant and state, the full prop contract, and its
place in the registry. It writes no screen spec, adds no screen-map node, and touches the
README only if a registry-level fact recorded there goes stale. An owner-pasted component
link is an explicit designation that the component is real — this refines DECISIONS.md D9
(the sheet is not wholly normative, but an owner-designated set is) — record the
designation in the contract.

## Hard rules (re-read before EVERY phase)

- **Docs only.** Writes under `docs/ui2/` exclusively.
- **Figma is normative** (D5): cite node URL + frozen snapshot(s) + capture date;
  deviations are a CLOSED enumerated list ending "anything else that differs from the
  source is a defect". Banned phrasings per build-spec REFERENCE.md §3c.
- **Registry discipline** (D6): exactly one row per component — mint the next `C-###`
  only after proving no existing row covers it (check names AND anatomy — a geometry
  variant of an existing row is an amendment or a consolidation OQ, never a duplicate).
  Check the legacy candidate pool (`iphone/MakeReady/Components/`,
  `docs/ui/COMPONENT_INVENTORY.md`) before minting `new`.
- **Naming & scoping rules** (registry rules header) apply in full — role-based name,
  family suffix, no collisions; renames propagate via grep the same run.
- **Tokens by name** (D7): new Figma variables become token rows; raw values become
  tokens or flagged literals — never silent.
- **One component per run.** A session may loop to another only if the user says so.

**At the end of every phase, print that phase's exit checklist with ✓/✗ per item.** Do
not advance with an ✗ — fix it or surface why.

## 0. Load context

1. Read `docs/ui2/design-system/registry.md` — the full rules header and every category
   section (you are about to search it for an existing row).
2. Read `docs/ui2/design-system/tokens.md` (populated families) and
   `docs/ui2/DECISIONS.md` (all of it).
3. Resolve the target: does a registry row already cover this node/set (match by Figma
   ref, by name, or by anatomy)? → this run **enriches** that row (read its "Defined in"
   contract first — screen-spec §4 subsection or an existing component file — and carry
   it forward, never restart). No row → this run **mints**.
4. If the row's contract lives in a screen spec's §4, this run MAY relocate it: the new
   component file becomes the contract, the screen spec's §4 subsection is replaced by a
   pointer line, and the registry "Defined in" is repointed. Relocate only when the
   component file adds material the screen section lacks; otherwise the component file
   supplements and cross-links.

**Exit checklist 0:** registry + tokens + DECISIONS loaded ✓ · target resolved to
mint-or-enrich with the existing contract read ✓ · not actually a screen URL ✓

## 1. INGEST — capture the whole set

1. `get_metadata` on the node → if it's a variant set, enumerate every symbol (name =
   the variant-prop assignment). If it's a lone component, note that.
2. `get_screenshot` → save to `docs/ui2/design-system/components/assets/C-###-<name>.png`
   (one image of the whole set where possible; `-<variant>` suffixes otherwise). Frozen
   snapshot rule per D5 — a later Figma edit is a visible re-spec event.
3. `get_variable_defs` → diff against tokens.md; append new tokens (D7 naming, cite the
   variable). Raw values → token row or flagged literal.
4. `get_design_context` on the set (or per-variant for large sets) → geometry, spacing,
   typography, and the variant-prop type (`state?: ...` unions are the axis evidence).
5. Also probe the component sheet (`3632:4502`) copy of this component if the given node
   lives elsewhere — the sheet may hold MORE variants than the pasted node (grep a saved
   metadata dump or drill into the set node).

**Exit checklist 1:** node + snapshot(s) + date pinned ✓ · every variant symbol
enumerated ✓ · token diff folded into tokens.md ✓ · no unexplained raw values ✓

## 2. RESOLVE — variants, sub-components, naming

1. **Full state/variant matrix.** List every axis × value the source designs. For each:
   consumed already (by which screen), designed-unconsumed, or newly designed. States
   the contract needs but the source doesn't design (pressed/disabled/empty/error…)
   become **proposed defaults + an OQ** — never stated as fact.
2. **Sub-components:** every nested element resolves to a registry row (existing —
   append this component to its Consumed-by — or a justified mint). No element without
   a row.
3. **Naming & scoping check** on the row being minted/enriched AND its sub-components;
   renames propagate now.
4. Ambiguities → ask the user ONE at a time; deferred answers become OQ rows in the
   contract file (`OQ-C-###-#`).

**Exit checklist 2:** matrix complete with per-variant consumption status ✓ ·
sub-components resolved ✓ · naming check passed ✓ · ambiguities asked or parked ✓

## 3. WRITE — the component contract

Write `docs/ui2/design-system/components/C-###-<kebab-name>.md` (an empty section means
"verified none", never "didn't look"):

```markdown
# C-### <Name> — <one-line role>

Status: <new | existing | existing-modified> · Specced: <date> · Owner-designated: <how
this run was invoked>

## 1. Normative source
Figma set/node URL + id + snapshot file(s) + capture date; sheet copy if distinct.
**Deviations (closed list):** …then "Anything else that differs from the source is a defect."

## 2. Anatomy & geometry
Structure, dimensions, spacing, typography — token names only; literals flagged.

## 3. Variant & state matrix
The CLOSED table: every axis × value, its geometry delta, and its consumption status
(consumed-by screen / designed-unconsumed / proposed-default+OQ). End with the sentence
"Variants not in this table may not be built without a ruling."

## 4. Props contract
Name, type, purpose per prop; how variants map to props.

**Never restate another row's value set.** A prop that takes a set owned by another
component cites the row — `C-021 glyph`, or `[C-021 glyph]` for a list — and the options
resolve from that contract (`preview-build.md` §3 rule 5). Copying the values in is a spec
defect: the copy drifts the moment the owner adds one.

## 5. Composition
Sub-component registry rows consumed (IDs), and which rows/screens consume THIS component
(known + anticipated).

## 6. Open questions
OQ-C-###-# rows: question, blocks?, who decides.
```

**Exit checklist 3:** all 6 sections filled ✓ · deviation list + matrix closed with
their defect/ruling sentences ✓ · every referenced ID exists in the registry ✓

## 4. UPDATE — registry last

1. `docs/ui2/design-system/tokens.md` — re-verify phase-1 additions.
2. Screen specs — if the contract relocated (phase 0.4), land the pointer edits; if this
   run changed a consumed variant's status, annotate the consuming spec's state-coverage
   line.
3. `docs/ui2/design-system/registry.md` — **the last act**: row minted or amended
   (dated closed change list), "Defined in" → the new contract file, Figma ref updated,
   Consumed-by honest (may be empty — that's fine for an owner-designated pre-spec;
   screens append later).
4. Tell the user: the row (ID + name + mint/enrich), the variant matrix headline (N
   variants, which are unconsumed), new tokens, open OQs, and any consolidation flags
   raised.

**Exit checklist 4:** tokens ✓ · consuming specs consistent ✓ · registry updated last
with honest Defined-in/Consumed-by ✓ · user told ✓
