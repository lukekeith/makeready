# 04 — Server

**Not affected.**

The production Express API (`server/`) has no part in this feature. Nothing here reads or
writes a production model, route, service, middleware, or external integration, and no Prisma
migration is involved.

The word "server" in this suite always means **`capture/server.mjs`** — the capture dev tool's
own Express process on port 5951, with its own Postgres (`makeready_capture`) and its own
route namespace. Its changes are specified in [07-capture.md](07-capture.md) §3.

Verified 2026-09-11: the feature's entire data surface is the repo filesystem under
`docs/ui2/` plus four capture-local HTTP routes ([03-data-and-api.md](03-data-and-api.md) §2).
