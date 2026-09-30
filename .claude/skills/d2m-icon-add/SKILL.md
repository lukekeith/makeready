---
name: d2m-icon-add
description: Add ONE icon to the d2m icon library from an .svg file or inline SVG text — `/d2m-icon-add <file.svg | "<svg …>…</svg>"> [--name <name>]`. It dry-runs the art, mints it with put_glyph when it is new, and asks only when the dry-run finds a taken name, a missing name or more than one colour; art already in the library is named, not minted. A file records its path as where the icon came from. For a folder, a URL, npm or Figma, use /d2m-icon-import.
argument-hint: <file.svg | inline svg> [--name <name>] [--project <slug>] [--era <key>]
---

# Icon add — $ARGUMENTS

Add the one icon **$ARGUMENTS** gives to this project's library. The argument is a path to one
`.svg` file, or the SVG text itself. `--name <name>` names it; without it the name comes from the
file name, else from the SVG's `<title>`. `--project <slug>` and `--era <key>` override the scope
this repo's `.mcp.json` pins. **Pass `--project` and `--era` through to every tool call.**

## Hard rules (re-read before EVERY phase)

- **One write: `put_glyph`**, called at most once. Never `tag_glyph`, `rename_glyph`,
  `merge_glyph`, `strike_glyph` or `use_glyph`, and nothing in the repo.
- **The dry-run comes first.** Nothing is minted before `normalize_glyphs` has classified the art.
- **Ask only when the dry-run is not `new`.** A `new` icon is minted without a question.
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
3. `WORK=$(mktemp -d "${TMPDIR:-/tmp}/d2m-icon-add.XXXXXX")` — print the path. **Every later
   command that touches `$WORK` re-declares it first, in that same tool call**
   (`WORK=<the printed path>; …`): a tool call is a fresh shell, and shell variables do not
   survive between calls.
4. **What the argument is:**
   - **Inline SVG text** (it starts with `<svg` or `<?xml`) → write it to `$WORK/0001.svg` — an
     all-digit file name, so the dry-run never proposes the temp file's name as the icon's.
     `source: "pasted"`, no `sourceRef`.
   - **A path** → `~` is your home directory; a relative path is resolved against the session's
     working directory. It must be an existing `.svg` file of at most 1 MB.
     `source: "file"`, `sourceRef` = its absolute path.
   - Anything else — a folder, a URL, `npm:`, `d2m:` — ends failed: "add takes one .svg file or
     inline SVG — for <argument> use `/d2m-icon-import <argument>`".
5. **The name.** `--name`, which must be an icon name (lowercase kebab-case, starting with a
   letter), else ends failed: "`--name <name>` is not an icon name — lowercase kebab-case,
   starting with a letter". Without `--name`: the file name, else the `<title>`, made an icon name
   by splitting camelCase, lowercasing, turning every run of other characters into `-`, and
   dropping a leading component prefix (`c072-`) and every `icon` or `glyph` segment. No valid
   name: send none, and the dry-run answers `unnamed`.

**Exit checklist 0:** project + era stated ✓ · run or session recorded ✓ · argument read, source
recorded ✓ · name proposed or none ✓

## 1. Dry-run

`normalize_glyphs(items: [{ key, path, name }])` with ONE item: key `0001`, the absolute path of the
file (`$WORK/0001.svg` for inline text), and the name (or none). Nothing is written.

**Exit checklist 1:** dry-run answered one status ✓ · nothing written ✓

## 2. Decide — ask only when the dry-run is not `new`

- `new` → mint it without asking.
- `duplicate` → mint nothing: end with "already in the library as `<matches>` — use it, or look at
  it with `/d2m-icon-find <matches>`" — `rm -rf "$WORK"` before ending, the same cleanup as a
  failure. `put_glyph` never mints identical art twice.
- `refused` → end failed with its `rejected` verbatim.
- `unnamed` → ask for a name.
- `name-taken` → ask, with the options **Use another name** · **Replace the art of `<name>`** ·
  **Cancel**. Replace is offered **only when `matches` equals the name** — a live icon of exactly
  that name. A Swift-case clash or a reserved name offers only another name or Cancel. The
  Replace option says, because the new art is never from Figma, that its Figma node link, if it
  has one, is cleared (D15); and with `colors` > 1 on the dry-run item, that the tint flattens it
  to one colour — `name-taken` is answered before `multicolour`, so the item's `colors` is the
  only place that shows.
- `multicolour` → ask, with the options **Add it anyway — the tint flattens it to one colour** ·
  **Cancel**.

**How to ask:**

- **In a d2m run:** with `--name`, `await_answers(subject: "glyph:<name>", questions: [{ question, options, recommended }])`;
  without it, `await_answers(subject: "icons", questions: [{ question, options, recommended }])`.
  Then END YOUR TURN; the owner answers on this run's card in the terminal, and the run resumes
  with the answer.
- **In a session:** ask the user directly and wait.

A new name goes back through phase 1 before any mint. **Cancel** ends the run with nothing minted
— `rm -rf "$WORK"` before ending, the same cleanup as a failure.

**Exit checklist 2:** `new` minted without a question, or one question asked ✓ · a new name dry-run
again ✓

## 3. Mint

- A file: `put_glyph(name: "<name>", svg: "<the SVG text>", source: "file", sourceRef: "<its absolute path>")`
- Inline text: `put_glyph(name: "<name>", svg: "<the SVG text>", source: "pasted")`
- Add `replace: true` only for the **Replace the art of `<name>`** answer: that icon keeps its
  name, usages and call sites.

The answer:

- the glyph → **added** (keep its `warnings`). Continue to phase 4.
- a `note` saying `already in the library as <x>` → nothing was minted: another run minted this
  exact art, under `<x>`, in the window between the dry-run and this mint (the dry-run classifies
  first, but does not hold the name). **End here — never go to phase 4, because `<name>` was never
  minted and there is nothing to render:**
  - **project + era**, first;
  - **skipped** — duplicate of `<x>`, nothing minted;

  then `rm -rf "$WORK"`, then stop.
- a refusal → end failed with it verbatim.

**Exit checklist 3:** `put_glyph` called once ✓ · answer read ✓ · a race-window duplicate ends here,
not at phase 4 ✓

## 4. Show and report

1. `render_glyph(names: ["<name>"])`. Run `open "<file>"` on the `file` it answers, and print the
   path.
2. Print, then `rm -rf "$WORK"`, then stop:
   - **project + era**, first;
   - **added** — `<name>`, its source and `sourceRef`, and the page `/<slug>/icons/<name>`;
   - **warnings** — the normaliser's, or "none".

**Exit checklist 4:** icon shown ✓ · report printed ✓ · `$WORK` deleted ✓ · nothing written but
the one `put_glyph` ✓
