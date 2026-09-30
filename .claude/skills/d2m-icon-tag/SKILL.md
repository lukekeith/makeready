---
name: d2m-icon-tag
description: Tag icons in the d2m icon library, or set an icon's notes — one icon or many. `/d2m-icon-tag close +nav -old`, `/d2m-icon-tag arrow-* +direction`, `/d2m-icon-tag close --notes "the dismiss mark"`. A glob matches live icons only; more than one match is listed and confirmed once. Writes tags and notes only, with tag_glyph.
argument-hint: <name|glob>… [+tag] [-tag] [--notes "<text>"] [--project <slug>] [--era <key>]
---

# Icon tag — $ARGUMENTS

Change the tags, or the notes, of the icons **$ARGUMENTS** names. Every argument that is not a flag
and does not start with `+` or `-` is a name or a glob (`*` any run of characters, `?` one). `+tag`
adds a tag, `-tag` removes one, and `--notes "<text>"` replaces the notes (`--notes ""` clears
them). `--project <slug>` and `--era <key>` override the scope this repo's `.mcp.json` pins.
**Pass `--project` and `--era` through to every tool call.**

## Hard rules (re-read before EVERY phase)

- **Exactly one kind of write: `tag_glyph`**, once per matched icon. Never `rename_glyph`,
  `merge_glyph`, `strike_glyph`, `put_glyph` or `use_glyph`, and nothing in the repo.
- **Globs resolve against `list_glyphs()`**, so struck and pending icons never match. A literal
  name that is pending is tagged all the same: tags stay editable while an import runs.
- **Confirm once.** More than one match: list every name and the change, ask ONE question, and
  write nothing until the answer is yes. One match: no question. In a d2m run (`D2M_WORK_ID` is
  set) ask through `await_answers` and END YOUR TURN; in a session, ask the user directly and wait.
- **No change, no write.** An icon that already has every `+tag`, none of the `-tag`s and the same
  notes is skipped and listed as unchanged.
- **Ending failed** means: write nothing more, print the phase's exit checklist, then print
  `✗ <reason>` as the very last line of the final message.

**At the end of every phase, print that phase's exit checklist with ✓/✗ per item.**

## 0. Load context

1. `project_info()`. **State the project slug and era key in your first report line.**
2. Parse `$ARGUMENTS` into names and globs, `+tag`s, `-tag`s and `--notes`. With no `+tag`, no
   `-tag` and no `--notes`, end failed: "nothing to change — add +tag, -tag or --notes".
3. `list_glyphs()`: the live icons, with their tags and notes.

**Exit checklist 0:** project + era stated ✓ · arguments parsed ✓ · library read ✓

## 1. Resolve

1. Each glob matches names in `list_glyphs()`.
2. Each literal name found there is a match. One not found: `get_glyph(name: "<name>")` —
   `pending: true` is a match; an answer under another name is merged: say "merged into
   `<keeper>`" and tag nothing for it; an error is "no icon `<name>`".
3. No match at all: end failed with "nothing matches `<arguments>`".
4. Work out each match's change: its tags after (`+` added, `-` removed, never duplicated) and its
   notes when `--notes` was given. Drop the matches with no change.

**Exit checklist 1:** every name and glob resolved ✓ · the change worked out per icon ✓

## 2. Confirm — only when more than one icon changes

Print one line per icon: `<name>`: tags before → after, and the notes when `--notes` was given.
Then ask ONE question: "Tag these `<N>` icons as listed?"

- **In a d2m run** (`echo "${D2M_WORK_ID:-}"` prints an id):
  `await_answers(subject: "icons", questions: [{ question, options, recommended }])` with that
  question, the options "Yes — tag all `<N>`" and "No — tag nothing", `recommended` 0, then END
  YOUR TURN. Several icons are the whole library's question, so the subject is always `icons`; the
  owner answers it on this run's card in the terminal, and the run resumes with the answer.
- **In a session:** ask the user directly and wait.

Anything but yes ends the run with nothing written.

**Exit checklist 2:** one confirm, or a single icon that needs none ✓

## 3. Write

For each icon with a change: `tag_glyph(name: "<name>", add: ["<tag>"], remove: ["<tag>"])`,
passing only the lists that are non-empty and adding `notes: "<text>"` when `--notes` was given.
A refusal for one icon is reported verbatim and the others continue.

**Exit checklist 3:** one `tag_glyph` per changed icon ✓ · refusals reported verbatim ✓

## 4. Report

- **project + era**, first;
- **tagged** — each icon, tags before → after, and notes when changed;
- **unchanged** — each icon that already matched;
- **refused** — each refusal verbatim.

**Exit checklist 4:** report printed ✓ · nothing written but `tag_glyph` ✓
