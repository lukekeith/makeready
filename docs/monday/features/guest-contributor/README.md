# Guest Contributor — Feature Spec

**Status:** Draft for review · **Created:** 2026-07-25 · **Owner:** Luke
**Source ticket:** [12266593869 "Solicitation of lesson in study"](https://scotts-team283817.monday.com/boards/18417603408) (Feature requests board) · **Analysis:** [../../feature-feasibility-2026-07-25.md](../../feature-feasibility-2026-07-25.md) (FR-7)

> This is a **design spec written to be reviewed before any code is written.** It lays out the full architecture, data model, security model, API surface, UX flows, and a phased delivery plan. Nothing here is built yet.

---

## The idea in one paragraph

A group leader can invite an outside person — a friend, a guest teacher — to contribute content to a study **without downloading the iPhone app**. The invitee opens a private link, signs in with Google **on the web**, and lands in a **stripped-down editor that shows only what they were assigned** — a specific lesson, a specific activity, or a request to write *N* new lessons on a given topic. They can write text, add scripture, and **record a video of themselves in the browser**. When they submit, their work lands in the study **marked "for review,"** invisible to enrolled members until the leader accepts it. Their authorship is tracked and displayed with the lesson.

---

## Why this is the hard one (and why it's worth it)

FR-7 is the only **XL** on the board, and the reason is structural, not cosmetic:

> **MakeReady's authorization has no object-level scoping.** Today a user is authorized by an **org-wide role** plus **`creatorId` ownership**, and the dominant helper `canManageOrgContent()` (`server/src/services/permission.ts:269-298`) grants **any** role-holder in an org **full CRUD over all org content**. There is no way to say "this person may edit *only this lesson* and nothing else."

So the sentence in the ticket — *"an invited person cannot view, edit, create, delete anything outside the proper scope of their invitation"* — **cannot be expressed in the current model at all.** This spec introduces that missing capability: a **deny-by-default, object-scoped grant layer**. Once it exists, a whole class of future collaboration features (co-leaders, per-lesson delegation, org content editors, reviewer roles) becomes cheap. **Treat FR-7 as platform infrastructure with a first feature riding on it.**

A pleasant consequence of the current model: a user with **no role** is *already* denied by every content guard. So the permission work is mostly **selectively opening narrow, grant-checked holes** for a role-less contributor — not clamping down an over-permissive system. That materially lowers the audit risk (details in [01-architecture.md § Security](01-architecture.md#security-model--threat-cases)).

---

## Locked product decisions (2026-07-25)

These four forks were decided before writing; the whole spec is built on them.

| # | Decision | Choice | Consequence |
|---|----------|--------|-------------|
| D1 | **Scope unit** — what a contributor is assigned | **Leader chooses per invite:** a whole lesson · a single activity · or "create *N* new lessons" | The grant model is **polymorphic** over three target modes (`LESSON`, `ACTIVITY`, `PROGRAM_CREATE`). |
| D2 | **Link identity** — "only available to them, can't share it" | **Email-locked magic link** | The link only works when signed in with the exact Google email the leader entered. A forwarded link is useless to anyone else. |
| D3 | **Account type** — what the invitee becomes | **Scoped User in the leader's org** | A real Google-backed `User` attached to the **leader's** org via grants only — **no `UserRole`, not a group member, not org-wide.** Must intercept the auto-org-creation on Google signup. |
| D4 | **Review** — how contributions reach members | **Quarantined draft + accept/reject** | Contributed content carries a review state; the **publish snapshot + enrollment sync exclude anything not `APPROVED`.** v1 = accept/reject; **feedback-notes-to-contributor is v2** (per the ticket). |

Video recording on the web is **confirmed in scope** (leader requirement) and specced as a shared capability that also closes a standing leader-parity gap.

---

## Documents in this spec

| Doc | Contents |
|-----|----------|
| **README.md** (this file) | Idea, rationale, decisions, glossary, scope |
| [01-architecture.md](01-architecture.md) | Identity & tenancy · the object-level permission subsystem · data model (YAML-first) · invite/assignment · authorship · review & quarantine · web video recording · full API surface · **security threat cases** |
| [02-ux-flows.md](02-ux-flows.md) | Leader invite flow · contributor onboarding + scoped editor shell · in-browser video recording UX · leader review queue · member-facing attribution · empty/error states |
| [03-delivery-plan.md](03-delivery-plan.md) | Phased build (foundations → contributor MVP → review queue → video → v2) · dependencies · test plan · open questions & risks |
| [04-ui-ux-spec.md](04-ui-ux-spec.md) | **Build-ready UI spec** — every screen mapped to concrete design-system components (with paths) · the scoped contributor-shell architecture · in-browser video-capture UI · states |
| [05-design-system.md](05-design-system.md) | **Design-system delta** — REUSE / WIRE / BUILD / MODIFY ledger across ~25 surfaces · specs for the 2 net-new components · conventions any new component must follow · no new tokens |

---

## Scope

### In scope (v1)
- Email-locked invite to a specific study, carrying scope (lesson / activity / N-new-lessons), a **requested lesson count**, and **topic direction** text.
- Google web sign-in that attaches the invitee to the **leader's** org as a scoped contributor (no role, no org creation).
- A **contributor-only web surface** showing only assigned content + the leader's instructions.
- Text-based authoring reusing the existing web editors (write / read / youtube / exegesis) — same server APIs the iPhone uses.
- **In-browser video recording** + upload, driving the existing Cloudflare Stream pipeline.
- **Authorship tracking + display** ("Guest author: Name").
- **Quarantine + accept/reject** review, gating publish and enrollment sync.
- Invite **revocation** and grant expiry.

### Out of scope (v2+)
- Feedback-notes-to-contributor + resubmit loop (D4 defers this).
- Teleprompter parity for web recording.
- Activity-scoped edits to **already-published/live** lessons (v1 focuses contributions on not-yet-published lessons; live-edit version-pinning is a v1.1/v2 refinement — see [01 § Review](01-architecture.md#review--quarantine)).
- Contributors editing on iPhone (web-only by design).
- Multiple contributors collaborating on the *same* lesson simultaneously.

### Non-goals
- Turning contributors into org members or giving them any org-wide visibility.
- Any change to how *members* consume lessons.

---

## Glossary

- **Leader** — an existing org role-holder (Owner/Admin/Group Leader) who owns/manages a study and issues invites.
- **Contributor** — the invited outside person; a real `User` in the leader's org, authorized **only** by explicit grants.
- **Grant** (`ContributorGrant`) — a single object-scoped permission: "this user may author *this* target." Polymorphic over lesson / activity / program-create-quota.
- **Contribution invite** (`ContributionInvite`) — the email-locked token that, when redeemed, provisions the contributor User + grant(s).
- **Contribution** (`Contribution`) — a unit of submitted work tracked through DRAFT → SUBMITTED → APPROVED/REJECTED; the review gate reads this.
- **Quarantine** — the state in which contributed content exists in the study but is excluded from publish snapshots and enrollment sync until `APPROVED`.
- **Scoped editor shell** — the contributor-only web surface: the existing overlay editors hosted without the leader nav, whole-study loaders, or library access.
