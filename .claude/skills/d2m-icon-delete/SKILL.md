---
name: d2m-icon-delete
description: Delete an icon from the d2m icon library — `/d2m-icon-delete <name>` — only when nothing uses it: no usage recorded in d2m and no call site anywhere in the repo. Then it strikes the icon with strike_glyph, or removes a pending import that never returned art. When something uses it, it strikes nothing, lists every use, and prints the /d2m-icon-merge command that folds it into another icon instead.
argument-hint: <name> [--project <slug>] [--era <key>]
---

# Icon delete — $ARGUMENTS

Delete the icon **$ARGUMENTS** from this project's library — but only an icon nothing uses. A
minted icon is struck: its name answers 404 from then on and the next sync deletes its imageset. A
pending import that never returned art is removed outright. `--project <slug>` and `--era <key>`
override the scope this repo's `.mcp.json` pins. **Pass `--project` and `--era` through to every
tool call.**

## Hard rules (re-read before EVERY phase)

- **One write: `strike_glyph`**, called once, and only when phase 1 found nothing that uses the
  icon. Never `merge_glyph` — print its command instead — and never `rename_glyph`, `tag_glyph` or
  `put_glyph`.
- **In use means no strike.** A usage in d2m, or a call site anywhere in the repo, ends the run with
  every use listed and `/d2m-icon-merge <name> --into <keeper>` printed. Nothing is struck.
- **Never touch the repo.** This run deletes no file and no imageset; the next sync deletes a struck
  icon's imageset.
- **Confirm once**, before the strike. In a d2m run (`D2M_WORK_ID` is set) ask through
  `await_answers` and END YOUR TURN; in a session, ask the user directly and wait.
- **Ending failed** means: write nothing more, print the phase's exit checklist, then print
  `✗ <reason>` as the very last line of the final message.

**At the end of every phase, print that phase's exit checklist with ✓/✗ per item.**

## 0. Load context

1. `project_info()`. **State the project slug and era key in your first report line.** Note
   `project.repoPath` and `project.previewDir`.
2. `get_glyph(name: "<name>")`:
   - a glyph named `<name>`, minted: this run strikes it;
   - a glyph named `<name>` with `pending: true`: an import that never returned art — this run
     removes it, once nothing is importing it;
   - a glyph under another name: end: "`<name>` was merged into `<keeper>` — nothing to delete";
   - an error: end failed: "no icon `<name>` in this era".

**Exit checklist 0:** project + era stated ✓ · the icon read, strike or remove decided ✓

## 1. Check what uses it

1. **In d2m:** the `usages` `get_glyph` answered — the count, and each component or screen.
2. **In the repo, everywhere**, skipping node_modules, .git, build, DerivedData, Pods, where `<case>`
   is the name in lowerCamel (`walk-probe` → `walkProbe`):

   ```sh
   find "<repoPath>" \( -name node_modules -o -name .git -o -name build -o -name DerivedData -o -name Pods \) -prune -o -name '*.swift' -print0 | xargs -0 perl -ne 'print "$ARGV:$.:$_" if /(?<![\w.])Glyph\(\s*\.<case>\b|\bGlyphName\.<case>\b|Image\("<name>"/; close ARGV if eof'
   ```

3. **Anything found:** strike nothing. Print every usage and every `file:line`, then "fold it into
   another icon instead: `/d2m-icon-merge <name> --into <keeper>` — pick the keeper with
   `/d2m-icon-find`", and end with `✗ <name> is in use — nothing struck`.

**Exit checklist 1:** d2m usages read ✓ · whole repo searched ✓ · in use → nothing struck, or
unused ✓

## 2. Confirm, then strike

1. For a minted icon, `render_glyph(names: ["<name>"])`, run `open "<file>"` on the `file` it
   answers, and print the path.
2. Ask ONE question: "Delete `<name>`? Nothing uses it."
   - **In a d2m run** (`echo "${D2M_WORK_ID:-}"` prints an id):
     `await_answers(subject: "glyph:<name>", questions: [{ question, options, recommended }])` with
     that question, the options "Yes — delete it" and "No — keep it", `recommended` 0, then END
     YOUR TURN. One icon's question is asked on that icon, `glyph:<name>` — an unused icon has no
     component or screen, and needs none; the owner answers it on this run's card in the terminal,
     and the run resumes with the answer.
   - **In a session:** ask the user directly and wait.

   Anything but yes ends the run with nothing struck.
3. `strike_glyph(name: "<name>")`. It answers `struck: true` (minted) or `removed: true` (pending).
   A refusal is reported verbatim: "… merge it instead" means something started using it since
   phase 1; "the import is still running" means cancel that import in the terminal first.

**Exit checklist 2:** confirmed ✓ · `strike_glyph` answered struck or removed, or its refusal
reported ✓

## 3. Report

- **project + era**, first;
- **deleted** — `<name>`, struck or removed;
- **next** — "the next sync deletes `<name>.imageset`" for a struck icon.

**Exit checklist 3:** report printed ✓ · nothing written but the one `strike_glyph` ✓
