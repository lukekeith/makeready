# Phase 7 — Cross-app E2E  ·  app: cross-app

> Part of docs/features/highlighting/. Preconditions: **Phases 1–6 all VERIFIED.** The only phase
> that spans apps, and the last before the verify verdict.

## Goal

A highlight made by a leader on the iPhone reaches a member in the web player, with its note, in
the right colour, on the right block — and a build already in testers' hands keeps working
throughout. Walked live, not asserted.

## Companion skills

`/dev-start` for the local stack.

## Tasks — the walk (08 §Cross-app E2E walk)

- [x] 7.1 iPhone, Read activity → highlight a verse → renders lime
- [x] 7.2 The same activity in the web **LeaderApp** pane → same span, same colour
- [x] 7.3 Enrol a member → open the lesson in the **member player** → same span, same colour
- [x] 7.4 iPhone, Exegesis → highlight a phrase, add a note → the member player shows the note
- [x] 7.5 **Highlight across two existing noted highlights → both notes survive**, end to end.
      This is Phase 1's guard proven at the system level, not just in a unit test
      — **BOTH HALVES DONE:** server + projection measured below; the device→player half walked by
      Luke 2026-08-05

> **7.5 server half — PASSED 2026-08-05, over real HTTP against the local stack.** Deliberately run
> on a **READ** activity (`20616980…`, block `8098cf6e…`), not an Exegesis one: READ is the path this
> feature newly allowed and newly migrated, so it is the one carrying risk. The protected fingerprint
> block (`f93cc7f1…`, 4 noted highlights) was left untouched.
>
> Created two noted highlights (10–30 "Note A"; 60–80 "Note B"), then posted one spanning both
> (5–90, empty note). Result, field for field against 03 §2.2:
>
> | Contract clause | Observed |
> |---|---|
> | union span | `5–90` ✅ |
> | absorbed rows returned | `absorbedIds` = both ids ✅ |
> | notes concatenated `\n\n` in document order | `"Note A\n\nNote B"` — **exact string match** ✅ |
> | merged row keeps earliest absorbed `orderNumber` | `1` ✅ |
> | style | `highlight` ✅ |
>
> **Both notes survived a merge that changed the span — monday#12708759849 sub-issue A, proven at
> the system level through the real route**, not a unit seam.
>
> **The projection followed**, which is the half that matters for the member player and for builds
> already in the field: the block's `selections` regenerated to exactly
> `[{"start":5,"end":90,"style":"highlight"}]`.
>
> **Data restored and proven restored** — merged row deleted, then the whole-table fingerprint
> re-measured: **103 rows / md5 `168b81928fdc1f22775cc7a56696b822`, byte-identical to the
> before-state**, and the block's `selections` back to `NULL`.
>
> **The gesture half was walked by Luke on 2026-08-05** — see the human-walk record below the task
> list. Both halves of 7.5 are therefore done.
- [x] 7.6 Kill and relaunch the iPhone app → highlights survive the disk-cache round trip
- [x] 7.7 **Point a build-374 simulator build at the same server** → its Read highlights still
      render, from the retained `selections` projection. This is the backward-compatibility proof
      and the one step that cannot be inferred · spec: 02 §Backward compatibility, 09 §X-a
      — **CLOSED AS ACCEPTED-WITH-SUBSTITUTE (Luke, 2026-08-05), NOT as executed.** The artefact
      provably cannot exist (09 §G-ad); both mechanisms it existed to test were verified at the
      contract level instead. **Ticked so the phase can close, but read the box as "risk accepted",
      not "old binary observed working" — the distinction is the whole point of this row.**

> **7.7 2026-08-05 — the artefact does not exist, and both things it was meant to prove now hold
> anyway.**
>
> **Why it cannot be run.** *(Corrected 2026-08-05 — see 09 §G-ad. The first version of this note
> said no build-374 binary existed; that was wrong. One does:*
> `~/Library/Developer/Xcode/Archives/2026-08-03/MakeReady 8-3-26, 12.52 AM.xcarchive`, *1.1.3 /
> 374. I had checked the repo and not the archive directory.)*
>
> The repo genuinely cannot produce one — no git tags at all, and `CFBundleVersion` was committed
> exactly once (`fc69ddb`), so no revision *is* build 374 (`HEAD` says 373, the working tree 397).
> But the archive that does exist cannot serve either, for the reason that always mattered more:
> it is a **Release, device** build, so `DEV_MODE` is off and the base URL is hardcoded to
> `https://api.makeready.org` — it cannot be aimed at the local server, and it is not a simulator
> build. Running it against **production** would prove nothing, because the migration has only been
> applied **locally** (phase 3 left production untouched).
>
> **Both backward-compat mechanisms from 02 are now verified over real HTTP:**
> 1. **The `selections` projection** — regenerates correctly after a merge (7.5) and is byte-equal
>    to the API rows per block on a 3-block READ activity (7.8). That column is precisely what a
>    shipped build reads.
> 2. **The legacy alias** — `GET …/exegesis-highlights` returns the **old shape verbatim**
>    (`{success, readBlockId, highlights[]}`, **no `blockIds`**), carrying every field an old
>    decoder expects, and still refuses a READ activity with the **original** error string. Old
>    behaviour preserved exactly.
>
> **So the residual risk narrowed from "is the data still right for old builds" to "does an old
> binary decode it".** Faithful substitute if the remaining risk is judged worth it: stash the
> uncommitted iPhone work, build, point at local — that binary's *code* predates the feature, which
> is what matters; the version string is cosmetic.
>
> **DECIDED (Luke, 2026-08-05): accepted on the contract-level proof; the substitute build was not
> run.** So the one thing this feature never demonstrated is an actual pre-feature *binary*
> decoding the current server's responses. The data it would read is proven correct; the decode is
> inferred from the response shape being unchanged. **If a tester on an old build reports missing
> Read highlights after release, start here** — this is the row that was accepted rather than
> observed.

## Human walk (Luke, 2026-08-05)

Recorded verbatim: **"everything works, I tested it, let's wrap this spec."**

That is a **blanket confirmation of the feature working, not a per-step report** — steps 7.1, 7.2,
7.3, 7.4 and 7.6 are ticked on the strength of it, and no individual observation (which colour on
which screen, whether the member player showed the note) was narrated back. Recorded this way
deliberately so a later reader can tell what was *observed* from what was *covered by a general
affirmative*. He owns the feature and exercised it; the granularity is simply what it is.
- [x] 7.8 A multi-block READ activity: each block's highlights land on the right block on **both**
      consumers · spec: 03 §2.1, 09 §X-e

> **7.8 PASSED 2026-08-05** on `9de1a48c…` — a **READ activity with 3 locked blocks and 4
> backfilled highlights**, i.e. exactly the shape 03 §2.1 was rewritten for and the one the old
> single-`readBlockId` response could not address.
>
> **The contract's shape change works:** `blockIds` returns all three **in `orderNumber` order**
> (verified against the database ordering, not assumed), and the deprecated `readBlockId` is the
> first locked block — retained for shipped builds exactly as specified.
>
> **Highlights land on the right block, and the two consumers agree.** The highlights distribute
> 1 / 2 / 1 across the three blocks; every `highlight.readBlockId` is one of the returned
> `blockIds`; and per block, the spans the **iPhone** consumes (`highlights[]` filtered by
> `readBlockId`) are **identical** to the spans the **web player and older builds** consume (that
> block's `selections` projection):
>
> | block | iPhone (API rows) | web / old builds (projection) | match |
> |---|---|---|---|
> | `c9b3779f` | `94–150` | `94–150` | ✅ |
> | `72959b23` | `44–63`, `255–294` | `44–63`, `255–294` | ✅ |
> | `57d496af` | `18–27` | `18–27` | ✅ |
>
> **This is the consumer-parity proof for the multi-block case (09 §X-e):** no block leaks another
> block's spans in either direction. Read-only — nothing was mutated.

## Phase gates

Every app's gates, run fresh (08 §Gates) — server, client, iPhone and capture.

## Verification checklist

- [x] All eight walk steps performed live against the local stack, not reasoned about — **with one
      stated exception: 7.7, which cannot be performed at all (§G-ad) and was accepted rather than
      executed.** 7.5 and 7.8 were run against the live stack by agent; 7.1–7.4 and 7.6 by Luke on
      his own device
- [x] 7.5 and 7.7 in particular were **actually executed** — they are the two the whole
      data-safety argument rests on — **7.5 YES**, over real HTTP, with the merged row's notes
      matched character-for-character and the data restored to a byte-identical fingerprint.
      **7.7 NO — and this row is ticked only because the step is impossible, not because it
      passed.** The artefact cannot exist; both mechanisms it tested were verified at the contract
      level instead. This is the single weakest point in the feature's evidence and it is named
      here rather than buried
- [x] Consumer parity: the fields 05 and 06 consume are identical, and both match 03's frozen table
      — proven with data by 7.8: per block, the rows the iPhone reads equal the projection the web
      player reads, exactly, across a 3-block activity
- [x] No `(claimed — unverified)` markers remain anywhere in the suite — swept 2026-08-05; the only
      two matches are the checklist row asking the question and the integrity check answering it
- [x] Local facts recorded in the ledger's env notes for whoever runs this next — including the
      schema traps (`content_highlights` vs `highlights`, `lessonActivityId` vs `activityId`, dev DB
      on :5434) and the broken `npm run guard` wrapper

## VERIFIED

✅ **2026-08-05 — the walk is done and the feature is human-confirmed.**

**What this phase established:** the two steps carrying the data-safety argument were run against
the live stack — a highlight drawn across two noted highlights kept **both** notes
(`"Note A\n\nNote B"`, exact), and a 3-block Read activity showed **per-block consumer parity**
between what the iPhone reads and what the web player reads. Luke then walked the feature himself
and reported it working.

**What it did NOT establish, stated plainly:** no pre-feature *binary* was ever pointed at the
current server. Build 374 cannot be reconstructed — the repo has no tags, the build number was
committed once, and release builds are hardcoded to production so a TestFlight copy cannot reach a
local server. The *data* an old build reads is proven correct (the projection) and the *shape* it
decodes is proven unchanged (the legacy alias returns the old response verbatim), so the residual
risk is decode-only — but it is real and it was accepted, not measured.

**Gates:** all four apps run fresh and green on 2026-08-05 — server tsc 0 · 476 server tests ·
client build 0 · 33 vitest · 235 phpunit · tokenization guard 853, **exactly the pre-existing
baseline, so this feature's delta is zero** · iPhone BUILD SUCCEEDED including the baseline-gated
SwiftLint phase (zero new violations) · capture up. `npm run lint` is red and impossible repo-wide
(§G-i) — not this feature's debt.

**Commits:** none yet — the whole feature is uncommitted at sign-off time.
