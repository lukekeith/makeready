# Monday.com Work Organization

Pulled and analyzed 2026-07-05. All 22 incomplete items on **Ongoing Tasks Tracking** and all 12 items on **Feature requests** (App workspace) were read in full — descriptions, every comment, and repro notes — and each issue was traced to the responsible code in `/server`, `/client`, or `/iphone`.

| Doc | Contents |
|---|---|
| [PIPELINE.md](PIPELINE.md) | **The resolution pipeline** — /monday-review → /monday-ticket → /monday-resolve, dossier schema, affected-areas gate |
| [tickets/](tickets/) | **Per-ticket dossiers** — one file per open ticket with verbatim reports, verdict, affected areas, root cause, resolution log |
| [triage-2026-07-19.md](triage-2026-07-19.md) | **Latest status refresh** — per-ticket verdicts (fixed / outstanding / needs clarification) against main @ ec028ba, post study-sync |
| [code-fixes.md](code-fixes.md) | **Priority 1** — 19 code-only fixes (no new UI/UX needed), ordered by severity, with file:line evidence |
| [ui-ux.md](ui-ux.md) | **Priority 2** — 11 items needing interaction design before build |
| [feature-requests.md](feature-requests.md) | **Priority 3** — 12 feature tickets deduped to 9, grouped into roadmap themes |
| [tickets.md](tickets.md) | Raw inventory: every open ticket with all comments transcribed and monday URLs |

## Headline findings

1. **Two real authorization gaps (fix first).** Any org role-holder can delete another leader's study (`programs.ts` delete uses an org-scoped filter, not creator-scoped), and the enrollment endpoint does **no** ownership/org check on the study being enrolled (the code comments this as intentional). Both are small server patches — CF-1, CF-2.
2. **One architecture issue explains four bug tickets.** Enrollments deep-copy lessons at enroll time and nothing re-syncs or lifecycle-gates the snapshot: unpublish is a no-op for enrollments, "incomplete" status is a live-vs-snapshot denominator drift, added days never reach members, and soft-deleted studies keep rendering because no list endpoint filters on program active state — CF-3…CF-7. All server-side, no UI needed.
3. **The member web app's recurring "covered/hidden/stuck" complaints reduce to three contained causes:** the exegesis step never migrated to the dynamic-header CSS variable the read step already uses (CF-10); the bottom nav ignores `safe-area-inset-bottom`/`dvh` (CF-11); and the lesson player's only forward control is the header chevron, which the keyboard or fullscreen video hides (UX-2/UX-3).
4. **Ticket hygiene:** the "remove people from a group" feature request is already fully built on all three platforms (FR-6 — close it, check the reporter's role). The image-optimization question has a concrete answer: all active upload paths resize via sharp, originals capped at 1200px (CF-18 — reply and close). Two feature tickets are duplicates of two others.

## Recommended execution order

| Wave | Items | Why |
|---|---|---|
| 1 | CF-1, CF-2 | Authorization gaps — small diffs, real exposure |
| 2 | CF-3 → CF-8 | Enrollment lifecycle/data-integrity cluster; one coherent server pass + client cache invalidation |
| 3 | CF-9 → CF-13 | Join-flow org bug + member web CSS/copy batch — clears most member-visible complaints |
| 4 | CF-14 → CF-19 | iPhone editor fixes; four need on-device repro first |
| 5 | UX-1, UX-2, UX-3 | Highest-impact UX items; small designs (leader preview routing, sticky Done/Continue) |
| 6 | Remaining UX + features | Per [ui-ux.md](ui-ux.md) ordering and the roadmap grouping in [feature-requests.md](feature-requests.md) |

## Open questions for Scott/product

- **CF-6:** should unpublishing an enrolled study be *blocked* or *kick groups out*? (He stated kick-out; blocking is safer.)
- **UX-1:** is "Open Lesson" meant as leader preview, member share-link, or both?
- ~~**CF-13:** which screen was the "should say lessons" screenshot — member group home or leader dashboard?~~ RESOLVED: it was neither — the Program Home tab slider (iPhone + web twin). Renamed to "Lessons" in `fdb1b31`.
- **UX-4:** the highlight-overlap data loss is already guarded on web; needs a repro to confirm whether the iPhone path can still destroy a note.

## Ticket → work-item map

| Monday item | Work items |
|---|---|
| 12325580210 UX change needed | CF-1, UX-6 |
| 12344861586 UX update please | CF-2, UX-1, UX-2, UX-4, UX-8 |
| 12268464531 publishing toggle error | CF-3, CF-6, UX-9 |
| 12415690223 member - error | CF-4 |
| 12268576962 calendar breaks when unpublishing | CF-5 |
| 12344966891 UI not updating | CF-4, CF-7 |
| 12297338039 error log | CF-8, CF-14, CF-15, CF-16, CF-17, UX-6 |
| 12268645785 validation error (→ SMS verification fails to send) | CF-9 (disproved), UX-1; deep-dived + split → 12572733385; diagnostic fix applied, Twilio ops diagnosis pending |
| 12572733385 iPhone exegesis "Couldn't save changes" | Split from 12268645785; root-caused (overlap semantics) + fixed `e8e9718` (merge into existing); resolved-pending-verify |
| 12415662995 member - reading issue | CF-10 — ⏳ RESOLVED-PENDING-VERIFY (fbcd848) — exegesis top inset + mask → dynamic `var(--member-lesson-header)`; monday → Verify |
| 12386101354 error member experience | CF-10, CF-19 |
| 12297336134 stuck | CF-11, CF-19, UX-2, UX-5 |
| 12344966853 UI update please | CF-11, UX-11 |
| 12268578241 covering text | CF-12 |
| ~~12268465402 should say lessons~~ | CF-13 ✅ CLOSED (fdb1b31) — Program Home tab renamed to "Lessons" |
| ~~12271625826 image optimize~~ | CF-18 ✅ CLOSED (Done) 2026-07-19 — answered (optimized, not ideal); follow-up Feature **12572712291** opened for WebP/AVIF + right-sized delivery |
| 12572712291 Image optimization (WebP/AVIF + right-sized delivery) | NEW Feature — Media · Multiple; provisional pending Option A (static variants) vs. B (transform layer) decision |
| ~~12415667946 member - video~~ | UX-3 — ✅ CLOSED/Done (03e1367 + 1e3f035) — header safe-area inset + warning empty-video state; user-verified in-browser |
| 12268478769 add bible verse unclear | UX-7 |
| 12297345805 suggestion | UX-7 |
| 12268648378 no way to change enrollment calendar | UX-10 |
| 12270302158 rescheduling | UX-10 |
| 12081607589 confused with notes in group | UX-11 |
| 12101572041 inspirational notes | FR-3-adjacent (note-first lesson creation; needs product definition) |
| Feature requests board (12) | FR-1 … FR-9 (see [feature-requests.md](feature-requests.md)) |
