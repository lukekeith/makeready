# Application State — Standardization Spec

Spec for standardizing how MakeReady's client apps hold server data. Written 2026-08-01 from the
codebase audit recorded in `docs/monday/tickets/12668501065.md` § "State-management analysis",
prompted by sub-issue **J** of that ticket ("Newly added tags dont show up on the tag filter").

**Status: built and closed by the owner (2026-08-02) — three behaviors accepted UNWALKED.**
All five phases are VERIFIED and committed (9 local commits, nothing pushed). Every gate is green
and the `/compare` re-captures are done. Luke closed the feature on 2026-08-02 with the multi-page
posts append, the cross-org sign-out walk and the media-tag repro **still never exercised by
anyone** — a deliberate acceptance, recorded in § Verify verdict, **not** a human sign-off that the
feature works. Adopted into the `/build-spec` pipeline 2026-08-01.

## Pipeline status (snapshot — updated at step completions; 2026-08-01)

**To execute this feature: `/build-spec state-management`** — no prior familiarity required.

**Progress:** ▓▓▓▓▓▓▓▓▓░ ~93% (spec ✅ · audit ✅ · decisions ✅ · plan ✅ · **build: all five
phases VERIFIED and committed**. Remaining: the verify verdict (5) + human sign-off (2), both
hinging on the same three unexercised behaviors — the multi-page posts append, the cross-org
sign-out walk, and the media-tag repro)

| Step | Status |
|---|---|
| spec | ✅ suite 01–09 (2026-08-01, adopted from the pre-pipeline docs) |
| integrity | ✅ 2026-08-01 — DEFECTS (2), both corrected; all 13 citations verified exact |
| audit | ✅ **clean (2026-08-01, after 2 passes + a closed delta round)** — pass 1: `G2` logout leak in the exemplar, `G3` paginated fork, `G4` 7 call sites not 2, `X1` capture not out of scope. **Pass 2 (delta)**: `G5`, `G6` — both inside the pagination design the decisions had just added. All resolved; see [09](09-gaps-and-decisions.md) |
| decisions | ✅ **all 4 answered (Luke, 2026-08-01)** — memory-only · fix the `textThemes` leak here · design paginated posts now · capture in scope. Consequences applied across 01/02/03/06/07/08 |
| plan | ✅ **5 phase docs written (2026-08-01)** — 10–14, 20 tasks; C split into C-a/C-b. Build go-ahead: ✅ given (Luke, 2026-08-01) |
| build | ✅ **all 5 phases VERIFIED (2026-08-01)** — per-phase table below |
| verify | ✅ **READY-by-acceptance (2026-08-02)** — gates green, zero unverified claims, `/compare` re-captures done. The 3 unexercised behaviors were **accepted unwalked by the owner**, which is the documented alternative to walking them. See § Verify verdict |
| sign-off | ⬜ **not earned** — Luke closed the feature ("done for now, mark it complete") without exercising it. That is a decision to stop, not a confirmation that it works; the distinction is deliberate and this row stays ⬜ |

## Verify verdict — INCOMPLETE (2026-08-01)

**What passed.** All five phase docs carry signed VERIFIED blocks. Both iPhone gates re-run fresh:
`npm run ios:build-check` → BUILD SUCCEEDED, `swiftlint lint --baseline` → 0 violations in 267
files. Zero `(claimed — unverified)` markers anywhere in the suite. Consumer parity is not
applicable — this feature touches one app, and [02-app-impact](02-app-impact.md)'s ⬜ rows for
server, client and capture were each re-checked during the audit.

**Why not READY.** Three behaviors have never been exercised — not by a gate, not by the owner's two
app passes. Each is marked `[~]` in its phase doc, so none of them is hiding (a fourth, the
`/compare` re-captures, was cleared 2026-08-01 and is struck through below):

| # | Unexercised | Why it matters | Where |
|---|---|---|---|
| 1 | **Multi-page posts append** — a group with >20 posts, scrolled to load more | The single riskiest change in the feature: C-b rewrote the cursor and the append path. Nothing else would reveal a pagination mistake | [13](13-phase-c2-paginated-posts.md) |
| 2 | **Cross-org sign-out walk** — sign out, sign in as a different user in a different org | This is the leak `G2`/`D2` existed to fix. Static tracing shows all four collections cleared, but nobody has watched it happen | [11](11-phase-b-homeless-domains.md) |
| 3 | **Media-tag repro** — add a tag to a media item, check the Media filter | The program-tag twin (the monday ticket) is confirmed working and the media code is its literal twin — but a twin is an argument, not evidence | [11](11-phase-b-homeless-domains.md) |
| ~~4~~ | ~~**`/compare` re-captures**~~ — **CLEARED 2026-08-01** | `group-home`/`posts` (C-b's surface) diffed **0 px** against its pre-change shot. `study-programs` moved 6042 px, **explained not accepted**: confined to the first card's title/day-count — same cards, reordered — while the filter chips Phase B changed are pixel-identical. Root cause is `G13`, a harness defect (all fixture programs share one `updatedAt`, which `orderedPrograms` sorts on, so order is unstable between runs). `group-members-page` has no iPhone side; `group-members` and `media` have no same-variant prior, so they are *current*, not *proven inert* | [07](07-capture.md) |

**Item 4 is done.** Items 1–3 still need the app. **The verdict flips to READY when they are walked,
or when a deliberate decision records why one is being accepted unwalked.**

### CLOSED BY ACCEPTANCE — 2026-08-02

**Items 1, 2 and 3 were never walked.** The app was built and launched for exactly that purpose
(iPhone 17 Pro Max, BUILD SUCCEEDED, running and signed in against the local server), and 25 posts
were seeded into *Young Professionals* to make item 1 reproducible. Before the walk happened Luke
closed the feature — *"state-management is done for now, you can mark it complete"* — so the three
are accepted unwalked. The seeded posts were removed (`DELETE 25`; the group is back to its
original 2).

**What that means, stated plainly so a later reader doesn't over-trust this page:**

- The feature is **built, gated and internally consistent**. Both iPhone gates are green, every
  phase doc carries a signed VERIFIED block, and no claim in the suite is unverified.
- The **posts pagination rewrite has never been run past page one by anyone.** It is the single
  riskiest change here — C-b moved the cursor into `AppState` and rewrote the append path — and
  static tracing plus a green build is the entirety of the evidence behind it.
- The **cross-org leak fix has never been observed working.** Tracing shows all four collections
  cleared on sign-out; nobody has watched a second account come up clean.
- The **media-tag path rests on a twin argument** — the program-tag path (the monday ticket) is
  confirmed, and the media code is its literal twin. `G14` established the capture harness *cannot*
  show this behavior, so no automated check can ever close it.

If any of these three surfaces misbehaves in the field, **start here** — this is the list of what
was shipped untested, and it is short on purpose.

### Local-data feasibility of the three walks — **checked 2026-08-01**

Queried against the local dev database (`makeready-postgres` :5434, `makeready_dev`) so the walk
script doesn't send anyone hunting for data that isn't there:

| # | Walkable locally? | Evidence |
|---|---|---|
| 1 | ❌ **not as-is — needs seeding** | The page size is **20** (`server/src/routes/posts.ts:291`, and the iPhone asks for `limit: Int = 20` at `iphone/MakeReady/State/Actions/GroupActions.swift:328`). The fullest local group has **3** posts (`Scott's personal group`, `MakeReady BETA`); every other group has ≤2. Nothing here can produce a second page — seed ~25 posts into one group, or accept the item unwalked |
| 2 | ✅ **yes, with any second Google account** | A Google sign-in for an unknown `googleId` creates the user **and its own organization** in one transaction (`server/src/routes/auth.ts:1087-1105`), so a second account Luke controls lands in a fresh org with no setup. Locally only two orgs currently hold users — `MakeReady` (5, incl. `luke@lukekeith.com`) and `Pamela Dunn` (1) |
| 3 | ✅ **yes, no setup** | Needs only a media item and the Media tab's tag filter |

*Method note worth keeping:* the first re-capture pass compared whichever two PNGs were newest on
disk, which silently paired **different variants** and produced meaningless numbers. A valid
before/after pairs the same variant, using the version→variant mapping read from the capture DB
**before** re-capturing — capturing deletes the prior version row (the PNG survives on disk as an
orphan with no recoverable variant).

## Phase status

Five phase docs, written 2026-08-01. All are **iPhone-only** (the capture work edits
`iphone/MakeReadyCaptureTests/`, which is iPhone code — capture is a *verification surface*, not a
separate phase).

**Dependencies (corrected 2026-08-01):** `A → {B, C-a, C-b} → D`. B, C-a and C-b each depend only
on **A**, not on each other — C-a and C-b read through to stores that already exist. The phase docs
originally chained all five strictly in sequence; that was a planning error, and it mattered
because it let B's blocked state block phases that had no reason to wait. **D still runs last**, for
the baseline reason in § Ordering hazard.

| Phase | App | Doc | Tasks | Status |
|---|---|---|---|---|
| A — the rule | iphone | [10-phase-a-the-rule.md](10-phase-a-the-rule.md) | 1 | ✅ **VERIFIED 2026-08-01** |
| B — Mode 1: homeless domains | iphone | [11-phase-b-homeless-domains.md](11-phase-b-homeless-domains.md) | 8 | ✅ **VERIFIED 2026-08-01** — build ✅ SwiftLint ✅ + Luke's app pass; 3 checks carried to verify |
| C-a — Mode 2: clean read-throughs | iphone | [12-phase-c1-read-throughs.md](12-phase-c1-read-throughs.md) | 5 | ✅ **VERIFIED 2026-08-01** (`bc2b16a`, `65eeaa2`) — gates green + Luke's app pass; C1.4 refuted (`G9`); **C1.5 added** for join requests (`G11`) |
| C-b — Mode 2: paginated posts | iphone | [13-phase-c2-paginated-posts.md](13-phase-c2-paginated-posts.md) | 4 | ✅ **VERIFIED 2026-08-01** (`15e82bb`) — gates green + Luke's app pass; cursor moved to `AppState`; two design defects caught pre-build (`G10`). **The multi-page append is the one check carried to verify** |
| D — enforcement | iphone | [14-phase-d-enforcement.md](14-phase-d-enforcement.md) | 4 | ✅ **VERIFIED 2026-08-01** (`b649e53`, `e4972c2`) — ran last, after C-a + C-b were signed; rule fires on exactly the 11 predicted sites, baseline regenerated deliberately |

**Why C split:** `D3` chose to design store-backed pagination rather than defer it, which made the
original Phase C too large for one session. C-a is three straight read-throughs with no pagination
in them; C-b is the only phase that touches store architecture.

## Documents

| Doc | Contents |
|---|---|
| [01-architecture.md](01-architecture.md) | Decisions table, baseline patterns by file:line, out-of-scope — plus the index into the narrative docs below |
| [02-app-impact.md](02-app-impact.md) | **Which of the four apps this touches, and why not the other three** — sequencing, backward compatibility, blast radius |
| [03-data-and-api.md](03-data-and-api.md) | Not affected (no schema, no endpoint) — plus the client-side `PersistedState` format notes |
| [04-server.md](04-server.md) · [05-client.md](05-client.md) · [07-capture.md](07-capture.md) | Not affected — each with its evidence and what the audit must re-check |
| [06-iphone.md](06-iphone.md) | The app in scope: `AppState` additions, Actions changes, page read-throughs, and what is *not* in scope |
| [08-testing.md](08-testing.md) | Gates, per-phase verification (static vs live), and the human-verification script |
| [09-gaps-and-decisions.md](09-gaps-and-decisions.md) | The G/D/O/C/X ledger + audit pass log — all decisions answered, `O1` cleared, `G7`–`G12` found during the builds + the integrity pass |
| [audit.md](audit.md) | Every local server-data collection in the iPhone app (19 sites), each classified against the rule with a disposition |
| [enforcement.md](enforcement.md) | The SwiftLint custom rule, baseline procedure, and review checklist that keep the rule true |
| [library-evaluation.md](library-evaluation.md) | Research review — should we adopt TCA / swift-sharing / SQLiteData / SwiftData instead? (Verdict: no, and the one condition that flips it) |
| [STATUS.md](STATUS.md) | Pre-pipeline status doc, retained for its **pick-up-here notes** (dirty-tree hazards). Live status is the snapshot above |

## The rule

> **Any server-derived collection that more than one screen can read, or that any screen can
> mutate, lives in `AppState`** — as an `EntityStore` when it has identity, or as a plain
> `@Observable` property when it is a reference list.
>
> **An Action's job is to mutate state, not to return data for a view to hold.** An Action that
> returns a collection is a smell: the caller now owns a copy that nothing can invalidate.
>
> **When a mutation changes data another screen derives from** — tag lists, leader lists, counts —
> **the mutating Action must refresh that derived state in the same call.**
>
> **Every collection added to `AppState` must be cleared in `clearInMemory()`.** Org-scoped data
> left behind leaks into the next user's session after sign-out.
> *(Clause added 2026-08-01 by G2/D2 — the audit found the codebase's own exemplar, `textThemes`,
> violating it. Shipped in Phase A.)*
>
> Genuinely screen-local state stays local. An in-flight edit buffer (`ProgramHomePage.editTags`)
> or pure UI state (`Dragula.draggedItems`) is correct as `@State` and must not be migrated.

## Why this is not a redesign

The architecture is already right and already documented in `iphone/.claude/CLAUDE.md`
(AppState + Actions, `EntityStore`, `RelationshipIndex`, `LoadingStateManager`). Three things
prove the pattern works today:

1. **The Actions boundary holds.** `grep -rl "APIClient.shared" iphone/MakeReady/Pages
   iphone/MakeReady/Components` returns **zero** files. No view makes its own API calls. This is
   *not* a rogue-networking problem, and nothing in this spec addresses one.
2. **A correct reference-collection exemplar exists in-repo.** `ThemeActions.loadThemes()`
   (`ThemeActions.swift:62-66`) writes `state.textThemes` and calls `state.persist()`;
   `AppState.swift:339-358` already hosts non-entity server collections as plain observable
   properties (`homeHeatmapData`, `homeWeeklyActivity`, `homeTotalMembers`, `homeTotalGroups`).
3. **The web client already does this correctly** — see "Scope" below.

What is missing is not an architecture. It is a **rule about what must live in `AppState`**, and
anything that enforces it. Today the pattern is honoured for whatever happens to have an
`EntityStore` and quietly skipped for everything else.

## The two failure modes

The audit found the problem splits cleanly in two. Both produce the same user-visible symptom —
a screen showing stale data after another screen changed it — but they need different fixes.

### Mode 1 — Homeless domain

No store exists for the data, so every consumer keeps a private copy and a mutation has **nowhere
to publish**.

`ProgramActions.swift:402-495` — `getTags`, `addTags`, `removeTags`, `syncTags`, `loadAllTags`,
`loadGroupLeaders`, `suggestTags` — contains **zero** `state.` writes. All are pass-through API
wrappers returning values for callers to cache. `AppState` normalizes 13 entity types; **tags and
group-leaders are not among them.** So the only copy of the tag list in the app is
`MainLibrary.swift:109` (`@State allTags`), and when `ProgramHomePage` edits a program's tags there
is no store to write and therefore no observer to notify.

**That is monday ticket 12668501065 sub-issue J**, unfixed as of this writing.

*Fix:* give the domain a home (mirroring `textThemes`), make its Actions write instead of return,
and add the invalidation edge on mutation.

### Mode 2 — Forked copy (the more dangerous one)

A store **does** exist. The page seeds from it, then forks into a private array that `AppState` can
no longer reach. This is more insidious than Mode 1 because the code *looks* correct — it reads
`AppState` on the way in:

- `GroupHomePage.swift:942` — `posts = result.posts`, while `AppState.posts` exists
- `GroupMembersPage.swift:48,399` — `_members = State(initialValue: cachedMembers)` then
  `members = loadedMembers`, while `AppState.members` exists
- `EnrollmentsListPage.swift:66,282,380` — same shape, while `AppState.enrollments` exists

Once forked, any update written to the store by another screen — or by a background refresh — is
invisible to the fork until the page reloads.

*Fix:* read through to the store (`state.postsFor(groupId:)` and friends) instead of copying out
of it. The cache-seeding motive is already served by AppState's own cache-first loading.

## Scope

**iPhone only.** The web client was audited and is **conformant**:

- The LeaderApp has **14 Pinia domain stores** (`client/resources/js/islands/leader-app/stores/`).
- **Zero of its 31 components make their own API calls.** The single `fetch(` hit in
  `share-invite-sheet.vue:69` is `fetch(dataUrl)` converting a data URL to a blob — not networking.

So the web is a second working exemplar, not a target. **No web changes are in scope.** If the web
later drifts, the same rule applies with "Pinia store" substituted for "AppState".

## Delivery phases

| Phase | Scope | Depends on |
|---|---|---|
| **A — The rule** | Add the rule to `iphone/.claude/CLAUDE.md` beside the existing "WRONG patterns" block. Pure docs; no code. | — |
| **B — Mode 1: homeless domains** | `allProgramTags` + `groupLeaders` (+ `allMediaTags`) into `AppState` mirroring `textThemes`; tag/leader Actions write instead of return; `add/remove/syncTags` refresh the derived list; `MainLibrary` + `OrgHomePage` read through. **Fixes ticket 12668501065 sub-issue J.** ⚠️ See "Phase B is wider than one file" below. | A |
| **C — Mode 2: forked copies** | `GroupHomePage.posts`, `GroupMembersPage.members`, `EnrollmentsListPage.enrollments`, `MemberHomePage.allMembers` read through to their existing stores instead of forking. | A |
| **D — Enforcement** | SwiftLint custom rule + baseline regeneration + review checklist ([enforcement.md](enforcement.md)). **Must come after B and C** — see the ordering hazard below. | B, C |

### Phase B is wider than one file — "mirror `textThemes`" pulls in persistence

Discovered in the 2026-08-01 sanity check. `textThemes` is **not** a single property; it is wired
through **seven** sites across two files:

| File | Line | Role |
|---|---|---|
| `AppState.swift` | `:142` | the property itself |
| `AppState.swift` | `:663` | hydrate on launch — `textThemes = persisted.textThemes` |
| `PersistedState.swift` | `:58` | the persisted field |
| `PersistedState.swift` | `:123` | default init |
| `PersistedState.swift` | `:210` | snapshot from `AppState` |
| `PersistedState.swift` | `:246` | `CodingKeys` |
| `PersistedState.swift` | `:291` | decode — `decodeIfPresent(...) ?? []` |

An implementer who adds only the `AppState` property will find it does not survive relaunch and
have to reverse-engineer the rest. **`PersistedState.swift` is in scope for Phase B.**

**Good news on compatibility:** `:291` decodes with `decodeIfPresent(…) ?? []`, so the persisted
snapshot format is **backward compatible by construction** — adding fields will not invalidate
existing on-disk state, and no cache-busting is needed on upgrade.

**Resolved by `D1` (Luke, 2026-08-01): memory-only.** Tags and leaders are cheap to refetch and
change often, so they are plain `@Observable` properties following `homeHeatmapData` — **no
`PersistedState` change at all**, and the seven-site wiring above is out of scope. (`GroupLeader` is
`Codable, Identifiable, Hashable`, so persistence was *possible*; it just wasn't *wanted*.) The
table above is retained because it documents how the `textThemes` exemplar is actually wired —
useful if a future collection does need to persist. **As built (Phase B, 2026-08-01), Phase B
touched `AppState.swift` and four call-site files; `PersistedState.swift` was never opened.**

### Ordering hazard (do not rearrange)

**Phase D must be last.** The SwiftLint baseline is regenerated wholesale
(`swiftlint lint --write-baseline`, currently 1,118 entries). If the rule lands before B and C, the
violations those phases are about to *delete* get baselined — enshrining exactly what we fixed, and
leaving stale entries behind. Regenerate against post-migration code so the baseline grandfathers
only the sites [audit.md](audit.md) deliberately defers.

## Non-goals

- **Any web/client change.** The web is conformant; see Scope.
- **Migrating every local collection.** 19 sites were audited; most are legitimately screen-local.
  [audit.md](audit.md) gives each a disposition — **migrate only the ones with a demonstrated
  sharing or mutation path.** Speculative migration is explicitly out of scope.
- **Replacing `EntityStore`, `RelationshipIndex`, or the Actions pattern.** They work.
- **The `APIClient` boundary.** Already clean on both platforms.
- **Server-side changes.** Nothing in this spec touches `server/`.
- **Fixing the other nine sub-issues of ticket 12668501065.** Only J is in scope here, and only via
  Phase B.

## Success criteria

1. Editing a program's tags on one screen updates the Library tag filter on another with **no
   screen-specific refresh call** — sub-issue J cannot recur.
2. A new screen that displays tags, leaders, posts, members, or enrollments inherits correctness by
   reading `AppState`, with no new caching code.
3. A new `@State` collection of server models inside `Pages/` fails the build, with the escape
   hatch being a deliberate, reviewed baseline entry rather than silence.
4. `iphone/.claude/CLAUDE.md` answers "where does this data live?" without the reader having to
   infer it from which types happen to have an `EntityStore`.
