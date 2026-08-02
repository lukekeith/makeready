# 05 — Client (web)

**Not affected** — the web client was audited on 2026-08-01 and is **conformant with the rule**. It
is a second working exemplar, not a target.

## The evidence

| Claim | Evidence | Status |
|---|---|---|
| The LeaderApp holds server data in stores, not components | **14 files** in `client/resources/js/islands/leader-app/stores/` — 13 Pinia stores + `activity-editor-actions.ts` (a factory seam, not a store) | **verified in code (2026-08-01)** |
| Nothing in the LeaderApp fetches outside those stores | A `fetch(` / `axios` / `XMLHttpRequest` sweep over **all 44 `.vue` files** returns exactly two hits, neither a data fetch: `leader-app.vue:7,54` imports axios only to set a default `X-CSRF-TOKEN` header, and `share-invite-sheet.vue:69` is `fetch(dataUrl)` converting a data URL to a blob | **verified in code (2026-08-01)** |
| Views delegate rather than fetch | The three `admin/api` hits in `views/` (`dashboard-view.vue:5`, `groups-view.vue:8`, `library-view.vue:12`) are **comments** describing the data path, not calls | **verified in code (2026-08-01)** |

> **Correction (2026-08-01, integrity check).** The original claim was "zero of 31 components" —
> that number is exactly the `components/` subdirectory and silently **excluded `views/` (6) and
> `overlay/` (6)**, i.e. it audited 31 of 44 `.vue` files, and the unaudited `views/` are the ones
> that mention the proxy path. Re-swept across all 44: the conclusion holds, but it now rests on
> the full denominator, and the axios import (previously unmentioned) is accounted for.

## Component coverage

**N/A** — no view is added, removed, or restyled on the web.

## If the web later drifts

The same rule applies with "Pinia store" substituted for "AppState": any server-derived collection
more than one component reads, or any component mutates, lives in a store; a mutation that changes
data another component derives from refreshes that derived state in the same call. That would be a
new feature suite, not an amendment to this one.

**What the audit should check:** re-run both greps rather than trusting this page. The counts (14
stores, 31 components, one non-networking `fetch`) are a 2026-08-01 snapshot of a codebase under
active parity work, and a wrong "not affected" claim is exactly what `X#` rows exist to catch.
