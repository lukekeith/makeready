# Guest Contributor — Delivery Plan

← [README](README.md) · [Architecture](01-architecture.md) · [UX flows](02-ux-flows.md)

How to build it in shippable slices, what each depends on, how it's tested, and the decisions still open. The sequencing rule: **land the invisible foundations first (identity + permission layer), prove them with tests before any UI, then build outward.** The user's stated intent — "lay all the groundwork, then begin working on the UI" — maps directly to Phases 0–1 (groundwork) → Phase 2+ (UI).

---

## Phase map

| Phase | Deliverable | Size | Ships value on its own? |
|-------|-------------|:----:|-------------------------|
| **0** | Foundations: data model + identity/tenancy + permission resolver, **no UI** | **L** | No — enabling infra (but fully testable) |
| **1** | Contributor MVP: invite → email-locked sign-in → scoped **text** authoring → submit | **L** | Yes — a guest can write a lesson on the web |
| **2** | Review queue: leader accept/reject + quarantine gate wired to publish/sync + authorship display | **M** | Yes — closes the loop end-to-end |
| **3** | Web video recording (`<VideoCapture>`) — contributor **and** leader app | **M** | Yes — also closes a leader-parity gap |
| **4 (v2)** | Feedback-notes + resubmit loop · teleprompter · activity-scoped edits to live content | **L** | Yes — richer collaboration |

**Recommended stop-and-review points:** after Phase 0 (security design proven by the deny-matrix tests) and after Phase 2 (first real end-to-end contribution). Video (Phase 3) can run in parallel with Phase 2 since it's a self-contained client capability against an existing server API.

---

## Phase 0 — Foundations (no UI)

**Server / schema (YAML-first via `/schema`):**
- New models + enums: `ContributionInvite`, `ContributorGrant`, `Contribution`; author fields on `Lesson`/`LessonActivity` ([01 § 7](01-architecture.md#7-data-model-changes-yaml-first)).
- `resolveContributorScope(userId, target)` resolver + the deny-by-default semantics ([01 § 2](01-architecture.md#2-the-object-level-permission-subsystem-the-core)).
- Redemption-aware OAuth: `redeemContributionInvite` branch that **skips org creation** and attaches grants ([01 § 1](01-architecture.md#1-identity--tenancy)); new gate `canAccessContributorSurface` + `/auth/contributor-access`.
- Wire the **grant-check branch** onto the enumerated content endpoints; wire the **`APPROVED` filter** into `buildSnapshotLessons` + `enrollment-sync`.

**Exit criteria:** the entire [test plan](#test-plan) security matrix (S1–S9) passes with **no UI in existence** — invites created and grants exercised via API tests only.

**Why first:** these are the two fail-open surfaces (identity, per-target authz). Proving them in isolation, before any UI can paper over a hole, is the whole risk-reduction strategy.

---

## Phase 1 — Contributor MVP (text authoring)

- Leader API: `POST /programs/:id/contribution-invites` (+ list/revoke/resend).
- Contributor API: `GET /contributor/assignments[/:grantId]`, `POST …/submit`.
- **UI:** the invite form (Flow A), the contributor landing + email-lock screens (Flow B1), and the **scoped editor shell** (Flow B2) hosting the existing write/read/youtube/exegesis editors without leader nav.
- No video yet (video activities show "add later" / disabled), no review UI yet (leader can inspect via API/DB or a stub list).

**Exit criteria:** a brand-new Google user opens a link, signs in, writes a lesson end-to-end on the web, and submits — with every out-of-scope action denied.

---

## Phase 2 — Review queue

- Leader API: `GET /programs/:id/contributions`, `POST /contributions/:id/approve|reject`.
- **UI:** Contributors/review section on Program Home (Flow C), review preview via real renderers, accept/reject.
- Wire notifications (in-app `Notification` + optional APNs to the leader) on submit.
- Confirm the quarantine gate behaves on **both** the draft-publish and live-sync paths.
- Authorship display in the review UI (and member-facing per the open decision).

**Exit criteria:** full loop — invite → contribute → submit → leader accepts → lesson reaches members via publish/sync; reject keeps it invisible.

---

## Phase 3 — Web video recording

- Build the shared **`<VideoCapture>`** component (in-browser `MediaRecorder` + file-upload fallback) against the existing `POST /api/videos/upload-url` → Cloudflare → `POST /api/videos` pipeline ([01 § 6](01-architecture.md#6-web-video-recording)).
- Integrate into the contributor video activity **and** the leader app's video activity card (closes `manifest.md:131` parity gap).
- Handle the mobile-Safari `MediaRecorder` fallback, permissions, progress/resume, and processing states.

**Exit criteria:** a contributor records themselves in the browser (desktop and mobile), it uploads + transcodes + attaches, and plays back in the review preview and the member lesson player.

---

## Phase 4 — v2 enhancements
Feedback-notes-to-contributor + resubmit loop (D4 deferral); teleprompter parity for web recording; activity-scoped edits to already-published lessons via version-pinning ([01 § 5](01-architecture.md#the-one-hard-edge-v11v2-activity-scoped-edits-to-already-live-content)).

---

## Dependencies & interactions with other FRs

- **FR-1 (living study):** approval of a contribution to a **live** study rides the existing publish→sync fan-out. This spec's quarantine gate sits *upstream* of it. If FR-1's web schedule UI lands first, contributor content flows into it for free.
- **FR-8 (video library / authorship):** the `authorId` fields here are the same ones FR-8 wants for "track the lesson author." Build once.
- **Leader parity project:** Phase 3's `<VideoCapture>` closes an open parity item (`docs/parity/manifest.md:131`). Coordinate so it's built in the shared editor layer, not contributor-only.
- **Schema workflow:** every model/field change goes through `server/schema/schema.yaml` + `/schema` Atlas, never a direct Prisma edit (`server/.claude/CLAUDE.md`).

---

## Test plan

**Security matrix (Phase 0 gate — must pass before UI).** One test per threat case in [01 § Security](01-architecture.md#security-model--threat-cases):
- **S1** user-with-grant has zero `UserRole` (invariant); **S2** redeeming as a new googleId creates **no** Organization; **S3** deny matrix — sibling activity / other lesson / other study / other org all 403; **S4** direct API call with a spoofed scope 403s; **S5** email-mismatch sign-in rejected, invite stays `PENDING`; **S6** contributor cannot list org media or attach another user's video; **S7** unapproved content absent from **both** the publish snapshot and the enrollment sync (two tests); **S8** revoke mid-session → next write 403; **S9** PROGRAM_CREATE quota enforced.

**Integration:** invite lifecycle (create → claim → submit → approve/reject → complete); grant expiry; resend/revoke; quota consumption via `createdLessonIds`.

**E2E (Phase 2):** the full leader→contributor→review→member journey on web, including a returning contributor revising before approval.

**Video (Phase 3):** capture on desktop Chrome + mobile Safari (fallback path); upload resume; transcode-then-attach; playback in review + member player.

---

## Open questions & risks

**Product decisions still needed (do not block Phase 0):**
1. **Member-facing attribution (D-open):** show the guest author's name to *members*, or leader-facing only? Ticket says "display it with the lesson" → proposed default **show, togglable per invite**.
2. **Scope unit granularity in the UI:** D1 says "leader chooses"; confirm all three modes ship in v1, or start with **whole-lesson + write-N** and add single-activity in Phase 1.1 (single-activity has the most edge cases — [01 § 5 hard edge](01-architecture.md#the-one-hard-edge-v11v2-activity-scoped-edits-to-already-live-content)).
3. **Editing after submit:** v1 **locks** the contributor's editing on submit until the leader acts. Confirm that's acceptable vs. allowing continued edits.
4. **Multiple contributors, one study:** supported (many grants) — but **one lesson at a time per contributor**; simultaneous co-editing of the *same* lesson is out of scope. Confirm.
5. **Invite delivery:** copy-link only, or also server-sent email to `invite.email`? (Email adds a small sending dependency.)
6. **Contributor identity display:** use the Google display name/photo, or let them set a "how should we credit you?" name on first entry?

**Engineering risks (ranked):**
1. **Fail-open authz (highest).** Mitigated by the zero-role invariant (S1) making a contributor denied-by-default, plus a **bounded, enumerated** endpoint audit list ([01 § 2](01-architecture.md#2-the-object-level-permission-subsystem-the-core)). The discipline: never grant a contributor a `UserRole`; never add a content endpoint to the contributor flow without its grant-check + a deny test.
2. **Identity/tenancy slip.** Intercepting `passport.ts` auto-org-creation must not regress normal leader signup. Test both paths (new leader → gets org; new contributor → gets none).
3. **Quarantine leak on the live-sync path.** The gate must be enforced in `enrollment-sync`, not just at publish. Explicit S7 two-path test.
4. **Mobile Safari video capture.** `MediaRecorder` support is uneven; the file-upload fallback is **required**, not optional.
5. **Scope creep from single-activity live edits.** Keep v1 to not-yet-published targets; version-pinning is a deliberate later phase.

---

## What this unlocks beyond the ticket

The object-level permission layer (Phase 0) is reusable infrastructure. Once it exists, cheap follow-ons include: **co-leaders** scoped to specific groups, **content reviewers** who can comment but not publish, **per-lesson delegation** among a leadership team, and **org content editors** scoped to a program — none of which are expressible today. This is the strategic argument for paying the XL cost deliberately rather than hard-coding a one-off guest hack.
