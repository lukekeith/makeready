# ui2-members-edit — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Leaders edit a member's Email, Phone, Birthday, Gender, Address, Emergency contact and Emergency phone from the UI 2.0 member page, one field per pushed edit page, saved through an extended `PATCH /api/members/:memberId`.

**Architecture:** The server phase extends the member PATCH (strict schema, phone normalization + uniqueness 409 + verification/consent reset, birthday bounds, member-session phone guard in the service) and freezes the contract. The iPhone then gains live text editing and a date page in MakeReadyUI, a status-bearing PATCH and `MemberActions.updateMember` in State, and the `editMemberField` push with one `MemberFieldEditContainer` in the UI2 shell.

**Tech Stack:** server — Express, zod, Prisma, vitest · iphone — SwiftUI (MakeReadyUI views compiled into the app module), `@Observable` AppState + Actions, XCTest in `MakeReadyCaptureTests`.

**Spec:** `docs/features/ui2-members-edit/SPEC.md`

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. 🔴 You stage your commit and STOP — an iPhone commit is the human's to approve.
- Capture: fixtures are manifest-driven and twins additive-only; register a new twin in the component-capture map and check its BEM root for a collision with a legacy web component before naming it; restart the capture server after editing an adapter, and rebuild the client bundle before any web capture.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test or `/compare` diff, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(ui2-members-edit): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.


## Phases

| Phase | App | Tasks | Goal | Gates |
|---|---|---|---|---|
| 1 | server | 1–4 | PATCH accepts and validates all seven fields with D4–D12/D17–D19/D23 effects; sparse fixtures exist; contract frozen | `cd server && npx tsc --noEmit` · `cd server && npx tsc --noEmit -p fixtures` · `cd server && npm run test:run` |
| 2 | iphone | 5–7 | MakeReadyUI text pages accept live input with per-field options; member page reports a field key; the date page exists | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 3 | iphone | 8–9 | `MemberActions.updateMember` PATCHes one key with status-aware errors; field rules/page states/patches built and tested | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 4 | iphone | 10–11 | Row tap pushes the edit page, Save round-trips and pops; Emergency phone displays per D7 | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |

---

### Task 1: Member field helpers — phone normalization, contact-phone, birthday (member-fields.ts)
App: server
Phase: 1
Recipe: /api

Implements SPEC D4, D7, D9, D18, D19 and T2: pure normalization/validation helpers (no Prisma, no
Express) that the PATCH route (Task 3) and `updateMember` (Task 2) use, plus the shared E.164 regex
that `routes/verification.ts` now imports instead of keeping its own copy (SPEC §server, last bullet).
`verification.ts` behaviour must stay byte-for-byte identical (same regex, same message).

Manual curl against the docker server needs `docker restart makeready-server` after editing
`server/src` (the container does not hot-reload); vitest does NOT need it.

**Files:**
- Create: `server/src/services/member-fields.ts`
- Modify: `server/src/routes/verification.ts:1-10` (imports) and `:49-54` (`phoneNumberSchema`)
- Test: `server/src/services/__tests__/member-fields.test.ts`

**Interfaces:**
- Consumes: nothing.
- Produces (all exported from `server/src/services/member-fields.ts`, imported as `'../services/member-fields.js'` from routes and `'./member-fields.js'` from services):
  - `export const E164: RegExp` — exactly `/^\+[1-9]\d{1,14}$/`
  - `export function normalizePhone(raw: string): string | null` — D4 + D18; `null` = not storable
  - `export function isValidContactPhone(raw: string): boolean` — D7
  - `export function parseBirthday(raw: string): Date | null` — D19; the UTC calendar date at 00:00Z
  - `export function birthdayInRange(d: Date, now: Date): boolean` — D9; 1900-01-01 ≤ d ≤ UTC today + 1 day

- [ ] **Step 1: Record the verification baseline** — before touching anything, run
  `cd server && npx vitest run src/routes/__tests__/verification.test.ts` and note the pass/fail
  counts (this suite imports the whole app; whatever it reports now is the baseline Step 8 must match).

- [ ] **Step 2: Write the failing unit tests**

Create `server/src/services/__tests__/member-fields.test.ts`:

```ts
import { describe, expect, it } from 'vitest'
import { E164, birthdayInRange, isValidContactPhone, normalizePhone, parseBirthday } from '../member-fields.js'

describe('E164 (shared with routes/verification.ts)', () => {
  it('is the sign-in regex', () => {
    expect(E164.source).toBe('^\\+[1-9]\\d{1,14}$')
    expect(E164.test('+15550100001')).toBe(true)
    expect(E164.test('+05550100001')).toBe(false)
    expect(E164.test('15550100001')).toBe(false)
  })
})

describe('normalizePhone (D4, D18)', () => {
  it.each([
    ['5550109999', '+15550109999'], // 10 digits → +1
    ['(555) 010-9999', '+15550109999'], // punctuation stripped
    ['555.010.9999', '+15550109999'],
    [' 555 010 9999 ', '+15550109999'],
    ['15550109999', '+15550109999'], // D18: 11 digits starting 1 → +
    ['1-555-010-9999', '+15550109999'],
    ['+1 (555) 010-9999', '+15550109999'], // leading + kept
    ['+44 20 7946 0958', '+442079460958'],
    ['+15550100001', '+15550100001'], // already normalized
    ['0123456789', '+10123456789'], // NANP-invalid but E.164-valid: accepted (D18)
  ])('%j → %j', (raw, expected) => {
    expect(normalizePhone(raw)).toBe(expected)
  })

  it.each([
    [''],
    ['   '],
    ['12345'], // too short, no +
    ['25550109999'], // 11 digits not starting 1
    ['abc'],
    ['555-010-9999 x12'], // extensions are emergency-phone only (D7)
    ['+0123456789'], // E.164 first digit must be 1-9
    ['+1234567890123456'], // 16 digits
    ['+'],
  ])('%j → null', (raw) => {
    expect(normalizePhone(raw)).toBeNull()
  })
})

describe('isValidContactPhone (D7)', () => {
  it.each([
    ['555-1234'], // exactly 7 digits
    ['(555) 010-2000'],
    ['+1 555 010 2000'],
    ['+44 20 7946 0958'],
    ['555-010-2000 ext. 12'],
    ['555-010-2000 ext 12'],
    ['555 010 2000 x9'],
    ['5550102000X9'],
    ['  555-1234  '], // trimmed before the check
  ])('%j is valid', (raw) => {
    expect(isValidContactPhone(raw)).toBe(true)
  })

  it.each([
    [''],
    ['123456'], // 6 digits
    ['12345 x67'], // 5 digits before the extension
    ['call mom'],
    ['555-1234 ext'], // extension word without digits
    ['555-1234 ext. 12 ext. 3'],
    ['555#1234'],
  ])('%j is invalid', (raw) => {
    expect(isValidContactPhone(raw)).toBe(false)
  })
})

describe('parseBirthday (D9, D19)', () => {
  it.each([
    ['1990-05-01', '1990-05-01T00:00:00.000Z'],
    [' 1990-05-01 ', '1990-05-01T00:00:00.000Z'],
    ['1990-05-01T00:00:00Z', '1990-05-01T00:00:00.000Z'],
    ['1990-05-01T00:00:00.000Z', '1990-05-01T00:00:00.000Z'],
    ['1990-05-01T15:45:00Z', '1990-05-01T00:00:00.000Z'], // time dropped
    ['1990-05-01T23:30:00-05:00', '1990-05-02T00:00:00.000Z'], // its UTC calendar date
    ['1990-05-01T01:00:00+05:00', '1990-04-30T00:00:00.000Z'],
    ['1990-05-01T12:00:00', '1990-05-01T00:00:00.000Z'], // no offset = UTC (never server-local)
    ['2000-02-29', '2000-02-29T00:00:00.000Z'],
  ])('%j → %s', (raw, iso) => {
    expect(parseBirthday(raw)?.toISOString()).toBe(iso)
  })

  it.each([[''], ['not a date'], ['1990-13-01'], ['2026-02-30'], ['2001-02-29'], ['05/01/1990'], ['1990-5-1'], ['1990']])(
    '%j → null',
    (raw) => {
      expect(parseBirthday(raw)).toBeNull()
    }
  )
})

describe('birthdayInRange (D9)', () => {
  const now = new Date('2026-10-26T15:00:00Z')
  const at = (ymd: string) => new Date(`${ymd}T00:00:00Z`)

  it.each<[string, boolean]>([
    ['1899-12-31', false],
    ['1900-01-01', true],
    ['1990-05-01', true],
    ['2026-10-26', true], // UTC today
    ['2026-10-27', true], // UTC tomorrow (UTC+14 devices)
    ['2026-10-28', false],
  ])('%s → %s', (ymd, expected) => {
    expect(birthdayInRange(at(ymd), now)).toBe(expected)
  })

  it('uses the UTC day of now, not its time', () => {
    expect(birthdayInRange(at('2026-10-27'), new Date('2026-10-26T00:00:01Z'))).toBe(true)
    expect(birthdayInRange(at('2026-10-28'), new Date('2026-10-26T23:59:59Z'))).toBe(false)
  })
})
```

- [ ] **Step 3: Run it and watch it fail** — `cd server && npx vitest run src/services/__tests__/member-fields.test.ts` → FAIL, `Failed to load url ../member-fields.js` / "Cannot find module".

- [ ] **Step 4: Write the implementation**

Create `server/src/services/member-fields.ts`:

```ts
/**
 * ui2-members-edit D4, D7, D9, D18, D19: normalization and validation of the member fields
 * PATCH /api/members/:memberId writes. Pure functions — no Prisma, no Express.
 */

/** E.164 — the only shape a Member.phoneNumber may hold; SMS sign-in accepts nothing else. */
export const E164 = /^\+[1-9]\d{1,14}$/

/**
 * D4 + D18: strip spaces, `-`, `.`, `(`, `)`; exactly 10 digits → `+1` + digits; exactly 11 digits
 * starting `1` → `+` + digits; a leading `+` is kept. The result must match E164, else null.
 */
export function normalizePhone(raw: string): string | null {
  const stripped = raw.replace(/[\s\-.()]/g, '')
  let candidate = stripped
  if (/^\d{10}$/.test(stripped)) candidate = `+1${stripped}`
  else if (/^1\d{10}$/.test(stripped)) candidate = `+${stripped}`
  return E164.test(candidate) ? candidate : null
}

/** D7: digits and phone punctuation, an optional `ext`/`ext.`/`x` extension, ≥ 7 digits before it. */
const CONTACT_PHONE = /^[\d\s().+-]+(?:\s*(?:ext\.?|x)\s*\d+)?$/i
const CONTACT_EXTENSION = /\s*(?:ext\.?|x)\s*\d+$/i

export function isValidContactPhone(raw: string): boolean {
  const value = raw.trim()
  if (!CONTACT_PHONE.test(value)) return false
  const main = value.replace(CONTACT_EXTENSION, '')
  return (main.match(/\d/g) ?? []).length >= 7
}

const DATE_ONLY = /^\d{4}-\d{2}-\d{2}$/
const ISO_DATE_TIME = /^(\d{4}-\d{2}-\d{2})T\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(Z|[+-]\d{2}:?\d{2})?$/

/**
 * D19: `YYYY-MM-DD` or an ISO date-time; returns its UTC calendar date at 00:00Z (time and offset
 * dropped after converting to UTC). An ISO string without an offset is read as UTC, never as the
 * server's local time. Anything else — including impossible dates like 2026-02-30 — is null.
 */
export function parseBirthday(raw: string): Date | null {
  const value = raw.trim()
  let utcDay: string
  if (DATE_ONLY.test(value)) {
    utcDay = value
  } else {
    const match = ISO_DATE_TIME.exec(value)
    if (!match) return null
    const instant = new Date(match[2] ? value : `${value}Z`)
    if (Number.isNaN(instant.getTime())) return null
    // The written date must exist (rejects 2026-02-30T…, which Date would roll forward).
    const written = new Date(`${match[1]}T00:00:00Z`)
    if (Number.isNaN(written.getTime()) || written.toISOString().slice(0, 10) !== match[1]) return null
    utcDay = instant.toISOString().slice(0, 10)
  }
  const date = new Date(`${utcDay}T00:00:00Z`)
  if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== utcDay) return null
  return date
}

const MIN_BIRTHDAY_MS = Date.UTC(1900, 0, 1)
const DAY_MS = 86_400_000

/** D9: 1900-01-01 ≤ d ≤ (UTC today + 1 day), so UTC tomorrow is accepted for UTC+14 devices. */
export function birthdayInRange(d: Date, now: Date): boolean {
  const todayUtcMs = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())
  const t = d.getTime()
  return t >= MIN_BIRTHDAY_MS && t <= todayUtcMs + DAY_MS
}
```

- [ ] **Step 5: Run it and watch it pass** — `cd server && npx vitest run src/services/__tests__/member-fields.test.ts` → PASS (all cases).

- [ ] **Step 6: Point `routes/verification.ts` at the shared regex**

In `server/src/routes/verification.ts`, add to the imports (after `import { ActivityTypes } from '../lib/activity-types.js';`):

```ts
import { E164 } from '../services/member-fields.js';
```

and replace the schema at lines ~49-54:

```ts
/**
 * Phone number validation schema (E.164 format)
 */
const phoneNumberSchema = z.string().regex(/^\+[1-9]\d{1,14}$/, {
  message: 'Phone number must be in E.164 format (e.g., +1234567890)',
});
```

with:

```ts
/**
 * Phone number validation schema (E.164 format) — the regex is shared with the member PATCH
 * (services/member-fields.ts, ui2-members-edit D4).
 */
const phoneNumberSchema = z.string().regex(E164, {
  message: 'Phone number must be in E.164 format (e.g., +1234567890)',
});
```

Leave the OpenAPI comments (which spell the pattern as text) unchanged.

- [ ] **Step 7: Typecheck** — `cd server && npx tsc --noEmit` → exit 0.

- [ ] **Step 8: Re-run verification and the new tests** — `cd server && npx vitest run src/routes/__tests__/verification.test.ts src/services/__tests__/member-fields.test.ts` → member-fields PASS; verification identical to the Step 1 baseline.

- [ ] **Step 9: Commit** — `git add server/src/services/member-fields.ts server/src/services/__tests__/member-fields.test.ts server/src/routes/verification.ts && git commit -m "feat(ui2-members-edit): member field helpers — phone normalization, contact phone, birthday"`

### Task 2: updateMember — phone change effects, member-session guard, 409 PHONE_TAKEN
App: server
Phase: 1
Recipe: /api

Implements SPEC SC2, SC3, SC4, D5, D12, D17, D23 and T3 in the service layer
(`server/src/services/member.ts`). The route (Task 3) normalizes and validates; this service still
normalizes `phoneNumber` itself so it is safe for any caller, compares against the stored number, and
owns the member-session phone guard (house rule: authorization-shaped checks live in services).

Behaviour, exactly:
- `data.phoneNumber === undefined` → no extra read; update as today.
- `data.phoneNumber !== undefined` → `normalizePhone(data.phoneNumber)`; `null` → `{ success:false, error:'Enter a valid phone number', status:400 }` (no write). Load the current row's `phoneNumber` (`prisma.member.findUnique({ where:{id}, select:{ phoneNumber:true } })`); no row → `{ success:false, error:'Member not found', status:404 }`.
  - normalized === stored → drop `phoneNumber` from the update (no verification/consent change).
  - different and `viewerKind === 'self'` → `{ success:false, error:'Phone changes go through sign-in', status:403 }` (no write).
  - different otherwise → write the normalized number plus `phoneVerified:false`, `lastVerifiedAt:null`, `smsConsent:false`, `smsConsentAt:new Date()` (these override any `smsConsent` in the same request — D17).
- Any Prisma `P2002` thrown by the update → `{ success:false, error:'That number belongs to another member', code:'PHONE_TAKEN', status:409 }`. Detect by `error.code === 'P2002'` (duck-typed: tests mock `Prisma` as `{}`, so `instanceof Prisma.PrismaClientKnownRequestError` cannot be used, and `meta.target` naming varies by Prisma version).
- Anything else → unchanged `{ success:false, error:'Failed to update member' }` (no `status` → the route answers 500).

`MemberResult` gains optional `status?: number; code?: string`; every other `MemberResult` producer and
consumer (`getMember`, `getMemberByPhone`, `createMember`, `verifyMemberPhone`, `deleteMember`, the
other `updateMember` callers in `routes/members.ts:739,1443,1568`) keeps compiling unchanged because
both fields are optional and the new parameter defaults to `'user'`.

Manual curl against the docker server needs `docker restart makeready-server` after editing
`server/src`; vitest does NOT need it.

**Files:**
- Modify: `server/src/services/member.ts:1-14` (imports, `MemberResult`), `:60-71` (`UpdateMemberData`), `:247-276` (`updateMember`)
- Test: `server/src/services/__tests__/member-update.test.ts`

**Interfaces:**
- Consumes (Task 1, `server/src/services/member-fields.ts`): `normalizePhone(raw: string): string | null`.
- Produces (`server/src/services/member.ts`):
  - `export interface MemberResult { success: boolean; data?: Member; error?: string; status?: number; code?: string }`
  - `export type MemberUpdateViewerKind = 'self' | 'user'`
  - `export interface UpdateMemberData { firstName?: string; lastName?: string; email?: string | null; phoneNumber?: string; gender?: string | null; birthday?: Date | null; address?: string | null; emergencyContactName?: string | null; emergencyContactPhone?: string | null; profilePicture?: string | null; phoneVerified?: boolean; lastVerifiedAt?: Date | null; smsConsent?: boolean; smsConsentAt?: Date | null }`
  - `export async function updateMember(memberId: string, data: UpdateMemberData, viewerKind: MemberUpdateViewerKind = 'user'): Promise<MemberResult>`

- [ ] **Step 1: Write the failing service tests**

Create `server/src/services/__tests__/member-update.test.ts` (same mocking style as `member-scope.test.ts`):

```ts
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  member: { findUnique: vi.fn(), update: vi.fn() },
}))
const permissionMock = vi.hoisted(() => ({ isSuperAdmin: vi.fn() }))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../permission.js', () => permissionMock)

import { updateMember } from '../member.js'

const STORED_PHONE = '+15550100001'
const UPDATED = { id: 'm1', firstName: 'James', phoneNumber: STORED_PHONE }
const p2002 = () =>
  Object.assign(new Error('Unique constraint failed on the fields: (`phone_number`)'), {
    code: 'P2002',
    meta: { target: ['phone_number'] },
  })

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.member.findUnique.mockResolvedValue({ phoneNumber: STORED_PHONE })
  prismaMock.member.update.mockResolvedValue(UPDATED)
})

const written = () => prismaMock.member.update.mock.calls[0][0]

describe('updateMember without a phone (unchanged behaviour)', () => {
  it('writes the keys as given and never reads the stored phone', async () => {
    const res = await updateMember('m1', { firstName: 'X', address: null, emergencyContactName: null })
    expect(res).toEqual({ success: true, data: UPDATED })
    expect(prismaMock.member.findUnique).not.toHaveBeenCalled()
    expect(written()).toEqual({
      where: { id: 'm1' },
      data: { firstName: 'X', address: null, emergencyContactName: null, updatedAt: expect.any(Date) },
    })
  })

  it('returns the generic failure (no status) on any non-P2002 error', async () => {
    prismaMock.member.update.mockRejectedValue(new Error('connection lost'))
    expect(await updateMember('m1', { firstName: 'X' })).toEqual({ success: false, error: 'Failed to update member' })
  })
})

describe('updateMember with a changed phone (D5, D17)', () => {
  it('writes the normalized number and resets verification and consent', async () => {
    const res = await updateMember('m1', { phoneNumber: '(555) 010-9999' })
    expect(res.success).toBe(true)
    expect(prismaMock.member.findUnique).toHaveBeenCalledWith({ where: { id: 'm1' }, select: { phoneNumber: true } })
    expect(written()).toEqual({
      where: { id: 'm1' },
      data: {
        phoneNumber: '+15550109999',
        phoneVerified: false,
        lastVerifiedAt: null,
        smsConsent: false,
        smsConsentAt: expect.any(Date),
        updatedAt: expect.any(Date),
      },
    })
  })

  it('overrides an smsConsent:true sent in the same request (D17)', async () => {
    await updateMember('m1', { phoneNumber: '+15550109999', smsConsent: true, smsConsentAt: null })
    expect(written().data).toMatchObject({ smsConsent: false, smsConsentAt: expect.any(Date) })
  })

  it('lets a user viewer (the default) change it', async () => {
    expect((await updateMember('m1', { phoneNumber: '+15550109999' }, 'user')).success).toBe(true)
    expect(prismaMock.member.update).toHaveBeenCalledTimes(1)
  })

  it('maps a P2002 to 409 PHONE_TAKEN', async () => {
    prismaMock.member.update.mockRejectedValue(p2002())
    expect(await updateMember('m1', { phoneNumber: '+15550100002' })).toEqual({
      success: false,
      error: 'That number belongs to another member',
      code: 'PHONE_TAKEN',
      status: 409,
    })
  })

  it('maps a P2002 without meta.target to 409 too (Prisma-version independent)', async () => {
    prismaMock.member.update.mockRejectedValue(Object.assign(new Error('unique'), { code: 'P2002' }))
    expect((await updateMember('m1', { phoneNumber: '+15550100002' })).status).toBe(409)
  })
})

describe('updateMember with the same phone in another format (D5, D23)', () => {
  it.each([['+15550100001'], ['(555) 010-0001'], ['1-555-010-0001'], ['5550100001']])(
    '%j drops the key and changes nothing about verification',
    async (raw) => {
      const res = await updateMember('m1', { phoneNumber: raw, firstName: 'X' }, 'self')
      expect(res.success).toBe(true)
      expect(written().data).toEqual({ firstName: 'X', updatedAt: expect.any(Date) })
    }
  )
})

describe('updateMember member-session phone guard (D12, D23)', () => {
  it('403s a member session changing its own number and writes nothing', async () => {
    expect(await updateMember('m1', { phoneNumber: '+15550109999' }, 'self')).toEqual({
      success: false,
      error: 'Phone changes go through sign-in',
      status: 403,
    })
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })

  it('lets a member session save its unchanged number', async () => {
    expect((await updateMember('m1', { phoneNumber: STORED_PHONE }, 'self')).success).toBe(true)
  })
})

describe('updateMember phone edge cases', () => {
  it('400s an unnormalizable number without a read or a write', async () => {
    expect(await updateMember('m1', { phoneNumber: '12345' })).toEqual({
      success: false,
      error: 'Enter a valid phone number',
      status: 400,
    })
    expect(prismaMock.member.findUnique).not.toHaveBeenCalled()
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })

  it('404s when the member row is gone', async () => {
    prismaMock.member.findUnique.mockResolvedValue(null)
    expect(await updateMember('m1', { phoneNumber: '+15550109999' })).toEqual({
      success: false,
      error: 'Member not found',
      status: 404,
    })
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run src/services/__tests__/member-update.test.ts` → FAIL (e.g. "changed phone" case: `data` lacks `phoneVerified`; guard case: expected 403 result, got success; P2002 case: got `error: 'Failed to update member'` with no `code`).

- [ ] **Step 3: Write the implementation**

In `server/src/services/member.ts`:

(a) add the import after `import { type MemberViewer, visibleMemberOrgIds } from './member-access.js'`:

```ts
import { normalizePhone } from './member-fields.js'
```

(b) replace `MemberResult`:

```ts
export interface MemberResult {
  success: boolean
  data?: Member
  error?: string
  /** ui2-members-edit SC3/D12: an HTTP status the route should answer with (absent → 500). */
  status?: number
  /** ui2-members-edit D5: a machine-readable error code, e.g. 'PHONE_TAKEN'. */
  code?: string
}
```

(c) replace `UpdateMemberData` (SC4):

```ts
export interface UpdateMemberData {
  firstName?: string
  lastName?: string
  email?: string | null
  phoneNumber?: string
  gender?: string | null
  birthday?: Date | null
  address?: string | null
  emergencyContactName?: string | null
  emergencyContactPhone?: string | null
  profilePicture?: string | null
  phoneVerified?: boolean
  lastVerifiedAt?: Date | null
  smsConsent?: boolean
  smsConsentAt?: Date | null
}

/** ui2-members-edit D12: who is calling updateMember — the member's own session, or a user. */
export type MemberUpdateViewerKind = 'self' | 'user'
```

(d) replace the whole `updateMember` function (doc comment included):

```ts
/** A Prisma unique-constraint violation; phoneNumber is the only writable unique key here (SC3). */
function isUniqueViolation(error: unknown): boolean {
  return typeof error === 'object' && error !== null && (error as { code?: unknown }).code === 'P2002'
}

/**
 * Update member profile
 * ui2-members-edit D5/D17: a changed (normalized) phone resets phoneVerified, lastVerifiedAt and SMS
 * consent; the same number in another format is dropped. D12/D23: a member session may not change
 * its own number. SC3: a unique violation is 409 PHONE_TAKEN.
 * @param memberId - Member ID
 * @param data - Update data
 * @param viewerKind - 'self' for the member's own session, 'user' otherwise (default)
 * @returns Updated member or error (status/code set when the route should not answer 500)
 */
export async function updateMember(
  memberId: string,
  data: UpdateMemberData,
  viewerKind: MemberUpdateViewerKind = 'user'
): Promise<MemberResult> {
  try {
    const update: UpdateMemberData = { ...data }

    if (data.phoneNumber !== undefined) {
      const next = normalizePhone(data.phoneNumber)
      if (!next) return { success: false, error: 'Enter a valid phone number', status: 400 }

      const current = await prisma.member.findUnique({
        where: { id: memberId },
        select: { phoneNumber: true },
      })
      if (!current) return { success: false, error: 'Member not found', status: 404 }

      if (next === current.phoneNumber) {
        delete update.phoneNumber
      } else {
        if (viewerKind === 'self') {
          return { success: false, error: 'Phone changes go through sign-in', status: 403 }
        }
        Object.assign(update, {
          phoneNumber: next,
          phoneVerified: false,
          lastVerifiedAt: null,
          smsConsent: false,
          smsConsentAt: new Date(),
        })
      }
    }

    const member = await prisma.member.update({
      where: { id: memberId },
      data: {
        ...update,
        updatedAt: new Date(),
      },
    })

    return {
      success: true,
      data: member,
    }
  } catch (error) {
    if (isUniqueViolation(error)) {
      return {
        success: false,
        error: 'That number belongs to another member',
        code: 'PHONE_TAKEN',
        status: 409,
      }
    }
    console.error('Error updating member:', error)
    return {
      success: false,
      error: 'Failed to update member',
    }
  }
}
```

- [ ] **Step 4: Run it and watch it pass** — `cd server && npx vitest run src/services/__tests__/member-update.test.ts src/services/__tests__/member-scope.test.ts` → PASS (both files).

- [ ] **Step 5: Typecheck** — `cd server && npx tsc --noEmit` → exit 0 (the other `updateMember` callers in `routes/members.ts` compile unchanged).

- [ ] **Step 6: Commit** — `git add server/src/services/member.ts server/src/services/__tests__/member-update.test.ts && git commit -m "feat(ui2-members-edit): updateMember resets verification on a phone change, guards member sessions, 409 PHONE_TAKEN"`

### Task 3: PATCH /api/members/:memberId — strict schema, new keys, viewer kind, status mapping
App: server
Phase: 1
Recipe: /api

Implements SPEC SC1, T1, T4, §Contract row 1, D4, D7, D8, D9, D11, D19, F3 in
`server/src/routes/members.ts`. The route stays thin: zod does trim / `""`→`null` / normalization /
bounds, then it calls `updateMember(memberId, data, viewerKind)` and maps `result.status`.

Request rules (`.strict()` — an unknown key is a 400 "Unrecognized key(s) in object: '…'"):
- `firstName`, `lastName` (`z.string().optional()`), `profilePicture` (`url` nullable optional), `smsConsent` (boolean optional) — unchanged.
- `email` — trim, `""` → `null`, then `z.string().email('Enter a valid email').nullable().optional()`.
- `phoneNumber` — string; normalized with `normalizePhone` (which strips whitespace, so `""`/`"   "` → null); null → 400 "Enter a valid phone number"; a non-string (incl. `null`) → the same message.
- `address`, `emergencyContactName` — trim, `""` → `null`, string nullable optional.
- `emergencyContactPhone` — trim, `""` → `null`; non-null must pass `isValidContactPhone`, else "Enter a valid phone number". Stored as typed (trimmed).
- `birthday` — trim, `""` → `null`; a string → `parseBirthday` then `birthdayInRange(date, new Date())`, either failing → "Birthday must be between 1900 and today"; output is a `Date` at 00:00Z or `null`.
- `gender` — `""` → `null`, `z.enum(['male','female']).nullable().optional()`.

Response mapping: `!result.success` → `res.status(result.status ?? 500).json({ success:false, error: result.error, ...(result.code && { code: result.code }) })`.

Manual curl against the docker server needs `docker restart makeready-server` after editing
`server/src` (and a non-bot `User-Agent`); vitest does NOT need it.

**Files:**
- Modify: `server/src/routes/members.ts:5-14` (imports), `:1201-1209` (`updateMemberSchema`), `:1211-1255` (`router.patch('/:memberId'` handler body)
- Test: `server/src/routes/__tests__/members-edit.request.test.ts` (new; same harness as `members-scope.request.test.ts`)

**Interfaces:**
- Consumes (Task 1, `server/src/services/member-fields.ts`): `normalizePhone(raw: string): string | null`, `isValidContactPhone(raw: string): boolean`, `parseBirthday(raw: string): Date | null`, `birthdayInRange(d: Date, now: Date): boolean`.
- Consumes (Task 2, `server/src/services/member.ts`): `updateMember(memberId: string, data: UpdateMemberData, viewerKind: 'self' | 'user' = 'user'): Promise<MemberResult>` where `MemberResult` has optional `status?: number; code?: string`; `type UpdateMemberData`.
- Consumes (existing, `routes/members.ts:63`): `viewerOf(req, memberId): MemberViewer | null` (`{ kind: 'self' }` | `{ kind: 'user', userId }`).
- Produces: the wire contract `PATCH /api/members/:memberId` per SPEC §Contract (consumed by the iPhone in a later phase): 200 `{success:true,data:Member}`; 400 `{success:false,error}` with messages "Enter a valid phone number" / "Enter a valid email" / "Birthday must be between 1900 and today"; 403 `{success:false,error:'Phone changes go through sign-in'}`; 404 `{success:false,error:'Member not found'}`; 409 `{success:false,error:'That number belongs to another member',code:'PHONE_TAKEN'}`; 500 `{success:false,error:'Failed to update member'}`.

- [ ] **Step 1: Write the failing request tests**

Create `server/src/routes/__tests__/members-edit.request.test.ts`:

```ts
import express from 'express'
import request from 'supertest'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/twilio.js', () => ({ sendVerificationCode: vi.fn(), verifyCode: vi.fn() }))
vi.mock('../../services/storage.js', () => ({ uploadMemberAvatar: vi.fn(), deleteMemberAvatar: vi.fn() }))
vi.mock('../../middleware/auth.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../middleware/auth.js')>()),
  // 401/403 stay the middleware's (unchanged); these tests are about the body and the service call.
  requireMemberOrOrgOwner: (_req: unknown, _res: unknown, next: () => void) => next(),
}))
vi.mock('../../services/member-access.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/member-access.js')>()),
  canViewMember: vi.fn(),
}))
vi.mock('../../services/member.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/member.js')>()),
  updateMember: vi.fn(),
}))

import { updateMember } from '../../services/member.js'
import { canViewMember } from '../../services/member-access.js'
import membersRoutes from '../members.js'

function appAs(who: { userId?: string; memberId?: string }) {
  const app = express()
  app.use(express.json())
  app.use((req, _res, next) => {
    Object.assign(req, { session: { memberId: who.memberId } })
    if (who.userId) Object.assign(req, { user: { id: who.userId, isActive: true }, apiKeyId: 'test-key' })
    next()
  })
  app.use('/api/members', membersRoutes)
  return app
}

const LEADER = { userId: 'gl' }
const SELF = { memberId: 'm1' }
const DATA = { id: 'm1', firstName: 'James', phoneNumber: '+15550100001' }
const PHONE_MESSAGE = 'Enter a valid phone number'
const BIRTHDAY_MESSAGE = 'Birthday must be between 1900 and today'

const patch = (body: unknown, who: { userId?: string; memberId?: string } = LEADER) =>
  request(appAs(who)).patch('/api/members/m1').send(body as object)
/** The (data, viewerKind) the route handed to updateMember. */
const sent = () => {
  const [memberId, data, viewerKind] = vi.mocked(updateMember).mock.calls[0]
  expect(memberId).toBe('m1')
  return { data, viewerKind }
}
const expect400 = async (body: unknown, message: string) => {
  const res = await patch(body)
  expect(res.status).toBe(400)
  expect(res.body).toEqual({ success: false, error: message })
  expect(updateMember).not.toHaveBeenCalled()
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.useFakeTimers({ toFake: ['Date'] })
  vi.setSystemTime(new Date('2026-10-26T15:00:00Z'))
  vi.mocked(canViewMember).mockResolvedValue(true)
  vi.mocked(updateMember).mockResolvedValue({ success: true, data: DATA as never })
})

afterEach(() => {
  vi.useRealTimers()
})

describe('PATCH /api/members/:memberId — today’s web bodies still save (F3)', () => {
  it('admin profile.ui.ts name edit', async () => {
    const res = await patch({ firstName: 'Ann', lastName: 'Lee' })
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ success: true, data: DATA })
    expect(sent()).toEqual({ data: { firstName: 'Ann', lastName: 'Lee' }, viewerKind: 'user' })
  })

  it('admin profile.ui.ts consent toggle', async () => {
    const res = await patch({ smsConsent: true })
    expect(res.status).toBe(200)
    expect(sent().data).toEqual({ smsConsent: true, smsConsentAt: expect.any(Date) })
  })

  it('member /profile form (ProfileController.php), from the member’s own session', async () => {
    const res = await patch({ firstName: 'Ann', lastName: 'Lee', gender: null, birthday: '1990-05-01' }, SELF)
    expect(res.status).toBe(200)
    expect(canViewMember).not.toHaveBeenCalled()
    expect(sent()).toEqual({
      data: { firstName: 'Ann', lastName: 'Lee', gender: null, birthday: new Date('1990-05-01T00:00:00.000Z') },
      viewerKind: 'self',
    })
  })
})

describe('.strict() (SC1)', () => {
  it('400s an unknown key and never calls the service', async () => {
    const res = await patch({ firstName: 'Ann', nickname: 'A' })
    expect(res.status).toBe(400)
    expect(res.body.success).toBe(false)
    expect(res.body.error).toContain('nickname')
    expect(updateMember).not.toHaveBeenCalled()
  })

  it('400s server-written keys sent by a client', async () => {
    expect((await patch({ phoneVerified: true })).status).toBe(400)
    expect((await patch({ lastVerifiedAt: null })).status).toBe(400)
    expect(updateMember).not.toHaveBeenCalled()
  })
})

describe('phoneNumber (D4, D18)', () => {
  it.each([
    ['5550109999', '+15550109999'],
    ['(555) 010-9999', '+15550109999'],
    ['15550109999', '+15550109999'],
    ['1-555-010-9999', '+15550109999'],
    ['+44 20 7946 0958', '+442079460958'],
    [' +15550109999 ', '+15550109999'],
  ])('%j is sent normalized as %j', async (raw, normalized) => {
    expect((await patch({ phoneNumber: raw })).status).toBe(200)
    expect(sent().data).toEqual({ phoneNumber: normalized })
  })

  it.each([[''], ['   '], ['12345'], ['abc'], ['+0123456789'], ['555-010-9999 x12'], [null], [5550109999]])(
    '%j → 400',
    async (raw) => {
      await expect400({ phoneNumber: raw }, PHONE_MESSAGE)
    }
  )
})

describe('emergencyContactPhone (D7)', () => {
  it.each([['555-1234'], ['(555) 010-2000 ext. 12'], ['+44 20 7946 0958'], ['555 010 2000 x9']])(
    '%j saves as typed',
    async (raw) => {
      expect((await patch({ emergencyContactPhone: raw })).status).toBe(200)
      expect(sent().data).toEqual({ emergencyContactPhone: raw })
    }
  )

  it('trims before storing', async () => {
    await patch({ emergencyContactPhone: '  555-1234  ' })
    expect(sent().data).toEqual({ emergencyContactPhone: '555-1234' })
  })

  it.each([['123456'], ['call mom'], ['555-1234 ext'], ['12345 x67']])('%j → 400', async (raw) => {
    await expect400({ emergencyContactPhone: raw }, PHONE_MESSAGE)
  })
})

describe('birthday (D9, D19) — today is 2026-10-26 UTC', () => {
  it.each([
    ['1900-01-01', '1900-01-01T00:00:00.000Z'],
    ['2026-10-26', '2026-10-26T00:00:00.000Z'], // today
    ['2026-10-27', '2026-10-27T00:00:00.000Z'], // UTC tomorrow (UTC+14)
    ['1990-05-01T23:30:00-05:00', '1990-05-02T00:00:00.000Z'], // its UTC date, at 00:00Z
    ['1990-01-01T00:00:00Z', '1990-01-01T00:00:00.000Z'],
  ])('%j is stored as %s', async (raw, iso) => {
    expect((await patch({ birthday: raw })).status).toBe(200)
    expect((sent().data.birthday as Date).toISOString()).toBe(iso)
  })

  it.each([['1899-12-31'], ['2026-10-28'], ['not a date'], ['2026-02-30'], ['05/01/1990']])('%j → 400', async (raw) => {
    await expect400({ birthday: raw }, BIRTHDAY_MESSAGE)
  })

  it('null clears', async () => {
    expect((await patch({ birthday: null })).status).toBe(200)
    expect(sent().data).toEqual({ birthday: null })
  })
})

describe('email (D11)', () => {
  it('trims before the email check', async () => {
    expect((await patch({ email: ' a@b.com ' })).status).toBe(200)
    expect(sent().data).toEqual({ email: 'a@b.com' })
  })

  it('null clears', async () => {
    expect((await patch({ email: null })).status).toBe(200)
    expect(sent().data).toEqual({ email: null })
  })

  it('an invalid address → 400', async () => {
    await expect400({ email: 'not-an-email' }, 'Enter a valid email')
  })
})

describe('gender (D10)', () => {
  it.each([['male'], ['female'], [null]])('%j saves', async (gender) => {
    expect((await patch({ gender })).status).toBe(200)
    expect(sent().data).toEqual({ gender })
  })

  it('any other value → 400', async () => {
    expect((await patch({ gender: 'other' })).status).toBe(400)
    expect(updateMember).not.toHaveBeenCalled()
  })
})

describe('address and emergencyContactName', () => {
  it('trims and saves', async () => {
    await patch({ address: '  12 Main St\nChicago, IL 60614  ', emergencyContactName: ' Sophia Carter ' })
    expect(sent().data).toEqual({ address: '12 Main St\nChicago, IL 60614', emergencyContactName: 'Sophia Carter' })
  })

  it('null clears', async () => {
    await patch({ address: null, emergencyContactName: null })
    expect(sent().data).toEqual({ address: null, emergencyContactName: null })
  })
})

describe('"" on each clearable key saves null (D8, D11)', () => {
  it.each([['email'], ['birthday'], ['gender'], ['address'], ['emergencyContactName'], ['emergencyContactPhone']])(
    '%s',
    async (key) => {
      expect((await patch({ [key]: '' })).status).toBe(200)
      expect(sent().data).toEqual({ [key]: null })
    }
  )

  it('whitespace-only counts as empty', async () => {
    await patch({ address: '   ', emergencyContactPhone: ' ' })
    expect(sent().data).toEqual({ address: null, emergencyContactPhone: null })
  })
})

describe('viewer kind and result mapping (D5, D12, SC3)', () => {
  it('passes "self" for the member’s own session and "user" for a leader', async () => {
    await patch({ phoneNumber: '+15550109999' }, SELF)
    expect(sent().viewerKind).toBe('self')
    vi.mocked(updateMember).mockClear()
    await patch({ phoneNumber: '+15550109999' }, LEADER)
    expect(sent().viewerKind).toBe('user')
  })

  it('answers 409 with the PHONE_TAKEN code', async () => {
    vi.mocked(updateMember).mockResolvedValue({
      success: false,
      error: 'That number belongs to another member',
      code: 'PHONE_TAKEN',
      status: 409,
    })
    const res = await patch({ phoneNumber: '+15550100002' })
    expect(res.status).toBe(409)
    expect(res.body).toEqual({ success: false, error: 'That number belongs to another member', code: 'PHONE_TAKEN' })
  })

  it('answers 403 for the member-session phone guard', async () => {
    vi.mocked(updateMember).mockResolvedValue({ success: false, error: 'Phone changes go through sign-in', status: 403 })
    const res = await patch({ phoneNumber: '+15550109999' }, SELF)
    expect(res.status).toBe(403)
    expect(res.body).toEqual({ success: false, error: 'Phone changes go through sign-in' })
  })

  it('answers 500 when the service sets no status', async () => {
    vi.mocked(updateMember).mockResolvedValue({ success: false, error: 'Failed to update member' })
    const res = await patch({ firstName: 'Ann' })
    expect(res.status).toBe(500)
    expect(res.body).toEqual({ success: false, error: 'Failed to update member' })
  })

  it('still 404s a leader the member is hidden from, before validating (D7)', async () => {
    vi.mocked(canViewMember).mockResolvedValue(false)
    const res = await patch({ phoneNumber: '+15550109999' }, { userId: 'gl2' })
    expect(res.status).toBe(404)
    expect(res.body).toEqual({ success: false, error: 'Member not found' })
    expect(updateMember).not.toHaveBeenCalled()
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run src/routes/__tests__/members-edit.request.test.ts` → FAIL (e.g. phoneNumber cases: `data` is `{}` because the old schema strips the key; `.strict()` case: expected 400, got 200; 409 case: got 500; viewer kind: `viewerKind` is `undefined`).

- [ ] **Step 3: Write the implementation**

In `server/src/routes/members.ts`:

(a) extend the `../services/member.js` import (lines 5-14) with the type, and add the helpers import right after it:

```ts
import {
  getMember,
  getMemberByPhone,
  createMember,
  updateMember,
  deleteMember,
  getScopedMember,
  getScopedMemberGroups,
  addMemberToOrganization,
  type UpdateMemberData,
} from '../services/member.js'
import {
  birthdayInRange,
  isValidContactPhone,
  normalizePhone,
  parseBirthday,
} from '../services/member-fields.js'
```

(b) replace the `updateMemberSchema` declaration (`const updateMemberSchema = z.object({ … })`, ~line 1201; keep the OpenAPI comment above it) with:

```ts
// ui2-members-edit SC1 / §Contract. Strings are trimmed; "" on a clearable key is null (D8, D11);
// unknown keys are a 400, never silently dropped (.strict()).
const PHONE_MESSAGE = 'Enter a valid phone number'
const BIRTHDAY_MESSAGE = 'Birthday must be between 1900 and today'
const emptyToNull = (value: unknown) => {
  const trimmed = typeof value === 'string' ? value.trim() : value
  return trimmed === '' ? null : trimmed
}
const clearableText = () => z.preprocess(emptyToNull, z.string().nullable().optional())

const updateMemberSchema = z
  .object({
    firstName: z.string().optional(),
    lastName: z.string().optional(),
    email: z.preprocess(emptyToNull, z.string().email('Enter a valid email').nullable().optional()),
    // D4/D18: normalized to E.164; "" / whitespace normalizes to null → 400 (D8: phone is required).
    phoneNumber: z
      .string({ invalid_type_error: PHONE_MESSAGE, required_error: PHONE_MESSAGE })
      .transform((raw, ctx) => {
        const phone = normalizePhone(raw)
        if (!phone) {
          ctx.addIssue({ code: z.ZodIssueCode.custom, message: PHONE_MESSAGE })
          return z.NEVER
        }
        return phone
      })
      .optional(),
    gender: z.preprocess(emptyToNull, z.enum(['male', 'female']).nullable().optional()),
    // D9/D19: YYYY-MM-DD or ISO → its UTC calendar date at 00:00Z, 1900-01-01 … UTC today + 1 day.
    birthday: z
      .preprocess(emptyToNull, z.string({ invalid_type_error: BIRTHDAY_MESSAGE }).nullable().optional())
      .transform((raw, ctx): Date | null | undefined => {
        if (raw === undefined || raw === null) return raw
        const date = parseBirthday(raw)
        if (!date || !birthdayInRange(date, new Date())) {
          ctx.addIssue({ code: z.ZodIssueCode.custom, message: BIRTHDAY_MESSAGE })
          return z.NEVER
        }
        return date
      }),
    address: clearableText(),
    emergencyContactName: clearableText(),
    // D7: stored as typed (trimmed); not unique, not verified.
    emergencyContactPhone: z.preprocess(
      emptyToNull,
      z
        .string({ invalid_type_error: PHONE_MESSAGE })
        .nullable()
        .optional()
        .refine((value) => value === undefined || value === null || isValidContactPhone(value), PHONE_MESSAGE)
    ),
    profilePicture: z.string().url().optional().nullable(),
    smsConsent: z.boolean().optional(),
  })
  .strict()
```

(c) in `router.patch('/:memberId', requireMemberOrOrgOwner, …)`, replace everything from
`const { birthday, gender, profilePicture, smsConsent, ...rest } = validation.data` down to (and
including) the `if (!result.success) { … }` block with:

```ts
    const { smsConsent, ...rest } = validation.data
    const updateData: UpdateMemberData = {
      ...rest,
      ...(smsConsent !== undefined && {
        smsConsent,
        smsConsentAt: smsConsent ? new Date() : null,
      }),
    }

    // D12/D23: the member-session phone guard runs in the service; the route only says who is asking.
    const result = await updateMember(memberId, updateData, viewer?.kind ?? 'user')

    if (!result.success) {
      return res.status(result.status ?? 500).json({
        success: false,
        error: result.error,
        ...(result.code && { code: result.code }),
      })
    }
```

Leave the D7 `viewerOf` / `canViewMember` 404 block above it, the `safeParse` 400 block, the success
`res.json` and the outer `catch` exactly as they are.

- [ ] **Step 4: Run it and watch it pass** — `cd server && npx vitest run src/routes/__tests__/members-edit.request.test.ts src/routes/__tests__/members-scope.request.test.ts` → PASS (both files; the existing D7 PATCH tests in `members-scope.request.test.ts` still pass).

- [ ] **Step 5: Typecheck** — `cd server && npx tsc --noEmit` → exit 0.

- [ ] **Step 6: Commit** — `git add server/src/routes/members.ts server/src/routes/__tests__/members-edit.request.test.ts && git commit -m "feat(ui2-members-edit): PATCH /api/members/:id accepts phone, address and emergency fields under a strict schema"`

### Task 4: Fixtures — `sparse` scenario for the edit pages' "Not set" states, then freeze the contract
App: server
Phase: 1
Recipe: server/fixtures/README.md

Implements SPEC T5 (house rule: a wired UI 2.0 screen adds `server/fixtures/screens/<screen-id>.ts`;
the screen id is `shared-edit-field`). The fixtures system already has scenarios
(`LayerScenario = 'full' | 'sparse' | 'extreme'` in `server/fixtures/context.ts:157`); the runner
offers a scenario as soon as one layer exports it, and runs **only** base + the layers that export
that scenario (`runner.ts` `runFixtures`). So:

- `screens/shared-edit-field.ts` exports **only** `sparse` — no `full`, so the `full` scenario keeps
  all 24 members fully populated (`fixtures/__tests__/members.db.test.ts` "fills the D13 fields on
  all 24 members" stays green unchanged).
- Because no other layer exports `sparse`, `sparse` first replays the two Members layers' `full`
  (`members-home` — the Prayer Team memberships the Group-Leader user sees; `members-profile` — the
  member-7 user link), then nulls `gender`, `birthday`, `address`, `emergencyContactName`,
  `emergencyContactPhone` on member 16 (one of the 3 Prayer Team members, `MULTI_GROUP_MEMBER_INDICES
  = [0, 8, 16]`; member 0 is avoided because `members.db.test.ts` searches and engages on James
  Carter). Its email and phone stay set (phone is required; email's empty state is reachable by
  clearing it in the walk).
- `db-harness.ts`'s `run()` scenario type widens to include `'sparse'`.
- Final step records the contract freeze (SPEC §Apps Sequencing: server PATCH verifies → contract
  FREEZES) — run it only after the whole server suite is green.

Fixture layers need no restart (README: layer edits are picked up). `docker restart makeready-server`
is needed only for manual curl against server/src changes, not for vitest.

**Files:**
- Create: `server/fixtures/screens/shared-edit-field.ts`
- Modify: `server/fixtures/__tests__/db-harness.ts:19` (`run` signature)
- Modify: `server/fixtures/README.md` (Scenarios section — add the `sparse` paragraph)
- Test: `server/fixtures/__tests__/shared-edit-field.test.ts` (unit, mocked Prisma)
- Test: `server/fixtures/__tests__/shared-edit-field.db.test.ts` (gated on `FIXTURES_TEST_DATABASE_URL`)

**Interfaces:**
- Consumes (existing): `FixtureContext`, `createContext(prisma, now)`, `LAYER_SCENARIOS` from `server/fixtures/context.ts`; `availableScenarios(screens: NamedLayer[])` from `server/fixtures/runner.ts`; `full`, `MULTI_GROUP_MEMBER_INDICES` from `server/fixtures/screens/members-home.ts`; `full` from `server/fixtures/screens/members-profile.ts`; `FIXTURE_MEMBER_IDS`, `FIXTURE_LEADER_GROUP_ID`, `FIXTURE_LEADER_USER_ID` from `server/fixtures/ids.ts`; `getScopedMember(memberId, viewer)` from `server/src/services/member.ts`.
- Produces (`server/fixtures/screens/shared-edit-field.ts`):
  - `export const SPARSE_MEMBER_INDEX = 16`
  - `export const SPARSE_NULL_FIELDS: readonly ['gender', 'birthday', 'address', 'emergencyContactName', 'emergencyContactPhone']`
  - `export async function sparse(ctx: FixtureContext): Promise<void>`
  - scenario `npm run fixtures:reset -- sparse` becomes available (`full, sparse, empty`).

- [ ] **Step 1: Write the failing unit test**

Create `server/fixtures/__tests__/shared-edit-field.test.ts`:

```ts
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { LAYER_SCENARIOS, createContext } from '../context.js'
import { FIXTURE_MEMBER_IDS } from '../ids.js'
import { availableScenarios } from '../runner.js'
import { MULTI_GROUP_MEMBER_INDICES } from '../screens/members-home.js'
import { LEADER_MEMBER_INDEX } from '../screens/members-profile.js'
import * as layer from '../screens/shared-edit-field.js'

const prisma = {
  groupMember: { createMany: vi.fn() },
  memberOrganization: { update: vi.fn() },
  member: { update: vi.fn() },
}

beforeEach(() => {
  vi.clearAllMocks()
})

describe('shared-edit-field layer (ui2-members-edit T5)', () => {
  it('exports sparse only, so full keeps every member populated', () => {
    expect(Object.keys(layer).filter((k) => (LAYER_SCENARIOS as readonly string[]).includes(k))).toEqual(['sparse'])
    expect(availableScenarios([{ name: 'shared-edit-field', module: { sparse: layer.sparse } }])).toEqual(['sparse', 'empty'])
  })

  it('picks a Prayer Team member the Group-Leader user sees, never the leader’s own member or James Carter', () => {
    expect(MULTI_GROUP_MEMBER_INDICES).toContain(layer.SPARSE_MEMBER_INDEX)
    expect(layer.SPARSE_MEMBER_INDEX).not.toBe(LEADER_MEMBER_INDEX)
    expect(layer.SPARSE_MEMBER_INDEX).not.toBe(0)
  })

  it('replays the Members layers, then nulls the five optional fields on that one member', async () => {
    await layer.sparse(createContext(prisma as never, new Date('2026-10-26T15:00:00Z')))
    // members-home: the three Prayer Team memberships; members-profile: the member-7 user link.
    expect(prisma.groupMember.createMany).toHaveBeenCalledTimes(1)
    expect(prisma.groupMember.createMany.mock.calls[0][0].data).toHaveLength(3)
    expect(prisma.member.update).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: FIXTURE_MEMBER_IDS[LEADER_MEMBER_INDEX] } })
    )
    expect(prisma.member.update).toHaveBeenLastCalledWith({
      where: { id: FIXTURE_MEMBER_IDS[layer.SPARSE_MEMBER_INDEX] },
      data: { gender: null, birthday: null, address: null, emergencyContactName: null, emergencyContactPhone: null },
    })
    expect(layer.SPARSE_NULL_FIELDS).toEqual(['gender', 'birthday', 'address', 'emergencyContactName', 'emergencyContactPhone'])
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run fixtures/__tests__/shared-edit-field.test.ts` → FAIL, `Failed to load url ../screens/shared-edit-field.js`.

- [ ] **Step 3: Write the layer**

Create `server/fixtures/screens/shared-edit-field.ts`:

```ts
/**
 * shared-edit-field layer (ui2-members-edit T5, D8, D9, D10): the edit pages' "stored null" states.
 * Exports `sparse` only — `full` keeps all 24 members fully populated (members.db.test.ts). The
 * runner runs just the layers that export the chosen scenario, so `sparse` first replays the two
 * Members layers' `full` (the Prayer Team memberships the Group-Leader user sees, and member 7's
 * user link), then nulls gender, birthday, address and both emergency fields on one Prayer Team
 * member: the Birthday page opens on "Not set", Gender pre-selects "Not set", Address and both
 * Emergency pages open empty. Email and phone stay set. Creates no org, user or group.
 */
import type { FixtureContext } from '../context.js'
import { FIXTURE_MEMBER_IDS } from '../ids.js'
import { full as membersHome } from './members-home.js'
import { full as membersProfile } from './members-profile.js'

/** One of MULTI_GROUP_MEMBER_INDICES (Prayer Team); not member 0, whom members.db.test.ts searches. */
export const SPARSE_MEMBER_INDEX = 16

export const SPARSE_NULL_FIELDS = [
  'gender',
  'birthday',
  'address',
  'emergencyContactName',
  'emergencyContactPhone',
] as const

export async function sparse(ctx: FixtureContext): Promise<void> {
  await membersHome(ctx)
  await membersProfile(ctx)
  await ctx.prisma.member.update({
    where: { id: FIXTURE_MEMBER_IDS[SPARSE_MEMBER_INDEX] },
    data: { gender: null, birthday: null, address: null, emergencyContactName: null, emergencyContactPhone: null },
  })
}
```

- [ ] **Step 4: Run it and watch it pass** — `cd server && npx vitest run fixtures/__tests__/shared-edit-field.test.ts fixtures/__tests__/runner.test.ts fixtures/__tests__/members.test.ts` → PASS (runner.test stubs its own layers, so its "Available scenarios: full, empty" assertions are unaffected).

- [ ] **Step 5: Widen the DB harness and write the DB test**

In `server/fixtures/__tests__/db-harness.ts`, change the `FixturesDb.run` signature:

```ts
  run(command: 'reset' | 'seed', scenario: 'full' | 'sparse' | 'empty'): Promise<RowCounts>
```

Create `server/fixtures/__tests__/shared-edit-field.db.test.ts`:

```ts
/**
 * ui2-members-edit T5 against a throwaway database: `fixtures:reset -- sparse` leaves exactly one
 * Prayer Team member with the five optional fields null, and the Group-Leader user can still open
 * that member. Gated on FIXTURES_TEST_DATABASE_URL (db-harness.ts); absent, it prints the skip line.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { FIXTURE_LEADER_GROUP_ID, FIXTURE_LEADER_USER_ID, FIXTURE_MEMBER_IDS } from '../ids.js'
import { SPARSE_MEMBER_INDEX } from '../screens/shared-edit-field.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

const leader = { kind: 'user' as const, userId: FIXTURE_LEADER_USER_ID }
const sparseId = FIXTURE_MEMBER_IDS[SPARSE_MEMBER_INDEX]

describe.skipIf(!TEST_DB_URL)('shared-edit-field sparse scenario against the test database (ui2-members-edit T5)', () => {
  let db: FixturesDb

  beforeAll(async () => {
    db = await openFixturesDb()
    await db.run('reset', 'sparse')
  }, 180_000)

  afterAll(async () => {
    if (db) await db.close()
  })

  it('nulls gender, birthday, address and both emergency fields on the one sparse member', async () => {
    const m = await db.prisma.member.findUniqueOrThrow({ where: { id: sparseId } })
    expect(m).toMatchObject({ gender: null, birthday: null, address: null, emergencyContactName: null, emergencyContactPhone: null })
    expect(m.email).toMatch(/@example\.org$/)
    expect(m.phoneNumber).toMatch(/^\+1555010\d{4}$/)
  })

  it('leaves the other 23 members populated', async () => {
    const rest = await db.prisma.member.findMany({ where: { id: { in: FIXTURE_MEMBER_IDS.filter((id) => id !== sparseId) } } })
    expect(rest).toHaveLength(23)
    for (const m of rest) {
      expect(m.gender).not.toBeNull()
      expect(m.birthday).not.toBeNull()
      expect(m.address).not.toBeNull()
      expect(m.emergencyContactName).not.toBeNull()
      expect(m.emergencyContactPhone).not.toBeNull()
    }
  })

  it('keeps the Prayer Team, so the Group-Leader user opens the sparse member', async () => {
    expect(await db.prisma.groupMember.count({ where: { groupId: FIXTURE_LEADER_GROUP_ID, isActive: true } })).toBe(3)
    const { getScopedMember } = await import('../../src/services/member.js')
    const res = await getScopedMember(sparseId, leader)
    expect(res.success).toBe(true)
    expect(res.data?.gender).toBeNull()
    expect(res.data?.birthday).toBeNull()
  })
})
```

- [ ] **Step 6: Run the fixture tests and typecheck** — `cd server && npx vitest run fixtures/__tests__/shared-edit-field.test.ts fixtures/__tests__/shared-edit-field.db.test.ts fixtures/__tests__/members.db.test.ts` → unit PASS; the two DB files print `fixtures DB tests skipped — set FIXTURES_TEST_DATABASE_URL` unless that env var points at a throwaway database (never `makeready_dev`), in which case both PASS. Then `cd server && npx tsc --noEmit -p fixtures` → exit 0, and `cd server && npx tsc --noEmit` → exit 0.

- [ ] **Step 7: Document the scenario in the README**

In `server/fixtures/README.md`, under `## Scenarios`, after the paragraph that ends "…the runner offers a scenario as soon as one layer implements it.", add:

```markdown
`sparse` (ui2-members-edit T5) = base + `screens/shared-edit-field.ts`, the only layer that exports
it. That layer replays `members-home` and `members-profile` `full` (so the Group-Leader session
still lists the three Prayer Team members and Nathan Hughes reads "Group leader"), then nulls
`gender`, `birthday`, `address`, `emergencyContactName` and `emergencyContactPhone` on member 16
(`SPARSE_MEMBER_INDEX`, one of the Prayer Team three): the edit pages open on their "Not set" /
empty states. Home's dashboard layer does not run under `sparse`, so Home reads as empty.
`docker exec makeready-server npm run fixtures:reset -- sparse`.
```

- [ ] **Step 8: Commit** — `git add server/fixtures/screens/shared-edit-field.ts server/fixtures/__tests__/shared-edit-field.test.ts server/fixtures/__tests__/shared-edit-field.db.test.ts server/fixtures/__tests__/db-harness.ts server/fixtures/README.md && git commit -m "feat(ui2-members-edit): sparse fixtures scenario for the shared-edit-field Not-set states"`

- [ ] **Step 9: Run the whole server suite** — `cd server && npm run test:run` → every test file added or touched by Tasks 1–4 passes (`member-fields`, `member-update`, `member-scope`, `members-edit.request`, `members-scope.request`, `verification`, `shared-edit-field`, `runner`, `members`). A failure in any other file must be shown to be pre-existing: re-run that one file (`cd server && npx vitest run <file>`) and confirm it imports none of `services/member.ts`, `services/member-fields.ts`, `routes/members.ts`, `routes/verification.ts` or `fixtures/` — or, for the whole-app suites (`members.test.ts`, `verification.test.ts`, `member-auth.test.ts`), that it fails with a database/env connection error rather than an assertion about the PATCH body or phone rules; any assertion failure there is a regression to fix before Step 10.

- [ ] **Step 10: Record the contract freeze** — from the repo root: `node /Users/lukekeith/.claude-home/plugins/cache/claude-builder/builder/4.14.8/scripts/advance.mjs docs/features/ui2-members-edit --set "contract=frozen $(date +%F)" --commit "chore(ui2-members-edit): contract frozen"` → `docs/features/ui2-members-edit/MANIFEST.md` reads `contract: frozen <today>` and a commit `chore(ui2-members-edit): contract frozen` exists.

### Task 5: Live text editing through C-045 → C-046 → SharedEditFieldTemplate (T9 a–f)
App: iphone
Phase: 2
Recipe: /ui2-resolve

> **d2m ownership (F2/F4).** Everything under `iphone/MakeReadyUI/` is d2m-owned. This task edits C-045 `TextInput`, C-046 `FieldGroup`, `SharedEditFieldTemplate` and the two text screens in code only; after the build `/ui2-resolve` re-renders them through the d2m harness and diffs against the frozen snapshots. **Never write a UI 2.0 contract, registry row, token or note.** Every new parameter is defaulted so every existing `#Preview`, every `ViewRegistry` case and every capture renders exactly as today: the static (display-only) render stays the default, and the live field appears only when a caller passes `editable: true`.

**Module boundary (read once).** `MakeReadyUI/*.swift` compiles into THREE targets — the `MakeReadyUI` framework, the `MakeReady` app and `MakeReadyCapture` (`iphone/scripts/makereadyui-sync.rb`, `capture-targets.rb`). The app never imports the framework: inside the app these views are plain `MakeReady` module types, internal by default. Tests use `@testable import MakeReady` and refer to them unqualified (`UI2MembersComponentTests.swift` precedent). No `public` is needed anywhere.

**Files:**
- Modify: `iphone/MakeReadyUI/TextInput.swift:47-78` (new `editing` prop + `Editing` struct after `onFocusChange`; body split into a static and a live form) and append a private `LiveField` view at the end of the file
- Modify: `iphone/MakeReadyUI/FieldGroup.swift:56-75` (three pass-through props; the `TextInput(...)` call)
- Modify (full rewrite): `iphone/MakeReadyUI/Screens/Shared/SharedEditFieldTemplate.swift`
- Modify (full rewrite): `iphone/MakeReadyUI/Screens/Fields/EditTextSingleFieldScreen.swift`
- Modify (full rewrite): `iphone/MakeReadyUI/Screens/Fields/EditTextMultiFieldScreen.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — register the new test file in target `MakeReadyCaptureTests` (Step 1). The project uses explicit file references (objectVersion 56, no synchronized folders), so a file not referenced there is invisible to the compiler.
- Test: Create `iphone/MakeReadyCaptureTests/UI2MembersEditComponentTests.swift`

**Interfaces:**
- Consumes: existing `TextInput(text:placeholder:kind:alignment:focused:countryCode:onChange:onFocusChange:)` memberwise init, `FieldGroup(label:field:style:layout:text:placeholder:)` memberwise init, `AISuggestionsBlock`, `PageActionButton(label:role:enabled:onTap:)`, `PageHeader`, `Token.TypeStyle.input` / `.pageTitle`, `Token.error`, `Token.Space.elementGap` / `.sectionGap` / `.pageMargin`, `Token.inputValue` / `.inputPlaceholder` / `.accent`.
- Produces (later tasks rely on these exact names):
  - `TextInput.Editing` — `struct Editing { var keyboard: UIKeyboardType = .default; var textContentType: UITextContentType? = nil; var autocapitalization: TextInputAutocapitalization = .sentences; var autocorrect: Bool = true; var focusOnAppear: Bool = false; var isEnabled: Bool = true; var accessibilityName: String = "" }`; `TextInput.editing: Editing? = nil` (nil = today's static render)
  - `FieldGroup.editing: TextInput.Editing? = nil`, `FieldGroup.onChange: (String) -> Void = { _ in }`, `FieldGroup.onFocusChange: (Bool) -> Void = { _ in }`
  - `SharedEditFieldTemplate.saveEnabled(text: String, loaded: String, allowsEmpty: Bool, saving: Bool, canSave: ((String) -> Bool)?) -> Bool` (static) and `SharedEditFieldTemplate.capped(_ text: String, maxLength: Int) -> String` (static)
  - `EditTextSingleFieldScreen.State` gains (all defaulted): `allowsEmpty: Bool = false`, `maxLength: Int = 200`, `errorMessage: String = ""`, `showsAISuggestions: Bool = true`, `editable: Bool = false`, `focusOnAppear: Bool = false`, `keyboard: UIKeyboardType = .default`, `textContentType: UITextContentType? = nil`, `autocapitalization: TextInputAutocapitalization = .sentences`, `autocorrect: Bool = true`
  - `EditTextSingleFieldScreen.init(state:onBack:onGenerate:onSave:canSave: ((String) -> Bool)? = nil, onTextChange: @escaping (String) -> Void = { _ in })`
  - `EditTextMultiFieldScreen.State` gains (all defaulted): `maxLength: Int = 2000`, `errorMessage: String = ""`, `showsAISuggestions: Bool = true`, `editable: Bool = false`, `focusOnAppear: Bool = false`, `keyboard: UIKeyboardType = .default`, `textContentType: UITextContentType? = nil`, `autocapitalization: TextInputAutocapitalization = .sentences`, `autocorrect: Bool = true`
  - `EditTextMultiFieldScreen.init(state:onBack:onGenerate:onSave:onTextChange: @escaping (String) -> Void = { _ in })`
  - Behaviour: `saving` → Save disabled AND the live field disabled, no spinner (D26). `canSave`, when given, receives the TRIMMED text and replaces only the dirty/empty rule; `saving` still disables (D24). The single-line live field keeps focus on return (D22: return does nothing); the multi-line live field inserts a newline on return.

- [ ] **Step 1: Write the failing tests** — create `iphone/MakeReadyCaptureTests/UI2MembersEditComponentTests.swift`:

```swift
import XCTest
import SwiftUI
@testable import MakeReady

/// ui2-members-edit: the MakeReadyUI edits this feature makes (T9 a–f, T10, T11). Render parity is
/// the d2m harness's job via /ui2-resolve (F2/F4); these pin the props and the pure rules.
final class UI2MembersEditComponentTests: XCTestCase {

    // MARK: - Task 5: shared-edit-field template (T9 a–f)

    /// §3: `clean` (trimmed equal to the loaded value) disables Save; `dirty` enables it;
    /// `saving` disables it.
    func testSaveIsEnabledOnlyWhenDirtyAndNotSaving() {
        XCTAssertFalse(SharedEditFieldTemplate.saveEnabled(text: "Ann", loaded: "Ann", allowsEmpty: false, saving: false, canSave: nil))
        XCTAssertFalse(SharedEditFieldTemplate.saveEnabled(text: " Ann \n", loaded: "Ann", allowsEmpty: false, saving: false, canSave: nil))
        XCTAssertTrue(SharedEditFieldTemplate.saveEnabled(text: "Anna", loaded: "Ann", allowsEmpty: false, saving: false, canSave: nil))
        XCTAssertFalse(SharedEditFieldTemplate.saveEnabled(text: "Anna", loaded: "Ann", allowsEmpty: false, saving: true, canSave: nil))
    }

    /// T9b / D8: empty is `invalid` unless the screen allows it; clearing a set value is dirty.
    func testEmptyIsInvalidUnlessAllowed() {
        XCTAssertFalse(SharedEditFieldTemplate.saveEnabled(text: "  ", loaded: "Ann", allowsEmpty: false, saving: false, canSave: nil))
        XCTAssertTrue(SharedEditFieldTemplate.saveEnabled(text: "  ", loaded: "Ann", allowsEmpty: true, saving: false, canSave: nil))
        XCTAssertFalse(SharedEditFieldTemplate.saveEnabled(text: "", loaded: "", allowsEmpty: true, saving: false, canSave: nil))
    }

    /// T9f / D24: a caller rule replaces dirty/empty, never `saving`; it sees the trimmed text.
    func testCanSaveReplacesTheDirtyRuleButNotSaving() {
        XCTAssertTrue(SharedEditFieldTemplate.saveEnabled(text: "Ann", loaded: "Ann", allowsEmpty: false, saving: false, canSave: { _ in true }))
        XCTAssertFalse(SharedEditFieldTemplate.saveEnabled(text: "Anna", loaded: "Ann", allowsEmpty: false, saving: false, canSave: { _ in false }))
        XCTAssertFalse(SharedEditFieldTemplate.saveEnabled(text: "Anna", loaded: "Ann", allowsEmpty: false, saving: true, canSave: { _ in true }))
        var seen = ""
        _ = SharedEditFieldTemplate.saveEnabled(text: "  +1 555 \n", loaded: "", allowsEmpty: false, saving: false, canSave: { seen = $0; return true })
        XCTAssertEqual(seen, "+1 555")
    }

    /// T9d: the silent hard cap.
    func testCapClipsTypedText() {
        XCTAssertEqual(SharedEditFieldTemplate.capped("abcdef", maxLength: 3), "abc")
        XCTAssertEqual(SharedEditFieldTemplate.capped("ab", maxLength: 3), "ab")
    }

    /// Every new prop defaults to today's render: AI block shown, no error line, static input,
    /// single-line caps at 200 and forbids empty, multi-line caps at 2000.
    func testTextScreenStatesDefaultToTodaysRender() {
        let single = EditTextSingleFieldScreen.State(
            title: "T", description: "D", label: "L", placeholder: "", text: "", loadedValue: "",
            focused: false, saving: false, promptCopy: "", aiState: "prompt", suggestions: []
        )
        XCTAssertFalse(single.allowsEmpty)
        XCTAssertEqual(single.maxLength, 200)
        XCTAssertEqual(single.errorMessage, "")
        XCTAssertTrue(single.showsAISuggestions)
        XCTAssertFalse(single.editable)
        XCTAssertFalse(single.focusOnAppear)
        XCTAssertEqual(single.keyboard, .default)
        XCTAssertNil(single.textContentType)
        XCTAssertTrue(single.autocorrect)

        let multi = EditTextMultiFieldScreen.State(
            title: "T", description: "D", label: "L", placeholder: "", text: "", loadedValue: "",
            focused: false, saving: false, promptCopy: "", aiState: "prompt", suggestions: []
        )
        XCTAssertEqual(multi.maxLength, 2000)
        XCTAssertEqual(multi.errorMessage, "")
        XCTAssertTrue(multi.showsAISuggestions)
        XCTAssertFalse(multi.editable)
    }

    /// T9e: the static render stays the default for C-045 and C-046; the live field's defaults.
    func testInputsAreDisplayOnlyUnlessGivenEditing() {
        XCTAssertNil(TextInput(text: "", placeholder: "", kind: .single, focused: false).editing)
        XCTAssertNil(FieldGroup(label: "L", field: .text, style: .default, layout: .default, text: "", placeholder: "").editing)
        let editing = TextInput.Editing()
        XCTAssertEqual(editing.keyboard, .default)
        XCTAssertTrue(editing.isEnabled)
        XCTAssertFalse(editing.focusOnAppear)
        XCTAssertTrue(editing.autocorrect)
        XCTAssertEqual(editing.accessibilityName, "")
    }
}
```

Register the test file (from `iphone/`):

```bash
cd iphone && ruby -rxcodeproj -e '
p = Xcodeproj::Project.open("MakeReady.xcodeproj")
[["MakeReadyCaptureTests", "UI2MembersEditComponentTests.swift", "MakeReadyCaptureTests"]].each do |group, path, target|
  g = p.main_group.find_subpath(group, false) or abort("no group #{group}")
  next if g.files.any? { |f| f.path == path }
  p.targets.find { |t| t.name == target }.add_file_references([g.new_reference(path)])
end
p.save'
```

- [ ] **Step 2: Run it and watch it fail** — from the repo root: `npm run ios:build-check -- --test` → FAIL (test target does not compile): "type 'SharedEditFieldTemplate' has no member 'saveEnabled'", "value of type 'EditTextSingleFieldScreen.State' has no member 'allowsEmpty'", "value of type 'TextInput' has no member 'editing'".

- [ ] **Step 3: C-045 TextInput — the `editing` prop.** In `iphone/MakeReadyUI/TextInput.swift`, directly after line 50 (`var onFocusChange: (Bool) -> Void = { _ in }`), insert:

```swift
    /// ui2-members-edit T9e (D22, D26): nil — the default — is the static render every preview
    /// and capture draws (R-01: `text` is drawn, nothing is typed). Non-nil makes Single and
    /// Multi a live text field: every edit calls `onChange`, focus calls `onFocusChange`, and the
    /// caller keeps owning `text` and `focused`. Phone ignores it (no live consumer yet; the
    /// member Phone page uses `field: .text`, D22). Routed to /ui2-resolve (F2).
    var editing: Editing? = nil

    /// ui2-members-edit T9d/T9e: the live field's keyboard and focus — behaviour, not design.
    struct Editing {
        var keyboard: UIKeyboardType = .default
        var textContentType: UITextContentType? = nil
        var autocapitalization: TextInputAutocapitalization = .sentences
        var autocorrect: Bool = true
        /// D22: the field takes focus when it appears.
        var focusOnAppear: Bool = false
        /// D26: false while a save is in flight — the input is locked.
        var isEnabled: Bool = true
        /// R-17: the live field's spoken name (C-046 passes its label); "" falls back to `placeholder`.
        var accessibilityName: String = ""
    }
```

Then replace the whole `var body: some View { … }` block (lines 52-78, from `var body: some View {` through the `.ui2Element("TextInput")` line and its closing brace) with:

```swift
    var body: some View {
        if let editing, kind != .phone {
            // T9e: the live form — the same §2 box with a real field inside. The field carries
            // its own accessibility (R-17), so the box does not flatten it.
            chrome(
                LiveField(
                    text: text,
                    placeholder: placeholder,
                    multiline: kind == .multi,
                    alignment: textAlignment,
                    editing: editing,
                    onChange: onChange,
                    onFocusChange: onFocusChange
                )
                .ui2Element(text.isEmpty ? "Placeholder" : "Value")
            )
            .ui2Element("TextInput")
        } else {
            chrome(content)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(placeholder)          // R-17: §4 names placeholder as the label
                .accessibilityValue(text)
                .ui2Element("TextInput")                  // capture element map — UI2Element.swift
        }
    }

    /// §2's box around either form — the static render gets exactly the modifiers it always had,
    /// in the same order.
    private func chrome(_ inner: some View) -> some View {
        inner
            // §2: p16 / px16 for every kind — measured INSIDE the 1px border (see
            // `borderWidth`).
            .padding(.horizontal, Self.borderWidth + Token.Space.cardPadding)
            .padding(.vertical, verticalInset)
            // §2: Single / Phone 44pt, content vertically centred · Multi 88pt MINIMUM,
            // growing with content (OQ-C-045-3), content top-aligned.
            .frame(
                maxWidth: .infinity,
                minHeight: minHeight,
                maxHeight: kind == .multi ? nil : minHeight,
                alignment: boxAlignment
            )
            .overlay(
                // §2: Border 1px `color-card-border`; focused: 1px `color-text-primary`.
                // (Error = `color-negative` is ruled by OQ-C-045-2 but §4 gives it no prop:
                // "it is not built until a consumer needs it". ui2-members-edit D28: still no
                // red border — the inline error line only.)
                RoundedRectangle(cornerRadius: Token.Radius.cardSm)
                    .strokeBorder(focused ? Token.textPrimary : Token.cardBorder, lineWidth: Self.borderWidth)
            )
            .contentShape(Rectangle())
    }
```

At the very end of the file (after the closing brace of `struct TextInput`), append:

```swift
/// ui2-members-edit T9e: C-045's live text run — a `TextField` drawn in §2's `type-input` and
/// colours, with the system caret tinted `color-accent` in place of the drawn 2×24 caret (the
/// C-034 SearchField editable-form precedent). Its own type so the focus state stays private
/// without touching `TextInput`'s memberwise initializer.
private struct LiveField: View {
    let text: String
    let placeholder: String
    let multiline: Bool
    let alignment: TextAlignment
    let editing: TextInput.Editing
    let onChange: (String) -> Void
    let onFocusChange: (Bool) -> Void

    /// Ephemeral UI state (R-02), reported out through `onFocusChange`.
    @FocusState private var fieldFocused: Bool

    init(
        text: String,
        placeholder: String,
        multiline: Bool,
        alignment: TextAlignment,
        editing: TextInput.Editing,
        onChange: @escaping (String) -> Void,
        onFocusChange: @escaping (Bool) -> Void
    ) {
        self.text = text
        self.placeholder = placeholder
        self.multiline = multiline
        self.alignment = alignment
        self.editing = editing
        self.onChange = onChange
        self.onFocusChange = onFocusChange
    }

    var body: some View {
        TextField(
            editing.accessibilityName.isEmpty ? placeholder : editing.accessibilityName,
            text: Binding(get: { text }, set: { onChange($0) }),
            prompt: Text(placeholder).foregroundColor(Token.inputPlaceholder),
            // D22: Multi — return inserts a newline; Single — one line.
            axis: multiline ? .vertical : .horizontal
        )
        // §2: Single/Multi text — Regular 14/24 `type-input`, value `color-input-value`.
        .designTextStyle(Token.TypeStyle.input)
        .foregroundColor(Token.inputValue)
        .multilineTextAlignment(alignment)
        .tint(Token.accent)
        .keyboardType(editing.keyboard)
        .textContentType(editing.textContentType)
        .textInputAutocapitalization(editing.autocapitalization)
        .autocorrectionDisabled(!editing.autocorrect)
        .focused($fieldFocused)
        // D26: `saving` locks the input.
        .disabled(!editing.isEnabled)
        // D22: on a single-line page the return key does nothing — Save stays a tap — so the
        // field keeps focus instead of resigning.
        .onSubmit { if !multiline { fieldFocused = true } }
        .onChange(of: fieldFocused) { _, now in onFocusChange(now) }
        .onAppear { if editing.focusOnAppear { fieldFocused = true } }
    }
}
```

- [ ] **Step 4: C-046 FieldGroup — pass-throughs.** In `iphone/MakeReadyUI/FieldGroup.swift`, directly after line 57 (`let placeholder: String`), insert:

```swift
    /// ui2-members-edit T9e: passed to C-045 `editing` — nil (the default) keeps the static
    /// render every preview and capture uses. Routed to /ui2-resolve (F2).
    var editing: TextInput.Editing? = nil
    /// ui2-members-edit T9e: C-045's `onChange` / `onFocusChange`, forwarded unchanged.
    var onChange: (String) -> Void = { _ in }
    var onFocusChange: (Bool) -> Void = { _ in }
```

and replace the `TextInput(...)` call (lines 65-72) with:

```swift
            TextInput(
                text: text,
                placeholder: placeholder,
                kind: kind,
                // §2 / OQ-C-046-004: Centered centres the input text; Phone ignores it.
                alignment: isCentered ? .center : .leading,
                focused: style == .focus,
                onChange: onChange,
                onFocusChange: onFocusChange,
                editing: editing
            )
```

- [ ] **Step 5: SharedEditFieldTemplate — replace the whole file** `iphone/MakeReadyUI/Screens/Shared/SharedEditFieldTemplate.swift` with:

```swift
//
//  SharedEditFieldTemplate.swift
//  MakeReadyUI — the UI 2.0 module
//
//  The shared §2 layout of the screens minted from collection shared-edit-field whose layouts
//  differ only in content (D7): edit-text-single-field and edit-text-multi-field. Both §2s read
//  PageHeader → page description → C-046 FieldGroup → C-051 AISuggestionsBlock → C-048 Save,
//  in one content column; they differ in C-046's `field`, in whether an empty value may be
//  saved, and in the server's length cap — each taken here as a parameter.
//  §5 endpoints, cited only — this view calls none: PATCH /api/groups/{id} · GET /api/groups/{id}
//  (the AI field-suggestion endpoint is an API-GAP in both screens' §5).
//  ui2-members-edit T9 a–f, routed to /ui2-resolve (F2): C-051 can be hidden (a), the inline
//  error line above Save (c), keyboard/focus/cap per field (d), a live C-045 field (e), a
//  caller-supplied save rule (f). Every addition is defaulted to today's render.
//  Wired by MakeReady/UI2/Containers/Members/MemberFieldEditContainer.swift (ui2-members-edit).
//

import SwiftUI

/// The layout both text-field edit screens share. Each screen is a thin wrapper that keeps its
/// own `State`, closures and `#Preview` blocks and passes its content in.
struct SharedEditFieldTemplate: View {
    /// §2: C-040's centered title — the field's short name.
    let title: String
    /// §2: the screen-owned page description.
    let description: String
    /// §2: C-046's label.
    let label: String
    /// §2: C-046's `field` — the one structural value the two screens differ by.
    let field: FieldGroup.Field
    /// §1: placeholder copy is undesigned per use; proposed default "".
    let placeholder: String
    /// §3: the value the page was loaded with — what `clean` / `dirty` compare against.
    let loadedValue: String
    /// §3 input sub-state: focused → C-046 `style=Focus` (the static render; the live field
    /// reports its own focus).
    let focused: Bool
    /// §3 `saving`: a save is in flight — Save disabled and the input locked, no spinner (D26).
    let saving: Bool
    /// §2: C-051's per-field prompt copy.
    let promptCopy: String
    /// §3: C-051's state — the screen owns the request, so the block's state is an input.
    let aiState: String
    /// §3: C-051's rows in `list` / `regenerating`.
    let suggestions: [String]
    /// §3: whether a trimmed-empty value may be saved (single: no → `invalid`; multi: yes).
    let allowsEmpty: Bool
    /// §3 Length: the silent hard cap at the server limit (§5's zod `max`).
    let maxLength: Int
    /// ui2-members-edit T9a (D3): false hides C-051 — no member field offers AI suggestions.
    let showsAISuggestions: Bool
    /// T9c (D13/D16): §3 `save-failed`'s inline error line directly above Save, drawn as
    /// edit-option-field draws it; "" renders no line.
    let errorMessage: String
    /// T9e: true → a live C-045 text field the user types into; false → the static render the
    /// previews and captures use.
    let editable: Bool
    /// T9d (D22): the live field's keyboard, content type, capitalization and correction.
    let keyboard: UIKeyboardType
    let textContentType: UITextContentType?
    let autocapitalization: TextInputAutocapitalization
    let autocorrect: Bool
    /// D22: the live field takes focus on appear.
    let focusOnAppear: Bool
    /// T9f (D24): when given, replaces the dirty/empty rule with the caller's (it receives the
    /// trimmed text); `saving` still disables Save.
    let canSave: ((String) -> Bool)?
    var onBack: () -> Void = {}
    var onGenerate: () -> Void = {}
    var onSave: (String) -> Void = { _ in }
    /// Every accepted edit (after the cap). No render effect.
    var onTextChange: (String) -> Void = { _ in }

    // §3 UI-only rule: "picking a suggestion replaces the input's text with it (→ `dirty`, or
    // `clean` if it equals the loaded value)" — the field's local text, seeded by the caller.
    @SwiftUI.State private var text: String
    /// The live field's focus as C-045 reports it; drives C-046 `style` when `editable`.
    @SwiftUI.State private var inputFocused = false

    init(
        title: String,
        description: String,
        label: String,
        field: FieldGroup.Field,
        placeholder: String,
        text: String,
        loadedValue: String,
        focused: Bool,
        saving: Bool,
        promptCopy: String,
        aiState: String,
        suggestions: [String],
        allowsEmpty: Bool,
        maxLength: Int,
        showsAISuggestions: Bool = true,
        errorMessage: String = "",
        editable: Bool = false,
        keyboard: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        autocapitalization: TextInputAutocapitalization = .sentences,
        autocorrect: Bool = true,
        focusOnAppear: Bool = false,
        canSave: ((String) -> Bool)? = nil,
        onBack: @escaping () -> Void = {},
        onGenerate: @escaping () -> Void = {},
        onSave: @escaping (String) -> Void = { _ in },
        onTextChange: @escaping (String) -> Void = { _ in }
    ) {
        self.title = title
        self.description = description
        self.label = label
        self.field = field
        self.placeholder = placeholder
        self.loadedValue = loadedValue
        self.focused = focused
        self.saving = saving
        self.promptCopy = promptCopy
        self.aiState = aiState
        self.suggestions = suggestions
        self.allowsEmpty = allowsEmpty
        self.maxLength = maxLength
        self.showsAISuggestions = showsAISuggestions
        self.errorMessage = errorMessage
        self.editable = editable
        self.keyboard = keyboard
        self.textContentType = textContentType
        self.autocapitalization = autocapitalization
        self.autocorrect = autocorrect
        self.focusOnAppear = focusOnAppear
        self.canSave = canSave
        self.onBack = onBack
        self.onGenerate = onGenerate
        self.onSave = onSave
        self.onTextChange = onTextChange
        _text = SwiftUI.State(initialValue: text)
    }

    var body: some View {
        // §2: top → bottom. The system status bar (deviation 2) is not drawn — the canvas is
        // set at the call site.
        VStack(spacing: 0) {
            // §2.2: C-040 `twoIcons`, `showIcons=false`, `leadingGlyph=back`, centered title.
            PageHeader(
                style: .twoIcons,
                title: title,
                showTitle: true,
                showIcons: false,
                leadingGlyph: .back,
                rightButtons: [],
                onLeading: onBack
            )
            .ui2Element("C-040 PageHeader")

            // §2.3: content column — padding `space-page-margin`, gap `space-section-gap`.
            VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
                // §2.3.1: screen-owned text, `type-page-title`, `color-text-secondary`, wraps.
                Text(description)
                    .designTextStyle(Token.TypeStyle.pageTitle)
                    .foregroundStyle(Token.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                // §2.3.2: C-046 `field` per screen, `style` per focus (§3; OQ-C-046-1 ruled).
                FieldGroup(
                    label: label,
                    field: field,
                    style: (editable ? inputFocused : focused) ? .focus : .default,
                    layout: .default,
                    text: text,
                    placeholder: placeholder,
                    editing: editable ? liveEditing : nil,
                    onChange: { typed in
                        text = Self.capped(typed, maxLength: maxLength)
                        onTextChange(text)
                    },
                    onFocusChange: { inputFocused = $0 }
                )
                .ui2Element("C-046 FieldGroup")

                // §2.3.3: C-051 — `prompt` as drawn; the screen drives its state (§3). T9a: a
                // caller may hide it (D3).
                if showsAISuggestions {
                    AISuggestionsBlock(
                        state: AISuggestionsBlock.State(rawValue: aiState) ?? .prompt,
                        promptCopy: promptCopy,
                        suggestions: suggestions,
                        onGenerate: onGenerate,
                        onPick: { text = Self.capped($0, maxLength: maxLength) }
                    )
                    .ui2Element("C-051 AISuggestionsBlock")
                }

                VStack(alignment: .leading, spacing: Token.Space.elementGap) {
                    // T9c — §3 `save-failed` (edit-option-field's proposed default,
                    // OQ-edit-option-field-2): "an inline error line sits in `type-page-title`
                    // `color-error` directly above Save". "" draws nothing, so the column is
                    // exactly today's.
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .designTextStyle(Token.TypeStyle.pageTitle)
                            .foregroundStyle(Token.error)
                            .frame(maxWidth: .infinity, minHeight: Self.lineBox, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // §2.3.4: C-048 "Save", `role=affirmative`, `isEnabled` per §3.
                    PageActionButton(
                        label: Self.saveLabel,
                        role: .affirmative,
                        enabled: saveEnabled,
                        onTap: { onSave(trimmed) }
                    )
                    .ui2Element("C-048 PageActionButton")
                }
            }
            .padding(Token.Space.pageMargin)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Token.layoutBackground)                 // §2: background
    }

    private var liveEditing: TextInput.Editing {
        TextInput.Editing(
            keyboard: keyboard,
            textContentType: textContentType,
            autocapitalization: autocapitalization,
            autocorrect: autocorrect,
            focusOnAppear: focusOnAppear,
            isEnabled: !saving,                              // D26: saving locks the input
            accessibilityName: label
        )
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var saveEnabled: Bool {
        Self.saveEnabled(text: text, loaded: loadedValue, allowsEmpty: allowsEmpty, saving: saving, canSave: canSave)
    }

    // §3: `clean` (equal to the loaded value) disables Save, and so does `invalid` (empty) where
    // the screen forbids an empty value; `dirty` enables it; `saving` disables it; `save-failed`
    // re-enables it. T9f (D24): a caller rule replaces clean/invalid, never `saving`.
    static func saveEnabled(
        text: String,
        loaded: String,
        allowsEmpty: Bool,
        saving: Bool,
        canSave: ((String) -> Bool)?
    ) -> Bool {
        guard !saving else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let canSave { return canSave(trimmed) }
        return (allowsEmpty || !trimmed.isEmpty)
            && trimmed != loaded.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// §3 Length: the silent hard cap — typed or picked text beyond it is dropped.
    static func capped(_ text: String, maxLength: Int) -> String { String(text.prefix(maxLength)) }

    // §2 content tables: the action's copy.
    private static let saveLabel = "Save"

    /// The designed line box of `type-page-title`.
    private static let lineBox: CGFloat = Token.TypeStyle.pageTitle.lineHeight ?? Token.TypeStyle.pageTitle.size
}
```

- [ ] **Step 6: EditTextSingleFieldScreen — replace the whole file** `iphone/MakeReadyUI/Screens/Fields/EditTextSingleFieldScreen.swift` with:

```swift
//
//  EditTextSingleFieldScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen edit-text-single-field in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: PATCH /api/groups/{id} · GET /api/groups/{id}
//  (the AI field-suggestion endpoint is an API-GAP in §5).
//  ui2-members-edit T9 a–f, routed to /ui2-resolve (F2): every addition to State is defaulted to
//  today's render. Wired by MakeReady/UI2/Containers/Members/MemberFieldEditContainer.swift.
//

import SwiftUI

/// Edit Text Single Field — a pushed page that edits ONE single-line text value of an entity
/// and saves it (§1). Composed only of §4's C-040, C-046 (→ C-045), C-051 (→ C-049) and C-048,
/// laid out by SharedEditFieldTemplate (D7).
struct EditTextSingleFieldScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        /// §2: C-040's centered title — the field's short name.
        var title: String
        /// §2: the screen-owned page description.
        var description: String
        /// §2: C-046's label.
        var label: String
        /// §1 deviation 4: placeholder copy is undesigned per use; proposed default "".
        var placeholder: String
        /// The input's current text.
        var text: String
        /// §3: the value the page was loaded with — what `clean` / `dirty` compare against.
        var loadedValue: String
        /// §3 input sub-state: focused → C-046 `style=Focus`.
        var focused: Bool
        /// §3 `saving`: a save is in flight.
        var saving: Bool
        /// §2: C-051's per-field prompt copy.
        var promptCopy: String
        /// §3: C-051's state — the screen owns the request, so the block's state is an input.
        var aiState: String
        /// §3: C-051's rows in `list` / `regenerating`.
        var suggestions: [String]
        /// T9b (ui2-members-edit D8): whether an empty value may be saved. Default false — §3:
        /// empty → `invalid`.
        var allowsEmpty: Bool = false
        /// §3 Length (OQ-edit-text-single-field-2 ruled): silent hard cap at the server limit —
        /// §5: `name: z.string().min(1).max(200)`. T9d: a caller may set its own (D22).
        var maxLength: Int = 200
        /// T9c: §3 `save-failed`'s inline error line above Save; "" renders none.
        var errorMessage: String = ""
        /// T9a (D3): false hides C-051.
        var showsAISuggestions: Bool = true
        /// T9e: true → a live text field; false → the static render previews and captures use.
        var editable: Bool = false
        /// T9d (D22): the live field's focus on appear, keyboard, content type, caps, correction.
        var focusOnAppear: Bool = false
        var keyboard: UIKeyboardType = .default
        var textContentType: UITextContentType? = nil
        var autocapitalization: TextInputAutocapitalization = .sentences
        var autocorrect: Bool = true
    }

    let state: State
    var onBack: () -> Void = {}
    var onGenerate: () -> Void = {}
    var onSave: (String) -> Void = { _ in }
    /// T9f (D24): replaces the dirty/empty rule when given; `saving` still disables Save.
    let canSave: ((String) -> Bool)?
    var onTextChange: (String) -> Void = { _ in }

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onGenerate: @escaping () -> Void = {},
        onSave: @escaping (String) -> Void = { _ in },
        canSave: ((String) -> Bool)? = nil,
        onTextChange: @escaping (String) -> Void = { _ in }
    ) {
        self.state = state
        self.onBack = onBack
        self.onGenerate = onGenerate
        self.onSave = onSave
        self.canSave = canSave
        self.onTextChange = onTextChange
    }

    var body: some View {
        // D7: the layout is shared with edit-text-multi-field — SharedEditFieldTemplate.swift.
        SharedEditFieldTemplate(
            title: state.title,
            description: state.description,
            label: state.label,
            field: .text,                                   // §2.3.2: C-046 `field=Text`
            placeholder: state.placeholder,
            text: state.text,
            loadedValue: state.loadedValue,
            focused: state.focused,
            saving: state.saving,
            promptCopy: state.promptCopy,
            aiState: state.aiState,
            suggestions: state.suggestions,
            allowsEmpty: state.allowsEmpty,                 // §3: default empty → `invalid`
            maxLength: state.maxLength,
            showsAISuggestions: state.showsAISuggestions,
            errorMessage: state.errorMessage,
            editable: state.editable,
            keyboard: state.keyboard,
            textContentType: state.textContentType,
            autocapitalization: state.autocapitalization,
            autocorrect: state.autocorrect,
            focusOnAppear: state.focusOnAppear,
            canSave: canSave,
            onBack: onBack,
            onGenerate: onGenerate,
            onSave: onSave,
            onTextChange: onTextChange
        )
    }
}

private extension EditTextSingleFieldScreen.State {
    /// §2's Group name content table, verbatim — the base every preview varies.
    static func groupName(
        text: String = "Young professionals",
        loadedValue: String = "Young professionals",
        saving: Bool = false
    ) -> Self {
        .init(
            title: "Group name",
            description: "The group name is the primary title for your group that will be surfaced anytime the group is displayed in a MakeReady app",
            label: "Group name",
            placeholder: "",
            text: text,
            loadedValue: loadedValue,
            focused: false,
            saving: saving,
            promptCopy: "If you need help coming up with a name for your group, MakeReady AI can analyze your content and provide suggestions.",
            aiState: "prompt",
            suggestions: []
        )
    }
}

#Preview("clean") {
    EditTextSingleFieldScreen(state: .groupName())
        .frame(width: 440, height: 494)
}

#Preview("dirty") {
    EditTextSingleFieldScreen(state: .groupName(loadedValue: "Young adults"))
        .frame(width: 440)
}

#Preview("invalid") {
    EditTextSingleFieldScreen(state: .groupName(text: ""))
        .frame(width: 440)
}

#Preview("saving") {
    EditTextSingleFieldScreen(state: .groupName(loadedValue: "Young adults", saving: true))
        .frame(width: 440)
}

#Preview("save-failed") {
    EditTextSingleFieldScreen(state: .groupName(loadedValue: "Young adults"))
        .frame(width: 440)
}
```

- [ ] **Step 7: EditTextMultiFieldScreen — replace the whole file** `iphone/MakeReadyUI/Screens/Fields/EditTextMultiFieldScreen.swift` with:

```swift
//
//  EditTextMultiFieldScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen edit-text-multi-field in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: PATCH /api/groups/{id} · GET /api/groups/{id}
//  (the AI field-suggestion endpoint is an API-GAP in §5).
//  ui2-members-edit T9 a, c–e, routed to /ui2-resolve (F2): every addition to State is defaulted
//  to today's render. Wired by MakeReady/UI2/Containers/Members/MemberFieldEditContainer.swift.
//

import SwiftUI

/// Edit Text Multi Field — a pushed page that edits ONE multi-line text value of an entity and
/// saves it (§1). Composed only of §4's C-040, C-046 (→ C-045), C-051 (→ C-049) and C-048,
/// laid out by SharedEditFieldTemplate (D7).
struct EditTextMultiFieldScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        /// §2: C-040's centered title — the field's short name.
        var title: String
        /// §2: the screen-owned page description.
        var description: String
        /// §2: C-046's label.
        var label: String
        /// §1 deviation 5: placeholder copy is undesigned per use; proposed default "".
        var placeholder: String
        /// The input's current text.
        var text: String
        /// §3: the value the page was loaded with — what `clean` / `dirty` compare against.
        var loadedValue: String
        /// §3 input sub-state: focused → C-046 `style=Focus`.
        var focused: Bool
        /// §3 `saving`: a save is in flight.
        var saving: Bool
        /// §2: C-051's per-field prompt copy.
        var promptCopy: String
        /// §3: C-051's state — the screen owns the request, so the block's state is an input.
        var aiState: String
        /// §3: C-051's rows in `list` / `regenerating`.
        var suggestions: [String]
        /// §3 Length (OQ-edit-text-multi-field-3 proposed default): silent hard cap at the server
        /// limit — §5: `description: z.string().max(2000)`. T9d: a caller may set its own.
        var maxLength: Int = 2000
        /// T9c: §3 `save-failed`'s inline error line above Save; "" renders none.
        var errorMessage: String = ""
        /// T9a (D3): false hides C-051.
        var showsAISuggestions: Bool = true
        /// T9e: true → a live text field; false → the static render previews and captures use.
        var editable: Bool = false
        /// T9d (D22): the live field's focus on appear, keyboard, content type, caps, correction.
        var focusOnAppear: Bool = false
        var keyboard: UIKeyboardType = .default
        var textContentType: UITextContentType? = nil
        var autocapitalization: TextInputAutocapitalization = .sentences
        var autocorrect: Bool = true
    }

    let state: State
    var onBack: () -> Void = {}
    var onGenerate: () -> Void = {}
    var onSave: (String) -> Void = { _ in }
    var onTextChange: (String) -> Void = { _ in }

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onGenerate: @escaping () -> Void = {},
        onSave: @escaping (String) -> Void = { _ in },
        onTextChange: @escaping (String) -> Void = { _ in }
    ) {
        self.state = state
        self.onBack = onBack
        self.onGenerate = onGenerate
        self.onSave = onSave
        self.onTextChange = onTextChange
    }

    var body: some View {
        // D7: the layout is shared with edit-text-single-field — SharedEditFieldTemplate.swift.
        SharedEditFieldTemplate(
            title: state.title,
            description: state.description,
            label: state.label,
            field: .multilineText,                          // §2.3.2: C-046 `field=Multiline Text`
            placeholder: state.placeholder,
            text: state.text,
            loadedValue: state.loadedValue,
            focused: state.focused,
            saving: state.saving,
            promptCopy: state.promptCopy,
            aiState: state.aiState,
            suggestions: state.suggestions,
            allowsEmpty: true,                              // §3 Empty value (OQ-edit-text-multi-field-2 default)
            maxLength: state.maxLength,
            showsAISuggestions: state.showsAISuggestions,
            errorMessage: state.errorMessage,
            editable: state.editable,
            keyboard: state.keyboard,
            textContentType: state.textContentType,
            autocapitalization: state.autocapitalization,
            autocorrect: state.autocorrect,
            focusOnAppear: state.focusOnAppear,
            onBack: onBack,
            onGenerate: onGenerate,
            onSave: onSave,
            onTextChange: onTextChange
        )
    }
}

private extension EditTextMultiFieldScreen.State {
    /// §2's Group description content table — the base every preview varies. The field label
    /// takes OQ-edit-text-multi-field-1's proposed default ("Group description"), not the
    /// frame's "Program description" (§1 deviation 4).
    static func groupDescription(
        loadedValue: String = "A group designed for young men who are out of college and are beginning their professional journey",
        saving: Bool = false
    ) -> Self {
        .init(
            title: "Description",
            description: "The group description is used to help others understand the purpose of your group at a glance.",
            label: "Group description",
            placeholder: "",
            text: "A group designed for young men who are out of college and are beginning their professional journey",
            loadedValue: loadedValue,
            focused: false,
            saving: saving,
            promptCopy: "If you need help writing a description for your group, MakeReady AI can analyze your content and provide suggestions.",
            aiState: "prompt",
            suggestions: []
        )
    }
}

#Preview("clean") {
    EditTextMultiFieldScreen(state: .groupDescription())
        .frame(width: 440, height: 516)
}

#Preview("dirty") {
    EditTextMultiFieldScreen(state: .groupDescription(loadedValue: ""))
        .frame(width: 440)
}

#Preview("saving") {
    EditTextMultiFieldScreen(state: .groupDescription(loadedValue: "", saving: true))
        .frame(width: 440)
}

#Preview("save-failed") {
    EditTextMultiFieldScreen(state: .groupDescription(loadedValue: ""))
        .frame(width: 440)
}
```

- [ ] **Step 8: Run the tests and watch them pass** — from the repo root `npm run ios:build-check -- --test` → PASS (the six new tests, and every existing `ViewRegistry` case still compiles: it builds `EditTextSingleFieldScreen.State`/`EditTextMultiFieldScreen.State`, `TextInput` and `FieldGroup` without the new defaulted props). Then `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 9: Commit** — iphone is `commit: auto` under `/builder:*`: `git add iphone/MakeReadyUI/TextInput.swift iphone/MakeReadyUI/FieldGroup.swift iphone/MakeReadyUI/Screens/Shared/SharedEditFieldTemplate.swift iphone/MakeReadyUI/Screens/Fields/EditTextSingleFieldScreen.swift iphone/MakeReadyUI/Screens/Fields/EditTextMultiFieldScreen.swift iphone/MakeReadyCaptureTests/UI2MembersEditComponentTests.swift iphone/MakeReady.xcodeproj/project.pbxproj && git commit -m "feat(ui2-members-edit): live text editing through C-045/C-046 and the shared edit-field template"`

### Task 6: MembersProfileScreen reports a MemberField key, per-row tappability (T10)
App: iphone
Phase: 2
Recipe: /ui2-resolve

> **d2m ownership (F2/F4).** `MakeReadyUI/Screens/Members/MembersProfileScreen.swift` is d2m-owned. This task changes it in code only (D1 rows tappable, D2 field-key callback, D27 gate, D28 Organization/Role never); after the build `/ui2-resolve` re-renders members-profile through the d2m harness and diffs it against its frozen snapshot. **Never write a UI 2.0 contract, registry row, token or note.** The new `fieldsEditable` flag defaults to `false`, so every preview and the `screen.2.0.members-profile` capture still render display-only rows exactly as today.

**Module boundary.** `MemberField` is declared in MakeReadyUI, but MakeReadyUI sources also compile INTO the `MakeReady` app module (`iphone/scripts/makereadyui-sync.rb`: every MakeReadyUI file is a member of targets `MakeReadyUI` and `MakeReady`). So the app's shell and containers use `MemberField` unqualified and without an import, and it stays internal like every other MakeReadyUI type — no `public` needed.

**Files:**
- Modify: `iphone/MakeReadyUI/Screens/Members/MembersProfileScreen.swift` — new top-level `enum MemberField` after `import SwiftUI` (:16); `State` gains `fieldsEditable` after `programCoverURLs` (:81); `onEditField` type (:91, :97, :103-114 init); replace `static let fieldsTappable` (:138-139); the field-row `ForEach` (:291-303)
- Modify: `iphone/MakeReadyCaptureTests/UI2MembersComponentTests.swift:72-78` (the browse test asserted the removed `fieldsTappable`)
- Test: `iphone/MakeReadyCaptureTests/UI2MembersEditComponentTests.swift` (append; created by Task 5)

**Interfaces:**
- Consumes: `EditableFieldRow(label:value:indicator:multiline:onTap:isTappable:)`; `MembersProfileScreen.fieldLabels` (unchanged).
- Produces:
  - `enum MemberField: String, CaseIterable { case email, phone, birthday, gender, address, emergencyName, emergencyPhone }` (Hashable by synthesis — `UI2Destination` carries it)
  - `MembersProfileScreen.State.fieldsEditable: Bool = false` (D27: the container sets it to `AppState.memberDetails[id] != nil`)
  - `MembersProfileScreen.init(state:showsHeader:onBack:onEditField: @escaping (MemberField) -> Void = { _ in }, onJumpToToday:onAddToGroup:onOpenGroup:onEnroll:)`
  - `static func field(forLabel label: String) -> MemberField?` — the 7 D1 labels map, Organization/Role → nil
  - `static func label(for field: MemberField) -> String` — the row label exactly: "Email address", "Phone number", "Birthday", "Gender", "Address", "Emergency contact", "Emergency phone" (Task 9 uses it as the edit page title, D14)
  - `static func isTappable(_ label: String, _ s: State) -> Bool` — `s.fieldsEditable && field(forLabel: label) != nil`
  - `static let fieldsTappable` is REMOVED.

- [ ] **Step 1: Write the failing tests** — append inside `final class UI2MembersEditComponentTests` in `iphone/MakeReadyCaptureTests/UI2MembersEditComponentTests.swift`, before the class's final closing brace:

```swift
    // MARK: - Task 6: MembersProfileScreen field keys (D1, D2, D27, D28)

    /// D2: a row reports its field KEY, never its label; Organization and Role have none (D28).
    func testEveryEditableRowMapsToItsFieldKey() {
        let expected: [String: MemberField] = [
            "Email address": .email, "Phone number": .phone, "Birthday": .birthday, "Gender": .gender,
            "Address": .address, "Emergency contact": .emergencyName, "Emergency phone": .emergencyPhone
        ]
        for (label, field) in expected {
            XCTAssertEqual(MembersProfileScreen.field(forLabel: label), field, label)
            XCTAssertEqual(MembersProfileScreen.label(for: field), label)
        }
        XCTAssertNil(MembersProfileScreen.field(forLabel: "Organization"))
        XCTAssertNil(MembersProfileScreen.field(forLabel: "Role"))
        XCTAssertEqual(MemberField.allCases.map(\.rawValue),
                       ["email", "phone", "birthday", "gender", "address", "emergencyName", "emergencyPhone"])
    }

    /// D1 + D27: exactly the 7 rows are tappable, and only once the member is loaded; the
    /// previews' samples stay display-only.
    func testRowsAreTappableOnlyOnceTheMemberLoaded() {
        var s = MembersProfileScreen.State.populated
        XCTAssertFalse(s.fieldsEditable)
        for label in MembersProfileScreen.fieldLabels {
            XCTAssertFalse(MembersProfileScreen.isTappable(label, s), label)
        }
        s.fieldsEditable = true
        XCTAssertEqual(MembersProfileScreen.fieldLabels.filter { MembersProfileScreen.isTappable($0, s) }, [
            "Phone number", "Email address", "Birthday", "Gender", "Address", "Emergency contact", "Emergency phone"
        ])
    }
```

and in `iphone/MakeReadyCaptureTests/UI2MembersComponentTests.swift`, replace lines 72-78 (the `testMemberPageDrawsNineDisplayOnlyFields` body's doc comment through its closing brace) with:

```swift
    /// P6: nine rows, "Emergency phone" last; the samples stay display-only (ui2-members-edit
    /// D27 — `fieldsEditable` defaults false; browse D3's blanket flag is gone).
    func testMemberPageDrawsNineDisplayOnlyFields() {
        XCTAssertEqual(MembersProfileScreen.fieldLabels, [
            "Organization", "Role", "Phone number", "Email address", "Birthday",
            "Gender", "Address", "Emergency contact", "Emergency phone"
        ])
        XCTAssertFalse(MembersProfileScreen.isTappable("Email address", .populated))
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL (compile): "cannot find type 'MemberField' in scope", "type 'MembersProfileScreen' has no member 'isTappable'", "value of type 'MembersProfileScreen.State' has no member 'fieldsEditable'".

- [ ] **Step 3: Write the minimal implementation** — in `iphone/MakeReadyUI/Screens/Members/MembersProfileScreen.swift`:

(a) Directly after `import SwiftUI` (line 16), insert:

```swift

/// ui2-members-edit D2 (P3): the member fields a leader edits from this page — the key a C-042
/// row reports, never its label. MakeReadyUI compiles into the app module too, so the shell's
/// `UI2Destination.editMemberField` and the edit container use this same type.
enum MemberField: String, CaseIterable {
    case email, phone, birthday, gender, address, emergencyName, emergencyPhone
}
```

(b) In `struct State`, directly after `var programCoverURLs: [String]` (line 81), insert:

```swift
        // ── ui2-members-edit D27 ──
        /// The 7 D1 rows are tappable only when the member's detail is loaded. Defaulted false:
        /// the previews and the capture case render display-only rows, as before.
        var fieldsEditable: Bool = false
```

(c) Replace line 91:

```swift
    var onEditField: (String) -> Void = { _ in }    // C-042 tap → shared-edit-field (OQ-1), by label
```

with:

```swift
    var onEditField: (MemberField) -> Void = { _ in }  // C-042 tap → shared-edit-field (OQ-1), by field key (D2)
```

and in `init(...)` replace the parameter line `onEditField: @escaping (String) -> Void = { _ in },` with:

```swift
        onEditField: @escaping (MemberField) -> Void = { _ in },
```

(d) Replace lines 138-139:

```swift
    /// D3: every C-042 row on this page is display-only in this child (child 2 enables them).
    static let fieldsTappable = false
```

with:

```swift
    /// ui2-members-edit D2: the field a row edits — the 7 D1 rows; Organization and Role edit
    /// nothing (D28 / OQ-C-042-3: they keep `isTappable: false`).
    static func field(forLabel label: String) -> MemberField? {
        MemberField.allCases.first { Self.label(for: $0) == label }
    }

    /// D14: the row label, verbatim — also the edit page's title.
    static func label(for field: MemberField) -> String {
        switch field {
        case .email: return emailLabel
        case .phone: return phoneLabel
        case .birthday: return birthdayLabel
        case .gender: return genderLabel
        case .address: return addressLabel
        case .emergencyName: return emergencyContactLabel
        case .emergencyPhone: return emergencyPhoneLabel
        }
    }

    /// D1 + D27: a row is tappable iff it edits a field and the member is loaded.
    static func isTappable(_ label: String, _ s: State) -> Bool {
        s.fieldsEditable && field(forLabel: label) != nil
    }
```

(e) In `private var fields`, replace the `EditableFieldRow(...)` call (lines 293-300) with:

```swift
                EditableFieldRow(
                    label: label,
                    value: Self.fieldValue(label, state),
                    indicator: Self.indicator(forField: label, state: state),
                    multiline: label == Self.addressLabel,              // P7
                    onTap: { if let field = Self.field(forLabel: label) { onEditField(field) } },   // D2
                    isTappable: Self.isTappable(label, state)           // D1 + D27
                )
```

Also update the header comment line 13 (`//  `age` as a String (D10), the rail opening on today (D12).`) by appending one line after it:

```swift
//  ui2-members-edit edits, routed to /ui2-resolve (F2): the 7 D1 rows tappable once loaded (D27),
//  `onEditField` reports a MemberField key (D2); Organization and Role stay display-only (D28).
```

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (`MemberProfileContainer` still compiles: it passes no `onEditField`; `ViewRegistry`'s members-profile case builds `State` without `fieldsEditable`). Then `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 5: Commit** — `git add iphone/MakeReadyUI/Screens/Members/MembersProfileScreen.swift iphone/MakeReadyCaptureTests/UI2MembersComponentTests.swift iphone/MakeReadyCaptureTests/UI2MembersEditComponentTests.swift && git commit -m "feat(ui2-members-edit): member page rows report a MemberField key and turn tappable once loaded"`

### Task 7: New EditDateFieldScreen (T11 — D3, D9, D13, D26, D28)
App: iphone
Phase: 2
Recipe: /ui2-resolve

> **d2m ownership (F2/F4).** This is a NEW MakeReadyUI view the design does not yet draw (P10: birthday as a native wheel). It is UNBUILT in d2m: after the build `/ui2-resolve` routes it to be drawn and captured through the d2m harness. **Do not add a `ViewRegistry` case or capture fixture, and never write a UI 2.0 contract, registry row, token or note.** It composes only existing components — C-040 `PageHeader`, C-049 `LinkButton` (as built, accent — D28 / OQ-shared-edit-field-4), C-048 `PageActionButton` — plus a system `DatePicker(.wheel)`; anything undesigned (the "Not set" line's type, the wheel's dark scheme) is marked `GAP` in a comment for /ui2-resolve.

**Files:**
- Create: `iphone/MakeReadyUI/Screens/Fields/EditDateFieldScreen.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — via `ruby scripts/makereadyui-sync.rb` (adds every MakeReadyUI `.swift` to targets `MakeReadyUI` + `MakeReady`) then `ruby scripts/capture-targets.rb` (mirrors into `MakeReadyCapture`) — Step 3
- Test: `iphone/MakeReadyCaptureTests/UI2MembersEditComponentTests.swift` (append; created by Task 5)

**Interfaces:**
- Consumes: `PageHeader(style:title:showTitle:showIcons:leadingGlyph:rightButtons:onLeading:)`, `LinkButton(label:style:onTap:isEnabled:)`, `PageActionButton(label:role:enabled:onTap:)`, `Token.TypeStyle.pageTitle` / `.valueEmphasis`, `Token.textSecondary`, `Token.error`, `Token.layoutBackground`, `Token.Space.*`.
- Produces:
  - `struct EditDateFieldScreen: View` with `struct State { var title: String; var description: String; var loadedValue: DateComponents?; var selectedValue: DateComponents?; var minDate: Date; var maxDate: Date; var saving: Bool = false; var errorMessage: String = "" }` — `selectedValue` seeds the page's current value (nil = "Not set"); the container passes `selectedValue == loadedValue`, so the page opens `clean`
  - `init(state: State, onBack: @escaping () -> Void = {}, onSave: @escaping (DateComponents?) -> Void = { _ in })` — `onSave(nil)` clears
  - statics: `day(_ c: DateComponents?) -> DateComponents?` (keeps year/month/day only), `isDirty(value: DateComponents?, loaded: DateComponents?) -> Bool`, `saveEnabled(value:loaded:saving:) -> Bool`, `clearEnabled(value: DateComponents?, saving: Bool) -> Bool`, `unsetWheelStart: DateComponents` (2000-01-01), `wheelStart(loaded: DateComponents?, min: Date, max: Date, calendar: Calendar) -> Date`, `components(of date: Date, calendar: Calendar) -> DateComponents`
  - Values are calendar-free `DateComponents(year:month:day:)` in LOCAL terms (D9): the wheel shows them via `Calendar.current`; the container builds them from the stored UTC calendar date and sends them back as `YYYY-MM-DD`.

- [ ] **Step 1: Write the failing tests** — append inside `final class UI2MembersEditComponentTests`, before its final closing brace:

```swift
    // MARK: - Task 7: EditDateFieldScreen (D3, D9, D13, D26)

    private var june25: DateComponents { DateComponents(year: 1974, month: 6, day: 25) }

    /// D9 / D13: dirty compares the calendar day only; Clear on a set value is dirty; any wheel
    /// value over a stored null is dirty; null over null is clean.
    func testDateDirtyRuleComparesTheCalendarDayOnly() {
        XCTAssertFalse(EditDateFieldScreen.isDirty(value: june25, loaded: june25))
        XCTAssertFalse(EditDateFieldScreen.isDirty(value: DateComponents(year: 1974, month: 6, day: 25, hour: 9), loaded: june25))
        XCTAssertTrue(EditDateFieldScreen.isDirty(value: DateComponents(year: 1974, month: 6, day: 26), loaded: june25))
        XCTAssertTrue(EditDateFieldScreen.isDirty(value: nil, loaded: june25))
        XCTAssertTrue(EditDateFieldScreen.isDirty(value: june25, loaded: nil))
        XCTAssertFalse(EditDateFieldScreen.isDirty(value: nil, loaded: nil))
    }

    /// D13 / D26: `saving` disables Save and Clear; D9: Clear is disabled when already "Not set".
    func testDateSaveAndClearEnablement() {
        XCTAssertTrue(EditDateFieldScreen.saveEnabled(value: nil, loaded: june25, saving: false))
        XCTAssertFalse(EditDateFieldScreen.saveEnabled(value: june25, loaded: june25, saving: false))
        XCTAssertFalse(EditDateFieldScreen.saveEnabled(value: nil, loaded: june25, saving: true))
        XCTAssertFalse(EditDateFieldScreen.clearEnabled(value: nil, saving: false))
        XCTAssertTrue(EditDateFieldScreen.clearEnabled(value: june25, saving: false))
        XCTAssertFalse(EditDateFieldScreen.clearEnabled(value: june25, saving: true))
    }

    /// D9: the wheel opens on the value, or on 2000-01-01 when "Not set", and never outside its range.
    func testDateWheelStartsAtTheValueOr2000AndStaysInRange() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Denver")!
        let min = cal.date(from: DateComponents(year: 1900, month: 1, day: 1))!
        let max = cal.date(from: DateComponents(year: 2026, month: 10, day: 26))!
        let unset = EditDateFieldScreen.wheelStart(loaded: nil, min: min, max: max, calendar: cal)
        XCTAssertEqual(EditDateFieldScreen.components(of: unset, calendar: cal), DateComponents(year: 2000, month: 1, day: 1))
        let set = EditDateFieldScreen.wheelStart(loaded: june25, min: min, max: max, calendar: cal)
        XCTAssertEqual(EditDateFieldScreen.components(of: set, calendar: cal), june25)
        XCTAssertEqual(EditDateFieldScreen.wheelStart(loaded: DateComponents(year: 2030, month: 1, day: 1), min: min, max: max, calendar: cal), max)
        XCTAssertEqual(EditDateFieldScreen.wheelStart(loaded: DateComponents(year: 1850, month: 1, day: 1), min: min, max: max, calendar: cal), min)
    }

    func testDateDayDropsEverythingButTheCalendarDay() {
        XCTAssertEqual(EditDateFieldScreen.day(DateComponents(year: 1974, month: 6, day: 25, hour: 3, minute: 4)), june25)
        XCTAssertNil(EditDateFieldScreen.day(DateComponents(year: 1974, month: 6)))
        XCTAssertNil(EditDateFieldScreen.day(nil))
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL (compile): "cannot find 'EditDateFieldScreen' in scope".

- [ ] **Step 3: Write the minimal implementation** — create `iphone/MakeReadyUI/Screens/Fields/EditDateFieldScreen.swift`:

```swift
//
//  EditDateFieldScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  ui2-members-edit (new, T11): the shared-edit-field date arrangement (P10, D3) — a pushed page
//  that edits ONE calendar date and saves it. C-040 header → page description → "Not set" line
//  (when empty) → native wheel DatePicker → C-049 "Clear" → inline error line → C-048 Save.
//  States as the other shared-edit-field screens: clean · dirty · saving (Save disabled, input
//  locked, no spinner — D26) · save-failed (inline error line above Save).
//  UNBUILT in d2m — routed to /ui2-resolve to be drawn and captured (P10, F2, F4). This view
//  calls no endpoint. Wired by MakeReady/UI2/Containers/Members/MemberFieldEditContainer.swift.
//

import SwiftUI

/// Edit Date Field — one calendar date, picked on a native wheel, clearable to "Not set".
/// Values are calendar-free `DateComponents(year:month:day:)` in local terms (D9): the caller
/// converts the stored date to them and back, so no instant ever crosses a time zone here.
struct EditDateFieldScreen: View {

    /// One state's inputs. Every state is reachable by these alone.
    struct State {
        /// C-040's centred title — the field name.
        var title: String
        /// The screen-owned page description.
        var description: String
        /// The value the page was loaded with — what `clean` / `dirty` compare against. nil = "Not set".
        var loadedValue: DateComponents?
        /// The value the page opens with (the loaded value in the app; previews vary it). nil = "Not set".
        var selectedValue: DateComponents?
        /// The wheel's range (D9: 1900-01-01 … today, device local).
        var minDate: Date
        var maxDate: Date
        /// `saving`: a save is in flight.
        var saving: Bool = false
        /// `save-failed`: the inline error line's copy; "" renders no line.
        var errorMessage: String = ""
    }

    let state: State
    var onBack: () -> Void = {}
    /// The chosen day, or nil to clear.
    var onSave: (DateComponents?) -> Void = { _ in }

    /// The page's current value — nil while "Not set" (local UI state, seeded from `State`).
    @SwiftUI.State private var value: DateComponents?
    /// What the wheel shows; it keeps its position when Clear sets `value` to nil.
    @SwiftUI.State private var wheelDate: Date

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onSave: @escaping (DateComponents?) -> Void = { _ in }
    ) {
        self.state = state
        self.onBack = onBack
        self.onSave = onSave
        let start = Self.day(state.selectedValue)
        _value = SwiftUI.State(initialValue: start)
        _wheelDate = SwiftUI.State(initialValue: Self.wheelStart(
            loaded: start, min: state.minDate, max: state.maxDate, calendar: .current
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // C-040 `twoIcons`, `showIcons=false`, leading glyph `back`, centred title — as the
            // other shared-edit-field screens.
            PageHeader(
                style: .twoIcons,
                title: state.title,
                showTitle: true,
                showIcons: false,
                leadingGlyph: .back,
                rightButtons: [],
                onLeading: onBack
            )
            .ui2Element("C-040 PageHeader")

            // Content column — inset `space-page-margin`, `space-section-gap` between parts.
            VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
                Text(state.description)
                    .designTextStyle(Token.TypeStyle.pageTitle)
                    .foregroundStyle(Token.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: Self.lineBox, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: Token.Space.elementGap) {
                    // D9: an empty value says so above the wheel.
                    // GAP — undesigned: `type-value-emphasis` `color-text-secondary` proposed.
                    if value == nil {
                        Text(Self.notSetLabel)
                            .designTextStyle(Token.TypeStyle.valueEmphasis)
                            .foregroundStyle(Token.textSecondary)
                            .ui2Element("Not set")
                    }

                    DatePicker(
                        state.title,
                        selection: wheelBinding,
                        in: Self.range(min: state.minDate, max: state.maxDate),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    // GAP — undesigned: the system wheel in the dark scheme over
                    // `color-layout-background`.
                    .environment(\.colorScheme, .dark)
                    .frame(maxWidth: .infinity)
                    .disabled(state.saving)                          // D26: input locked
                    .ui2Element("DatePicker")

                    // D28 / OQ-shared-edit-field-4: C-049 as built (accent).
                    LinkButton(
                        label: Self.clearLabel,
                        onTap: { value = nil },
                        isEnabled: Self.clearEnabled(value: value, saving: state.saving)
                    )
                    .ui2Element("C-049 LinkButton")
                }

                VStack(alignment: .leading, spacing: Token.Space.elementGap) {
                    // `save-failed`: the inline error line in `type-page-title` `color-error`
                    // directly above Save (edit-option-field's proposed default).
                    if !state.errorMessage.isEmpty {
                        Text(state.errorMessage)
                            .designTextStyle(Token.TypeStyle.pageTitle)
                            .foregroundStyle(Token.error)
                            .frame(maxWidth: .infinity, minHeight: Self.lineBox, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    PageActionButton(
                        label: Self.saveLabel,
                        role: .affirmative,
                        enabled: Self.saveEnabled(value: value, loaded: state.loadedValue, saving: state.saving),
                        onTap: { onSave(value) }
                    )
                    .ui2Element("C-048 PageActionButton")
                }
            }
            .padding(Token.Space.pageMargin)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Token.layoutBackground)
    }

    /// Any wheel movement sets the value (D9: from "Not set" that is dirty).
    private var wheelBinding: Binding<Date> {
        Binding(
            get: { wheelDate },
            set: { date in
                wheelDate = date
                value = Self.components(of: date, calendar: .current)
            }
        )
    }

    // MARK: - Rules (pure)

    /// The calendar day of `c` — year, month and day only; nil when any is missing.
    static func day(_ c: DateComponents?) -> DateComponents? {
        guard let year = c?.year, let month = c?.month, let day = c?.day else { return nil }
        return DateComponents(year: year, month: month, day: day)
    }

    /// `clean` ⇔ the same calendar day (or both "Not set").
    static func isDirty(value: DateComponents?, loaded: DateComponents?) -> Bool {
        day(value) != day(loaded)
    }

    /// `clean` and `saving` disable Save; `dirty` and `save-failed` enable it.
    static func saveEnabled(value: DateComponents?, loaded: DateComponents?, saving: Bool) -> Bool {
        !saving && isDirty(value: value, loaded: loaded)
    }

    /// D9: Clear is disabled when the value is already "Not set"; D26: and while saving.
    static func clearEnabled(value: DateComponents?, saving: Bool) -> Bool {
        !saving && day(value) != nil
    }

    /// D9: a "Not set" page opens the wheel on 2000-01-01.
    static let unsetWheelStart = DateComponents(year: 2000, month: 1, day: 1)

    /// The wheel's opening date — the value (or 2000-01-01), clamped into min…max.
    static func wheelStart(loaded: DateComponents?, min: Date, max: Date, calendar: Calendar) -> Date {
        let bounds = range(min: min, max: max)
        guard let date = calendar.date(from: day(loaded) ?? unsetWheelStart) else { return bounds.upperBound }
        return Swift.min(Swift.max(date, bounds.lowerBound), bounds.upperBound)
    }

    /// The calendar day `date` falls on in `calendar`.
    static func components(of date: Date, calendar: Calendar) -> DateComponents {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return DateComponents(year: c.year, month: c.month, day: c.day)
    }

    /// A range that cannot trap when a caller passes max < min.
    private static func range(min: Date, max: Date) -> ClosedRange<Date> {
        min...Swift.max(min, max)
    }

    private static let notSetLabel = "Not set"
    private static let clearLabel = "Clear"
    private static let saveLabel = "Save"

    /// The designed line box of `type-page-title`.
    private static let lineBox: CGFloat = Token.TypeStyle.pageTitle.lineHeight ?? Token.TypeStyle.pageTitle.size
}

private extension EditDateFieldScreen.State {
    static var previewCalendar: Calendar { Calendar(identifier: .gregorian) }

    /// The member Birthday Use (D14 copy) — the base every preview varies.
    static func birthday(
        loaded: DateComponents? = DateComponents(year: 1974, month: 6, day: 25),
        selected: DateComponents? = DateComponents(year: 1974, month: 6, day: 25),
        saving: Bool = false,
        errorMessage: String = ""
    ) -> Self {
        .init(
            title: "Birthday",
            description: "Used to show this member's age to group leaders.",
            loadedValue: loaded,
            selectedValue: selected,
            minDate: previewCalendar.date(from: DateComponents(year: 1900, month: 1, day: 1)) ?? .distantPast,
            maxDate: previewCalendar.date(from: DateComponents(year: 2026, month: 10, day: 26)) ?? Date(),
            saving: saving,
            errorMessage: errorMessage
        )
    }
}

#Preview("clean") {
    EditDateFieldScreen(state: .birthday())
        .frame(width: 440)
}

#Preview("dirty") {
    EditDateFieldScreen(state: .birthday(selected: DateComponents(year: 1975, month: 6, day: 25)))
        .frame(width: 440)
}

#Preview("saving") {
    EditDateFieldScreen(state: .birthday(selected: DateComponents(year: 1975, month: 6, day: 25), saving: true))
        .frame(width: 440)
}

#Preview("save-failed") {
    EditDateFieldScreen(state: .birthday(selected: DateComponents(year: 1975, month: 6, day: 25), errorMessage: "Couldn't save. Try again."))
        .frame(width: 440)
}

#Preview("not-set") {
    EditDateFieldScreen(state: .birthday(loaded: nil, selected: nil))
        .frame(width: 440)
}
```

Register it (from `iphone/`) — MakeReadyUI is synced by folder, the capture target mirrors the app:

```bash
cd iphone && ruby scripts/makereadyui-sync.rb && ruby scripts/capture-targets.rb && ruby scripts/capture-targets.rb --check
```
→ the sync prints `added: Screens/Fields/EditDateFieldScreen.swift, Screens/Fields/EditDateFieldScreen.swift (MakeReady)`; the last command exits 0 (in sync).

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (four new tests). Then `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations (no force unwraps in the new file — the preview dates fall back with `??`).

- [ ] **Step 5: Commit** — `git add iphone/MakeReadyUI/Screens/Fields/EditDateFieldScreen.swift iphone/MakeReadyCaptureTests/UI2MembersEditComponentTests.swift iphone/MakeReady.xcodeproj/project.pbxproj && git commit -m "feat(ui2-members-edit): EditDateFieldScreen — wheel date page with Clear and inline error"`

### Task 8: Status-bearing PATCH + MemberActions.updateMember (T6, T7 — D13, D15, D21)
App: iphone
Phase: 3
Recipe: /ios-error-surface

**Why the new call (T6).** `APIClient.performRequest` turns EVERY non-2xx carrying `error` into `APIError.serverError(String)` and drops the status — and a 500 carries `error` too — so D13's "400/409 → the server's text, anything else → generic" split cannot be made from it. Existing throws stay exactly as they are: `EnrollmentActions.swift:454` and `UserFacingErrorFormatter.swift:117,137,160` match `.serverError`. The status rides a SEPARATE error type (`APIHTTPError`, not a new `APIError` case — a new case would break every exhaustive `switch` on `APIError`), thrown ONLY by the new `requestWithStatus`. A 401 still throws `APIError.unauthorized`, so `AuthStatusPolicy.shouldSignOut(after:)` keeps working.

**Files:**
- Modify: `iphone/MakeReady/State/API/APIClient.swift` — `APIHTTPError` after the `APIError` enum (:43); `requestWithStatus` + `statusError` inside `final class APIClient`, directly before the doc comment `/// Execute a request and decode the response` (~:190); the protocol requirement in `protocol APIClientProtocol` (:411-420)
- Modify: `iphone/MakeReadyCaptureTests/StubAPIClient.swift` (conform to the new requirement, after `request(endpoint:method:body:timeout:)` at :72)
- Modify: `iphone/MakeReady/State/Models/MemberModels.swift` (append `MemberPatch`, `MemberSaveError` at the end of the file)
- Modify: `iphone/MakeReady/State/Actions/MemberActions.swift` (new section before `// MARK: - Helpers`, :97)
- Test: `iphone/MakeReadyCaptureTests/MemberActionsTests.swift` (append)

**Interfaces:**
- Consumes: `APIClient.buildRequest(endpoint:method:body:timeout:)` (private, same type), `AppState.initialLoad.generation` / `.isCurrent(_:)`, `AppState.memberDetails` (`EntityStore<MemberDetail>`: `subscript`, `upsert`, `update(_:transform:)`), `AppState.recordError(_:context:surface:)`, `AuthStatusPolicy.shouldSignOut(after:)`, `MemberActions.loadMember(_:)`, `StubAPIClient` (`stub`, `errorFor`, `beforeReturn`, `calls`, `callCount`).
- Produces:
  - `struct APIHTTPError: LocalizedError, Equatable { let status: Int; let message: String? }`
  - `APIClient.requestWithStatus(endpoint: String, method: String, body: [String: Any]?) async throws -> Data` and `static func statusError(status: Int, data: Data) -> Error?` (nil for 2xx; `APIError.unauthorized` for 401; else `APIHTTPError(status:, message: body["error"] as? String)`)
  - `APIClientProtocol.requestWithStatus(endpoint:method:body:) async throws -> Data` (requirement; `StubAPIClient` implements it by recording through its `request` path)
  - `enum MemberPatch: Equatable { case email(String?), phoneNumber(String?), birthday(String?), gender(String?), address(String?), emergencyContactName(String?), emergencyContactPhone(String?) }` with `var key: String` (the D15 wire key), `var value: String?`, `var jsonValue: Any` (value or `NSNull()`), `var body: [String: Any]` (`[key: jsonValue]`)
  - `enum MemberSaveError: Error, Equatable { case validation(String), generic }`
  - `MemberActions.saveFailedMessage = "Couldn't save. Try again."` (static)
  - `@MainActor func updateMember(_ id: String, _ patch: MemberPatch) async -> Result<Void, MemberSaveError>`
  - `static func applying(_ patch: MemberPatch, to detail: MemberDetail) -> MemberDetail` (D21; a changed phone also sets `phoneVerified = false`; a birthday `YYYY-MM-DD` is stored as `YYYY-MM-DDT00:00:00.000Z`, the GET's shape the mapper parses)

- [ ] **Step 1: Write the failing tests** — append inside `final class MemberActionsTests` in `iphone/MakeReadyCaptureTests/MemberActionsTests.swift`, before its final closing brace:

```swift
    // MARK: - ui2-members-edit Task 8: updateMember (T6, T7 — D13, D15, D21)

    private func isSuccess(_ result: Result<Void, MemberSaveError>) -> Bool {
        if case .success = result { return true }
        return false
    }

    private func failure(_ result: Result<Void, MemberSaveError>) -> MemberSaveError? {
        if case .failure(let error) = result { return error }
        return nil
    }

    private func patchCall() -> StubAPIClient.RecordedCall? { api.calls.first { $0.method == "PATCH" } }

    /// T6: the status survives; 401 stays `.unauthorized` (sign-out policy unchanged).
    func testStatusErrorKeepsTheStatusAndTheServersMessage() {
        XCTAssertNil(APIClient.statusError(status: 200, data: Data()))
        XCTAssertNil(APIClient.statusError(status: 204, data: Data()))
        let unauthorized = APIClient.statusError(status: 401, data: Data(#"{"error":"nope"}"#.utf8))
        XCTAssertTrue(AuthStatusPolicy.shouldSignOut(after: unauthorized ?? APIError.invalidResponse))
        let taken = Data(#"{"success":false,"error":"That number belongs to another member","code":"PHONE_TAKEN"}"#.utf8)
        XCTAssertEqual(APIClient.statusError(status: 409, data: taken) as? APIHTTPError,
                       APIHTTPError(status: 409, message: "That number belongs to another member"))
        XCTAssertEqual(APIClient.statusError(status: 502, data: Data("<html>".utf8)) as? APIHTTPError,
                       APIHTTPError(status: 502, message: nil))
    }

    /// D15: the wire keys, and a clear is JSON null.
    func testPatchKeysAreTheWireKeysAndNilIsNull() {
        let patches: [MemberPatch] = [.email(nil), .phoneNumber("+1"), .birthday(nil), .gender(nil), .address(nil),
                                      .emergencyContactName(nil), .emergencyContactPhone(nil)]
        XCTAssertEqual(patches.map(\.key), ["email", "phoneNumber", "birthday", "gender", "address",
                                            "emergencyContactName", "emergencyContactPhone"])
        XCTAssertTrue(MemberPatch.gender(nil).jsonValue is NSNull)
        XCTAssertEqual(MemberPatch.gender("male").jsonValue as? String, "male")
        XCTAssertEqual(MemberPatch.address("1 Main").body.keys.sorted(), ["address"])
    }

    /// D15: one key PATCHed, then the member re-read with GET (the reload wins).
    func testUpdateMemberPatchesOneKeyThenReloads() async {
        state.memberDetails.upsert(MemberDetail(id: "m1", email: "old@stark.example"))
        api.stub("PATCH", "/api/members/m1", json: #"{"success":true,"data":{"id":"m1"}}"#)
        api.stub("GET", "/api/members/m1", json: #"{"success":true,"data":{"id":"m1","phoneVerified":true,"email":"new@stark.example"}}"#)
        let result = await actions().updateMember("m1", .email("new@stark.example"))
        XCTAssertTrue(isSuccess(result))
        XCTAssertEqual(patchCall()?.endpoint, "/api/members/m1")
        XCTAssertEqual(patchCall()?.body?.keys.sorted(), ["email"])
        XCTAssertEqual(patchCall()?.body?["email"] as? String, "new@stark.example")
        XCTAssertEqual(api.callCount("GET", "/api/members/m1"), 1)
        XCTAssertEqual(state.memberDetails["m1"]?.email, "new@stark.example")
        XCTAssertEqual(state.memberDetails["m1"]?.phoneVerified, true)
    }

    /// D8 / D15: a clear sends JSON null for the one key.
    func testClearSendsJSONNull() async {
        api.stub("PATCH", "/api/members/m1", json: #"{"success":true}"#)
        api.stub("GET", "/api/members/m1", json: #"{"success":true,"data":{"id":"m1"}}"#)
        _ = await actions().updateMember("m1", .address(nil))
        XCTAssertEqual(patchCall()?.body?.keys.sorted(), ["address"])
        XCTAssertTrue(patchCall()?.body?["address"] is NSNull)
    }

    /// D13: 409 → the server's text; nothing written, no reload, nothing recorded.
    func test409ReturnsTheServersMessageAndWritesNothing() async {
        let before = MemberDetail(id: "m1", phoneNumber: "+15550100009")
        state.memberDetails.upsert(before)
        api.errorFor = { _, body in
            body == nil ? nil : APIHTTPError(status: 409, message: "That number belongs to another member") as Error
        }
        let result = await actions().updateMember("m1", .phoneNumber("+15550100001"))
        XCTAssertEqual(failure(result), .validation("That number belongs to another member"))
        XCTAssertEqual(state.memberDetails["m1"], before)
        XCTAssertEqual(api.callCount("GET", "/api/members/m1"), 0)
        XCTAssertTrue(state.errors.isEmpty)
    }

    /// D13: 400 and 403 carry the server's text; a missing one falls back to the generic line.
    func test400And403CarryTheMessageOrTheFallback() async {
        api.errorFor = { _, body in body == nil ? nil : APIHTTPError(status: 400, message: "Enter a valid email") as Error }
        let invalid = await actions().updateMember("m1", .email("a@b"))
        XCTAssertEqual(failure(invalid), .validation("Enter a valid email"))
        api.errorFor = { _, body in body == nil ? nil : APIHTTPError(status: 403, message: nil) as Error }
        let refused = await actions().updateMember("m1", .phoneNumber("+15550100001"))
        XCTAssertEqual(failure(refused), .validation("Couldn't save. Try again."))
        XCTAssertTrue(state.errors.isEmpty)
    }

    /// D13: anything else — 500, 404, a network failure — is generic, recorded console-only.
    func test500IsGenericAndRecordedConsoleOnly() async {
        api.errorFor = { _, body in body == nil ? nil : APIHTTPError(status: 500, message: "Failed to update member") as Error }
        let crashed = await actions().updateMember("m1", .gender("male"))
        XCTAssertEqual(failure(crashed), .generic)
        XCTAssertEqual(state.errors.last?.context, "MemberActions.updateMember")
        XCTAssertEqual(state.errors.last?.surface, false)
        api.errorFor = { _, body in body == nil ? nil : APIHTTPError(status: 404, message: "Member not found") as Error }
        let hidden = await actions().updateMember("m1", .gender("male"))
        XCTAssertEqual(failure(hidden), .generic)
    }

    /// ui2-shell D27: a 401 signs out and records nothing.
    func testUnauthorizedSaveSignsOut() async {
        api.errorFor = { _, _ in APIError.unauthorized }
        var signedOut = false
        let result = await actions(onUnauthorized: { signedOut = true }).updateMember("m1", .gender("male"))
        XCTAssertTrue(signedOut)
        XCTAssertEqual(failure(result), .generic)
        XCTAssertTrue(state.errors.isEmpty)
    }

    /// T7: a sign-out while the PATCH is in flight retires the generation — the result writes
    /// nothing and the reload is skipped (as testSignOutMidLoadDropsTheResult does for loads).
    func testSignOutMidSaveWritesNothingAndSkipsTheReload() async {
        api.stub("PATCH", "/api/members/m1", json: #"{"success":true}"#)
        api.beforeReturn = { _, body in
            guard body != nil else { return }
            self.state.clearAllData()
            self.state.memberDetails.upsert(MemberDetail(id: "m1", gender: "female"))
        }
        let result = await actions().updateMember("m1", .gender("male"))
        XCTAssertEqual(failure(result), .generic)
        XCTAssertEqual(state.memberDetails["m1"]?.gender, "female")
        XCTAssertEqual(api.callCount("GET", "/api/members/m1"), 0)
    }

    /// D21: the sent value shows even when the reload fails; a changed phone is unverified (D5).
    func testSavedValueShowsEvenWhenTheReloadFails() async {
        state.memberDetails.upsert(MemberDetail(id: "m1", phoneNumber: "+15550100009", phoneVerified: true))
        api.stub("PATCH", "/api/members/m1", json: #"{"success":true}"#)
        api.errorFor = { _, body in body == nil ? APIError.serverError("boom") as Error : nil }
        let result = await actions().updateMember("m1", .phoneNumber("+15555550123"))
        XCTAssertTrue(isSuccess(result))
        XCTAssertEqual(state.memberDetails["m1"]?.phoneNumber, "+15555550123")
        XCTAssertEqual(state.memberDetails["m1"]?.phoneVerified, false)
        XCTAssertEqual(state.errors.last?.context, "MemberActions.loadMember")
    }

    /// D21 / D5: only the sent key changes; an unchanged phone keeps its verification.
    func testApplyingWritesTheSentKeyOnly() {
        let d = MemberDetail(id: "m1", phoneNumber: "+15550100009", phoneVerified: true, email: "a@b.example")
        XCTAssertEqual(MemberActions.applying(.phoneNumber("+15550100009"), to: d).phoneVerified, true)
        XCTAssertEqual(MemberActions.applying(.phoneNumber("+15550100001"), to: d).phoneVerified, false)
        XCTAssertEqual(MemberActions.applying(.birthday("1974-06-25"), to: d).birthday, "1974-06-25T00:00:00.000Z")
        XCTAssertNil(MemberActions.applying(.birthday(nil), to: d).birthday)
        XCTAssertNil(MemberActions.applying(.email(nil), to: d).email)
        XCTAssertEqual(MemberActions.applying(.email(nil), to: d).phoneNumber, "+15550100009")
        XCTAssertEqual(MemberActions.applying(.emergencyContactPhone("555-1234 x2"), to: d).emergencyContactPhone, "555-1234 x2")
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL (compile): "cannot find 'APIHTTPError' in scope", "cannot find type 'MemberSaveError' in scope", "value of type 'MemberActions' has no member 'updateMember'".

- [ ] **Step 3: APIClient — the opt-in status error.** In `iphone/MakeReady/State/API/APIClient.swift`, directly after the closing brace of `enum APIError` (line 43), insert:

```swift

/// ui2-members-edit T6: a non-2xx response WITH its status, thrown ONLY by
/// `APIClient.requestWithStatus`. Every other call keeps throwing `APIError` exactly as before
/// (`EnrollmentActions` and `UserFacingErrorFormatter` match `.serverError`). A 401 is never this
/// type — it stays `APIError.unauthorized`, so `AuthStatusPolicy.shouldSignOut` still sees it.
struct APIHTTPError: LocalizedError, Equatable {
    let status: Int
    /// The response body's `error` string, when it carried one.
    let message: String?

    var errorDescription: String? { message ?? "Server returned status \(status)" }
}
```

Inside `final class APIClient`, directly before the doc comment `/// Execute a request and decode the response`, insert:

```swift
    /// ui2-members-edit T6: an uncoalesced request whose non-2xx failure keeps its HTTP status
    /// (`APIHTTPError`). Opt-in: only `MemberActions.updateMember` calls it.
    func requestWithStatus(endpoint: String, method: String, body: [String: Any]?) async throws -> Data {
        let request = try buildRequest(endpoint: endpoint, method: method, body: body, timeout: 30)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if let error = Self.statusError(status: http.statusCode, data: data) { throw error }
        return data
    }

    /// T6: nil for a 2xx; `APIError.unauthorized` for a 401 (sign-out policy unchanged);
    /// otherwise the status with the body's `error` string.
    static func statusError(status: Int, data: Data) -> Error? {
        if (200...299).contains(status) { return nil }
        if status == 401 { return APIError.unauthorized }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        return APIHTTPError(status: status, message: json?["error"] as? String)
    }

```

In `protocol APIClientProtocol`, directly after the line `func request(endpoint: String, method: String, body: [String: Any]?, timeout: TimeInterval) async throws -> Data`, insert:

```swift
    /// ui2-members-edit T6: as `request`, but a non-2xx throws `APIHTTPError` with its status.
    func requestWithStatus(endpoint: String, method: String, body: [String: Any]?) async throws -> Data
```

In `iphone/MakeReadyCaptureTests/StubAPIClient.swift`, directly after the closing brace of `func request(endpoint: String, method: String, body: [String: Any]?, timeout: TimeInterval) async throws -> Data` (line 72), insert:

```swift

    /// Recorded and answered like any call; a test returns an `APIHTTPError` from `errorFor`
    /// to play a status.
    func requestWithStatus(endpoint: String, method: String, body: [String: Any]?) async throws -> Data {
        try await request(endpoint: endpoint, method: method, body: body, timeout: 30)
    }
```

- [ ] **Step 4: The patch and error types.** Append to the end of `iphone/MakeReady/State/Models/MemberModels.swift`:

```swift

// MARK: - ui2-members-edit: one field's edit

/// ui2-members-edit D15: the ONE key a member edit page PATCHes to `/api/members/:id`. nil clears
/// (sent as JSON null, D8). Values are already in their wire form: phone normalized (D4),
/// birthday `YYYY-MM-DD` (D9), gender `male` / `female` (D10), strings trimmed.
enum MemberPatch: Equatable {
    case email(String?)
    case phoneNumber(String?)
    case birthday(String?)
    case gender(String?)
    case address(String?)
    case emergencyContactName(String?)
    case emergencyContactPhone(String?)

    /// The wire key (SPEC §Contract — camelCase on both sides, no transform).
    var key: String {
        switch self {
        case .email: return "email"
        case .phoneNumber: return "phoneNumber"
        case .birthday: return "birthday"
        case .gender: return "gender"
        case .address: return "address"
        case .emergencyContactName: return "emergencyContactName"
        case .emergencyContactPhone: return "emergencyContactPhone"
        }
    }

    var value: String? {
        switch self {
        case .email(let v), .phoneNumber(let v), .birthday(let v), .gender(let v), .address(let v),
             .emergencyContactName(let v), .emergencyContactPhone(let v):
            return v
        }
    }

    /// `JSONSerialization` writes `NSNull` as `null`.
    var jsonValue: Any { value ?? NSNull() }

    var body: [String: Any] { [key: jsonValue] }
}

/// ui2-members-edit D13: how a save failed, as the edit page shows it — the server's text for a
/// 400 / 403 / 409, else the generic line.
enum MemberSaveError: Error, Equatable {
    case validation(String)
    case generic
}
```

- [ ] **Step 5: The action.** In `iphone/MakeReady/State/Actions/MemberActions.swift`, directly before `    // MARK: - Helpers` (line 97), insert:

```swift
    // MARK: - Edit one field (ui2-members-edit)

    /// D13: the edit page's line for any failure that is not a 400 / 403 / 409 with a message.
    static let saveFailedMessage = "Couldn't save. Try again."

    /// D13 / D15 / D21: PATCH one key, write it into `memberDetails` so the page shows it even if
    /// the reload fails, then re-read the member with GET. A sign-out mid-save (stale generation)
    /// writes nothing. A 401 signs out; a 400 / 403 / 409 returns the server's text; anything
    /// else is generic and recorded console-only (UI 2.0 mounts no banner — the inline line is
    /// the only surface). Never throws: the container shows every failure.
    @MainActor
    func updateMember(_ id: String, _ patch: MemberPatch) async -> Result<Void, MemberSaveError> {
        let generation = state.initialLoad.generation
        do {
            _ = try await api.requestWithStatus(endpoint: "/api/members/\(id)", method: "PATCH", body: patch.body)
        } catch {
            guard state.initialLoad.isCurrent(generation) else { return .failure(.generic) }
            return await saveFailure(error)
        }
        guard state.initialLoad.isCurrent(generation) else { return .failure(.generic) }
        state.memberDetails.update(id) { $0 = Self.applying(patch, to: $0) }
        await loadMember(id)
        return .success(())
    }

    /// D21: the sent key written into a member detail. A CHANGED phone also turns
    /// `phoneVerified` off (D5); the same number changes nothing. A birthday `YYYY-MM-DD` is
    /// stored as the GET's UTC-midnight ISO string, which `MembersHomeMapper.parseDate` reads.
    static func applying(_ patch: MemberPatch, to detail: MemberDetail) -> MemberDetail {
        var d = detail
        switch patch {
        case .email(let v): d.email = v
        case .phoneNumber(let v):
            guard let v, v != detail.phoneNumber else { return d }
            d.phoneNumber = v
            d.phoneVerified = false
        case .birthday(let v): d.birthday = v.map { "\($0)T00:00:00.000Z" }
        case .gender(let v): d.gender = v
        case .address(let v): d.address = v
        case .emergencyContactName(let v): d.emergencyContactName = v
        case .emergencyContactPhone(let v): d.emergencyContactPhone = v
        }
        return d
    }

    @MainActor
    private func saveFailure(_ error: Error) async -> Result<Void, MemberSaveError> {
        if AuthStatusPolicy.shouldSignOut(after: error) {
            await onUnauthorized()                                     // ui2-shell D27
            return .failure(.generic)
        }
        if let http = error as? APIHTTPError, [400, 403, 409].contains(http.status) {
            return .failure(.validation(http.message ?? Self.saveFailedMessage))
        }
        if !(error is CancellationError) {
            state.recordError(error, context: "MemberActions.updateMember", surface: false)
        }
        return .failure(.generic)
    }

```

- [ ] **Step 6: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (the 11 new tests; every existing `MemberActionsTests` / `EnrollmentActions` / `UserFacingErrorFormatterTests` case unchanged). Then `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 7: Commit** — `git add iphone/MakeReady/State/API/APIClient.swift iphone/MakeReady/State/Models/MemberModels.swift iphone/MakeReady/State/Actions/MemberActions.swift iphone/MakeReadyCaptureTests/StubAPIClient.swift iphone/MakeReadyCaptureTests/MemberActionsTests.swift && git commit -m "feat(ui2-members-edit): MemberActions.updateMember over a status-bearing PATCH"`

### Task 9: MemberFieldEditor — field rules, page states, validation and the patch (D3, D4, D7, D9–D11, D14, D16, D18, D22, D24)
App: iphone
Phase: 3
Recipe: /ios-error-surface

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Members/MemberFieldEditor.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — register the source in target `MakeReady` (group `MakeReady/UI2`, path `Containers/Members/MemberFieldEditor.swift`, as `MemberProfileMapper.swift` is) and mirror into `MakeReadyCapture`; register the test in `MakeReadyCaptureTests` (Steps 1 and 3)
- Test: Create `iphone/MakeReadyCaptureTests/MemberFieldEditorTests.swift`

**Interfaces:**
- Consumes: `MemberField` and `MembersProfileScreen.label(for:)` (Task 6); `EditTextSingleFieldScreen.State` / `EditTextMultiFieldScreen.State` with Task 5's defaulted props (`allowsEmpty`, `maxLength`, `errorMessage`, `showsAISuggestions`, `editable`, `focusOnAppear`, `keyboard`, `textContentType`, `autocapitalization`, `autocorrect`); `EditOptionFieldScreen.State(title:description:options:optionDescriptions:loadedValue:selectedOption:saving:errorMessage:)`; `EditDateFieldScreen.State(title:description:loadedValue:selectedValue:minDate:maxDate:saving:errorMessage:)` (Task 7); `MemberPatch`, `MemberSaveError`, `MemberActions.saveFailedMessage` (Task 8); `MemberDetail`; `MemberProfileMapper.phoneLabel(_:)` (browse D23 label); `MembersHomeMapper.parseDate(_:)`.
- Produces:
  - `enum MemberFieldRules` — `phoneMessage = "Enter a valid phone number"`, `emailMessage = "Enter a valid email"`, `birthdayMessage = "Birthday must be between 1900 and today"`; `static func normalizePhone(_ raw: String) -> String?` (D4/D18; nil = invalid); `static func isValidContactPhone(_ raw: String) -> Bool` (D7); `static func isValidEmail(_ raw: String) -> Bool` (zod 3.23 `email()` regex); `static func birthdayInRange(_ day: DateComponents, today: Date, calendar: Calendar) -> Bool`; `static func birthdayBounds(today: Date, calendar: Calendar) -> (min: Date, max: Date)`; `static func birthdayComponents(_ iso: String?) -> DateComponents?` (stored UTC calendar date → calendar-free local components, D9); `static func isoDay(_ day: DateComponents?) -> String?` (`YYYY-MM-DD`)
  - `enum MemberFieldInput { case text(String), option(String), date(DateComponents?) }`
  - `enum MemberFieldPage { case textSingle(EditTextSingleFieldScreen.State, canSave: ((String) -> Bool)?), textMulti(EditTextMultiFieldScreen.State), option(EditOptionFieldScreen.State), date(EditDateFieldScreen.State) }`
  - `enum MemberFieldEditModel` — `genderOptions = ["Male", "Female", "Not set"]`; `static func description(_ field: MemberField) -> String` (D14); `static func page(_ field: MemberField, detail: MemberDetail, saving: Bool, errorMessage: String, today: Date, calendar: Calendar) -> MemberFieldPage`; `static func phoneCanSave(_ typed: String, stored: String) -> Bool` (D24); `static func validate(_ field: MemberField, _ input: MemberFieldInput, today: Date, calendar: Calendar) -> String?` (D16 — nil = valid); `static func patch(_ field: MemberField, _ input: MemberFieldInput) -> MemberPatch`; `static func message(for error: MemberSaveError) -> String`

The D4/D7/D11/D9 cases below are the server's tables (SPEC §Testing server, T2's `member-fields.ts` unit tables) duplicated row for row; each row carries the server's verdict next to the iPhone's.

- [ ] **Step 1: Write the failing tests** — create `iphone/MakeReadyCaptureTests/MemberFieldEditorTests.swift`:

```swift
import XCTest
@testable import MakeReady

/// ui2-members-edit T8/D16: the edit pages' pure rules. The phone, contact-phone, email and
/// birthday tables mirror the server's (SPEC §Testing server / T2) row for row.
final class MemberFieldEditorTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Denver")!
        return c
    }()
    private let today = ISO8601DateFormatter().date(from: "2026-10-26T18:00:00Z")!   // Mon Oct 26, noon MDT

    private func tony() -> MemberDetail {
        MemberDetail(id: "m1", phoneNumber: "+15550100009", phoneVerified: true, firstName: "Tony", lastName: "Stark",
                     email: nil, googleEmail: "tony@gmail.example", gender: "male",
                     birthday: "1974-06-25T00:00:00.000Z", address: "10880 Malibu Point\nMalibu, CA",
                     emergencyContactName: "Pepper Potts", emergencyContactPhone: "555-123-4567 x2")
    }

    private func page(_ field: MemberField, _ d: MemberDetail, saving: Bool = false, error: String = "") -> MemberFieldPage {
        MemberFieldEditModel.page(field, detail: d, saving: saving, errorMessage: error, today: today, calendar: cal)
    }

    private func single(_ field: MemberField, _ d: MemberDetail) -> (EditTextSingleFieldScreen.State, ((String) -> Bool)?)? {
        if case let .textSingle(s, canSave) = page(field, d) { return (s, canSave) }
        return nil
    }

    // MARK: - D4 / D18 phone normalization (server T2 `normalizePhone` table)

    func testPhoneNormalizationMatchesTheServerTable() {
        // input                      server (D4/D18)          iPhone
        let rows: [(String, String?)] = [
            ("5551234567", "+15551234567"),            // 10 digits → +1
            ("(555) 123-4567", "+15551234567"),        // punctuation stripped
            ("555.123.4567", "+15551234567"),
            (" +1 555 123 4567 ", "+15551234567"),     // trimmed, spaces stripped
            ("15551234567", "+15551234567"),           // D18: 11 digits starting 1
            ("1-555-123-4567", "+15551234567"),        // D18
            ("+44 20 7946 0958", "+442079460958"),     // + kept
            ("+447700900123", "+447700900123"),
            ("555-1234", nil),                         // 400 "Enter a valid phone number"
            ("25551234567", nil),                      // 11 digits not starting 1 → 400
            ("+0123456789", nil),                      // E.164 forbids a leading 0
            ("+1234567890123456", nil),                // 16 digits → 400
            ("abc", nil),
            ("", nil)                                  // empty → 400
        ]
        for (input, expected) in rows {
            XCTAssertEqual(MemberFieldRules.normalizePhone(input), expected, input)
        }
    }

    // MARK: - D7 emergency phone validity (server T2 `isValidContactPhone` table)

    func testContactPhoneValidityMatchesTheServerTable() {
        let rows: [(String, Bool)] = [
            ("555-123-4567", true),
            ("(555) 123-4567 ext. 89", true),
            ("555 1234 x12", true),
            ("555-1234 EXT 5", true),                  // extension word is case-insensitive
            ("+44 20 7946 0958", true),
            ("1234567", true),                         // 7 digits is enough
            ("123456", false),                         // 6 digits
            ("555-123", false),
            ("555-1234 ext", false),                   // an extension needs digits
            ("call me", false)
        ]
        for (input, expected) in rows {
            XCTAssertEqual(MemberFieldRules.isValidContactPhone(input), expected, input)
        }
    }

    // MARK: - D11 email (zod `email()`)

    func testEmailValidityMatchesZod() {
        let rows: [(String, Bool)] = [
            ("a@b.com", true),
            ("first.last+tag@example.org", true),
            ("a@b", false),
            ("a..b@c.com", false),
            (".a@b.com", false),
            ("a@b.c", false)
        ]
        for (input, expected) in rows {
            XCTAssertEqual(MemberFieldRules.isValidEmail(input), expected, input)
        }
    }

    // MARK: - D9 birthday

    func testBirthdayBoundsAndUTCCalendarDate() {
        XCTAssertFalse(MemberFieldRules.birthdayInRange(DateComponents(year: 1899, month: 12, day: 31), today: today, calendar: cal))
        XCTAssertTrue(MemberFieldRules.birthdayInRange(DateComponents(year: 1900, month: 1, day: 1), today: today, calendar: cal))
        XCTAssertTrue(MemberFieldRules.birthdayInRange(DateComponents(year: 2026, month: 10, day: 26), today: today, calendar: cal))
        XCTAssertFalse(MemberFieldRules.birthdayInRange(DateComponents(year: 2026, month: 10, day: 27), today: today, calendar: cal))
        // The stored UTC midnight is June 25 everywhere — never June 24 in Denver.
        XCTAssertEqual(MemberFieldRules.birthdayComponents("1974-06-25T00:00:00.000Z"), DateComponents(year: 1974, month: 6, day: 25))
        XCTAssertNil(MemberFieldRules.birthdayComponents(nil))
        XCTAssertNil(MemberFieldRules.birthdayComponents("garbage"))
        XCTAssertEqual(MemberFieldRules.isoDay(DateComponents(year: 1974, month: 6, day: 5)), "1974-06-05")
        XCTAssertNil(MemberFieldRules.isoDay(nil))
    }

    // MARK: - Page states (D3, D10, D11, D14, D22, D24)

    func testEmailPageLoadsTheRawEmailNeverTheGoogleFallback() {
        guard let email = single(.email, tony()) else { return XCTFail("email is a text-single page") }
        let (s, canSave) = email
        XCTAssertEqual(s.title, "Email address")
        XCTAssertEqual(s.label, "Email address")
        XCTAssertEqual(s.description, "The email address used to contact this member.")
        XCTAssertEqual(s.text, "")                     // D11: email nil → "", not googleEmail
        XCTAssertEqual(s.loadedValue, "")
        XCTAssertEqual(s.placeholder, "")
        XCTAssertTrue(s.allowsEmpty)                   // D8
        XCTAssertEqual(s.maxLength, 254)
        XCTAssertEqual(s.keyboard, .emailAddress)
        XCTAssertFalse(s.autocorrect)
        XCTAssertFalse(s.showsAISuggestions)           // D3
        XCTAssertTrue(s.editable)
        XCTAssertTrue(s.focusOnAppear)                 // D22
        XCTAssertNil(canSave)
    }

    func testPhonePagePrefillsTheLabelAndComparesNormalized() {
        guard let phone = single(.phone, tony()) else { return XCTFail("phone is a text-single page") }
        let (s, canSave) = phone
        XCTAssertEqual(s.title, "Phone number")
        XCTAssertEqual(s.description, "The number this member signs in with. Changing it marks it unverified until they sign in with the new number.")
        XCTAssertEqual(s.text, "+1 (555) 010-0009")    // browse D23 label
        XCTAssertFalse(s.allowsEmpty)                  // D8: Phone can't be cleared
        XCTAssertEqual(s.maxLength, 20)
        XCTAssertEqual(s.keyboard, .phonePad)
        guard let canSave else { return XCTFail("D24: phone supplies canSave") }
        XCTAssertFalse(canSave("+1 (555) 010-0009"))   // same number → clean
        XCTAssertFalse(canSave("555.010.0009"))        // same number, another format → clean
        XCTAssertTrue(canSave("555 010 0001"))         // a different number → dirty
        XCTAssertTrue(canSave("555-01"))               // invalid → enabled; validate() explains
        XCTAssertFalse(canSave(""))                    // D8: empty disables Save
    }

    func testEmergencyPagesKeepTheValueAsTyped() {
        guard let phone = single(.emergencyPhone, tony())?.0 else { return XCTFail("emergency phone is text-single") }
        XCTAssertEqual(phone.title, "Emergency phone")
        XCTAssertEqual(phone.text, "555-123-4567 x2")
        XCTAssertEqual(phone.maxLength, 40)
        XCTAssertEqual(phone.keyboard, .numbersAndPunctuation)   // D22: reaches "x"/"ext" (D7)
        XCTAssertTrue(phone.allowsEmpty)
        guard let name = single(.emergencyName, tony())?.0 else { return XCTFail("emergency contact is text-single") }
        XCTAssertEqual(name.title, "Emergency contact")
        XCTAssertEqual(name.description, "The person to contact if there is an emergency.")
        XCTAssertEqual(name.text, "Pepper Potts")
        XCTAssertEqual(name.maxLength, 200)
        XCTAssertEqual(name.keyboard, .default)
    }

    func testAddressIsTheMultiLinePage() {
        guard case let .textMulti(s) = page(.address, tony()) else { return XCTFail("address is text-multi") }
        XCTAssertEqual(s.title, "Address")
        XCTAssertEqual(s.description, "This member's mailing address.")
        XCTAssertEqual(s.text, "10880 Malibu Point\nMalibu, CA")
        XCTAssertEqual(s.maxLength, 2000)
        XCTAssertFalse(s.showsAISuggestions)
        XCTAssertTrue(s.editable)
    }

    func testGenderOptionsAndUnknownValuesStartAtNotSet() {
        guard case let .option(s) = page(.gender, tony()) else { return XCTFail("gender is the option page") }
        XCTAssertEqual(s.title, "Gender")
        XCTAssertEqual(s.description, "Helps leaders place this member in the right groups.")
        XCTAssertEqual(s.options, ["Male", "Female", "Not set"])
        XCTAssertEqual(s.optionDescriptions, [])       // D10: title-only rows
        XCTAssertEqual(s.selectedOption, "Male")
        XCTAssertEqual(s.loadedValue, "Male")
        var d = tony()
        d.gender = nil
        guard case let .option(unset) = page(.gender, d) else { return XCTFail("gender is the option page") }
        XCTAssertEqual(unset.selectedOption, "Not set")
        d.gender = "nonbinary"
        guard case let .option(other) = page(.gender, d) else { return XCTFail("gender is the option page") }
        XCTAssertEqual(other.selectedOption, "Not set")
        XCTAssertEqual(other.loadedValue, "Not set")   // the page starts clean
    }

    func testBirthdayPageShowsTheStoredDayAndToday() {
        guard case let .date(s) = page(.birthday, tony(), saving: true, error: "x") else { return XCTFail("birthday is the date page") }
        XCTAssertEqual(s.title, "Birthday")
        XCTAssertEqual(s.description, "Used to show this member's age to group leaders.")
        XCTAssertEqual(s.loadedValue, DateComponents(year: 1974, month: 6, day: 25))
        XCTAssertEqual(s.selectedValue, s.loadedValue)
        XCTAssertEqual(s.maxDate, today)
        XCTAssertEqual(cal.dateComponents([.year, .month, .day], from: s.minDate).year, 1900)
        XCTAssertTrue(s.saving)
        XCTAssertEqual(s.errorMessage, "x")
    }

    func testSavingAndErrorReachTheTextPages() {
        guard case let .textSingle(s, _) = page(.email, tony(), saving: true, error: "Enter a valid email") else {
            return XCTFail("email is text-single")
        }
        XCTAssertTrue(s.saving)
        XCTAssertEqual(s.errorMessage, "Enter a valid email")
    }

    // MARK: - D16 validation, D15 patch, D13 copy

    func testValidationMessagesMatchTheServer() {
        XCTAssertNil(MemberFieldEditModel.validate(.email, .text(""), today: today, calendar: cal))           // clears
        XCTAssertNil(MemberFieldEditModel.validate(.email, .text(" a@b.com "), today: today, calendar: cal))  // trim first
        XCTAssertEqual(MemberFieldEditModel.validate(.email, .text("a@b"), today: today, calendar: cal), "Enter a valid email")
        XCTAssertEqual(MemberFieldEditModel.validate(.phone, .text("555-01"), today: today, calendar: cal), "Enter a valid phone number")
        XCTAssertEqual(MemberFieldEditModel.validate(.phone, .text(""), today: today, calendar: cal), "Enter a valid phone number")
        XCTAssertNil(MemberFieldEditModel.validate(.phone, .text("(555) 010-0001"), today: today, calendar: cal))
        XCTAssertNil(MemberFieldEditModel.validate(.emergencyPhone, .text(""), today: today, calendar: cal))
        XCTAssertEqual(MemberFieldEditModel.validate(.emergencyPhone, .text("12"), today: today, calendar: cal), "Enter a valid phone number")
        XCTAssertNil(MemberFieldEditModel.validate(.birthday, .date(nil), today: today, calendar: cal))
        XCTAssertEqual(MemberFieldEditModel.validate(.birthday, .date(DateComponents(year: 2026, month: 10, day: 27)), today: today, calendar: cal),
                       "Birthday must be between 1900 and today")
        XCTAssertNil(MemberFieldEditModel.validate(.address, .text(""), today: today, calendar: cal))
        XCTAssertNil(MemberFieldEditModel.validate(.gender, .option("Not set"), today: today, calendar: cal))
    }

    /// `MemberField` ↔ PATCH key, and each field's wire value.
    func testPatchSendsTheFieldsWireKeyAndValue() {
        XCTAssertEqual(MemberFieldEditModel.patch(.email, .text(" a@b.com ")), .email("a@b.com"))
        XCTAssertEqual(MemberFieldEditModel.patch(.email, .text("")), .email(nil))
        XCTAssertEqual(MemberFieldEditModel.patch(.phone, .text("(555) 010-0001")), .phoneNumber("+15550100001"))
        XCTAssertEqual(MemberFieldEditModel.patch(.birthday, .date(DateComponents(year: 1974, month: 6, day: 25))), .birthday("1974-06-25"))
        XCTAssertEqual(MemberFieldEditModel.patch(.birthday, .date(nil)), .birthday(nil))
        XCTAssertEqual(MemberFieldEditModel.patch(.gender, .option("Male")), .gender("male"))
        XCTAssertEqual(MemberFieldEditModel.patch(.gender, .option("Female")), .gender("female"))
        XCTAssertEqual(MemberFieldEditModel.patch(.gender, .option("Not set")), .gender(nil))
        XCTAssertEqual(MemberFieldEditModel.patch(.address, .text("")), .address(nil))
        XCTAssertEqual(MemberFieldEditModel.patch(.emergencyName, .text("Pepper")), .emergencyContactName("Pepper"))
        XCTAssertEqual(MemberFieldEditModel.patch(.emergencyPhone, .text("555-1234 x2")), .emergencyContactPhone("555-1234 x2"))
        let keys = MemberField.allCases.map { MemberFieldEditModel.patch($0, .text("")).key }
        XCTAssertEqual(keys, ["email", "phoneNumber", "birthday", "gender", "address", "emergencyContactName", "emergencyContactPhone"])
    }

    func testSaveErrorCopy() {
        XCTAssertEqual(MemberFieldEditModel.message(for: .validation("That number belongs to another member")),
                       "That number belongs to another member")
        XCTAssertEqual(MemberFieldEditModel.message(for: .generic), "Couldn't save. Try again.")
    }
}
```

Register the test file (from `iphone/`):

```bash
cd iphone && ruby -rxcodeproj -e '
p = Xcodeproj::Project.open("MakeReady.xcodeproj")
[["MakeReadyCaptureTests", "MemberFieldEditorTests.swift", "MakeReadyCaptureTests"]].each do |group, path, target|
  g = p.main_group.find_subpath(group, false) or abort("no group #{group}")
  next if g.files.any? { |f| f.path == path }
  p.targets.find { |t| t.name == target }.add_file_references([g.new_reference(path)])
end
p.save'
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL (compile): "cannot find 'MemberFieldRules' in scope", "cannot find 'MemberFieldEditModel' in scope", "cannot find type 'MemberFieldPage' in scope".

- [ ] **Step 3: Write the minimal implementation** — create `iphone/MakeReady/UI2/Containers/Members/MemberFieldEditor.swift`:

```swift
import Foundation
import SwiftUI

/// ui2-members-edit D4/D7/D9/D11/D18: the member-field rules, identical to the server's
/// `services/member-fields.ts` so the iPhone shows the same message without a request (D16).
/// ASCII digits only (`[0-9]`, never ICU's Unicode `\d`), to match JavaScript's `\d`.
enum MemberFieldRules {
    static let phoneMessage = "Enter a valid phone number"
    static let emailMessage = "Enter a valid email"
    static let birthdayMessage = "Birthday must be between 1900 and today"

    private static let e164 = #"^\+[1-9][0-9]{1,14}$"#
    /// D7, the literal server regex with the pre-extension part captured.
    private static let contactPhone = #"^([0-9\s().+-]+)(?:\s*(?:ext\.?|x)\s*[0-9]+)?$"#
    /// zod 3.23 `z.string().email()`.
    private static let email = #"^(?!\.)(?!.*\.\.)([A-Z0-9_'+\-\.]*)[A-Z0-9_+-]@([A-Z0-9][A-Z0-9\-]*\.)+[A-Z]{2,}$"#
    private static let utc = TimeZone(secondsFromGMT: 0) ?? .current

    /// D4 / D18: strip spaces, `-`, `.`, `(`, `)`; 10 digits → `+1…`; 11 digits starting `1` →
    /// `+…`; a leading `+` is kept; the result must be E.164. nil = invalid (400).
    static func normalizePhone(_ raw: String) -> String? {
        let stripped = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { !$0.isWhitespace && !"-.()".contains($0) }
        let candidate: String
        if stripped.hasPrefix("+") {
            candidate = stripped
        } else if stripped.count == 10, isDigits(stripped) {
            candidate = "+1" + stripped
        } else if stripped.count == 11, stripped.hasPrefix("1"), isDigits(stripped) {
            candidate = "+" + stripped
        } else {
            candidate = stripped
        }
        return candidate.range(of: e164, options: .regularExpression) != nil ? candidate : nil
    }

    /// D7: digits and separators, an optional `ext`/`x` extension, ≥7 digits before it.
    static func isValidContactPhone(_ raw: String) -> Bool {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let regex = try? NSRegularExpression(pattern: contactPhone, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let main = Range(match.range(at: 1), in: s) else { return false }
        return s[main].filter { ("0"..."9").contains($0) }.count >= 7
    }

    /// D11: the trimmed value passes zod's `email()`.
    static func isValidEmail(_ raw: String) -> Bool {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.range(of: email, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// D9: 1900-01-01 … today in the device calendar, compared as calendar days.
    static func birthdayInRange(_ day: DateComponents, today: Date, calendar: Calendar) -> Bool {
        guard let y = day.year, let m = day.month, let d = day.day else { return false }
        let t = calendar.dateComponents([.year, .month, .day], from: today)
        guard let ty = t.year, let tm = t.month, let td = t.day else { return false }
        return (y, m, d) >= (1900, 1, 1) && (y, m, d) <= (ty, tm, td)
    }

    /// D9: the wheel's range — 1900-01-01 local … today.
    static func birthdayBounds(today: Date, calendar: Calendar) -> (min: Date, max: Date) {
        (calendar.date(from: DateComponents(year: 1900, month: 1, day: 1)) ?? .distantPast, today)
    }

    /// D9: the stored UTC calendar date as calendar-free components — the wheel shows them as a
    /// LOCAL date, never the UTC instant (which lands a day early west of UTC).
    static func birthdayComponents(_ iso: String?) -> DateComponents? {
        guard let iso, let date = MembersHomeMapper.parseDate(iso) else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utc
        let c = cal.dateComponents([.year, .month, .day], from: date)
        guard let y = c.year, let m = c.month, let d = c.day else { return nil }
        return DateComponents(year: y, month: m, day: d)
    }

    /// D9: the local day the iPhone sends — `YYYY-MM-DD`.
    static func isoDay(_ day: DateComponents?) -> String? {
        guard let y = day?.year, let m = day?.month, let d = day?.day else { return nil }
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private static func isDigits(_ s: String) -> Bool {
        !s.isEmpty && s.allSatisfy { ("0"..."9").contains($0) }
    }
}

/// What an edit page hands back on Save.
enum MemberFieldInput {
    /// A text page's trimmed text.
    case text(String)
    /// The option page's selected title.
    case option(String)
    /// The date page's day, nil = cleared.
    case date(DateComponents?)

    fileprivate var trimmedText: String {
        switch self {
        case .text(let s), .option(let s): return s.trimmingCharacters(in: .whitespacesAndNewlines)
        case .date: return ""
        }
    }

    fileprivate var day: DateComponents? {
        if case .date(let d) = self { return d }
        return nil
    }
}

/// D3: the one built screen a field opens, with its State.
enum MemberFieldPage {
    case textSingle(EditTextSingleFieldScreen.State, canSave: ((String) -> Bool)?)
    case textMulti(EditTextMultiFieldScreen.State)
    case option(EditOptionFieldScreen.State)
    case date(EditDateFieldScreen.State)
}

/// ui2-members-edit §iphone Edit container: each field's screen State from the loaded member,
/// the D16 checks and the one-key patch. Pure — `MemberFieldEditContainer` renders and saves.
enum MemberFieldEditModel {
    /// D10: top → bottom; stored `male` / `female` / null.
    static let genderOptions = ["Male", "Female", "Not set"]
    private static let notSet = "Not set"

    /// D14: each page's description, verbatim.
    static func description(_ field: MemberField) -> String {
        switch field {
        case .email: return "The email address used to contact this member."
        case .phone: return "The number this member signs in with. Changing it marks it unverified until they sign in with the new number."
        case .birthday: return "Used to show this member's age to group leaders."
        case .gender: return "Helps leaders place this member in the right groups."
        case .address: return "This member's mailing address."
        case .emergencyName: return "The person to contact if there is an emergency."
        case .emergencyPhone: return "The number to call for this member's emergency contact."
        }
    }

    /// D3 arrangement + D10/D11/D14/D22/D24 per field, from the loaded detail (D27).
    static func page(
        _ field: MemberField,
        detail: MemberDetail,
        saving: Bool,
        errorMessage: String,
        today: Date,
        calendar: Calendar
    ) -> MemberFieldPage {
        let title = MembersProfileScreen.label(for: field)
        switch field {
        case .email:
            return .textSingle(single(field, text: detail.email ?? "", saving: saving, errorMessage: errorMessage), canSave: nil)
        case .phone:
            let stored = detail.phoneNumber
            return .textSingle(
                single(field, text: MemberProfileMapper.phoneLabel(stored), saving: saving, errorMessage: errorMessage),
                canSave: { phoneCanSave($0, stored: stored) }
            )
        case .emergencyName:
            return .textSingle(single(field, text: detail.emergencyContactName ?? "", saving: saving, errorMessage: errorMessage), canSave: nil)
        case .emergencyPhone:
            return .textSingle(single(field, text: detail.emergencyContactPhone ?? "", saving: saving, errorMessage: errorMessage), canSave: nil)
        case .address:
            var s = EditTextMultiFieldScreen.State(
                title: title, description: description(field), label: title, placeholder: "",
                text: detail.address ?? "", loadedValue: detail.address ?? "", focused: false, saving: saving,
                promptCopy: "", aiState: "prompt", suggestions: []
            )
            s.maxLength = 2000
            s.errorMessage = errorMessage
            s.showsAISuggestions = false
            s.editable = true
            s.focusOnAppear = true
            s.textContentType = .fullStreetAddress
            return .textMulti(s)
        case .gender:
            let selected = genderLabel(detail.gender)
            return .option(EditOptionFieldScreen.State(
                title: title, description: description(field),
                options: genderOptions, optionDescriptions: [],
                loadedValue: selected, selectedOption: selected,
                saving: saving, errorMessage: errorMessage
            ))
        case .birthday:
            let day = MemberFieldRules.birthdayComponents(detail.birthday)
            let bounds = MemberFieldRules.birthdayBounds(today: today, calendar: calendar)
            return .date(EditDateFieldScreen.State(
                title: title, description: description(field),
                loadedValue: day, selectedValue: day,
                minDate: bounds.min, maxDate: bounds.max,
                saving: saving, errorMessage: errorMessage
            ))
        }
    }

    /// D24 + D8: Save is enabled when the typed number normalizes to something other than the
    /// stored one (an invalid number counts as different — `validate` explains it); empty never.
    static func phoneCanSave(_ typed: String, stored: String) -> Bool {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && MemberFieldRules.normalizePhone(trimmed) != stored
    }

    /// D16: the server's message for an input it would reject, else nil.
    static func validate(_ field: MemberField, _ input: MemberFieldInput, today: Date, calendar: Calendar) -> String? {
        let text = input.trimmedText
        switch field {
        case .email:
            return text.isEmpty || MemberFieldRules.isValidEmail(text) ? nil : MemberFieldRules.emailMessage
        case .phone:
            return MemberFieldRules.normalizePhone(text) == nil ? MemberFieldRules.phoneMessage : nil
        case .emergencyPhone:
            return text.isEmpty || MemberFieldRules.isValidContactPhone(text) ? nil : MemberFieldRules.phoneMessage
        case .birthday:
            guard let day = input.day else { return nil }
            return MemberFieldRules.birthdayInRange(day, today: today, calendar: calendar) ? nil : MemberFieldRules.birthdayMessage
        case .gender, .address, .emergencyName:
            return nil
        }
    }

    /// D15: the one key and its wire value; "" / "Not set" / a cleared date → nil (D8).
    static func patch(_ field: MemberField, _ input: MemberFieldInput) -> MemberPatch {
        let text = input.trimmedText
        let orNil: String? = text.isEmpty ? nil : text
        switch field {
        case .email: return .email(orNil)
        case .phone: return .phoneNumber(MemberFieldRules.normalizePhone(text) ?? text)
        case .birthday: return .birthday(MemberFieldRules.isoDay(input.day))
        case .gender:
            switch text {
            case "Male": return .gender("male")
            case "Female": return .gender("female")
            default: return .gender(nil)
            }
        case .address: return .address(orNil)
        case .emergencyName: return .emergencyContactName(orNil)
        case .emergencyPhone: return .emergencyContactPhone(orNil)
        }
    }

    /// D13: the inline error line for a failed save.
    static func message(for error: MemberSaveError) -> String {
        switch error {
        case .validation(let message): return message
        case .generic: return MemberActions.saveFailedMessage
        }
    }

    // MARK: - Helpers

    /// D10: "Not set" for null or any value other than male/female, so the page starts clean.
    private static func genderLabel(_ stored: String?) -> String {
        switch stored {
        case "male": return "Male"
        case "female": return "Female"
        default: return notSet
        }
    }

    /// D3/D14/D22: a member text-single page — title = label, no placeholder, no AI block, a live
    /// field focused on appear, the field's keyboard, caps and cap.
    private static func single(_ field: MemberField, text: String, saving: Bool, errorMessage: String) -> EditTextSingleFieldScreen.State {
        let title = MembersProfileScreen.label(for: field)
        var s = EditTextSingleFieldScreen.State(
            title: title, description: description(field), label: title, placeholder: "",
            text: text, loadedValue: text, focused: false, saving: saving,
            promptCopy: "", aiState: "prompt", suggestions: []
        )
        s.errorMessage = errorMessage
        s.showsAISuggestions = false
        s.editable = true
        s.focusOnAppear = true
        s.allowsEmpty = field != .phone                                  // D8
        switch field {
        case .email:
            s.keyboard = .emailAddress
            s.textContentType = .emailAddress
            s.autocapitalization = .never
            s.autocorrect = false
            s.maxLength = 254
        case .phone:
            s.keyboard = .phonePad
            s.textContentType = .telephoneNumber
            s.autocapitalization = .never
            s.autocorrect = false
            s.maxLength = 20
        case .emergencyPhone:
            s.keyboard = .numbersAndPunctuation   // D22: ABC key reaches "x"/"ext" (D7)
            s.textContentType = .telephoneNumber
            s.autocapitalization = .never
            s.autocorrect = false
            s.maxLength = 40
        case .emergencyName, .birthday, .gender, .address:
            s.keyboard = .default
            s.textContentType = .name
            s.autocapitalization = .words
            s.maxLength = 200
        }
        return s
    }
}
```

Register the source in target `MakeReady` (the `UI2` group stores container files with a subdirectory path and a display name, as `MemberProfileMapper.swift`), then mirror it into `MakeReadyCapture`:

```bash
cd iphone && ruby -rxcodeproj -e '
p = Xcodeproj::Project.open("MakeReady.xcodeproj")
g = p.main_group.find_subpath("MakeReady/UI2", false) or abort("no group MakeReady/UI2")
path = "Containers/Members/MemberFieldEditor.swift"
unless g.files.any? { |f| f.path == path }
  ref = g.new_reference(path)
  ref.name = File.basename(path)
  p.targets.find { |t| t.name == "MakeReady" }.add_file_references([ref])
end
p.save' && ruby scripts/capture-targets.rb && ruby scripts/capture-targets.rb --check
```
→ the last command exits 0 (in sync).

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (`MemberFieldEditorTests`, 15 tests). Then `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations (`try?` only; no `try!`, no force unwraps in the source).

- [ ] **Step 5: Commit** — `git add iphone/MakeReady/UI2/Containers/Members/MemberFieldEditor.swift iphone/MakeReadyCaptureTests/MemberFieldEditorTests.swift iphone/MakeReady.xcodeproj/project.pbxproj && git commit -m "feat(ui2-members-edit): member field rules, page states and one-key patch (D16 mirrors the server)"`

### Task 10: The editMemberField push, the edit container and popIfTop (T8 — D2, D13, D27)
App: iphone
Phase: 4
Recipe: /push-page

**Files:**
- Modify: `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift:17-19` (new destination case), after `pop(on:)` (:49) (new `popIfTop`)
- Modify: `iphone/MakeReady/UI2/Shell/UI2Navigation.swift:6-9` (`popIfTop` on the navigator)
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift:65-68` (navigator wiring), `:85-89` (`page(for:)`)
- Create: `iphone/MakeReady/UI2/Containers/Members/MemberFieldEditContainer.swift`
- Modify: `iphone/MakeReady/UI2/Containers/Members/MemberProfileContainer.swift:27-31` (`fieldsEditable`), `:44-49` (`onEditField`)
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — register the container in target `MakeReady` and mirror into `MakeReadyCapture` (Step 5)
- Test: `iphone/MakeReadyCaptureTests/UI2ShellModelTests.swift` (append)

**Interfaces:**
- Consumes: `MemberField`, `MembersProfileScreen(state:showsHeader:onEditField:)`, `State.fieldsEditable` (Task 6); `EditTextSingleFieldScreen(state:onBack:onSave:canSave:)`, `EditTextMultiFieldScreen(state:onBack:onSave:)` (Task 5); `EditOptionFieldScreen(state:onBack:onSave:)`; `EditDateFieldScreen(state:onBack:onSave:)` (Task 7); `MemberActions(onUnauthorized:)`, `updateMember(_:_:) -> Result<Void, MemberSaveError>` (Task 8); `MemberFieldEditModel.page(_:detail:saving:errorMessage:today:calendar:)`, `.validate(_:_:today:calendar:)`, `.patch(_:_:)`, `.message(for:)`, `MemberFieldInput`, `MemberFieldPage` (Task 9); `AuthManager.signOut()`, `AppState.shared.memberDetails`, `AppState.recordError(_:context:surface:)`.
- Produces:
  - `UI2Destination.editMemberField(memberId: String, field: MemberField)`
  - `UI2ShellModel.popIfTop(_ destination: UI2Destination, on tab: TabBar.Tab)` — pops only when the tab's last entry equals `destination`
  - `UI2Navigator.popIfTop: (UI2Destination) -> Void` (default no-op)
  - `struct MemberFieldEditContainer: View { let memberId: String; let field: MemberField }`

- [ ] **Step 1: Write the failing tests** — append inside `final class UI2ShellModelTests` in `iphone/MakeReadyCaptureTests/UI2ShellModelTests.swift`, before its final closing brace (`tony` is the class's existing `UI2Destination.memberDetail(id: "m1", name: "Tony Stark")`):

```swift
    // MARK: - ui2-members-edit D2 / D13: the edit page on the member page

    private var editPhone: UI2Destination { .editMemberField(memberId: "m1", field: .phone) }

    /// D2: a field-row tap pushes its edit page above the member page.
    func testEditFieldPushesAboveTheMemberPage() {
        var m = UI2ShellModel()
        m.push(tony, on: .home)
        m.push(editPhone, on: .home)
        XCTAssertEqual(m.path(for: .home), [tony, editPhone])
        XCTAssertNotEqual(editPhone, .editMemberField(memberId: "m1", field: .email))
        XCTAssertNotEqual(editPhone, .editMemberField(memberId: "m2", field: .phone))
    }

    /// D13: the success pop fires only while THIS edit page is still the last entry — a
    /// swipe-back, another page on top or a Home re-tap during the save leaves the stack alone.
    func testPopIfTopPopsOnlyWhenTheEditPageIsStillOnTop() {
        var m = UI2ShellModel()
        m.push(tony, on: .home)
        m.push(editPhone, on: .home)
        m.popIfTop(editPhone, on: .home)
        XCTAssertEqual(m.path(for: .home), [tony])
        m.popIfTop(editPhone, on: .home)                       // already swiped back: no-op
        XCTAssertEqual(m.path(for: .home), [tony])
        m.push(.editMemberField(memberId: "m1", field: .email), on: .home)
        m.popIfTop(editPhone, on: .home)                       // another page on top: no-op
        XCTAssertEqual(m.path(for: .home).count, 2)
        m.push(editPhone, on: .home)
        m.apply(.tab(.home))                                   // D20 re-tap empties the path
        m.popIfTop(editPhone, on: .home)
        XCTAssertEqual(m.path(for: .home), [])
        m.push(editPhone, on: .home)
        m.popIfTop(editPhone, on: .profile)                    // another tab: no-op
        XCTAssertEqual(m.path(for: .home), [editPhone])
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL (compile): "type 'UI2Destination' has no member 'editMemberField'", "value of type 'UI2ShellModel' has no member 'popIfTop'".

- [ ] **Step 3: Shell model + navigator.** In `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift` replace lines 15-19 (`/// ui2-members-browse D1: …` through the enum's closing brace) with:

```swift
/// ui2-members-browse D1: a page pushed onto a tab's NavigationStack. `name` is the list-known
/// title the pushed page's C-040 header shows while it loads (members-profile §3 `loading`).
/// ui2-members-edit D2: `editMemberField` — one member field's edit page, above the member page.
enum UI2Destination: Hashable {
    case memberDetail(id: String, name: String)
    case editMemberField(memberId: String, field: MemberField)
}
```

and directly after the closing brace of `mutating func pop(on tab: TabBar.Tab)` insert:

```swift

    /// ui2-members-edit D13: the success pop — only while `destination` is still the tab's last
    /// entry, so a swipe-back or a Home re-tap during the save leaves the stack alone.
    mutating func popIfTop(_ destination: UI2Destination, on tab: TabBar.Tab) {
        guard path(for: tab).last == destination else { return }
        pop(on: tab)
    }
```

In `iphone/MakeReady/UI2/Shell/UI2Navigation.swift` replace lines 4-9 with:

```swift
/// ui2-members-browse D1: how a container moves its own tab's stack. UI2Shell injects one per
/// NavigationStack, bound to that stack's tab; the default (previews, capture) does nothing.
struct UI2Navigator {
    var push: (UI2Destination) -> Void = { _ in }
    var pop: () -> Void = {}
    /// ui2-members-edit D13: pop only if `destination` is still on top.
    var popIfTop: (UI2Destination) -> Void = { _ in }
}
```

In `iphone/MakeReady/UI2/Shell/UI2Shell.swift` replace lines 65-68 with:

```swift
        .environment(\.ui2Navigator, UI2Navigator(
            push: { model.push($0, on: tab) },
            pop: { model.pop(on: tab) },
            popIfTop: { model.popIfTop($0, on: tab) }
        ))
```

and replace `page(for:)` (lines 85-89) with:

```swift
    @ViewBuilder private func page(for destination: UI2Destination) -> some View {
        switch destination {
        case let .memberDetail(id, name): MemberDetailHost(id: id, name: name)
        case let .editMemberField(memberId, field): MemberFieldEditContainer(memberId: memberId, field: field)  // ui2-members-edit D2
        }
    }
```

- [ ] **Step 4: Run the shell tests** — `npm run ios:build-check -- --test` → still FAIL to compile, now only on "cannot find 'MemberFieldEditContainer' in scope" (UI2Shell). That is the next step.

- [ ] **Step 5: The edit container** — create `iphone/MakeReady/UI2/Containers/Members/MemberFieldEditContainer.swift`:

```swift
import SwiftUI

/// ui2-members-edit §iphone Edit container: the `.editMemberField` destination (D2). Reads only
/// `AppState.memberDetails[memberId]` (D27), builds the field's built screen (D3, D10, D14),
/// runs the D16 checks before any request, owns `saving` and the inline error (D13), saves
/// through `MemberActions.updateMember` (D15, D21) and pops only if this page is still on top.
/// Back at any time discards silently (P11): the draft lives only in the screen's own state.
/// F5: the post-save `loadMember` overlaps the member page's `.task` reload on reappear — the
/// APIClient GET coalescer dedupes them.
struct MemberFieldEditContainer: View {
    let memberId: String
    let field: MemberField

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    /// D13 `saving` — set synchronously on Save, so a second tap is a no-op.
    @State private var saving = false
    /// D13 `save-failed` / D16: the inline line above Save; "" draws none.
    @State private var errorText = ""

    var body: some View {
        Group {
            if let detail = AppState.shared.memberDetails[memberId] {
                screen(MemberFieldEditModel.page(
                    field, detail: detail, saving: saving, errorMessage: errorText,
                    today: Date(), calendar: .current
                ))
            } else {
                // D27: rows open this page only once the member is loaded; a sign-out mid-page
                // clears the store and UI2Root swaps to Login.
                Token.layoutBackground
            }
        }
        .background(Token.layoutBackground.ignoresSafeArea())
    }

    @ViewBuilder private func screen(_ page: MemberFieldPage) -> some View {
        switch page {
        case let .textSingle(state, canSave):
            EditTextSingleFieldScreen(state: state, onBack: { navigator.pop() },
                                      onSave: { save(.text($0)) }, canSave: canSave)
        case let .textMulti(state):
            EditTextMultiFieldScreen(state: state, onBack: { navigator.pop() }, onSave: { save(.text($0)) })
        case let .option(state):
            EditOptionFieldScreen(state: state, onBack: { navigator.pop() }, onSave: { save(.option($0)) })
        case let .date(state):
            EditDateFieldScreen(state: state, onBack: { navigator.pop() }, onSave: { save(.date($0)) })
        }
    }

    /// D16 first (the server's message inline, no request); then D13: `saving` set synchronously,
    /// the save in an unstructured Task, the pop only if this page is still the last entry.
    private func save(_ input: MemberFieldInput) {
        guard !saving else { return }
        if let message = MemberFieldEditModel.validate(field, input, today: Date(), calendar: .current) {
            errorText = message
            return
        }
        saving = true
        errorText = ""
        let patch = MemberFieldEditModel.patch(field, input)
        let destination = UI2Destination.editMemberField(memberId: memberId, field: field)
        let actions = MemberActions(onUnauthorized: { [authManager] in
            // ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
            do { try await authManager.signOut() } catch {
                AppState.shared.recordError(error, context: "MemberFieldEditContainer.signOut", surface: false)
            }
        })
        Task { @MainActor in
            let result = await actions.updateMember(memberId, patch)
            saving = false
            switch result {
            case .success:
                navigator.popIfTop(destination)
            case .failure(let error):
                errorText = MemberFieldEditModel.message(for: error)   // value kept, Save re-enabled
            }
        }
    }
}
```

Register it in target `MakeReady`, then mirror into `MakeReadyCapture` (from `iphone/`):

```bash
cd iphone && ruby -rxcodeproj -e '
p = Xcodeproj::Project.open("MakeReady.xcodeproj")
g = p.main_group.find_subpath("MakeReady/UI2", false) or abort("no group MakeReady/UI2")
path = "Containers/Members/MemberFieldEditContainer.swift"
unless g.files.any? { |f| f.path == path }
  ref = g.new_reference(path)
  ref.name = File.basename(path)
  p.targets.find { |t| t.name == "MakeReady" }.add_file_references([ref])
end
p.save' && ruby scripts/capture-targets.rb && ruby scripts/capture-targets.rb --check
```
→ the last command exits 0 (in sync).

- [ ] **Step 6: The member page pushes it.** In `iphone/MakeReady/UI2/Containers/Members/MemberProfileContainer.swift` replace lines 27-31:

```swift
        let state = {
            var state = mapped
            state.programCoverURLs = Self.cachedCoverURLs(mapped.programCoverURLs)
            return state
        }()
```

with:

```swift
        let state = {
            var state = mapped
            state.programCoverURLs = Self.cachedCoverURLs(mapped.programCoverURLs)
            state.fieldsEditable = app.memberDetails[memberId] != nil     // ui2-members-edit D27
            return state
        }()
```

and replace the `MembersProfileScreen(...)` call (lines 44-49) with:

```swift
                MembersProfileScreen(
                    state: state,
                    showsHeader: false,
                    // ui2-members-edit D2: a field row pushes its edit page on this tab's stack.
                    // Group rows, program rows, both `add`s and the day cards stay no-ops (browse D5).
                    onEditField: { navigator.push(.editMemberField(memberId: memberId, field: $0)) }
                )
```

- [ ] **Step 7: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (the two new shell tests and every existing `UI2ShellModelTests` case — `UI2Destination` stays `Hashable`). Then `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 8: Commit** — `git add iphone/MakeReady/UI2/Shell/UI2ShellModel.swift iphone/MakeReady/UI2/Shell/UI2Navigation.swift iphone/MakeReady/UI2/Shell/UI2Shell.swift iphone/MakeReady/UI2/Containers/Members/MemberFieldEditContainer.swift iphone/MakeReady/UI2/Containers/Members/MemberProfileContainer.swift iphone/MakeReadyCaptureTests/UI2ShellModelTests.swift iphone/MakeReady.xcodeproj/project.pbxproj && git commit -m "feat(ui2-members-edit): member field rows push their edit page; save pops only while on top"`

### Task 11: Emergency phone display per D7 (T12)
App: iphone
Phase: 4
Recipe: REFERENCE §House rules (iphone) · tiny

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Members/MemberProfileMapper.swift:46` (the `emergencyContactPhone:` line) and add `contactPhoneLabel` after `phoneLabel` (:108)
- Test: `iphone/MakeReadyCaptureTests/MemberProfileMapperTests.swift` (append)

**Interfaces:**
- Consumes: `MemberProfileMapper.state(_:today:timeZone:)`, the test class's existing `tony()` and `map(_:)` helpers.
- Produces: `static func contactPhoneLabel(_ typed: String) -> String` — D7: a value made of digits plus only separators (space, `-`, `.`, `(`, `)`, `+` — `+` counts as a separator) holding exactly 10 digits, or 11 digits starting `1`, shows as `+1 (AAA) BBB-CCCC` (browse D23's form); anything else shows as typed. The Phone row keeps `phoneLabel` (browse D23).

- [ ] **Step 1: Write the failing test** — append inside `final class MemberProfileMapperTests`, before its final closing brace:

```swift
    // MARK: - ui2-members-edit D7: Emergency phone display

    func testEmergencyPhoneDisplayRule() {
        let rows: [(String, String)] = [
            ("5551234567", "+1 (555) 123-4567"),
            ("(555) 123-4567", "+1 (555) 123-4567"),
            ("555.123.4567", "+1 (555) 123-4567"),
            ("1-555-123-4567", "+1 (555) 123-4567"),
            ("+1 555 123 4567", "+1 (555) 123-4567"),       // `+` is a separator
            ("+11234567891", "+1 (123) 456-7891"),
            ("555-1234", "555-1234"),                       // 7 digits: as typed
            ("555-123-4567 x12", "555-123-4567 x12"),       // an extension: as typed
            ("+44 20 7946 0958", "+44 20 7946 0958"),       // 12 digits: as typed
            ("25551234567", "25551234567"),                 // 11 digits not starting 1
            ("", "")
        ]
        for (typed, shown) in rows {
            XCTAssertEqual(MemberProfileMapper.contactPhoneLabel(typed), shown, typed)
        }
    }

    func testEmergencyPhoneRowUsesTheContactRule() {
        var d = tony()
        d.emergencyContactPhone = "555.123.4567"
        XCTAssertEqual(map(.init(name: "Tony S.", detail: d)).emergencyContactPhone, "+1 (555) 123-4567")
        d.emergencyContactPhone = "555-123-4567 ext. 2"
        XCTAssertEqual(map(.init(name: "Tony S.", detail: d)).emergencyContactPhone, "555-123-4567 ext. 2")
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL (compile): "type 'MemberProfileMapper' has no member 'contactPhoneLabel'".

- [ ] **Step 3: Write the minimal implementation** — in `iphone/MakeReady/UI2/Containers/Members/MemberProfileMapper.swift` replace line 46:

```swift
            emergencyContactPhone: phoneLabel(d?.emergencyContactPhone ?? ""),
```

with:

```swift
            emergencyContactPhone: contactPhoneLabel(d?.emergencyContactPhone ?? ""),   // ui2-members-edit D7
```

and directly after the closing brace of `static func phoneLabel(_ e164: String) -> String` insert:

```swift

    /// ui2-members-edit D7: the Emergency phone is stored as typed. A bare NANP number — only
    /// digits and separators (space, `-`, `.`, `(`, `)`, `+`), exactly 10 digits or 11 starting
    /// `1` — shows in browse D23's form; anything else (extensions, other countries) as typed.
    static func contactPhoneLabel(_ typed: String) -> String {
        let separators: Set<Character> = [" ", "-", ".", "(", ")", "+"]
        let isDigit: (Character) -> Bool = { ("0"..."9").contains($0) }
        guard typed.allSatisfy({ isDigit($0) || separators.contains($0) }) else { return typed }
        let digits = typed.filter(isDigit)
        let ten: [String]
        if digits.count == 10 {
            ten = digits.map { String($0) }
        } else if digits.count == 11, digits.hasPrefix("1") {
            ten = digits.dropFirst().map { String($0) }
        } else {
            return typed
        }
        return "+1 (\(ten[0..<3].joined())) \(ten[3..<6].joined())-\(ten[6..<10].joined())"
    }
```

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (both new tests, and the existing `testIdentityQuickStatsAndFields` assertion `"+11234567891"` → `"+1 (123) 456-7891"` still holds). Then `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 5: Commit** — `git add iphone/MakeReady/UI2/Containers/Members/MemberProfileMapper.swift iphone/MakeReadyCaptureTests/MemberProfileMapperTests.swift && git commit -m "feat(ui2-members-edit): emergency phone displays as typed unless it is a bare NANP number (D7)"`
