# Client (web)

In scope, but as a **consumer only** (D7): the web reads the converged shape and adopts the new
colour. This feature builds **no new** highlight-authoring module for the web.

> **Corrected 2026-08-04 (09 §G-v) — the web is not authoring-free, and this doc said it was.**
> The original wording ("the LeaderApp's authoring stays deferred and implements 03 §5's normative
> rules when it is built") is wrong: the LeaderApp shipped highlight authoring during the parity
> project. The read pane has highlight mode + the `.stylePicker` route + `applyStyle`
> (`edit-read-activity-pane.vue`); the exegesis pane creates highlights from a native selection,
> edits their notes and deletes them (`edit-exegesis-activity-pane.vue`). So 03 §5's normative
> rules bind the web **now**, not later — and checking that they actually held is what found
> **09 §X-o**, a fourth word-snapper that disagreed with the contract. What stays deferred is
> only *new* authoring surface; what already exists is held to the contract.

## Member lesson player — the member-facing risk

| File | Change |
|---|---|
| `resources/js/components/domain/lesson-island/use-lesson-state.ts` | consume `highlights[]` from the activity payload; keep tolerating `selections[]` for a release |
| `resources/js/components/domain/lesson-island/steps/read-step.vue` | render spans from `highlights` (each row carries its own `readBlockId`, so a multi-block READ activity resolves correctly); saved wash → `#F4FF76 @0.35` |
| `resources/js/components/domain/lesson-island/steps/exegesis-step.vue` | same, plus notes continue to render from `noteMarkdown` |

> ⚠️ **Members see this.** The saved-highlight colour changes from brand purple to lime on deploy
> for content that already exists. That is a live visual change to published lessons, not a
> leader-only change — call it out at sign-off.

Both steps must keep rendering correctly for an activity whose highlights arrive **before** M3 has
run (still only in `selections[]`) and after (in `highlights[]`). Tolerating both for one release
is what makes the rollout order safe.

## LeaderApp

| File | Change |
|---|---|
| `islands/leader-app/stores/activity-editor-actions.ts` | point read/exegesis selection reads at `highlights[]`; keep the write path unchanged (authoring is still deferred) |
| `islands/leader-app/stores/leader-program.store.ts` · `leader-enrollment-schedule.store.ts` | carry `highlights[]` on the activity entities |
| `islands/leader-app/components/edit-read-activity-pane.vue` | render saved highlights from `highlights[]` in the new colour. Its header comment already records that highlighter/selection styling is **DEFERRED** — that stays true |
| `islands/leader-app/components/edit-exegesis-activity-pane.vue` | same |

Proxy: these go through the existing `/admin/api/{path}` proxy — no new proxy entries, since the
paths live under the already-proxied `/api/activities/…` family. Confirm during the build rather
than assuming.

## Component coverage

No new components. Every view already renders highlight spans; only the data source and the colour
token change. The colour belongs in the design tokens rather than inline in either step component —
verify where the current purple is defined before adding a token, and run the tokenization guard.

## Tests

- `read-step` and `exegesis-step` render identical spans from `highlights[]` and from legacy
  `selections[]` (the dual-read window)
- a READ activity with multiple locked blocks renders each block's highlights against the right
  block
- an activity with zero highlights renders no wash and no empty artifacts
- Laravel feature tests for any controller/proxy touchpoint that changes

## Gates

```
cd client && npm run build          # also required before any capture
cd client && npm run guard          # design-token compliance
cd client && ./vendor/bin/phpunit
```
