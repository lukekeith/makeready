# Guest Contributor — Architecture

← [README](README.md) · [UX flows](02-ux-flows.md) · [Delivery plan](03-delivery-plan.md)

This document specifies the system design. It assumes the four locked decisions (D1–D4) in the README. Every "today" claim is anchored to a file/line in `main` @ `776a4ab`.

---

## 1. Identity & tenancy

### Today (the two obstacles)
1. **Auto-org-creation.** The Passport Google strategy creates a **brand-new `Organization` with the new user as `ownerId`** for every first-seen `googleId` (`server/src/config/passport.ts:32-59`; also the client token-exchange path `auth.ts:1087-1109`). An invited contributor who signs in today becomes owner of *their own* org — the wrong tenant.
2. **Leader gate.** `canAccessIosApp()` (`auth.ts:20-43`) admits only super admins, org owners, and `Owner`/`Admin`/`Group Leader` role-holders, and it **excludes Contributor** (`auth.ts:39`). The whole `/admin` web app sits behind it.

### Design

**A contributor is a real `User`, attached to the leader's org through grants only — never through a role or an org of their own** (D3).

- **Redemption-aware signup.** OAuth initiated from an invite carries the invite token in the OAuth `state`. On callback, a new branch (`redeemContributionInvite`) runs **instead of** the auto-org path:
  1. Resolve the `ContributionInvite` by token; verify it's `PENDING` and unexpired.
  2. **Email-lock check (D2):** the authenticated Google email must equal `invite.email` (case-insensitive). Mismatch → hard reject, invite stays `PENDING`.
  3. Find-or-create the `User` by `googleId`. **If newly created, skip organization creation entirely** — the contributor has `organizationId = null` (the field is already nullable/deprecated, `schema.prisma:171`) and no `UserRole`.
  4. Provision the `ContributorGrant`(s) from the invite in the **leader's** `organizationId`.
  5. Mark the invite `CLAIMED`, record `claimedByUserId`.
  6. Redirect to the contributor surface (`/contribute/:grantContext`), **not** `/member/groups` or `/admin`.
- **Existing users can contribute in other orgs.** A `ContributorGrant.organizationId` is independent of `User.organizationId`, so someone who already owns their own org can hold a grant in a *different* leader's org without any tenancy conflict. (An existing user redeeming a link just skips step 3's create.)
- **Contributors do not use `/admin`.** `canAccessIosApp` stays leader-only and unchanged. A **new gate** `canAccessContributorSurface(userId)` = "has ≥1 `ACTIVE` `ContributorGrant`" guards the new contributor routes. Contributors never pass the leader gate; leaders don't need grants.

> **Invariant (enforced + tested):** a contributor `User` has **zero `UserRole` rows** and is **never** an `Organization.ownerId`. Both are the conditions `canManageOrgContent()` checks, so a contributor is denied org-wide access *by construction*.

---

## 2. The object-level permission subsystem (the core)

### Today
- `hasPermission(subject, permission, resourceType?, resourceId?)` (`permission.ts:179-251`) resolves authority from `UserRole` → `RolePermission`, with super-admin and org-owner bypasses.
- `getOrganizationForResource()` resolves **only** `organization`, `group`, `media` (`permission.ts:116-143`) — there is no lesson/activity/study resolver.
- `canManageOrgContent(userId, orgId, creatorId)` grants creator **OR** super admin **OR** org owner **OR** **any role-holder in the org** (`permission.ts:293-297`). This is the anti-pattern for scoping — but it also means **a role-less contributor is already denied**.

### Design: `ContributorGrant` + a scope resolver, orthogonal to roles

A contributor is authorized **exclusively** by grants. We add a resolver and thread a **grant-check branch** onto the specific endpoints in the contributor flow. We do **not** weaken any existing guard; we add an alternate "OR the caller holds a covering grant" path only where a contributor legitimately needs to act.

**`ContributorGrant`** — one row per scoped capability:

| Field | Type | Notes |
|-------|------|------|
| `id` | uuid | |
| `organizationId` | fk → Organization | the **leader's** org (the tenant the grant lives in) |
| `userId` | fk → User | the contributor |
| `grantedByUserId` | fk → User | the leader who issued it |
| `studyProgramId` | fk → StudyProgram | denormalized; always set, scopes every check to one study |
| `targetType` | enum | `LESSON` \| `ACTIVITY` \| `PROGRAM_CREATE` (D1) |
| `targetId` | string? | lessonId (LESSON) or lessonActivityId (ACTIVITY); null for PROGRAM_CREATE |
| `createQuota` | int? | PROGRAM_CREATE only — max new lessons the contributor may create |
| `createdLessonIds` | string[]? | PROGRAM_CREATE — lessons this grant has spawned (enforces the quota) |
| `capabilities` | string[] | v1: `["CONTENT_EDIT"]` (implies read of the target + its children) |
| `status` | enum | `ACTIVE` \| `REVOKED` \| `COMPLETED` |
| `expiresAt` | datetime? | optional hard expiry |
| `createdAt`/`updatedAt` | datetime | |

**The resolver** — `resolveContributorScope(userId, target)` → `{ allowed, grant }`:
- `target` is one of `{ programId }`, `{ lessonId }`, `{ activityId }`.
- For a **LESSON** grant: allow reads/edits of that lesson and any `LessonActivity`/`ActivityReadBlock`/exegesis-highlight **whose parent chain resolves to `targetId`**.
- For an **ACTIVITY** grant: allow reads/edits of that activity and its children only; **deny** the sibling activities and the lesson container's other content.
- For a **PROGRAM_CREATE** grant: allow `POST` new lessons into `studyProgramId` up to `createQuota`, and (implicitly, via the lessons it spawns) LESSON-level authority over each `createdLessonId`.
- Every branch verifies `grant.status === ACTIVE`, not expired, and `grant.studyProgramId` matches the target's study. **Cross-study, cross-org, and cross-scope targets are denied.**

**Enforcement pattern** on a content route (illustrative, not final code):

```
// existing guard result:
const canManage = await canManageOrgContent(userId, orgId, resource.creatorId)
// new alternate path:
const scoped   = canManage ? null : await resolveContributorScope(userId, { activityId })
if (!canManage && !scoped?.allowed) return res.status(403)
```

Because the contributor fails `canManageOrgContent`, the **only** way they proceed is a covering grant, checked **server-side against the exact target** — never trusting a client-supplied scope. This is defense-in-depth: even if the scoped UI is bypassed, the API denies out-of-scope writes.

**Endpoints that receive the grant-check branch** (the complete v1 list — the audit surface):
- Read (scoped): a **new** `GET /contributor/assignments` and `GET /contributor/assignments/:grantId` returning **only** the in-scope lesson(s)/activity(ies) + the leader's topic/instructions. Contributors **never** hit `GET /programs/:id` (returns the whole study — `leader-program.store.ts:328`).
- Author: `POST /programs/:id/lessons` (PROGRAM_CREATE only, quota-checked), `POST /programs/:id/lessons/:lessonId/activities`, `PATCH /activities/:id`, read-block CRUD (`programs.ts:2044-2120`, `:473-539` client), exegesis-highlight CRUD.
- Video: `POST /api/videos/upload-url`, `POST /api/videos` (creates a `Video` owned by the contributor's `userId` — already the model, `schema.prisma:531-553`), then attach via `PATCH /activities/:id { videoId }`. The existing attach already requires `video.userId === caller` (`programs.ts:2077-2084`) — which **passes** for the contributor's own upload and **blocks** them from attaching anyone else's video. No org-library exposure.
- Submit: a **new** `POST /contributor/assignments/:grantId/submit`.

> Everything **not** in this list stays denied for a role-less contributor by the existing guards. The audit is bounded to this list.

---

## 3. Invite & assignment model

### Today
The `Invite` model (`schema.prisma:289-303`) is **phone/SMS/group-only**: `token`, `groupId?`, `recipientPhone`, no role, no email, no content target. Redemption matches by `Member.phoneNumber` and always creates `role:'member'` (`invite.ts:203,237`). It is unfit for this; we add a **new** model rather than overload it.

### Design: `ContributionInvite`

| Field | Type | Notes |
|-------|------|------|
| `id` | uuid | |
| `token` | string unique | unguessable; in the magic-link URL |
| `organizationId` | fk | leader's org |
| `inviterUserId` | fk → User | the leader |
| `studyProgramId` | fk → StudyProgram | the study |
| `email` | string | **email-lock target** (D2) |
| `scopeType` | enum | `LESSON` \| `ACTIVITY` \| `PROGRAM_CREATE` |
| `targetLessonId` / `targetActivityId` | string? | for LESSON/ACTIVITY scope |
| `requestedLessonCount` | int? | PROGRAM_CREATE — "fill out N lessons" |
| `topicDirection` | text? | the leader's guidance ("what the study is / what to write") |
| `status` | enum | `PENDING` \| `CLAIMED` \| `REVOKED` \| `EXPIRED` |
| `claimedByUserId` | fk? | set on redemption |
| `expiresAt` | datetime? | |
| `createdAt`/`updatedAt` | datetime | |

On redemption, the invite **spawns the `ContributorGrant`(s)**: a LESSON/ACTIVITY invite → one grant; a PROGRAM_CREATE invite → one `PROGRAM_CREATE` grant with `createQuota = requestedLessonCount`. `topicDirection` is surfaced to the contributor throughout their editing session.

**Non-shareable guarantee (D2)** rests on three legs: (1) unguessable token, (2) email-lock at redemption, (3) `PENDING → CLAIMED` is one-shot — once claimed, re-opening the link routes the claimer to their assignment and everyone else to a "this invite isn't for you" page.

---

## 4. Authorship tracking

### Today
No `authorId` on `Lesson`/`LessonActivity` (`schema.prisma:913-971`); the only "author" concept is `Post.authorId`. Lesson ownership is inferred up-chain via `StudyProgram.creatorId`.

### Design (small, shared with FR-8)
- `Lesson`: add `authorId? (fk User)` + `authorType (enum LEADER|CONTRIBUTOR, default LEADER)`.
- `LessonActivity`: add `authorId? (fk User)` for activity-scoped attribution.
- Set on contributor create/edit; **display** "Guest author: {name}" on the lesson in the leader review UI and (product decision — see open questions) optionally to members. This same field satisfies FR-8's "keep track of the lesson author (guest)."

---

## 5. Review & quarantine

### Principle
Contributed content may exist in the study's curriculum **but must be excluded from anything members can see until the leader approves it** (D4). The single enforcement point is the **publish snapshot builder + enrollment sync**, which already exist and already decide what reaches members.

### Design: `Contribution` + a snapshot/sync gate

**`Contribution`** — one per unit of submitted work:

| Field | Type | Notes |
|-------|------|------|
| `id` | uuid | |
| `grantId` | fk → ContributorGrant | |
| `contributorUserId` | fk → User | |
| `studyProgramId` | fk | |
| `targetType` / `targetLessonId` / `targetActivityId` | | what was produced/filled |
| `status` | enum | `DRAFT` \| `SUBMITTED` \| `APPROVED` \| `REJECTED` |
| `submittedAt` / `reviewedAt` / `reviewedByUserId` | | |
| `feedbackNotes` | text? | **v2** (D4 defers) |
| `createdAt`/`updatedAt` | | |

**The gate.** The publish pipeline builds a canonical snapshot from lessons (`buildSnapshotLessons`, `study-program-publish.ts:285`) and the sync engine fans versions to enrollments (`enrollment-sync.ts`). We add **one filter**: content associated with a `Contribution` whose `status !== APPROVED` is **omitted** from the snapshot and from sync. Concretely:
- **LESSON / PROGRAM_CREATE** contribution → the whole lesson is excluded from publish/sync while `SUBMITTED`/`DRAFT`/`REJECTED`. On `APPROVED`, it joins the next published version and syncs normally (the "auto-added to the calendar" behavior FR-1 already provides).
- **ACTIVITY** contribution to a **not-yet-published** lesson → same: the containing lesson isn't live yet, so the draft activity is naturally quarantined; approval simply clears the gate.

This unifies both worlds: a **draft study** (leader publishes after approving) and a **live study** (FR-1 — sync excludes until approved) use the *same* gate.

### The one hard edge (v1.1/v2): activity-scoped edits to already-live content
If a contributor is asked to redo one activity inside a lesson that is **already published and enrolled**, the "omit from snapshot" gate can't simply hide it (the lesson is live). The correct mechanism is **version-pinning**: the contributor edits a **pending revision** of that activity that the sync engine treats as not-yet-approved; on approval it becomes the current `LessonScheduleVersion`. This reuses the existing versioning primitives (`LessonScheduleVersion`, `schema.prisma`), but is meaningfully more work. **v1 restricts activity/lesson contributions to not-yet-published lessons**; live-content revision is called out as a fast-follow.

---

## 6. Web video recording

**Confirmed in scope.** The leader stated the web admin must support recording; the contributor flow needs "record a video of themselves."

### Today
- **Web has no capture path.** `grep MediaRecorder|getUserMedia|navigator.mediaDevices` in `client/` → **0 hits**. The web "video picker" only *selects* an already-uploaded video (`leader-program.store.ts:640` `loadMyVideos()` → `GET /admin/api/videos/me`; `updateActivityVideo()` PATCHes `{videoId, videoUrl}`). Recording is explicitly excluded in the parity manifest (`docs/parity/manifest.md:131`).
- **The server pipeline is complete and tested:** `POST /api/videos/upload-url` → `createDirectUploadUrl()` returns a Cloudflare Stream direct-upload URL (TUS/form) → client uploads **straight to Cloudflare** → `POST /api/videos` finalizes the `Video` record (`videos.ts:208,365`). The iPhone already uses exactly this.

### Design (client-only build against the existing server API)
A reusable `<VideoCapture>` component with two acquisition modes, both feeding the **same** upload pipeline:
1. **In-browser capture** — `navigator.mediaDevices.getUserMedia({video,audio})` + `MediaRecorder` → a recorded `Blob`; live preview, record/stop, re-record, and a confirm step.
2. **File upload fallback** — a file `<input accept="video/*" capture="user">`; on mobile this invokes the native camera. **Required** because iOS Safari's `MediaRecorder` support is unreliable — the contributor may well be on an iPhone browser.

Then: `POST /api/videos/upload-url` → upload the blob/file to Cloudflare (TUS for resumability on large/long clips) → poll `POST /api/videos/:id/refresh` until `ready` → `PATCH /activities/:id { videoId, videoUrl, status:'COMPLETE' }`.

**Design notes / edge cases:** camera+mic permission prompt and denial UX; max duration + size guidance; codec (`video/webm` from `MediaRecorder`, Cloudflare transcodes to HLS on ingest); upload progress + resumability; "processing" state while Cloudflare transcodes; unstable-network resume; and a **re-record/discard** loop. **Teleprompter parity is v2.** This component is shared: the leader app gets web recording too (closing the parity gap) — build it once in the shared editor layer.

---

## 7. Data model changes (YAML-first)

All server schema changes go through `server/schema/schema.yaml` → the `/schema` Atlas workflow → generated `prisma/schema.prisma` (never a direct Prisma edit; per `server/.claude/CLAUDE.md`).

**New models:** `ContributionInvite`, `ContributorGrant`, `Contribution` (§3, §2, §5).
**New enums:** `ContributorTargetType (LESSON|ACTIVITY|PROGRAM_CREATE)`, `ContributionInviteStatus`, `ContributorGrantStatus`, `ContributionStatus`, `LessonAuthorType (LEADER|CONTRIBUTOR)`.
**Modified models:** `Lesson` (+`authorId?`, +`authorType`), `LessonActivity` (+`authorId?`).
**Indexes:** `ContributorGrant(userId, status)`, `ContributorGrant(studyProgramId)`, `ContributionInvite(token)` unique, `Contribution(studyProgramId, status)`.

No destructive migrations — all additive.

---

## 8. API surface

### New (contributor-scoped) — behind `canAccessContributorSurface`
| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/contributor/assignments` | list the caller's active grants (+ study/topic context) |
| `GET` | `/contributor/assignments/:grantId` | the in-scope lesson/activity content **only** + instructions |
| `POST` | `/contributor/assignments/:grantId/submit` | move `Contribution` DRAFT → SUBMITTED |

### New (leader-side) — behind existing leader guards
| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/programs/:id/contribution-invites` | create an email-locked invite (scope, count, topic) |
| `GET` | `/programs/:id/contribution-invites` | list/track invites for a study |
| `DELETE`/`PATCH` | `/contribution-invites/:id` | revoke / resend |
| `GET` | `/programs/:id/contributions` | the **review queue** for a study |
| `POST` | `/contributions/:id/approve` | approve → clears the quarantine gate |
| `POST` | `/contributions/:id/reject` | reject (v2: with `feedbackNotes`) |

### New (auth) 
| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/auth/google?invite=:token` (state-carried) | redemption-aware OAuth entry |
| `GET` | `/auth/contributor-access` | mirror of `/auth/leader-access` for the new gate |

### Modified (add grant-check branch)
`PATCH /activities/:id` · `POST /programs/:id/lessons` · `POST /programs/:id/lessons/:lessonId/activities` · read-block + exegesis-highlight CRUD · `POST /api/videos` attach path. Each gains the **"OR covering grant"** alternate authorization; none loses an existing check.

### Modified (quarantine gate)
`publishProgramVersion()` / `buildSnapshotLessons` and `enrollment-sync` gain the **`Contribution.status === APPROVED`** filter (§5).

---

## Security model & threat cases

The design fails **closed**. Each risk below has a concrete guarantee + a test hook (see [03 § Test plan](03-delivery-plan.md#test-plan)).

| # | Threat | Guarantee |
|---|--------|-----------|
| S1 | Contributor gains org-wide access | Contributor holds **no `UserRole`** and is **not** an org owner → `canManageOrgContent` returns false → every existing content guard denies. Invariant test asserts zero roles for any user with a grant. |
| S2 | Auto-org-creation makes contributor an owner | Redemption path **skips** org creation (§1); an invited signup never reaches `passport.ts:32-59`. Test: redeem as a brand-new googleId, assert no `Organization` was created. |
| S3 | Out-of-scope target (sibling activity / other lesson / other study / other org) | `resolveContributorScope` verifies the target's parent chain resolves to `grant.targetId` **and** `grant.studyProgramId` **and** `grant.organizationId`, server-side. Deny matrix test across all four axes. |
| S4 | Client bypasses the scoped UI and calls an API directly | Authorization is **server-side per target**, never trusts a client-supplied scope. The grant-check branch runs on every listed endpoint. |
| S5 | Link forwarded to the wrong person | Email-lock (D2): authenticated Google email must match `invite.email`; one-shot `CLAIMED`. |
| S6 | Contributor reads/attaches org media | Contributor picker is disabled/limited to their **own** uploads; the attach path already enforces `video.userId === caller` (`programs.ts:2077`). |
| S7 | Unapproved content leaks to members | Publish snapshot **and** sync both filter on `Contribution.status === APPROVED` (§5). Tests cover **both** the draft-study publish path and the live-study sync path. |
| S8 | Revoked/expired grant still works | Every scoped check requires `status === ACTIVE` and not expired; revoke takes effect immediately. Test: revoke mid-session, assert next write 403s. |
| S9 | PROGRAM_CREATE quota abuse | Create endpoint checks `createdLessonIds.length < createQuota` atomically. |

**The two ways to fail open (call-outs for review):** (S1/S2) an identity slip that lands the contributor in the wrong tenant or with a role, and (S3/S4) a content route that a contributor can reach *without* the grant-check branch. Both are addressed by (a) the zero-role invariant and (b) a **bounded, enumerated** endpoint list (§2) — the audit is finite because a role-less user starts fully denied.
