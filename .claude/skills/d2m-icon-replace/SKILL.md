---
name: d2m-icon-replace
description: Give an existing icon in the d2m icon library new art from any source — `/d2m-icon-replace <name> <source>`, where the source is anything /d2m-icon-import takes (an .svg file, a folder with --pick, a Figma URL, a web page, npm:, d2m:) and must resolve to exactly one icon. The name, usages and call sites stay; the new art's provenance is recorded. It refuses art that is already another icon (merge instead), shows old and new side by side, and asks once before put_glyph replaces. With --draw "<description>" instead of a source, the new art is drawn from the description the way /d2m-icon-draw draws (three variants, a self-check, a contact sheet with the current art, one pick).
argument-hint: <name> <source | --draw "<description>"> [--pick <glob>] [--variant solid] [--project <slug>] [--era <key>]
---

# Icon replace — $ARGUMENTS

Give the icon named by the first argument of **$ARGUMENTS** new art, from the source the second
argument names. The icon keeps its name, its usages and its call sites; only the art and where it
came from change. `--pick <glob>` narrows a source that holds several icons. `--draw
"<description>"` replaces the source: the new art is drawn from words (§2b). `--project <slug>`
and `--era <key>` override the scope this repo's `.mcp.json` pins. **Pass `--project` and `--era`
through to every tool call.**

## Hard rules (re-read before EVERY phase)

- **One write: `put_glyph` with `replace: true`**, called once, after the confirm. Never
  `tag_glyph`, `rename_glyph`, `merge_glyph`, `strike_glyph` or `use_glyph`, and nothing in the
  repo.
- **Exactly one candidate.** A source that resolves to more than one icon ends the run.
- **Never give one icon's art to two.** `put_glyph` with `replace: true` does not check for
  duplicate art, so this skill dry-runs first and refuses art that is already another icon.
- **One temp directory.** Phase 0 makes it with `mktemp -d`; delete it with `rm -rf "$WORK"` at
  the end — and on every failure, before the `✗` line. **`$WORK` does not survive between tool
  calls — every command that touches it starts `WORK=<the printed path>;` in that same call.**
  Never rely on an earlier command's `WORK=` assignment still being set.
- **Ending failed** means: print the phase's exit checklist, run `rm -rf "$WORK"`, and make
  `✗ <reason>` the last line.

**At the end of every phase, print that phase's exit checklist with ✓/✗ per item.**

## 0. Load context

1. `project_info()`. **State the project slug and era key in your first report line.** Note
   `project.repoPath`.
2. In a d2m run or a session? `echo "${D2M_WORK_ID:-}"` prints an id inside a run and nothing in a
   session.
3. `WORK=$(mktemp -d "${TMPDIR:-/tmp}/d2m-icon-replace.XXXXXX")` — print the path. **Every later
   command that touches `$WORK` re-declares it first, in that same tool call**
   (`WORK=<the printed path>; …`): a tool call is a fresh shell, and shell variables do not
   survive between calls.
4. `get_glyph(name: "<name>")`:
   - `pending: true` → end failed: "still importing — wait, retry or remove".
   - an answer whose `name` is not `<name>` → end failed: "`<name>` was merged into `<keeper>` —
     replace `<keeper>`"; an error → end failed: "no icon `<name>` in this era".
   - Otherwise keep its `usages.count`, its `source` and whether it has a `figmaNodeId`.
5. **`--draw`?** When the arguments carry `--draw "<description>"`, there is no source: the
   description is the quoted text after `--draw`, or, unquoted, every token after `--draw` up to
   the next `--flag`, joined by single spaces (empty → end failed: "give a description after
   `--draw`"). Keep it for `sourceRef`, truncated to 2048 characters. **The description never
   reaches a shell** — it goes only into tool arguments and this transcript.

**Exit checklist 0:** project + era stated ✓ · run or session recorded ✓ · `$WORK` made ✓ · the
icon read, minted and live ✓

## 1. Gather — exactly as /d2m-icon-import does

**With `--draw`, skip this phase and §2 — go to §2b.**

1. Read `<project.repoPath>/.claude/skills/d2m-icon-import/SKILL.md` and follow its `## 1. Gather`
   for `<source>`: its detection order, the section for that source, its limits, its fetch rule
   (only `https://`, never a loopback or private host), and its in-run refusal for a page that
   renders its icons with JavaScript. Use this run's `$WORK`. If that file is missing, end failed:
   "the d2m skills are not installed in this repo — run `d2m skills install`".
2. Apply `--pick`.
3. **Exactly one candidate.** None → end failed: "nothing found at <source>". More than one → end
   failed: "replace takes one icon — add `--pick <name>`", listing up to 12 of their names.

**Exit checklist 1:** source gathered by import's rules ✓ · exactly one candidate, with its
`source`, `sourceRef` and `license` ✓

## 2. Dry-run

`normalize_glyphs(items: [{ key, path, name }])` with ONE item: key `new`, the candidate's file,
name `<name>`. Nothing is written.

- `refused` → end failed with its `rejected` verbatim.
- `duplicate` whose `matches` is another icon → end failed: "that art is already `<matches>` —
  merge instead: `/d2m-icon-merge <name> --into <matches>`".
- `duplicate` whose `matches` is `<name>` → end: "`<name>` already has this art — nothing to
  replace" — `rm -rf "$WORK"` before ending, the same cleanup as a failure.
- `name-taken` with `matches` `<name>`, `multicolour` or `new` → carry on: the name is this
  icon's own.
- **Read `colors` from the item, whatever its status:** `colors` > 1 means the tint flattens it to
  one colour, and the confirm says so. The dry-run under the live name answers `name-taken` before
  it would answer `multicolour`, so the status alone never shows it.

**Exit checklist 2:** dry-run answered ✓ · no other icon has this art ✓

## 2b. Draw — the `--draw` source

1. Read `<project.repoPath>/.claude/skills/d2m-icon-draw/SKILL.md` and follow its `## 0. Load
   context` steps 7–8 (the style, the neighbours), then `## 1. Draw three`, `## 2. Self-check` and
   `## 3. Sheet and choice`, using this run's `$WORK`, with these differences. If that file is
   missing, end failed: "the d2m skills are not installed in this repo — run `d2m skills install`".
   - **The name is `<name>`** — no name is proposed, and phase 0's name check is skipped: the name
     is this icon's own.
   - **The neighbours** exclude `<name>` — the current icon is never one of the neighbours,
     because it has its own cell.
   - **The sheet** puts the current art first, as a `names` cell, then the neighbours, then the
     three variants — still at most 8 cells:
     `render_glyph(names: ["<name>", "<neighbour>", …], svgs: [{ label, path }, …], sizes: [24, 48, 96])`.
     Run `open "<file>"` on the `file` it answers and print the path.
   - **The question is the confirm — the pick is the confirm.** It reads: "Replace the art of
     `<name>` with variant …? Its <usages.count> usages keep the name." with the lines §3 adds
     when they apply: "its Figma node link is cleared" (the icon has a `figmaNodeId` — the new art
     is never from Figma). Options: the passing variants' numbers · **Revise** · **Cancel**;
     `recommended` is the 0-based index in `options` of your best variant — with options `["1",
     "3", "Revise", "Cancel"]`, variant 3 is `recommended: 1` (or the index of Revise when none
     passes). In a d2m run it is
     `await_answers(subject: "glyph:<name>", questions: [{ question, options, recommended }])`,
     then END YOUR TURN; in a session, ask directly and wait. **Revise** asks its free-text
     follow-up the same way and starts the next round; **Cancel** ends the run with nothing
     written — `rm -rf "$WORK"` before ending.
   - A variant whose dry-run is `duplicate` fails its pass — `matches` another icon (§2's
     refusal), or `<name>` itself (a no-op replace).
2. A number → the pick. The candidate for §4 is that file, read from disk, unchanged:
   `<source>` is `generated`, `<sourceRef>` is the description, and there is no licence. Skip §3
   — the confirm has been given.

**Exit checklist 2b:** the draw skill's phases followed with the current art on the sheet ✓ · one
answer read ✓ · the picked file named as the candidate ✓

## 3. Show and confirm

**With `--draw`, the pick in §2b was the confirm — skip to §4.**

1. `render_glyph(names: ["<name>"], svgs: [{ label, path }])` — the live icon, and the new art
   labelled `new`. Run `open "<file>"` on the `file` it answers, and print the path.
2. Ask ONE question: "Replace the art of `<name>`? Its <usages.count> usages and its call sites
   keep the name." Options **Replace** · **Cancel**, `recommended` 0. Add to it, when they apply:
   "the tint flattens it to one colour" (`colors` > 1 on the dry-run item); "its Figma node link is cleared" (the icon
   has a Figma node and the new art is not from Figma — D15); "its Figma node becomes <id>" (the
   new art is from Figma).
   - **In a d2m run:** `await_answers(subject: "glyph:<name>", questions: [{ question, options, recommended }])`,
     then END YOUR TURN; the owner answers on this run's card in the terminal, and the run resumes
     with the answer.
   - **In a session:** ask the user directly and wait.

   Anything but **Replace** ends the run with nothing written — `rm -rf "$WORK"` before ending, the
   same cleanup as a failure.

**Exit checklist 3:** old and new shown ✓ · one answer ✓

## 4. Replace

`put_glyph(name: "<name>", svg: "<the new file's text>", source: "<source>", sourceRef: "<sourceRef>", license: "<license>", replace: true)`

Figma art also passes `figmaNodeId` and `figmaFileKey`. Leave out `sourceRef` or `license` when the
candidate has none. A refusal is reported verbatim and ends the run failed.

From `--draw`: `<source>` is `generated`, `<sourceRef>` is the description, and no `license` is
passed. The server clears the Figma ids for any source that is not `figma` (icon-import D15) —
the skill clears nothing.

**Exit checklist 4:** `put_glyph` called once, with `replace: true` ✓ · answer read ✓

## 5. Report

Print, then `rm -rf "$WORK"`, then stop:

- **project + era**, first;
- **replaced** — `<name>`, from <source> (`sourceRef`), licence or "licence unknown" — or "drawn
  from a description" for `--draw`;
- **usages kept: <usages.count>** — and its call sites, unchanged;
- **page** — `/<slug>/icons/<name>`.

**Exit checklist 5:** report printed ✓ · `$WORK` deleted ✓ · nothing written but the one
`put_glyph` ✓
