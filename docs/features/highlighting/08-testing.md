# Testing

## Server

| Area | Tests |
|---|---|
| Merge (the prerequisite guard) | overlap absorbs + unions the span · **notes concatenated in document order** · earliest `orderNumber` kept · `absorbedIds` returned · differing styles → incoming wins |
| Multi-block READ | GET on an activity with three locked blocks returns all three blocks' highlights + `blockIds.length == 3` |
| Type gate | READ ✅ · EXEGESIS ✅ · VIDEO/YOUTUBE/USER_INPUT → 400 |
| Legacy aliases | `…/exegesis-highlights` returns byte-identical fields to today for an EXEGESIS activity |
| PATCH | `style` only · `noteMarkdown` only · both · neither → 400 · foreign highlight → 404 |
| Authorization | non-org user → 404 on every route · org leader who is not the creator behaves exactly as before (no widening) |
| Projection | after every mutation `selections[]` == rows' `(start,end,style)` in `orderNumber` order |
| **Backfill** | dry-run mutates nothing · second run is a no-op · every pre-run span exists as a row · projection set-equal to pre-run `selections[]` · `selections` untouched on disk · overlapping spans copied without merging |
| Content hash | rebuilding the projection does **not** change a lesson's content hash / trigger `enrollment-sync` |

## Client

- `read-step` / `exegesis-step` render identical spans from `highlights[]` and from legacy
  `selections[]` (the dual-read window)
- multi-block READ activity maps each highlight to its own block
- zero highlights → no wash, no artifacts
- design-token guard passes with the lime token

## iPhone

- **Snapping unit tests** — the case today's three copies disagree on: `"Lord's"` selected mid-word
  snaps to the whole word including the apostrophe; a selection ending at a verse-terminating
  newline does not walk into the next verse; grow-only (never trims the user's range)
- **Granularity** — `.verse` returns whole-verse ranges; `.word` returns word ranges; the same
  controller drives both
- **Commit lifecycle** — a selection with the finger still down does not commit after any elapsed
  time; a cancelled touch does not commit; release commits exactly once; a re-touch during the
  post-release hop abandons the commit
- **Store** — create/update/delete round-trip through both program and enrollment providers;
  `AppState` reflects the mutation without a manual refetch; `clearInMemory()` clears highlights
- **Note keying** — a note survives a merge that changes the highlight's span (the
  monday#12708759849 sub-issue A regression guard)
- Disk cache: an old-shape cached payload degrades rather than crashing the decode

## Capture

Re-capture the five compare fixtures plus the iPhone-only read/exegesis fixtures; review each diff
and accept only those explained by the colour change (07).

## Gates (run fresh, record output)

```
# server
cd server && npx tsc --noEmit && npm run lint && npm run test:run
cd server && npm run schema:validate && npm run schema:diff && npm run migrate:status
docker restart makeready-server

# client
cd client && npm run build && npm run guard && ./vendor/bin/phpunit

# iphone
npm run ios:build-check
cd iphone && swiftlint

# capture
curl -s localhost:5950/api/compare/manifest
```

## Cross-app E2E walk

Against the local stack (`/dev-start`):

1. iPhone, Read activity → highlight a verse → it renders lime.
2. Same activity in the **web LeaderApp** pane → the same span, same colour.
3. Enrol a member → open the lesson in the **member player** → the same span, same colour.
4. iPhone, Exegesis activity → highlight a phrase, add a note → member player shows the note.
5. Highlight across two existing noted highlights → **both notes survive** in the merged result
   (the sub-issue A guard, end to end).
6. Kill and relaunch the iPhone app → highlights survive the disk cache round-trip.
7. Point a **build-374 simulator build** at the same server → its Read highlights still render
   from the retained `selections` projection (the backward-compatibility proof).

## Human-verification script (sign-off)

Hand over the app and ask for exactly this — newest and least-exercised first:

1. **Exegesis, drag and hold.** Long-press into a passage, drag, then **hold still for several
   seconds**. Nothing should lock in. Release — *now* it commits, snapped to whole words.
2. **Read, verse tap.** Tap a verse, extend to another, tap inside to style it. Unchanged from
   today, but now driven by the shared controller.
3. **Bible reader.** Select a passage — the gesture should feel identical to Exegesis, and the
   result should still be a passage reference, not a highlight.
4. **Merge with notes.** Two noted exegesis highlights, then one highlight across both. **Both
   notes must survive.**
5. **The colour change.** Confirm the new lime on an existing, already-published lesson — as a
   member, in the web player. This is the change real members will notice.
6. **Old build.** If a build-374 device is still available, confirm its Read highlights are intact.

Local facts they'd otherwise rediscover: web client on `:8001` (docker) or `:8002` (host, needed
for captures), server on `:3010`, `docker restart makeready-server` after server edits.
