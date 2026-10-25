# Local fixtures

A resettable fixture world for walking UI 2.0 screens locally (SPEC:
`docs/features/ui2-fixtures/SPEC.md`). One org, **MakeReady Fixtures**, owned by
**Fixture Leader** (`fixtures@makeready.local`). Your own local org and data are never read
or touched: reset deletes only rows under the fixed IDs below.

## Run it

```bash
docker exec makeready-server npm run fixtures:reset            # wipe + seed, scenario full
docker exec makeready-server npm run fixtures:reset -- empty   # base world only, Home zeroed
docker exec makeready-server npm run fixtures:seed             # seed only; fails if the fixture user exists
```

From the host (the agent walk env does this): `cd server && NODE_ENV=development
DATABASE_URL=postgresql://postgres:postgres@localhost:5434/<db> DIRECT_URL=<same> npm run fixtures:reset`.

The container mounts `server/fixtures/` and `server/package.json` (root `docker-compose.yml`).
After this feature first lands, run `docker compose up -d --build server` once; after that, layer
edits need no restart. A change to `package.json` dependencies still needs that rebuild.

It refuses (exit 1) unless `NODE_ENV` is `development` or `test` **and** `DATABASE_URL` (and
`DIRECT_URL`, when set) points at `postgres`, `localhost` or `127.0.0.1`. It also exits 1 on an
unknown scenario (listing the available ones), when the fixture user already exists under
`fixtures:seed`, and when the analytics refresh never ran. On success it prints row counts per table.

Then, in an iPhone dev build on Local: Profile → Local identity → **Fixtures**.

## Scenarios

`full` (default) runs `base.ts` and every screen layer's `full`. `empty` runs `base.ts` only. A
screen adds `sparse` / `extreme` exports when its spec lists those states; the runner offers a
scenario as soon as one layer implements it.

### What `full` makes non-empty on Home

`screens/home-dashboard.ts` (home-dashboard-data D1, D12, D17): Overview (~700 completions, the
current 24 days above the previous 24), Activity's scheduled and completed columns, every day card
for the past 7 days (5–40 min sittings in morning, midday and evening bands; today's only after
~07:15 Chicago), Sessions for every range, Engagement (10 of 24 members caught up → 42%, the rest
1–5 lessons behind) and Following (the fixture user's `dashboard.followedEnrollments` preference =
enrollments 2–4, two programs). The preference row cascades with the fixture user.

## Layers

`index.ts` → `base.ts` → every file in `screens/`, in filename order, all sharing one
`FixtureContext`. A screen layer **reads** base entities from `ctx.created` and must not create
orgs, users or groups of its own. Every row it creates takes a fixed ID. A layer must not run code
at import time: the runner loads every layer before the guard runs, so only its exported scenario
functions may touch the database.

## FixtureContext

| Member | What it is |
|---|---|
| `ctx.now` | the run's `Date`; every timestamp derives from it |
| `ctx.today` | `now`'s America/Chicago date, `YYYY-MM-DD` |
| `ctx.prisma` | the generated Prisma client |
| `ctx.ids` | the base fixed IDs (`user`, `org`, `groups`, `members`, `programs`, `enrollments`) |
| `ctx.rand` | seeded PRNG — `next()`, `int(min, max)`, `shuffle(items)`; same sequence every reset |
| `ctx.created` | what base made: `user`, `org`, `groups`, `members`, `groupMembers`, `programs`, `lessons`, `activities`, `enrollments`, `schedules` |
| `ctx.daysAgo(n)` | Chicago noon `n` days ago (negative = future) |
| `ctx.atLocalHour(date, h)` | wall-clock hour `h` (fractional ok) on `date`'s Chicago day |
| `ctx.dateOf(offset)` | Chicago date `offset` days from today |
| `ctx.at(offset, h)` | wall-clock hour `h` on that day |

**Dates come from `ctx.now`, never literals** — literal dates age out of every window. Put
activity in the 07:00–21:00 Chicago band so it lands on the same calendar day on any US device.

## Fixed IDs

`fixtureId(kind, n)` in `ids.ts` → `f1f1f1f1-<kind>-4000-8000-<n as 12 hex>`. Kinds: `0001` user,
`0002` org, `0003` groups, `0004` members, `0005` programs, `0006` lessons, `0007` activities,
`0008` enrollments, `0009` schedules, `000a` lesson progress, `000b` video progress, `000c`
membership events, `000d` client events, `000e` user roles, `000f` group members, `0010` member
orgs, `0011` user preferences. A new kind gets the next free code. Rows that hang off a fixture
member, group, program or the fixture user are deleted by reset's cascade; anything else needs a
line in `wipe.ts`.

## A new screen layer

Every feature that wires a UI 2.0 screen into the iPhone app adds `screens/<screen-id>.ts` (the id
as in `docs/ui2/screens/`), whose `full` makes every section it wires non-empty:

```ts
/** <screen-id> layer: what this screen reads, and which section each block fills. */
import type { FixtureContext } from '../context.js'
import { FIXTURE_ORG_ID, fixtureId } from '../ids.js'

export async function full(ctx: FixtureContext): Promise<void> {
  const { prisma, created } = ctx
  // Read base entities from ctx.created; never create orgs, users or groups (D2).
  const members = created.members.slice(0, 5)
  // One fixed-ID row per thing the screen renders, dated from ctx — never a literal date.
  await prisma.clientEvent.createMany({
    data: members.map((member, i) => ({
      id: fixtureId('clientEvent', 100_000 + i), // clear of other layers' n ranges, or add a kind
      eventType: 'LESSON_OPENED',
      occurredAt: ctx.at(-(i + 1), 9),
      memberId: member.id,
      organizationId: FIXTURE_ORG_ID,
    })),
  })
}
// A screen whose spec lists sparse / extreme states also exports `sparse` / `extreme`.
```

Run `cd server && npx tsc --noEmit -p fixtures` and `npm run fixtures:reset`; add a test under
`__tests__/` for the numbers the screen's spec promises.

## Host notes

`server/bin/atlas` is absent in git worktrees; use a global `atlas`. `npm run db:seed` and
`migrate:*` go through dotenv and read `server/.env`.
