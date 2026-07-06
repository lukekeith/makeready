# Roadmap (Jun 28, 2026 → Feb 6, 2028)

Seven consolidated agile-level epics, sequenced by dependency and sized against measured velocity (see `velocity.md`). Dates and estimates live in `timeline.json`; this file is the rationale. **126 work-weeks total, $151,200 of Fable 5 tokens; ~77 work-weeks (~$92k) land in the first 12 months (through Jun 27, 2027).**

**Scheduling model: contiguous epics, overlapping workstreams.** Each epic runs as one continuous block with internal phases (its former sub-epics), and adjacent epics overlap the way the historical epics did (far below the historically demonstrated concurrency). Live Events additionally runs as a deliberate low-intensity background stream — releasing continuously from September 2026 rather than as an exclusive block. Sub-epic deliveries survive as milestones inside each bar.

Each epic is **one whole-application unit of work** — the timeline shows a single bar per epic, and the per-app split (API / Web Client / iPhone App / Tooling) lives inside each epic's `apps` field, surfaced in the drill-down as "Where it gets built". API work leads within each epic; the clients follow.

## The seven epics

### 1. Web Platform Parity & Offline — started Jun 28, → Sep 20, 2026 (12 wks: Web 11, API 1; in progress)
The web client reaches 100% parity with the iPhone app, then goes where the iPhone can't. Phase 1 (8 wks) is the active iPhone-to-web port: 7 of 27 tracked screens verified, 7 wired awaiting verification, 13 remaining plus the Bible reader page — each screen provable via the pixel-parity compare system built in June. Phase 2 (4 wks) ships the web client as an installable PWA with offline lesson caching and input sync for low-connectivity group settings.

### 2. Communication Platform — Aug 31, 2026 → Jan 3, 2027 (16 wks: API 8, Web 4, iPhone 4; overlaps parity tail)
Every way a group communicates, in two phases. **Notifications & SMS (6 wks):** push + web push + email + two-way SMS with per-user channel preferences, scheduled/digest notifications with templates, delivery tracking, quiet hours, org-level triggers (14.8), A2P scale-up. **Chat (10 wks):** group channels + DMs with mentions and per-conversation preferences (domain 12 — the largest unbuilt domain); its WebSocket layer is the real-time foundation Live Events extends. Nearly every later epic consumes this platform: marketplace update alerts, analytics notifications, challenge reminders, event reminders.

### 3. Live Events — Sep 14, 2026 → Jun 27, 2027 (16 wks as a continuous background stream: API 7, Web 5, iPhone 4)
The in-person gathering platform, released in parts over ~10 months rather than as one block. **Scheduling & RSVP (3 wks):** completes the partially-built events APIs — recurrence, RSVP with attendee communication, ICS export, templates, reminders (domain 3). **Attendance & event roles (3 wks):** QR self check-in + leader roster check-in with history feeding Member Analytics; leaders assign members to food, setup and activity roles with accept/decline. **Real-time session infrastructure (3 wks):** WebSocket session/participant model, presenter state sync, reconnection — extending Chat's foundation. **Live presentation mode (5 wks):** the headline — leader-run sessions where members join by QR code on their phones (no app install, so visitors participate too) and follow synchronized content and media, vote in live polls, answer questionnaires, and submit questions with results aggregating in real time; presentation content builds on the shipped lesson players and activity types. **Big-screen TV mode (2 wks):** a browser display surface for the room — join code, synchronized content, live result visualizations.

### 4. Creator Platform & Marketplace — Nov 16, 2026 → Jun 27, 2027 (29 wks over ~32 calendar wks incl. holidays: API 14, Web 10, iPhone 5)
From single-leader authorship to a creator economy, in three phases. **Collaboration (11 wks):** invite anyone — including non-members — to contribute to programs, lessons and enrolled content, with per-resource/per-action permission grants enforced across ~115 endpoints, permission editors on both clients, and a full audit trail (access control is a component, not an epic). **Marketplace (12 wks):** the "app store for study programs" — publish, discover, rate, adopt-for-my-group (reusing the export/import engine), content versioning with update notifications, creator messaging. **Billing (6 wks):** Stripe subscriptions, usage tiers, and the payout rails that monetize the marketplace.

### 5. Enterprise Trust & Compliance — May 31 → Oct 24, 2027 (20 wks: API 11, Web 5, iPhone 1, Tooling 3; overlaps the marketplace tail)
Everything an organization needs to say yes, in sequence: penetration test + remediation, secrets rotation, backup drills and SOC 2 groundwork (3 wks); OIDC SSO with domain-open access and auto-provisioning (5 wks); member data export/delete and consent surfaces — the GDPR/CCPA posture AI insights requires (2 wks); AI-assisted content moderation with org policies and report/review workflows, required before community content and chat scale (4 wks); per-org white-labeling with self-serve onboarding (4 wks); and a closing cross-feature regression + load-testing pass (2 wks).

### 6. Analytics & AI Insights — Aug 30, 2027 → Jan 9, 2028 (18 wks over ~19 calendar wks incl. holidays: API 9, Web 5, iPhone 3, Tooling 1; overlaps the trust tail)
The data and AI layer, in three phases. **Member analytics (7 wks):** event instrumentation across both lesson players — dwell time, drop-off funnels, watch-time, cohort dashboards (domain 13). **AI growth insights (8 wks):** all member input flows into an AI analysis pipeline producing growth timelines and the Trophy Room (9.10, domain 2) — opt-in, member-owned, launch-gated on the privacy tooling shipped in epic 5. **Semantic search (3 wks):** the Bible-search pgvector/reranker stack extended to programs, lessons, notes and media — one search box that understands meaning, and better marketplace discovery.

### 7. Habits & Accountability — Oct 25, 2027 → Feb 6, 2028 (15 wks: API 6, iPhone 5, Web 4; overlaps analytics tail)
The recurring-cadence challenge and goal system — the densest unbuilt domain in the original spec (domains 7–8, 20 stories) and its strongest retention mechanic: frequency engine with per-period objectives and questions, leader solicitation workflows, privacy-preserving progress sharing, and goals linked to challenge progress. Reminders ride the Communication Platform.

### Sequencing rationale
- Parity + offline first: it unblocks every later epic shipping web-first, and it's already moving at 1–2 screens/day.
- Communication Platform runs early and in parallel with the parity tail — server-heavy, independent, and nearly everything downstream consumes it (marketplace alerts, analytics notifications, challenge and event reminders). Chat lands before Trust & Compliance's moderation phase hardens it at scale.
- Live Events runs as a continuous low-intensity stream from September 2026: RSVP and attendance ship early and standalone, then the live presentation layer starts right after Chat delivers the WebSocket foundation it extends.
- Collaboration → Marketplace → Billing form one dependency chain inside epic 4 (published community content is a permission surface; billing monetizes it).
- Enterprise Trust follows the marketplace: SSO, moderation and white-labeling matter most once orgs and community content are arriving; its privacy phase deliberately lands before AI insights launches.
- Analytics before AI insights (internal to epic 6): the AI features consume the input-capture pipeline analytics builds.
- Habits last: it leans on communication reminders and benefits from the analytics substrate.
- Overlaps mirror measured history: the delivered epics overlapped heavily (4.9 epics/month at peak); the plan holds at most two full concurrent streams plus the Live Events background stream.

## Comparison against the original user stories (`docs/plans/user-stories.txt`)

Status of the 14 original domains after this roadmap completes:

| Domain | Today | After the roadmap |
|---|---|---|
| 1. Account | Largely built (phone + Google auth, profiles) | + OIDC/SSO, domain access, collaborator roles |
| 2. Accountability & Discipleship | Not started | Partially via AI growth insights |
| 3. Events | APIs built, UX partial | Completed (Live Events: scheduling, attendance, roles, live presentation + TV mode) |
| 4. Video Content | Upload/library/AI-tagging built | + Creator sharing via Marketplace, moderation |
| 5. Notes | Lesson notes built | + AI analysis of all input |
| 6. Todos | Not started | Not scheduled |
| 7. Challenges | Not started | Completed (Habits & Accountability) |
| 8. Goals | Not started | Completed (Habits & Accountability) |
| 9. Curriculum | Fully built (programs, lessons, sequencing, progress) | + Marketplace, Trophy Room AI summaries |
| 10. Personal Needs | Not started | Not scheduled |
| 11. Groups | Fully built | + Multi-user collaboration with permissions |
| 12. Chat | Not started | Completed (Communication Platform) |
| 13. Analytics | Org dashboards built | + Member behavior analytics (completes the domain) |
| 14. Admin | RBAC + management built | + SSO, permission grants, white-label, audit logs |
