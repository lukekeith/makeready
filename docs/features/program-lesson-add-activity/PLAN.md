# program-lesson-add-activity — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** On the iPhone 2.0 program page every lesson rail ends in a "+" card that opens the activity-new picker, and each lesson's chevron opens a bottom menu that opens the same picker or deletes the lesson.

**Architecture:** No server route, service or schema changes: the server gains one fixture layer so every walk step has data. d2m delivers the C-063, `StudyProgramHomeScreen` and `ActivityNewScreen` inputs, then the app wires them from `iphone/MakeReady/UI2`: a new `UI2Destination.activityNew` and `ActivityNewContainer`, a lesson menu and delete flow in `StudyProgramHomeContainer`, and `ProgramActions.deleteLesson` with its success boundary moved. 🔴 Implementers have no d2m tools, so **the coordinator runs Task 2's d2m request and waits for it before dispatching Task 2**.

**Tech Stack:** server — fixture layers (TypeScript, Prisma), vitest · iphone — SwiftUI, `@Observable` AppState + Actions, XCTest, d2m-built `MakeReadyUI` views.

**Spec:** `docs/features/program-lesson-add-activity/SPEC.md`

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. Builder agents commit under the owner-approved `apps.iphone.commit: auto` policy; other iPhone commit flows retain their human approval requirements.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(program-lesson-add-activity): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal |
|---|---|---|---|
| 1 | server | 1 | The `activity-new` fixture layer gives the walk an empty lesson and a one-lesson program; the existing delete contract is recorded as frozen at this phase's close |
| 2 | iphone | 2–6 | Coordinator first runs Task 2's d2m request. Then the "+" card and chevron work on the program page: the picker opens, and a lesson can be deleted |

---

### Task 1: The activity-new fixture layer
App: server
Phase: 1
Recipe: `server/fixtures/README.md` §A new screen layer

**Files:**
- Create: `server/fixtures/screens/activity-new.ts` — the D18 layer, `full` scenario only
- Modify: `server/fixtures/README.md` — a "What `full` makes non-empty on the activity picker" entry beside the other screens' entries
- Test: `server/fixtures/__tests__/activity-new.test.ts` — fixed ids and the D18 counts, with a fake context in the `study-programs.test.ts` form (no database)

**Interfaces:**
- Consumes: `lessonId` and `activityId` from `server/fixtures/base.ts` (each takes a program index and day, and `activityId` also an order; returns a fixed id), `fixtureId`, `FIXTURE_ORG_ID` and `FIXTURE_USER_ID` from `server/fixtures/ids.ts`.
- Produces: `LESSON_RAIL_PROGRAM_ID` = `fixtureId('program', 200)`, `SINGLE_LESSON_PROGRAM_ID` = `fixtureId('program', 201)`, and `full`, which takes the fixture context and returns nothing. No API contract changes.

**Behaviour:**
- Program "Lesson Rail Samples", `days: 3`: lessons 1, 2 and 3 have 2, 1 and 0 activities and `estimatedMinutes` 3, 5 and null (D18)
- Program "Single Lesson Study", `days: 1`: one lesson with 0 activities (D18)
- Both programs are in `FIXTURE_ORG_ID` with `creatorId` and `leaderId` = `FIXTURE_USER_ID`; `createdAt` comes from `ctx.daysAgo` (D18, §fixtures house rule)
- Lesson ids are `lessonId(200, day)` and `lessonId(201, 1)`. Activity ids are `activityId(200, day, order)`. All are clear of base (program indexes 1–2), `search-home` (lesson 7000) and `groups-enroll-program` (lesson 900,000+) (D18)
- The layer runs first among the screens, so it reads only base and depends on no other layer (§server)
- Activities are one READ (with `readContent`) and one USER_INPUT (with `placeholder`), in the shape at `server/fixtures/base.ts:274-300` (D18)
- ⚠ build-time risk F7: the new programs may disturb fixture tests that count org programs (`server/fixtures/counts.ts:44`). The phase gate settles it. Update a count only where it is a total of fixture-org programs, never by removing a program from this layer

**Pattern:**
- `server/fixtures/screens/study-program-home.ts:40-69` — `createMany` of programs in `full(ctx)` with exported ids
- `server/fixtures/__tests__/study-programs.test.ts:12-20` — the fake context

**Tests:**
- `uses fixed program ids clear of the other layers` — D18's two ids

```ts
it('uses fixed program ids clear of the other layers', () => {
  expect(LESSON_RAIL_PROGRAM_ID).toBe(fixtureId('program', 200))
  expect(SINGLE_LESSON_PROGRAM_ID).toBe(fixtureId('program', 201))
})
```

- `creates both programs in the fixture org with the D18 day counts` — names, days, org and creator

```ts
it('creates both programs in the fixture org with the D18 day counts', async () => {
  const { prisma, ctx } = fakeCtx()
  await full(ctx)
  const rows = prisma.studyProgram.createMany.mock.calls[0][0].data
  expect(rows).toEqual([
    expect.objectContaining({ id: LESSON_RAIL_PROGRAM_ID, name: 'Lesson Rail Samples', days: 3, organizationId: FIXTURE_ORG_ID, creatorId: FIXTURE_USER_ID }),
    expect.objectContaining({ id: SINGLE_LESSON_PROGRAM_ID, name: 'Single Lesson Study', days: 1, organizationId: FIXTURE_ORG_ID, creatorId: FIXTURE_USER_ID }),
  ])
})
```

- `gives the lessons the D18 minutes` — 3, 5, null, and the single lesson

```ts
it('gives the lessons the D18 minutes', async () => {
  const { prisma, ctx } = fakeCtx()
  await full(ctx)
  const rows = prisma.lesson.createMany.mock.calls[0][0].data
  expect(rows.map((l: { id: string; estimatedMinutes: number | null }) => [l.id, l.estimatedMinutes ?? null])).toEqual([
    [lessonId(200, 1), 3],
    [lessonId(200, 2), 5],
    [lessonId(200, 3), null],
    [lessonId(201, 1), null],
  ])
})
```

- `gives lessons 2, 1 and 0 activities, and the single lesson none` — the rail's three shapes

```ts
it('gives lessons 2, 1 and 0 activities, and the single lesson none', async () => {
  const { prisma, ctx } = fakeCtx()
  await full(ctx)
  const rows = prisma.lessonActivity.createMany.mock.calls[0][0].data
  const count = (id: string) => rows.filter((a: { lessonId: string }) => a.lessonId === id).length
  expect([count(lessonId(200, 1)), count(lessonId(200, 2)), count(lessonId(200, 3)), count(lessonId(201, 1))]).toEqual([2, 1, 0, 0])
  expect(new Set(rows.map((a: { id: string }) => a.id)).size).toBe(rows.length)
})
```

- [ ] **Step 1: Write the listed tests** — in `server/fixtures/__tests__/activity-new.test.ts`, with a `fakeCtx()` whose `prisma` has `vi.fn()` `studyProgram.createMany`, `lesson.createMany` and `lessonActivity.createMany`, and a `daysAgo`
- [ ] **Step 2: Run `cd server && npx vitest run fixtures/__tests__/activity-new.test.ts`, watch them fail** — module not found
- [ ] **Step 3: Implement `full` and the two exported ids in `server/fixtures/screens/activity-new.ts` to the Behaviour, and add the README entry**
- [ ] **Step 4: Run the same vitest command and `cd server && npx --no-install tsc --noEmit -p fixtures`, then `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree` and `verify.mjs wait <id>`** (database fixture tests run only in its lease; `<builder>` is the directory your brief names) — PASS
- [ ] **Step 5: Commit** — `feat(program-lesson-add-activity): activity-new fixture layer with an empty lesson and a one-lesson program`
- [ ] **Step 6: At this phase's close (coordinator, not the implementer), record the freeze** — `advance.mjs <folder> --set "contract=frozen <YYYY-MM-DD>"` with the phase's ledger line, per build §phase close. The one contract row, `DELETE /api/programs/:programId/lessons/:lessonId`, is existing and unchanged

### Task 2: Check d2m's delivery of the card, chevron and picker fit
App: iphone
Phase: 2
Recipe: d2m-channel (`check_project_change` → `request_project_change` → `wait_project_change`)

🔴 **Coordinator, before dispatching this task:** implementers have no d2m tools. Call `check_project_change` (subject `C-063`, kinds `["composition", "new-state"]`, summary: "add card and chevron button on the program page"). It returned lane `handover` on 2026-11-06. Then call `request_project_change` with subject `C-063`, `branch` = the current branch, `references: [{ path: "docs/features/program-lesson-add-activity/SPEC.md", subjects: ["C-063", "study-program-home", "activity-new"] }]`, the `intent` and `why` below, then `wait_project_change` until done. Settle any handback as the d2m-channel instructions say: `answer_project_change`, `approve_project_change` or `retry_project_change`, and call it again on `timedOut`. Check the d2m commits landed on this branch, and pass the `changeId` and the delivered signatures into the brief's context. If d2m takes one subject per request, send one request each for C-063, `study-program-home` and `activity-new`, in that order, each with its part of the intent. ⚠ build-time risk F2: `study-program-home` has a stale d2m stop (catch-up `cmvujmxxj009dv073n1zxlbbd`, no contract change, one manual owner step). If it blocks the request, or `next` starts `cannot be done:`, park for the owner to close it.

`why`: "The program page needs a way to reach activity creation and lesson delete; SPEC D1, D2, D4, D7, D12, D13."

`intent`:

```text
Figma: Lessons section 4789:45890, add card 4494:40744. Rulings are in the referenced SPEC (D1, D7, D11, D12, D13, D16, F5, F9, F10).

C-063 LessonCard:
1. A defaulted optional add-card input. When supplied, the rail draws one add card after the last slide: 112 wide, add icon 24 centred, VoiceOver label "Add activity to lesson {n}". Take the slide's height so the rail does not change height (F10: 244 in Figma against 243.35 from C-079's aspect).
2. With the add input, `empty` draws the rail with the add card alone. This departs from ruled OQ-C-063-005 for this host only; record that in the contract. Without the input, `empty` keeps today's look.
3. A defaulted optional chevron-button input, drawn in the title row. VoiceOver label "Lesson {n} actions". The chevron is a sibling of the title-block button, never inside it, because that button ignores its children for accessibility.
4. Two-tone meta where the host opts in: number color-text-primary, unit color-text-secondary. Hosts that don't opt in keep one tone.
enrollment-home and groups-detail supply none of these inputs, and their previews must not change.

study-program-home (StudyProgramHomeScreen):
Add `onAddActivity: (Int) -> Void` and `onOpenLessonMenu: (Int) -> Void`, both lesson indexes into the state's lesson arrays, both defaulted to no-ops. Pass them to every C-063 with the add card, chevron and two-tone meta on. The section header's "31 days" and "+" stay as built. Lesson metaLabel strings arrive as "N mins", "1 min" or "0 mins".

activity-new (ActivityNewScreen):
1. Replace the content region's `minHeight: 775` with a flexible region. The grid scrolls only when it doesn't fit (activity-new §2 already says this); header and C-081 stay fixed. The four frozen captures must stay unchanged.
2. Record in §3 and §6: tiles do nothing yet (D3); the strip's slide taps and add do nothing, and back pops (D10); the confirmed entry from study-program-home's add card and lesson menu. Remove the header comment "PREVIEW ONLY".

Capture C-063's new states, and confirm the unchanged previews of enrollment-home and groups-detail.
```

**Files:**
- d2m-made (handover, never hand-edited): `iphone/MakeReadyUI/LessonCard.swift`, `iphone/MakeReadyUI/Screens/Programs/StudyProgramHomeScreen.swift`, `iphone/MakeReadyUI/Screens/Activities/ActivityNewScreen.swift`, and their capture cases
- Test: `iphone/MakeReadyCaptureTests/StudyProgramHomeContainerTests.swift` — the delivered inputs exist, and the picker fits a phone. An existing test file, because a new one would have to be added to `project.pbxproj`

**Interfaces:**
- Consumes: d2m's delivered views.
- Produces: `StudyProgramHomeScreen` with `onAddActivity` and `onOpenLessonMenu`, each taking a lesson index and returning nothing; `ActivityNewScreen` that fits the safe area.

**Behaviour:**
- d2m's changes are its own: this task never edits a file under `iphone/MakeReadyUI/`. A missing or differently named input is reported as BLOCKED, naming it (D12)
- The picker no longer overflows a phone, because its content region is flexible (D13, F5)
- ⚠ build-time risk F5: d2m's fit fix must keep the four frozen captures. Read d2m's wait result and put its capture outcome in the report
- ⚠ build-time risk F10: the add card takes the slide's height. Read `LessonCard.swift` and name the height used in the report

**Tests:**
- `testProgramPageTakesBothLessonClosures` — the delivered closures compile and are the names Task 6 calls (D12)

```swift
func testProgramPageTakesBothLessonClosures() {
    let state = StudyProgramHomeMapper.state(.init(name: "", program: nil, lessons: [], enrollments: [], failed: false, activeDay: 1),
                                             timeZone: .current)
    _ = StudyProgramHomeScreen(state: state, onAddActivity: { _ in }, onOpenLessonMenu: { _ in })
}
```

- `testActivityNewFitsAPhone` — the 775pt minimum is gone, so the screen fits a proposed 700pt (D13, F5)

```swift
func testActivityNewFitsAPhone() {
    let host = UIHostingController(rootView: ActivityNewScreen(state: .populated))
    XCTAssertLessThanOrEqual(host.sizeThatFits(in: CGSize(width: 390, height: 700)).height, 700)
}
```

- [ ] **Step 1: Confirm the delivery** — d2m's commits are in `git log`, and the Interfaces names are in the three view files. If not, report BLOCKED and stop
- [ ] **Step 2: Write the listed tests** — d2m wrote the code before this task, so there is no red run here. A failure means the delivery falls short: report it as BLOCKED, and never edit `MakeReadyUI`
- [ ] **Step 3: Run `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`** (`<builder>` is the directory your brief names) — PASS
- [ ] **Step 4: Commit** — `test(program-lesson-add-activity): pin d2m's lesson closures and the picker's fit`

### Task 3: deleteLesson succeeds when the delete does
App: iphone
Phase: 2
Recipe: ios-error-surface · tiny

**Files:**
- Modify: `iphone/MakeReady/State/Actions/ProgramActions+Lessons.swift:36-55` — drop the `getProgram` refresh at `:54`, add `state.persist()`
- Test: `iphone/MakeReadyCaptureTests/ProgramActionsTests.swift` — success and failure

**Interfaces:**
- Consumes: `DELETE /api/programs/:programId/lessons/:lessonId` (SPEC §Contract, frozen): no body, `{ success: true }`.
- Produces: `deleteLesson` — same signature, takes `programId` and `lessonId`, returns nothing, and throws only when the DELETE failed.

**Behaviour:**
- Success means the DELETE returned `{ success: true }`. The action then removes the lesson and its activities from the stores and returns, sending no follow-up request (D15)
- It calls `state.persist()` after the store updates, as `addLesson` does at `:78`. This has no unit seam, so the reviewer checks it (D15)
- A failed DELETE throws and leaves the stores unchanged (D15)
- The other callers are in the legacy `Pages/` tree, outside the app target. Leave them alone (§Apps)

**Tests:**
- `testDeleteLessonRemovesItAndSendsNoRefresh` — the stores update and no GET follows (D15)

```swift
func testDeleteLessonRemovesItAndSendsNoRefresh() async throws {
    seedTwoLessons()
    api.stub("DELETE", "/api/programs/p1/lessons/l1", json: #"{"success":true}"#)
    try await actions.deleteLesson(programId: "p1", lessonId: "l1")
    XCTAssertEqual(state.lessonsFor(programId: "p1").map(\.id), ["l2"])
    XCTAssertNil(state.activities["a1"])
    XCTAssertTrue(state.programActivitiesFor(lessonId: "l1").isEmpty)
    XCTAssertEqual(api.calls.filter { $0.method == "GET" }.count, 0)
}
```

- `testDeleteLessonFailureThrowsAndKeepsTheStores` — a server error changes nothing (D15)

```swift
func testDeleteLessonFailureThrowsAndKeepsTheStores() async {
    seedTwoLessons()
    api.errorToThrow = APIError.serverError("nope")
    do {
        try await actions.deleteLesson(programId: "p1", lessonId: "l1")
        XCTFail("expected a throw")
    } catch {}
    XCTAssertEqual(state.lessonsFor(programId: "p1").map(\.id), ["l1", "l2"])
    XCTAssertNotNil(state.activities["a1"])
}
```

- [ ] **Step 1: Write the listed tests**, with a private `seedTwoLessons()` that upserts lessons `l1` (day 1) and `l2` (day 2) under `p1`, and activity `a1` under `l1`, into `state.lessons`, `state.activities`, `state.programLessonIndex` and `state.lessonActivityIndex`
- [ ] **Step 2: Run `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`, watch them fail** — the GET count, or no canned response for the refresh (`<builder>` is the directory your brief names)
- [ ] **Step 3: Change `deleteLesson` to the Behaviour**
- [ ] **Step 4: Run the same verifier request, watch them pass**
- [ ] **Step 5: Commit** — `fix(program-lesson-add-activity): deleteLesson succeeds when the delete does, without a refresh`

### Task 4: Lesson wording and the selected day after a delete
App: iphone
Phase: 2
Recipe: `iphone/.claude/CLAUDE.md` · tiny

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Programs/StudyProgramHomeMapper.swift:41,44` — the clamp and the duration wording
- Test: `iphone/MakeReadyCaptureTests/StudyProgramHomeMapperTests.swift` — D11 and D14. Update `testLessons`' `["12 min", ""]` assertion at `:66` and the existing `testActiveDayPassesThrough`, which has no lessons and now needs three

**Interfaces:**
- Consumes: nothing new.
- Produces: `StudyProgramHomeMapper.lessonDuration` — takes optional minutes, returns the row's meta string. `StudyProgramHomeScreen.State.lessonCount` stays the count Task 6 reads for D5.

**Behaviour:**
- Meta reads "N mins", "1 min" when N is 1, and "0 mins" for 0 or no estimate (D11)
- `activeDay` in the mapped state is the input clamped to 1…max(lesson count, 1). The container's `activeDay` state is not rewritten (D14)

**Tests:**
- `testLessonDurationWording` — the D11 values

```swift
func testLessonDurationWording() {
    XCTAssertEqual(StudyProgramHomeMapper.lessonDuration(nil), "0 mins")
    XCTAssertEqual(StudyProgramHomeMapper.lessonDuration(0), "0 mins")
    XCTAssertEqual(StudyProgramHomeMapper.lessonDuration(1), "1 min")
    XCTAssertEqual(StudyProgramHomeMapper.lessonDuration(3), "3 mins")
}
```

- `testActiveDayClampsToTheLessons` — past the last lesson selects the new last chip; no lessons selects 1 (D14)

```swift
func testActiveDayClampsToTheLessons() {
    let lessons = [Lesson(id: "l1", dayNumber: 1, title: "A"), Lesson(id: "l2", dayNumber: 2, title: "B")]
    XCTAssertEqual(state(input(program(), lessons: lessons, activeDay: 3)).activeDay, 2)
    XCTAssertEqual(state(input(program(), lessons: lessons, activeDay: 2)).activeDay, 2)
    XCTAssertEqual(state(input(program(), activeDay: 3)).activeDay, 1)
}
```

- `testActiveDayPassesThrough` (updated) — within range it passes through

```swift
func testActiveDayPassesThrough() {
    let lessons = (1...3).map { Lesson(id: "l\($0)", dayNumber: $0, title: "") }
    XCTAssertEqual(state(input(program(), lessons: lessons, activeDay: 3)).activeDay, 3)
}
```

- `testLessons` (updated) — the row strings

```swift
XCTAssertEqual(s.lessonDurations, ["12 mins", "0 mins"])
```

- [ ] **Step 1: Write and update the listed tests**
- [ ] **Step 2: Run `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`, watch them fail** — `lessonDuration` is not defined (`<builder>` is the directory your brief names)
- [ ] **Step 3: Implement `lessonDuration` and the clamp in the mapper to the Behaviour**
- [ ] **Step 4: Run the same verifier request, watch them pass**
- [ ] **Step 5: Commit** — `feat(program-lesson-add-activity): lesson rows read N mins, and the selected day stays on the rail`

### Task 5: The activity-new route and container
App: iphone
Phase: 2
Recipe: nav-route

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Programs/ActivityNewContainer.swift` — `ActivityNewContainer` and the pure `ActivityNewMapper`
- Modify: `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift:19,83-91` — the new case, and `isFullScreen`
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift:206-222` — route it in `page(for:)`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — the new file in the `MakeReady` target, then `MakeReadyCapture` through `ruby iphone/scripts/capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/UI2ShellModelTests.swift` — full screen. `iphone/MakeReadyCaptureTests/StudyProgramHomeContainerTests.swift` — `ActivityNewMapper`, an existing file for the same pbxproj reason as Task 2

**Interfaces:**
- Consumes: `ActivityNewScreen` and its `State` from Task 2; `Lesson.activities`; `AppState.lessons`.
- Produces: `UI2Destination.activityNew(programId:lessonId:)`, two strings. `ActivityNewContainer` — takes `programId` and `lessonId`. `ActivityNewMapper.state` — takes an optional `Lesson`, returns `ActivityNewScreen.State`. `ActivityNewMapper.placeholderID` = "placeholder", `ActivityNewMapper.placeholderLabel` = "New activity".

**Behaviour:**
- `.activityNew` is in `isFullScreen`, so no TabBar sits under C-081 (D13)
- The strip lists the lesson's activities by `orderNumber`, labelled by title (empty when nil), then one placeholder chip last and active. A lesson missing from `AppState` shows the placeholder alone (D10, D17)
- `pendingType` stays "" and `createFailed` false. The container does no load of its own (§iphone)
- Back calls `navigator.pop()`. `onSelect`, `onSelectSlide` and `onAdd` stay no-ops: no request, navigation or state change (D3, D10)
- The page applies `.ui2PushedPageFill()`, as `ProgramsHomeHost` does (D13)
- The case is reached only from the program page: no deep link or notification target (§iphone)
- ⚠ build-time risk F11: new `UI2/Containers` files are not picked up automatically, because the project has no synchronised groups and `makereadyui-sync.rb` covers only `MakeReadyUI/`. Add the file to the `MakeReady` target with the `xcodeproj` gem as `capture-targets.rb` uses it, in a throwaway command with nothing committed but the pbxproj, then run `capture-targets.rb`

**Pattern:**
- `iphone/MakeReady/UI2/Containers/Programs/ProgramsHomeHost.swift:9-22` — a pushed page's fill
- `iphone/MakeReadyCaptureTests/UI2ShellModelTests.swift:361` — the `isFullScreen` test form

**Tests:**
- `testActivityNewIsFullScreen` — in `UI2ShellModelTests` (D13)

```swift
func testActivityNewIsFullScreen() {
    XCTAssertTrue(UI2Destination.activityNew(programId: "p1", lessonId: "l1").isFullScreen)
}
```

- `testActivityNewStripListsActivitiesThenThePlaceholder` — order, labels, placeholder last and active, inert state (D10, D17)

```swift
func testActivityNewStripListsActivitiesThenThePlaceholder() {
    let lesson = Lesson(id: "l1", dayNumber: 1, title: "A",
                        activities: [StudyActivity(id: "a2", type: .read, orderNumber: 2, title: "Second"),
                                     StudyActivity(id: "a1", type: .video, orderNumber: 1, title: "First")])
    let s = ActivityNewMapper.state(lesson: lesson)
    XCTAssertEqual(s.slideIDs, ["a1", "a2", "placeholder"])
    XCTAssertEqual(s.slideLabels, ["First", "Second", "New activity"])
    XCTAssertEqual(s.activeID, "placeholder")
    XCTAssertEqual(s.pendingType, "")
    XCTAssertFalse(s.createFailed)
}
```

- `testActivityNewWithoutTheLessonShowsThePlaceholderAlone` — a missing lesson (D17)

```swift
func testActivityNewWithoutTheLessonShowsThePlaceholderAlone() {
    let s = ActivityNewMapper.state(lesson: nil)
    XCTAssertEqual(s.slideIDs, ["placeholder"])
    XCTAssertEqual(s.slideLabels, ["New activity"])
}
```

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`, watch them fail** — `activityNew` is not a member (`<builder>` is the directory your brief names)
- [ ] **Step 3: Add the destination, its `isFullScreen` entry and its `page(for:)` case**
- [ ] **Step 4: Create `ActivityNewContainer.swift` to the Behaviour, add it to the project and run `capture-targets.rb`**
- [ ] **Step 5: Run the same verifier request, watch them pass**
- [ ] **Step 6: Commit** — `feat(program-lesson-add-activity): route to the activity-new picker with the lesson's strip`

### Task 6: The lesson menu, confirmation and delete on the program page
App: iphone
Phase: 2
Recipe: present-overlay

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Programs/StudyProgramHomeContainer.swift` — wire both closures, present the menu and confirmation, run the delete
- Test: `iphone/MakeReadyCaptureTests/StudyProgramHomeContainerTests.swift` — the pure decisions

**Interfaces:**
- Consumes: `StudyProgramHomeScreen`'s `onAddActivity` and `onOpenLessonMenu` from Task 2; `deleteLesson` from Task 3; `StudyProgramHomeScreen.State.lessonCount` from Task 4; `UI2Destination.activityNew(programId:lessonId:)` from Task 5; `ActionMenuOverlay` with `title`, `message`, `actions` and `doneLabel`.
- Produces, all on `StudyProgramHomeContainer`: `LessonMenuChoice`, a String enum with cases `addActivity` = "Add activity" and `deleteLesson` = "Delete lesson". `lessonMenuRows` — takes `lessonCount`, returns the `ActionMenuOverlay.ActionItem` rows. `lessonID` — takes `at` an index and `in` a list of lessons, returns the optional id at that position by `dayNumber`. `DeleteFailure`, an enum with cases `silent`, `signOut` and `banner`. `deleteFailure` — takes `for` an error, returns a `DeleteFailure`. The strings `deleteLessonConfirmTitle`, `deleteLessonConfirmMessage`, `deleteLessonFailedMessage`, and `deleteLessonConfirmAction`, one destructive `ActionItem`.

**Behaviour:**
- The "+" card pushes `.activityNew` for that lesson at once (D2)
- The chevron presents `ActionMenuOverlay` with Add activity then Delete lesson; the Done button stays (D4, D16)
- Rows: glyph `add`, "Add activity", standard tone; glyph `trash-2`, "Delete lesson", destructive tone (D16)
- With exactly 1 lesson the menu omits Delete lesson (D5)
- The container holds the lesson's id from the chevron tap, so a background reload can't retarget the action (D16)
- A chosen row runs in the menu's `onHidden`, as `runPendingCoverChoice` does: Add activity pushes the picker; Delete lesson presents the confirmation (D4, D16)
- The confirmation is `ActionMenuOverlay(title:message:actions:doneLabel: "Cancel")` with one destructive action, the `RequestDetailContainer` form (D8, D16)
- Exact copy: title "Delete lesson?", message "This lesson and its activities will be permanently deleted.", action "Delete lesson", failure banner "Couldn't delete the lesson" (D8, D9)
- Cancel keeps the lesson, sends no request and clears the held id (D8)
- One delete runs at a time, guarded by `deletingLesson`, as `addLesson` guards with `addingLesson` (D15)
- No client-side role gating on the card or chevron; the server's `programManageFilter` decides (D19)

The delete's control flow (D9, D15) — the banner path reloads too, so a row deleted elsewhere or a stale count corrects itself, and a 404 shows the banner instead of popping the page:

```text
guard !deletingLesson; deletingLesson = true; defer false
do:
  try await ProgramActions().deleteLesson(programId, lessonId)
  await reload()
catch, by deleteFailure(for: error):
  .silent  → return
  .signOut → await signOut()
  .banner  → recordError(error, context: "StudyProgramHomeContainer.deleteLesson", surface: true,
                         friendlyMessage: deleteLessonFailedMessage, retry: delete the same lessonId again)
             await reload()
```

**Pattern:**
- `iphone/MakeReady/UI2/Containers/Programs/StudyProgramHomeContainer.swift:96-106,200-209` — menu plus `onHidden`
- `iphone/MakeReady/UI2/Containers/Programs/StudyProgramHomeContainer.swift:230-248` — the `addLesson` flag and failure form
- `iphone/MakeReady/UI2/Containers/Invites/RequestDetailContainer.swift:152-160` — the confirmation form
- `iphone/MakeReady/UI2/Containers/Groups/GroupDetailContainer.swift` — two `.actionMenuPresentation` modifiers on one page

**Tests:**
- `testLessonMenuRowsInOrderWithGlyphsAndTones` — two or more lessons (D4, D16)

```swift
func testLessonMenuRowsInOrderWithGlyphsAndTones() {
    let rows = StudyProgramHomeContainer.lessonMenuRows(lessonCount: 2)
    XCTAssertEqual(rows.map(\.label), ["Add activity", "Delete lesson"])
    XCTAssertEqual(rows.map(\.glyph), ["add", "trash-2"])
    XCTAssertEqual(rows.map(\.tone), [.standard, .destructive])
}
```

- `testLessonMenuOmitsDeleteForTheOnlyLesson` — one lesson (D5)

```swift
func testLessonMenuOmitsDeleteForTheOnlyLesson() {
    XCTAssertEqual(StudyProgramHomeContainer.lessonMenuRows(lessonCount: 1).map(\.label), ["Add activity"])
}
```

- `testDeleteConfirmationStrings` — the D8 copy, destructive, and the D9 banner

```swift
func testDeleteConfirmationStrings() {
    XCTAssertEqual(StudyProgramHomeContainer.deleteLessonConfirmTitle, "Delete lesson?")
    XCTAssertEqual(StudyProgramHomeContainer.deleteLessonConfirmMessage, "This lesson and its activities will be permanently deleted.")
    XCTAssertEqual(StudyProgramHomeContainer.deleteLessonConfirmAction.label, "Delete lesson")
    XCTAssertEqual(StudyProgramHomeContainer.deleteLessonConfirmAction.tone, .destructive)
    XCTAssertEqual(StudyProgramHomeContainer.deleteLessonFailedMessage, "Couldn't delete the lesson")
}
```

- `testDeleteFailureRouting` — cancelled is silent, 401 signs out, and everything else is the banner, 404 included (D15, D19)

```swift
func testDeleteFailureRouting() {
    XCTAssertEqual(StudyProgramHomeContainer.deleteFailure(for: CancellationError()), .silent)
    XCTAssertEqual(StudyProgramHomeContainer.deleteFailure(for: APIError.unauthorized), .signOut)
    XCTAssertEqual(StudyProgramHomeContainer.deleteFailure(for: APIHTTPError(status: 404, message: nil)), .banner)
    XCTAssertEqual(StudyProgramHomeContainer.deleteFailure(for: APIError.serverError("nope")), .banner)
}
```

- `testLessonIDFollowsDayOrder` — the index the screen sends maps to the right lesson, and out of range gives nil (D16)

```swift
func testLessonIDFollowsDayOrder() {
    let lessons = [Lesson(id: "l2", dayNumber: 2, title: ""), Lesson(id: "l1", dayNumber: 1, title: "")]
    XCTAssertEqual(StudyProgramHomeContainer.lessonID(at: 0, in: lessons), "l1")
    XCTAssertEqual(StudyProgramHomeContainer.lessonID(at: 1, in: lessons), "l2")
    XCTAssertNil(StudyProgramHomeContainer.lessonID(at: 2, in: lessons))
}
```

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`, watch them fail** — `lessonMenuRows` is not a member (`<builder>` is the directory your brief names)
- [ ] **Step 3: Add the pure helpers and strings**
- [ ] **Step 4: Wire `onAddActivity` and `onOpenLessonMenu`, the two `.actionMenuPresentation` modifiers and the delete to the Behaviour, then run `/transition-review` on the diff**
- [ ] **Step 5: Run the same verifier request, watch them pass**
- [ ] **Step 6: Commit** — `feat(program-lesson-add-activity): lesson menu, delete confirmation and the picker from the program page`
