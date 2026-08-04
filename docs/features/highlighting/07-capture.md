# Capture

**In scope.** Both the saved-highlight colour (D6) and the Read editor's selection visuals change,
so every fixture that renders a highlight produces a different screenshot and must be re-captured
with the new baseline reviewed rather than rubber-stamped.

## Affected fixtures

| Fixture | Kind | Why it changes |
|---|---|---|
| `capture/fixtures/compare/content/SelectableLockedBlockView.json` | component | Read block rendering — saved spans go purple → lime |
| `capture/fixtures/compare/content/ExegesisVerseView.json` | component | already lime at 0.35; verify unchanged, which is the useful signal |
| `capture/fixtures/compare/library/edit-read-activity.json` | page | the editor with highlighted blocks |
| `capture/fixtures/compare/library/edit-exegesis-activity.json` | page | same |
| `capture/fixtures/compare/overlays/exegesis-highlight-menu.json` | overlay | menu over a highlighted span |

Plus the iPhone-only fixtures under `capture/fixtures/iphone/create-read-activity/` (notably
`03-styled-blocks.json`, which exists precisely to exercise styled spans) and
`create-exegesis-activity/`.

## ViewRegistry

`iphone/MakeReadyCaptureTests/ViewRegistry.swift` has cases at `:2050`
(`component.ExegesisVerseView`) and `:2069` (`component.SelectableLockedBlockView`). If 06 replaces
those views rather than wrapping them, both cases and `CaptureFixture.swift`'s field list must be
updated in the same task — a capture target that no longer compiles blocks the whole harness.

Neither case can currently express an **in-progress selection** (both pass `.constant(nil)`), so
the live-drag wash is not capturable today. A new fixture variant seeding a live range would make
the "live vs saved" colour pair verifiable — worth adding, since that pair is now a contract value
(03 §5).

## Rules

- **Additive-only for twins.** New props default to the captured rendering; existing markup and
  class names are never altered (see the `compare-twins-index` memory before touching any twin).
- Web captures go through the **host** artisan on `:8002` with `CAPTURE_BASE_URL` — never docker
  `:8001`, which advertises a stale LAN origin and yields silently blank shots
  (memory: `capture-web-host-8002`).
- **Rebuild the client bundle before capturing** — `/compare` web captures hit the built bundle
  (memory: `capture-client-served-from-build`).
- Restart the capture server after editing adapters (memory: `compare-adapter-server-reload`).

## Gates

```
curl -s localhost:5950/api/compare/manifest        # capture server up
node capture/runners/compare/diff.mjs …            # advisory pixel diff
```

Expected diffs are **not** failures here — the colour change is intended. Each re-capture is
reviewed and accepted deliberately, and any diff that is *not* explained by the colour change is a
finding.
