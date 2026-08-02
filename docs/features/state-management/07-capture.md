# 07 — Capture

**In scope.** `X1` **DECIDED (Luke, 2026-08-01): accepted.** The original "Not affected" claim did
not survive audit pass 1 — see [09-gaps-and-decisions.md](09-gaps-and-decisions.md) § X1.

## Why capture is affected

`MakeReadyCaptureTests/ViewRegistry.swift` instantiates the **exact pages Phases B and C modify**,
and `CaptureEnvironment.swift:18-25` builds a fresh `AppState` and seeds stores through it
(`AppState.shared = AppState()`, then `state.<store>.replaceAll([…])`):

| ViewRegistry case | Page | Touched by |
|---|---|---|
| `:227` | `MainLibrary` (Programs tab) | Phase B |
| `:254` | `MainLibrary(initialTab: 1)` (Media tab) | Phase B |
| `:191` | `GroupHomePage` | Phase C (paginated posts) |
| `:201` | group Members / Enrolled tabs | Phase C |
| `:266` | `MemberHomePage` (Members tab) | Phase C |

Once those pages read from the store instead of their own arrays, **what the capture renders stops
depending on the page's own load and starts depending on what `setupCaptureState` seeds** — sorted
by `postsFor` / `membersFor` rather than by whatever order the fork happened to hold.

## The work

**Phase B — likely inert, still verified.** Nothing seeds tags or leaders today (they were
`@State`, populated by a network call that doesn't happen in a snapshot test), so the Library filter
dropdowns render empty before and after. Confirm by re-capturing the two `MainLibrary` cases and
diffing; a non-zero diff means the load path changed in a way the spec didn't predict.

**Phase C — the real exposure.**

1. **Seed what the read-throughs now read.** `CaptureEnvironment` seeds the stores the pages will
   read from (`posts` + `groupPostIndex`, `members` + `groupMemberIndex`, `enrollments`) so the
   captured screens render populated states rather than empty ones.
2. **Seed the posts cursor** (`groupPostsNextCursor`) so `hasMorePosts` derives correctly and the
   captured group-home doesn't render a spurious "load more" affordance.
3. **Re-capture and diff** the affected comparison ids — at minimum `group-home`,
   `group-members-page`, and the two `library` cases — and treat any pixel delta as a finding to
   explain, not to accept silently.

## Compare fixtures at risk

`capture/fixtures/compare/group/group-home.json`, `.../group-members-page.json`, and the `library`
family. Sort order is the specific hazard: `postsFor` returns `createdAt` descending and
`membersFor` alphabetical, which may differ from the order the fixture's seeded array happens to be
in.

## Standing constraints

- **Twins change additively only** — new props default to the captured rendering.
- Re-capture through the **host artisan on `:8002`** with `CAPTURE_BASE_URL` set (never docker
  `:8001` — it advertises a stale `VITE_ORIGIN` and silently produces blank shots), and rebuild the
  client bundle first. Restart the capture server after editing adapters.
- Nothing here is web work: these are **iPhone** snapshot captures. The web side of `/compare` is
  untouched, consistent with [05-client.md](05-client.md).
