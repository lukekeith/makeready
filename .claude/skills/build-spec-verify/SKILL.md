---
name: build-spec-verify
description: The final gate of the /build-spec pipeline — verifies a built MakeReady feature against its suite and issues a READY / INCOMPLETE verdict with evidence. Re-runs every affected app's quality gates fresh, confirms consumer parity against the frozen API contract, sweeps for pattern regressions per app, confirms every phase doc is VERIFIED and every 08-testing requirement satisfied, and walks the cross-app E2E flow. READY is agent evidence, not the user's sign-off — it ends by handing the app to the human to test. Use when the user asks to verify a built feature or check whether a feature is done.
---

# /build-spec-verify <feature> — is it actually done?

Read the ledger + the full suite (`docs/features/<feature>/`). This step trusts nothing remembered
from the build — including the phase docs' own sign-offs: every check below is executed fresh,
evidence in hand. Conventions in [`build-spec/REFERENCE.md`](../build-spec/REFERENCE.md).

## The checklist (all must hold for READY)

1. **Phases complete** — every phase doc's VERIFIED block signed and dated; README Phase status
   all ✅; no unchecked task rows anywhere.
2. **Gates green NOW** — run the full suite for every in-scope app (REFERENCE.md §7), fresh, and
   record outputs: server typecheck + lint + vitest (+ `schema:validate` and `migrate:status` if
   schema changed), client `build` + `guard` + phpunit, iPhone `ios:build-check` + swiftlint,
   capture diffs. An app in 02's scope table with no gate output is an INCOMPLETE item.
3. **Contract integrity** — 03 is frozen; every amendment since the freeze has an `X#` row and a
   re-verified server phase. Then diff the consumers against it: every field `05` and `06` consume
   exists in 03's response table with the same name and type, traced in the shipped code
   (`opus` judgment, not grep). Any drift = INCOMPLETE.
4. **Consumer parity** — where both client and iPhone implement the same capability, they hit the
   same endpoints and show the same data. Divergence must trace to a recorded `D#`.
5. **No unverified claims** — grep the suite for `(claimed — unverified)`: zero hits.
6. **No open ledger rows** — 09's G/D/O/C/X tables have no OPEN entries.
7. **No pattern regressions** — sweep the feature's new code per app: server (no logic in route
   modules, RBAC checked in services, zod not stripping consumer fields, no creator-only
   authorization where org leaders must reach it); client (no component-level fetching, no
   hardcoded design values — `npm run guard`, proxy entries present); iPhone (no `APIClient` in
   Pages/Components, no `.sheet`/`.fullScreenCover`/`asyncAfter` choreography, shared server-derived
   collections in `AppState` with mutations refreshing derived state); capture (twins additive-only).
8. **Migrations applied locally** and idempotent (re-apply is a no-op); seed unaffected; the
   rollout order in 02 still holds against what actually shipped.
9. **08-testing satisfied row by row** — each required test exists and passes, in the right app.
10. **Cross-app E2E walked** — 08's flow executed live against the local stack (`/dev-start`; the
    server container restarted after the last `server/src` edit). If the stack cannot be brought
    up, the verdict is BLOCKED-on-environment, never READY.

## The verdict

Write a dated verdict block into the README (below the snapshot tables) — `**GATE: READY (date)**`
or `**GATE: INCOMPLETE**` with the numbered failing items and, for each, the step that clears it
(a phase-doc task, a 09 row, an environment fix). Update the ledger.

INCOMPLETE is a normal outcome, not a failure — the orchestrator loops the blocking list back to
the right step.

## After READY — hand the app to the human (this step is not finished at READY)

READY means the agents verified it. It does not mean anyone has used it. Do not describe the
feature as done or shipped yet. Present the **human-verification script** from 08:

- the exact URL(s) and simulator screen(s), what to tap, what to look for — newest and
  least-exercised surfaces first;
- the local facts they'd otherwise rediscover (which port, which seeded org/user, where SMS codes
  come from, which surfaces genuinely can't work locally);
- a plain statement of what has and hasn't been human-tested.

Then stop. On an explicit affirmative that the feature works, record their words in the ledger's
sign-off row, flip the README status line to `Shipped-ready (date)`, and only then point at
`/deploy` — always the user's explicit command, never run from the pipeline. Offer a final docs
commit if the suite has uncommitted changes.

## Exit handoff (standalone runs too)

End every run with the standard handoff (`build-spec` §Step-end handoff): the verdict + its
evidence in plain language, the blocking list (if any) as file+edit+command rows, and ALWAYS the
two-line status block as the last thing in the response (REFERENCE.md §6):

```
📊 <feature> ~98% ▓▓▓▓▓▓▓▓▓▓ — verify: READY, all gates green
📍 Nothing to run — test it yourself (script above), then tell me and I'll commit + push
```
