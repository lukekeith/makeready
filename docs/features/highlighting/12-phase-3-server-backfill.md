# Phase 3 — The backfill  ·  app: server

> Part of docs/features/highlighting/. Preconditions: **Phase 1 VERIFIED** (the merge path is
> proven safe) **and Phase 2 VERIFIED** (the table and projection exist). This is the only phase
> that touches existing customer data. Governing rule 1 applies to every task in it.

## Goal

Every existing Read highlight exists as a `highlights` row, the derived projection reproduces each
block's previous `selections` JSON **byte-for-byte**, and no lesson content hash moves. Nothing is
deleted; `ActivityReadBlock.selections` is retained.

## Companion skills

None — this is a script plus assertions. Do **not** use `/schema`: M3 is a data migration, not a
schema migration.

## Tasks (execute in order — no ∥ in this phase)

- [ ] 3.1 Write `server/scripts/backfill-highlights.ts`. `--dry-run` is the **default**; `--apply`
      is required to write anything. · spec: 03 §4, 04 §Migration & backfill
- [ ] 3.2 Implement the **content-hash pre-flight**: for every block, compute the current
      `selections` JSON and the regenerated projection, and report every block where they differ by
      value, key order or array order — plus how many lessons and enrolled schedules those roll up
      to. · spec: 04 §Content-hash pre-flight · evidence: `lesson-content-hash.ts:180`,
      `enrollment-sync.ts:322`
- [ ] 3.3 Implement normalisation so the pre-flight comes back clean: assign `orderNumber` = the
      span's **index in the existing `selections` array**, so the `orderNumber`-sorted projection
      re-emits the original order. Keys already match — `ReadBlockSelection` (`StudyModels.swift:372`)
      encodes exactly `start`/`end`/`style`. · spec: 04 §How normalisation is achieved
- [ ] 3.4 Implement idempotence: a selection counts as already migrated when a row exists on the
      same block with the same `(start, end, style)`. Second run must create nothing.
      · spec: 03 §4.2 · tests: run twice, assert zero new rows
- [ ] 3.5 Implement the per-block assertions: every pre-run span exists as a row; the regenerated
      projection is set-equal to the pre-run `selections[]`; no block loses spans; total row count
      only increases. · spec: 03 §4.3
- [ ] 3.6 **Run the dry run and read the report.** A dirty pre-flight is a **stop**, not a warning
      — fix normalisation and re-run. Do not proceed to 3.7 on a dirty report.
      · spec: 04 §Content-hash pre-flight (DECIDED: hash-neutral)
- [ ] 3.7 Run `--apply` on local, then re-run the projection rebuild and the assertions.
- [ ] 3.8 Overlapping spans within one block's existing array are migrated **as-is, without
      merging** — the backfill is a copy, not a normalisation of user intent. · spec: 03 §4
- [ ] 3.9 Tests: idempotence, span equality, `selections` untouched on disk, hash-neutrality
      · files: `server/src/routes/__tests__/` or `server/scripts/__tests__/`

## Phase gates

```
cd server && npx tsc --noEmit
cd server && npm run lint
cd server && npm run test:run
cd server && npm run migrate:status
docker restart makeready-server
```

## Verification checklist

- [ ] Dry-run report is **clean** — zero blocks whose serialisation would change
- [ ] Zero lessons and zero enrolled schedules would have their content hash move
- [ ] Second `--apply` run is a no-op (idempotent)
- [ ] Spot-check three real blocks: pre-run `selections` JSON == post-run projection, byte for byte
- [ ] `ActivityReadBlock.selections` still populated on every block that had it
- [ ] Row count only increased; nothing deleted
- [ ] Rollback rehearsed: deleting the created rows and leaving `selections` alone restores the
      previous state exactly

## VERIFIED

*(unsigned)*
