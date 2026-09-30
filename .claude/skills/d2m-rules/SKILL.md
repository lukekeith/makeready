---
name: d2m-rules
description: Recommend or derive the era's code-pattern rules — never rule them. `analyze` reads the project (intake answers, the views already in previewDir, a few contracts, the D# register) and recommends one option per catalog decision with evidence, in ONE put_rule_recommendations call. `derive R-##` works out a derived decision's options from the project itself (R-13's type-name affix, R-38's domain glossary) and writes them with put_rule_step_options. The owner rules in the workbench. Started by the d2m rules page. Designed to run in a FRESH session.
argument-hint: <analyze | derive R-##> [--project <slug>] [--era <key>]
---

# Code-pattern rules — $ARGUMENTS

Run **$ARGUMENTS** against this project's era. This is the RECOMMEND phase of the rules: the
output is a recommendation per decision, or a derived decision's options, on the era's rules in
**d2m** — never a ruling, never a spec, never a file. The run ends when its one write has been
made and the report printed.

**Arguments:** `analyze` → one recommendation for every decision the owner has not ruled.
`derive R-##` → 2–4 options for that one derived decision. Anything else → stop and print the
two forms.

`--project <slug>` and `--era <key>` override the scope this repo's `.mcp.json` pins. The d2m
app appends them to the prompt it submits. **Pass them through to every tool call.**

## Hard rules (re-read before EVERY phase)

- **Never rule.** `analyze` writes exactly once, with `put_rule_recommendations`; `derive`
  writes exactly once, with `put_rule_step_options`. Never `rule`, never `skip_rule`, never
  `add_decision`, never a file in the project repo. Recommending is the run's whole job; ruling
  is the owner's click.
- **Evidence or the ★.** A recommendation that disagrees with the catalog's ★ cites a
  `file:line` under `project.repoPath` where the code already does it, a `D-##` that implies it,
  or an intake answer (`intake: tests = snapshot`). With none of those, recommend the ★ and say
  so — the ★ already follows the era's rulings through each decision's `recommendedWhen`.
- **Ruled rows are not yours.** `get_rule_catalog()`'s `rows` say which decisions are `ruled`
  (and `skipped`); leave both out of the items. A `ruled` row the tool keeps and reports in
  `keptRuled`; a `skipped` row it would OVERWRITE to `recommended`, undoing the owner's skip — so
  the filter is yours. A `retired` decision has no options: never recommend on it.
- **Read the repo; do not run it.** `analyze` greps and reads Swift under `project.previewDir`
  and the shipping app; it never builds, lints, syncs or captures.
- **Real names only.** A derived option's samples use registry names from `list_components()`
  and types that exist in the repo — never `Foo`, never a name the project does not have.

**At the end of every phase, print that phase's exit checklist with ✓/✗ per item.**

## 0. Load context

1. `project_info()` — **state the project slug and era key in your first report line.** Keep
   `repoPath`, `previewDir`, `codeFlavor`.
2. `get_rule_catalog()` — every decision with its options, pros, cons, `instruction`,
   `recommendedWhen` and `derived` prompt, without sample code; and `rows`, the era's status
   per decision (`unruled` / `recommended` / `ruled` / `skipped`). A row also carries
   `derivedOptions` — the options a derive run produced, which REPLACE the catalog's for that
   decision in the owner's wizard; null until a derive lands.
3. `get_rules()` — the rulebook as a skill reads it: `ruled` (obeyed today), `defaulted`
   (the ★ today), and `intake` — the owner's six questionnaire answers (`codebase`, `team`,
   `tapOwner`, `strictness`, `tests`, `a11y`), null when the intake was skipped.
4. `get_decisions()` — the D# register in full; a D# is evidence.

**Exit checklist 0:** project + era stated ✓ · catalog + rows read ✓ · rulebook + intake read ✓ ·
D# register read ✓ · argument is `analyze` or `derive R-##` ✓

## A. analyze

### A1. Sample the project

1. **Existing views.** List the Swift files under `project.previewDir` (all of them) and, when
   the intake says `codebase: existing`, up to twenty view files from the shipping app outside
   `previewDir` (prefer files whose names match registry names). With `intake: null` sample the
   shipping app the same way, up to twenty files; only `codebase: greenfield` skips it. Read them. For each catalog
   group note, with a `file:line`, how the code already answers the group's questions: who owns
   state (`@Binding` / value + callback / `@State` inside), how actions leave (closures per
   action, an action enum, a delegate), how variants are typed (enum / Bools / String), how
   styling is applied (modifiers / style structs / raw values), how files are laid out, how
   callbacks, booleans and acronyms are spelled, and which domain words the types use.
2. **A few contracts.** `list_components()`, then `get_component(component: "C-###")` for up to
   five rows that have a contract — the §4 prop tables show the shapes the specs already assume.
3. **The register.** From `get_decisions()`, every D# whose topic or text bears on a decision
   (naming, state, styling, files). Quote the D# id as evidence.

**Exit checklist A1:** views read with file:line notes per group ✓ · ≤ 5 contracts read ✓ · D#s
bearing on decisions listed ✓

### A2. Pick one option per decision

For every decision in the catalog that is not `ruled`, not `skipped` and not `retired`:

- Start from the ★ in `get_rules().defaulted` for that decision (it already applies the era's
  rulings and the intake).
- Move off it only with evidence (Hard rules): the code does the other thing in two or more
  views (`confidence: high`), in one view or by a D# (`medium`), or an intake answer argues for
  it and nothing in the code contradicts (`low`). Keeping the ★ with no contrary evidence is
  `high` when two or more views already do it, `medium` otherwise.
- `why` is one line naming what argued for the pick. `evidence` is the list of `file:line`,
  `D-##` and `intake: key = value` strings; empty only when the pick is the ★ and nothing
  argued otherwise.
- A derived decision whose row carries `derivedOptions` is recommended among THOSE — its ★ is
  the derived option marked `recommended`, and `get_rules().defaulted` names it too; a catalog
  option id is wrong for such a row and the page cannot show it.
- A `derived` decision with no `derivedOptions` on its row has only the catalog's options to
  pick from; recommend among those, and note in the report that `derive R-##` would ground it.
- Naming decisions read the spelling the code uses most; a tie keeps the ★.

**Exit checklist A2:** one item per eligible decision ✓ · every non-★ pick has evidence ✓ ·
confidence set per the scale ✓ · no ruled, skipped or retired id in the list ✓

### A3. Write once, then report

1. `put_rule_recommendations(items: [...])` — ONE call with every item. Read the answer:
   `keptRuled` (ids you should not have sent — fix your filter next time) and `unknown` (ids
   the catalog does not know — a typo).
2. **Report to the user**, leading with the picks that DISAGREE with the ★:
   - **project + era** — first line;
   - **against the ★** — each `R-## title: <option> (★ was <option>)`, its why, its evidence;
   - **with the ★** — each `R-## title: <option>` with its confidence, one line each;
   - **left alone** — ruled and skipped ids, and any `retired`;
   - **derive would help** — each derived decision still on catalog options;
   - **the answer** — `keptRuled` and `unknown`, if either is non-empty.
   Then STOP. The owner rules on the page; **Accept all recommendations** is theirs to click.

**Exit checklist A3:** put_rule_recommendations called once ✓ · answer read, keptRuled + unknown
reported ✓ · report leads with disagreements ✓ · nothing else written ✓

## B. derive R-##

### B1. Read the decision

1. From `get_rule_catalog()`, the decision `R-##`. It must carry a `derived` prompt (a string;
   null means not derived) — otherwise stop: `R-## is not a derived decision — its options are
   the catalog's`. Its row must not be `ruled` on a derived option (the tool refuses that; say
   so and stop).
2. The prompt is the brief. Today's two: **R-13** (type and file naming: is an affix needed to
   avoid collisions with the shipping app?) and **R-38** (the domain glossary: one word per
   concept). Read its current catalog options too — the derived ones replace them in the
   owner's wizard, so they must cover at least what the catalog's did.

### B2. Sample the project for that brief

- **R-13:** `get_registry_rules()` for the naming rules; `list_components()` for every registry
  name; grep the shipping app under `project.repoPath` (outside `previewDir`) for `struct|class|enum <Name>`
  declarations matching those names. The collisions, with `file:line`, are the evidence for or
  against an affix, and the affix (if any) is filled in from what the shipping app already uses.
- **R-38:** `list_components()` for the registry's names; the views under `previewDir`; the API
  models in the shipping app (grep `Codable|Decodable` types under `project.repoPath`). List the
  domain concepts — the things the app is about (a program, a lesson, a learner…), not UI parts —
  and, for each, the word the registry uses, the word the API uses, and any third word a screen
  uses. That table is the evidence.

**Exit checklist B2:** evidence gathered with file:line ✓ · (R-38) concept table: concept ×
registry word × API word ✓

### B3. Shape 2–4 options

Each option in the catalog's own shape: `id` (kebab), `label`, `summary`, `recommended`
(exactly one true), `pros`, `cons`, `samples.swift` (≥ 1, each `{ title, code, caption? }`),
`instruction` (the one sentence a skill obeys), `idealFor` (≤ 4 chips, optional).

- Samples are the SAME source across the options of one decision, differing only in what the
  decision decides — the owner reads the difference, not a new snippet per option. Use real
  registry names. Naming slots are allowed and preferred so the page and the rulebook spell them
  under the era's rulings: `{cb:tap}` (callback), `{bool:selected}` (boolean), `{acr:url}`
  (acronym), `{term:program}` / `{Term:program}` (a domain word, camel / Pascal) — the spec's
  slot grammar is lowercase words inside the braces.
- **R-38 options carry `terms`:** every option maps the SAME concept keys to one lowercase word
  or phrase each (`{ program: 'study program', lesson: 'session' }`); a `{term:program}` slot in
  a sample renders to that option's word. The recommended option is the vocabulary the
  evidence supports (the registry's, unless the code overwhelmingly uses the API's).
- **R-13 options** fill the affix in: an option's `instruction` names the exact prefix or suffix
  (`Views are named <Registry name> with the suffix View: FilterChipView`) or says plain.

**Exit checklist B3:** 2–4 options ✓ · exactly one recommended ✓ · same source across samples,
real names ✓ · (R-38) `terms` on every option, same keys ✓ · instruction is one obeyable
sentence per option ✓

### B4. Write once, then report

1. `put_rule_step_options(decisionId: "R-##", options: [...])` — ONE call. The tool validates
   the shape and refuses a decision that is not derived; fix and re-send only on a validation
   error.
2. **Report:** project + era; the decision; each option as `label — summary`, ★ on the
   recommended one; the evidence table (B2); and the sentence: `the owner rules on the page —
   Work out the options is done`. Then STOP.

**Exit checklist B4:** put_rule_step_options called once ✓ · options echoed with the ★ marked ✓
· evidence shown ✓ · nothing else written ✓
