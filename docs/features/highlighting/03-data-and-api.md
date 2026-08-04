# Data & API — the contract

> **This is the shared contract.** Every consumer codes against this document alone. It freezes
> when the server phase signs VERIFIED; amendments after that require a dated edit here, an `X#`
> row in 09, and a re-run of the server phase gates.

## 1. Schema change

Source of truth is `server/schema/schema.yaml` — never edit `prisma/schema.prisma` or
`atlas/.schema.hcl` (both are generated). After editing the YAML run `npm run schema:validate` →
`schema:generate` → `schema:diff` → review → `migrate:apply` → `migrate:status`
(**there is no `/schema` skill** — 09 §G-e).

### 1.1 `ExegesisHighlight` → `ContentHighlight`  ·  applied 2026-08-04

**Not `Highlight`.** That model already exists (`server/schema/schema.yaml:1435`) and is the Bible
reader's per-user personal verse highlights — a different domain that this feature does not touch.
Decided by Luke, 2026-08-04; analysis and blast radius in 09 §X-g.

**The rename is internal only.** API paths stay activity-scoped at `…/highlights` and the response
key stays `highlights` — §2 below is unaffected by this decision.

```yaml
  ContentHighlight:
    table_name: content_highlights   # was exegesis_highlights
    fields:
      id:            { type: uuid, primary: true, default: uuid() }
      readBlockId:   { type: string, description: "FK to ActivityReadBlock (locked block)" }
      orderNumber:   { type: int,    description: "Stable ordering for highlight navigation" }
      start:         { type: int,    description: "Start character offset (plain-text) into block content" }
      end:           { type: int,    description: "End character offset (exclusive)" }
      style:         { type: string, default: "highlight" }   # NEW — highlight | bold
      noteMarkdown:  { type: text }
      createdAt:     { type: datetime, default: now() }
      updatedAt:     { type: datetime }
```

Everything except `style` and the two names is unchanged, so existing rows survive the rename
without transformation.

### 1.2 `ActivityReadBlock.selections` — retained, redefined

The column is **not dropped** (D3). Its description changes from authoritative storage to:

```yaml
      selections:
        type: json
        nullable: true
        description: "DERIVED, read-only projection of ContentHighlight rows for this block,
                      maintained by syncSelectionsForBlock(). Retained so shipped iPhone builds keep
                      reading the shape they were built against. Do not write directly."
```

### 1.3 Migration list

| # | Migration | Type | Reversible |
|---|---|---|---|
| M1 | rename `exegesis_highlights` → `content_highlights` (+ index/FK renames) | rename | yes |
| M2 | add `content_highlights.style` default `'highlight'`, backfill existing rows to `'highlight'` | additive | yes |
| M3 | **data backfill** — `ActivityReadBlock.selections[]` → `content_highlights` rows (see §4) | additive, idempotent | yes (rows are deletable; source column retained) |

⚠️ **M1 is the single most dangerous statement in this feature.** Atlas may express a table rename
as drop-and-create, which would destroy every existing highlight and violate governing rule 1. The
generated migration must be read before it is applied, and must contain
`ALTER TABLE … RENAME TO …` — hand-authored if Atlas does not produce it.

No migration drops a column or deletes a row. `/build-spec` must not generate one that does.

## 2. Endpoints

All paths exist in **two contexts** with identical shapes:
`/api/activities/:activityId/…` (program) and `/api/scheduled-activities/:activityId/…`
(enrollment). Auth on every route: `requireAuth` **+**
`canManageOrgContent(userId, organizationId, creatorId)` — the org-aware helper, unchanged from
today's exegesis routes (`programs.ts:2964`, `:3016`, `:3101`, `:3147`).

> **Activity-type gate must relax — and the two contexts don't spell it the same way.**
> Program routes gate on `activity.activityType` (`programs.ts:2968`, `:3020`, `:3105`, `:3151`);
> scheduled routes gate on **`activity.type`** (`enrollments.ts:4277` and its three siblings) —
> a different field on a different model. Relaxing the gate is **not** a copy-paste across the two
> files. Both accept **`EXEGESIS` and `READ`** afterwards and 400 on anything else.
> *(added 2026-08-04 — gap hunt.)*

### 2.1 `GET /api/activities/:activityId/highlights`

Returns every highlight on the activity, across **all** of its locked blocks.

> **Shape change from the exegesis original.** The old route returned a single
> `readBlockId` chosen by `findFirst({ isLocked: true })` — the exegesis model assumes one locked
> block per activity. **A READ activity can have many verse blocks**, so a single id cannot
> address them. `readBlockId` is retained but **deprecated and nullable** (first locked block, for
> shipped builds); consumers use `highlight.readBlockId` on each row.

```jsonc
200 {
  "success": true,
  "readBlockId": "uuid|null",        // DEPRECATED — first locked block only
  "blockIds": ["uuid", "uuid"],      // NEW — every locked block, in orderNumber order
  "highlights": [
    { "id": "uuid", "readBlockId": "uuid", "orderNumber": 1,
      "start": 0, "end": 42, "style": "highlight",
      "noteMarkdown": "", "createdAt": "…", "updatedAt": "…" }
  ]
}
```
Errors: `404 {success:false,error:"Activity not found"}` (missing **or** unauthorised — the
existing conflation is retained deliberately); `400` wrong activity type; `500`.

### 2.2 `POST /api/activities/:activityId/highlights`

```jsonc
// request
{ "readBlockId": "uuid", "start": 0, "end": 42,
  "style": "highlight",              // NEW, optional, default "highlight"
  "noteMarkdown": "" }               // optional, default ""
```
```jsonc
201 { "success": true,
      "highlight": { … },            // the created (possibly merged) row
      "absorbedIds": ["uuid"] }      // rows absorbed by overlap-merge, now deleted
```
**Merge semantics (unchanged, now applying to READ too):** the new range absorbs every existing
highlight it overlaps; the result spans the union; `noteMarkdown` values are concatenated in
document order with `\n\n`; the merged row keeps the earliest absorbed `orderNumber`
(`programs.ts:3033-3069`).

> ⚠️ **This is the write path with the open data-loss report** (monday#12708759849 sub-issue A).
> It must be reproduced and fixed **before** M3 backfills Read data into this table — see
> [04-server.md](04-server.md) §Prerequisite and D8.

**Style on merge:** when absorbed rows disagree on `style`, the **incoming** style wins for the
merged row. **RATIFIED (Luke, 2026-08-04)** — consumers may rely on this.

Errors: `400` invalid body / wrong activity type; `404` activity or block not found; `500`.

### 2.3 `PATCH /api/activities/:activityId/highlights/:highlightId`

```jsonc
{ "noteMarkdown": "…",   // optional
  "style": "bold" }      // NEW, optional
```
At least one field required. Returns `200 { success, highlight }`. Ownership is verified twice —
org check on the activity, then `highlight.readBlock.lessonActivityId === activityId`
(`programs.ts:3110-3117`) — retain both. Errors: `400`, `404` (activity or highlight), `500`.

### 2.4 `DELETE /api/activities/:activityId/highlights/:highlightId`

Returns `200 { success: true }`. Same double ownership check. Errors: `404`, `500`.

### 2.5 Legacy aliases (backward compatibility)

The four `…/exegesis-highlights…` paths remain mounted for **at least one release**, in both
contexts, delegating to the same handlers and returning the same field names a shipped build
decodes. They keep the strict `EXEGESIS`-only gate so an old build's behaviour is bit-identical.

Removal is a separate, later change — not part of this feature.
**DECIDED (Luke, 2026-08-04): revisit one release after this ships**, at which point the cleanup
gets an owner. Until then the aliases and the projection stay.

## 3. The derived projection

`syncSelectionsForBlock(readBlockId)` (generalised from `syncExegesisSelectionsForBlock`,
`programs.ts:2894-2907`) rewrites `ActivityReadBlock.selections` from the block's `ContentHighlight` rows
after **every** mutation:

```ts
selections = highlights
  .sort(byOrderNumber)
  .map(h => ({ start: h.start, end: h.end, style: h.style }))   // style now real, was hardcoded
```

This is what keeps shipped iPhone builds working (D3). It runs after create, update, delete and
the M3 backfill. It is the **only** writer of that column.

> ⚠️ **CONFIRMED (2026-08-04) — this projection is load-bearing on lesson versioning.**
> `lesson-content-hash.ts:180` hashes `block.selections`, and `enrollment-sync.ts:322` decides
> whether an enrolled group's scheduled lesson is stale by comparing that hash. So the projection
> is already how a highlight edit invalidates a version, and any change to how it *serialises*
> re-hashes every block carrying highlights.
> **DECIDED (Luke, 2026-08-04): M3 must be hash-neutral** — the backfill assigns `orderNumber` =
> the span's index in the existing array so the projection re-emits byte-identical JSON. Proven
> achievable in code; mechanism and pre-flight in [04-server.md](04-server.md) §Content-hash
> pre-flight.

## 4. Backfill (M3) — the data-safety procedure

Non-negotiable, per the feature's governing rule 1.

1. **Dry run first**, writing a report and mutating nothing: per block — existing `selections[]`
   count, existing `highlights` row count, and the exact spans that would be created.
2. **Idempotent**: re-running creates nothing new. A selection is considered already migrated when
   a row exists on the same block with the same `(start, end, style)`.
3. **Per-block assertions** after the real run:
   - every span present in `selections[]` before the run exists as a row afterwards;
   - the regenerated projection is **set-equal** to the pre-run `selections[]` (order by
     `orderNumber`, compare `(start, end, style)`);
   - no block loses spans; total row count only increases.
4. **Source retained** — `selections` is never cleared. Rollback = stop writing rows and point
   consumers back at the column.
5. Runs **only after** the prerequisite fix in 04 §Prerequisite is verified.

Overlapping spans within one block's existing `selections[]` are migrated **as-is, without
merging** — the backfill is a copy, not a normalisation. Merging only ever happens on a user
action through §2.2.

## 5. Normative highlight rules (cross-app)

D7: web implements these when its authoring UI is built; the iPhone service implements them now.
They are part of the contract, not a client detail.

| Rule | Value |
|---|---|
| **Granularity** | injected per surface: `verse` (Read editor), `word` (Exegesis editor, Bible reader). Never character. |
| **Word snapping** | grow-only, outward from the user's range. `'` `’` `-` are **intra-word** ("Lord's" stays whole). Whitespace and all other punctuation are boundaries. Never trims what the user covered. |
| **Commit** | on genuine pointer/finger release only. **Never on a timer**, never on a cancelled touch, never on a selection-change debounce. The selection stays live and adjustable until release. |
| **Saved highlight** | `#F4FF76` @ **0.35** |
| **Live selection** | `#F4FF76` @ **0.55** |
| **Active/being-edited** | white @ 0.25 |
| **"Used" reference (Bible reader)** | `#6c47ff` @ 0.2 — the one remaining purple, and it does not mean "highlight" |
| **Overlap** | resolved server-side by §2.2 merge. Consumers never merge locally and then post a union. |
| **`style: "bold"`** | renders as **font weight only — no background wash**, on every surface. *(added 2026-08-04 — G-b: `bold` was in the contract with no rendering rule, which is exactly the divergence this feature exists to prevent. `read-step.vue:63` already documents both style values.)* |
