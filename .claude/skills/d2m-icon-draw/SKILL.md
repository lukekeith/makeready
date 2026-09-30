---
name: d2m-icon-draw
description: Draw a new icon for the d2m icon library from a description alone — `/d2m-icon-draw "<description>" [--name <name>] [--tag <t>]…`. It reads the library's measured style, hand-writes three SVG variants on the 24 grid in that style, looks at each one through render_glyph and fixes what reads badly, opens a contact sheet of the three beside the nearest library icons, and mints the one you pick with put_glyph (source generated). You can ask for a revision round instead of picking. To redraw an existing icon, use /d2m-icon-replace <name> --draw.
argument-hint: "<description>" [--name <name>] [--tag <t>]… [--project <slug>] [--era <key>]
---

# Icon draw — $ARGUMENTS

Draw one icon from the description **$ARGUMENTS** gives, in the style the library already has, and
mint the variant the owner picks. `--name <name>` names it; without it a name is proposed from the
metaphor. `--tag <t>` (repeatable) tags the minted icon. `--project <slug>` and `--era <key>`
override the scope this repo's `.mcp.json` pins. **Pass `--project` and `--era` through to every
tool call.**

## Hard rules (re-read before EVERY phase)

- **One write: `put_glyph`**, called at most once, in phase 4. Never `tag_glyph`, `rename_glyph`,
  `merge_glyph`, `strike_glyph` or `use_glyph`, and nothing in the repo.
- **Never mint before the choice.** Phase 3's question is answered before phase 4 starts; a run
  that has not heard **1**, **2** or **3** mints nothing.
- **Never edit a variant after the choice.** The file the owner picked is what `put_glyph` gets,
  read from disk; it is never re-typed from memory or "tidied".
- **The description never reaches a shell.** It goes only into tool arguments (`sourceRef`, the
  question text) and this transcript — never into `echo`, `printf`, a heredoc, a file name or any
  other bash command, because a `$`, a backtick or a quote in it would be expanded.
- **Every variant is a file.** `$WORK/r<round>-<n>.svg`, written with the Write tool (not a shell
  redirect), rendered by `path`, and minted from its text — written and cited by its absolute path
  (the one `mktemp` printed), never the literal `$WORK/…`, because the Write tool and a tool's
  `path` argument do not expand shell variables. A resume that finds `$WORK` missing ends the run
  failed: "the draft files are gone — run it again".
- **One temp directory.** Phase 0 makes it with `mktemp -d`; delete it with `rm -rf "$WORK"` at
  the end — and on every failure, before the `✗` line. **`$WORK` does not survive between tool
  calls — every command that touches it starts `WORK=<the printed path>;` in that same call.**
  Never rely on an earlier command's `WORK=` assignment still being set.
- **Ending failed** means: print the phase's exit checklist, run `rm -rf "$WORK"`, and make
  `✗ <reason>` the last line.

**At the end of every phase, print that phase's exit checklist with ✓/✗ per item.**

## 0. Load context

1. `project_info()`. **State the project slug and era key in your first report line.**
2. In a d2m run or a session? `echo "${D2M_WORK_ID:-}"` prints an id inside a run and nothing in a
   session.
3. `WORK=$(mktemp -d "${TMPDIR:-/tmp}/d2m-icon-draw.XXXXXX")` — print the path. **Every later
   command that touches `$WORK` re-declares it first, in that same tool call**
   (`WORK=<the printed path>; …`): a tool call is a fresh shell, and shell variables do not
   survive between calls.
4. **The description** is every token of the arguments that is not a flag or a flag's value,
   joined by single spaces — the quoted text when it was quoted, the bare words otherwise. Empty →
   end failed: "give a description — `/d2m-icon-draw \"a bell with a slash through it\"`". Keep
   the original text for `sourceRef`, truncated to 2048 characters.
5. **The name.** With `--name`, it must be an icon name — lowercase kebab-case, starting with a
   letter (`isGlyphName`) — else end failed: "`--name <name>` is not an icon name — lowercase
   kebab-case, starting with a letter". A bad name would also break this run's own question: the
   run's subject is `glyph:<name>`, and `await_answers` refuses a subject that is not a name.
   Without `--name`, propose a **1–3 word** kebab-case name for the metaphor, not the sentence
   ("a bell with a slash through it" → `bell-slash`, never `a-bell-with-a-slash-through-it`), and
   check it with the same `isGlyphName` rule.
6. **Is the name free?** `normalize_glyphs(items: [{ key, svg, name }])` with ONE item: key
   `name`, a placeholder `svg` of `<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="1"/></svg>`,
   and the name. Read its `status`: `new` → the name is free; `name-taken` → taken; anything else
   (`duplicate`, `refused`) means the check never reached the name — treat it as free here, because
   phase 4 re-checks before the mint. With `--name`, ask
   once (phase 3's "how to ask", subject `glyph:<name>`): **rename-to** (free text, checked the
   same way and dry-run again) · **Cancel**. **Never offer to replace `<matches>`'s art** —
   redrawing an existing icon is `/d2m-icon-replace <matches> --draw "<description>"`, which keeps
   its usages on purpose. Without `--name`, propose a different name yourself and check again, up
   to 3 tries, then ask the same question.
7. **The style.** `audit_glyphs()` — keep its `style`: `sample`, `strokeWidth`, `linecap`,
   `linejoin`, `mode`, `fillRatio`. The paint and stroke every variant uses (D8):
   - `sample` < 5 or `mode` null → **stroked**: `stroke="currentColor" fill="none"`,
     `stroke-width="2"`, `stroke-linecap="round"`, `stroke-linejoin="round"` — 2 · round · round.
   - `mode` `stroked` or `mixed` → **stroked**, with `stroke-width` = `strokeWidth`, linecap =
     `linecap`, linejoin = `linejoin`, each falling back to 2 / round / round when it is null.
   - `mode` `filled` → `currentColor` fill, no stroke: `fill="currentColor"`.
   `strokeWidth` is the library's median effective width; `linecap` and `linejoin` are its majority
   values. `fillRatio` (median art-box area ÷ 576) says how much of the grid the library's icons
   fill — match it.
8. **The library.** `list_glyphs()` — keep every item's `name`, `tags` and `usages.count`. Choose
   up to four **neighbours**: live glyphs whose name or tags share a word with the description
   (word by word, ignoring `a`, `an`, `the`, `with`, `of`, `and`); fill any empty slot with the
   most-used remaining glyphs, so the sheet always has a style reference. Fewer than four glyphs
   in the library → all of them.

**Exit checklist 0:** project + era stated ✓ · run or session recorded ✓ · `$WORK` made ✓ ·
description read and non-empty ✓ · name valid and free (or the question asked) ✓ · style read and
the paint chosen ✓ · neighbours chosen ✓

## 1. Draw three

Round `r` starts at 1; a **Revise** answer starts the next round here with the feedback.

Write **three variants** that differ in metaphor or composition — not just in stroke — each to
`$WORK/r<round>-<n>.svg` (n = 1, 2, 3) with the Write tool. **Every variant must satisfy this
checklist:**

- an `<svg viewBox="0 0 24 24">` root — the 24 grid, no `width`/`height`, no `<style>`, no
  `<defs>`, no `<g transform>`;
- the art sits inside the 2–22 box (2 px padding on every side); its extent matches the library's
  `fillRatio`;
- it uses only `path`, `circle`, `rect`, `line`, `polyline`, `polygon` and `ellipse`;
- one paint, from phase 0's D8 choice: either `stroke="currentColor" fill="none"` with the chosen
  `stroke-width`, `stroke-linecap` and `stroke-linejoin` on every element, or `fill="currentColor"`
  with no stroke — never both, never a literal colour;
- stroked art has no stroke thinner than the median; filled art has no counter narrower than
  1.5 px at 24 px;
- it is recognisable as the description at 24 px, and optically centred.

Then the dry-run, **with no `name`**, one item per variant:
`normalize_glyphs(items: [{ key, path }])` with keys `1`, `2`, `3` and the absolute file paths.
Nothing is written. A variant **passes** when its `status` is none of `refused`, `duplicate` or
`multicolour` and its `colors` ≤ 1 — the tool names a `path` item from its file name, so expect
`new` (or `name-taken` when a library icon is called `r1-1`), and `unnamed` for art it cannot name;
none of those is a failure, because the name is settled in phase 0 and used in phase 4.
`duplicate` means the art is byte-identical, after normalisation, to a library icon
(`matches`) — that variant fails. `refused` fails with its `rejected`; `multicolour` fails.

**Exit checklist 1:** three files written ✓ · each differs in metaphor or composition ✓ · dry-run
answered for all three ✓ · every variant meets the checklist, or its failure is noted ✓

## 2. Self-check

For each variant that passed the dry-run:
`render_glyph(svgs: [{ label, path }], sizes: [24, 48, 96])` with ONE cell, labelled `<n>`, by
path. Judge the 96 px cell for detail and the 24 px cell for legibility, against this fixed list:

- recognisable as the description at 24 px;
- no stroke thinner than the median (stroked) — no hairlines from a scaled path;
- no gaps under 1.5 px at 24 px between strokes or counters — they close into a blob;
- optically centred — not just bounding-box centred;
- not a near-duplicate, by eye, of any neighbour from phase 0 (phase 1's `duplicate` catches only
  identical art).

A variant listed in `missing` by `render_glyph` counts as a failed pass. A variant that fails is
**redrawn** to the same file and dry-run again (phase 1's rules), **up to 3 passes** each. One still
failing after 3 passes is kept on the sheet **with its failure noted** and is **not offered as a
pick**. Never ask the owner anything during the self-check.

**Exit checklist 2:** each passing variant rendered at 24/48/96 and judged ✓ · failed ones redrawn,
up to 3 passes ✓ · every variant either passes or carries a noted failure ✓

## 3. Sheet and choice

1. **The sheet** — ONE call, **at most 8 cells** (above 8 the tool draws 48 px only):
   `render_glyph(names: ["<neighbour>", …], svgs: [{ label, path }, …], sizes: [24, 48, 96])` —
   the neighbours as `names` (the tool draws `names` first, each labelled with its glyph name),
   then the three variants as `svgs` labelled `1`–`3` — from round 2 on, `r<round>·<n>`, so a
   later sheet is never confused with an earlier one. Run `open "<file>"` on the `file` it answers
   and print the path (icon-manage D8). Say which cells, if any, are shown with a noted failure.
2. **ONE question, per round** — the options are the passing variants' numbers, then **Revise**,
   then **Cancel**: with all three passing, **1** · **2** · **3** · **Revise** · **Cancel**. From
   round 2 on the question names the round ("round 2: 1 · 2 · 3 · …") so the digits match the
   sheet's `r<round>·<n>` labels. When none passes the options are **Revise** · **Cancel** only.
   `recommended` is the 0-based index in `options` of your best variant — with options `["1", "3",
   "Revise", "Cancel"]`, variant 3 is `recommended: 1` (or the index of Revise when none passes).
   **Only the current round's three are pickable**; feedback
   may refer back ("like round 1's 2"). **From round 3 on, the question says** that every round
   adds a self-check render and a sheet to this run's context, so a long chain may run out of room.
   - **In a d2m run** (phase 0 found an id): with `--name`,
     `await_answers(subject: "glyph:<name>", questions: [{ question, options, recommended }])`;
     without it,
     `await_answers(subject: "icons", questions: [{ question, options, recommended }])`.
     Then END YOUR TURN; the owner answers on this run's card in the terminal, and the run resumes
     with the answer. On resume, `WORK=<the printed path>; ls "$WORK"` first — missing → end
     failed, per the hard rule.
   - **In a session:** ask the user directly and wait.
3. **Revise** asks ONE free-text follow-up the same way (no options): "What should change?" The
   answer is the feedback for the next round → **phase 1**, round + 1, keeping the same name and
   the same neighbours. There is no round cap.
4. **Cancel** ends the run with nothing written — `rm -rf "$WORK"` before ending, the same cleanup
   as a failure.
5. A number → the pick. Note the file: `$WORK/r<round>-<n>.svg`.

**Exit checklist 3:** sheet opened, path printed ✓ · one question asked, one answer read ✓ · a
number picked, or a Revise round started, or cancelled ✓

## 4. Name re-check and mint

1. **Re-check right before the write** — the library may have changed while the run was parked:
   `normalize_glyphs(items: [{ key, path, name }])` with ONE item: key `pick`, the picked file's
   path, and the name. `new` or `multicolour` (impossible here, but not a stop) → mint.
   `name-taken` → phase 0 step 6's question (rename-to · Cancel) and this step again.
   `duplicate` → end: "another run minted this exact art as `<matches>` while you chose — nothing
   minted"; `refused` → end failed with `rejected`.
2. **Mint** — the picked file's text, read from disk, unchanged:
   `put_glyph(name: "<name>", svg: "<the picked file's text>", source: "generated", sourceRef: "<the description>", tags: ["<each --tag>"])`
   Leave out `tags` when there is no `--tag`; there is never a `license`. `sourceRef` is the
   original description (truncated to 2048 characters) — Revise feedback is not recorded.
3. The answer: the glyph → **drawn** (keep its `warnings`). A `note` saying `already in the library
   as <x>` → nothing was minted: end with "not minted — identical to `<x>`", `rm -rf "$WORK"`,
   stop. A refusal → end failed with it verbatim.

**Exit checklist 4:** name re-checked ✓ · `put_glyph` called once, with the picked file's text ✓ ·
answer read ✓

## 5. Report

Print, then `rm -rf "$WORK"`, then stop:

- **project + era**, first;
- **drawn** — `<name>`, "from a description", round `<r>` variant `<n>`, and the page
  `/<slug>/icons/<name>`;
- **tags** — the `--tag` values, or "none";
- **warnings** — the normaliser's, or "none".

**Exit checklist 5:** report printed ✓ · `$WORK` deleted ✓ · nothing written but the one
`put_glyph` ✓
