---
name: d2m-icon-rename
description: Rename an icon in the d2m icon library AND in the repo — `/d2m-icon-rename <name> <new-name>`. Checks the whole repo first and refuses when a use it cannot edit would break; then renames in d2m (rename_glyph), syncs the catalog and Glyph.swift (sync_glyphs), rewrites the Swift call sites under the preview directory, deletes the old imageset, and recaptures each component whose file changed. A rerun after a failure resumes where it stopped. Run it in a Claude session in the project's repo.
argument-hint: <name> <new-name> [--project <slug>] [--era <key>]
---

# Icon rename — $ARGUMENTS

Rename the icon in **$ARGUMENTS**: `<old>` is the first argument and `<new>` the second, both
kebab-case. When this run ends, d2m calls the icon `<new>`, every prop option and preview value that
carried `<old>` says `<new>`, `Glyph.swift` declares the new case, every call site under the preview
directory draws it, the old imageset is gone, and each component whose file changed was recaptured.

A name's Swift case is the name in lowerCamel: each `-`-separated segment after the first is
capitalised and the dashes go (`walk-probe` → `walkProbe`, `arrow-up-2` → `arrowUp2`). Below they
are `<oldCase>` and `<newCase>`.

`--project <slug>` and `--era <key>` override the scope this repo's `.mcp.json` pins. **Pass
`--project` and `--era` through to every tool call.**

## Hard rules (re-read before EVERY phase)

- **Exactly one d2m write: `rename_glyph`**, called at most once. Never `merge_glyph`,
  `strike_glyph`, `put_glyph`, `tag_glyph` or `use_glyph`.
- **The order is fixed: the DB write → `sync_glyphs(wait: true)` → the file edits → `capture(component: "C-<code>", wait: true)`.**
  Never edit a file before the sync has ended `done`: without the new case in `Glyph.swift` the
  edited call sites cannot compile. A sync that has not ended within the wait budget stops the run
  before any edit, and the report carries its run id.
- **Rerun resumes.** When `<old>` answers 404 and `<new>` is live, the d2m rename already happened
  on an earlier run: skip the confirm and the write, and go straight on to the sync.
- **Edit only under `project.previewDir`**: the call sites, and `<old>.imageset` in the catalog
  directory. A use of `<old>` anywhere else in the repo refuses the run in phase 1, before any
  write. Never Figma, never d2m's own code, never `project.pbxproj`.
- **Call sites are found with exactly these patterns**, with perl, which has lookbehind:
  `(?<![\w.])Glyph\(\s*\.<oldCase>\b` and `\bGlyphName\.<oldCase>\b`, plus the literal
  `Image("<old>"`, which also covers `Image("<old>", bundle: …)`. `ArrowGlyph(…)` and `GlyphButton.Glyph(…)` are other views and never match.
- **Confirm once**, before the d2m write. In a d2m run (`D2M_WORK_ID` is set) ask through
  `await_answers` and END YOUR TURN; in a session, ask the user directly and wait.
- **Ending failed** means: write nothing more, print the phase's exit checklist, say what was
  already done (the d2m rename, the sync, which files were edited), print the rerun command
  `/d2m-icon-rename <old> <new> --project <slug> --era <key>`, then print `✗ <reason>` as the very
  last line of the final message.

**At the end of every phase, print that phase's exit checklist with ✓/✗ per item.**

## 0. Load context

1. `project_info()`. **State the project slug and era key in your first report line.** From its
   settings note `project.repoPath`, `project.previewDir`, `project.lintCmd` and
   `project.captureAdapter`, and the two icon paths: the catalog directory is
   `project.glyphCatalogPath`, or `<project.previewDir>/Resources/Glyphs.xcassets` when that is
   null; the generated Swift file is `project.glyphSwiftPath`, or `<project.previewDir>/Glyph.swift`
   when that is null. Every path is relative to `project.repoPath`.
2. **The working directory.** `pwd -P` must equal `project.repoPath` resolved the same way
   (`cd "<repoPath>" && pwd -P`). If it does not, end failed, having written nothing: "this session
   is in `<pwd>`, not the project's repo `<repoPath>` — open a session there and rerun". A worktree
   is a different checkout: its edits would land where nothing builds them.
3. `<old>` and `<new>` from `$ARGUMENTS`: both lowercase kebab-case, and different. Otherwise end
   failed with the usage `/d2m-icon-rename <name> <new-name>`.
4. **Where the rename stands.** `get_glyph(name: "<old>")` and `get_glyph(name: "<new>")`:
   - `<old>` answers a glyph named `<old>`: a fresh rename. When it is `pending: true`, end failed:
     "`<old>` is still importing — wait for the import, then rerun". Keep its `usages`.
   - `<old>` answers 404 and `<new>` is live: **resume**. Say "resuming — `<old>` is already `<new>`
     in d2m", keep `<new>`'s `usages`, run phase 1 without its refusal, skip phase 2.
   - `<old>` answers a glyph under another name: end failed: "`<old>` was merged into `<keeper>` —
     nothing to rename".
   - Anything else: end failed: "no icon `<old>` in this era".

**Exit checklist 0:** project + era stated ✓ · working directory is the repo ✓ · names valid ✓ ·
fresh or resume decided ✓

## 1. Check — every use, in the whole repo

1. **Every use of the old spelling**, anywhere in the repo, skipping node_modules, .git, build, DerivedData, Pods:

   ```sh
   find "<repoPath>" \( -name node_modules -o -name .git -o -name build -o -name DerivedData -o -name Pods \) -prune -o -name '*.swift' -print0 | xargs -0 perl -ne 'print "$ARGV:$.:$_" if /(?<![\w.])Glyph\(\s*\.<oldCase>\b|\bGlyphName\.<oldCase>\b|Image\("<old>"/; close ARGV if eof'
   ```

   The matches under `<repoPath>/<previewDir>` are the call sites this run edits; every other one
   is a use it cannot edit.
2. **A use outside `project.previewDir` refuses the run.** List each `file:line` and end failed,
   having written nothing: "`<N>` uses of `<old>` outside the preview directory — rename them by
   hand first, or keep the name". Once the sync drops `<oldCase>` they would stop compiling. On a
   resume the d2m rename is already done: list them under "fix by hand" and go on.
3. **Prop-option usages.** For each usage whose `kind` is `option`, the component keeps its own
   option enum in Swift while d2m's value becomes `<new>`, so its next capture fails until the enum
   follows. List each as `C-<code>.<prop>=<old>` with `/d2m-component-update C-<code>`.
4. **Which component owns each call-site file.** For each component among the usages,
   `build_status(component: "C-<code>")`: a file whose path under `project.previewDir` equals its
   `previewPath` is that component's. A file no usage component owns: take the first `C-###` in the
   file's name or in a comment inside it, and confirm it the same way. A file still unowned is
   "edited, not recaptured".

**Exit checklist 1:** whole repo searched ✓ · no use outside the preview directory, or a resume ✓ ·
prop-option usages listed ✓ · call-site files mapped to components ✓

## 2. Confirm, then rename in d2m

Skip this phase on a resume.

1. Print what the rename will do: the usage count; every call site `file:line`; each prop-option
   usage with its `/d2m-component-update C-<code>`; and "`Glyph.swift` will declare `<newCase>`
   instead of `<oldCase>`, and `<old>.imageset` goes".
2. Ask ONE question: "Rename `<old>` to `<new>`?"
   - **In a d2m run** (`echo "${D2M_WORK_ID:-}"` prints an id):
     `await_answers(subject: "glyph:<old>", questions: [{ question, options, recommended }])` with
     that question, the options "Yes — rename it" and "No — leave it", `recommended` 0, then END
     YOUR TURN. One icon's question is asked on that icon, `glyph:<old>`, whether or not anything
     uses it; the owner answers it on this run's card in the terminal, and the run resumes with the
     answer.
   - **In a session:** ask the user directly and wait.

   Anything but yes ends the run with nothing written.
3. `rename_glyph(name: "<old>", to: "<new>")`. Keep `usagesRewritten`. A refusal — the name or its
   Swift case taken, the icon still importing, an import running on it, a reserved name — ends
   failed with the refusal verbatim; nothing was written.

**Exit checklist 2:** confirmed ✓ · `rename_glyph` answered `<new>` with `usagesRewritten` ✓

## 3. Sync

1. `sync_glyphs(wait: true)`. In a session it queues, or joins, the era's sync; in a d2m run it runs
   as this run's child. Read the answer:
   - `status: "done"`: continue, and keep `report`.
   - `timedOut: true`: end failed: "the sync `<runId>` has not ended — rerun when it has; no file
     was edited".
   - Any other `status`, or a refusal (the project cannot sync — the reason names what to set): end
     failed with it verbatim and the report's last lines; no file was edited.
2. Read the generated Swift file. It must declare `case <newCase>` and no `case <oldCase>`;
   otherwise end failed: "`Glyph.swift` does not declare `<newCase>` yet — rerun once the sync has
   written it".

**Exit checklist 3:** sync `done`, its run id kept ✓ · `Glyph.swift` declares `<newCase>` ✓

## 4. Edit — under `project.previewDir` only

1. Rewrite each call-site file phase 1 found, in place:

   ```sh
   perl -pi -e 's/((?<![\w.])Glyph\(\s*\.)<oldCase>\b/${1}<newCase>/g; s/\bGlyphName\.<oldCase>\b/GlyphName.<newCase>/g; s/Image\("<old>"/Image("<new>"/g' <the files>
   ```

2. Search `<repoPath>/<previewDir>` again with phase 1's command: no match may remain.
3. **The old imageset.** Delete `<repoPath>/<catalog>/<old>.imageset` (`rm -r`) only when the sync's `not in the library:` line names `<old>`. A rename leaves the old imageset behind, and `Image("<old>")` would keep compiling against stale art. Never delete another imageset: the sync removes struck ones itself.
4. Run `project.lintCmd` when it is set. Fix a lint failure on a line you edited; report any other.

**Exit checklist 4:** every call site rewritten ✓ · no old spelling left under the preview
directory ✓ · `<old>.imageset` deleted, or kept with the reason ✓ · lint clean ✓

## 5. Recapture and report

For each component phase 1 mapped to an edited file whose `build_status` says it is built:
`capture(component: "C-<code>", wait: true)`, and read its final state. When
`project.captureAdapter` is `noop` the project has no render lane: say so and skip. Never report a
render that did not happen.

**Report:**

- **project + era**, first;
- **rename** — `<old>` → `<new>` and `usagesRewritten`, or "resumed";
- **sync** — its run id and status, and its "not in the library" line;
- **call sites** — each `file:line`, before → after;
- **removed** — `<old>.imageset`, or why it stayed;
- **recaptures** — each component and its capture's final state, and each edited file no component
  owns;
- **fix by hand** — each prop-option usage with `/d2m-component-update C-<code>`, and on a resume
  any use outside the preview directory;
- **check** — "build the app in Xcode: this run changed Swift".

**Exit checklist 5:** each edited, built component recaptured, or the missing render lane said ✓ ·
report covers every point ✓
