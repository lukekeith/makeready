# Requirements: MakeReady v2.1 — Member Management & Activity History

**Defined:** 2026-03-21
**Core Value:** Group leaders can see, manage, and understand every member across their entire organization from a single unified interface

## v2.1 Requirements

### Member List & Navigation

- [x] **MLIST-01**: Leader can see all members across all groups in a single virtualized list at /admin/members
- [x] **MLIST-02**: Leader can search members by name via a search input that adds filter tags (not live filtering)
- [x] **MLIST-03**: Leader can filter the member list by group via tag chips
- [x] **MLIST-04**: Leader can filter the member list by lesson completion status via tag chips
- [x] **MLIST-05**: Leader can filter the member list by activity type via tag chips
- [x] **MLIST-06**: Leader can remove individual filter tags or clear all filters at once
- [x] **MLIST-07**: Member list displays name, avatar, groups, and last active date per row
- [x] **MLIST-08**: Members navigation item appears in the admin sidebar
- [x] **MLIST-09**: Member list supports infinite scroll for 500+ members without performance degradation

### Member Profile & Groups

- [x] **MPROF-01**: Leader can view a member's profile showing name, phone, email, avatar, groups, and joined date
- [x] **MPROF-02**: Leader can add a member to one or more additional groups from the profile view
- [x] **MPROF-03**: Leader can remove a member from a specific group from the profile view
- [x] **MPROF-04**: Leader can see enrollment progress summary (% complete, completed/total lessons) per enrollment on the profile
- [x] **MPROF-05**: Leader cannot edit member profile information (name, email, phone) — read-only

### Activity History & Replay

- [ ] **MACT-01**: Leader can see a list of all lessons a member has participated in with completion status badges (completed, in-progress, upcoming)
- [ ] **MACT-02**: Leader can navigate to any lesson and see the full activity replay — written SOAP entries, USER_INPUT responses, scripture readings, and video watch progress
- [ ] **MACT-03**: Leader can search a member's activity history by lesson title, enrollment name, or completion status
- [ ] **MACT-04**: Leader can see a per-enrollment day-by-day timeline showing when each lesson was completed
- [ ] **MACT-05**: Leader can see an activity log timeline showing auth, join, and access events for a member
- [ ] **MACT-06**: All member activity content is read-only — leader cannot edit member responses or notes

## Future Requirements

### Enhanced Analytics

- **MANA-01**: Leader can see completion heatmap per member (calendar-style view)
- **MANA-02**: Leader can compare member engagement across groups

### Bulk Operations

- **MBULK-01**: Leader can select multiple members and assign to a group in bulk
- **MBULK-02**: Leader can export aggregate completion stats (not raw journal content) to CSV

## Out of Scope

| Feature | Reason |
|---------|--------|
| Editing member responses/notes | Member-owned content; trust violation; no API support |
| Real-time member presence | Project constraint: no WebSocket/real-time features |
| Live search (type-to-query API) | Client-side filtering sufficient for 500+ scale; matches iPhone pattern |
| Messaging from admin panel | Separate product surface; SMS compliance concerns; leaders have phone numbers |
| Member cohort analytics | Enterprise LMS feature; months of work for marginal gain at current scale |
| CSV export of raw journal content | Data privacy: exports sensitive pastoral entries |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| MLIST-01 | Phase 11 | Complete |
| MLIST-02 | Phase 12 | Complete |
| MLIST-03 | Phase 12 | Complete |
| MLIST-04 | Phase 12 | Complete |
| MLIST-05 | Phase 12 | Complete |
| MLIST-06 | Phase 12 | Complete |
| MLIST-07 | Phase 12 | Complete |
| MLIST-08 | Phase 10 | Complete |
| MLIST-09 | Phase 12 | Complete |
| MPROF-01 | Phase 13 | Complete |
| MPROF-02 | Phase 13 | Complete |
| MPROF-03 | Phase 13 | Complete |
| MPROF-04 | Phase 13 | Complete |
| MPROF-05 | Phase 13 | Complete |
| MACT-01 | Phase 14 | Pending |
| MACT-02 | Phase 14 | Pending |
| MACT-03 | Phase 14 | Pending |
| MACT-04 | Phase 14 | Pending |
| MACT-05 | Phase 14 | Pending |
| MACT-06 | Phase 14 | Pending |

**Coverage:**
- v2.1 requirements: 20 total
- Mapped to phases: 20
- Unmapped: 0

---
*Requirements defined: 2026-03-21*
*Last updated: 2026-03-21 after roadmap creation*
