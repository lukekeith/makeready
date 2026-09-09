# UI 2.0 Migration & Cutover (DECISIONS.md D2 mechanics)

**Strategy: parallel shell, hard cutover.** UI 2.0 is built as its own screen tree inside
the same iPhone app target, behind a flag. Legacy stays untouched and shippable for the
whole build; when 2.0 is complete and verified, the flag flips and the legacy tree is
removed. No mixed-UI period, no legacy elements inside 2.0 screens, no 2.0 elements leaking
into legacy.

This doc records the isolation rules the build suites must obey. It is designed now so the
`ui2-shell` suite can operationalize it without re-deciding anything; the exact flag/namespace
implementation details are settled in that suite's draft.

## Isolation rules (binding on every build suite)

1. **The flag.** One boolean gate (build-time or remote — decided in the `ui2-shell` suite
   draft) selects which shell mounts at app root. Default stays legacy until cutover.
2. **Distinct namespaces.** UI 2.0 screens live in their own directory tree (e.g.
   `iphone/MakeReady/UI2/…` — final path decided in `ui2-shell`), with their own route
   namespace and their own navigation shell/coordinator. Legacy `Services/Route.swift`,
   `NavigationCoordinator`, and `Pages/` are **never edited** by a UI 2.0 suite.
3. **Shared foundations stay shared.** `AppState`, Actions, services, and the server API are
   shared — UI 2.0 changes them only through its build-spec suites' server/contract phases,
   additively where a shipped legacy build still consumes them (build-spec audit Phase A
   backward-compat rules apply as normal).
4. **Design-system isolation.** 2.0 tokens/components are generated from
   `design-system/tokens.md` + `registry.md` into the 2.0 namespace. Legacy `Colors.swift` /
   `Typography.swift` are not modified; a registry `existing` row consumes a legacy component
   as-is, an `existing-modified` row **copies** it into the 2.0 namespace and modifies the
   copy (never the original — modifying in place would leak into legacy).
5. **Web member runtime.** The new member lesson UI is new web surface area (the legacy web
   lesson player keeps running until cutover); the same flag discipline applies to any shared
   entry points, per the activities suite's feature-flag open question — resolved in the
   `activities-player-web` suite draft.

## Cutover criteria (checklist — the `ui2-cutover` suite's precondition)

- [ ] Every README screen row is ✅ `verified`
- [ ] `gap-analysis.md` shows zero open `GAP-###`
- [ ] All build suites in the README Build program table are signed off (build-spec human sign-off)
- [ ] Soak period with the flag on for internal/TestFlight users — duration decided at the time, recorded here
- [ ] Data written by 2.0 verified readable by nothing legacy-only (no orphaned consumers)

## Cutover execution (the `ui2-cutover` suite)

Flag default flips → release → legacy tree removal (Pages/, legacy routes, dead components,
legacy web player) as a follow-up phase in the same suite, with the removal list generated
from the gap-analysis "carried/merged/dropped" tables → final cross-app E2E.
