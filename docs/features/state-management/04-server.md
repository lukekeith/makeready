# 04 — Server

**Not affected** — nothing in this feature touches `server/`.

The feature is a client-side ownership change: data the iPhone app already fetches through existing
Actions moves from private `@State` collections into `AppState`. No route module, service,
middleware, zod schema, Prisma model, migration, permission check, or external integration changes.

Stated as an explicit non-goal in [README.md](README.md) § Non-goals ("Server-side changes —
nothing in this spec touches `server/`") and carried into
[02-app-impact.md](02-app-impact.md)'s scope table.

**What the audit should check:** that none of the Phase-B Actions need a server change to be
correct — specifically that `loadAllTags` / `loadGroupLeaders` return the *complete* collection the
new `AppState` properties will claim to hold, rather than a filtered or paginated slice that only
happened to be sufficient for `MainLibrary`'s single consumer. A mismatch there would put a server
task back in scope and become a `G#` row.
