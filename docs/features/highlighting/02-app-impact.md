# App impact

## Scope per app

| App | In scope | What changes | Owner doc |
|---|---|---|---|
| server | ✅ | `exegesis_highlights` → `content_highlights` + `style`; additive backfill of `ActivityReadBlock.selections[]` → rows; endpoint family generalised off "exegesis" with aliases; **the prerequisite merge data-loss fix** | [04-server.md](04-server.md) |
| client | ✅ | member lesson player (`read-step`, `exegesis-step`, `use-lesson-state`) + LeaderApp panes/stores read `highlights[]`; saved-highlight colour → lime | [05-client.md](05-client.md) |
| iphone | ✅ | new `Services/Highlighting/` (5 layers); Read + Exegesis editors adopt fully; Bible reader adopts the interaction layers; 8 Action methods collapse behind `HighlightStore` | [06-iphone.md](06-iphone.md) |
| capture | ✅ | 5 existing fixtures re-captured — the rendering colour and the Read editor's selection visuals both change | [07-capture.md](07-capture.md) |

No ⬜ rows. Cross-checked against the root `.claude/CLAUDE.md` §Cross-App Impact Guide: this is a
"Database schema change" (→ server + both consumers) combined with a "Study/lesson content model"
change (→ client lesson player + iPhone lesson views). Both consumers are in scope, as that table
requires.

## The contract (who produces, who consumes)

| Contract | Producer | Consumers | Defined in |
|---|---|---|---|
| `GET /api/activities/:activityId/highlights` | server | iphone, client (LeaderApp via `/admin/api` proxy) | 03 §2 |
| `POST /api/activities/:activityId/highlights` | server | iphone | 03 §2 |
| `PATCH /api/activities/:activityId/highlights/:highlightId` | server | iphone | 03 §2 |
| `DELETE /api/activities/:activityId/highlights/:highlightId` | server | iphone | 03 §2 |
| the same four at `/api/scheduled-activities/:activityId/highlights…` | server | iphone (enrollment context) | 03 §2 |
| `…/exegesis-highlights` (legacy aliases) | server | **shipped iPhone builds** | 03 §2.1 |
| `ActivityReadBlock.selections[]` (now a derived projection) | server | **shipped iPhone builds**, member lesson player | 03 §3 |
| Normative highlight rules (snapping, colour, commit) | 03 | iphone service, future web authoring UI | 03 §5 |

## Cross-app sequencing

1. **Prerequisite** — reproduce and fix monday#12708759849 sub-issue A (notes erased by merge).
   No backfill runs until this is verified. See 04 §Prerequisite.
2. `03` contract settled + migrations planned.
3. **server** implements: schema change, additive backfill (dry-run → verified run), endpoints +
   aliases, projection maintenance. Verifies → **contract FROZEN**.
4. **client** and **iphone** build against the frozen contract, in parallel (they never import
   each other).
5. **capture** fixtures re-captured once both consumers render.
6. cross-app E2E + the human walk in 08.

The dependency in step 3→4 is real: both consumers change the *shape they read*, and iPhone's
disk cache persists that shape across launches.

## Backward compatibility

This is the highest-risk part of the feature, because build **374 is in testers' hands right now**
and reads the old shape.

- **Shipped iPhone builds read `ActivityReadBlock.selections`** for Read highlights and
  `GET …/exegesis-highlights` for Exegesis. Both keep working:
  - `selections` is **never dropped** (D3) and is regenerated from `highlights` rows by the
    existing projection mechanism, so an old build sees the same array it always did.
  - `…/exegesis-highlights` paths **alias** to the new endpoints for at least one release,
    returning the same field names an old build decodes.
- **The migration is additive.** Nothing is deleted: rows are created from existing spans, the
  source column is retained, and the backfill is idempotent and re-runnable.
- **Rollback** is pointing clients back at the old field/paths — no data restoration required,
  because nothing was removed.
- **`style` is additive.** Existing exegesis rows backfill to `style: "highlight"`; existing Read
  spans carry their `style` value across unchanged.
- **iPhone disk cache**: `AppState` persists entities to disk. A build that upgrades mid-session
  must not decode a cached old-shape payload into the new model — 06 specifies the cache
  invalidation.

## Blast radius (what else reads this data)

- **Member lesson player** — `client/resources/js/components/domain/lesson-island/steps/read-step.vue`,
  `exegesis-step.vue`, `use-lesson-state.ts`. This is member-facing production content: the colour
  change (D6) is visible to every member, not just leaders.
- **LeaderApp** — `islands/leader-app/components/edit-read-activity-pane.vue`,
  `edit-exegesis-activity-pane.vue`, `stores/activity-editor-actions.ts`,
  `leader-program.store.ts`, `leader-enrollment-schedule.store.ts`.
- **Server-side lesson copy / versioning** — `services/lesson-copy.ts`,
  `lesson-content-hash.ts`, `lesson-version-resolution.ts`, `enrollment-sync.ts` all touch read
  blocks. A content hash that includes `selections` will change when the projection is rebuilt —
  the audit must check whether that spuriously invalidates lesson versions.
- **Deletion cascade** — `programs.ts:2746` already deletes `contentHighlight` (was `exegesisHighlight`) rows for a block
  set; after convergence that path deletes *all* highlights including Read's. Verify it is still
  scoped correctly.
- **`SelectableLockedBlockView`** has two consumers (the Read editor and the capture
  `ViewRegistry`); **`ExegesisVerseView`** has three (editor, `ExegesisHighlightModal`,
  `ExegesisNoteEditorPage`) — only the editor enables native selection today.
- **`/compare` twins** are rendered by both the capture harness and production — additive-only
  (see the `compare-twins-index` memory before touching any twin).
