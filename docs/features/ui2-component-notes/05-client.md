# 05 — Client

**Not affected.**

The Laravel + Vue web app (`client/`) has no part in this feature.

Nothing in `client/` reads `docs/ui2`, and the UI 2.0 era of the components browser renders
frozen Figma PNGs rather than live web twins — so the `/compare` hidden-twin iframe path (the
one client-adjacent mechanism in the capture tool) is not on this feature's route at all. No
Blade page, Vue island, Pinia store, SCSS partial, or `/admin/api` proxy entry changes.

Verified 2026-09-11 against [02-app-impact.md](02-app-impact.md) §Scope per app.
