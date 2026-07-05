# Development Velocity Analysis

Measured from the complete commit histories of all five MakeReady repositories.

## Sources

| Repository | Commits | Span | What it is |
|---|---|---|---|
| makeready-iphone | 277 | Oct 31 2025 → May 15 2026 | Native iOS app (Swift/SwiftUI) |
| makeready-server | 366 | Oct 31 2025 → May 20 2026 | Express + Prisma + PostgreSQL API |
| makeready-web | 658 | Oct 31 2025 → May 20 2026 | Laravel + Vue web client |
| makeready-capture | 8 | May 3 → May 18 2026 | Visual regression tool |
| makeready (monorepo) | 241 | May 20 → Jun 28 2026 | All four apps, consolidated |
| **Total** | **~1,550** | **8.2 months** | |

Note: the monorepo's first commit is a consolidation import of the four prior repos (380k lines), so history before May 20 2026 lives in the original repositories. Work after Jun 28 (the iPhone→web parity port) is in progress on a feature branch.

## Monthly commit cadence (all repos combined)

| Month | Commits | What happened |
|---|---|---|
| Nov 2025 | 137 | Server + iPhone foundations |
| Dec 2025 | 89 | Bible, enrollment, media pipeline |
| Jan 2026 | 242 | Web client push, notifications |
| Feb 2026 | 153 | Lesson activity editors (both platforms) |
| Mar 2026 | 346 | Laravel replatform + admin panel (244 commits in 10 days) |
| Apr 2026 | 197 | Editors, enrollment, compliance |
| May 2026 | ~140 | Marketing site, monorepo consolidation |
| Jun 2026 | 216 | iOS audit, semantic Bible search, parity tooling |

**Average: ~190 commits/month**, sustained for 8+ months by a single developer working with Claude Code.

## Epic-level velocity

Clustering the 1,550 commits by deliverable yields **40 completed epics** — about **4.9 epics/month**, averaging 39 commits per epic. Three reference points investors can verify in the history:

- **Laravel replatform**: entire web client rebuilt on a new framework with a 52-component library in **4 days** (108 commits)
- **Admin console**: full CRUD + analytics dashboard in **7 days** (136 commits)
- **Parity tooling**: 80+ pixel-parity web components in **4 days** (84 commits)

## Parity-specific cadence (July 2026)

The active iPhone→web parity program independently confirms the rate: **1–2 screens verified per day** (7 screens verified Jul 2–4, 7 more wired Jul 4–5), each screen including pixel-diff proof against the iPhone original.

## How this feeds the forecast

The 12-month plan (see `roadmap.md`) budgets **~1.5 feature-epic-equivalents per month** — roughly one third of the demonstrated epic rate. The discount absorbs:

1. Live verification and production-hardening time that pure build velocity understates
2. New-domain complexity (marketplace, SSO, analytics pipeline) vs. now-familiar domains
3. Schedule buffer (an explicit 2-week hardening block ends the plan)

The result is a forecast that is aggressive by industry standards but conservative against MakeReady's own measured history.
