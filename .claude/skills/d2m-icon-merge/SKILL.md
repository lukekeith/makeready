---
name: d2m-icon-merge
description: Fold one icon into another, in the d2m icon library AND in the repo — `/d2m-icon-merge <name> --into <keeper>`. Shows both icons, checks the whole repo and refuses when a use it cannot edit would break; then merges in d2m (merge_glyph), syncs the catalog and Glyph.swift (sync_glyphs), rewrites the Swift call sites under the preview directory to the keeper, and recaptures each component whose file changed. A rerun after a failure resumes where it stopped. Run it in a Claude session in the project's repo.
argument-hint: <name> --into <keeper> [--project <slug>] [--era <key>]
---

# Icon merge — $ARGUMENTS

Fold the icon `<old>` (the first argument) into `<keeper>` (the `--into` value). When this run ends,
`<old>` is struck with `mergedInto` `<keeper>`, every usage it had is the keeper's, `Glyph.swift` no
longer declares the old case, every call site under the preview directory draws the keeper, and each
component whose file changed was recaptured.

A name's Swift case is the name in lowerCamel: each `-`-separated segment after the first is
capitalised and the dashes go (`arrow-left-2` → `arrowLeft2`). Below they are `<oldCase>` and
`<keeperCase>`.

`--project <slug>` and `--era <key>` override the scope this repo's `.mcp.json` pins. **Pass
`--project` and `--era` through to every tool call.**

## Hard rules (re-read before EVERY phase)

- **Exactly one d2m write: `merge_glyph`**, called at most once. Never `rename_glyph`,
  `strike_glyph`, `put_glyph`, `tag_glyph` or `use_glyph`.
- **The order is fixed: the DB write → `sync_glyphs(wait: true)` → the file edits → `capture(component: "C-<code>", wait: true)`.**
  Never edit a file before the sync has ended `done`. A sync that has not ended within the wait
  budget stops the run before any edit, and the report carries its run id.
- **Rerun resumes.** When `<old>` is struck with `mergedInto` `<keeper>` (from
  `list_glyphs(includeStruck: true)`), the d2m merge already happened on an earlier run: skip the
  confirm and the write, and go straight on to the sync.
- **Edit only under `project.previewDir`.** A use of `<old>` anywhere else in the repo refuses the
  run in phase 1, before any write. This run deletes no imageset: the sync removes a struck icon's
  itself. Never Figma, never d2m's own code, never `project.pbxproj`.
- **Call sites are found with exactly these patterns**, with perl, which has lookbehind:
  `(?<![\w.])Glyph\(\s*\.<oldCase>\b` and `\bGlyphName\.<oldCase>\b`, plus the literal
  `Image("<old>"`, which also covers `Image("<old>", bundle: …)`. `ArrowGlyph(…)` and `GlyphButton.Glyph(…)` are other views and never match.
- **Confirm once**, after showing both icons and before the d2m write. In a d2m run (`D2M_WORK_ID`
  is set) ask through `await_answers` and END YOUR TURN; in a session, ask the user directly and
  wait.
- **Ending failed** means: write nothing more, print the phase's exit checklist, say what was
  already done (the d2m merge, the sync, which files were edited), print the rerun command
  `/d2m-icon-merge <old> --into <keeper> --project <slug> --era <key>`, then print `✗ <reason>` as
  the very last line of the final message.

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
   is in `<pwd>`, not the project's repo `<repoPath>` — open a session there and rerun".
3. `<old>` and `<keeper>` from `$ARGUMENTS`: both lowercase kebab-case, and different. Otherwise
   end failed with the usage `/d2m-icon-merge <name> --into <keeper>`.
4. **The keeper.** `get_glyph(name: "<keeper>")` must answer a live glyph named `<keeper>` that is
   not pending; otherwise end failed: "`<keeper>` is not a live icon to merge into".
5. **Where the merge stands.** `get_glyph(name: "<old>")` first — `list_glyphs` never lists a
   pending row, so only `get_glyph` can see one still importing:
   - `<old>` answers a glyph named `<old>`: a fresh merge. When it is `pending: true`, end failed:
     "`<old>` is still importing — wait for the import, then rerun". Keep its `usages`.
   - Otherwise (a 404, or a glyph under another name) read `list_glyphs(includeStruck: true)`, the
     struck row named `<old>`:
     - struck with `mergedInto` `<keeper>`: **resume**. Say "resuming — `<old>` is already merged
       into `<keeper>` in d2m", run phase 1 without its refusal, skip phase 2.
     - struck otherwise: end failed: "`<old>` is already struck".
     - absent: end failed: "no icon `<old>` in this era".

**Exit checklist 0:** project + era stated ✓ · working directory is the repo ✓ · keeper live ✓ ·
fresh or resume decided ✓

## 1. Check — every use, in the whole repo

1. **Every use of the old spelling**, anywhere in the repo, skipping node_modules, .git, build, DerivedData, Pods:

   ```sh
   find "<repoPath>" \( -name node_modules -o -name .git -o -name build -o -name DerivedData -o -name Pods \) -prune -o -name '*.swift' -print0 | xargs -0 perl -ne 'print "$ARGV:$.:$_" if /(?<![\w.])Glyph\(\s*\.<oldCase>\b|\bGlyphName\.<oldCase>\b|Image\("<old>"/; close ARGV if eof'
   ```

   The matches under `<repoPath>/<previewDir>` are the call sites this run edits; every other one
   is a use it cannot edit.
2. **A use outside `project.previewDir` refuses the run.** List each `file:line` and end failed,
   having written nothing: "`<N>` uses of `<old>` outside the preview directory — point them at
   `<keeper>` by hand first". Once the sync drops `<oldCase>` they would stop compiling. On a resume
   the d2m merge is already done: list them under "fix by hand" and go on.
3. **Prop-option usages.** For each usage whose `kind` is `option`, the component keeps its own
   option enum in Swift while d2m's value becomes `<keeper>`, so its next capture fails until the
   enum follows. List each as `C-<code>.<prop>=<old>` with `/d2m-component-update C-<code>`.
4. **Which component owns each call-site file.** For each component among the usages,
   `build_status(component: "C-<code>")`: a file whose path under `project.previewDir` equals its
   `previewPath` is that component's. A file no usage component owns: take the first `C-###` in the
   file's name or in a comment inside it, and confirm it the same way. A file still unowned is
   "edited, not recaptured".

**Exit checklist 1:** whole repo searched ✓ · no use outside the preview directory, or a resume ✓ ·
prop-option usages listed ✓ · call-site files mapped to components ✓

## 2. Confirm, then merge in d2m

Skip this phase on a resume.

1. **Show both.** `render_glyph(names: ["<old>", "<keeper>"])`. Run `open "<file>"` on the `file` it
   answers and print the path.
2. Print what the merge will do: `<old>`'s usage count, which all move to `<keeper>`; every call
   site `file:line`, which will draw `<keeper>`; each prop-option usage with its
   `/d2m-component-update C-<code>`; and "`<old>` is struck, and the sync deletes `<old>.imageset`".
3. Ask ONE question: "Merge `<old>` into `<keeper>`?"
   - **In a d2m run** (`echo "${D2M_WORK_ID:-}"` prints an id):
     `await_answers(subject: "glyph:<old>", questions: [{ question, options, recommended }])` with
     that question, the options "Yes — merge them" and "No — keep both", `recommended` 0, then END
     YOUR TURN. One icon's question is asked on that icon, `glyph:<old>`, whether or not anything
     uses it; the owner answers it on this run's card in the terminal, and the run resumes with the
     answer.
   - **In a session:** ask the user directly and wait.

   Anything but yes ends the run with nothing written.
4. `merge_glyph(name: "<old>", into: "<keeper>")`. Keep `moved`. A refusal — either side pending,
   an import running on either, the keeper struck — ends failed with the refusal verbatim; nothing
   was written.

**Exit checklist 2:** both shown ✓ · confirmed ✓ · `merge_glyph` answered `<keeper>` with `moved` ✓

## 3. Sync

1. `sync_glyphs(wait: true)`. In a session it queues, or joins, the era's sync; in a d2m run it runs
   as this run's child. Read the answer:
   - `status: "done"`: continue, and keep `report`; its `removed (struck):` line should name `<old>`.
   - `timedOut: true`: end failed: "the sync `<runId>` has not ended — rerun when it has; no file
     was edited".
   - Any other `status`, or a refusal (the project cannot sync — the reason names what to set): end
     failed with it verbatim and the report's last lines; no file was edited.
2. Read the generated Swift file. It must declare `case <keeperCase>` and no `case <oldCase>`;
   otherwise end failed: "`Glyph.swift` still declares `<oldCase>` — rerun once the sync has
   written it".

**Exit checklist 3:** sync `done`, its run id kept ✓ · `Glyph.swift` without `<oldCase>` ✓

## 4. Edit — under `project.previewDir` only

1. Rewrite each call-site file phase 1 found, in place:

   ```sh
   perl -pi -e 's/((?<![\w.])Glyph\(\s*\.)<oldCase>\b/${1}<keeperCase>/g; s/\bGlyphName\.<oldCase>\b/GlyphName.<keeperCase>/g; s/Image\("<old>"/Image("<keeper>"/g' <the files>
   ```

2. Search `<repoPath>/<previewDir>` again with phase 1's command: no match may remain.
3. Run `project.lintCmd` when it is set. Fix a lint failure on a line you edited; report any other.

**Exit checklist 4:** every call site draws `<keeper>` ✓ · no old spelling left under the preview
directory ✓ · lint clean ✓

## 5. Recapture and report

For each component phase 1 mapped to an edited file whose `build_status` says it is built:
`capture(component: "C-<code>", wait: true)`, and read its final state. When
`project.captureAdapter` is `noop` the project has no render lane: say so and skip. Never report a
render that did not happen.

**Report:**

- **project + era**, first;
- **merge** — `<old>` → `<keeper>` and `moved`, or "resumed";
- **sync** — its run id and status, and its `removed (struck):` line;
- **call sites** — each `file:line`, before → after;
- **recaptures** — each component and its capture's final state, and each edited file no component
  owns;
- **fix by hand** — each prop-option usage with `/d2m-component-update C-<code>`, and on a resume
  any use outside the preview directory;
- **check** — "build the app in Xcode: this run changed Swift".

**Exit checklist 5:** each edited, built component recaptured, or the missing render lane said ✓ ·
report covers every point ✓
