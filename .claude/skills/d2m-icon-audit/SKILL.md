---
name: d2m-icon-audit
description: Audit the d2m icon library — `/d2m-icon-audit [--fix-tags]`. Reports unused icons, near-duplicate pairs rendered side by side, icons off the house style, and icon art in the repo that is not in the library (loose .svg files and imagesets, including c0xx-* component leftovers), each finding with the command that acts on it. Read-only, except --fix-tags, which offers one confirm to tag the off-style icons off-style.
argument-hint: [--fix-tags] [--project <slug>] [--era <key>]
---

# Icon audit — $ARGUMENTS

Audit this project's icon library and the repo's icon art. The output is a report in which every
finding carries the command that acts on it; this run acts on none of them. `--fix-tags` is the one
exception: after one confirm it tags the off-style icons `off-style`. `--project <slug>` and
`--era <key>` override the scope this repo's `.mcp.json` pins. **Pass `--project` and `--era`
through to every tool call.**

## Hard rules (re-read before EVERY phase)

- **Read-only, except `--fix-tags`.** The one write is `tag_glyph` adding `off-style`, once per
  off-style icon, only under `--fix-tags` and only after ONE confirm. Never `rename_glyph`,
  `merge_glyph`, `strike_glyph`, `put_glyph` or `use_glyph`.
- **Never edit the repo.** Reading it (`find`, `perl`) is allowed; deleting or moving a file is not.
  The report names the command that would.
- **Every finding carries its command.** A section with nothing in it says "none".
- **Confirm once** (`--fix-tags` only). In a d2m run (`D2M_WORK_ID` is set) ask through
  `await_answers` and END YOUR TURN; in a session, ask the user directly and wait.

**At the end of every phase, print that phase's exit checklist with ✓/✗ per item.**

## 0. Load context

1. `project_info()`. **State the project slug and era key in your first report line.** Note
   `project.repoPath`, `project.previewDir`, and the catalog directory: `project.glyphCatalogPath`,
   or `<project.previewDir>/Resources/Glyphs.xcassets` when that is null. Both are relative to
   `project.repoPath`.
2. `list_glyphs(includeStruck: true)`: the live names, and the struck ones.

**Exit checklist 0:** project + era stated ✓ · catalog path resolved ✓ · library read ✓

## 1. Measure the library

1. `audit_glyphs()` answers `unused`, `nearDuplicates`, `style` and `outliers`.
2. **Near-duplicates, seen.** Render the pairs, most similar first, at most 24 pairs (48 icons)
   per sheet: `render_glyph(names: ["<a>", "<b>", …])`. Run `open "<file>"` on each sheet's `file`
   and print the path.
3. For each pair, `get_glyph(name: "<a>")` and `get_glyph(name: "<b>")`: the keeper is the one with
   more usages, ties to the shorter name. Below, `<a>` is the keeper and `<b>` the other.

**Exit checklist 1:** audit read ✓ · pairs rendered and opened ✓ · a keeper chosen per pair ✓

## 2. Find repo art that is not in the library

1. **Imagesets:** `find "<repoPath>/<catalog>" -maxdepth 1 -name '*.imageset'`. One whose name
   (without `.imageset`) is a live icon is the library's. One whose name is a struck icon is
   "struck — the next sync deletes it". Every other one is not in the library; a name that is `c`
   plus three digits plus `-…` (`c072-link`) is a `c0xx-*` leftover of a component row.
2. **Loose SVG files:** `find "<repoPath>/<previewDir>" -name '*.svg' -not -path '*.xcassets/*'`.
3. For each, count the lines under `<repoPath>/<previewDir>` that draw it:
   `grep -rn --include='*.swift' 'Image("<name>"' "<repoPath>/<previewDir>"`.
4. For each `c0xx-*` leftover, `get_component(component: "C-0xx")`: is its row still live?

**Exit checklist 2:** imagesets checked ✓ · loose SVGs found ✓ · what draws each counted ✓

## 3. Fix tags — only with `--fix-tags`

Skip this phase without `--fix-tags`, or when there are no outliers.

List each off-style icon with its reasons, then ask ONE question: "Tag these `<N>` icons
`off-style`?"

- **In a d2m run:** `await_answers(subject: "icons", questions: [{ question, options, recommended }])`
  with that question, the options "Yes — tag them" and "No — leave them", `recommended` 0, then END
  YOUR TURN. Several icons are the whole library's question, so the subject is always `icons`; the
  owner answers it on this run's card in the terminal, and the run resumes with the answer.
- **In a session:** ask the user directly and wait.

On yes, for each: `tag_glyph(name: "<name>", add: ["off-style"])`.

**Exit checklist 3:** confirmed once ✓ · each outlier tagged, or none ✓

## 4. Report

- **project + era**, first;
- **House style** — sample, strokeWidth, linecap, linejoin, mode and fillRatio from `style`
  ("none yet" for a null);
- **Unused** — each name, with `/d2m-icon-delete <name>`;
- **Near-duplicates** — each pair `<a>` ≈ `<b>` with its `diff` %, and the sheet path, with
  `/d2m-icon-merge <b> --into <a>` (`<a>` the keeper);
- **Off-style** — each name and its reasons, with `/d2m-icon-tag <name> +off-style`, or "rerun with
  --fix-tags"; say which were tagged this run;
- **Repo art not in the library** — each imageset or file and how many lines draw it: "add it from
  the Icons page" when something draws it, "delete it by hand" when nothing does; for a `c0xx-*`
  imageset whose row is still live, `/d2m-component-retire C-0xx --into glyphs`.

**Exit checklist 4:** four sections printed, each finding with its command ✓ · nothing written but
`--fix-tags`'s tags ✓
