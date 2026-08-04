# Phase 5 — Web consumers  ·  app: client

> Part of docs/features/highlighting/. Preconditions: **Phase 2 VERIFIED and 03 FROZEN.**
> Parallelizable with Phase 4 (iphone). Consumer-only: no authoring UI is built here (D7).

## Goal

The member lesson player and the LeaderApp panes read `highlights[]` and render the new colour,
while continuing to tolerate the legacy `selections[]` for one release. **Members see this** — it
is the only phase whose output is visible on already-published lessons.

## Companion skills

`/component` if a shared component genuinely needs changing (it should not — 05 says no new
components) · `/store` for Pinia store conventions.

## Tasks

- [ ] 5.1 `use-lesson-state.ts` — consume `highlights[]` from the activity payload; keep decoding
      `selections[]` when `highlights` is absent (the dual-read window)
      · files: `client/resources/js/components/domain/lesson-island/use-lesson-state.ts`
      · spec: 05 · tests: renders identically from either source
- [ ] 5.2 `read-step.vue` — render spans from `highlights`, resolving each to its block via
      `highlight.readBlockId` so a **multi-block** READ activity is correct. It already renders
      spans with offset remapping (`:160`, `:193-239`, `:217`) — extend, don't rewrite.
      · spec: 05, 03 §2.1 · tests: multi-block activity maps each highlight to the right block
- [ ] 5.3 `exegesis-step.vue` — same, plus notes continue rendering from `noteMarkdown`
- [ ] 5.4 Colour: saved highlight → `#F4FF76 @0.35`; `bold` → **weight only, no wash** (03 §5).
      Put the colour in a design token, not inline — find where today's purple is defined first.
      · gate: `npm run guard` must pass
- [ ] 5.5 ∥ LeaderApp stores carry `highlights[]` on the activity entities
      · files: `islands/leader-app/stores/activity-editor-actions.ts`,
        `leader-program.store.ts`, `leader-enrollment-schedule.store.ts`
- [ ] 5.6 ∥ `edit-read-activity-pane.vue` and `edit-exegesis-activity-pane.vue` render saved
      highlights from `highlights[]` in the new colour. **Authoring stays deferred** — the panes'
      existing "DEFERRED" comment remains true (D7)
- [ ] 5.7 Confirm the `/admin/api/{path}` proxy already covers these paths (they sit under the
      proxied `/api/activities/…` family) — verify, don't assume
- [ ] 5.8 Tests per 08 §Client

## Phase gates

```
cd client && npm run build      # also required before any capture
cd client && npm run guard      # design-token compliance
cd client && ./vendor/bin/phpunit
```

## Verification checklist

- [ ] A member opening a lesson sees the same spans as before, in lime
- [ ] A READ activity with several verse blocks renders each block's highlights against that block
- [ ] An activity with zero highlights renders no wash and no empty artifacts
- [ ] `bold` renders as weight with no background, matching 03 §5 and the iPhone rendering
- [ ] The dual-read window works: an activity whose payload still carries only `selections[]`
      renders identically
- [ ] Contract parity: fields consumed match 03's frozen table, same names — and match what Phase 4
      consumes (`/build-spec-verify` diffs 05 against 06 for this)
- [ ] Token guard green — the colour is a token, not a literal

## VERIFIED

*(unsigned)*
