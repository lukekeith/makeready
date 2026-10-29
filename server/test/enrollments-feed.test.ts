/**
 * ui2-enrollments-browse SC4 (D7, D8, D12, D13, D15–D17, D25, D27): GET /api/enrollments-feed.
 * Real DB + API-key auth. Dates are UTC days relative to today; enrollments carry timezone 'UTC'.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { bucketOf } from '../src/services/enrollment-directory.service.js'
import { todayInTimezone } from '../src/utils/timezone.js'
import { createUserWithApiKey, bearer, type TestUserWithToken } from './helpers/api-auth.js'

const addDays = (ymd: string, n: number) => {
  const d = new Date(`${ymd}T12:00:00Z`); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10)
}

describe('bucketOf (D8)', () => {
  it('buckets on the enrollment\'s own zone against the request zone\'s today', () => {
    // Kiritimati is UTC+14: these instants fall on 2026-03-11 (start) and 2026-03-21 (end) there.
    const e = { startDate: new Date('2026-03-10T11:00:00Z'), endDate: new Date('2026-03-20T11:00:00Z'), timezone: 'Pacific/Kiritimati' }
    expect(bucketOf(e, '2026-03-10')).toBe('upcoming')
    expect(bucketOf({ ...e, timezone: 'UTC' }, '2026-03-10')).toBe('active')
    expect(bucketOf(e, '2026-03-21')).toBe('active')
    expect(bucketOf({ ...e, timezone: null }, '2026-03-21')).toBe('completed')
  })
})

describe('GET /api/enrollments-feed', () => {
  const stamp = Date.now()
  const now = new Date()
  const today = todayInTimezone('UTC')
  const day = (offset: number) => new Date(`${addDays(today, offset)}T12:00:00Z`)
  const ago = (ms: number) => new Date(now.getTime() - ms)
  const HOUR = 3_600_000
  const DAY = 24 * HOUR
  let owner: TestUserWithToken, leader2: TestUserWithToken, stranger: TestUserWithToken, admin: TestUserWithToken
  let orgA: string, orgB: string
  let g1: string, g2: string, gInactive: string, gB: string
  let program: string, programInactive: string, programB: string
  const memberIds: string[] = []
  let eActive: string, eUpcoming: string, eCompleted: string, eActive2: string
  let eInactiveProgram: string, eInactiveGroup: string, eForeign: string
  let draftId: string
  const progressAt = ago(HOUR)

  const feed = (u: TestUserWithToken, query: Record<string, string> = {}) =>
    request(app).get('/api/enrollments-feed').query({ tz: 'UTC', ...query }).set('Authorization', bearer(u.token))
  const ids = (body: { sections: { items: { kind: string; id?: string; draft?: { id: string } }[] }[] }) =>
    body.sections.flatMap((s) => s.items.map((i) => (i.kind === 'draft' ? i.draft!.id : i.id!)))
  const mkEnrollment = async (groupId: string, studyProgramId: string, start: number, end: number, createdAt: Date) =>
    (await prisma.enrollment.create({
      data: { groupId, studyProgramId, startDate: day(start), endDate: day(end), enabledDays: '["Mon"]', timezone: 'UTC', createdAt },
    })).id

  beforeAll(async () => {
    owner = await createUserWithApiKey({ email: `ef-owner-${stamp}@cl.test`, name: 'Amy Owner' })
    leader2 = await createUserWithApiKey({ email: `ef-l2-${stamp}@cl.test`, name: 'Ben Leader' })
    stranger = await createUserWithApiKey({ email: `ef-str-${stamp}@cl.test`, name: 'Stranger' })
    admin = await createUserWithApiKey({ email: `ef-sa-${stamp}@cl.test`, name: 'Super', isSuperAdmin: true })
    orgA = (await prisma.organization.create({ data: { name: `EF A ${stamp}`, ownerId: owner.userId } })).id
    orgB = (await prisma.organization.create({ data: { name: `EF B ${stamp}`, ownerId: stranger.userId } })).id
    const role = await prisma.role.create({ data: { name: `EF Leader ${stamp}`, organizationId: orgA, isSystem: false } })
    await prisma.userRole.create({ data: { userId: leader2.userId, roleId: role.id, organizationId: orgA } })
    const mkGroup = async (org: string, creator: string, name: string, isActive = true) =>
      (await prisma.group.create({ data: { name, code: `ef-${name}-${stamp}`, creatorId: creator, organizationId: org, isActive } })).id
    g1 = await mkGroup(orgA, owner.userId, 'Alpha')
    g2 = await mkGroup(orgA, leader2.userId, 'Bravo')
    gInactive = await mkGroup(orgA, owner.userId, 'Charlie', false)
    gB = await mkGroup(orgB, stranger.userId, 'Delta')
    const mkProgram = async (org: string, creator: string, name: string, isActive = true) =>
      (await prisma.studyProgram.create({ data: { name, days: 3, creatorId: creator, organizationId: org, isActive, coverImageUrl: `https://img.test/${name}.jpg` } })).id
    program = await mkProgram(orgA, owner.userId, `EF Program ${stamp}`)
    programInactive = await mkProgram(orgA, owner.userId, `EF Gone ${stamp}`, false)
    programB = await mkProgram(orgB, stranger.userId, `EF B Program ${stamp}`)

    // g1: three active members + one ex-member (D16: the ex-member's completions never count).
    for (let i = 0; i < 4; i++) {
      const m = await prisma.member.create({ data: { firstName: `M${i}`, lastName: 'Feed', phoneNumber: `+1558${String(stamp).slice(-6)}${i}` } })
      memberIds.push(m.id)
      await prisma.groupMember.create({ data: { groupId: g1, memberId: m.id, isActive: i < 3 } })
    }

    eActive = await mkEnrollment(g1, program, -5, 5, ago(10 * DAY))
    const s = [
      await prisma.lessonSchedule.create({ data: { enrollmentId: eActive, scheduledDate: day(-5), estimatedMinutes: 30, title: 'A' } }),
      await prisma.lessonSchedule.create({ data: { enrollmentId: eActive, scheduledDate: new Date(day(-5).getTime() + HOUR), estimatedMinutes: 30, title: 'B' } }),
      await prisma.lessonSchedule.create({ data: { enrollmentId: eActive, scheduledDate: day(-4), estimatedMinutes: null, title: 'C' } }),
      await prisma.lessonSchedule.create({ data: { enrollmentId: eActive, scheduledDate: day(-3), estimatedMinutes: 60, title: 'Removed', removedAt: now } }),
    ]
    const complete = (memberIndex: number, scheduleIndexes: number[]) =>
      prisma.memberLessonProgress.createMany({
        data: scheduleIndexes.map((k) => ({
          memberId: memberIds[memberIndex], lessonScheduleId: s[k].id, completedAt: ago(2 * HOUR), startedAt: ago(3 * HOUR), lastUpdatedAt: ago(2 * HOUR),
        })),
      })
    await complete(0, [0, 1, 2, 3]) // every lesson (+ the removed one, which never counts)
    await complete(1, [0])
    await complete(3, [0, 1, 2]) // ex-member
    await prisma.memberLessonProgress.update({
      where: { memberId_lessonScheduleId: { memberId: memberIds[1], lessonScheduleId: s[0].id } },
      data: { lastUpdatedAt: progressAt },
    })

    eUpcoming = await mkEnrollment(g1, program, 3, 10, ago(2 * DAY))
    eCompleted = await mkEnrollment(g1, program, -20, -10, ago(30 * DAY))
    eActive2 = await mkEnrollment(g2, program, -1, 1, ago(HOUR / 2))
    eInactiveProgram = await mkEnrollment(g1, programInactive, -1, 1, now)
    eInactiveGroup = await mkEnrollment(gInactive, program, -1, 1, now)
    eForeign = await mkEnrollment(gB, programB, -1, 1, now)
    draftId = (await prisma.enrollmentDraft.create({ data: { groupId: g1, studyProgramId: program, createdById: owner.userId } })).id
  })

  afterAll(async () => {
    const orgs = [orgA, orgB]
    await prisma.enrollment.deleteMany({ where: { group: { organizationId: { in: orgs } } } })
    await prisma.enrollmentDraft.deleteMany({ where: { group: { organizationId: { in: orgs } } } })
    await prisma.groupMember.deleteMany({ where: { memberId: { in: memberIds } } })
    await prisma.member.deleteMany({ where: { id: { in: memberIds } } })
    await prisma.studyProgram.deleteMany({ where: { organizationId: { in: orgs } } })
    await prisma.group.deleteMany({ where: { organizationId: { in: orgs } } })
    await prisma.userRole.deleteMany({ where: { organizationId: orgA } })
    await prisma.role.deleteMany({ where: { organizationId: orgA } })
    const users = [owner.userId, leader2.userId, stranger.userId, admin.userId]
    await prisma.apiKey.deleteMany({ where: { userId: { in: users } } })
    await prisma.organization.deleteMany({ where: { id: { in: orgs } } })
    await prisma.user.deleteMany({ where: { id: { in: users } } })
  })

  it('defaults to Active: sections by newest item, rows newest first, no drafts (D8, D17)', async () => {
    const res = await feed(owner)
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
    expect(res.body.sections.map((s: { group: { id: string } }) => s.group.id)).toEqual([g2, g1]) // eActive2 (−30 min) beats eActive (−1 h)
    expect(ids(res.body)).toEqual([eActive2, eActive])
    expect(res.body.sections[0].group).toEqual({ id: g2, name: 'Bravo', coverImageUrl: null, leader: { id: leader2.userId, name: 'Ben Leader' } })
  })

  it('computes the row numbers on active members and non-removed lessons (D12, D16, D17)', async () => {
    const res = await feed(owner)
    const item = res.body.sections[1].items[0]
    expect(item).toEqual({
      kind: 'enrollment',
      id: eActive,
      studyProgram: { id: program, name: `EF Program ${stamp}`, coverImageUrl: `https://img.test/EF Program ${stamp}.jpg` },
      startDate: addDays(today, -5),
      endDate: addDays(today, 5),
      enrolledAt: ago(10 * DAY).toISOString(),
      progress: 4 / 9, // (3 + 1) completions ÷ (3 active members × 3 lessons); the ex-member's 3 never count
      completedMembers: 1,
      memberCount: 3,
      plannedMinutes: 60, // 30 + 30 + null(0); the removed 60 is excluded
      recencyAt: progressAt.toISOString(),
    })
    expect(item.progress).toBeLessThanOrEqual(1)
  })

  it('Upcoming, Completed, Draft and All each return only their rows; drafts only under Draft and All (D8)', async () => {
    expect(ids((await feed(owner, { status: 'upcoming' })).body)).toEqual([eUpcoming])
    expect(ids((await feed(owner, { status: 'completed' })).body)).toEqual([eCompleted])
    const drafts = (await feed(owner, { status: 'draft' })).body
    expect(ids(drafts)).toEqual([draftId])
    expect(drafts.sections[0].items[0]).toMatchObject({
      kind: 'draft',
      draft: { id: draftId, groupId: g1, studyProgramId: program, createdBy: { id: owner.userId, name: 'Amy Owner' } },
      studyProgram: { id: program },
    })
    const all = (await feed(owner, { status: 'all' })).body
    expect(all.sections.map((s: { group: { id: string } }) => s.group.id)).toEqual([g1, g2]) // the draft (now) is newest
    expect(ids(all)).toEqual([draftId, eActive, eUpcoming, eCompleted, eActive2])
  })

  it('never lists an inactive group, an inactive program or another org (D19, D25)', async () => {
    const all = ids((await feed(owner, { status: 'all' })).body)
    for (const hidden of [eInactiveProgram, eInactiveGroup, eForeign]) expect(all).not.toContain(hidden)
  })

  it('groupId and leaderId narrow the sections; options stay the scope\'s (D13, §Contract)', async () => {
    const base = (await feed(owner)).body.options
    expect(base).toEqual({
      groups: [{ id: g1, name: 'Alpha' }, { id: g2, name: 'Bravo' }],
      leaders: [{ id: owner.userId, name: 'Amy Owner' }, { id: leader2.userId, name: 'Ben Leader' }],
    })
    const byLeader = (await feed(owner, { leaderId: leader2.userId })).body
    expect(ids(byLeader)).toEqual([eActive2])
    expect(byLeader.options).toEqual(base)
    const byGroup = (await feed(owner, { groupId: g1 })).body
    expect(ids(byGroup)).toEqual([eActive])
    expect(byGroup.options).toEqual(base)
    expect((await feed(owner, { status: 'upcoming' })).body.options.groups).toEqual([{ id: g1, name: 'Alpha' }])
  })

  it('orgId: one of yours narrows; another org is 400 with the D15 message', async () => {
    expect(ids((await feed(owner, { orgId: orgA })).body)).toEqual([eActive2, eActive])
    const res = await feed(owner, { orgId: orgB })
    expect(res.status).toBe(400)
    expect(res.body).toEqual({ success: false, error: 'orgId is not one of your organizations' })
    expect((await feed(owner, { orgId: 'nope' })).status).toBe(400)
  })

  it('a super admin with no orgId sees only orgs they manage; an explicit orgId reaches any org (D25)', async () => {
    expect(ids((await feed(admin, { status: 'all' })).body)).not.toContain(eActive)
    expect(ids((await feed(admin, { orgId: orgA })).body)).toEqual([eActive2, eActive])
  })

  it('400s a bad status or tz; ignores an unknown q (D27)', async () => {
    expect((await feed(owner, { status: 'paused' })).status).toBe(400)
    expect((await feed(owner, { tz: 'Mars/Olympus' })).status).toBe(400)
    expect((await feed(owner, { q: 'alpha' })).status).toBe(200)
  })
})

describe('GET /api/enrollments-feed cap (D25)', () => {
  const stamp = Date.now()
  let owner: TestUserWithToken
  let orgId: string
  let groupId: string
  let programId: string
  const created: string[] = []

  beforeAll(async () => {
    owner = await createUserWithApiKey({ email: `efc-owner-${stamp}@cl.test`, name: 'Cap Owner' })
    orgId = (await prisma.organization.create({ data: { name: `EFC ${stamp}`, ownerId: owner.userId } })).id
    groupId = (await prisma.group.create({ data: { name: 'Cap', code: `efc-${stamp}`, creatorId: owner.userId, organizationId: orgId } })).id
    programId = (await prisma.studyProgram.create({ data: { name: 'Cap P', days: 1, creatorId: owner.userId, organizationId: orgId } })).id
    const now = Date.now()
    const today = todayInTimezone('UTC')
    for (let i = 0; i < 201; i++) {
      const id = crypto.randomUUID()
      created.push(id)
      await prisma.enrollment.create({
        data: {
          id, groupId, studyProgramId: programId, enabledDays: '["Mon"]', timezone: 'UTC',
          startDate: new Date(`${addDays(today, -1)}T12:00:00Z`), endDate: new Date(`${addDays(today, 1)}T12:00:00Z`),
          createdAt: new Date(now - (i + 1) * 60_000),
        },
      })
    }
  })

  afterAll(async () => {
    await prisma.enrollment.deleteMany({ where: { groupId } })
    await prisma.studyProgram.deleteMany({ where: { id: programId } })
    await prisma.group.deleteMany({ where: { id: groupId } })
    await prisma.apiKey.deleteMany({ where: { userId: owner.userId } })
    await prisma.organization.deleteMany({ where: { id: orgId } })
    await prisma.user.deleteMany({ where: { id: owner.userId } })
  })

  it('returns at most 200 items and drops the oldest', async () => {
    const res = await request(app).get('/api/enrollments-feed').query({ tz: 'UTC' }).set('Authorization', bearer(owner.token))
    expect(res.status).toBe(200)
    const items = res.body.sections.flatMap((s: { items: { id: string }[] }) => s.items.map((i) => i.id))
    expect(items).toHaveLength(200)
    expect(items).toEqual(created.slice(0, 200))
  })
})
