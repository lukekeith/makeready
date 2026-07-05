# 12-Month Roadmap (Jul 2026 → Jun 2027)

Seven committed features, sequenced by dependency, sized against measured velocity (see `velocity.md`). Dates and estimates live in `timeline.json`; this file is the rationale.

Every feature is decomposed in `timeline.json` into **per-app epics** (API / Web Client / iPhone App / Tooling & Infrastructure) — each with its own dates, weeks and token budget, grouped by a shared `feature` field — so the timeline shows what needs to be built and where it goes. API work leads each feature; the clients follow. The committed 12 months total 53 work-weeks: Web 21, API 20, iPhone 9, Tooling 3.

## Committed features

### 1. Web Client: 100% iPhone Parity — Jul 6 → Aug 28 (8 wks)
Finish the parity program already in flight. 7 of 27 tracked screens are verified, 7 are wired awaiting verification, 13 remain (member profile, requests, enrollment flow/scheduling, calendar, global search, notification feed, org home, invite contacts), plus the Bible reader page. The pixel-parity compare system built in June makes each screen provable, not aspirational.

### 2. Content Collaborator Invitations — Aug 24 → Sep 25 (5 wks)
Leaders invite anyone — including non-members — to create and edit study programs, lessons, enrolled-lesson content and related material. Builds on the existing invitation infrastructure (email/SMS invites, QR codes, status tracking) and the June org-authorization work.

### 3. ACL Permissions for Invited Users — Sep 28 → Nov 6 (6 wks)
Fine-grained grants so a leader specifies exactly what each invited person can and cannot do: per-resource, per-action (full CRUD) on programs, lessons, enrolled lessons and content. This extends the org-role authorization layer across ~115 content endpoints and adds a permission editor UI plus an audit log. Deliberately sequenced right after invitations while that code is fresh.

### 4. Group Leader Community / Content Marketplace — Nov 9 → Feb 12 (12 wks + holidays)
The "app store for study programs": leaders publish curriculum for other leaders to discover, adopt for enrollment, rate, discuss and message the author about — with content versioning and update notifications to adopters. The largest single feature in the plan; depends on ACL (published content is a permission surface) and reuses the existing program export/import engine for cloning.

### 5. Org SSO & Domain-Controlled Access — Jan 25 → Feb 26 (5 wks, overlaps community tail)
Organizations toggle between invite-only and domain-open: anyone with an email at the org's domain (Google, Microsoft, generic OIDC) gets access automatically. Google OAuth already exists for leaders; this generalizes it to OIDC, adds domain verification, auto-provisioning with default roles, and deprovisioning.

### 6. Member Analytics & Behavior Tracking — Mar 1 → Apr 16 (7 wks)
Event instrumentation across web and iPhone lesson players: per-activity dwell time, drop-off funnels, video watch-time and abandonment, cohort progress. Answers "where do members get stuck, where do they fly" — the data substrate for improving the experience and for feature 7. Directly fulfills user-story domain 13 (Analytics).

### 7. AI Growth Insights & Summarization — Apr 19 → Jun 11 (8 wks)
All user input anywhere in the app (SOAP entries, notes, answers, reflections) flows into an AI analysis pipeline producing personal growth timelines, "lessons learned" summaries and the Trophy Room view from the original user stories (9.10: "view an AI summary of lessons learned"; domain 2: understand spiritual health "the way Apple Health communicates physical health"). Ships with explicit privacy controls: opt-in, member-owned data.

**+ Hardening buffer — Jun 14 → Jun 30**: regression, performance, security review.

### Sequencing rationale
- Parity first: it unblocks every later feature shipping web-first, and it's already moving at 1–2 screens/day.
- Invitations → ACL → Community form one dependency chain (each is the foundation of the next).
- SSO is independent, slotted to overlap the community tail (different subsystem, low collision).
- Analytics before AI insights: the AI features consume the input-capture pipeline analytics builds.
- Modest overlaps mirror how work has actually shipped for 8 months (server/web/iPhone epics have always run concurrently with Claude Code parallelism).

## Comparison against the original user stories (`docs/plans/user-stories.txt`)

Status of the 14 original domains after this plan completes:

| Domain | Today | After 12 months |
|---|---|---|
| 1. Account | Largely built (phone + Google auth, profiles) | + OIDC/SSO, domain access, collaborator roles |
| 2. Accountability & Discipleship | Not started | Partially via AI growth insights |
| 3. Events | APIs built, UX partial | Unchanged (proposed follow-on) |
| 4. Video Content | Upload/library/AI-tagging built | + Creator-to-creator sharing via Community |
| 5. Notes | Lesson notes built | + AI analysis of all input |
| 6. Todos | Not started | Not scheduled |
| 7. Challenges | Not started | Proposed follow-on |
| 8. Goals | Not started | Proposed follow-on |
| 9. Curriculum | Fully built (programs, lessons, sequencing, progress) | + Marketplace, Trophy Room AI summaries |
| 10. Personal Needs | Not started | Not scheduled |
| 11. Groups | Fully built | + Collaborators with ACL |
| 12. Chat | Not started | Proposed follow-on |
| 13. Analytics | Org dashboards built | + Member behavior analytics (completes the domain) |
| 14. Admin | RBAC + management built | + SSO, ACL, audit logs |

## Recommended additions (proposed, post-Jun 2027 or as capacity allows)

These come straight from unserved user-story domains and from what the committed features will need at scale:

1. **Events & Calendar completion** (4 wks) — RSVP, ICS, event channels. APIs partially exist; high value per week.
2. **Org Billing & Payments** (6 wks) — Stripe subscriptions. Prerequisite to monetizing the marketplace.
3. **Challenges** (10 wks) + **Goals & Accountability** (5 wks) — the strongest retention mechanic in the original vision, and its densest unbuilt spec (domains 7–8: recurring frequency engine, per-period questions, solicitation workflows, privacy-preserving progress sharing, scheduled push reminders, curriculum integration — across both platforms). Goals build on the challenge engine, so they follow it.
4. **Moderation & Safety** (4 wks) — AI content screening and org policies; required before community content and chat scale (stories 4.6–4.7, 12.15).
5. **Group Communication / Chat** (10 wks) — the largest unbuilt domain (12); recommended after moderation exists.
