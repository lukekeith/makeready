/**
 * Base layer (SPEC ui2-fixtures D3, D11, D12): the fixture owner, org, groups,
 * members, programs, enrollments and lesson schedules every screen layer
 * reads. Runs for every scenario, `empty` included. Every row has a fixed ID;
 * every date comes from ctx (D9). Every group's and program's creatorId is the
 * fixture user, so deleting that user cascades the graph (D7); the Group-Leader
 * user (ui2-members-browse T7) and its one group are deleted with it by reset (wipe.ts).
 */
import { FIXTURE_TZ, FixtureError, type ScenarioFn, addDays, weekdayOf } from './context.js'
import { seedImages } from './images.js'
import { textDocument, textObject, videoDocument, writeDocument } from './activity-documents.js'
import { type ScheduleSeed, publishProgramVersion, scheduleLessons } from './lesson-content.js'
import {
  FIXTURE_EMPTY_GROUP_ID,
  FIXTURE_ENROLLMENT_IDS,
  FIXTURE_GROUP_IDS,
  FIXTURE_LEADER_EMAIL,
  FIXTURE_LEADER_GROUP_ID,
  FIXTURE_LEADER_USER_ID,
  FIXTURE_MEMBER_IDS,
  FIXTURE_ORG2_ID,
  FIXTURE_ORG2_OWNER_EMAIL,
  FIXTURE_ORG2_OWNER_USER_ID,
  FIXTURE_ORG_ID,
  FIXTURE_PROGRAM_IDS,
  FIXTURE_USER_EMAIL,
  FIXTURE_USER_ID,
  fixtureId,
} from './ids.js'

export const FIXTURE_USER_NAME = 'Fixture Leader'
export const FIXTURE_ORG_NAME = 'MakeReady Fixtures'
/** ui2-members-browse T7: the Group-Leader fixture user — the same person as member 7 (members-profile links them, D8). */
export const FIXTURE_LEADER_NAME = 'Nathan Hughes'
export const FIXTURE_ORG2_OWNER_NAME = 'Grace Whitfield'
export const FIXTURE_ORG2_NAME = 'Northside Fellowship'
export const LEADER_GROUP_NAME = 'Prayer Team'
/** ui2-groups-browse D25: the group page's empty states. */
export const EMPTY_GROUP_NAME = 'Empty Group'
export const GROUP_NAMES = ["Tuesday Men's Group", 'Young Adults', "Women's Bible Study"] as const
export const MEMBERS_PER_GROUP = 8
export const ALL_DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'] as const
/** Weekdays only, Mon–Fri (home-dashboard-data D21: not every group meets every day). */
export const WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'] as const
/** Every lesson's VIDEO activity runs 20 minutes. */
export const VIDEO_SECONDS = 1200

const FIRST_NAMES = [
  'James', 'Michael', 'David', 'Daniel', 'Matthew', 'Andrew', 'Joshua', 'Nathan',
  'Emily', 'Grace', 'Hannah', 'Olivia', 'Sophia', 'Abigail', 'Chloe', 'Lydia',
  'Sarah', 'Rachel', 'Rebecca', 'Naomi', 'Ruth', 'Esther', 'Leah', 'Miriam',
]
const LAST_NAMES = [
  'Carter', 'Brooks', 'Hayes', 'Morgan', 'Reed', 'Foster', 'Bennett', 'Hughes',
  'Price', 'Coleman', 'Jenkins', 'Perry', 'Powell', 'Long', 'Patterson', 'Russell',
  'Griffin', 'Diaz', 'Myers', 'Ford', 'Hamilton', 'Graham', 'Sullivan', 'Wallace',
]

/** FIRST_NAMES 0–7 are men's names (Tuesday Men's Group), 8–23 women's. */
export const MALE_MEMBER_COUNT = 8
const STREETS = ['Maple Ave', 'Oak St', 'Cedar Ln', 'Elm St', 'Willow Dr', 'Birch Rd', 'Pine St', 'Lakeview Ave'] as const
const CITY_LINES = ['Chicago, IL 60614', 'Evanston, IL 60201', 'Oak Park, IL 60302', 'Naperville, IL 60540'] as const

/** D13: nominal age 20–66; when the birthday has not come yet this year the true age is one less, so 19–66. */
export const memberNominalAge = (i: number): number => 20 + ((i * 17) % 47)

/** ui2-members-browse D13: every fixture member's personal fields, derived from its index and ctx.today. */
export function memberProfile(i: number, today: string) {
  const last = LAST_NAMES[i]
  return {
    email: `${FIRST_NAMES[i]}.${last}@example.org`.toLowerCase(),
    birthday: new Date(Date.UTC(Number(today.slice(0, 4)) - memberNominalAge(i), (i * 5) % 12, 1 + ((i * 11) % 28), 12)),
    gender: (i < MALE_MEMBER_COUNT ? 'male' : 'female') as 'male' | 'female',
    address: `${100 + i * 37} ${STREETS[i % STREETS.length]}\n${CITY_LINES[i % CITY_LINES.length]}`,
    emergencyContactName: `${FIRST_NAMES[(i + 12) % FIRST_NAMES.length]} ${last}`,
    emergencyContactPhone: `+1555020${String(i + 1).padStart(4, '0')}`,
  }
}

export const PROGRAMS = [
  { key: 'days21', id: FIXTURE_PROGRAM_IDS.days21, index: 1, name: 'Foundations of Faith', days: 21 },
  { key: 'days30', id: FIXTURE_PROGRAM_IDS.days30, index: 2, name: 'Walking Through John', days: 30 },
] as const

const PROGRAM_BY_KEY = { days21: PROGRAMS[0], days30: PROGRAMS[1] }

/**
 * D11 stagger: day k of enrollment e is the k-th day on or after today + startOffset whose weekday
 * is in `days`. Daily enrollments run startOffset … startOffset + days − 1; Women's (D21) meets
 * Mon–Fri, so its 21 lessons reach about a week further.
 */
export const ENROLLMENT_PLAN = [
  { index: 1, groupIndex: 0, program: 'days30', startOffset: -48, days: ALL_DAYS }, // −48 … −19
  { index: 2, groupIndex: 1, program: 'days30', startOffset: -29, days: ALL_DAYS }, // −29 … 0
  { index: 3, groupIndex: 2, program: 'days21', startOffset: -20, days: WEEKDAYS }, // −20 … ~+8, weekdays
  { index: 4, groupIndex: 0, program: 'days21', startOffset: -13, days: ALL_DAYS }, // −13 … +7
] as const

/** Day offsets (from today) of `count` lessons from `startOffset`, on `days` only. */
export function lessonOffsets(
  today: string,
  startOffset: number,
  count: number,
  days: readonly string[]
): number[] {
  const out: number[] = []
  for (let o = startOffset; out.length < count; o++) {
    if (days.includes(ALL_DAYS[weekdayOf(addDays(today, o))])) out.push(o)
  }
  return out
}

export const lessonId = (programIndex: number, day: number) => fixtureId('lesson', programIndex * 1000 + day)
export const activityId = (programIndex: number, day: number, order: number) =>
  fixtureId('activity', (programIndex * 1000 + day) * 10 + order)
export const lessonVersionId = (programIndex: number, day: number) => fixtureId('lessonVersion', programIndex * 1000 + day)
export const programVersionId = (programIndex: number) => fixtureId('programVersion', programIndex)
/** The key of a base lesson's video activity (analytics recognises a watched video through it). */
export const videoActivityKey = (programIndex: number, day: number) => activityId(programIndex, day, 2)
export const scheduleId = (enrollmentIndex: number, day: number) => fixtureId('schedule', enrollmentIndex * 1000 + day)

const dayNumbers = (n: number) => Array.from({ length: n }, (_, i) => i + 1)

export const seedBase: ScenarioFn = async (ctx) => {
  const { prisma, created } = ctx

  // D12: the system Owner role is looked up, never created.
  const ownerRole = await prisma.role.findFirst({ where: { name: 'Owner', isSystem: true, organizationId: null } })
  if (!ownerRole) throw new FixtureError('the system Owner role is missing — run `npm run db:seed` first')
  const groupLeaderRole = await prisma.role.findFirst({ where: { name: 'Group Leader', isSystem: true, organizationId: null } })
  if (!groupLeaderRole) throw new FixtureError('the system Group Leader role is missing — run `npm run db:seed` first')
  const adminRole = await prisma.role.findFirst({ where: { name: 'Admin', isSystem: true, organizationId: null } })
  if (!adminRole) throw new FixtureError('the system Admin role is missing — run `npm run db:seed` first')

  const seededAt = ctx.daysAgo(75)
  created.user = await prisma.user.create({
    data: { id: FIXTURE_USER_ID, email: FIXTURE_USER_EMAIL, name: FIXTURE_USER_NAME, createdAt: seededAt },
  })
  created.org = await prisma.organization.create({
    data: { id: FIXTURE_ORG_ID, name: FIXTURE_ORG_NAME, ownerId: FIXTURE_USER_ID, createdAt: seededAt },
  })
  await prisma.userRole.create({
    data: {
      id: fixtureId('userRole', 1),
      userId: FIXTURE_USER_ID,
      roleId: ownerRole.id,
      organizationId: FIXTURE_ORG_ID,
      assignedAt: seededAt,
    },
  })
  // ui2-members-browse T7: a second leader with the system Group Leader role who created one
  // group, so a Group-Leader session sees only that group's members (D7). Base, not a screen
  // layer: screen layers may not create users or groups.
  await prisma.user.create({
    data: { id: FIXTURE_LEADER_USER_ID, email: FIXTURE_LEADER_EMAIL, name: FIXTURE_LEADER_NAME, createdAt: seededAt },
  })
  await prisma.userRole.create({
    data: {
      id: fixtureId('userRole', 2),
      userId: FIXTURE_LEADER_USER_ID,
      roleId: groupLeaderRole.id,
      organizationId: FIXTURE_ORG_ID,
      assignedAt: seededAt,
      assignedBy: FIXTURE_USER_ID,
    },
  })

  // media-library D20: a second org the fixture user administers (Source chip, Upload-to menu).
  await prisma.user.create({
    data: { id: FIXTURE_ORG2_OWNER_USER_ID, email: FIXTURE_ORG2_OWNER_EMAIL, name: FIXTURE_ORG2_OWNER_NAME, createdAt: seededAt },
  })
  await prisma.organization.create({
    data: { id: FIXTURE_ORG2_ID, name: FIXTURE_ORG2_NAME, ownerId: FIXTURE_ORG2_OWNER_USER_ID, createdAt: seededAt },
  })
  await prisma.userRole.create({
    data: {
      id: fixtureId('userRole', 3),
      userId: FIXTURE_USER_ID,
      roleId: adminRole.id,
      organizationId: FIXTURE_ORG2_ID,
      assignedAt: seededAt,
      assignedBy: FIXTURE_ORG2_OWNER_USER_ID,
    },
  })

  await prisma.group.createMany({
    data: GROUP_NAMES.map((name, i) => ({
      id: FIXTURE_GROUP_IDS[i],
      name,
      creatorId: FIXTURE_USER_ID,
      organizationId: FIXTURE_ORG_ID,
      createdAt: seededAt,
    })),
  })
  created.groups = await prisma.group.findMany({ where: { id: { in: FIXTURE_GROUP_IDS } }, orderBy: { id: 'asc' } })
  // Kept out of created.groups on purpose: home-dashboard walks the three base groups.
  // Its members are added by screens/members-home.ts.
  await prisma.group.create({
    data: {
      id: FIXTURE_LEADER_GROUP_ID,
      name: LEADER_GROUP_NAME,
      creatorId: FIXTURE_LEADER_USER_ID,
      organizationId: FIXTURE_ORG_ID,
      createdAt: seededAt,
    },
  })
  // ui2-groups-browse D25: no members, enrollments, schedules or history, so the group page shows
  // every designed empty line. Kept out of created.groups (like Prayer Team): no other layer sees it.
  await prisma.group.create({
    data: {
      id: FIXTURE_EMPTY_GROUP_ID,
      name: EMPTY_GROUP_NAME,
      creatorId: FIXTURE_USER_ID,
      organizationId: FIXTURE_ORG_ID,
      createdAt: seededAt,
    },
  })

  // Members join on −62 … −51, two a day, before the first schedule (−48).
  const joinedAt = (i: number) => ctx.at(-62 + Math.floor(i / 2), 10)
  await prisma.member.createMany({
    data: FIXTURE_MEMBER_IDS.map((id, i) => ({
      id,
      phoneNumber: `+1555010${String(i + 1).padStart(4, '0')}`,
      phoneVerified: true,
      firstName: FIRST_NAMES[i],
      lastName: LAST_NAMES[i],
      ...memberProfile(i, ctx.today),
      createdAt: joinedAt(i),
    })),
  })
  created.members = await prisma.member.findMany({ where: { id: { in: FIXTURE_MEMBER_IDS } }, orderBy: { id: 'asc' } })
  await prisma.groupMember.createMany({
    data: FIXTURE_MEMBER_IDS.map((memberId, i) => ({
      id: fixtureId('groupMember', i + 1),
      groupId: FIXTURE_GROUP_IDS[Math.floor(i / MEMBERS_PER_GROUP)],
      memberId,
      joinedAt: joinedAt(i),
    })),
  })
  created.groupMembers = await prisma.groupMember.findMany({
    where: { memberId: { in: FIXTURE_MEMBER_IDS } },
    orderBy: { id: 'asc' },
  })
  await prisma.memberOrganization.createMany({
    data: FIXTURE_MEMBER_IDS.map((memberId, i) => ({
      id: fixtureId('memberOrganization', i + 1),
      memberId,
      organizationId: FIXTURE_ORG_ID,
      joinedAt: joinedAt(i),
    })),
  })

  await prisma.studyProgram.createMany({
    data: PROGRAMS.map((p) => ({
      id: p.id,
      name: p.name,
      days: p.days,
      creatorId: FIXTURE_USER_ID,
      organizationId: FIXTURE_ORG_ID,
      isPublished: true,
      publishedAt: ctx.daysAgo(70),
      createdAt: seededAt,
    })),
  })
  await prisma.lesson.createMany({
    data: PROGRAMS.flatMap((p) => dayNumbers(p.days).map((day) => ({ id: lessonId(p.index, day), programId: p.id, position: day }))),
  })
  // Each lesson: one published version with a text page, a 20-minute video and a write prompt; each program: version 1.
  for (const p of PROGRAMS) {
    await publishProgramVersion(ctx, {
      programId: p.id,
      programVersionId: programVersionId(p.index),
      publishedAt: ctx.daysAgo(70),
      versions: dayNumbers(p.days).map((day) => ({
        id: lessonVersionId(p.index, day),
        lessonId: lessonId(p.index, day),
        number: 1,
        title: `Day ${day}`,
        estimatedSeconds: 1500,
        activities: [
          {
            id: fixtureId('contentActivity', (p.index * 1000 + day) * 10 + 1),
            activityKey: activityId(p.index, day, 1),
            kind: 'text',
            title: 'Read',
            document: textDocument([textObject({ id: 'o1', role: 'body', text: `Read John ${day} slowly, twice.` })]),
          },
          {
            id: fixtureId('contentActivity', (p.index * 1000 + day) * 10 + 2),
            activityKey: videoActivityKey(p.index, day),
            kind: 'video',
            title: 'Watch',
            document: videoDocument(fixtureId('video', 1)),
            estimatedSeconds: VIDEO_SECONDS,
          },
          {
            id: fixtureId('contentActivity', (p.index * 1000 + day) * 10 + 3),
            activityKey: activityId(p.index, day, 3),
            kind: 'write',
            title: 'Reflect',
            document: writeDocument('What stood out to you today?'),
          },
        ],
      })),
    })
  }
  created.programs = await prisma.studyProgram.findMany({ where: { organizationId: FIXTURE_ORG_ID }, orderBy: { id: 'asc' } })
  created.lessons = await prisma.lesson.findMany({
    where: { programId: { in: PROGRAMS.map((p) => p.id) } },
    orderBy: { id: 'asc' },
  })
  created.lessonVersions = await prisma.lessonVersion.findMany({
    where: { lessonId: { in: created.lessons.map((l) => l.id) } },
    orderBy: { id: 'asc' },
  })
  created.activities = await prisma.contentActivity.findMany({
    where: { lessonVersionId: { in: created.lessonVersions.map((v) => v.id) } },
    orderBy: { id: 'asc' },
  })

  const offsetsOf = (e: (typeof ENROLLMENT_PLAN)[number]) =>
    lessonOffsets(ctx.today, e.startOffset, PROGRAM_BY_KEY[e.program].days, e.days)
  await prisma.enrollment.createMany({
    data: ENROLLMENT_PLAN.map((e) => {
      const p = PROGRAM_BY_KEY[e.program]
      const offsets = offsetsOf(e)
      return {
        id: FIXTURE_ENROLLMENT_IDS[e.index - 1],
        groupId: FIXTURE_GROUP_IDS[e.groupIndex],
        studyProgramId: p.id,
        startDate: ctx.at(e.startOffset, 12),
        endDate: ctx.at(offsets[offsets.length - 1], 12),
        enabledDays: JSON.stringify(e.days),
        smsTime: '08:00',
        timezone: FIXTURE_TZ,
        createdById: FIXTURE_USER_ID,
        createdAt: ctx.daysAgo(3 - e.startOffset),
      }
    }),
  })
  for (const e of ENROLLMENT_PLAN) {
    const p = PROGRAM_BY_KEY[e.program]
    const offsets = offsetsOf(e)
    await scheduleLessons(ctx, {
      enrollmentId: FIXTURE_ENROLLMENT_IDS[e.index - 1],
      programVersionId: programVersionId(p.index),
      schedules: dayNumbers(p.days).map(
        (day): ScheduleSeed => ({
          id: scheduleId(e.index, day),
          lessonId: lessonId(p.index, day),
          currentVersionId: lessonVersionId(p.index, day),
          scheduledDate: ctx.at(offsets[day - 1], 12),
        })
      ),
    })
  }
  created.enrollments = await prisma.enrollment.findMany({ where: { id: { in: FIXTURE_ENROLLMENT_IDS } }, orderBy: { id: 'asc' } })
  created.schedules = await prisma.scheduledLesson.findMany({
    where: { enrollmentId: { in: FIXTURE_ENROLLMENT_IDS } },
    orderBy: { id: 'asc' },
  })
  // D22: covers and the media library, from the d2m image set.
  await seedImages(ctx)
}
