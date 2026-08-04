# Phase 2 — Schema, routes and the projection  ·  app: server

> Part of docs/features/highlighting/. Preconditions: **Phase 1's VERIFIED block is signed.**
> This phase's sign-off **FREEZES the contract in 03** — consumers build against it afterwards
> and amendments require a dated `03` edit + an `X#` row + a re-run of these gates.

## Goal

`exegesis_highlights` becomes `content_highlights` with a `style` column; all eight routes are generalised
to `…/highlights` across both context files with their `…/exegesis-highlights` aliases intact; and
`syncSelectionsForBlock` maintains the derived projection. **No data is migrated in this phase** —
that is Phase 3.

## Companion skills

`/schema` exists (`server/.claude/commands/schema.md`) and is the normal path — **but do NOT use it
on this feature.** Its step 4 applies whatever migration was generated, and Atlas generated a
`DROP TABLE` for this rename (09 §X-h). Run the steps yourself so the review step cannot be skipped:

```
cd server && npm run schema:validate     # tsx scripts/schema/validate-schema.ts
cd server && npm run schema:generate     # yaml-to-hcl.ts && yaml-to-prisma.ts
cd server && npm run schema:diff         # schema:generate, then atlas migrate diff --env local
#   → REVIEW the generated file in server/atlas/migrations/ BEFORE the next line
cd server && npm run migrate:apply       # atlas migrate apply --env local
cd server && npm run migrate:status
```

**Never `npx prisma migrate dev`** — Atlas owns the migrations, Prisma is generated from the YAML.
`/api` for route scaffolding conventions.

## Tasks (execute in order unless marked ∥)

- [x] 2.1 ✅ **DONE 2026-08-04.** Edited `server/schema/schema.yaml`; `npm run schema:validate` → ✅
      **All schema files are valid.** · spec: 03 §1.1, §1.2
      - [x] `ExegesisHighlight` → **`ContentHighlight`**, `exegesis_highlights` →
            **`content_highlights`** (Luke's decision, 09 §X-g — **not** `Highlight`/`highlights`,
            which the Bible reader's per-user verse highlights already own at `schema.yaml:1435`).
            The destination name was grepped across all four apps and confirmed unused *before*
            applying. A comment at the model records why the obvious name was not taken.
      - [x] Back-relation `ActivityReadBlock.exegesisHighlights` → **`contentHighlights`**. Not in
            the original task text; `schema:validate` caught the dangling reference. This name is a
            Prisma `include` key — see 2.3.
      - [x] `style: {type: string, default: "highlight"}` added, with the default spelled out as
            "every pre-existing row keeps today's appearance"
      - [x] `ActivityReadBlock.selections` description rewritten to DERIVED / READ-ONLY, naming
            `syncSelectionsForBlock` as the only writer and warning off route/service/client writes
- [x] 2.2 ✅ **DONE 2026-08-04 — migration hand-authored, applied, and proven non-destructive.**
      · spec: 03 §1.3
      - [x] `schema:generate` → Prisma model `ContentHighlight` with `@@map("content_highlights")`,
            `style String @default("highlight")`, back-relation `contentHighlights` (71 models)
      - [x] `schema:diff` → `server/atlas/migrations/20260804070717.sql`
      - [x] **Reviewed — and it was destructive.** Atlas does not detect renames: it emitted
            `CREATE TABLE "content_highlights"` + **`DROP TABLE "exegesis_highlights"`**, which
            would have deleted every existing highlight and note. See 09 §X-h. *This is why the
            review step exists; had `/schema` been run unattended it would have applied it.*
      - [x] **Replaced by hand** with in-place `ALTER TABLE … RENAME TO`, six constraint/index
            renames (Postgres keeps old identifiers through a table rename), and
            `ADD COLUMN "style" text NOT NULL DEFAULT 'highlight'`. Existing column types are
            preserved deliberately (09 §G-g). No row created, copied or dropped.
      - [x] `atlas migrate hash` re-run — `atlas.sum` matches the edited file
      - [x] **Made replay-safe on the second attempt.** The first hand-authored version hardcoded
            the *live* database's Prisma-era identifiers; it applied fine but broke `schema:diff`,
            which replays the directory into a scratch DB where the table carries **Atlas's** names
            (`fk_exegesis_highlights_readBlock`, `idx_exegesis_…`) from `20260510032114.sql`. Every
            rename is now a conditional `DO $$` block accepting either ancestor, and `ADD COLUMN`
            uses `IF NOT EXISTS` — safe against a live DB, a from-scratch replay, and a re-run.
            See 09 §G-h.
      - [x] **`npm run migrate:apply` → applied, then deliberately rolled back with
            `atlas migrate set` and re-applied to PROVE idempotency.** Ran clean both times.
      - [x] **Data preserved — verified, not assumed.** Row fingerprint
            `md5(id|readBlockId|orderNumber|start|end|noteMarkdown ORDER BY id)` =
            **`4ab6fd621692720c1caf55657ae08117`** before the migration and identical after it and
            after the re-apply. 36 rows · 17 blocks · 26 carrying notes, unchanged throughout.
            All 36 rows backfilled to `style = 'highlight'`.
      - [x] `\d content_highlights` shows all six identifiers renamed and the FK intact;
            `migrate:status` → **OK, 0 pending**
      - [x] `schema:diff` → **"The migration directory is synced with the desired state, no changes
            to be made"** — zero residual drift. (Getting there also required fixing the `style`
            column to `character varying`, not `text`, and correcting the YAML `selections`
            description that still said "Highlight rows".)
      - [x] `npx prisma generate` — `prisma.contentHighlight` now on the client
- [x] 2.3 ✅ **DONE 2026-08-04 — 84 identifiers across 10 files; `tsc` clean, 435 tests pass.**
      **The suite named 4 files; the truth was 10** (09 §G-f understated it too — corrected here).
      Renamed: `exegesisHighlight` → `contentHighlight` (30, the Prisma accessor) ·
      `exegesisHighlights` → `contentHighlights` (31, the relation / `include` key) ·
      `exegesisHighlightData` → `contentHighlightData` (23, an internal `LessonCopyRows` field —
      renamed for consistency, since leaving "exegesis" on data that now includes Read highlights
      is the exact confusion this feature exists to end).
      **Deliberately NOT renamed:** `exegesisVisitedHighlightIds` (12 sites) — a real column on
      `member_activity_progress`, unrelated to this model. Verified untouched afterwards.
      **Checked before renaming:** no occurrence is a quoted string or JSON response key, so the
      API contract is unaffected — the only quoted uses are TypeScript indexed-access types.
      Files: `routes/programs.ts` · `routes/enrollments.ts` · `routes/study-preview.ts` ·
      `routes/activity-progress.ts` · `routes/__tests__/enrollment-edit.test.ts` ·
      `services/lesson-copy.ts` · `services/enrollment-sync.ts` · `services/enrollment-edit.ts` ·
      `services/member-progress.service.ts` · `services/lesson-content-hash.ts`
      *(the last five were named nowhere in the suite; `lesson-content-hash.ts` matters most —
      it is the file 09 §X-c identified as the staleness trigger)*
      · gate: `npx tsc --noEmit` → **exit 0** · `vitest run` → **435 passed / 37 files**

  <details><summary>Original task text (superseded)</summary>

  Rename `prisma.exegesisHighlight` → **`prisma.contentHighlight`** across the server.
      ⚠️ **NOT `prisma.highlight`** — that accessor already belongs to the Bible reader's model
      (`src/routes/bible.ts`, 7 call sites); using it would silently retarget the wrong table.
      **Two renames, not one** (09 §G-f) — the model accessor *and* the relation field
      `exegesisHighlights` → `contentHighlights`, which is a Prisma `include` key, so every
      eager-loading query fails to compile until updated. Corrected file list, all sites:
      · `src/routes/enrollments.ts:166, 4709, 4872`
      · `src/routes/study-preview.ts:427, 540` *(inside long inline `include` chains)*
      · `src/routes/programs.ts:1710, 1974`
      · `src/services/lesson-copy.ts:27, 29, 88` *(also a typed field name, not just a query key)*
      · plus every `prisma.exegesisHighlight` call site in `programs.ts` / `enrollments.ts`
      · tests: `npx tsc --noEmit` is the real gate here — it finds any site this list missed

  </details>

- [x] 2.4 ✅ **DONE 2026-08-04.** Program routes generalised to `/activities/:activityId/highlights`
      with `…/exegesis-highlights` kept as aliases. Each verb is now ONE handler factory
      (`listHighlightsHandler(legacy)` etc.) mounted at both paths, so the two can never drift.
      · files: `server/src/routes/programs.ts` · spec: 03 §2, §2.5
- [x] 2.5 ✅ **DONE 2026-08-04.** Scheduled routes generalised identically.
      · files: `server/src/routes/enrollments.ts` · spec: 03 §2
      · **Confirmed the asymmetry was real and handled:** this file gates on `activity.type`, the
        program file on `activity.activityType`. Separate helpers, not a copy-paste.
- [x] 2.6 ✅ **DONE 2026-08-04.** Gate relaxed to EXEGESIS **or** READ on the general routes; the
      aliases keep the strict EXEGESIS-only gate and its exact original error string, so an old
      build's behaviour is unchanged. **Verified live** (curl, non-bot UA, after
      `docker restart makeready-server`):
      | Case | Result |
      |---|---|
      | READ on `…/highlights` | ✅ 200 + `blockIds` |
      | READ on `…/exegesis-highlights` | ✅ 400 `"Activity is not an EXEGESIS activity"` |
      | USER_INPUT on `…/highlights` | ✅ 400 `"Activity is not an EXEGESIS or READ activity"` |
      | EXEGESIS on `…/highlights` | ✅ 200 |
- [x] 2.7 ✅ **DONE 2026-08-04.** GET uses `findMany` over all locked blocks and returns `blockIds[]`;
      `readBlockId` retained as the deprecated first block. Cross-block ordering is by block
      position then `orderNumber` — *not* by `readBlockId`, which would sort by uuid and be
      meaningless. The legacy alias still scopes to the first block only.
      **Byte-identical check against the pre-change baseline** (captured before task 2.4, stored
      beside the ledger): top-level keys identical, `readBlockId` identical, counts identical, and
      **every pre-existing field byte-identical** on both fixtures. The only difference is an
      **added** `style` key per row — unavoidable once it is a column, and additive-safe for a
      shipped Swift `Codable` decoder. Recorded rather than glossed.
- [x] 2.8 ✅ **DONE 2026-08-04.** `style: z.enum(['highlight','bold']).optional()` on POST and PATCH;
      incoming style wins on merge (03 §2.2 / 09 §D-a). PATCH now requires at least one of
      `noteMarkdown`/`style`. **Verified live:** POST `style:"bold"` → row + projection carry
      `bold` · PATCH → `highlight` → projection follows · PATCH `{}` → 400.
- [x] 2.9 ✅ **DONE 2026-08-04.** `syncExegesisSelectionsForBlock` → `syncSelectionsForBlock`
      (and its scheduled twin), emitting the row's **real** `style` instead of a hardcoded
      `'highlight'`, ordered by `orderNumber`. Still the only writer of that column.
      **Hash neutrality holds** (09 §X-c): every existing row's style is `'highlight'`, so output is
      byte-identical to before and no enrolled group's lessons go stale.
      · **Beyond the task text:** PATCH never used to call the sync, because it could only change
        `noteMarkdown`, which is not in the projection. It can now change `style`, which is — so
        PATCH calls the sync when and only when `style` changed.
- [x] 2.10 ✅ **DONE 2026-08-04 — confirmed in code, not assumed** (as 09 §X-d required).
      `programs.ts:2746` deletes highlights for a block, but the whole branch is inside
      `if (activity.activityType === 'EXEGESIS')`, is scoped to that one activity's own blocks
      (`lessonActivityId: id`), and those blocks are deleted on the very next line. **READ
      activities take the `else` branch, which only shifts `orderNumber` and deletes nothing.**
      So convergence is not merely equivalent here — Read highlights are never reachable by this
      path at all. Safer than X-d assumed.
- [x] 2.11 ✅ **DONE 2026-08-04 — 18 tests, `src/routes/__tests__/content-highlights.test.ts`.**
      Suite total 435 → **453, all passing**, three consecutive clean runs.
      Covers: the gate matrix in both directions (READ/EXEGESIS accepted on the general routes,
      non-text refused, READ refused on the alias with the *original* error string) · the alias
      keeping the OLD response shape (asserts `blockIds` is **absent** and the key set is exactly
      `success/readBlockId/highlights`) · multi-block reads returning document order rather than
      uuid order · `style` default, `bold`, and rejection of an unknown value · the projection
      matching the rows after create, patch and delete, including emptying on the last delete ·
      **merge semantics — union span, `ALPHA\n\nBRAVO\n\nCHARLIE` note concatenation, incoming
      style winning** · all four PATCH shapes including the empty-body 400 · the pre-backfill
      guard returning 409 with the legacy spans intact · cross-activity ownership · `end > start`.

      **The tests were checked for the ability to FAIL, not just to pass** — passing first try is
      not evidence. Two deliberate regressions were introduced and reverted:
      | Injected regression | Result |
      |---|---|
      | Guard neutered (`spans = 0`) | ✅ the 409 test failed — the guard is what makes it pass |
      | Merge keeps only the last note (`.slice(-1)`) | ✅ the merge test failed — genuine note-loss guard |

      **Coverage gap, named rather than implied (09 §G-j):** every automated test here drives the
      **program** context. The **scheduled** (`/api/scheduled-activities/…`) twin is verified only
      by curl — multi-block `blockIds`, deprecated `readBlockId`, and the strict alias gate all
      confirmed live against a real scheduled READ activity, mirroring the program context exactly.
      Automated coverage there needs an enrollment fixture and is owed. · files: `server/src/routes/__tests__/`
      · spec: 04 §Tests, 08 §Server

## Gate results — 2026-08-04 (after tasks 2.1–2.3)

| Gate | Result |
|---|---|
| `npx tsc --noEmit` | ✅ **exit 0** |
| `vitest run --exclude='test/integration/production.test.ts'` | ✅ **453 passed, 38 files, 0 failed** — three consecutive clean runs (435 before this phase's 18 new tests) |
| `npm run schema:validate` | ✅ valid |
| `npm run schema:diff` | ✅ "migration directory is synced with the desired state, no changes to be made" |
| `npm run migrate:status` | ✅ OK, 0 pending (current `20260804070717`) |
| `npm run lint` | ⛔ **BLOCKED — no ESLint config exists in the repo.** Pre-existing, not caused by this work. See 09 §G-i |
| `docker restart makeready-server` | ✅ run twice (after the route refactor, and after the X-i guard) before each round of curl verification |

**Live route verification, 2026-08-04** (all via curl with a non-bot User-Agent, against the
restarted container). Gate matrix in 2.6; style round-trip in 2.8; guard proof in 09 §X-i.
The full write round-trip — POST `style:"bold"` → PATCH → DELETE — left the test block in exactly
its before-state (`selections` null, 0 rows), so no local data was disturbed.

**Two environment facts this phase discovered** (both cost real time; noted so nobody re-derives them):
1. **The test suite uses a SEPARATE database** — `localhost:5433/makeready_test` from `.env.test`,
   not the dev DB on `:5434`. Migrations must be applied there too or every enrollment test fails
   with "table `public.content_highlights` does not exist". The migration's conditional form made
   applying it there a straight `psql -f`, which is exactly the replay-safety G-h bought.
   *(Note the `atlas.hcl` `test` env points at `:5432` — a third address, and it does not match
   `.env.test`. Not investigated; flagged only.)*
2. **`test/integration/production.test.ts` fires at the LIVE production API.** It fails locally for
   network/auth reasons and says nothing about this feature. `npm run test:ci` already excludes it —
   use that exclusion when judging a gate, as the table above does.
3. **`member-auth.test.ts`'s logout case is flaky under parallel load** — it intermittently dies
   with `Parse Error: Expected HTTP/, RTSP/ or ICE/`, a supertest socket race. It passes in
   isolation (15/15), never mentions highlights, and three consecutive full runs after it were
   clean. Pre-existing and unrelated; noted so the next person does not chase it into this feature.

## Phase gates (run fresh, record output)

```
cd server && npx tsc --noEmit
cd server && npm run lint
cd server && npm run test:run
cd server && npm run schema:validate
cd server && npm run schema:diff
cd server && npm run migrate:status
docker restart makeready-server      # REQUIRED after any server/src edit — tsx watch misses bind-mount events
```

## Verification checklist

- [x] `GET …/highlights` on a **READ** activity with several locked blocks returns every block's
      highlights and a correct `blockIds[]` — the shape 03 §2.1 promises, field for field.
      Covered by a test with a **four-locked-block** READ activity, asserting `blockIds` equals the
      blocks in `orderNumber` order and `readBlockId` is the first of them; a second test creates a
      highlight on each of three blocks out of order and asserts they come back in document order.
- [x] `GET …/exegesis-highlights` on an EXEGESIS activity returns **byte-identical** fields to
      before this phase. **Diffed against the baseline after the refactor: top-level keys identical,
      `readBlockId` identical, counts identical, every pre-existing field byte-identical on both
      fixtures. The ONLY difference is an added `style` key per row** — unavoidable once it is a
      column, and additive-safe for a shipped Swift `Codable` decoder. A test also asserts the alias
      omits `blockIds` entirely. ✅ **Baseline captured 2026-08-04, before any Phase 2 edit**, to
      `~/.claude-home/projects/-Users-lukekeith-www-makeready/build-spec/highlighting-phase2-baseline/`
      (outside git, beside the ledger, so a context clear cannot lose it): activities `f93cc7f1`
      (4 highlights) and `53ce58da` (1). Today's shape carries **no `style` field** — e.g.
      `{"success":true,"readBlockId":"cc0e6a55…","highlights":[{"id":…,"readBlockId":…,
      "orderNumber":1,"start":6,"end":47,"noteMarkdown":"Notes","createdAt":…,"updatedAt":…}]}`.
      The alias must still return exactly these keys afterwards.
- [x] The generated migration re-applies as a no-op; `migrate:status` clean — **proven the hard
      way**: the revision was rolled back with `atlas migrate set` and the migration re-applied
      against the already-migrated database. Clean both times. `migrate:status` → OK, 0 pending.
- [x] No column dropped, no row deleted anywhere in M1/M2 — the generated migration *did* contain
      `DROP TABLE` and was replaced by hand (09 §X-h). Row fingerprint
      `4ab6fd621692720c1caf55657ae08117` identical before, after, and after the re-apply; 36 rows
      still present at phase close.
- [x] Both context files behave identically for the same request shape — **verified live, not by
      tests.** A scheduled READ activity returned both locked blocks with a correct `blockIds[]`
      and first-block `readBlockId`, and its legacy alias refused with the original EXEGESIS-only
      string, matching the program context exactly. Automated coverage for the scheduled context
      is owed — **09 §G-j**, recorded rather than implied.
- [x] curl tests use a non-bot User-Agent (the bot guard 403s otherwise) — every curl in this
      phase used `-A "MakeReadyDev/1.0"`.
- [x] **Beyond the checklist:** the new tests were checked for the ability to fail by injecting two
      deliberate regressions (guard removed; merge dropping all but the last note). Both were
      caught, then reverted. See 2.11.

## Contract freeze

On signing this block, **03's endpoint table is frozen.** Record the freeze date in the ledger's
Contract state section before any consumer phase opens.

## VERIFIED

✅ **VERIFIED 2026-08-04 — agent evidence. Phase 3 may open; `03` is now FROZEN.**

**What exists that didn't:** `content_highlights` with a `style` column, eight generalised routes
across both context files with backward-compatible aliases, and `syncSelectionsForBlock` maintaining
`ActivityReadBlock.selections` as a derived projection. No data was migrated — that is Phase 3.

**Gates, run fresh at phase close:** `tsc --noEmit` exit 0 · **453 tests pass across 38 files**
(three consecutive clean runs) · `schema:validate` valid · `schema:diff` "synced with the desired
state, no changes to be made" · `migrate:status` OK, 0 pending · 36 highlight rows still present.
`npm run lint` is **BLOCKED repo-wide** with no ESLint config anywhere — pre-existing, not caused
here, and it will block `/build-spec-verify` for every server feature until fixed (09 §G-i).

**The two things this phase nearly got wrong, both caught by reading rather than by tooling:**
1. Atlas generated `DROP TABLE "exegesis_highlights"` for the rename. Applying it would have
   deleted every highlight and note in the database (09 §X-h).
2. Writing to a not-yet-backfilled block would have wiped its spans — 49 blocks / 67 spans measured
   (09 §X-i). Now refused with a 409.

**What this sign-off does NOT claim:**
- **No human has used any of this.** Every observation here is an agent's — curl, psql, vitest.
  The member-visible surfaces do not exist until the consumer phases.
- **The scheduled context has no automated tests** (09 §G-j). It is verified live by curl and
  mirrors the program context, but that is evidence, not coverage.
- **The 409 guard is defensive code the spec did not ask for** and is flagged for Luke's review.

## Contract freeze

✅ **`03-data-and-api.md`'s endpoint table is FROZEN as of 2026-08-04.** Consumers (phases 4 and 5)
build against it as written. Any amendment now requires a dated edit in `03`, an `X#` row in `09`
saying what broke, and a re-run of this phase's gates.

Frozen shape, as actually served and verified: `…/highlights` returns
`{success, readBlockId (deprecated, first locked block), blockIds[], highlights[]}` where each row
is `{id, readBlockId, orderNumber, start, end, noteMarkdown, style, createdAt, updatedAt}`.
The `…/exegesis-highlights` aliases return the same rows **without** `blockIds`, scoped to the first
locked block, and remain EXEGESIS-only.
