# filter-multiselect — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** every UI 2.0 filter menu (C-036) takes one or more picks and applies them with an explicit Save; the members directory accepts lists of groups and leaders.

**Architecture:** the server's `GET /api/organizations/:orgId/members` gains additive `groupIds` / `leaderIds` list params (OR within, AND across, narrowed callers' out-of-scope ids dropped). On iPhone, C-036 `FilterMenuOverlay` holds a draft set when its new `onSave` is given (Clear empties it, Save hands it back, ✕ discards it); Members, the invite picker and Groups home store sets instead of one value and show D4's chip labels.

**Tech Stack:** server — Express + zod + Prisma, vitest + supertest · iphone — SwiftUI (MakeReadyUI views + UI2 containers), `@Observable` AppState, XCTest in `MakeReadyCaptureTests`.

**Spec:** `docs/features/filter-multiselect/SPEC.md`

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. 🔴 You stage your commit and STOP — an iPhone commit is the human's to approve.
- Capture: fixtures are manifest-driven and twins additive-only; register a new twin in the component-capture map and check its BEM root for a collision with a legacy web component before naming it; restart the capture server after editing an adapter, and rebuild the client bundle before any web capture.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test or `/compare` diff, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(filter-multiselect): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal | Gates |
|---|---|---|---|---|
| 1 | server | 1–2 | `/members` filters by lists of groups and leaders (D5/D6/D7/D11); contract frozen | `cd server && npx tsc --noEmit` · `cd server && npm run test:run` |
| 2 | iphone | 3 | C-036 has a draft mode: Clear + Save on the top row, toggling options, `onSave(Set)` | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 3 | iphone | 4–5 | Members picks several groups and leaders, sends the list params, shows D4 chips | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 4 | iphone | 6–7 | invite Select group → Leaders and Groups home's Orgs / Leaders are multi-select | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |

---

### Task 1: Service — `groupIds` / `leaderIds` in `getOrganizationMembers`
App: server
Phase: 1
Recipe: `/api` (server endpoint) — the service half; SPEC §server, D5, D7

**Files:**
- Modify: `server/src/services/organization.ts` (`OrgMembersQuery` ~208, `getOrganizationMembers` ~237-271)
- Test: `server/src/services/__tests__/organization-members.test.ts`

**Interfaces:**
- Consumes: nothing new.
- Produces: `OrgMembersQuery.groupIds?: string[]`, `OrgMembersQuery.leaderIds?: string[]` — Task 2's route passes them. An empty or absent list = no filter for a caller who sees all. For a narrowed caller, ids outside their scope are dropped, and a list that ends empty answers `{ success: true, data: [], viewerScope }` without querying (D7). The single `groupId` / `leaderId` keep today's exact behaviour.

- [ ] **Step 1: Write the failing tests** — append to `server/src/services/__tests__/organization-members.test.ts`, inside the existing describe blocks as marked:

```ts
// inside describe('getOrganizationMembers — Owner/Admin (all)', …)
  it('ORs within groupIds and leaderIds and ANDs across them (filter-multiselect D5)', async () => {
    await getOrganizationMembers(ORG, 'owner-1', { groupIds: ['g1', 'g2'], leaderIds: ['u1', 'u2'] })
    expect(prismaMock.memberOrganization.findMany.mock.calls[0][0].where).toEqual({
      organizationId: ORG,
      member: {
        AND: [{ isActive: true }, activeIn({ id: { in: ['g1', 'g2'] } }), activeIn({ creatorId: { in: ['u1', 'u2'] } })],
      },
    })
  })

  it('treats empty lists as no filter (D6)', async () => {
    await getOrganizationMembers(ORG, 'owner-1', { groupIds: [], leaderIds: [] })
    expect(prismaMock.memberOrganization.findMany.mock.calls[0][0].where).toEqual({
      organizationId: ORG,
      member: { AND: [{ isActive: true }] },
    })
  })

  it('lets the org constraint empty another org’s group in a list', async () => {
    await getOrganizationMembers(ORG, 'owner-1', { groupIds: ['g-other-org'] })
    expect(prismaMock.memberOrganization.findMany.mock.calls[0][0].where.member.AND).toContainEqual(
      activeIn({ id: { in: ['g-other-org'] } })
    )
  })

// inside describe('getOrganizationMembers — narrowed leader (D7, D15)', …)
  it('drops out-of-scope ids from the lists and keeps the rest (filter-multiselect D7)', async () => {
    await getOrganizationMembers(ORG, 'gl', { groupIds: ['g-led', 'g-foreign'], leaderIds: ['gl', 'other-leader'] })
    expect(prismaMock.memberOrganization.findMany.mock.calls[0][0].where).toEqual({
      organizationId: ORG,
      member: {
        AND: [
          { isActive: true },
          activeIn({ id: { in: ['g-led'] } }),
          activeIn({ creatorId: { in: ['gl'] } }),
          activeIn({ id: { in: ['g-led'] } }),
        ],
      },
    })
  })

  it.each([
    ['only out-of-scope groups', { groupIds: ['g-foreign'] }],
    ['only other leaders', { leaderIds: ['other-leader'] }],
  ])('answers a list of %s with an empty list, without querying (D7)', async (_label, options) => {
    const result = await getOrganizationMembers(ORG, 'gl', options)
    expect(result).toEqual({ success: true, data: [], viewerScope: { all: false, groupIds: ['g-led'] } })
    expect(prismaMock.memberOrganization.findMany).not.toHaveBeenCalled()
  })
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run src/services/__tests__/organization-members.test.ts` → FAIL (the `in` filters are missing; tsc may also flag `groupIds` as an unknown key)

- [ ] **Step 3: Write the minimal implementation** in `server/src/services/organization.ts`:

```ts
export interface OrgMembersQuery {
  includeInactive?: boolean
  search?: string
  groupId?: string
  /** A User.id from /api/group-leaders → members of groups with that creatorId. */
  leaderId?: string
  /** filter-multiselect D5/D6: members active in ANY of these groups. Absent or [] = no filter. */
  groupIds?: string[]
  /** filter-multiselect D5: members of groups created by ANY of these users. A user who created
   *  no groups (an Owner/Admin listed by /api/group-leaders) contributes no members. */
  leaderIds?: string[]
}
```

and inside `getOrganizationMembers`, replace the destructuring and the narrowed-scope block, then add the two pushes after the single-filter pushes:

```ts
    const { includeInactive = false, search, groupId, leaderId } = options
    let { groupIds, leaderIds } = options
    const scope = await memberAccessScope(viewerUserId, organizationId)
    const viewerScope = { all: scope.all, groupIds: scope.all ? [] : scope.groupIds }
    if (!scope.all) {
      const outside =
        scope.groupIds.length === 0 ||
        (groupId !== undefined && !scope.groupIds.includes(groupId)) ||
        (leaderId !== undefined && leaderId !== viewerUserId)
      if (outside) return { success: true, data: [], viewerScope }
      // filter-multiselect D7: out-of-scope ids are dropped; a list that was sent and ends empty
      // names nothing the caller may see.
      if (groupIds !== undefined && groupIds.length > 0) {
        groupIds = groupIds.filter((id) => scope.groupIds.includes(id))
        if (groupIds.length === 0) return { success: true, data: [], viewerScope }
      }
      if (leaderIds !== undefined && leaderIds.length > 0) {
        leaderIds = leaderIds.filter((id) => id === viewerUserId)
        if (leaderIds.length === 0) return { success: true, data: [], viewerScope }
      }
    }
```

```ts
    if (groupId !== undefined) and.push(activeIn({ id: groupId }))
    if (leaderId !== undefined) and.push(activeIn({ creatorId: leaderId }))
    // filter-multiselect D5: OR within a list (`in`), AND across filters (each its own entry).
    if (groupIds !== undefined && groupIds.length > 0) and.push(activeIn({ id: { in: groupIds } }))
    if (leaderIds !== undefined && leaderIds.length > 0) and.push(activeIn({ creatorId: { in: leaderIds } }))
    if (!scope.all) and.push(activeIn({ id: { in: scope.groupIds } }))
```

Also extend the function's doc comment with one line: `filter-multiselect: groupIds / leaderIds OR within, AND across; a narrowed caller's out-of-scope ids are dropped (D7).`

- [ ] **Step 4: Run it and watch it pass** — `cd server && npx vitest run src/services/__tests__/organization-members.test.ts` → PASS; `cd server && npx tsc --noEmit` → clean

- [ ] **Step 5: Commit** — `feat(filter-multiselect): members directory filters by lists of groups and leaders`

### Task 2: Route — parse `groupIds` / `leaderIds`, 400 on a bad list, Swagger; freeze the contract
App: server
Phase: 1
Recipe: `/api` (server endpoint) — the route half; SPEC §Contract, D6, D11

**Files:**
- Modify: `server/src/routes/organizations.ts` (Swagger block ~654-765, handler ~766-790)
- Test: `server/src/routes/__tests__/organization-members.request.test.ts`
- Modify: `docs/features/filter-multiselect/MANIFEST.md` (via `advance.mjs` — the freeze)

**Interfaces:**
- Consumes: Task 1's `OrgMembersQuery.groupIds` / `leaderIds`.
- Produces: the frozen §Contract row — `GET /api/organizations/:orgId/members?groupIds=a,b&leaderIds=c` (also the repeated form `groupIds=a&groupIds=b`); 400 `{ success: false, error }` on an invalid uuid or a non-string/array shape in a list; single `groupId` / `leaderId` unchanged and never 400.
- Build-time risk (F7): a list that parses to no ids (`groupIds=,`) must reach the service as `undefined`, never `[]`.

- [ ] **Step 1: Write the failing tests** — add to `organization-members.request.test.ts` (uuid-shaped ids; the existing tests keep passing because `toHaveBeenCalledWith` ignores `undefined` keys):

```ts
const G1 = '11111111-1111-4111-8111-111111111111'
const G2 = '22222222-2222-4222-8222-222222222222'
const U1 = '33333333-3333-4333-8333-333333333333'

describe('GET /api/organizations/:organizationId/members — lists (filter-multiselect D6, D11)', () => {
  const lastQuery = () => vi.mocked(getOrganizationMembers).mock.calls[0][2]

  it('splits comma lists into the service arrays', async () => {
    const res = await request(await appAs('owner-1')).get(`/api/organizations/org-1/members?groupIds=${G1},${G2}&leaderIds=${U1}`)
    expect(res.status).toBe(200)
    expect(lastQuery()).toMatchObject({ groupIds: [G1, G2], leaderIds: [U1] })
  })

  it('accepts the repeated form, trims, and drops duplicates', async () => {
    const res = await request(await appAs('owner-1')).get(`/api/organizations/org-1/members?groupIds=${G1}&groupIds=%20${G2}&groupIds=${G1}`)
    expect(res.status).toBe(200)
    expect(lastQuery()).toMatchObject({ groupIds: [G1, G2] })
  })

  it('treats a list with no ids left as absent (F7)', async () => {
    const res = await request(await appAs('owner-1')).get('/api/organizations/org-1/members?groupIds=,&leaderIds=')
    expect(res.status).toBe(200)
    expect(lastQuery()?.groupIds).toBeUndefined()
    expect(lastQuery()?.leaderIds).toBeUndefined()
  })

  it('unions a uuid single param into its list', async () => {
    await request(await appAs('owner-1')).get(`/api/organizations/org-1/members?groupId=${G1}&groupIds=${G2}`)
    expect(lastQuery()).toMatchObject({ groupId: undefined, groupIds: [G1, G2] })
  })

  it('keeps a single groupId alone exactly as before, uuid or not', async () => {
    const res = await request(await appAs('gl')).get('/api/organizations/org-1/members?groupId=g-foreign')
    expect(res.status).toBe(200)
    expect(lastQuery()).toMatchObject({ groupId: 'g-foreign', groupIds: undefined })
  })

  it.each([
    ['a non-uuid in groupIds', `groupIds=${G1},not-a-uuid`],
    ['a non-uuid in leaderIds', 'leaderIds=nope'],
    ['an object shape', `groupIds[a]=${G1}`],
  ])('400s on %s', async (_label, qs) => {
    const res = await request(await appAs('owner-1')).get(`/api/organizations/org-1/members?${qs}`)
    expect(res.status).toBe(400)
    expect(res.body.success).toBe(false)
    expect(getOrganizationMembers).not.toHaveBeenCalled()
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run src/routes/__tests__/organization-members.request.test.ts` → FAIL (lists not parsed; no 400)

- [ ] **Step 3: Write the minimal implementation** in `server/src/routes/organizations.ts`. Above the `router.get('/:organizationId/members', …)` Swagger block, add:

```ts
const uuidSchema = z.string().uuid()

/**
 * filter-multiselect D11: `a,b` or the repeated `x=a&x=b` (Express parses that to an array) →
 * distinct, trimmed ids. Absent, or nothing left after dropping empties → undefined (no filter,
 * never `in: []`). Any other shape, or an id that is not a uuid → 'invalid' (400).
 */
function parseIdList(value: unknown): string[] | undefined | 'invalid' {
  if (value === undefined) return undefined
  const parts =
    typeof value === 'string'
      ? [value]
      : Array.isArray(value) && value.every((p) => typeof p === 'string')
        ? (value as string[])
        : null
  if (parts === null) return 'invalid'
  const ids = [...new Set(parts.flatMap((p) => p.split(',')).map((p) => p.trim()).filter((p) => p.length > 0))]
  if (ids.length === 0) return undefined
  return ids.every((id) => uuidSchema.safeParse(id).success) ? ids : 'invalid'
}
```

In the handler, replace the `getOrganizationMembers(…)` call block with:

```ts
      const text = (v: unknown) => (typeof v === 'string' && v.length > 0 ? v : undefined)
      const isUuid = (v: string | undefined): v is string => v !== undefined && uuidSchema.safeParse(v).success

      let groupId = text(req.query.groupId)
      let leaderId = text(req.query.leaderId)
      let groupIds = parseIdList(req.query.groupIds)
      let leaderIds = parseIdList(req.query.leaderIds)
      if (groupIds === 'invalid' || leaderIds === 'invalid') {
        return res.status(400).json({
          success: false,
          error: 'groupIds and leaderIds must be comma-separated uuids',
        })
      }
      // D6: a uuid single param joins its list; a non-uuid one keeps today's no-match meaning.
      if (groupIds && isUuid(groupId)) {
        groupIds = [...new Set([groupId, ...groupIds])]
        groupId = undefined
      }
      if (leaderIds && isUuid(leaderId)) {
        leaderIds = [...new Set([leaderId, ...leaderIds])]
        leaderId = undefined
      }

      const result = await getOrganizationMembers(organizationId, userId, {
        search: text(req.query.search),
        groupId,
        leaderId,
        groupIds,
        leaderIds,
        includeInactive: req.query.includeInactive === 'true',
      })
```

(The existing `const text = …` line moves into this block — keep exactly one.) In the Swagger block, after the `leaderId` parameter, add:

```yaml
 *       - in: query
 *         name: groupIds
 *         required: false
 *         schema:
 *           type: string
 *         description: filter-multiselect — comma-separated group uuids (or repeated groupIds=…); members active in ANY of them. AND'd with leaderIds. A group-scoped caller's out-of-scope ids are dropped; empty result if none remain. 400 on a non-uuid.
 *       - in: query
 *         name: leaderIds
 *         required: false
 *         schema:
 *           type: string
 *         description: filter-multiselect — comma-separated User uuids (or repeated leaderIds=…); members of groups created by ANY of them. 400 on a non-uuid.
```

and add a `400:` response next to `401:` (`description: groupIds or leaderIds is not a list of uuids`, `$ref: '#/components/schemas/ErrorResponse'`).

- [ ] **Step 4: Run it and watch it pass** — `cd server && npx vitest run src/routes/__tests__/organization-members.request.test.ts src/services/__tests__/organization-members.test.ts` → PASS; `cd server && npx tsc --noEmit` → clean; `cd server && npm run test:run` → green

- [ ] **Step 5: Commit** — `feat(filter-multiselect): /members accepts groupIds and leaderIds lists`

- [ ] **Step 6: Freeze the contract** (the producer phase's close) — `node plugins/builder/scripts/advance.mjs docs/features/filter-multiselect --set "contract=frozen 2026-10-26" --commit "chore(filter-multiselect): contract frozen"`

### Task 3: C-036 draft mode — Clear + Save, toggling options, `onSave(Set)`
App: iphone
Phase: 2
Recipe: `/present-overlay` (overlay conventions — no `.sheet`, no `asyncAfter`); SPEC §iphone C-036, D1, D4, D8, D10

**Files:**
- Modify: `iphone/MakeReadyUI/FilterMenuOverlay.swift`
- Test: `iphone/MakeReadyCaptureTests/UI2MembersComponentTests.swift` (append — this target's files are registered explicitly in `project.pbxproj`, so no new test file)

**Interfaces:**
- Consumes: C-049 `LinkButton(label:onTap:isEnabled:)` (`MakeReadyUI/LinkButton.swift`; `style` defaults to `.default`).
- Produces (used by Tasks 5–7):
  - `FilterMenuOverlay.init(options:selectionMode:selectedIDs:onSelect:onClose:onClear:clearEnabled:onSave:)` — every parameter after `selectedIDs` defaulted; `onSave: ((Set<String>) -> Void)? = nil`.
  - `static func FilterMenuOverlay.toggled(_ draft: Set<String>, _ id: String) -> Set<String>`
  - `static func FilterMenuOverlay.chipLabel(picked labels: [String], resting: String, noun: String) -> String` — D4: 0 → `resting`, 1 → the label, n ≥ 2 → `"\(n) \(noun)"` (`noun` is the plural: "groups", "leaders", "orgs").
- Build-time risk (F4): rewrite the header's OQ-C-036-10 line and the `selectedIDs` doc's "Controlled (R-01)" sentence to describe draft mode; F2 routes both to `/d2m:component:update C-036`.

- [ ] **Step 1: Write the failing tests** — append to `UI2MembersComponentTests.swift`:

```swift
/// filter-multiselect D1/D4/D10: C-036's draft transition and chip summary.
final class FilterMenuOverlayDraftTests: XCTestCase {
    func testToggleAddsThenRemoves() {
        var draft: Set<String> = ["a"]
        draft = FilterMenuOverlay.toggled(draft, "b")
        XCTAssertEqual(draft, ["a", "b"])
        draft = FilterMenuOverlay.toggled(draft, "a")
        XCTAssertEqual(draft, ["b"])
    }

    func testChipLabelForZeroOneAndMany() {
        XCTAssertEqual(FilterMenuOverlay.chipLabel(picked: [], resting: "All Groups", noun: "groups"), "All Groups")
        XCTAssertEqual(FilterMenuOverlay.chipLabel(picked: ["Youth"], resting: "All Groups", noun: "groups"), "Youth")
        XCTAssertEqual(FilterMenuOverlay.chipLabel(picked: ["A", "B", "C"], resting: "All Leaders", noun: "leaders"), "3 leaders")
    }

    func testDraftModeBuildsWithSave() {
        var saved: Set<String>?
        let menu = FilterMenuOverlay(
            options: [.init(id: "a", label: "A")], selectionMode: .multiple, selectedIDs: ["a"],
            onSave: { saved = $0 }
        )
        menu.onSave?(["a"])
        XCTAssertEqual(saved, ["a"])
    }
}
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile ("type 'FilterMenuOverlay' has no member 'toggled'", "extra argument 'onSave'")

- [ ] **Step 3: Write the minimal implementation** in `FilterMenuOverlay.swift`:

Add after `clearEnabled`:

```swift
    /// filter-multiselect D1/D10: set → draft mode. Option taps toggle a draft seeded from
    /// `selectedIDs` when the menu opens; the top row's Clear empties the draft (the menu stays
    /// open); Save hands the draft back here (the presenter applies it and closes); ✕ discards it.
    /// `onSelect` still fires per toggle. `onClear` / `clearEnabled` are ignored in this mode (D10).
    var onSave: ((Set<String>) -> Void)?

    /// D1: the picks being edited — seeded once per presentation (each opening builds a new view).
    @SwiftUI.State private var draft: Set<String>

    private static let saveLabel = "Save"

    init(
        options: [Option],
        selectionMode: SelectionMode,
        selectedIDs: Set<String>,
        onSelect: @escaping (Option) -> Void = { _ in },
        onClose: @escaping () -> Void = {},
        onClear: (() -> Void)? = nil,
        clearEnabled: Bool = true,
        onSave: ((Set<String>) -> Void)? = nil
    ) {
        self.options = options
        self.selectionMode = selectionMode
        self.selectedIDs = selectedIDs
        self.onSelect = onSelect
        self.onClose = onClose
        self.onClear = onClear
        self.clearEnabled = clearEnabled
        self.onSave = onSave
        // Seeded here, not in onAppear, so the first frame already shows the current checks.
        _draft = SwiftUI.State(initialValue: selectedIDs)
    }

    /// D1: a tap toggles the option's id in the draft.
    static func toggled(_ draft: Set<String>, _ id: String) -> Set<String> {
        var next = draft
        if next.remove(id) == nil { next.insert(id) }
        return next
    }

    /// D4: a chip's text for the picked labels — none → `resting`, one → that label,
    /// n ≥ 2 → "n <noun>" (`noun` plural).
    static func chipLabel(picked labels: [String], resting: String, noun: String) -> String {
        switch labels.count {
        case 0: return resting
        case 1: return labels[0]
        default: return "\(labels.count) \(noun)"
        }
    }
```

Change `var onSelect`, `var onClose`, `var onClear`, `var clearEnabled` to drop their `= …` defaults (the init carries them). Replace the `if let onClear { … }` block in `body` with:

```swift
                    if let onSave {
                        // filter-multiselect D1/D8: Clear leading, Save trailing, one fixed row above
                        // the list. Clear is enabled iff the draft is non-empty; Save always is.
                        HStack(spacing: Token.Space.cardPadding) {
                            LinkButton(label: Self.clearLabel, onTap: { draft = [] }, isEnabled: !draft.isEmpty)
                                .ui2Element("C-049 LinkButton")
                            Spacer(minLength: 0)
                            LinkButton(label: Self.saveLabel, onTap: { onSave(draft) })
                                .ui2Element("C-049 LinkButton 2")
                        }
                        .padding(.horizontal, Token.Space.sectionGap)
                        .padding(.vertical, Token.Space.cardPadding)
                    } else if let onClear {
                        // filter-menu-clear: fixed above the list (it never scrolls away), on the
                        // option rows' leading inset.
                        LinkButton(label: Self.clearLabel, onTap: onClear, isEnabled: clearEnabled)
                            .padding(.horizontal, Token.Space.sectionGap)
                            .padding(.vertical, Token.Space.cardPadding)
                            .ui2Element("C-049 LinkButton")
                    }
```

In `optionList`, replace the `OptionRow(…)` arguments:

```swift
                    OptionRow(
                        glyph: option.glyph,
                        label: option.label,
                        selected: onSave != nil ? draft.contains(option.id) : selectedIDs.contains(option.id),
                        onTap: {
                            if onSave != nil { draft = Self.toggled(draft, option.id) }
                            onSelect(option)
                        }
                    )
```

Rewrite the header comment's `OQ-C-036-10` line to: `OQ-C-036-10 as amended by filter-multiselect D1 (owner 2026-10-26): with onSave set, picks are a draft — Save applies, ✕ discards (routed to /d2m:component:update C-036, F2/F4).` and the `selectedIDs` doc's last sentence to `Controlled (R-01) except in draft mode (onSave set), where it only seeds the draft.`

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS (the `ViewRegistry` C-036 case still builds: it passes only the first three arguments); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations

- [ ] **Step 5: Commit** — `feat(filter-multiselect): C-036 draft mode with Clear and Save`

### Task 4: `MemberActions.loadDirectory` sends `groupIds` / `leaderIds`
App: iphone
Phase: 3
Recipe: `/ios-error-surface` (the Action's failure routing is unchanged — keep it); SPEC §iphone Members, D12, F1

**Files:**
- Modify: `iphone/MakeReady/State/Actions/MemberActions.swift:28-42`
- Modify: `iphone/MakeReady/State/Models/MemberModels.swift:70-76` (`OrgMemberDirectory`)
- Modify: `iphone/MakeReady/UI2/Containers/Members/MembersHomeContainer.swift:103-110` (`load` — a one-line bridge Task 5 replaces)
- Test: `iphone/MakeReadyCaptureTests/MemberActionsTests.swift`

**Interfaces:**
- Consumes: the frozen §Contract (`groupIds=a,b&leaderIds=c`; the server never needs the single params from this build).
- Produces: `MemberActions.loadDirectory(orgId: String, search: String = "", groupIds: Set<String> = [], leaderIds: Set<String> = []) async`; `OrgMemberDirectory.groupIds: [String]`, `.leaderIds: [String]` (sorted; replace `groupId` / `leaderId`). The store key stays `orgId` (F1).

- [ ] **Step 1: Write the failing tests** — in `MemberActionsTests.swift`, replace `testDirectoryQuerySendsTrimmedSearchAndBothFilters` and change `XCTAssertNil(directory?.groupId)` in `testDirectoryLandsUnderItsOrgWithTheQueryAndScope` to `XCTAssertEqual(directory?.groupIds, [])`:

```swift
    func testDirectoryQuerySendsTrimmedSearchAndSortedLists() async {
        let path = "/api/organizations/org1/members?search=clark%20%20kent&groupIds=g1,g2&leaderIds=u1"
        api.stub("GET", path, json: directoryJSON)
        await actions().loadDirectory(orgId: "org1", search: "  clark  kent \n", groupIds: ["g2", "g1"], leaderIds: ["u1"])
        XCTAssertEqual(api.callCount("GET", path), 1)
        XCTAssertEqual(state.orgMembersByOrgId["org1"]?.search, "clark  kent")
        XCTAssertEqual(state.orgMembersByOrgId["org1"]?.groupIds, ["g1", "g2"])
        XCTAssertEqual(state.orgMembersByOrgId["org1"]?.leaderIds, ["u1"])
    }

    func testDirectoryQueryOmitsEmptyLists() async {
        api.stub("GET", "/api/organizations/org1/members", json: directoryJSON)
        await actions().loadDirectory(orgId: "org1", groupIds: [], leaderIds: [])
        XCTAssertEqual(api.callCount("GET", "/api/organizations/org1/members"), 1)
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile ("extra arguments 'groupIds'", "no member 'groupIds'")

- [ ] **Step 3: Write the minimal implementation**

`MemberModels.swift`:

```swift
struct OrgMemberDirectory: Equatable {
    var search: String = ""
    /// filter-multiselect D12: the query's group and leader picks, sorted.
    var groupIds: [String] = []
    var leaderIds: [String] = []
    var members: [OrgMemberListItem] = []
    var viewerScope: ViewerScope?
}
```

`MemberActions.swift`:

```swift
    /// D6/P12: one directory load — the server orders, filters and D7-scopes it. `search` is
    /// trimmed; filter-multiselect D12: the picks go as sorted comma lists (`groupIds`,
    /// `leaderIds` — never the single params); empty values are not sent.
    @MainActor
    func loadDirectory(orgId: String, search: String = "", groupIds: Set<String> = [], leaderIds: Set<String> = []) async {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let groups = groupIds.sorted()
        let leaders = leaderIds.sorted()
        let path = Self.path("/api/organizations/\(orgId)/members",
                             [("search", query),
                              ("groupIds", groups.joined(separator: ",")),
                              ("leaderIds", leaders.joined(separator: ","))])
        guard let response = await fetch("loadDirectory", path, OrgMembersResponse.self) else { return }
        state.orgMembersByOrgId[orgId] = OrgMemberDirectory(
            search: query, groupIds: groups, leaderIds: leaders,
            members: response.data, viewerScope: response.viewerScope
        )
    }
```

`MembersHomeContainer.swift` `load(_:actions:)` — the bridge until Task 5 makes the selection set-valued:

```swift
        await actions.loadDirectory(orgId: orgId, search: selection.search,
                                    groupIds: Set([selection.groupId].compactMap { $0 }),
                                    leaderIds: Set([selection.leaderId].compactMap { $0 }))
```

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS; `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations

- [ ] **Step 5: Commit** — `feat(filter-multiselect): Members directory sends groupIds and leaderIds`

### Task 5: Members — multi-select Groups and Leaders with Save, D4 chips, ids not labels
App: iphone
Phase: 3
Recipe: `/transition-review` (the screen's menu presentation is touched); SPEC §iphone Members, D2, D3, D4, D12, D15

**Files:**
- Modify: `iphone/MakeReadyUI/Screens/Members/MembersHomeScreen.swift` (State, closures, init, chips, `filterMenu`, sample data)
- Modify: `iphone/MakeReady/UI2/Containers/Members/MembersHomeMapper.swift`
- Modify: `iphone/MakeReady/UI2/Containers/Members/MembersHomeContainer.swift`
- Test: `iphone/MakeReadyCaptureTests/MembersHomeMapperTests.swift`, `iphone/MakeReadyCaptureTests/UI2MembersComponentTests.swift`
- Check only: `iphone/MakeReadyCaptureTests/ViewRegistry.swift:2496-2512` keeps compiling (every new State field is defaulted)

**Interfaces:**
- Consumes: Task 3's `FilterMenuOverlay(…, onSave:)` and `FilterMenuOverlay.chipLabel(picked:resting:noun:)`; Task 4's `loadDirectory(orgId:search:groupIds:leaderIds:)`.
- Produces: `MembersHomeScreen.State` gains `groupOptionIDs: [String] = []`, `leaderOptionIDs: [String] = []`, `selectedGroupIDs: Set<String> = []`, `selectedLeaderIDs: Set<String> = []`; `MembersHomeScreen(state:onSearch:onSaveGroups:onSaveLeaders:onOpenMember:onSearchActiveChange:)`; `static func menuChip(label: String, active: Bool, onTap: @escaping () -> Void) -> FilterChip`; `MembersHomeMapper.Selection { search, groupIds: Set<String>, leaderIds: Set<String> }`. Removed: `MembersHomeMapper.Pick`, `Output.groupPick` / `leaderPick`, `Output.groupOptionIds` / `leaderOptionIds`.

- [ ] **Step 1: Write the failing tests** — in `MembersHomeMapperTests.swift` replace `testAnOwnerSeesEveryGroupAndTheLeaderChip`, `testAScopedLeaderSeesOnlyTheirGroupsAndNoLeaderChip`, `testChipLabelsFollowTheSelection` and `testPicksResolveAgainstTheRenderedOptions` with:

```swift
    /// D7/D15 + filter-multiselect D3: no "All …" rows; ids ride beside the labels.
    func testAnOwnerSeesEveryGroupAndTheLeaderChip() {
        for scope in [ViewerScope(all: true, groupIds: []), nil] {
            let out = map(OrgMemberDirectory(viewerScope: scope))
            XCTAssertTrue(out.state.showsLeaderFilter)
            XCTAssertEqual(out.state.groupOptions, ["The kids", "Young professionals"])
            XCTAssertEqual(out.state.groupOptionIDs, ["g1", "g2"])
            XCTAssertEqual(out.state.leaderOptions, ["Luke Keith", "Scott Stickane"])
            XCTAssertEqual(out.state.leaderOptionIDs, ["u1", "u2"])
        }
    }

    func testAScopedLeaderSeesOnlyTheirGroupsAndNoLeaderChip() {
        let out = map(OrgMemberDirectory(viewerScope: ViewerScope(all: false, groupIds: ["g2"])))
        XCTAssertFalse(out.state.showsLeaderFilter)
        XCTAssertEqual(out.state.groupOptions, ["Young professionals"])
        XCTAssertEqual(out.state.groupOptionIDs, ["g2"])
    }

    /// filter-multiselect D4: 0 / 1 / many picks.
    func testChipLabelsFollowTheSelection() {
        var selection = MembersHomeMapper.Selection(search: "kent")
        var out = map(OrgMemberDirectory(), selection)
        XCTAssertEqual(out.state.searchText, "kent")
        XCTAssertEqual(out.state.groupFilterLabel, "All Groups")
        XCTAssertEqual(out.state.leaderFilterLabel, "All Leaders")
        XCTAssertEqual(out.state.selectedGroupIDs, [])
        selection.groupIds = ["g2"]
        selection.leaderIds = ["u1", "u2"]
        out = map(OrgMemberDirectory(), selection)
        XCTAssertEqual(out.state.groupFilterLabel, "Young professionals")
        XCTAssertEqual(out.state.leaderFilterLabel, "2 leaders")
        XCTAssertEqual(out.state.selectedGroupIDs, ["g2"])
        XCTAssertEqual(out.state.selectedLeaderIDs, ["u1", "u2"])
        selection.groupIds = ["g1", "g2", "gone"]
        out = map(OrgMemberDirectory(), selection)
        XCTAssertEqual(out.state.groupFilterLabel, "2 groups")              // an id no longer listed is not counted
        XCTAssertEqual(out.state.selectedGroupIDs, ["g1", "g2"])
    }

    /// filter-multiselect D15: two options with the same label stay two ids.
    func testSameNamedOptionsStayDistinct() {
        let twins = [MembersHomeMapper.Option(id: "u7", label: "Group Leader"),
                     MembersHomeMapper.Option(id: "u8", label: "Group Leader")]
        let out = MembersHomeMapper.output(directory: OrgMemberDirectory(), groups: groups, leaders: twins,
                                           selection: .init(leaderIds: ["u8"]), today: today, timeZone: tz)
        XCTAssertEqual(out.state.leaderOptionIDs, ["u7", "u8"])
        XCTAssertEqual(out.state.selectedLeaderIDs, ["u8"])
        XCTAssertEqual(out.state.leaderFilterLabel, "Group Leader")
    }
```

In `UI2MembersComponentTests.swift`, change the chip test's call to `MembersHomeScreen.menuChip(label: "All Groups", active: false) { tapped = true }.onTap()` and add:

```swift
    /// filter-multiselect D3: the sample menus carry no "All …" row.
    func testMembersHomeSampleHasNoAllRows() {
        let s = MembersHomeScreen.State.populated
        XCTAssertFalse(s.groupOptions.contains("All Groups"))
        XCTAssertFalse(s.leaderOptions.contains("All Leaders"))
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile (`groupOptionIDs`, `Selection.groupIds`, `menuChip(label:active:)` missing)

- [ ] **Step 3: Write the minimal implementation**

`MembersHomeScreen.swift` — State, after `leaderOptions` (update the two option docs to drop "\"All …\" +"):

```swift
        /// filter-multiselect D15: the id behind each `groupOptions` label, parallel; [] = the
        /// labels are the ids (previews, capture).
        var groupOptionIDs: [String] = []
        /// D15: the id behind each `leaderOptions` label, parallel; [] = the labels are the ids.
        var leaderOptionIDs: [String] = []
        /// filter-multiselect D1/D4: the checked Groups ids — C-036's seed; non-empty = active chip.
        var selectedGroupIDs: Set<String> = []
        /// D1/D4: the checked Leaders ids.
        var selectedLeaderIDs: Set<String> = []
```

Closures and init — replace `onSelectGroup` / `onSelectLeader` (property, init parameter, assignment) with:

```swift
    var onSaveGroups: (Set<String>) -> Void = { _ in }  // filter-multiselect D1: Save on the Groups menu
    var onSaveLeaders: (Set<String>) -> Void = { _ in } // D1: Save on the Leaders menu
```

`private enum FilterMenu` stays (it is already `Hashable`). Chips:

```swift
                Self.menuChip(label: state.groupFilterLabel, active: !state.selectedGroupIDs.isEmpty) { presentedMenu = .groups }
                .ui2Element("C-035 FilterChip")
                if state.showsLeaderFilter {                         // D7/D15
                    Self.menuChip(label: state.leaderFilterLabel, active: !state.selectedLeaderIDs.isEmpty) { presentedMenu = .leaders }
                    .ui2Element("C-035 FilterChip 2")
                }
```

```swift
    /// §3: "Tap a chip → FilterMenuOverlay (C-036) opens" — a `Menu` chip whose tap presents it;
    /// filter-multiselect D4: active while it has a pick.
    static func menuChip(label: String, active: Bool, onTap: @escaping () -> Void) -> FilterChip {
        FilterChip(type: .menu, active: active, label: label, onTap: onTap)
    }

    /// D15: the ids C-036 gets — the State's ids when they line up with the labels, else the labels.
    static func optionIDs(_ ids: [String], labels: [String]) -> [String] {
        ids.count == labels.count ? ids : labels
    }
```

`filterMenu` (replace the body and its doc's single-select sentences with "filter-multiselect D1/D2: multi-select with a draft; Save applies and closes, ✕ closes with no change"):

```swift
    @ViewBuilder private var filterMenu: some View {
        let leaders = presentedMenu == .leaders
        let labels = leaders ? state.leaderOptions : state.groupOptions
        let ids = Self.optionIDs(leaders ? state.leaderOptionIDs : state.groupOptionIDs, labels: labels)
        FilterMenuOverlay(
            options: zip(ids, labels).map { FilterMenuOverlay.Option(id: $0.0, label: $0.1) },
            selectionMode: .multiple,
            selectedIDs: leaders ? state.selectedLeaderIDs : state.selectedGroupIDs,
            onClose: { presentedMenu = nil },
            onSave: { picked in
                if leaders { onSaveLeaders(picked) } else { onSaveGroups(picked) }
                presentedMenu = nil
            }
        )
        // Groups and Leaders share this position: a new identity per menu, so a draft never
        // carries from one to the other.
        .id(presentedMenu)
        .ui2Element("C-036 FilterMenuOverlay")
    }
```

Sample data: `groupOptions: ["Young professionals"]`, `leaderOptions: []` (the labels "All Groups" / "All Leaders" stay as the chip labels).

`MembersHomeMapper.swift` — replace `Selection`, delete `Pick`, and reduce `Output` to `state` + `memberIds` + `memberId(atRow:)`:

```swift
    /// The container's query: search text and the two chip picks ([] = no filter, D3).
    struct Selection: Equatable {
        var search = ""
        var groupIds: Set<String> = []
        var leaderIds: Set<String> = []
    }

    /// T13: the State plus the member id behind every row it renders.
    struct Output {
        var state: MembersHomeScreen.State
        var memberIds: [String]

        func memberId(atRow row: Int) -> String? {
            memberIds.indices.contains(row) ? memberIds[row] : nil
        }
    }
```

In `output(…)`, build the State with:

```swift
        let pickedGroups = visibleGroups.filter { selection.groupIds.contains($0.id) }
        let pickedLeaders = leaders.filter { selection.leaderIds.contains($0.id) }
        let state = MembersHomeScreen.State(
            searchText: selection.search,
            groupFilterLabel: FilterMenuOverlay.chipLabel(picked: pickedGroups.map(\.label), resting: allGroups, noun: "groups"),
            leaderFilterLabel: FilterMenuOverlay.chipLabel(picked: pickedLeaders.map(\.label), resting: allLeaders, noun: "leaders"),
            groupOptions: visibleGroups.map(\.label),
            leaderOptions: leaders.map(\.label),
            groupOptionIDs: visibleGroups.map(\.id),
            leaderOptionIDs: leaders.map(\.id),
            selectedGroupIDs: Set(pickedGroups.map(\.id)),
            selectedLeaderIDs: Set(pickedLeaders.map(\.id)),
            showsLeaderFilter: seesAll,
            memberNames: members.map { displayName(first: $0.firstName, last: $0.lastName) },
            memberPhotoURLs: members.map { nonEmpty($0.profilePicture) ?? nonEmpty($0.googlePicture) ?? "" },
            memberInitials: members.map { initials(first: $0.firstName, last: $0.lastName) },
            memberJoinedLabels: members.map { joinedLabel($0.joinedAt, today: today, timeZone: timeZone) },
            memberGroupCounts: members.map(\.groupCount)
        )
        return Output(state: state, memberIds: members.map(\.id))
```

`MembersHomeContainer.swift` — replace `onSelectGroup` / `onSelectLeader` with:

```swift
            onSaveGroups: { ids in
                var next = selection
                next.groupIds = ids
                selection = next
                reload(next, after: nil)
            },
            onSaveLeaders: { ids in
                var next = selection
                next.leaderIds = ids
                selection = next
                reload(next, after: nil)
            },
```

and replace Task 4's bridge in `load(_:actions:)` with:

```swift
        await actions.loadDirectory(orgId: orgId, search: selection.search,
                                    groupIds: selection.groupIds, leaderIds: selection.leaderIds)
```

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS; `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations; `grep -rn "groupPick\|leaderPick\|onSelectGroup" iphone/MakeReady iphone/MakeReadyUI iphone/MakeReadyCaptureTests` → no hits

- [ ] **Step 5: Commit** — `feat(filter-multiselect): Members filters take several groups and leaders`

### Task 6: Invite picker — Leaders multi-select by `creatorId`
App: iphone
Phase: 4
Recipe: `/present-overlay` (the menu stays a `.filterMenuPresentation`); SPEC §iphone Invite picker, D4, D5, D13

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Groups/InviteSelectGroupMapper.swift`
- Modify: `iphone/MakeReady/UI2/Containers/Groups/InviteSelectGroupContainer.swift`
- Test: `iphone/MakeReadyCaptureTests/InviteSelectGroupMapperTests.swift`
- No change: `iphone/MakeReadyUI/Screens/Groups/EnrollmentSelectGroupScreen.swift` (takes a label; `active` already derives from `label != "Leaders"`)

**Interfaces:**
- Consumes: Task 3's `FilterMenuOverlay(…, onSave:)` and `FilterMenuOverlay.chipLabel(picked:resting:noun:)`.
- Produces: `InviteSelectGroupMapper.Input.leaderIds: Set<String>` (replaces `leader: String?`); `InviteSelectGroupMapper.LeaderOption { id: String; label: String }`; `Output.leaderOptions: [LeaderOption]`.

- [ ] **Step 1: Write the failing tests** — in `InviteSelectGroupMapperTests.swift`, change the `input` helper to `private func input(query: String = "", leaderIds: Set<String> = []) -> InviteSelectGroupMapper.Input { .init(groups: groups, enrollmentCounts: ["g2": 2], query: query, leaderIds: leaderIds, loading: false, failed: false) }`, and replace `testLeaderFilterNarrowsAndLabelsTheChip` and `testLeaderOptionsAreDistinctNonEmptyAndSorted` with:

```swift
    /// filter-multiselect D5/D13/D4: any of the picked creators; the chip summarises.
    func testLeaderFilterNarrowsByCreatorIdAndLabelsTheChip() {
        var out = InviteSelectGroupMapper.output(input(leaderIds: ["u-g1"]))
        XCTAssertEqual(out.groupIds, ["g1"])
        XCTAssertEqual(out.state.leaderFilterLabel, "Tony Stark")
        out = InviteSelectGroupMapper.output(input(leaderIds: ["u-g1", "u-g2"]))
        XCTAssertEqual(out.groupIds, ["g2", "g1"])
        XCTAssertEqual(out.state.leaderFilterLabel, "2 leaders")
    }

    /// D13: one option per creator id with a name — same-named creators stay two options.
    func testLeaderOptionsAreOnePerCreatorAndSorted() {
        let more = groups + [group("g4", "Alpha", leader: "Tony Stark", members: 1)]
        let out = InviteSelectGroupMapper.output(.init(groups: more, enrollmentCounts: [:], query: "", leaderIds: [], loading: false, failed: false))
        XCTAssertEqual(out.leaderOptions.map(\.label), ["Pepper Potts", "Tony Stark", "Tony Stark"])
        XCTAssertEqual(out.leaderOptions.map(\.id), ["u-g2", "u-g1", "u-g4"])
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile ("extra argument 'leaderIds'")

- [ ] **Step 3: Write the minimal implementation**

`InviteSelectGroupMapper.swift`:

```swift
    struct Input {
        var groups: [UserGroup]
        var enrollmentCounts: [String: Int]
        var query: String
        /// filter-multiselect D13: the picked creators' `User.id`s; [] = every group.
        var leaderIds: Set<String>
        var loading: Bool
        var failed: Bool
    }

    /// D13: one Leaders option — the creator's id and the name C-036 shows.
    struct LeaderOption: Equatable {
        let id: String
        let label: String
    }

    struct Output {
        var state: EnrollmentSelectGroupScreen.State
        var groupIds: [String]
        var leaderOptions: [LeaderOption]
    }
```

In `output(_:)`:

```swift
        let rows = input.groups
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            .filter { input.leaderIds.isEmpty || input.leaderIds.contains($0.creatorId) }   // D5: any of
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        var seen = Set<String>()
        let leaderOptions = input.groups
            .compactMap { g -> LeaderOption? in
                guard let name = g.creatorName, !name.isEmpty, seen.insert(g.creatorId).inserted else { return nil }
                return LeaderOption(id: g.creatorId, label: name)
            }
            .sorted {
                let byName = $0.label.localizedCaseInsensitiveCompare($1.label)
                return byName == .orderedSame ? $0.id < $1.id : byName == .orderedAscending
            }
        let picked = leaderOptions.filter { input.leaderIds.contains($0.id) }.map(\.label)
```

and in the State: `leaderFilterLabel: FilterMenuOverlay.chipLabel(picked: picked, resting: restingLeaderLabel, noun: "leaders"),`.

`InviteSelectGroupContainer.swift` — `@State private var leaderIds: Set<String> = []` replaces `leader`; pass `leaderIds: leaderIds` in the mapper input; the menu becomes:

```swift
            FilterMenuOverlay(
                options: output.leaderOptions.map { FilterMenuOverlay.Option(id: $0.id, label: $0.label) },
                selectionMode: .multiple,
                selectedIDs: leaderIds,
                onClose: { leaderMenuOpen = false },
                // filter-multiselect D1: picks are a draft; Save applies them and closes.
                onSave: { picked in
                    leaderIds = picked
                    leaderMenuOpen = false
                }
            )
```

Update the struct's doc line "the Leaders filter are local UI state" → "the Leaders filter (several creators, D13) is local UI state".

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS; `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations

- [ ] **Step 5: Commit** — `feat(filter-multiselect): invite picker Leaders filter takes several leaders`

### Task 7: Groups home — Orgs and Leaders menus multi-select
App: iphone
Phase: 4
Recipe: `/transition-review` (the screen's menu presentation is touched) · tiny; SPEC §iphone Groups home, D3, D4, D14

**Files:**
- Modify: `iphone/MakeReadyUI/Screens/Home/GroupsHomeScreen.swift` (State, closures, init, chips, `filterMenu`, sample data)
- Test: `iphone/MakeReadyCaptureTests/UI2MembersComponentTests.swift` (append)
- Check only: `iphone/MakeReadyCaptureTests/ViewRegistry.swift:2530-2545` keeps compiling (new State fields are defaulted)

**Interfaces:**
- Consumes: Task 3's `FilterMenuOverlay(…, onSave:)`.
- Produces: `GroupsHomeScreen.State.selectedOrgs: Set<String> = []`, `.selectedLeaders: Set<String> = []` (option ids are the labels — no container yet, D14); `GroupsHomeScreen(state:onSelectTab:onToggleNav:onAddGroup:onSearch:onSaveOrgs:onSaveLeaders:onOpenGroup:)`.

- [ ] **Step 1: Write the failing test** — append to `UI2MembersComponentTests.swift`:

```swift
/// filter-multiselect D3/D14: Groups home's menus carry no "All …" row and its State holds the picks.
final class GroupsHomeFilterTests: XCTestCase {
    func testSampleHasNoAllRowsAndEmptyPicks() {
        let s = GroupsHomeScreen.State.populated
        XCTAssertFalse(s.orgOptions.contains("All Orgs"))
        XCTAssertFalse(s.leaderOptions.contains("All Leaders"))
        XCTAssertEqual(s.selectedOrgs, [])
        XCTAssertEqual(s.selectedLeaders, [])
    }

    func testSaveClosuresAreSetValued() {
        var saved: Set<String>?
        let screen = GroupsHomeScreen(state: .populated, onSaveLeaders: { saved = $0 })
        screen.onSaveLeaders(["Tony"])
        XCTAssertEqual(saved, ["Tony"])
    }
}
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile ("no member 'selectedOrgs'", "extra argument 'onSaveLeaders'")

- [ ] **Step 3: Write the minimal implementation** in `GroupsHomeScreen.swift`:

State, after `leaderOptions` (drop "\"All Orgs\" +" / "\"All Leaders\" +" from the two option docs):

```swift
        /// filter-multiselect D14: the checked Orgs options (ids = labels until a container
        /// supplies ids); non-empty = the chip is active (D4).
        var selectedOrgs: Set<String> = []
        /// D14: the checked Leaders options.
        var selectedLeaders: Set<String> = []
```

Replace `onSelectOrg` / `onSelectLeader` (property, init parameter, assignment) with:

```swift
    var onSaveOrgs: (Set<String>) -> Void = { _ in }    // filter-multiselect D14: Save on the Orgs menu
    var onSaveLeaders: (Set<String>) -> Void = { _ in } // D14: Save on the Leaders menu
```

Chips: `FilterChip(type: .menu, active: !state.selectedOrgs.isEmpty, label: state.orgFilterLabel)` and `FilterChip(type: .menu, active: !state.selectedLeaders.isEmpty, label: state.leaderFilterLabel)` (update the `§4: both chips "type=Menu, active=false"` comment to "active while it has a pick — filter-multiselect D4").

`filterMenu`:

```swift
    @ViewBuilder private var filterMenu: some View {
        let orgs = presentedMenu == .orgs
        let options = orgs ? state.orgOptions : state.leaderOptions
        FilterMenuOverlay(
            options: options.map { FilterMenuOverlay.Option(id: $0, label: $0) },
            selectionMode: .multiple,
            selectedIDs: orgs ? state.selectedOrgs : state.selectedLeaders,
            onClose: { presentedMenu = nil },
            onSave: { picked in
                if orgs { onSaveOrgs(picked) } else { onSaveLeaders(picked) }
                presentedMenu = nil
            }
        )
        // Orgs and Leaders share this position: a new identity per menu, so a draft never carries over.
        .id(presentedMenu)
        .ui2Element("C-036 FilterMenuOverlay")
    }
```

(and its doc: "filter-multiselect D1/D2: multi-select with a draft; Save applies and closes, ✕ closes with no change"). Sample data: `orgOptions: []`, `leaderOptions: []` (the chip labels "All Orgs" / "All Leaders" stay).

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS; `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations; `grep -rn "onSelectOrg\|selectionMode: .single" iphone/MakeReady iphone/MakeReadyUI` → no hits

- [ ] **Step 5: Commit** — `feat(filter-multiselect): Groups home Orgs and Leaders menus are multi-select`
