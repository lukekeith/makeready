# Local fixtures

A resettable fixture world for walking UI 2.0 screens locally (SPEC:
`docs/features/ui2-fixtures/SPEC.md`). One org, **MakeReady Fixtures**, owned by
**Fixture Leader** (`fixtures@makeready.local`).
A second user, **Nathan Hughes** (`fixtures-leader@makeready.local`), holds the system Group Leader
role and created one group, **Prayer Team**. Your own local org and data are never read
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

`sparse` (ui2-members-edit T5) = base + `screens/shared-edit-field.ts`, the only layer that exports
it. That layer replays `members-home` and `members-profile` `full` (so the Group-Leader session
still lists the three Prayer Team members and Nathan Hughes reads "Group leader"), then nulls
`gender`, `birthday`, `address`, `emergencyContactName` and `emergencyContactPhone` on member 16
(`SPARSE_MEMBER_INDEX`, one of the Prayer Team three): the edit pages open on their "Not set" /
empty states. Home's dashboard layer does not run under `sparse`, so Home reads as empty.
`docker exec makeready-server npm run fixtures:reset -- sparse`.

### What `full` makes non-empty on Home

`screens/home-dashboard.ts` (home-dashboard-data D1, D12, D17): Overview (~700 completions, the
current 24 days above the previous 24), Activity's scheduled and completed columns, every day card
for the past 7 days (5–40 min sittings in morning, midday and evening bands; today's only after
~07:15 Chicago), Sessions for every range, Engagement (10 of 24 members caught up → 42%, the rest
1–5 lessons behind) and Following (the fixture user's `dashboard.followedEnrollments` preference =
enrollments 2–4, two programs). The preference row cascades with the fixture user.

**Six months of history** (owner ruling 2026-10-25): each group also has back-to-back past
enrollments of the two base programs (one lesson per day) from today−182 up to the day before its
earliest base enrollment (−48 / −29 / −20), so Activity's scheduled and completed columns and the
day cards have data on every day from today−182 through today. Caught-up members complete every
history lesson on its day (Engagement stays 10 of 24, 42%); the other 14 skip a fixed 10–25% of
them. History sittings are 5–40 min (a LESSON_OPENED, plus a resume open at the mid-point when
longer than 28 min so the session stays whole, and the completion) and carry **no video progress**,
so total video time stays exactly 40 h. Because group 1's and 2's history reaches into
Overview's previous 24-day window (−47…−24), that window now holds 547 completions (was 240) and
the 24-day trend is no longer positive. History ids: enrollments `enrollment` n 10…, schedules
`schedule` n = enrollment n × 1000 + day, progress/events `lessonProgress`/`clientEvent` n ≥ 1,000,000.

### What `full` makes non-empty on Members

`base.ts` + `screens/members-home.ts` + `screens/members-profile.ts` (ui2-members-browse D13, T7):
every member has an email (`first.last@example.org`), a birthday (ages 19–67), a gender, a
two-line city address and an emergency contact name and phone; 13 of 24 have a d2m avatar photo
when images are on (the set's avatars are all men, so 5 women carry one), the rest show initials.
The list leads with joins of today, yesterday, 4 days, 1 and 2 weeks and 40 days ago; James
Carter, Emily Price and Sarah Griffin are in two groups (their base group + Prayer Team). Nathan
Hughes (member 7) is linked to the Group-Leader user, so his Role reads "Group leader". Hannah Jenkins (member 10, no fixture avatar) is linked to a Google account whose picture is James Carter's placed avatar URL, so her avatar tap shows the Google-only menu (image-framing-editor D4); with images off her googlePicture is null.

Group-Leader session for the walk (the iPhone's Local identity offers only Fixtures):
`curl -s -X POST http://localhost:3010/auth/dev-login -H 'Content-Type: application/json' -d '{"email":"fixtures-leader@makeready.local"}'`
— it lists exactly the three Prayer Team members and gets 404 for anyone else.

### What `full` makes non-empty on Groups

`base.ts` + `screens/groups-home.ts` + `screens/groups-detail.ts` (ui2-groups-browse D19, D25): the
list shows five groups (Empty Group is base group 5 — no members, enrollments or history, for every
empty line). Tuesday Men's Group is the rich group: two pending join requests (Ruth Hamilton, Esther
Graham), today's and tomorrow's lesson each with a YouTube, a video and a READ thumbnail, and a
Timeline with every kind — requests (−1, −2 days), cover (−3), breakfast at Corner Bakery (−5), Sophia
Powell left (−6), settings (−10), joined (−20), base joins (−62…−59), created (−75). Its day rail is
base + home-dashboard: enrollment 1 (−48…−19) and 4 (−13…+7) leave −18…−14 at 0 lessons.

### What `full` makes non-empty on Enrollments

`screens/enrollments-home.ts` + `screens/enrollment-home.ts` (ui2-enrollments-browse D22): the list's
Active reads base enrollments 2–4 plus the Prayer Team's "Foundations of Faith" (enrollment 950,
−10…+10, invite 07:30, three members, thumbnails on days 1–3 — the detail walk); Upcoming reads the
Prayer Team's "Walking Through John" from +5 (enrollment 960); Completed reads base enrollment 1,
home-dashboard's history and groups-enroll-program's "Romans in 12 Days"; Draft reads two drafts —
Women's Bible Study + "Walking Through John" (group and program only, `Draft · 2/6`, started by
Fixture Leader) and Young Adults + "Foundations of Faith" (every row set, lesson dates from 3 days
ago, so the app's stale-start rule reads `Draft · 5/6`, started by Nathan Hughes). The Prayer Team
makes Nathan Hughes the second group creator in the Leaders filter. Neither layer adds member
progress; base enrollment 4's progress (home-dashboard) is spread over days.

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
orgs, `0011` user preferences, `0015` join requests, `0016` feed activities, `0017` events, `0018`
scheduled activities, `0019` videos, `001a` read blocks, `001b` enrollment drafts. A new kind gets the next free code. Rows that hang off a fixture
member, group, program or the fixture user are deleted by reset's cascade; anything else needs a
line in `wipe.ts`. The Group-Leader user is `user` n 2 and its group `group` n 4; the Empty Group is `group` n 5; the members-home
memberships are `groupMember` n 25–27. Reset deletes both users (`FIXTURE_USER_IDS`).

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

## Images (home-dashboard-data D22, fixture-real-uploads)

`fixtures:reset` seeds images as **real content**: the files go to the server's R2 bucket under the
keys a real upload uses, and the rows are shaped as that upload writes them — only the way they got
there differs.

| What | Stored as (the endpoint it mirrors) |
|---|---|
| 3 group covers, 2 program covers | `groups/group-<id>-<stamp>` / `programs/program-<id>-<stamp>` JPEG + WebP ladder; `coverImageUrl` = its R2 URL; a Media row "<name> - Cover Image" (source `auto_capture`) + its `GROUP_COVER`/`PROGRAM_COVER` usage (`POST /api/groups/:id/cover-image`, `/api/programs/:id/cover-image`) |
| 12 library photos | `library/library-<fixtureUserId>-<stamp>` ladder, Media row source `direct` (`POST /api/media`) |
| 13 member avatars | a 512px WebP at `avatars/members/<id>/<stamp>.webp` → `Member.profilePicture`, no Media row (`POST /api/members/:id/avatar`) |

`<stamp>` is a 13-digit number derived from the image's bytes, so a reset uploads only what the
bucket lacks, and a refreshed image gets a new key.

**Source.** The 30 originals live in `fixtures/images/` (≤1200px JPEGs + `manifest.json`: the
selection and each image's d2m title, alt and colour), committed — a reset never contacts d2m and
works in the container, on the host and in agent walks. `npm run fixtures:images:refresh` (on the
host, d2m running) re-pulls the selection from the d2m `makeready` image set; commit the result.

**Failure is loud.** Missing R2 settings (`R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`,
`R2_BUCKET_NAME`, `R2_PUBLIC_URL`), an upload error or a missing file fails the reset. It refuses the
production bucket (`makeready-media` / `images.makeready.org`). `FIXTURE_IMAGES=off` skips images on
purpose; images are off under vitest unless `FIXTURE_IMAGES=on`. The one exception: with **no** R2
setting at all — the agent walk env, which never sees `server/.env` — images are skipped with a
warning and the rest of the graph seeds; `FIXTURE_IMAGES=on` turns that back into a failure.
