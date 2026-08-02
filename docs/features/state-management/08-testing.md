# 08 — Testing

Consolidated from `STATUS.md` § Verification per phase and [enforcement.md](enforcement.md)
§ Procedure at pipeline adoption (2026-08-01).

## The constraint that shapes this plan

**No build, `xcodebuild`, or simulator command runs without asking first** — absolute rule in
`iphone/.claude/CLAUDE.md`. So verification is split in two, and the split must be stated honestly
in every phase sign-off:

- **Static** — SwiftLint + code review + grep. Runnable any time, by an agent.
- **Live** — the repro walks below. Each one requires a simulator build; **ask before running one**,
  and if the answer is no, the phase records the walk as *not yet verified* rather than claiming it.

## Gates

| Gate | When |
|---|---|
| `cd iphone && swiftlint` clean against the current baseline (**must run from `iphone/`** — the config's `included:` paths are relative; `.swiftlint-baseline.json` holds 1,118 grandfathered entries) | every phase |
| `npm run ios:build-check` (compile check) | every code phase — **ask first** |
| Deliberate-failure check ([enforcement.md](enforcement.md) § Procedure step 6) | Phase D only |

No server, client, or capture gates apply — those apps are out of scope
([02-app-impact.md](02-app-impact.md)).

## Per-phase verification

**Phase A — the rule** · docs only; no verification beyond review. The success test is criterion 4:
`iphone/.claude/CLAUDE.md` answers "where does this data live?" without the reader inferring it
from which types happen to have an `EntityStore`.

**Phase B — Mode 1** · SwiftLint clean against baseline, then:

1. **The sub-issue J repro** — edit a program's tags → return to Library → Programs → open
   `All tags` → confirm the new tag is listed **without** toggling a filter.
2. **The sign-out walk (new — G2/D2).** Sign out, sign in as a **different user in a different
   org**, open the Library filters. The tag and leader dropdowns must be **empty or repopulated for
   the new org** — never showing the previous user's values. Repeat for the themes list, which this
   phase also fixes.
3. **`OrgHomePage` leaders** still render (it was a second homeless copy — G4).
4. Re-capture the two `MainLibrary` ViewRegistry cases and diff; expected inert, and a non-zero
   diff is a finding ([07-capture.md](07-capture.md)).

**Phase C — Mode 2** · SwiftLint clean, then, in two parts:

*The three clean read-throughs* (`GroupMembersPage`, `EnrollmentsListPage`, `MemberHomePage`) —
change a member or enrollment on one screen and confirm the other reflects it **without a manual
reload**; confirm order, inclusion, and counts match the previous forked rendering.

*Paginated posts* (D3 — the enlarged part):

- open a group with **more than one page** of posts, scroll to trigger load-more, and confirm each
  page **appends** rather than replacing (this is the `addMany` vs `replace` hazard —
  `RelationshipIndex.swift:69` vs `AppState.swift:676`);
- confirm `hasMorePosts` goes false **exactly** at the end, with no spurious trailing affordance;
- leave and re-enter the group and confirm posts are not duplicated or lost;
- confirm ordering is `createdAt` descending, matching `postsFor`;
- **relaunch, open the group, then load more** — the first load-more refetches page 1 because no
  cursor is restored (G6). Confirm **no duplicate posts appear** (appends upsert). This is expected
  behavior, not a bug: do not "fix" the redundant fetch.

*Capture* — seed the stores and the posts cursor in `CaptureEnvironment`, re-capture, and diff
`group-home`, `group-members-page`, and the `library` family. **Any pixel delta must be explained,
not accepted.**

**Phase D — enforcement** · the deliberate-failure check: introduce a violating
`@State private var xs: [SomeModel] = []` in `Pages/`, confirm the build fails, remove it. Then
confirm the regenerated baseline grandfathers **only** the sites [audit.md](audit.md) deliberately
defers — a baseline that swallowed a site B or C was supposed to fix means the phase order was
violated.

## Cross-app E2E

**None** — single-app feature. The sub-issue J repro above is the closest thing to an end-to-end
walk and belongs to Phase B.

## Human-verification script (for the sign-off gate)

What to hand the user at the end, in this order (newest and least-exercised first):

1. **The J repro** — the bug that motivated the whole spec. Edit a program's tags, go to
   Library → Programs → `All tags`. The new tag should be there immediately.
2. **Relaunch** — reopen the app and confirm tags/leaders behave as `D1` decided (present at launch
   if persisted; refetched cleanly if memory-only).
3. **Cross-screen freshness** — change a post, member, or enrollment on one screen; confirm the
   other screen shows it without a reload.
4. **Regression sweep** — Library filters, Org home leaders list, group home posts, members list,
   enrollments list all still render normally.

Local facts worth stating when handing it over: this is simulator-only work, the app must be built
first (which needs their go-ahead), and no server or web restart is involved because neither app is
in scope.
