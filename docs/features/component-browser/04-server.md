# 04 — Server

**Not affected** — the production Express server (`/server`, :3010) plays no part in this
feature. The only backend involved is the capture tool's own Express (`capture/server.mjs`,
:5951), owned by `07-capture.md`. No production schema, endpoint, service, RBAC, or
integration changes.
