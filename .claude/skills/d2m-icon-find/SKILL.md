---
name: d2m-icon-find
description: Find an icon in the d2m icon library — by name, tag or description — and SHOW it. `/d2m-icon-find <query>` renders up to 12 candidates on one sheet, each with its usages, how many call sites draw it in the repo, and where its art came from. Read-only.
argument-hint: <query> [--project <slug>] [--era <key>]
---

# Icon find — $ARGUMENTS

Find the icons in this project's library that answer **$ARGUMENTS**, and show them. The query is a
name (`chevron-down`), a tag (`nav`), or a description in words ("a padlock with a keyhole").
`--project <slug>` and `--era <key>` override the scope this repo's `.mcp.json` pins. **Pass
`--project` and `--era` through to every tool call.**

## Hard rules (re-read before EVERY phase)

- **This run writes nothing.** No `put_glyph`, `tag_glyph`, `rename_glyph`, `merge_glyph`,
  `strike_glyph` or `use_glyph`, and no file in the repo. Its outputs are the report and one PNG
  in the OS temp directory.
- **At most 12 candidates are shown.** Further matches are listed by name after the sheet.
- **A merged name is not an icon.** It answers with its keeper: say "merged into `<keeper>`" and
  show the keeper.
- **Show, don't describe.** Every candidate is drawn on the sheet; a name with no picture is not an
  answer.

**At the end of every phase, print that phase's exit checklist with ✓/✗ per item.**

## 0. Load context

1. `project_info()`. **State the project slug and era key in your first report line.** Note
   `project.repoPath` and `project.previewDir` (relative to `repoPath`).
2. `list_glyphs()`: every minted icon, with its tags, notes and usage count. A pending import is
   not listed.

**Exit checklist 0:** project + era stated ✓ · library read ✓

## 1. Match

1. **Exact first.** A name equal to the query, then names that contain it, then tags equal to or
   containing it, all case-insensitive.
2. **Merged or pending.** When nothing matches and the query is a kebab-case name,
   `get_glyph(name: "<query>")`: an answer whose `name` differs is a merged name — say "merged into
   `<keeper>`" and make the keeper the candidate; `pending: true` is an import still waiting for
   art — say "pending — no art yet"; an error means there is no such icon.
3. **Descriptive.** When the query is words, read every name, tag and note in the library and pick
   the icons whose meaning answers it, closest first.
4. Keep the best 12. When nothing matches at all, say so, name the three closest by meaning, and say
   a new icon comes in from the Icons page (Add icon).

**Exit checklist 1:** exact matches first ✓ · a merged or pending name resolved ✓ · 12 or fewer
candidates ✓

## 2. Show

1. `render_glyph(names: [<the candidates>])`. Run `open "<file>"` on the `file` it answers so the
   user sees the sheet, and print that path. Never copy the PNG into the repo.
2. For each candidate, `get_glyph(name: "<name>")` for its `usages` and its origin (`source`,
   `figmaUrl`).
3. **Call sites.** Count the lines under `<repoPath>/<previewDir>` that draw each candidate, where
   `<case>` is the name in lowerCamel (`link-off` → `linkOff`). perl has the lookbehind the first
   pattern needs:

   ```sh
   find "<repoPath>/<previewDir>" -name '*.swift' -print0 | xargs -0 perl -ne 'print "$ARGV:$.:$_" if /(?<![\w.])Glyph\(\s*\.<case>\b|\bGlyphName\.<case>\b|Image\("<name>"/; close ARGV if eof'
   ```

**Exit checklist 2:** sheet rendered and opened ✓ · usages and origin read ✓ · call sites counted ✓

## 3. Report

Print these lines, then stop:

- **project + era**, first;
- **sheet** — its temp path;
- **one line per candidate** — `<name>` · tags · usages (the count, and each component or screen) ·
  call sites (the count) · origin (`source`, and the Figma URL when there is one) · its page
  `/<slug>/icons/<name>`;
- **more** — any matches beyond 12, by name;
- **next** — `/d2m-icon-tag <name> +<tag>` to tag one, `/d2m-icon-rename <name> <new-name>` to
  rename one.

**Exit checklist 3:** report printed ✓ · nothing written ✓
