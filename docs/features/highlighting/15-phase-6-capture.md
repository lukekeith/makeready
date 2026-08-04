# Phase 6 — Compare fixtures  ·  app: capture

> Part of docs/features/highlighting/. Preconditions: **Phase 4 and Phase 5 both VERIFIED** — the
> harness captures what both consumers actually render, so it cannot run before they render it.

## Goal

Every fixture that shows a highlight is re-captured against the new colour and the new Read
selection visuals, each diff reviewed and accepted deliberately. Any diff **not** explained by the
colour change is a finding, not a rubber stamp.

## Companion skills

`/capture-start` to bring the stack up · `/compare-adjust` per comparison if a twin needs work ·
read the `compare-twins-index` memory before touching **any** twin.

## Tasks

- [ ] 6.1 Rebuild the client bundle — `/compare` web captures hit the **built** bundle, not the dev
      server · gate: `cd client && npm run build`
- [ ] 6.2 Re-capture `compare/content/SelectableLockedBlockView.json` — Read block spans go purple
      → lime · spec: 07
- [ ] 6.3 Re-capture `compare/content/ExegesisVerseView.json` — already lime `@0.35`; **an
      unchanged screenshot is the useful signal here**
- [ ] 6.4 Re-capture `compare/library/edit-read-activity.json` and
      `compare/library/edit-exegesis-activity.json`
- [ ] 6.5 Re-capture `compare/overlays/exegesis-highlight-menu.json`
- [ ] 6.6 Re-capture the iPhone-only fixtures under `capture/fixtures/iphone/create-read-activity/`
      (notably `03-styled-blocks.json`, which exists to exercise styled spans) and
      `create-exegesis-activity/`
- [ ] 6.7 If Phase 4 changed either view's initializer, update the `ViewRegistry` cases
      (`iphone/MakeReadyCaptureTests/ViewRegistry.swift:2050`, `:2069`) and
      `CaptureFixture.swift` — a capture target that doesn't compile blocks the whole harness.
      *(Phase 4 wraps rather than replaces, so this should be a no-op — verify it is.)*
- [ ] 6.8 **New fixture variant: an in-progress selection.** Neither component case can express one
      today (both pass `.constant(nil)`), so the live-vs-saved colour pair — now a contract value
      (03 §5) — is not capturable. Add a variant that seeds a live range. · spec: 07 §ViewRegistry

## Phase gates

```
curl -s localhost:5950/api/compare/manifest        # capture server up
node capture/runners/compare/diff.mjs …            # advisory pixel diff
```

**Environment landmines** (both cost a silent failure):
- Web captures go through the **host** artisan on `:8002` with `CAPTURE_BASE_URL` — never docker
  `:8001`, which advertises a stale LAN origin and yields blank shots.
- Restart the capture server after editing any adapter.

## Verification checklist

- [ ] Every re-captured diff is either the expected colour change or investigated
- [ ] `ExegesisVerseView` is visually **unchanged** (it was already the target colour)
- [ ] The new live-selection variant captures a visible lime `@0.55` wash distinct from `@0.35`
- [ ] No twin's existing markup or class names were altered (additive-only)
- [ ] The iPhone capture target still compiles

## VERIFIED

*(unsigned)*
