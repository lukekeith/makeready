# ui2-shell — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer and a review per task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the UI 2.0 views the iPhone app: rename the d2m module to `MakeReadyUI`, take the
legacy UI out of the `MakeReady` target, and wire Login → Shell (TabBar + TopNav) → Home → Profile
stopgap on the existing foundations.

**Architecture:** d2m keeps owning the pure, prop-driven views under `iphone/MakeReadyUI/`; those
files compile into the capture framework AND the app target (SPEC D29). Hand-written wiring lives in
`iphone/MakeReady/UI2/` — `UI2Root` (auth gate), `Shell/` (tab/section state, TabBar + TopNav host),
`Containers/` (AppState → screen `State`, callbacks → Actions). Data goes through `State/Actions/`
into `AppState`, never from a view.

**Tech Stack:** iphone — Swift 5 / SwiftUI, `@Observable` `AppState` + Actions, XCTest in
`MakeReadyCaptureTests` (hosted by the `MakeReady` scheme), Ruby `xcodeproj` for project edits.
capture — Node (`capture/lib/ui2-tokens.mjs`), the capture server + simulator capture runner.

**Spec:** `docs/features/ui2-shell/SPEC.md`

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. 🔴 You stage your commit and STOP — an iPhone commit is the human's to approve.
- Capture: fixtures are manifest-driven and twins additive-only; register a new twin in the component-capture map and check its BEM root for a collision with a legacy web component before naming it; restart the capture server after editing an adapter, and rebuild the client bundle before any web capture.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test or `/compare` diff, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(ui2-shell): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal | Gates |
|---|---|---|---|---|
| 1 | iphone | 1–2 | `UI2Preview` is `MakeReadyUI` at `iphone/MakeReadyUI/` — target, scripts, SwiftLint, capture Swift targets renamed; nothing else changes | `npm run ios:build-check` · `npm run ios:build-check -- --test` · `cd iphone && swiftlint` |
| 2 | capture | 3 | capture tooling + `.claude` tooling follow the rename; a re-capture proves it pixel-neutral (D18) | `curl -s localhost:5950/api/compare/manifest` · `node capture/runners/compare/diff.mjs …` |
| 3 | iphone | 4–8 | the clean break: 1.0 capture cases retired, models moved, legacy out of the target, 2.0 files in it, `UI2Root` + Login wired with the auth fixes — an archivable login-only 2.0 build | `npm run ios:build-check` · `npm run ios:build-check -- --test` · `cd iphone && swiftlint` |
| 4 | iphone | 9–10 | the shell: TabBar always, TopNav (swipe + morph) on Home only, empty pages, initial load (⛔ needs SPEC F2 — `shell-topnav`/`shell-tabs` specced in d2m) | `npm run ios:build-check` · `npm run ios:build-check -- --test` · `cd iphone && swiftlint` |
| 5 | iphone | 11–13 | Home live: `DashboardActions` → `AppState.dashboard` → mapper → `HomeDashboardContainer` (⛔ needs SPEC F3 — `home-dashboard` rebuilt without app chrome) | `npm run ios:build-check` · `npm run ios:build-check -- --test` · `cd iphone && swiftlint` |
| 6 | iphone | 14–15 | Profile stopgap: Sign out + DEV-only environment switcher | `npm run ios:build-check` · `npm run ios:build-check -- --test` · `cd iphone && swiftlint` |

---

### Task 1: Rename the module folder, target and Swift references
App: iphone
Phase: 1
Recipe: SPEC §iphone Phase 1 + D1, D18, D23 (mechanical; no companion skill covers a target rename)

**Files:**
- Move: `iphone/MakeReady/UI2Preview/` → `iphone/MakeReadyUI/` (`git mv`)
- Create: `iphone/scripts/rename-ui2-target.rb` (one-shot; deleted in this task's commit)
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (via the script)
- Modify: `iphone/MakeReadyCapture/MakeReadyCaptureApp.swift:14,104`
- Modify: `iphone/MakeReadyCaptureTests/CaptureRunner.swift:13,83,90,113,322`
- Modify: `iphone/MakeReadyCaptureTests/ViewRegistry.swift` (import at :15, comment :13, every `UI2Preview.` qualifier)
- Modify: every `iphone/MakeReadyUI/**/*.swift` header comment, `iphone/MakeReadyUI/README.md`, `iphone/MakeReadyUI/Tokens.swift` header line

**Interfaces:**
- Consumes: nothing.
- Produces: framework target `MakeReadyUI` (bundle id `com.makeready.MakeReadyUI`), Xcode group `MakeReadyUI` under the main group with `path = MakeReadyUI`; module name `MakeReadyUI`; generated-file header line `// MakeReadyUI — the UI 2.0 module` (Task 3's generator must emit exactly this).

- [ ] **Step 1: Record the baseline** — `npm run ios:build-check -- --test 2>&1 | tail -5` → note the passing test count in your report (this is the "nothing changed" reference).

- [ ] **Step 2: Move the folder**

```bash
cd /Users/lukekeith/www/makeready
git mv iphone/MakeReady/UI2Preview iphone/MakeReadyUI
```

- [ ] **Step 3: Write the one-shot project rename script** — `iphone/scripts/rename-ui2-target.rb`

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true
# One-shot: UI2Preview → MakeReadyUI (SPEC D1). Idempotent; deleted after use.
require 'xcodeproj'
require 'pathname'

root = Pathname.new(__dir__).parent.parent
project = Xcodeproj::Project.open(root.join('iphone/MakeReady.xcodeproj').to_s)

target = project.targets.find { |t| %w[UI2Preview MakeReadyUI].include?(t.name) } || abort('target not found')
target.name = 'MakeReadyUI'
target.product_name = 'MakeReadyUI'
target.build_configurations.each do |c|
  c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.makeready.MakeReadyUI'
end
target.product_reference.path = 'MakeReadyUI.framework'
target.product_reference.name = 'MakeReadyUI.framework'

project.objects.grep(Xcodeproj::Project::Object::PBXContainerItemProxy).each do |proxy|
  proxy.remote_info = 'MakeReadyUI' if proxy.remote_info == 'UI2Preview'
end

old_parent = project.main_group.find_subpath('MakeReady', false)
group = old_parent&.children&.find { |g| g.display_name == 'UI2Preview' } ||
        project.main_group.children.find { |g| g.display_name == 'MakeReadyUI' } ||
        abort('UI2Preview group not found')
group.move(project.main_group) unless group.parent == project.main_group
group.name = 'MakeReadyUI'
group.path = 'MakeReadyUI'
group.source_tree = '<group>'

project.save
puts "renamed: target #{target.name}, group #{group.real_path}"
```

- [ ] **Step 4: Run it** — `ruby iphone/scripts/rename-ui2-target.rb` → prints `renamed: target MakeReadyUI, group …/iphone/MakeReadyUI`. Then `grep -c 'UI2Preview' iphone/MakeReady.xcodeproj/project.pbxproj` → only comment strings Xcode regenerates (e.g. `/* Build configuration list for PBXNativeTarget "UI2Preview" */`); fix any remaining by `sed -i '' 's/UI2Preview/MakeReadyUI/g' iphone/MakeReady.xcodeproj/project.pbxproj` and re-check it is 0.

- [ ] **Step 5: Rename the Swift module references**

```bash
cd /Users/lukekeith/www/makeready/iphone
sed -i '' -e 's/@testable import UI2Preview/@testable import MakeReadyUI/' \
          -e 's/UI2Preview\./MakeReadyUI./g' \
  MakeReadyCapture/MakeReadyCaptureApp.swift MakeReadyCaptureTests/CaptureRunner.swift MakeReadyCaptureTests/ViewRegistry.swift
grep -rn 'UI2Preview' MakeReadyCapture MakeReadyCaptureTests   # only comments may remain; rewrite them to MakeReadyUI
find MakeReadyUI -name '*.swift' -exec sed -i '' 's/UI2Preview — the UI 2.0 preview module/MakeReadyUI — the UI 2.0 module/' {} +
grep -rln 'UI2Preview' MakeReadyUI   # inspect each hit (README, GroupFollowCard.swift): rewrite prose to MakeReadyUI
```

- [ ] **Step 6: Update the module README** — `iphone/MakeReadyUI/README.md`: title `# MakeReadyUI — the UI 2.0 views`; replace the "Preview only" paragraph with: "These views ship. d2m builds them from contracts; the app wires them from `iphone/MakeReady/UI2/` containers (docs/features/ui2-shell SPEC D2, D29). Never hand-wire a file here — a d2m rebuild overwrites it." Replace every `UI2Preview` with `MakeReadyUI` and every `ui2-preview-sync.rb` with `makereadyui-sync.rb`.

- [ ] **Step 7: Build and test** — `npm run ios:build-check` → BUILD SUCCEEDED; `npm run ios:build-check -- --test` → same passing count as Step 1.

- [ ] **Step 8: Delete the one-shot script and stage** — `git rm -q --cached iphone/scripts/rename-ui2-target.rb 2>/dev/null; rm iphone/scripts/rename-ui2-target.rb`; `git add -A iphone/MakeReadyUI iphone/MakeReady.xcodeproj iphone/MakeReadyCapture iphone/MakeReadyCaptureTests`. Stage `refactor(ui2-shell): rename UI2Preview module to MakeReadyUI` and STOP (iPhone commit is the human's).

### Task 2: Rename the sync script and SwiftLint paths
App: iphone
Phase: 1
Recipe: SPEC §iphone Phase 1 + D23

**Files:**
- Move: `iphone/scripts/ui2-preview-sync.rb` → `iphone/scripts/makereadyui-sync.rb`
- Modify: `iphone/scripts/makereadyui-sync.rb:4-17,24,29-38,80`
- Modify: `iphone/scripts/capture-targets.rb:35,111-127`
- Modify: `iphone/.swiftlint.yml:17-18,49,55`
- Modify: `iphone/.swiftlint-baseline.json` (9 entries)

**Interfaces:**
- Consumes: Task 1's target `MakeReadyUI` and group under the main group.
- Produces: `ruby iphone/scripts/makereadyui-sync.rb` — idempotent sync of `iphone/MakeReadyUI/**` into the `MakeReadyUI` target (Task 6 extends it to the app target).

- [ ] **Step 1: Write the failing check** — `ruby iphone/scripts/ui2-preview-sync.rb` → FAIL ("no preview directory" — the folder moved in Task 1). That is the red.

- [ ] **Step 2: Move and edit the script**

```bash
git mv iphone/scripts/ui2-preview-sync.rb iphone/scripts/makereadyui-sync.rb
```

Replace its body from `repo_root   =` down to `group.set_path('UI2Preview')` with:

```ruby
repo_root    = Pathname.new(__dir__).parent.parent
project_path = repo_root.join('iphone/MakeReady.xcodeproj')
preview_dir  = repo_root.join('iphone/MakeReadyUI')

abort("no MakeReadyUI directory at #{preview_dir}") unless preview_dir.directory?

project = Xcodeproj::Project.open(project_path.to_s)
target  = project.targets.find { |t| t.name == 'MakeReadyUI' }
abort('MakeReadyUI target not found') if target.nil?

# The group sits under the MAIN group (iphone/MakeReadyUI beside iphone/MakeReady),
# recorded with a relative path.
group = project.main_group.find_subpath('MakeReadyUI', true)
group.set_source_tree('<group>')
group.set_path('MakeReadyUI')
```

Rewrite the header comment (lines 1–17) to describe `MakeReadyUI` (SPEC D1/D29) instead of the preview module, and change the final `puts` to `"MakeReadyUI: #{group.files.count} file(s) in target MakeReadyUI"`.

- [ ] **Step 3: Update `capture-targets.rb`** — line 35 `ui2 = find.('MakeReadyUI')`; lines 111–127 strings `'depend on MakeReadyUI'`, `'link MakeReadyUI.framework'`, `'embed MakeReadyUI.framework'`, comment `# MakeReadyUI: a dependency, linked, and embedded.`

- [ ] **Step 4: Update SwiftLint** — `.swiftlint.yml`:

```yaml
included:
  - MakeReady
  - MakeReadyUI
```

and line 55's regex `UI2Preview/Tokens\.swift` → `MakeReadyUI/Tokens\.swift` (line 49's comment likewise). Then `sed -i '' 's#MakeReady/UI2Preview/#MakeReadyUI/#g' iphone/.swiftlint-baseline.json`.

- [ ] **Step 5: Run the checks** — `ruby iphone/scripts/makereadyui-sync.rb` → `added: (none)`, `removed: (none)`; `git diff --stat iphone/MakeReady.xcodeproj` → no change from this run; `ruby iphone/scripts/capture-targets.rb --check` → exit 0; `cd iphone && swiftlint` → no new violations (the 9 baselined `EnrollCalendar.swift` ones stay baselined).

- [ ] **Step 6: Stage** — `refactor(ui2-shell): MakeReadyUI sync script and lint paths`; STOP for the human's commit.

### Task 3: Capture and tooling follow the rename; prove it pixel-neutral
App: capture
Phase: 2
Recipe: `/capture-start` · SPEC §capture + D18

**Files:**
- Modify: `capture/lib/ui2-tokens.mjs:2,16,106`
- Modify: `capture/server.mjs:1251` (comment), `capture/src/lib/ui2-sample-call.js:17` (comment)
- Modify: `.claude/scripts/list-ui2-refs.mjs:238`
- Modify: `.claude/commands/ui2-component-build.md`, `ui2-component-delete.md`, `ui2-component-merge.md`, `ui2-component-update.md`, `ui2-resolve.md`, `.claude/builder.md:204`

**Interfaces:**
- Consumes: Task 1's folder `iphone/MakeReadyUI/` and header line `// MakeReadyUI — the UI 2.0 module`; Task 2's `iphone/scripts/makereadyui-sync.rb`.
- Produces: `node capture/lib/ui2-tokens.mjs` writes `iphone/MakeReadyUI/Tokens.swift` byte-identical to the committed file.

- [ ] **Step 1: Write the failing check** — `node capture/lib/ui2-tokens.mjs && git status --porcelain iphone/MakeReady/UI2Preview` → FAIL: it recreates the old folder (`?? iphone/MakeReady/UI2Preview/`). Delete what it created: `rm -rf iphone/MakeReady/UI2Preview`.

- [ ] **Step 2: Point the generator at the new path** — in `capture/lib/ui2-tokens.mjs`:

```js
const tokensOutPath = path.resolve(makereadyRoot, 'iphone/MakeReadyUI/Tokens.swift')
```

and the emitted header at :106 → `// MakeReadyUI — the UI 2.0 module` (match Task 1 exactly); the :2 comment likewise.

- [ ] **Step 3: Run it and watch it pass** — `node capture/lib/ui2-tokens.mjs && git diff --exit-code iphone/MakeReadyUI/Tokens.swift` → exit 0 (byte-identical), and `test ! -e iphone/MakeReady/UI2Preview`.

- [ ] **Step 4: Repoint the tooling strings** — `.claude/scripts/list-ui2-refs.mjs:238` → `previewDir = 'iphone/MakeReadyUI'`; then in the five `.claude/commands/*.md` files and `.claude/builder.md`:

```bash
cd /Users/lukekeith/www/makeready
sed -i '' -e 's#iphone/MakeReady/UI2Preview#iphone/MakeReadyUI#g' \
          -e 's#ui2-preview-sync\.rb#makereadyui-sync.rb#g' \
          -e 's#UI2Preview\.#MakeReadyUI.#g' \
          -e 's#`UI2Preview`#`MakeReadyUI`#g' \
  .claude/commands/ui2-component-build.md .claude/commands/ui2-component-delete.md \
  .claude/commands/ui2-component-merge.md .claude/commands/ui2-component-update.md \
  .claude/commands/ui2-resolve.md .claude/builder.md
grep -n 'UI2Preview\|preview only\|PREVIEW ONLY' .claude/commands/ui2-component-build.md
```

Read every remaining hit. The scope-fence rules at `ui2-component-build.md:118,121` become: files are written under `iphone/MakeReadyUI/`; the "wired into no screen" rule becomes "never hand-wire — the app wires these from `iphone/MakeReady/UI2/` (ui2-shell D2)". Fix the two comment-only hits in `capture/server.mjs:1251` and `capture/src/lib/ui2-sample-call.js:17`. `node .claude/scripts/list-ui2-refs.mjs | head -3` → still prints the registry header.

- [ ] **Step 5: Re-capture and diff (D18)** — start capture (`/capture-start`); confirm `curl -s localhost:5950/api/compare/manifest | head -c 200` answers. Copy the current iPhone renders aside: `cp -R capture/fixtures/iphone/ztmp-ui2/screenshots /tmp/ui2-baseline` (use the session scratchpad). Re-capture every built component and screen through the d2m capture lane (`bash capture/runners/iphone/capture.sh ui2 '*'`). Then for each PNG: `node capture/runners/compare/diff.mjs /tmp/ui2-baseline/<device>/<file> capture/fixtures/iphone/ztmp-ui2/screenshots/<device>/<file>` → 0.00%. Any non-zero diff is a failure: report the file, don't fix it here.

- [ ] **Step 6: Commit** — `git add capture/lib/ui2-tokens.mjs capture/server.mjs capture/src/lib/ui2-sample-call.js .claude/scripts/list-ui2-refs.mjs .claude/commands .claude/builder.md` → `refactor(ui2-shell): capture tooling follows MakeReadyUI rename`.

### Task 4: Retire the 1.0 capture cases
App: iphone
Phase: 3
Recipe: SPEC D30

**Files:**
- Modify: `iphone/MakeReadyCaptureTests/ViewRegistry.swift`
- Delete (from disk and target, only if referenced solely by removed cases): 1.0-only capture-test helpers the compiler names after Step 3
- Test: `iphone/MakeReadyCaptureTests/ViewRegistryKeysTests.swift` (create)

**Interfaces:**
- Consumes: `ViewRegistry`'s existing view-key switch (keys like `"component.ui2.C-019"`, 2.0 screen keys).
- Produces: a `ViewRegistry` whose every case key starts with `component.ui2.` or names a 2.0 screen, and a static `ViewRegistry.registeredKeys: [String]`.

- [ ] **Step 1: Write the failing test** — `ViewRegistryKeysTests.swift`:

```swift
import XCTest
@testable import MakeReady

final class ViewRegistryKeysTests: XCTestCase {
    /// SPEC D30: only 2.0 cases remain.
    func testOnlyUI2KeysRemain() {
        let legacy = ViewRegistry.registeredKeys.filter { !$0.hasPrefix("component.ui2.") && !$0.hasPrefix("screen.") }
        XCTAssertEqual(legacy, [], "1.0 capture cases must be retired (D30)")
    }
}
```

First read `ViewRegistry.swift` to learn its 2.0 screen-key prefix; if screen keys are not `screen.`, change the second `hasPrefix` to the prefix the file actually uses.

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL: `registeredKeys` does not exist.

- [ ] **Step 3: Remove the 1.0 cases** — delete every `case "<key>":` arm whose key is not a 2.0 key, together with the private helpers only those arms used. Add, next to the switch, the list of the keys that remain:

```swift
extension ViewRegistry {
    /// Every key this registry renders (SPEC D30: 2.0 only).
    static let registeredKeys: [String] = [
        // one string per remaining `case` label, in switch order
    ]
}
```

Fill the array with the exact remaining case labels (generate it: `grep -o 'case "[^"]*"' iphone/MakeReadyCaptureTests/ViewRegistry.swift | sed 's/case //' | paste -sd, -`). Then delete any capture-test file the compiler reports as now unused only by 1.0 cases, and re-run `ruby iphone/scripts/capture-targets.rb` (the capture app compiles the shared ViewRegistry).

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS, including `ViewRegistryKeysTests`.

- [ ] **Step 5: Stage** — `refactor(ui2-shell): retire 1.0 iPhone capture cases`; STOP.

### Task 5: Move model types out of UI files
App: iphone
Phase: 3
Recipe: SPEC D5 (first half) — no behaviour change

**Files:**
- Move: `iphone/MakeReady/Pages/Manage/Program/Models/StudyModels.swift` → `iphone/MakeReady/State/Models/StudyModels.swift`
- Move: `iphone/MakeReady/Pages/Manage/Group/Models/GroupModels.swift` → `iphone/MakeReady/State/Models/GroupModels.swift`
- Create: `iphone/MakeReady/State/Models/ExtractedModels.swift` — the type declarations cut from `Pages/Manage/Group/GroupInvitePage.swift` (`GroupInviteData`, `GroupInviteResponse`), `Pages/Manage/Group/Enrollment/StudyInvitePage.swift` (`LessonInviteData`, `LessonInviteResponse`), `Pages/Bible/BibleVersionMenu.swift` (`BibleVersion`, `BibleTranslationsResponse`), `Components/Calendar/CalendarModels.swift` (`SplitCalendarEvent`, `CalendarActivityIcon`), `Components/Card/CardActivity.swift` (`ActivityLogResponse`), `Components/Card/CardData.swift` (`LessonActivityStatus`)
- Modify: the six source files above (declarations removed)
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (file moves)

**Interfaces:**
- Consumes: nothing new.
- Produces: every type `State/**`, `AuthManager.swift`, `Utilities/**` and `Services/**` reference is declared under `State/Models/` — Task 6 relies on this.

- [ ] **Step 1: Write the failing check** — create `iphone/scripts/check-kept-models.sh`:

```bash
#!/usr/bin/env bash
# SPEC D5: no type a kept file needs may be declared under Pages/ or Components/.
set -euo pipefail
cd "$(dirname "$0")/../MakeReady"
types="GroupInviteData GroupInviteResponse LessonInviteData LessonInviteResponse BibleVersion BibleTranslationsResponse SplitCalendarEvent CalendarActivityIcon ActivityLogResponse LessonActivityStatus StudyProgram UserGroup"
fail=0
for t in $types; do
  if grep -rqE "^(struct|enum|class|final class) $t\b" Pages Components; then echo "still in UI: $t"; fail=1; fi
done
exit $fail
```

Run `bash iphone/scripts/check-kept-models.sh` → FAIL listing all 12.

- [ ] **Step 2: Move the files and cut the declarations** — `git mv` the two model files; cut each listed declaration (with its `CodingKeys`/extensions) into `ExtractedModels.swift` verbatim, with `import Foundation` (and `import SwiftUI` only if a moved type needs `Color`). Update file references with Ruby:

```ruby
require 'xcodeproj'
p = Xcodeproj::Project.open('iphone/MakeReady.xcodeproj')
models = p.main_group.find_subpath('MakeReady/State/Models', true)
%w[StudyModels.swift GroupModels.swift].each do |name|
  ref = p.files.find { |f| f.path&.end_with?(name) && f.real_path.to_s.include?('/Pages/') }
  ref.move(models); ref.path = name
end
app = p.targets.find { |t| t.name == 'MakeReady' }
app.add_file_references([models.new_reference('ExtractedModels.swift')]) unless models.files.any? { |f| f.path == 'ExtractedModels.swift' }
p.save
```

Then `ruby iphone/scripts/capture-targets.rb` (keeps the capture app in sync).

- [ ] **Step 3: Run it and watch it pass** — `bash iphone/scripts/check-kept-models.sh` → exit 0; `npm run ios:build-check -- --test` → PASS, same count as before (no behaviour change).

- [ ] **Step 4: Stage** — `refactor(ui2-shell): move model types into State/Models`; STOP.

### Task 6: Take legacy UI out of the target; put the 2.0 files in; mount UI2Root
App: iphone
Phase: 3
Recipe: SPEC D3, D5, D6, D29 · `/ios-error-surface` (for anything caught while rewiring)

**Files:**
- Create: `iphone/scripts/remove-legacy-ui.rb` (kept — idempotent, documents D5)
- Modify: `iphone/scripts/makereadyui-sync.rb` (second membership in `MakeReady`)
- Modify: `iphone/MakeReady/MakeReadyApp.swift`
- Create: `iphone/MakeReady/UI2/UI2Root.swift`
- Create: `iphone/MakeReady/UI2/Containers/Auth/LoginContainer.swift` (minimal; Task 8 completes it)
- Modify: `iphone/MakeReady/Utilities/ActivityStyle.swift` (drop `Color` members if they reference `Colors.swift`)
- Test: `iphone/MakeReadyCaptureTests/AppTargetMembershipTests.swift` (create)

**Interfaces:**
- Consumes: Task 5's `State/Models/**`; `AuthManager` (`isAuthenticated`, `signIn()`), `AppState.shared`; `MakeReadyUI` types `LoginScreen(state:onSignIn:)`, `LoginScreen.State(authenticating:errorMessage:)`.
- Produces: `struct UI2Root: View` reading `@Environment(AuthManager.self)`; `struct LoginContainer: View`; `MakeReadyApp` mounts `UI2Root` unconditionally; `makereadyui-sync.rb` adds each `MakeReadyUI` source to BOTH targets.

- [ ] **Step 1: Tag the legacy line** — `git tag legacy-final HEAD` (the last commit with the legacy UI in the target; tell the human in your report — pushing the tag is theirs).

- [ ] **Step 2: Write the failing test** — `AppTargetMembershipTests.swift`:

```swift
import XCTest
@testable import MakeReady

final class AppTargetMembershipTests: XCTestCase {
    /// SPEC D29: 2.0 views compile into the app module.
    func testLoginScreenIsInTheAppModule() {
        let state = LoginScreen.State(authenticating: false, errorMessage: "")
        XCTAssertFalse(state.authenticating)
        XCTAssertEqual(String(reflecting: LoginScreen.self), "MakeReady.LoginScreen")
    }
}
```

- [ ] **Step 3: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL: `LoginScreen` is ambiguous or not in `MakeReady`.

- [ ] **Step 4: Write `remove-legacy-ui.rb`**

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true
# SPEC D5: take the legacy UI out of the MakeReady target. Files stay on disk
# (run the old app from the `legacy-final` tag). Idempotent.
require 'xcodeproj'
require 'pathname'

root = Pathname.new(__dir__).parent.parent
project = Xcodeproj::Project.open(root.join('iphone/MakeReady.xcodeproj').to_s)
app = project.targets.find { |t| t.name == 'MakeReady' } || abort('MakeReady target not found')
base = root.join('iphone/MakeReady')

REMOVE_DIRS  = %w[Pages Components Fixtures].freeze
REMOVE_FILES = %w[
  MainView.swift LoginView.swift Colors.swift Typography.swift FixturesManager.swift
  Services/NavigationCoordinator.swift Services/Route.swift Services/OverlayManager.swift
  Utilities/CachedAsyncImage.swift Utilities/CachedCardImage.swift
].freeze

removed = []
app.source_build_phase.files.dup.each do |bf|
  ref = bf.file_ref or next
  rel = ref.real_path.relative_path_from(base).to_s rescue next
  next unless REMOVE_DIRS.any? { |d| rel.start_with?("#{d}/") } || REMOVE_FILES.include?(rel)
  app.source_build_phase.remove_build_file(bf)
  removed << rel
end
project.save
puts "removed #{removed.size} file(s) from MakeReady target"
```

Run `ruby iphone/scripts/remove-legacy-ui.rb` → prints a count in the hundreds.

- [ ] **Step 5: Add the second membership** — in `makereadyui-sync.rb`, after `target = …`, add `app = project.targets.find { |t| t.name == 'MakeReady' } || abort('MakeReady target not found')`, and inside the sources loop, after `target.add_file_references([ref])`, also:

```ruby
  app.add_file_references([ref]) unless app.source_build_phase.files_references.include?(ref)
```

(restructure the `next if` so a ref already in `target` still gets added to `app`); add each `.xcassets` to `app.resources_build_phase` the same way. Run `ruby iphone/scripts/makereadyui-sync.rb`, then `ruby iphone/scripts/capture-targets.rb`.

- [ ] **Step 6: Write `UI2Root` and a minimal `LoginContainer`**

```swift
// iphone/MakeReady/UI2/UI2Root.swift
import SwiftUI

/// SPEC D3/D13: the app root. Signed out → Login; signed in → the shell
/// (an empty page until Phase 4's UI2Shell).
struct UI2Root: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                Token.layoutBackground.ignoresSafeArea()
            } else {
                LoginContainer()
            }
        }
    }
}
```

```swift
// iphone/MakeReady/UI2/Containers/Auth/LoginContainer.swift
import SwiftUI

/// SPEC D7 (outcomes completed in Task 8).
struct LoginContainer: View {
    @Environment(AuthManager.self) private var authManager
    @State private var authenticating = false
    @State private var errorMessage = ""

    var body: some View {
        LoginScreen(
            state: .init(authenticating: authenticating, errorMessage: errorMessage),
            onSignIn: signIn
        )
        .ignoresSafeArea(edges: .bottom)
    }

    private func signIn() {
        guard !authenticating else { return }
        authenticating = true
        errorMessage = ""
        Task { @MainActor in
            defer { authenticating = false }
            do { try await authManager.signIn() } catch { errorMessage = "Authentication failed" }
        }
    }
}
```

- [ ] **Step 7: Rewrite `MakeReadyApp`** — replace the `Group { if … MainView … LoginView … }` with `UI2Root().environment(authManager)`; delete `KeyboardToolbarInstaller.install()` from `init()`; keep `.onOpenURL`/`handleDeepLink`, the three `.task`s and the `scenePhase` handler unchanged (D17).

- [ ] **Step 8: Fix what the compiler reports** — `npm run ios:build-check`. For each error in a kept file: move the missing type into `State/Models/ExtractedModels.swift`, or remove the dead UI reference (e.g. `ActivityStyle`'s `Color` members — delete them if no kept file uses them). **Never re-add a file from the D5 remove list.** Where a container or kept file means SwiftUI's button, write `SwiftUI.Button` (C-105 `Button` shadows it). In capture-test files, qualify any now-ambiguous 2.0 name as `MakeReadyUI.X` (F17).

- [ ] **Step 9: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS incl. `AppTargetMembershipTests`; `cd iphone && swiftlint` clean; `ruby iphone/scripts/capture-targets.rb --check` → exit 0.

- [ ] **Step 10: Stage** — `feat(ui2-shell): legacy UI out of the app target, UI 2.0 root mounted`; STOP.

### Task 7: AuthManager — leader denial, dev-login gate, 401-only sign-out
App: iphone
Phase: 3
Recipe: `/ios-error-surface` · SPEC D7, D27

**Files:**
- Modify: `iphone/MakeReady/AuthManager.swift:33-45` (AuthError), `:137-236` (callback), `:323-358` (`fetchCurrentUser`/`checkAuthStatus`), `:406-461` (`devLogin`)
- Modify: `iphone/MakeReady/State/API/APIClient.swift:15-40` (APIError), `:159-178` (status handling)
- Create: `iphone/MakeReady/AuthCallbackParser.swift`
- Test: `iphone/MakeReadyCaptureTests/AuthCallbackParserTests.swift`, `iphone/MakeReadyCaptureTests/AuthStatusPolicyTests.swift`

**Interfaces:**
- Consumes: server `makeready://auth/error?message=…` redirect, `GET /auth/leader-access` → `{canAccess: Bool}` (SPEC §Contract).
- Produces: `AuthError.leaderAccessDenied`; `APIError.unauthorized` (HTTP 401); `enum AuthCallback { case code(String), denied(String?), invalid }` with `static func parse(_ url: URL?) -> AuthCallback`; `enum AuthStatusPolicy { static func shouldSignOut(after error: Error) -> Bool }`.

- [ ] **Step 1: Write the failing tests**

```swift
// AuthCallbackParserTests.swift
import XCTest
@testable import MakeReady

final class AuthCallbackParserTests: XCTestCase {
    func testCode() {
        XCTAssertEqual(AuthCallback.parse(URL(string: "makeready://auth/callback?code=abc")), .code("abc"))
    }
    func testLeaderDenialRedirect() {
        XCTAssertEqual(AuthCallback.parse(URL(string: "makeready://auth/error?message=No%20access")), .denied("No access"))
    }
    func testMissing() {
        XCTAssertEqual(AuthCallback.parse(nil), .invalid)
        XCTAssertEqual(AuthCallback.parse(URL(string: "makeready://auth/callback")), .invalid)
    }
}
```

```swift
// AuthStatusPolicyTests.swift
import XCTest
@testable import MakeReady

final class AuthStatusPolicyTests: XCTestCase {
    /// SPEC D27: only a 401 signs out.
    func testOnly401SignsOut() {
        XCTAssertTrue(AuthStatusPolicy.shouldSignOut(after: NSError(domain: "AuthError", code: 401)))
        XCTAssertTrue(AuthStatusPolicy.shouldSignOut(after: APIError.unauthorized))
        XCTAssertFalse(AuthStatusPolicy.shouldSignOut(after: URLError(.notConnectedToInternet)))
        XCTAssertFalse(AuthStatusPolicy.shouldSignOut(after: URLError(.timedOut)))
        XCTAssertFalse(AuthStatusPolicy.shouldSignOut(after: URLError(.badServerResponse)))
        XCTAssertFalse(AuthStatusPolicy.shouldSignOut(after: APIError.serverError("Too many requests")))
    }
}
```

- [ ] **Step 2: Run them and watch them fail** — `npm run ios:build-check -- --test` → FAIL: `AuthCallback`, `AuthStatusPolicy`, `APIError.unauthorized` undefined.

- [ ] **Step 3: Implement the parser and policy**

```swift
// iphone/MakeReady/AuthCallbackParser.swift
import Foundation

/// What the OAuth web session handed back (SPEC D7). The server's iOS leader
/// gate redirects a non-leader to makeready://auth/error?message=… with no code.
enum AuthCallback: Equatable {
    case code(String)
    case denied(String?)
    case invalid

    static func parse(_ url: URL?) -> AuthCallback {
        guard let url, let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return .invalid }
        let items = parts.queryItems ?? []
        if url.host == "auth", url.path == "/error" {
            return .denied(items.first { $0.name == "message" }?.value)
        }
        if let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty { return .code(code) }
        return .invalid
    }
}

/// SPEC D27: a launch/refresh error signs the user out only when the server
/// said the session is gone (401). Offline, timeouts, 5xx and 429 keep them in.
enum AuthStatusPolicy {
    static func shouldSignOut(after error: Error) -> Bool {
        if case APIError.unauthorized = error { return true }
        let ns = error as NSError
        return ns.domain == "AuthError" && ns.code == 401
    }
}
```

In `APIError` add `case unauthorized` (`errorDescription`: `"Your session has ended. Sign in again."`), and in `performRequest` before the generic non-2xx branch: `if httpResponse.statusCode == 401 { throw APIError.unauthorized }`. In `AuthError` add `case leaderAccessDenied` (`errorDescription`: `"This account doesn't have leader access."`).

- [ ] **Step 4: Use them in AuthManager**
  - In the `ASWebAuthenticationSession` handler, replace the `URLComponents … code` extraction with `switch AuthCallback.parse(callbackURL)`: `.code(let code)` → the existing exchange/fetch Task; `.denied` → `continuation.resume(throwing: AuthError.leaderAccessDenied)`; `.invalid` → the existing "No auth code in callback" error.
  - In `devLogin(email:)`, after `storeSessionCookie(sessionCookie)` and **before** `self.isAuthenticated = true`, check leader access:

```swift
        struct LeaderAccess: Decodable { let canAccess: Bool }
        let access = try await APIClient.shared.get("/auth/leader-access", responseType: LeaderAccess.self)
        guard access.canAccess else {
            try? await signOut()
            throw AuthError.leaderAccessDenied
        }
```

  - In `checkAuthStatus()`'s `catch`, only clear the user when `AuthStatusPolicy.shouldSignOut(after: error)`; otherwise keep `currentUser`/`isAuthenticated` from the cached user (`loadUser()` already restored it at init) and log via `Log.auth.info`.

- [ ] **Step 5: Run them and watch them pass** — `npm run ios:build-check -- --test` → PASS.

- [ ] **Step 6: Stage** — `feat(ui2-shell): auth reads the leader-denial redirect; only a 401 signs out`; STOP.

### Task 8: LoginContainer outcomes
App: iphone
Phase: 3
Recipe: `/ios-error-surface` · SPEC D7

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Auth/LoginContainer.swift`
- Create: `iphone/MakeReady/UI2/Containers/Auth/LoginOutcome.swift`
- Test: `iphone/MakeReadyCaptureTests/LoginOutcomeTests.swift`

**Interfaces:**
- Consumes: `AuthError.leaderAccessDenied`, `ASWebAuthenticationSessionError.canceledLogin` (Task 7).
- Produces: `enum LoginOutcome { static func message(for error: Error) -> String? }` — `nil` = return to idle silently.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import AuthenticationServices
@testable import MakeReady

final class LoginOutcomeTests: XCTestCase {
    func testLeaderDenied() {
        XCTAssertEqual(LoginOutcome.message(for: AuthError.leaderAccessDenied), "This account doesn't have leader access.")
    }
    func testCancelIsSilent() {
        let cancel = NSError(domain: ASWebAuthenticationSessionErrorDomain,
                             code: ASWebAuthenticationSessionError.canceledLogin.rawValue)
        XCTAssertNil(LoginOutcome.message(for: cancel))
    }
    func testAnythingElse() {
        XCTAssertEqual(LoginOutcome.message(for: URLError(.timedOut)), "Authentication failed")
        XCTAssertEqual(LoginOutcome.message(for: NSError(domain: "AuthError", code: -1)), "Authentication failed")
    }
}
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL: `LoginOutcome` undefined.

- [ ] **Step 3: Implement**

```swift
// LoginOutcome.swift
import AuthenticationServices
import Foundation

/// SPEC D7 / login §3: the welcome line becomes the error message.
enum LoginOutcome {
    static func message(for error: Error) -> String? {
        if case AuthError.leaderAccessDenied = error { return "This account doesn't have leader access." }
        let ns = error as NSError
        if ns.domain == ASWebAuthenticationSessionErrorDomain,
           ns.code == ASWebAuthenticationSessionError.canceledLogin.rawValue { return nil }
        return "Authentication failed"
    }
}
```

In `LoginContainer.signIn()` replace the `catch` body with `errorMessage = LoginOutcome.message(for: error) ?? ""` and log through `Log.auth.error` (no banner — D28).

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS. Then in the simulator (ask the human before launching it): signed out → 2.0 Login; tap Google → cancel → idle with "Welcome to MakeReady".

- [ ] **Step 5: Stage** — `feat(ui2-shell): login container maps auth outcomes`; STOP.

### Task 9: Shell state — tabs, sections, routes
App: iphone
Phase: 4
Recipe: `/nav-route` · SPEC D10, D12, D13, D19

**Files:**
- Create: `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift`
- Test: `iphone/MakeReadyCaptureTests/UI2ShellModelTests.swift`

**Interfaces:**
- Consumes: `TabBar.Tab` (`home, calendar, search, profile`), `TopNav.designedTabs` (8 labels).
- Produces: `enum UI2Section: String, CaseIterable { case home = "Home", library = "Library", groups = "Groups", members = "Members", enrollments = "Enrollments", invites = "Invites", programs = "Programs", media = "Media" }`; `enum UI2Route: Equatable { case tab(TabBar.Tab), section(UI2Section) }`; `struct UI2ShellModel` with `var tab: TabBar.Tab`, `var section: UI2Section`, `var expansion: Double`, `var scrollOffset: CGFloat`, `var showsTopNav: Bool { tab == .home }`, `mutating func apply(_ route: UI2Route)`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import MakeReady

final class UI2ShellModelTests: XCTestCase {
    func testEntryPoint() {
        let m = UI2ShellModel()
        XCTAssertEqual(m.tab, .home); XCTAssertEqual(m.section, .home); XCTAssertTrue(m.showsTopNav)
    }
    func testSectionsMatchTopNavContract() {
        XCTAssertEqual(UI2Section.allCases.map(\.rawValue), TopNav.designedTabs)
    }
    func testTopNavOnlyOnHome() {
        var m = UI2ShellModel()
        for tab in [TabBar.Tab.calendar, .search, .profile] { m.apply(.tab(tab)); XCTAssertFalse(m.showsTopNav) }
    }
    func testSectionSurvivesTabRoundTrip() {
        var m = UI2ShellModel()
        m.apply(.section(.groups)); m.scrollOffset = 120
        m.apply(.tab(.search)); m.apply(.tab(.home))
        XCTAssertEqual(m.section, .groups); XCTAssertEqual(m.scrollOffset, 120)
    }
    func testRetapHomeReturnsToHomeSection() {
        var m = UI2ShellModel()
        m.apply(.section(.members)); m.apply(.tab(.home))
        XCTAssertEqual(m.section, .home)
    }
    func testSelectingSectionCollapses() {
        var m = UI2ShellModel(); m.expansion = 1
        m.apply(.section(.invites))
        XCTAssertEqual(m.expansion, 0)
    }
}
```

Note the two round-trip rules: arriving at Home **from another tab** restores the section (D12); tapping Home **while on Home** returns to section Home (D13).

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL: types undefined.

- [ ] **Step 3: Implement**

```swift
// UI2ShellModel.swift
import CoreGraphics

/// SPEC D12/D13: the 8 TopNav sections, in C-019's closed order.
enum UI2Section: String, CaseIterable {
    case home = "Home", library = "Library", groups = "Groups", members = "Members"
    case enrollments = "Enrollments", invites = "Invites", programs = "Programs", media = "Media"
}

/// Release 1 routes: only the two navigation levels (SPEC §iphone Phase 3).
enum UI2Route: Equatable {
    case tab(TabBar.Tab)
    case section(UI2Section)
}

/// Ephemeral shell state (SPEC D19) — held as @State by UI2Shell, never persisted.
struct UI2ShellModel {
    var tab: TabBar.Tab = .home
    var section: UI2Section = .home
    var expansion: Double = 0
    var scrollOffset: CGFloat = 0

    var showsTopNav: Bool { tab == .home }

    mutating func apply(_ route: UI2Route) {
        switch route {
        case .tab(let next):
            if next == .home && tab == .home { section = .home }
            tab = next
        case .section(let next):
            section = next
            expansion = 0
        }
    }
}
```

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS.

- [ ] **Step 5: Stage** — `feat(ui2-shell): shell tab/section model`; STOP.

### Task 10: UI2Shell view — TabBar, TopNav host with the morph, empty pages
App: iphone
Phase: 4
Recipe: `/transition-review` · `/animation-debug` · SPEC D10–D14, D17, D24 · ⛔ read the d2m `shell-topnav` + `shell-tabs` specs first (SPEC F2); if they don't exist, STOP and report
Build-time risk: F2 — placement, safe area and the morph choreography come from those specs, not from this block

**Files:**
- Create: `iphone/MakeReady/UI2/Shell/UI2Shell.swift`
- Create: `iphone/MakeReady/UI2/Shell/TopNavHost.swift`
- Create: `iphone/MakeReady/UI2/Shell/EmptyPage.swift`
- Modify: `iphone/MakeReady/UI2/UI2Root.swift` (signed-in branch → `UI2Shell()`)
- Test: `iphone/MakeReadyCaptureTests/TopNavDragTests.swift`

**Interfaces:**
- Consumes: Task 9's `UI2ShellModel`, `UI2Section`, `UI2Route`; `TabBar(selected:onSelect:onAdd:)`; `TopNav(tabs:selectedTab:expansion:scrollOffset:onSelect:onToggleExpansion:onAdd:)`; `AppState.shared.loadInitialData()`; `PushNotificationManager.shared.pendingDeepLink`.
- Produces: `struct UI2Shell: View`; `struct TopNavHost: View` (binding to `UI2ShellModel`); `enum TopNavDrag { static func expansion(from start: Double, translation: CGFloat, travel: CGFloat) -> Double; static func settle(_ value: Double, velocity: CGFloat) -> Double }`; `struct EmptyPage: View`; `UI2Shell(content:)`-free — section content is chosen inside `UI2Shell.sectionContent` (Task 13 plugs Home in, Task 15 Profile).

- [ ] **Step 1: Write the failing test** (the drag math is the testable part of the morph)

```swift
import XCTest
@testable import MakeReady

final class TopNavDragTests: XCTestCase {
    func testDragDownExpands() {
        XCTAssertEqual(TopNavDrag.expansion(from: 0, translation: 32, travel: 64), 0.5, accuracy: 0.001)
    }
    func testClamped() {
        XCTAssertEqual(TopNavDrag.expansion(from: 0, translation: 500, travel: 64), 1)
        XCTAssertEqual(TopNavDrag.expansion(from: 1, translation: -500, travel: 64), 0)
    }
    func testSettleByPositionAndVelocity() {
        XCTAssertEqual(TopNavDrag.settle(0.6, velocity: 0), 1)
        XCTAssertEqual(TopNavDrag.settle(0.4, velocity: 0), 0)
        XCTAssertEqual(TopNavDrag.settle(0.3, velocity: 900), 1)
        XCTAssertEqual(TopNavDrag.settle(0.7, velocity: -900), 0)
    }
}
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL: `TopNavDrag` undefined.

- [ ] **Step 3: Implement the drag math** (in `TopNavHost.swift`)

```swift
/// SPEC D14: finger-tracked morph. `travel` = expanded row height − collapsed row
/// height, read from the shell-topnav spec / C-019 §2 (collapsed 32, expanded 96 → 64).
enum TopNavDrag {
    static func expansion(from start: Double, translation: CGFloat, travel: CGFloat) -> Double {
        guard travel > 0 else { return start }
        return min(1, max(0, start + Double(translation / travel)))
    }
    /// Flick wins over position past 500 pt/s; otherwise the nearer end.
    static func settle(_ value: Double, velocity: CGFloat) -> Double {
        if velocity > 500 { return 1 }
        if velocity < -500 { return 0 }
        return value >= 0.5 ? 1 : 0
    }
}
```

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS.

- [ ] **Step 5: Build the views** — `EmptyPage`:

```swift
import SwiftUI
/// SPEC D10: an unwired root — the layout background, nothing else.
struct EmptyPage: View {
    var body: some View { Token.layoutBackground.ignoresSafeArea() }
}
```

`TopNavHost` renders `TopNav(tabs: UI2Section.allCases.map(\.rawValue), selectedTab: model.section.rawValue, expansion: model.expansion, scrollOffset: model.scrollOffset, onSelect: { label in if let s = UI2Section(rawValue: label) { withAnimation(<shell-topnav motion token>) { model.apply(.section(s)) } } }, onToggleExpansion: { withAnimation(<token>) { model.expansion = model.expansion < 0.5 ? 1 : 0 } }, onAdd: { _ in })` and attaches a vertical `DragGesture` that sets `model.expansion = TopNavDrag.expansion(from: dragStart, translation: value.translation.height, travel: 64)` on change and `withAnimation(<token>) { model.expansion = TopNavDrag.settle(model.expansion, velocity: value.velocity.height) }` on end; horizontal scrolling feeds `model.scrollOffset`. Use the Motion token the shell-topnav spec names (from `Token`), never a literal duration, and no `asyncAfter`.

`UI2Shell`:

```swift
import SwiftUI

/// SPEC D11: the shell owns the app chrome; roots render content only.
struct UI2Shell: View {
    @State private var model = UI2ShellModel()

    var body: some View {
        VStack(spacing: 0) {
            if model.showsTopNav { TopNavHost(model: $model) }
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
            TabBar(selected: model.tab, onSelect: { model.apply(.tab($0)) }, onAdd: {})
        }
        .background(Token.layoutBackground.ignoresSafeArea())
        .task {
            PushNotificationManager.shared.pendingDeepLink = nil   // D17
            await AppState.shared.loadInitialData()                 // D24
        }
    }

    @ViewBuilder private var content: some View {
        switch model.tab {
        case .home: sectionContent
        case .calendar, .search: EmptyPage()
        case .profile: EmptyPage()            // Task 15 replaces this
        }
    }

    @ViewBuilder private var sectionContent: some View {
        switch model.section {
        case .home: EmptyPage()               // Task 13 replaces this
        default: EmptyPage()
        }
    }
}
```

Adjust the pinning and safe-area handling exactly to the shell-topnav / shell-tabs specs. In `UI2Root`, replace the signed-in `Token.layoutBackground…` with `UI2Shell()`.

- [ ] **Step 6: Review the motion** — run `/transition-review` over this diff; fix every FAIL.

- [ ] **Step 7: Verify in the simulator** (ask the human before launching) — sign in → TopNav + TabBar; drag the TopNav open/closed; pick each of the 8 sections; switch tabs (no TopNav on Calendar/Search/Profile); back to Home restores the section; re-tap Home → section Home.

- [ ] **Step 8: Stage** — `feat(ui2-shell): shell with TabBar and morphing TopNav`; STOP.

### Task 11: Analytics models and DashboardActions
App: iphone
Phase: 5
Recipe: `/ios-error-surface` · SPEC §Contract, D8, D20–D22, D24–D27

**Files:**
- Create: `iphone/MakeReady/State/Models/DashboardModels.swift`
- Create: `iphone/MakeReady/State/Actions/DashboardActions.swift`
- Modify: `iphone/MakeReady/State/AppState.swift` (add `var dashboard = DashboardSnapshot()`; clear it in `clearAllData()` and `reloadForEnvironmentSwitch()`)
- Modify: `iphone/MakeReady/State/Persistence/PersistedState.swift` (field, `CodingKeys` case, `decodeIfPresent`, `init(from: AppState)`, restore in `AppState`)
- Test: `iphone/MakeReadyCaptureTests/DashboardActionsTests.swift`

**Interfaces:**
- Consumes: `APIClientProtocol.post(_:body:responseType:)`, `.get(_:responseType:)`; `AppState.organizationId`; `AuthStatusPolicy.shouldSignOut(after:)` (Task 7).
- Produces:

```swift
struct DashboardSnapshot: Codable, Equatable {
    var completedSeries: [String: Int] = [:]      // yyyy-MM-dd → lesson_completions, last 24 days
    var completedTotal: Int = 0
    var completedPrevious: Int? = nil             // compareToPrevious total
    var watchSeconds: Int? = nil                  // snapshot, lifetime
    var activityDays: [String: Int] = [:]         // yyyy-MM-dd → completions, 28 back + today
    var kpiNames: [String] = ["lesson_completions", "watch_seconds"]
    var refreshedAt: Date? = nil
}
struct DashboardActions {
    init(api: APIClientProtocol = APIClient.shared, state: AppState? = nil, now: @escaping () -> Date = Date.init, timeZone: TimeZone = .current, onUnauthorized: @escaping @MainActor () async -> Void = {})
    @MainActor func refresh() async
}
```

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import MakeReady

@MainActor
final class DashboardActionsTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private let tz = TimeZone(identifier: "America/Denver")!
    private let now = ISO8601DateFormatter().date(from: "2026-10-25T18:00:00Z")!

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
        api.stub("GET", "/api/preferences/dashboard.kpis", json: #"{"key":"dashboard.kpis","value":"","isDefault":true}"#)
        api.stub("POST", "/api/analytics/query", json: #"{"success":true,"rows":[{"day":"2026-10-24","lesson_completions":3},{"day":"2026-10-25","lesson_completions":2}],"previousRows":[{"lesson_completions":4}]}"#)
    }

    func testSendsTimezoneOrgAndNoWindowOnSnapshot() async {
        state.organizationId = "org1"
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: tz).refresh()
        let bodies = api.calls.filter { $0.endpoint == "/api/analytics/query" }.compactMap(\.body)
        XCTAssertFalse(bodies.isEmpty)
        for b in bodies {
            XCTAssertEqual(b["timezone"] as? String, "America/Denver")
            XCTAssertEqual((b["filters"] as? [String: Any])?["organizationId"] as? String, "org1")
        }
        let snapshot = bodies.first { ($0["metrics"] as? [String]) == ["watch_seconds"] }
        XCTAssertNotNil(snapshot)
        XCTAssertNil((snapshot?["filters"] as? [String: Any])?["from"])
        XCTAssertNil(snapshot?["dimensions"])
    }

    func testNoOrgFilterWhenOrgUnknown() async {
        state.organizationId = nil
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: tz).refresh()
        for b in api.calls.compactMap(\.body) { XCTAssertNil((b["filters"] as? [String: Any])?["organizationId"]) }
    }

    func testStoresCompletionsByDay() async {
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: tz).refresh()
        XCTAssertEqual(state.dashboard.activityDays["2026-10-24"], 3)
        XCTAssertNotNil(state.dashboard.refreshedAt)
    }

    func testKeepsCacheOnFailure() async {
        state.dashboard.completedTotal = 9
        api.errorToThrow = URLError(.notConnectedToInternet)
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: tz).refresh()
        XCTAssertEqual(state.dashboard.completedTotal, 9)
    }

    func testUnauthorizedSignsOut() async {
        api.errorToThrow = APIError.unauthorized
        var signedOut = false
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: tz, onUnauthorized: { signedOut = true }).refresh()
        XCTAssertTrue(signedOut)
    }

    func testLegacySnapshotWithoutDashboardDecodes() throws {
        let legacy = try JSONEncoder().encode(PersistedState(from: state))
        var dict = try XCTUnwrap(JSONSerialization.jsonObject(with: legacy) as? [String: Any])
        dict.removeValue(forKey: "dashboard")
        let data = try JSONSerialization.data(withJSONObject: dict)
        XCTAssertNoThrow(try JSONDecoder().decode(PersistedState.self, from: data))
    }
}
```

If `PersistedState`'s encoder uses a custom date strategy, use the same encoder/decoder `StatePersistence` uses (read `StatePersistence.swift:75-92` first).

- [ ] **Step 2: Run them and watch them fail** — `npm run ios:build-check -- --test` → FAIL: `DashboardActions`, `state.dashboard` undefined.

- [ ] **Step 3: Implement the models** — `DashboardModels.swift` holds `DashboardSnapshot` exactly as in Interfaces, plus the wire types:

```swift
struct AnalyticsQueryResponse: Decodable {
    let rows: [[String: AnalyticsValue]]
    let previousRows: [[String: AnalyticsValue]]?
}
enum AnalyticsValue: Decodable, Equatable {
    case int(Int), string(String)
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) { self = .int(i) } else { self = .string(try c.decode(String.self)) }
    }
    var int: Int? { if case .int(let i) = self { return i }; return nil }
    var string: String? { if case .string(let s) = self { return s }; return nil }
}
struct PreferenceResponse: Decodable { let key: String; let value: String; let isDefault: Bool? }
```

- [ ] **Step 4: Implement `DashboardActions`**

```swift
import Foundation

/// SPEC D8, D20–D22, D24–D27: Home's Overview + Activity data.
struct DashboardActions {
    private let api: APIClientProtocol
    private let stateOverride: AppState?
    private let now: () -> Date
    private let timeZone: TimeZone
    private let onUnauthorized: @MainActor () async -> Void
    @MainActor private var state: AppState { stateOverride ?? AppState.shared }

    init(api: APIClientProtocol = APIClient.shared, state: AppState? = nil,
         now: @escaping () -> Date = Date.init, timeZone: TimeZone = .current,
         onUnauthorized: @escaping @MainActor () async -> Void = {}) {
        self.api = api; self.stateOverride = state; self.now = now
        self.timeZone = timeZone; self.onUnauthorized = onUnauthorized
    }

    @MainActor
    func refresh() async {
        do {
            var next = state.dashboard
            next.kpiNames = try await kpiNames()
            let today = day(now())
            let from24 = day(offset: -23), from28 = day(offset: -28)

            let series = try await query(["lesson_completions"], dimension: "day", from: from24, to: today, compare: true)
            next.completedSeries = byDay(series.rows, metric: "lesson_completions")
            next.completedTotal = next.completedSeries.values.reduce(0, +)
            next.completedPrevious = series.previousRows?.compactMap { $0["lesson_completions"]?.int }.reduce(0, +)

            let activity = try await query(["lesson_completions"], dimension: "day", from: from28, to: today, compare: false)
            next.activityDays = byDay(activity.rows, metric: "lesson_completions")

            if next.kpiNames.contains("watch_seconds") {
                let watch = try await query(["watch_seconds"], dimension: nil, from: nil, to: nil, compare: false)
                next.watchSeconds = watch.rows.first?["watch_seconds"]?.int
            }
            next.refreshedAt = now()
            state.dashboard = next
            state.persist()
        } catch {
            if AuthStatusPolicy.shouldSignOut(after: error) { await onUnauthorized(); return }
            state.recordError(error, context: "DashboardActions.refresh", surface: false)   // D28: logged, cache kept
        }
    }

    // MARK: - Helpers

    @MainActor
    private func kpiNames() async throws -> [String] {
        let pref = try await api.get("/api/preferences/dashboard.kpis", responseType: PreferenceResponse.self)
        guard pref.isDefault != true,
              let data = pref.value.data(using: .utf8),
              let names = try? JSONDecoder().decode([String].self, from: data), !names.isEmpty
        else { return ["lesson_completions", "watch_seconds"] }   // D25 default
        return names.filter { ["lesson_completions", "watch_seconds"].contains($0) }
    }

    @MainActor
    private func query(_ metrics: [String], dimension: String?, from: String?, to: String?, compare: Bool) async throws -> AnalyticsQueryResponse {
        var filters: [String: Any] = [:]
        if let org = state.organizationId { filters["organizationId"] = org }   // D26
        if let from { filters["from"] = from }
        if let to { filters["to"] = to }
        var body: [String: Any] = ["metrics": metrics, "timezone": timeZone.identifier, "filters": filters]
        if let dimension { body["dimensions"] = [dimension] }
        if compare { body["compareToPrevious"] = true }
        return try await api.post("/api/analytics/query", body: body, responseType: AnalyticsQueryResponse.self)
    }

    private func byDay(_ rows: [[String: AnalyticsValue]], metric: String) -> [String: Int] {
        Dictionary(rows.compactMap { r in r["day"]?.string.flatMap { d in r[metric]?.int.map { (d, $0) } } },
                   uniquingKeysWith: { $1 })
    }

    private func day(_ date: Date) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = timeZone; f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func day(offset: Int) -> String {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = timeZone
        return day(cal.date(byAdding: .day, value: offset, to: now()) ?? now())
    }
}
```

Check `state.recordError`'s real signature in `AppState.swift` and match it. Add `var dashboard = DashboardSnapshot()` to `AppState`, reset it in `clearAllData()` and `reloadForEnvironmentSwitch()`, and persist it: `PersistedState` gains `var dashboard: DashboardSnapshot`, a `dashboard` `CodingKeys` case, `self.dashboard = try container.decodeIfPresent(DashboardSnapshot.self, forKey: .dashboard) ?? DashboardSnapshot()`, and the from-AppState init + restore lines next to `organizationId`'s.

- [ ] **Step 5: Run them and watch them pass** — `npm run ios:build-check -- --test` → PASS.

- [ ] **Step 6: Stage** — `feat(ui2-shell): DashboardActions loads Home analytics into AppState`; STOP.

### Task 12: Home mapper — snapshot → HomeDashboardScreen.State
App: iphone
Phase: 5
Recipe: SPEC D8, D9, D21, D22, D25 · ⛔ read the rebuilt `HomeDashboardScreen.State` first (SPEC F3); if it still has `onSelectTab`/`onToggleNav` or draws `TopNav`, STOP and report
Build-time risk: F3 — field names below are the 2026-10-25 build's; adapt to the rebuilt State, keeping the same values. F4 — no loading/error inputs: first load renders the empty values

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Home/HomeDashboardMapper.swift`
- Test: `iphone/MakeReadyCaptureTests/HomeDashboardMapperTests.swift`

**Interfaces:**
- Consumes: Task 11's `DashboardSnapshot`; `HomeDashboardScreen.State` and its `.empty` preset.
- Produces: `enum HomeDashboardMapper { static func state(from s: DashboardSnapshot, today: Date, timeZone: TimeZone, sessionRange: String) -> HomeDashboardScreen.State }`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import MakeReady

final class HomeDashboardMapperTests: XCTestCase {
    private let tz = TimeZone(identifier: "America/Denver")!
    private let today = ISO8601DateFormatter().date(from: "2026-10-25T18:00:00Z")!

    private func snapshot() -> DashboardSnapshot {
        var s = DashboardSnapshot()
        s.completedSeries = ["2026-10-24": 3, "2026-10-25": 2]
        s.completedTotal = 5; s.completedPrevious = 4
        s.watchSeconds = 49_680
        s.activityDays = ["2026-10-24": 3, "2026-10-25": 2]
        return s
    }

    func testTwoKpisInOrder() {
        let st = HomeDashboardMapper.state(from: snapshot(), today: today, timeZone: tz, sessionRange: "All time")
        XCTAssertEqual(st.kpiTitles, ["Completed lessons", "Total video time"])     // D25
        XCTAssertEqual(st.metricCount, "2")
        XCTAssertEqual(st.kpiValues, ["5", "13.8hrs"])
        XCTAssertEqual(st.kpiSeries[0].count, 24)
        XCTAssertEqual(st.kpiSeries[1], [])
        XCTAssertEqual(st.kpiTrendDirections, ["up", "neutral"])
        XCTAssertEqual(st.kpiTrendLabels[0], "25%")
        XCTAssertEqual(st.kpiTrendLabels[1], "")
    }

    func testActivityWindowAndZeros() {
        let st = HomeDashboardMapper.state(from: snapshot(), today: today, timeZone: tz, sessionRange: "All time")
        XCTAssertEqual(st.chartDates.count, 36)                                       // 28 + today + 7
        XCTAssertEqual(st.chartToday, "2026-10-25")
        XCTAssertEqual(st.chartScheduled, Array(repeating: 0, count: 36))             // D25
        XCTAssertEqual(st.chartCompleted[st.chartDates.firstIndex(of: "2026-10-24")!], 3)
        XCTAssertTrue(st.dayLine1s.allSatisfy { $0 == "0 mins" })
    }

    func testEmptySectionsStayEmpty() {
        let st = HomeDashboardMapper.state(from: snapshot(), today: today, timeZone: tz, sessionRange: "Week")
        XCTAssertEqual(st.followedCount, "0"); XCTAssertEqual(st.programTitles, [])
        XCTAssertEqual(st.engagementCount, 0); XCTAssertEqual(st.centerValue, "0")
        XCTAssertEqual(st.sessionRange, "Week")
    }
}
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL: `HomeDashboardMapper` undefined.

- [ ] **Step 3: Implement**

```swift
import Foundation

/// SPEC D8/D25: Overview + Activity from the snapshot; Sessions, Engagement,
/// Following keep `.empty`'s values.
enum HomeDashboardMapper {
    static func state(from s: DashboardSnapshot, today: Date, timeZone: TimeZone, sessionRange: String) -> HomeDashboardScreen.State {
        var st = HomeDashboardScreen.State.empty
        st.sessionRange = sessionRange

        // Overview (D21/D25)
        let last24 = days(endingAt: today, back: 23, ahead: 0, tz: timeZone)
        let completedSeries = last24.map { Double(s.completedSeries[$0] ?? 0) }
        var titles = ["Completed lessons"], values = ["\(s.completedTotal)"]
        var series = [completedSeries], averages = [average(completedSeries)]
        var (dir, pol, label) = trend(current: s.completedTotal, previous: s.completedPrevious)
        var dirs = [dir], pols = [pol], labels = [label]
        if s.kpiNames.contains("watch_seconds") {
            titles.append("Total video time"); values.append(hours(s.watchSeconds ?? 0))
            series.append([]); averages.append("")
            dirs.append("neutral"); pols.append("neutral"); labels.append("")
        }
        st.kpiTitles = titles; st.kpiValues = values; st.kpiSeries = series; st.kpiAverageLabels = averages
        st.kpiTrendDirections = dirs; st.kpiTrendPolarities = pols; st.kpiTrendLabels = labels
        st.metricCount = "\(titles.count)"

        // Activity (D22/D25)
        let window = days(endingAt: today, back: 28, ahead: 7, tz: timeZone)
        let todayKey = key(today, tz: timeZone)
        st.chartDates = window
        st.chartCompleted = window.map { s.activityDays[$0] ?? 0 }
        st.chartScheduled = Array(repeating: 0, count: window.count)
        st.chartToday = todayKey
        st.chartWindowStart = window[max(0, window.firstIndex(of: todayKey)! - 14)]
        st.chartWindowEnd = window[min(window.count - 1, window.firstIndex(of: todayKey)! + 14)]
        st.dayDates = window
        st.dayMonths = window.map { label($0, "MMM", tz: timeZone).uppercased() }
        st.dayWeekdays = window.map { $0 == todayKey ? "" : label($0, "EEE", tz: timeZone).uppercased() }
        st.dayNumbers = window.map { label($0, "d", tz: timeZone) }
        st.dayDateStates = window.map { $0 == todayKey ? "today" : "default" }
        st.daySeries = window.map { _ in Array(repeating: 0, count: 12) }
        st.dayLine1s = window.map { _ in "0 mins" }
        st.dayLine2s = window.map { "\(s.activityDays[$0] ?? 0) lessons" }
        st.dayDetailsStates = window.map { (s.activityDays[$0] ?? 0) > 0 ? "default" : "nothing" }
        return st
    }

    // MARK: - Helpers
    static func trend(current: Int, previous: Int?) -> (String, String, String) {
        guard let previous, previous > 0 else { return ("neutral", "neutral", "") }
        let pct = Int((Double(current - previous) / Double(previous) * 100).rounded())
        if pct > 0 { return ("up", "positive", "\(pct)%") }
        if pct < 0 { return ("down", "negative", "\(-pct)%") }
        return ("neutral", "neutral", "0%")
    }
    static func hours(_ seconds: Int) -> String { String(format: "%.1fhrs", Double(seconds) / 3600) }
    static func average(_ v: [Double]) -> String {
        guard !v.isEmpty, v.contains(where: { $0 > 0 }) else { return "" }
        return "\(Int((v.reduce(0, +) / Double(v.count)).rounded()))"
    }
    static func days(endingAt today: Date, back: Int, ahead: Int, tz: TimeZone) -> [String] {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        return (-back...ahead).compactMap { cal.date(byAdding: .day, value: $0, to: today) }.map { key($0, tz: tz) }
    }
    static func key(_ d: Date, tz: TimeZone) -> String { format(d, "yyyy-MM-dd", tz) }
    static func label(_ key: String, _ pattern: String, tz: TimeZone) -> String {
        let p = DateFormatter(); p.timeZone = tz; p.locale = Locale(identifier: "en_US_POSIX"); p.dateFormat = "yyyy-MM-dd"
        return p.date(from: key).map { format($0, pattern, tz) } ?? ""
    }
    private static func format(_ d: Date, _ pattern: String, _ tz: TimeZone) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.timeZone = tz
        f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = pattern
        return f.string(from: d)
    }
}
```

`State`'s properties are `var` (they are in the 2026-10-25 build); if the rebuild made them `let`, construct a new `State` with every field instead of mutating `.empty`. Note `testActivityWindowAndZeros` expects 36 dates (28 back + today + 7 ahead) — keep `back: 28, ahead: 7`.

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS.

- [ ] **Step 5: Stage** — `feat(ui2-shell): Home dashboard mapper`; STOP.

### Task 13: HomeDashboardContainer in the shell
App: iphone
Phase: 5
Recipe: SPEC D9, D13, D20, D27

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Home/HomeDashboardContainer.swift`
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift` (`sectionContent` `.home` → `HomeDashboardContainer()`)
- Test: `iphone/MakeReadyCaptureTests/HomeDashboardContainerTests.swift`

**Interfaces:**
- Consumes: `DashboardActions(…).refresh()`, `HomeDashboardMapper.state(from:today:timeZone:sessionRange:)`, `AppState.shared.dashboard`, `AuthManager.signOut()`, `HomeDashboardScreen(state:onPickMetrics:onJumpToToday:onSelectSessionRange:onOpenEngagement:onFollowEnrollment:onProgramMenu:onOpenGroup:)` as rebuilt.
- Produces: `struct HomeDashboardContainer: View`; `HomeDashboardContainer.sessionRanges = ["All time", "Year", "Month", "Week"]`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import MakeReady

final class HomeDashboardContainerTests: XCTestCase {
    func testSessionRangesAreTheClosedList() {
        XCTAssertEqual(HomeDashboardContainer.sessionRanges, ["All time", "Year", "Month", "Week"])
    }
}
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL.

- [ ] **Step 3: Implement**

```swift
import SwiftUI

/// SPEC D8/D9: Home section content. Cache-first (D39): renders the snapshot
/// at once and refreshes in .task.
struct HomeDashboardContainer: View {
    static let sessionRanges = ["All time", "Year", "Month", "Week"]

    @Environment(AuthManager.self) private var authManager
    @State private var sessionRange = "All time"
    @State private var jumpToken = 0

    var body: some View {
        HomeDashboardScreen(
            state: HomeDashboardMapper.state(from: AppState.shared.dashboard, today: Date(),
                                             timeZone: .current, sessionRange: sessionRange),
            onPickMetrics: {},                         // D9 no-op
            onJumpToToday: { jumpToken += 1 },         // the screen recentres on today
            onSelectSessionRange: { sessionRange = $0 },
            onOpenEngagement: {}, onFollowEnrollment: {},
            onProgramMenu: { _ in }, onOpenGroup: { _ in }
        )
        .id(jumpToken)
        .task {
            await DashboardActions(onUnauthorized: { try? await authManager.signOut() }).refresh()
        }
    }
}
```

Match the rebuilt screen's exact initializer labels; if it exposes its own "jump to today" mechanism, use it instead of `.id(jumpToken)`. In `UI2Shell.sectionContent`, `case .home: HomeDashboardContainer()`.

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS. Then (ask the human before launching the simulator) sign in on Local → Home shows real Completed lessons and video time; Jump to today recentres; Sessions/Engagement/Following empty; the no-op buttons do nothing.

- [ ] **Step 5: Stage** — `feat(ui2-shell): Home dashboard wired to AppState`; STOP.

### Task 14: EnvironmentActions — switch and health
App: iphone
Phase: 6
Recipe: `/ios-error-surface` · SPEC D16

**Files:**
- Create: `iphone/MakeReady/State/Actions/EnvironmentActions.swift`
- Test: `iphone/MakeReadyCaptureTests/EnvironmentActionsTests.swift`

**Interfaces:**
- Consumes: `AppConfiguration.SelectedEnvironment` (`local, staging, production`), `AppConfiguration.selectedEnvironment`, `AppConfiguration.baseURL`, `LocalPortHealer.heal()` → outcome `.healthy/.healed/.notFound/.skipped`, `AuthManager.signInToReachableLocal()`, `.checkAuthStatus()`, `.isAuthenticated`, `AppState.persistImmediately()`, `.reloadForEnvironmentSwitch()`, `.loadInitialData()`, `AuthError.localServerUnreachable(host:port:)`.
- Produces: `enum EnvironmentHealth: Equatable { case checking, reachable, unreachable; var label: String }`; `struct EnvironmentActions { static func healthURL(for: AppConfiguration.SelectedEnvironment) -> URL?; func health(of:) async -> EnvironmentHealth; @MainActor func switchTo(_:auth:) async throws }`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import MakeReady

final class EnvironmentActionsTests: XCTestCase {
    func testLabels() {
        XCTAssertEqual(EnvironmentHealth.checking.label, "Checking…")
        XCTAssertEqual(EnvironmentHealth.reachable.label, "Reachable")
        XCTAssertEqual(EnvironmentHealth.unreachable.label, "Unreachable")
    }
    func testHealthURLs() {
        XCTAssertEqual(EnvironmentActions.healthURL(for: .staging)?.absoluteString, "https://staging.api.makeready.org/health")
        XCTAssertEqual(EnvironmentActions.healthURL(for: .production)?.absoluteString, "https://api.makeready.org/health")
    }
}
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL.

- [ ] **Step 3: Implement** — port `Pages/Profile/ProfilePage.swift:168-205, 358-424, 476-515` (read them on disk; the file is out of the target but present):

```swift
import Foundation

enum EnvironmentHealth: Equatable {
    case checking, reachable, unreachable
    var label: String {
        switch self { case .checking: "Checking…"; case .reachable: "Reachable"; case .unreachable: "Unreachable" }
    }
}

/// SPEC D16: legacy ProfilePage's environment switch, moved out of the view.
struct EnvironmentActions {
    static func healthURL(for env: AppConfiguration.SelectedEnvironment) -> URL? {
        switch env {
        case .local:
            if AppConfiguration.baseURL.contains("api.makeready.org") { return nil }   // no local URL resolved
            return URL(string: "\(AppConfiguration.baseURL)/health")
        case .staging: return URL(string: "https://staging.api.makeready.org/health")
        case .production: return URL(string: "https://api.makeready.org/health")
        }
    }

    /// The health probe is a sanctioned direct URLSession call, as in legacy.
    func health(of env: AppConfiguration.SelectedEnvironment) async -> EnvironmentHealth {
        guard let url = Self.healthURL(for: env) else { return .unreachable }
        var request = URLRequest(url: url); request.timeoutInterval = 5
        let status = (try? await URLSession.shared.data(for: request))?.1 as? HTTPURLResponse
        return status?.statusCode == 200 ? .reachable : .unreachable
    }

    @MainActor
    func switchTo(_ env: AppConfiguration.SelectedEnvironment, auth: AuthManager) async throws {
        let previous = AppConfiguration.selectedEnvironment
        guard previous != env else { return }
        AppState.shared.persistImmediately()
        AppConfiguration.selectedEnvironment = env
        AppState.shared.reloadForEnvironmentSwitch()
        if env == .local {
            let outcome = await LocalPortHealer.heal()
            let reachable: Bool
            switch outcome { case .healthy, .healed: reachable = true; case .notFound, .skipped: reachable = false }
            if reachable, await auth.signInToReachableLocal() {
                if auth.isAuthenticated { await AppState.shared.loadInitialData() }
                return
            }
            AppState.shared.persistImmediately()
            AppConfiguration.selectedEnvironment = previous
            AppState.shared.reloadForEnvironmentSwitch()
            await auth.checkAuthStatus()
            if auth.isAuthenticated { await AppState.shared.loadInitialData() }
            let host = AppConfiguration.localServerIP ?? AppConfiguration.defaultLocalIP
            throw AuthError.localServerUnreachable(host: host, port: AppConfiguration.localAPIPort)
        }
        await auth.checkAuthStatus()
        if auth.isAuthenticated { await AppState.shared.loadInitialData() }
    }
}
```

Match `LocalPortHealer.heal()`'s real outcome type and `Configuration`'s real property names as they are in the code.

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS.

- [ ] **Step 5: Stage** — `feat(ui2-shell): EnvironmentActions for the dev switcher`; STOP.

### Task 15: Profile stopgap — Sign out + DEV environment switcher
App: iphone
Phase: 6
Recipe: `/ios-error-surface` · SPEC D15, D16, D28

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Profile/ProfileStopgapContainer.swift`
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift` (`case .profile:` → `ProfileStopgapContainer()`)
- Test: `iphone/MakeReadyCaptureTests/ProfileStopgapTests.swift`

**Interfaces:**
- Consumes: `PageActionButton(label:role:…:onTap:)` with `role: .secondary`; `RadioOptionRow(title:description:selected:…:onSelect:)`; `EnvironmentActions`, `EnvironmentHealth` (Task 14); `AuthManager.signOut()`; `AppConfiguration.devMode`.
- Produces: `struct ProfileStopgapContainer: View`; `ProfileStopgapContainer.showsEnvironmentSwitcher(devMode:) -> Bool`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import MakeReady

final class ProfileStopgapTests: XCTestCase {
    func testSwitcherOnlyInDevMode() {
        XCTAssertTrue(ProfileStopgapContainer.showsEnvironmentSwitcher(devMode: true))
        XCTAssertFalse(ProfileStopgapContainer.showsEnvironmentSwitcher(devMode: false))
    }
}
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL.

- [ ] **Step 3: Implement** — read `PageActionButton.swift` and `RadioOptionRow.swift` for their exact initializer labels and defaults first.

```swift
import SwiftUI

/// SPEC D15/D16: a stopgap until profile-home is designed.
struct ProfileStopgapContainer: View {
    static func showsEnvironmentSwitcher(devMode: Bool) -> Bool { devMode }

    @Environment(AuthManager.self) private var authManager
    @State private var current = AppConfiguration.selectedEnvironment
    @State private var health: [AppConfiguration.SelectedEnvironment: EnvironmentHealth] = [:]
    @State private var switchError = ""

    var body: some View {
        VStack(spacing: Token.Space.sectionGap) {
            Spacer()
            PageActionButton(label: "Sign out", role: .secondary, onTap: signOut)
            if Self.showsEnvironmentSwitcher(devMode: AppConfiguration.devMode) {
                VStack(spacing: 0) {
                    ForEach(AppConfiguration.SelectedEnvironment.allCases, id: \.self) { env in
                        RadioOptionRow(
                            title: env.rawValue.capitalized,
                            description: (health[env] ?? .checking).label,
                            selected: env == current,
                            onSelect: { select(env) }
                        )
                    }
                }
                if !switchError.isEmpty {
                    Text(switchError).font(Token.Type.body).foregroundStyle(Token.negative)
                }
            }
            Spacer()
        }
        .padding(Token.Space.pageMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Token.layoutBackground)
        .task { await refreshHealth() }
    }

    private func signOut() { Task { try? await authManager.signOut() } }

    private func select(_ env: AppConfiguration.SelectedEnvironment) {
        switchError = ""
        Task { @MainActor in
            do { try await EnvironmentActions().switchTo(env, auth: authManager) }
            catch { switchError = error.localizedDescription; AppState.shared.recordError(error, context: "ProfileStopgap.switch", surface: false) }
            current = AppConfiguration.selectedEnvironment
            await refreshHealth()
        }
    }

    private func refreshHealth() async {
        for env in AppConfiguration.SelectedEnvironment.allCases {
            health[env] = .checking
            health[env] = await EnvironmentActions().health(of: env)
        }
    }
}
```

Replace `Token.Type.body` with the real typography token name from `Token.swift`, the `rawValue.capitalized` with a display name if the enum provides one, and match `recordError`'s signature. In `UI2Shell.content`, `case .profile: ProfileStopgapContainer()`.

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS; `cd iphone && swiftlint` clean. Then (ask the human before launching) Profile → Sign out → Login; in a Debug build, switch Local ⇄ Production and see the health labels update.

- [ ] **Step 5: Stage** — `feat(ui2-shell): Profile stopgap with sign out and dev environment switcher`; STOP.
