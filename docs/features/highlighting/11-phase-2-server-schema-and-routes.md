# Phase 2 — Schema, routes and the projection  ·  app: server

> Part of docs/features/highlighting/. Preconditions: **Phase 1's VERIFIED block is signed.**
> This phase's sign-off **FREEZES the contract in 03** — consumers build against it afterwards
> and amendments require a dated `03` edit + an `X#` row + a re-run of these gates.

## Goal

`exegesis_highlights` becomes `highlights` with a `style` column; all eight routes are generalised
to `…/highlights` across both context files with their `…/exegesis-highlights` aliases intact; and
`syncSelectionsForBlock` maintains the derived projection. **No data is migrated in this phase** —
that is Phase 3.

## Companion skills

`/schema` after **every** `schema/*.yaml` edit — it validates, generates HCL + Prisma, diffs the
migration and applies it. Never `npx prisma migrate dev`. `/api` for route scaffolding conventions.

## Tasks (execute in order unless marked ∥)

- [ ] 2.1 Edit `server/schema/schema.yaml:3794` — rename `ExegesisHighlight` → `Highlight`,
      `table_name: highlights`, add `style: {type: string, default: "highlight"}`. Update
      `ActivityReadBlock.selections`' description (`:3744`) to say DERIVED/read-only.
      · spec: 03 §1.1, §1.2 · tests: `npm run schema:validate`
- [ ] 2.2 Run `/schema` → produces M1 (rename) + M2 (add `style`). **Review the generated migration
      before applying** — it must not drop a column or delete a row (03 §1.3).
      · spec: 03 §1.3
- [ ] 2.3 ∥ Rename `prisma.exegesisHighlight` → `prisma.highlight` across the server.
      · files: `server/src/routes/programs.ts`, `server/src/routes/enrollments.ts`, any service
- [ ] 2.4 Generalise the **program** routes to `…/highlights`, keeping `…/exegesis-highlights` as
      aliases. · files: `server/src/routes/programs.ts` GET `:2954` · POST `:2997` · PATCH `:3086`
      · DELETE `:3137` · spec: 03 §2, §2.5
- [ ] 2.5 Generalise the **scheduled** routes identically.
      · files: `server/src/routes/enrollments.ts` GET `:4267` · POST `:4312` · PATCH `:4403`
      · DELETE `:4456` · spec: 03 §2 · **note: this file gates on `activity.type`, not
      `activity.activityType` (`:4277`) — not a copy-paste from 2.4**
- [ ] 2.6 Relax the activity-type gate to accept `EXEGESIS` **or** `READ` at all eight sites; 400
      otherwise. Aliases keep the strict EXEGESIS-only gate so old builds are bit-identical.
      · spec: 03 §2, §2.5 · tests: READ ✅, EXEGESIS ✅, VIDEO → 400, alias on READ → 400
- [ ] 2.7 GET returns **all** locked blocks: replace `findFirst({isLocked:true})` with `findMany`,
      add `blockIds[]`, retain `readBlockId` as the deprecated first block.
      · spec: 03 §2.1 · tests: a READ activity with three locked blocks returns all three
- [ ] 2.8 `style` on POST/PATCH: `z.enum(['highlight','bold']).optional()`; incoming style wins on
      merge. PATCH requires at least one of `noteMarkdown`/`style`.
      · spec: 03 §2.2, §2.3 · tests: each PATCH shape incl. neither → 400
- [ ] 2.9 Generalise `syncExegesisSelectionsForBlock` (`programs.ts:2894`) → `syncSelectionsForBlock`,
      emitting the **real** `style` instead of the hardcoded `'highlight'`, sorted by `orderNumber`.
      Call after every mutation in both files. It stays the **only** writer of that column.
      · spec: 03 §3 · tests: after each mutation the projection equals the rows
- [ ] 2.10 Verify the deletion cascade at `programs.ts:2746` is still correctly scoped now that Read
      highlights live in this table (09 §X-d closed it as equivalent — confirm in code, don't assume)
- [ ] 2.11 Tests for everything above · files: `server/src/routes/__tests__/`
      · spec: 04 §Tests, 08 §Server

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

- [ ] `GET …/highlights` on a **READ** activity with several locked blocks returns every block's
      highlights and a correct `blockIds[]` — the shape 03 §2.1 promises, field for field
- [ ] `GET …/exegesis-highlights` on an EXEGESIS activity returns **byte-identical** fields to
      before this phase (capture the response before 2.4 and diff it)
- [ ] The generated migration re-applies as a no-op; `migrate:status` clean
- [ ] No column dropped, no row deleted anywhere in M1/M2
- [ ] Both context files behave identically for the same request shape
- [ ] curl tests use a non-bot User-Agent (the bot guard 403s otherwise)

## Contract freeze

On signing this block, **03's endpoint table is frozen.** Record the freeze date in the ledger's
Contract state section before any consumer phase opens.

## VERIFIED

*(unsigned)*
