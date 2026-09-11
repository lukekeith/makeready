# 06 — iPhone

**Not affected.**

The iOS app (`iphone/`) has no build-time change in this feature.

Two things are easy to mistake for iPhone scope, and both are deliberate exclusions:

1. **`iphone/MakeReady/UI2Preview/` is edited at command runtime, not by this feature.**
   `/ui2-component-build` already writes preview views there, and the new
   `/ui2-component-update` ([07-capture.md](07-capture.md) §7.2) edits them to close gaps
   against spec + notes. That is those commands doing their job on the owner's content — the
   same way `/ui2-resolve` already edits preview views today. Building *this* feature adds no
   Swift.

2. **The XCTest element-map harness is untouched.** It emits `.elements.json` beside a built
   component render, and this feature adds `.elements.json` beside a **screen snapshot** — same
   file shape ([03-data-and-api.md](03-data-and-api.md) §1.2), different producer. A screen's
   map comes from Figma metadata at spec time, never from the simulator; no screen is ever
   rendered in the simulator.

No `AppState` entity, Action, `Route` case, page, component, push payload, or disk-cache
behavior changes.
