# ui2-programs — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking. (`build: here` — this session implements it inline.)

**Goal:** Wire the UI 2.0 Programs section (study-programs), create-study-program and study-program-home into the iPhone shell on live data, with the server storing the program settings, leader and cover framing the program page edits.

**Architecture:** Server first: one Atlas migration adds Group's settings columns + leader + cover framing to `StudyProgram`; a new `services/study-program.service.ts` owns template-less create, the widened list query with the private filter, and the payload mapper; `programs.ts` stays the route layer. Then iPhone: `StudyProgram` decodes the new optional fields; containers under `UI2/Containers/Programs/` map AppState into the d2m screens' State exactly as the Groups containers do, reusing the shared-edit-field screens and a generalised cover flow.

**Tech Stack:** server — Express, Prisma (schema YAML → Atlas), zod, vitest + supertest. iphone — SwiftUI, @Observable AppState + Actions, XCTest in MakeReadyCaptureTests.

**Spec:** docs/features/ui2-programs/SPEC.md (code map: the workspace's audit-digest.md)

## Global Constraints


- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. 🔴 You stage your commit and STOP — an iPhone commit is the human's to approve.
- Capture: fixtures are manifest-driven and twins additive-only; register a new twin in the component-capture map and check its BEM root for a collision with a legacy web component before naming it; restart the capture server after editing an adapter, and rebuild the client bundle before any web capture.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test or `/compare` diff, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(ui2-programs): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal | Gates |
|---|---|---|---|---|
| 1 | server | 1–3 | the columns exist; create works without a template; the list is widened, filtered and carries every field | `cd server && npx tsc --noEmit` · `cd server && npx tsc --noEmit -p fixtures` · `cd server && npm run test:run` · `cd server && npm run schema:validate` · `docker restart makeready-server` |
| 2 | server | 4–7 | detail/PATCH/cover/add-lesson match §Contract, fixtures seed the walk — contract FREEZES | `cd server && npx tsc --noEmit` · `cd server && npx tsc --noEmit -p fixtures` · `cd server && npm run test:run` · `docker restart makeready-server` |
| 3 | iphone | 8–10 | the phone decodes, patches and saves programs; the shell has the routes | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 4 | iphone | 11–13 | Programs list, create and the program page work on live data | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 5 | iphone | 14–16 | field edits and the cover flow; legacy surfaces proven unreferenced | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |

---

### Task 1: StudyProgram settings, leader and cover-framing columns
App: server
Phase: 1
Recipe: /api · REFERENCE §Schema & API changes (SPEC Data plan)

**Files:**
- Modify: `server/schema/schema.yaml:1950-2040` (StudyProgram fields, relations, indexes) and `:125-128`, `:181-184` (User back-relation)
- Create: `server/atlas/migrations/<generated>.sql` (+ `atlas.sum`)
- Regenerate: Prisma client (in the container)

**Interfaces:**
- Produces: `StudyProgram.isPrivate: Boolean` (default false), `ageRangeMin Int?`, `ageRangeMax Int?`, `maxMembers Int?`, `memberDirectoryAccess DirectoryAccess` (default ALLOWED), `leaderId String?` + relation `leader` (`StudyProgramLeader`), `coverOriginalUrl String?` (text), `coverFraming Json?`; `User.ledStudyPrograms`.

- [ ] **Step 1: Add the fields** to `StudyProgram` in schema.yaml, copying Group's YAML types (`schema.yaml:269-345`):

```yaml
      isPrivate:
        type: boolean
        default: false
        description: "ui2-programs D12/D13: hidden from other leaders' program lists"
      ageRangeMin:
        type: int
        nullable: true
      ageRangeMax:
        type: int
        nullable: true
      maxMembers:
        type: int
        nullable: true
      memberDirectoryAccess:
        type: enum
        enum: DirectoryAccess
        default: ALLOWED
      leaderId:
        type: string
        nullable: true
        description: "ui2-programs D12: one assignable leader, defaults to the creator"
      coverOriginalUrl:
        type: text
        nullable: true
      coverFraming:
        type: json
        nullable: true
```
  Relation `leader: {type: many_to_one, target: User, fields: [leaderId], references: [id], name: StudyProgramLeader, onDelete: SetNull, nullable: true}`; index `- fields: [leaderId]`; on User add the `ledStudyPrograms` one_to_many back-relation named `StudyProgramLeader` beside `studyPrograms`. (Match the exact key spelling Group uses for enum/text/json fields.)
- [ ] **Step 2: Validate** — `cd server && npm run schema:validate` → PASS
- [ ] **Step 3: Generate the migration** with the atlas `--var database_url=postgres://postgres:postgres@localhost:5434/makeready_dev` form (never `npm run schema:diff` — 1Password `.env`), append `UPDATE "study_programs" SET "leaderId" = "creatorId" WHERE "leaderId" IS NULL;` (precedent `atlas/migrations/20261027064150.sql:8`), `atlas migrate hash`, apply to the dev DB, `docker exec makeready-server npx prisma generate`, `docker restart makeready-server`.
- [ ] **Step 4: Typecheck** — `cd server && npx tsc --noEmit` → PASS
- [ ] **Step 5: Commit** — `feat(ui2-programs): StudyProgram settings, leader and cover-framing columns`

### Task 2: Template-less create + the program payload mapper
App: server
Phase: 1
Recipe: /api

**Files:**
- Create: `server/src/services/study-program.service.ts`
- Modify: `server/src/routes/programs.ts:215-365` (POST create)
- Test: `server/src/services/__tests__/study-program.service.test.ts`, `server/src/routes/__tests__/programs-create.request.test.ts`

**Interfaces:**
- Produces: `toProgramPayload<T extends {creator?: {name: string|null}|null, leader?: {name: string|null}|null}>(p: T): Omit<T,'creator'|'leader'> & {creatorName: string|null, leaderName: string|null}`; `createBlankProgram(input: {name: string, description?: string|null, userId: string, organizationId: string|null}): Promise<StudyProgram>`; `PROGRAM_NAME_INCLUDE = { creator: {select:{name:true}}, leader: {select:{name:true}} }`.

- [ ] **Step 1: Write the failing tests**

```ts
// study-program.service.test.ts
it('maps creator and leader names and drops the relations', () => {
  const out = toProgramPayload({ id: 'p1', creator: { name: 'Luke Keith' }, leader: null })
  expect(out).toEqual({ id: 'p1', creatorName: 'Luke Keith', leaderName: null })
})
// programs-create.request.test.ts (prisma mocked as groups-edit-fields.request.test.ts)
it('creates a blank program without a template: days 0, unpublished, leader = caller', async () => {
  prismaMock.studyProgram.create.mockResolvedValue({ id: 'p9', name: 'Walk', days: 0, creator: { name: 'U' }, leader: { name: 'U' } })
  const res = await request(app()).post('/api/programs').send({ name: '  Walk  ', days: 30, isPublished: true })
  expect(res.status).toBe(201)
  expect(prismaMock.studyProgram.create.mock.calls[0][0].data).toMatchObject({ name: 'Walk', days: 0, isPublished: false, creatorId: 'u1', leaderId: 'u1' })
  expect(prismaMock.lesson.create).not.toHaveBeenCalled()
  expect(res.body.program).toMatchObject({ id: 'p9', creatorName: 'U', leaderName: 'U' })
})
it('400s on an empty name', async () => {
  expect((await request(app()).post('/api/programs').send({ name: '   ' })).status).toBe(400)
})
it('still requires an existing template when templateId is sent', async () => {
  prismaMock.lessonTemplate.findFirst.mockResolvedValue(null)
  expect((await request(app()).post('/api/programs').send({ name: 'X', templateId: '00000000-0000-0000-0000-000000000000' })).status).toBe(404)
})
```
- [ ] **Step 2: Run and watch them fail** — `cd server && npx vitest run src/services/__tests__/study-program.service.test.ts src/routes/__tests__/programs-create.request.test.ts` → FAIL
- [ ] **Step 3: Implement** — the service (`toProgramPayload`, `createBlankProgram` writing `days: 0, isPublished: false, creatorId, leaderId: userId, updatedById: userId, organizationId` with `include: PROGRAM_NAME_INCLUDE`); in the route zod make `templateId: z.string().uuid().optional()`, `name: z.string().trim().min(1).max(200)`; branch `if (!body.templateId) { const program = await createBlankProgram({...}); return res.status(201).json({ success: true, program: toProgramPayload(program) }) }` before the template lookup; the template path also sets `leaderId: userId` and returns `toProgramPayload` with the include (match the route's existing success status).
- [ ] **Step 4: Run and watch them pass** — same command → PASS
- [ ] **Step 5: Commit** — `feat(ui2-programs): create a program without a template`

### Task 3: Program list — every managed org, private filter, full fields
App: server
Phase: 1
Recipe: /api

**Files:**
- Modify: `server/src/services/study-program.service.ts`, `server/src/services/permission.ts` (visibility helper), `server/src/routes/programs.ts:406-499`
- Test: `server/src/services/__tests__/study-program.service.test.ts`, `server/src/routes/__tests__/programs-list.request.test.ts`

**Interfaces:**
- Consumes: `getManageableOrgIds(userId)`, `isSuperAdmin(userId)` (permission.ts), `toProgramPayload`.
- Produces: `programListScope(userId: string): Promise<{orgIds: string[]}>`; `privateProgramVisibility(userId: string, orgIds: string[]): Promise<Prisma.StudyProgramWhereInput>` returning `{}` for super admins, else `{OR: [{isPrivate:false}, {creatorId:userId}, {leaderId:userId}, {organizationId:{in: ownedOrAdminOrgIds}}]}`; `buildProgramListWhere(opts): Prisma.StudyProgramWhereInput` composing `AND: [access, privacy, filters]`.

- [ ] **Step 1: Write the failing tests**

```ts
it('scopes to every managed org plus own programs, and composes privacy with AND', () => {
  const where = buildProgramListWhere({ userId: 'u1', orgIds: ['o1','o2'], privacy: { OR: [{ isPrivate: false }] }, leaders: ['l1'] })
  expect(where.AND).toEqual(expect.arrayContaining([
    { OR: [{ organizationId: { in: ['o1','o2'] } }, { creatorId: 'u1' }] },
    { OR: [{ isPrivate: false }] },
    { OR: [{ leaderId: { in: ['l1'] } }, { creatorId: { in: ['l1'] } }] },
  ]))
})
it('a Group Leader who neither created nor leads a private program does not see it', async () => { /* privateProgramVisibility with userRole Group Leader only → OR excludes the org */ })
it('owner, Admin role-holder and super admin see private programs', async () => { /* … */ })
// programs-list.request.test.ts
it('400s an orgId outside the scope', async () => { expect((await request(app()).get('/api/programs?orgId=zz')).status).toBe(400) })
it('returns org id/name, names and the D12 fields per program', async () => { /* select includes them; batched organization.findMany */ })
```
- [ ] **Step 2: Run and watch them fail** — `cd server && npx vitest run src/services/__tests__/study-program.service.test.ts src/routes/__tests__/programs-list.request.test.ts` → FAIL
- [ ] **Step 3: Implement** — scope = `getManageableOrgIds(userId)` ∪ `user.organizationId`; privacy helper: orgs the caller owns (`organization.ownerId = userId`) or holds a `UserRole` whose role name is `Admin` in; the route builds `where` through `buildProgramListWhere` (keeps `isActive: true`, `tag`, `isPublished`, `groupId`), validates `orgId` ∈ scope (else 400), adds to the `select` (`:461`): `organizationId, leaderId, isPrivate, ageRangeMin, ageRangeMax, maxMembers, memberDirectoryAccess, coverOriginalUrl, coverFraming, creator:{select:{name}}, leader:{select:{name}}`, batches `organization.findMany({where:{id:{in}}, select:{id,name}})` for `organizationName`, maps through `toProgramPayload`.
- [ ] **Step 4: Run and watch them pass** — same command → PASS; `cd server && npm run test:run` → PASS
- [ ] **Step 5: Commit** — `feat(ui2-programs): program list across managed orgs with the private filter`

### Task 4: Detail + PATCH — names, settings, org-move check, program manage filter
App: server
Phase: 2
Recipe: /api

**Files:**
- Modify: `server/src/services/permission.ts` (`programManageFilter`), `server/src/routes/programs.ts:63-71` (drop the route-local `mutationFilter` for the import), `:684-802` (detail select), `:844-1049` (PATCH)
- Test: `server/src/routes/__tests__/programs-edit-fields.request.test.ts`

**Interfaces:**
- Consumes: `isAgeRangeInverted` (`services/group-fields.ts`), `toProgramPayload`.
- Produces: `programManageFilter(userId): Promise<Prisma.StudyProgramWhereInput>` (same effect as today's `mutationFilter`); PATCH body keys `isPrivate`, `ageRange: {min:number|null, max:number|null} | null`, `maxMembers: number|null`, `memberDirectoryAccess`, `leaderId: string|null`, `description: string|null`.

- [ ] **Step 1: Write the failing tests** — PATCH each key incl. explicit nulls; `ageRange` inverted → 400 (and one bound sent against the stored other bound); `leaderId` not owner/role-holder of `program.organizationId` → 400; `organizationId` into an org the caller neither owns nor holds a role in → 403; `coverImageUrl` sets `coverOriginalUrl: null, coverFraming: Prisma.DbNull`; detail returns `creatorName`, `leaderName` and the D12 fields.
- [ ] **Step 2: Run and watch them fail** — `cd server && npx vitest run src/routes/__tests__/programs-edit-fields.request.test.ts` → FAIL
- [ ] **Step 3: Implement** — copy groups' PATCH patterns (`groups.ts:945-1040`): zod additions, `ageRange` → `ageRangeMin/Max` with `isAgeRangeInverted` against stored values, org-move check, then the `leaderId` check against the (possibly moved) org; detail `select` adds the D15 fields + names; responses map through `toProgramPayload`.
- [ ] **Step 4: Run and watch them pass** — same command; then `cd server && npm run test:run` → PASS
- [ ] **Step 5: Commit** — `feat(ui2-programs): program detail and PATCH carry settings, leader and names`

### Task 5: Program cover with original + framing
App: server
Phase: 2
Recipe: /api

**Files:**
- Modify: `server/src/services/group-cover.ts:20-114`, `server/src/routes/programs.ts:3780-3870`
- Test: `server/src/services/__tests__/group-cover.test.ts` (stays green), `server/src/routes/__tests__/programs-cover-image.request.test.ts`

**Interfaces:**
- Produces: `saveCover(owner: {kind:'group'|'program', id: string, coverOriginalUrl: string|null}, input): Promise<{coverImageUrl, coverOriginalUrl, coverFraming}>`; `saveGroupCover` kept as a wrapper. Route body `{imageData, contentType, originalData?, framing?}`; response adds top-level `coverOriginalUrl`, `coverFraming`.

- [ ] **Step 1: Write the failing tests** — legacy body still works; `originalData` + `framing` stored and returned top-level; `originalData` without `framing` → 400; R2 keys keep the `programs/program-` prefix.
- [ ] **Step 2: Run and watch them fail** — `cd server && npx vitest run src/routes/__tests__/programs-cover-image.request.test.ts src/services/__tests__/group-cover.test.ts` → FAIL (new file)
- [ ] **Step 3: Implement** — prefix map `{group: 'groups', program: 'programs'}` and base `${kind}-${id}`; owner-typed prisma update; route uses `programManageFilter`, captures to the library under `program.organizationId`.
- [ ] **Step 4: Run and watch them pass** — same command → PASS
- [ ] **Step 5: Commit** — `feat(ui2-programs): program cover keeps its original and framing`

### Task 6: Add-lesson on an empty program
App: server
Phase: 2
Recipe: /api · tiny

**Files:**
- Test: `server/src/routes/__tests__/programs-add-lesson.request.test.ts`

**Interfaces:**
- Consumes: `POST /api/programs/:id/lessons` as it is (`programs.ts:3910-4031`).

- [ ] **Step 1: Write the test** — a program with no lessons → creates `dayNumber: 1` and updates `days: 1` in the transaction.
- [ ] **Step 2: Run it** — `cd server && npx vitest run src/routes/__tests__/programs-add-lesson.request.test.ts` → PASS (behaviour verified at audit; a FAIL means fix the route here)
- [ ] **Step 3: Commit** — `test(ui2-programs): add-lesson creates day 1 on an empty program`

### Task 7: Fixture layers for the three screens — and the contract freeze
App: server
Phase: 2
Recipe: server/fixtures/README.md (house rule: fixtures)

**Files:**
- Create: `server/fixtures/screens/study-programs.ts`, `create-study-program.ts`, `study-program-home.ts`
- Modify: `server/fixtures/ids.ts` (kinds), the screen registry the README names
- Test: `server/fixtures/__tests__/` (the layers' DB test, as groups-detail's)

**Interfaces:**
- Consumes: `FIXTURE_ORG_ID`, `FIXTURE_LEADER_USER_ID`, `fixtureId('program', n)`, base PROGRAMS.

- [ ] **Step 1: Write the failing DB test** — after `full`: "Foundations of Faith" has a description, `isPrivate: false`, age 18–35, maxMembers 40, `NAMES_ONLY`, `leaderId = FIXTURE_LEADER_USER_ID`, ≥3 enrollments; program 3 is private, created by Nathan; program 4 "Empty Program" has 0 lessons, 0 enrollments, no cover; base counts under `empty` unchanged.
- [ ] **Step 2: Run and watch it fail** — the fixtures DB test command from the README → FAIL
- [ ] **Step 3: Implement** — `study-program-home.ts` updates base program 1 and creates programs 3 and 4 (fixed ids, dates from `ctx.now`); `study-programs.ts` an empty layer registering the screen unless the list needs more; `create-study-program.ts` empty layer.
- [ ] **Step 4: Run and watch it pass**; `cd server && npx tsc --noEmit -p fixtures` → PASS
- [ ] **Step 5: Freeze** — `node <builder>/scripts/advance.mjs docs/features/ui2-programs --set "contract=frozen <YYYY-MM-DD>" --head --commit "chore(ui2-programs): contract frozen"` after the phase gates pass
- [ ] **Step 6: Commit** — `feat(ui2-programs): fixture layers for the program screens`

### Task 8: StudyProgram decodes the new fields without risking the cache
App: iphone
Phase: 3
Recipe: iphone/.claude/CLAUDE.md §State Management · /ios-error-surface

**Files:**
- Modify: `iphone/MakeReady/State/Models/StudyModels.swift:19-127`
- Test: `iphone/MakeReadyCaptureTests/ProgramDecodingTests.swift` (new), `StatePersistenceRoundTripTests.swift`

**Interfaces:**
- Produces: `StudyProgram.creatorName, leaderName, leaderId, organizationId, organizationName, coverOriginalUrl: String?`, `isPrivate: Bool?`, `ageRangeMin, ageRangeMax, maxMembers: Int?`, `memberDirectoryAccess: DirectoryAccess?` (Group's enum), `coverFraming: ImageFraming?`.

- [ ] **Step 1: Write the failing tests** — decode with every key absent (all nil), present (values), and wrong-typed `coverFraming`/`memberDirectoryAccess` (nil, no throw); encode → decode round trip keeps all 12.
- [ ] **Step 2: Run and watch them fail** — `npm run ios:build-check -- --test` → FAIL
- [ ] **Step 3: Implement** — CodingKeys + `decodeIfPresent` (the two tolerant ones `(try? c.decodeIfPresent(...)) ?? nil`, as `GroupModels.swift:106`) + `encodeIfPresent` in `encode(to:)`; memberwise defaults nil.
- [ ] **Step 4: Run and watch them pass** — same → PASS; swiftlint from `iphone/`
- [ ] **Step 5: Commit** — `feat(ui2-programs): StudyProgram decodes settings, leader and cover framing`

### Task 9: ProgramActions — create, patch, cover, forget, lesson paging
App: iphone
Phase: 3
Recipe: iphone/.claude/CLAUDE.md §State Management · /ios-error-surface

**Files:**
- Modify: `iphone/MakeReady/State/Actions/ProgramActions.swift:94,116-155,194-275,366-406,565-590`
- Create: `iphone/MakeReady/State/Models/ProgramPatch.swift`
- Test: `iphone/MakeReadyCaptureTests/ProgramPatchTests.swift`, `ProgramActionsTests.swift`

**Interfaces:**
- Produces: `ProgramActions.createProgram(name: String) async throws -> StudyProgram`; `updateProgram(id: String, patch: ProgramPatch) async throws -> StudyProgram`; `saveCover(programId: String, rendered: UIImage, framing: ImageFraming?, original: UIImage?) async throws -> CoverSaveResult`; `forgetProgram(id: String)`; `getProgram` replaces `programLessonIndex[id]` after the last page. `ProgramPatch` = Group's `GroupPatch` shape with `name`, `description: String??`, `isPrivate`, `ageRange: AgeRangePatch??`, `maxMembers: Int??`, `memberDirectoryAccess`, `leaderId: String??` (explicit null encoded).

- [ ] **Step 1: Write the failing tests** — `ProgramPatch` encodes only set keys, explicit nulls as `null`, nested `ageRange`; `forgetProgram` clears the program, its lessons index and program enrollments; list load keeps the D15 fields (merge, not blank).
- [ ] **Step 2: Run and watch them fail** — `npm run ios:build-check -- --test` → FAIL
- [ ] **Step 3: Implement** — mirror `GroupActions.updateGroup(patch:)`, `saveCover` (`requestWithStatus`, 120 s, `originalData`), `forgetGroup`; extract `forgetProgram` from `deleteProgram`'s cleanup.
- [ ] **Step 4: Run and watch them pass** — same → PASS; swiftlint
- [ ] **Step 5: Commit** — `feat(ui2-programs): program create, patch, cover and forget actions`

### Task 10: Shell routes for programs
App: iphone
Phase: 3
Recipe: /push-page · /nav-route

**Files:**
- Modify: `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift:5-49,77-80`, `UI2Shell.swift:181-213`, `TopNavHost.swift:97-102`
- Test: `iphone/MakeReadyCaptureTests/UI2ShellModelTests.swift:295-302`

**Interfaces:**
- Produces: `UI2Destination.studyProgramHome(id: String, name: String)`, `.createStudyProgram`, `.editProgramField(programId: String, field: ProgramField)`, `.editProgramCover(programId: String, source: ImageEditSource)` (full-screen); `refreshableSection` includes `.programs`.

- [ ] **Step 1: Write the failing tests** — `refreshableSection` set; `.editProgramCover` `isFullScreen`; `replaceTop` from `.createStudyProgram` to `.studyProgramHome`.
- [ ] **Step 2: Run and watch them fail** → FAIL
- [ ] **Step 3: Implement** — cases, `page(for:)` mapping (containers land in Tasks 11–15; stub with `EmptyPage()` until then only within this task's commit if needed, replaced by those tasks), `sectionContent .programs`, `onAdd .programs → model.push(.createStudyProgram, on: .home)`, `refreshAction`.
- [ ] **Step 4: Run and watch them pass** → PASS; swiftlint
- [ ] **Step 5: Commit** — `feat(ui2-programs): shell routes for the program screens`

### Task 11: Programs list container
App: iphone
Phase: 4
Recipe: iphone/.claude/CLAUDE.md §State Management · build-time risk F1: start only once d2m changes cmvrt1gql000av0apcp9jchn4 and cmvrtiigb001av0ap04h1mk4u are `done`

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Programs/StudyProgramsContainer.swift`, `StudyProgramsMapper.swift`
- Test: `iphone/MakeReadyCaptureTests/StudyProgramsMapperTests.swift`

**Interfaces:**
- Consumes: `AppState.orderedPrograms`, `groupLeaders`, `myOrganizations`; `ProgramActions.loadPrograms(forceRefresh:)`, `loadGroupLeaders`, `GroupActions.loadMyOrganizations`; the screen's post-d2m filter API.
- Produces: `StudyProgramsMapper.output(programs:leaders:orgs:selectedLeaders:selectedOrgs:searchText:loading:failed:) -> (state: StudyProgramsScreen.State, programIds: [String])`.

- [ ] **Step 1: Write the failing mapper tests** — order, chips multi/AND/leader-or-creator/org, `orgFilterVisible` with ≥2 orgs, enrolled count, empty/no-match lines per D4.
- [ ] **Step 2–4:** fail → implement (container mirrors `GroupsHomeContainer`: `.task` loads, 401 sign-out, cache-aware D4 errors, row tap → `.studyProgramHome(id, name)`) → pass
- [ ] **Step 5: Commit** — `feat(ui2-programs): Programs list on live data`

### Task 12: Program page container
App: iphone
Phase: 4
Recipe: iphone/.claude/CLAUDE.md §State Management · /ios-error-surface · build-time risk F1: start only once cmvrt1jl5000jv0apjy6tlfk0 and cmvrtikv0001jv0apwciaj98o are `done`

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Programs/StudyProgramHomeHost.swift`, `StudyProgramHomeContainer.swift`, `StudyProgramHomeMapper.swift`
- Test: `iphone/MakeReadyCaptureTests/StudyProgramHomeMapperTests.swift`, `StudyProgramHomeContainerTests.swift`

**Interfaces:**
- Consumes: `ProgramActions.getProgram`, `getProgramEnrollments(programId:forceRefresh:)`, `addLesson`, `forgetProgram`; `GroupDetailMapper` label helpers.
- Produces: `StudyProgramHomeMapper.state(program:lessons:enrollments:loading:failed:activeDay:) -> StudyProgramHomeScreen.State`; `ProgramField(label:) -> ProgramField?` (nil for "Lessons").

- [ ] **Step 1: Write the failing tests** — every D6 value (each Age form, Unlimited, durations, slide fallbacks, "0 groups", "«n» lessons"); "Lessons" row maps to nil; loading/failed flags per D5.
- [ ] **Step 2–4:** fail → implement (host pins C-040 "Study program" + `showsHeader: false`, `ScrollViewReader` day scroll, image cache seeding, Lessons `+` with one-in-flight guard then reload, 404 → forget + `popTo(0)` after the push settles) → pass
- [ ] **Step 5: Commit** — `feat(ui2-programs): program page on live data`

### Task 13: Create study program container
App: iphone
Phase: 4
Recipe: /push-page · build-time risk F1: start only once cmvrtieot0011v0apd8m6x90w is `done`

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Programs/CreateStudyProgramContainer.swift`
- Test: `iphone/MakeReadyCaptureTests/CreateProgramSubmitTests.swift`

**Interfaces:**
- Produces: `CreateProgramSubmit.run(title: String, creating: Bool) async -> Result` (as `CreateGroupSubmit.run`).

- [ ] **Step 1: Write the failing tests** — trims; empty → no call; double submit guarded; failure → "Couldn't create the program"; 401 → sign-out.
- [ ] **Step 2–4:** fail → implement (full-screen host, `replaceTop(.createStudyProgram, .studyProgramHome(id, name))`) → pass
- [ ] **Step 5: Commit** — `feat(ui2-programs): create a study program from a title`

### Task 14: Program field edit pages
App: iphone
Phase: 5
Recipe: /push-page · /ios-error-surface

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Programs/ProgramFieldEditor.swift`, `ProgramFieldEditContainer.swift`, `iphone/MakeReady/UI2/Containers/Shared/FieldEditRules.swift` (helpers lifted from `GroupFieldEditor`)
- Modify: `iphone/MakeReady/UI2/Containers/Groups/GroupFieldEditor.swift` (use the lifted helpers)
- Test: `iphone/MakeReadyCaptureTests/ProgramFieldEditorTests.swift`; `GroupFieldEditorTests` stays green

**Interfaces:**
- Produces: `enum ProgramField { name, description, visibility, ageRange, maxMembers, memberDirectoryAccess }`; `ProgramFieldEditModel.page(field:program:saving:errorMessage:)`; `patch(for:value:) -> ProgramPatch`.

- [ ] **Step 1: Write the failing tests** — per field: page kind, validation, copy, the patch it builds (explicit nulls, nested ageRange).
- [ ] **Step 2–4:** fail → implement (mirror `GroupFieldEditContainer`: save → `updateProgram` → `popIfTop`; 404 forget + `popTo(0)`; Age failure → banner) → pass
- [ ] **Step 5: Commit** — `feat(ui2-programs): program settings edit pages`

### Task 15: Program cover flow
App: iphone
Phase: 5
Recipe: /present-overlay · /transition-review

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Groups/EditGroupCoverContainer.swift:10-265`, `CoverViewerOverlay.swift:17-81`, the cover-tap helper in `GroupDetailContainer.swift` (generalise over original/cover/framing)
- Create: `iphone/MakeReady/UI2/Containers/Programs/EditProgramCoverContainer.swift` (thin, over the generalised container)
- Modify: `StudyProgramHomeContainer.swift` (cover tap → picker / C-066 menu / viewer)
- Test: `EditGroupCoverContainerTests`, `GroupDetailCoverTapTests` stay green; `ProgramCoverTapTests.swift` (new)

- [ ] **Step 1: Write the failing tests** — program cover tap: no cover → picker; cover → menu Edit/Change/View; Edit reopens on `coverOriginalUrl` + `coverFraming`; save calls `ProgramActions.saveCover`.
- [ ] **Step 2–4:** fail → implement (no `.sheet`/`.fullScreenCover`; `.photosPicker`) → pass; `/transition-review` on the diff
- [ ] **Step 5: Commit** — `feat(ui2-programs): program cover uses the group cover flow`

### Task 16: Repoint + retire sweep (R1–R3)
App: iphone
Phase: 5
Recipe: REFERENCE §Prototype mode (repoint + retire) · tiny

**Files:**
- (none changed unless a hit is found)

- [ ] **Step 1: Re-grep** the app target's compiled sources for `MainPrograms`, `ProgramHomePage`, `CreateProgramPage`, `.programHome`, `.createProgram` → zero hits outside `MakeReady/Pages/` (out of target); record the result in the ledger.
- [ ] **Step 2: Commit** — only if a hit had to be repointed: `refactor(ui2-programs): repoint <surface>`
