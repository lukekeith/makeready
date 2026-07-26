# Feature Requests — Feasibility & Effort Analysis

**Board:** Feature requests (`18417603408`) · **Analyzed:** 2026-07-25 against `main` @ `776a4ab`
**Method:** all 12 tickets read in full; each traced to concrete code across `/server`, `/client`, `/iphone` via five parallel codebase investigations. Every effort read below is anchored to file/line evidence, not vibes.

This supersedes the shallower [feature-requests.md](feature-requests.md) (2026-07-05) with a deeper feasibility pass — scope, edge cases, per-sub-capability effort, and (the headline) where **one platform investment collapses several requests into a single build**.

---

## How to read this

- **T-shirt sizes:** `XS` (hours) · `S` (~1–3 days) · `M` (~1–2 weeks) · `L` (~3–6 weeks) · `XL` (multi-month, multiple subsystems). Sizes are *engineering* effort assuming product/UX is defined; where UX definition is the real cost, it's called out.
- **12 tickets → 9 distinct features.** Two duplicate pairs: `12270300418 ≡ 12354285433` (add content to published study) and `12303207603 ≡ 12273864192` (makeready videos). FR-numbers continue the 2026-07-05 doc for continuity.
- **Schema note:** the server schema is **YAML-first** (`server/schema/schema.yaml` → generated `prisma/schema.prisma`). Any model/field change below must go through the `/schema` Atlas workflow, not a direct Prisma edit.

---

## Summary table

| FR | Feature | Tickets | T-shirt | One-line verdict |
|----|---------|---------|:------:|------------------|
| **FR-7** | 🚩 Guest contributor invites | 12266593869 | **XL** | Flagship. Net-new object-level permission subsystem + identity rework. The big bet. |
| FR-1 | Add content to a published study | 12270300418, 12354285433 | **S–M** | Backbone already exists (copy-on-enroll + sync engine). Mostly UX + policy. |
| FR-2 | Skip / reschedule / special lesson | 12270300519 | **M** (+**L** for true one-off) | Skip/reschedule endpoints exist; only "lesson not in curriculum" is net-new. |
| FR-3 | Lesson library & migration | 12268474877 | **L** | Copy machinery exists; a lesson-independent-of-a-study *library* does not. |
| FR-4 | Duplicate a study | 12268427023 | **S** | Reuse existing export/import internals as one in-process endpoint. |
| FR-5 | Custom lesson templates | 12268463248 | **S–M** | Template CRUD + duplicate already ship; needs only a study-scope field. |
| FR-6 | Remove people from a group | 12303257933 | **XS** | ✅ **Already built** end-to-end. Close the ticket (check reporter's role). |
| FR-8 | MakeReady video library in lessons | 12303207603, 12273864192 | **M** picker/tags · **L–XL** w/ transcript search | Org library + tags exist; "search by spoken words" is a net-new pipeline. |
| FR-9 | AI note summaries & lesson chapters | 12303272591, 12303188320 | **L** | Per-lesson AI summary already ships; blocked on chapters + a completion trigger + a notes-reading screen. |

---

## The consolidation thesis (read this first)

The requests are not nine unrelated builds. They collapse onto **one flagship platform bet and four shared foundations.** Sequencing to the *foundations* rather than the *tickets* is how this list gets cheap.

### 🚩 Bet: the Contributor Platform (FR-7)
This is the theme you flagged, and it recurs across the board. It is the **only XL** on the list, and the reason is a single hard fact from the code:

> **Authorization today is org-scoped role + `creatorId` ownership, with _zero_ object-level scoping.** The dominant helper, `canManageOrgContent()` (`server/src/services/permission.ts:269-298`), grants **any** role-holder in an org **full CRUD over all org content** — the exact opposite of a sandboxed guest. There is no `permission.resource` value for a lesson/activity/study and no per-row ACL (`schema.prisma:405-417`, `permission.ts:116-143`).

So "an invited person cannot view, edit, create, or delete anything outside the scope of their invitation" cannot be expressed in the current model. It requires a **new resource-scoped grant layer, threaded deny-by-default through every content route.** That layer is a genuine platform capability — once it exists, a whole class of collaboration features (co-leaders, per-lesson delegation, org content roles) becomes cheap. Treat FR-7 as **infrastructure with a first feature riding on it**, not a feature.

**FR-7 pulls two other tickets into its orbit** (build once, reuse):
- **Web video capture** — FR-7 needs a guest to *record a video on the web*. Web has **no capture/upload path today** (`grep MediaRecorder|getUserMedia` in `client/` → 0 hits), but the *server* upload pipeline is built and tested (`videos.ts:208,365` → Cloudflare Stream). Building the browser side is client-only work that **also unlocks leader-side web recording generally** — a standing parity gap (`docs/parity/manifest.md:131`).
- **Lesson authorship** — FR-7's "keep track of the lesson author (guest)" is the same missing `authorId` field FR-8's provenance wants. One small addition serves both.

### Foundation A — Enrollment schedule/sync surface → serves FR-1, FR-2
The hard part is **already built**: copy-on-enroll (`LessonSchedule` *owns* its content, `schema.prisma:1031`), the versioned publish→sync fan-out (`enrollment-sync.ts`, selective `POST /enrollments/:id/sync/apply`), and add/skip/reschedule endpoints (`enrollments.ts:4291/4564/4645`). What's missing is mostly the **web UI** for it (the whole enrollment-schedule chain is still `—` in the parity manifest, `manifest.md:116-120`) plus a one-off-lesson primitive. FR-1 and FR-2 are the *same surface* — design and build them together.

### Foundation B — Deep-copy service → serves FR-3, FR-4, FR-5
The copy primitives are mature (`lesson-copy.ts`, template `POST /templates/:id/duplicate`, program `exportProgram`/`importProgram`). FR-4 is nearly free on top of them. FR-5's authoring stack already exists. FR-3 is the only one needing a genuinely new concept (a lesson that lives outside a single study). Do them in the order FR-4 → FR-5 → FR-3.

### Foundation C — Org content library → serves FR-8
The org-scoped `Media` library, `MediaTag`, and Cloudflare-Stream `Video` model already exist. The picker + tag-search halves are cheap. Only **transcript / spoken-word search** is net-new (and optional/deferrable).

### Foundation D — Member notes surface + AI → serves FR-9
The AI is the *most* mature piece — a per-lesson "how you learned" summary already ships in production (`AiLessonSummary`, opus-4-8). The blockers are structural: no chapters, no per-member study-completion moment, and **no screen that renders a member's past notes** (the read-back API exists but is dark).

---

# Per-feature dossiers

---

## 🚩 FR-7 — Guest contributor invites  ·  **XL**
**Ticket:** 12266593869 "Solicitation of lesson in study"

**The ask.** A leader sends a private, non-shareable link to a friend. The friend logs in with Google **on the web (no app download)** and becomes a scoped **contributor** who can create/edit **only** the lesson(s)/activity(ies) assigned — nothing else, in any direction. The leader can request N lessons, give topic direction, see the guest tracked as author, and accept/reject each submission (v2: leave feedback notes). Submissions auto-insert "for review," pending approval.

### Current state (evidence)
- A **`Contributor` role is already seeded** (`server/prisma/seed.ts:159-172`) and named in the schema comment (`schema.prisma:388) — but it grants **org-wide** `group.read`/`member.read`/`media.create`/`media.read`. There is no lesson/activity concept in it.
- Authorization = org-role + `creatorId` only. `canManageOrgContent()` grants **any** role-holder full CRUD over **all** org content (`permission.ts:293-297`). No object-level ACL exists (`permission.ts:116-143`; `Lesson`/`LessonActivity` have no `authorId`/owner, `schema.prisma:913-971`).
- Google login **auto-creates a brand-new Organization with the new user as owner** for every new `googleId` (`passport.ts:32-59`; token-exchange `auth.ts:1087-1109`). An invited guest today becomes owner of their *own* org — wrong tenant.
- The leader gate `canAccessIosApp()` (`auth.ts:20-43`) admits only Super Admin / owner / Owner|Admin|Group Leader roles and **deliberately excludes Contributor** (`auth.ts:39`). The whole `/admin` web app sits behind it.
- `Invite` model (`schema.prisma:289-303`) is **phone/SMS/group-only** — no role field, no target lesson/activity, no email/User recipient; redemption matches by `Member.phoneNumber` and always creates `role:'member'` (`invite.ts:203,237`).
- Web authoring itself is real: write/read/youtube/exegesis activity editors + create + publish + export are built and hit the **same server APIs** as iPhone (`leader-program.store.ts`; `manifest.md:83-92,143`). **Except video capture** (see below).

### Sub-capability breakdown
| # | Sub-capability | Size | Why |
|---|----|:--:|----|
| A | Scoped invite object (single-recipient, non-shareable, carries email + `roleId` + target ids + requested count + topic) | **M** | New model/columns + issue/expire/revoke logic; current `Invite` is phone/group-only. |
| B | Web Google login that lands the guest in the **leader's** org (not a new one) as a Contributor | **M–L** | Rework `passport.ts` auto-org-creation + a redemption branch attaching a `UserRole` to the inviter's org. Touches identity/tenancy — get it wrong and you leak a tenant. |
| C | **Object-level permission subsystem** (edit ONLY assigned lesson/activity; deny-by-default everywhere else) | **XL** | No resource-scoped authz exists. New grant table + resolver in `getOrganizationForResource` + deny-by-default threaded through every content route (`programs.ts` alone is ~4,000 lines), **and** neutralize `canManageOrgContent`'s "any role-holder" grant for contributors. This is the whole cost center. |
| D | Lesson authorship tracking + display | **S–M** | Add `authorId` to `Lesson`/`LessonActivity`, set on contributor create, surface in API + UI. (Shared with FR-8.) |
| E | "For review" state + per-item accept/reject (+ v2 feedback notes) | **L** | New review status/`ContributionReview` model + approval endpoints + **publish gating** so unapproved lessons never reach enrolled groups via sync (`study-program-publish.ts`, `enrollment-sync.ts`). |
| F | Assignment object (request N lessons + topic direction, track fulfillment) | **M** | New model linking contributor ↔ program ↔ requested count ↔ topic ↔ status; overlaps A. |
| G | Contributor-scoped web editor shell (a stripped `/admin` showing only assigned lessons) | **L** | Editors are overlay-presented off a **whole-program** store (`leader-program.store.ts:328`) with no per-lesson deep-link route; needs a scoped host + gate change that hides Library/Groups/Enrollments and skips whole-study loaders. |
| H | Web video capture/upload (guest records themselves) | **M** | Client-only: `getUserMedia`/`MediaRecorder` or file `<input>` → existing `POST /api/videos/upload-url` → Cloudflare TUS → `POST /api/videos`. Server side already tested. Teleprompter parity would push toward L. |

### Edge cases & nuances to design
- **Non-shareable link.** A URL is inherently shareable; "only available to them, can't share it" means binding the token to the *authenticated Google identity* on first redemption (email-locked), not device-locked. Decide: does clicking = claim-by-first-Google-login, or must the email match a pre-entered address? (The device-locked token in `study-preview.ts` is a *mechanics* reference, not the identity model.)
- **What is the scope unit** — a whole lesson, or a single activity within a lesson? The ticket says both ("provide a lesson" *and* "each one of the lesson activities"). Grant granularity drives table shape (C).
- **Draft isolation.** A contributor's in-progress lesson must be invisible to enrolled members until approved — the "for review" gate (E) must sit *upstream* of the publish/sync pipeline, or unapproved content fans out.
- **Reject semantics** — does reject delete, or return-to-contributor-with-notes (v2)? Attribution must survive a reject→resubmit cycle.
- **Contributor offboarding** — when the assignment closes, grants must be revoked but authorship display retained.
- **Media scoping** — a guest uploading a video creates a `Video` owned by their `userId`; it must attach to the assigned activity without exposing the org library (ties to FR-8's ownership coupling).

### Biggest architectural risk
Two independent ways to silently **over-permit** the guest: (1) the missing object-level layer means any accidental reuse of `canManageOrgContent`/an org role grants org-wide access; (2) identity rework must not drop the guest into their own auto-created org (`passport.ts:32-59`). Both fail *open*. This demands a deny-by-default design and a route-by-route authz audit — the reason it's XL, not L.

### Recommendation
**Phase it.** (1) Ship the **object-level permission layer (C) + identity/invite plumbing (A,B,F)** as infrastructure with a *text-only* contributor MVP (reuse existing web editors, gate C, authorship D). (2) Add the **review queue (E)**. (3) Add **web video capture (H)** — which independently closes a leader-parity gap. The teleprompter and v2 feedback notes are last.

---

## FR-1 — Add content to a published study ("living study")  ·  **S–M**
**Tickets:** 12270300418 + 12354285433 (duplicates)

**The ask.** Add lessons/content to an already-published, enrolled study; new lessons auto-join the calendar; a missed/empty date doesn't stop the study; lesson frequency is preserved; people can be added mid-study.

### Current state (evidence) — this is the **best-supported** request
- **Editing after publish is not blocked.** Curriculum lessons/activities stay editable; immutability lives only in the versioned *snapshots* (`StudyProgramVersion`, `schema.prisma:879-897`) and the copy-on-enroll design, not the editable curriculum.
- **Copy-on-enroll + sync fan-out already exist.** `publishProgramVersion()` cuts a snapshot, diffs added/removed/moved/changed, and fans out to enrollments in the background (`study-program-publish.ts:169-282`). `computePendingChanges()` classifies `new|updated|removed`; `syncEnrollmentToLatest()`/`applyVersion()` apply them progress-aware (soft-hide if a member has progress, else delete). Selective approval via `GET/POST /enrollments/:id/sync/changes|apply` (`enrollments.ts:1906,1956`).
- **Mid-study add auto-schedules.** `POST /enrollments/:id/schedules` walks forward across `enabledDays`, deep-copies activities, creates the calendar `Event`, extends `endDate` if needed (`enrollments.ts:4291`).
- **Missed dates don't stall.** `LessonSchedule.removedAt` soft-hide + "schedule owns its content" (`schema.prisma:1031`) keep the cadence on the enrollment regardless of misses.
- **New members inherit automatically.** Schedules are per-*enrollment* (group), not per-member; a `GroupMember` added mid-study inherits the existing schedule with no backfill.

### Gaps & edge cases
- `POST /enrollments/:id/schedules` requires the lesson to **already exist in the program** and inserts at the **end** of the calendar — no mid-sequence insert with date reshuffle beyond `applyVersion`'s freed-slot handling. Verify sync assigns a `scheduledDate` to newly-added lessons (logic just past `enrollments.ts:4370`).
- The **web UI for the enrollment-schedule surface is unbuilt** (parity `—`, `manifest.md:116-120`).
- Product policy: when a new lesson lands mid-sequence, does everyone's remaining calendar shift, or does it append? Does it SMS-notify?

### Effort
Server backbone is largely done → **S** for append-to-end; **M** once you add the web schedule UI and settle insertion/date policy. The real work is **UX definition**, not data modeling.

---

## FR-2 — Skip / reschedule / insert a special lesson  ·  **M** (+**L** for a true one-off)
**Ticket:** 12270300519

**The ask.** Insert a one-off lesson (current events, special date) into an enrolled study; skip or reschedule any lesson at any time; a skipped lesson can be rescheduled or removed.

### Current state (evidence)
- **Skip** = `DELETE /enrollments/:enrollmentId/schedules/:scheduleId` (`enrollments.ts:4645`). **Reschedule** = `PATCH …/schedules/:scheduleId` (`:4564`). **Insert existing lesson** = `POST …/schedules` (`:4291`). Whole-schedule re-layout on cadence change: `POST /enrollments/:id/edit/preview` + `PATCH /enrollments/:id` (`:1576,1669`).

### Gaps & edge cases
- **Missing primitive: a true "special lesson"** that is *not part of the program curriculum.* The add endpoint hard-rejects any `lessonId` outside the enrollment's program (`enrollments.ts:4324-4352`). A one-off needs: an enrollment-local lesson authoring path **and** sync-safety so a later publish/sync doesn't clobber or reorder it. → **L**.
- Same web-UI gap as FR-1 (shared surface).
- Known bug to fix alongside: iOS `addScheduledLesson` sends an empty body; the endpoint requires `{lessonId}` (zod, `enrollments.ts:4296-4299`) so it 400s. → **S** fix.

### Effort
**M** to expose skip/reschedule/insert-existing on web (endpoints exist). **L** for the ad-hoc special lesson. **Design FR-1 + FR-2 together** — one enrollment-schedule surface.

---

## FR-3 — Lesson library & migration  ·  **L**
**Ticket:** 12268474877

**The ask.** Move a lesson between studies; duplicate a lesson; move+copy without breaking study flow; compose a study by picking lessons from a library.

### Current state (evidence)
- Copy primitives are mature: `buildLessonCopyRows`/`buildLessonRowsFromSnapshot` (`lesson-copy.ts`), the template→lesson copy loop (`programs.ts:288-320`), and export/import prove full lesson-tree cloning works.

### Gaps & edge cases
- **`Lesson` is hard-bound to one study** — `studyProgramId` required, `@@unique([studyProgramId, dayNumber])`, cascade delete (`schema.prisma:913-929`). There is **no library table** and no lesson that exists independent of a study.
- **"Move"** = re-parent + re-key `dayNumber` **and** reconcile `LessonSchedule.lessonId` FKs (which point at the curriculum lesson) — moving a lesson referenced by a live enrollment is the sharp edge.
- **"Duplicate within a study"** is close to `POST /programs/:id/lessons`, but that stamps from the *template*, not from an existing lesson — needs a copy-from-lesson variant.
- **"Compose from a library"** needs the net-new concept: either a `LessonLibrary`/source-lesson entity or a documented copy-by-value convention with dayNumber renumbering.

### Effort
Intra-study duplicate is **S** (reuse copy helpers). A true cross-study library is **L** — the data-model concept + FK-safety around live enrollments is the cost. Pairs with FR-4/FR-5 (shared deep-copy foundation).

---

## FR-4 — Duplicate a study  ·  **S**
**Ticket:** 12268427023

**The ask.** Clone a study to re-target for a different audience ("dumb it down or dress it up").

### Current state (evidence)
- `exportProgram()`/`importProgram()` (`program-export.ts:116,329`; wired at `programs.ts:4015-4216`) already deep-clone a full study tree with **new IDs**. The copy logic is written and tested.

### Gaps & edge cases
- No **in-place** duplicate endpoint — only a zip download+reupload round-trip today.
- A direct `POST /programs/:id/duplicate` reuses the export deep-read include + import create logic in-process, resetting `isPublished`/`publishedAt`/`currentVersionNumber` and **dropping versions/enrollments** on the copy. Decide whether tags/cover carry over (import already handles them).

### Effort
**S** — mostly wiring existing internals into one endpoint + a single "Duplicate" action + naming dialog. No schema change.

---

## FR-5 — Custom lesson templates  ·  **S–M**
**Ticket:** 12268463248

**The ask.** Leader authors their own lesson templates; by default a custom template applies only to the study it was created in.

### Current state (evidence) — mostly **already built**
- Full `LessonTemplate` CRUD + activity CRUD + `POST /templates/:id/reorder-activities` (`templates.ts:161,693`) and **`POST /templates/:id/duplicate`** (`:358-413`) already exist. Templates scope by `isSystem`/`creatorId`/`organizationId` with `sourceTemplateId` provenance.
- `POST /api/programs` stamps `days` lessons from a chosen template (`programs.ts:215-365`); adding a day re-copies from `program.template.activities`.

### Gaps & edge cases
- Templates are **org/creator-wide**, not study-scoped. "By default only this study" needs a **scope field** (nullable `studyProgramId` or a scope enum) on `LessonTemplate` + a filter in the template-list query (`templates.ts:48`).
- Product decision: is a "study template" the existing *lesson*-shaped template, or a new *study*-level template (there is **no `StudyTemplate` model** — the study itself plays that role via export/import)? This choice is the S-vs-M swing.

### Effort
**S–M** — the authoring stack exists; the only real work is a study-scope column + filter and the product decision above.

---

## FR-6 — Remove people from a group  ·  **XS · ✅ already built**
**Ticket:** 12303257933

Fully implemented end-to-end:
- Server `DELETE /api/groups/:groupId/members/:memberId` (`group-members.ts:619-677`) — soft-delete + immutable `MembershipEvent` audit + history endpoint, gated by `requireGroupManage('group.update')`.
- Web LeaderApp: `members.domain.ts:133-146` → wired via `members-tab.ui.ts:59` and `member-detail.ui.ts:135`.
- iPhone: `GroupActions.swift`, `MemberProfilePage`, `ChangeMembershipModal` "Remove from group".

**Action:** close the ticket. If the reporter can't see it, it's a **role/discoverability** issue — check them against the `requireGroupManage('group.update')` gate, not missing functionality.

---

## FR-8 — MakeReady video library in lessons  ·  **M** (picker+tags) · **L–XL** (with transcript search)
**Tickets:** 12303207603 + 12273864192 (duplicates)

**The ask.** Insert one of ~400 existing MakeReady social videos into a lesson; find it by tag search **and by the words spoken in it**; architecture must generalize to per-org private content libraries.

### Current state (evidence)
- **Org content library already exists.** `Media` is org-scoped (`schema.prisma:453-498`) with `MediaTag` (indexed, `:500-512`) and `MediaUsage` (`LESSON_ACTIVITY`, `:514-529`). Videos auto-capture into it (`captureToLibrary`, `videos.ts:446-465`); bulk import exists (`POST …/media/upload/batch`, up to 50/call, `media.ts:1383`).
- **`Video`** = Cloudflare Stream entity (`schema.prisma:531-553`), **user-scoped** (`userId`, no org of its own).
- **Tag search works** — `listLibrary` does case-insensitive `contains` across title/description/altText and tags, plus exact `tags[]` filter (`media-library.ts:360-380`); endpoint `GET /api/organizations/:orgId/media/library` (`media.ts:1090`).

### Gaps & edge cases
- **Ownership coupling.** Attaching a video to an activity validates the video's uploader == caller (`programs.ts:2077-2084`), and the in-product picker pulls `/api/videos/me` (own uploads), not the org library. A leader can't attach a colleague's org video. Fix = relax to `canManageOrgContent` (already done for the `Video` CRUD routes, `videos.ts:685`) + repoint the picker at `…/media/library?type=video`. → **S–M**.
- **No org-owned `Video`.** Each `Video` needs a `userId`; bulk-importing 400 org videos needs a service-account/org-owned concept. → part of **M**.
- **AI tagging is images-only** (`claude.ts:110`, `media-library.ts:181`). Auto-tagging 400 videos needs frame extraction or transcript-based tagging. → **M** if you want auto-tags (manual tags are free on the existing `MediaTag`).
- **"Search by spoken words" is fully net-new.** Zero transcript data, no transcript field, and Cloudflare Stream's caption API is **not wired** (`grep transcript|caption|vtt|whisper` → 0 hits). Needs: transcription source (Stream auto-captions or Whisper) → transcript storage (new schema) → index (**pgvector already exists** from the Bible feature, `embeddings.ts`/`semantic-search.ts`, or Postgres FTS as used for lessons at `search.ts:633`) → search endpoint. → **L–XL**, and it's the whole cost of the ticket.

### Effort
**M** for the picker + manual/AI tag search on the existing org library. **L–XL** if spoken-word search is in-scope. **Recommendation:** ship picker+tags first; treat transcript search as a fast-follow that reuses the Bible embeddings stack.

---

## FR-9 — AI note summaries & lesson chapters  ·  **L**
**Tickets:** 12303272591 (AI summaries) + 12303188320 (chapters) — a linked pair

**The ask.** Chapters as structural markers in a study; reaching a chapter/study end triggers an AI "how you've changed" summary of the member's notes; members can also read their old notes; a summary auto-generates at the end of each study or chapter.

### Current state (evidence) — the AI is the **most mature** piece
- **A per-lesson AI note summary already ships in production.** `AiLessonSummary` (`schema.prisma:1342-1360`) + `getOrCreateAiLessonSummary` (`lesson-summary.service.ts:38-122`) generate a `memberSummary` ("You explored…") from the member's SOAP/journal notes via opus-4-8 (`claude.ts:285-312`), rendered in web `complete-step.vue:47-66`. It even null-suppresses non-substantive input.
- **Retrieval primitive for the cross-study version exists:** `getNotesForLLM(memberId, {enrollmentId, startDate, endDate})` (`notes.service.ts:1198`) pulls a member's notes with scripture context across an enrollment/date range. Exposed at `GET /member/notes/llm`.
- Notes model is mature: `StudyNote` + polymorphic `NoteLink` (`schema.prisma:1227-1267`), already fan-linked per activity/schedule/enrollment/group/lesson/program.
- Delivery primitive exists: in-app `Notification` feed (`schema.prisma:1636`); APNs exists but is user/leader-scoped (member delivery would be in-app).

### Gaps & edge cases
- **No chapter model.** Lessons are flat `dayNumber`s; a `LessonChapter`/`StudySection` (with `studyProgramId`, `orderNumber`, `title`, nullable `chapterId` on `Lesson`) is net-new and must be threaded through the publish snapshot, export/import, and every ordering/reorder query. → **M–L** structurally (this is the chapters ticket 12303188320 on its own).
- **No study/chapter completion moment.** `Enrollment` has `startDate`/`endDate` but **no per-member `completedAt`**; per-lesson completion exists (`MemberLessonProgress.completedAt`) but nothing fires at study or chapter end. The trigger must be built before an end-of-study/chapter summary can fire. → the gating dependency.
- **Notes-reading UI is effectively unbuilt.** `getNotesWithContext` / `GET /member/notes/with-context` exist but **no web or iPhone screen renders them** (grep → 0 consumers). "Read their old notes" is a from-scratch UI.
- **Thin-volume risk.** The code already hedges against sparse input (`memberSummary` nullable, substantive-content gate at `claude.ts:308`). "How you've changed over time" needs many notes across many lessons — per-member quantity is uneven and unverified.
- **No consent layer** for running personal spiritual reflections through an LLM (precedent exists but is silent — no `aiConsent` field). Product/privacy decision needed.

### Sub-capability sizing
| Sub-capability | Size |
|---|:--:|
| Read-old-notes UI (web) | **M** (API done, pure frontend) · **L** if iPhone-member surface required (iPhone has no member lesson/notes UI at all) |
| End-of-study summary generation | **M** (reuse summarize pattern + `getNotesForLLM`), **blocked by** the missing completion trigger |
| End-of-chapter summary (AI side) | **M**, gated entirely on the chapter model + chapter-completion event |
| Delivery / "summary ready" notification | **S–M** (in-app `Notification` feed exists) |

### Effort
**L overall** — not because of the Claude call (the mature part) but the aggregate of: build the notes-reading screen, add a study/chapter-completion trigger the model lacks, ship the chapter structure, and settle privacy/tone. **Sequence:** notes-reading UI (standalone value) → study-completion trigger + end-of-study summary → chapters + chapter summary.

---

# Recommended build order

| Wave | Items | Rationale |
|------|-------|-----------|
| **0 — hygiene** | Close **FR-6**; fix iOS `addScheduledLesson` empty-body (**S**) | Free wins; FR-6 is already shipped. |
| **1 — cheap reuse** | **FR-4** (S), **FR-5** (S–M) | Ride the existing deep-copy + template stacks; high value, low risk, no new subsystems. |
| **2 — living studies** | **FR-1** + **FR-2** together (S–M / M) | One enrollment-schedule surface; backbone exists, build the web UI + insertion policy. Defer the true one-off "special lesson" (L) if needed. |
| **3 — content library** | **FR-8** picker + tag search (M) | Rides the org `Media` library. Transcript/spoken-word search (L–XL) as an explicit fast-follow. |
| **4 — the platform bet** | **FR-7** phased: object-level authz + identity/invite (infra) → text-only contributor MVP → review queue → **web video capture** (which also closes a leader parity gap) | The XL. Sequence so each phase ships value; the permission layer is reusable infrastructure. |
| **5 — reflection loop** | **FR-3** (L), **FR-9** (L) | FR-3 needs the library concept; FR-9 needs chapters + a completion trigger + the notes-reading screen. Most product/UX definition. |

**Two cross-cutting investments that pay off more than once, do them deliberately:**
1. **Object-level permission layer** (FR-7 core) → unlocks all future collaboration/delegation features.
2. **Web video capture** (FR-7 sub-cap H) → also closes the standing leader web-recording parity gap.

---

# Open product questions (for Scott)

- **FR-7 scope unit:** does a contributor own a whole *lesson*, or a single *activity*? (Drives the entire permission-table shape.)
- **FR-7 link identity:** claim-by-first-Google-login, or must the invitee's email pre-match? (Defines "non-shareable.")
- **FR-7 reject:** hard delete, or return-to-contributor-with-notes (v2)?
- **FR-1/FR-2 insertion:** when a lesson is added/inserted mid-study, does everyone's remaining calendar shift or append? SMS-notify on change?
- **FR-5:** "study template" = the existing lesson template (study-scoped), or a new study-level template concept?
- **FR-8:** is spoken-word/transcript search in the first cut, or a fast-follow? (M vs. L–XL swing.)
- **FR-9:** consent model for running members' personal notes through an LLM; and is the notes-reading screen web-only or also iPhone-member?
