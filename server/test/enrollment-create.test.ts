/**
 * ui2-enrollment-create SC2 (D3, D4, D5, D16, T12): POST /api/enrollments takes the app's exact
 * dates and lesson access, refuses a 0-member group and a program outside the caller's read scope.
 * Real DB + API-key auth, as enrollment-authorization.test.ts.
 */
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { createUserWithApiKey, bearer, type TestUserWithToken } from './helpers/api-auth.js'
import { todayInTimezone } from '../src/utils/timezone.js'

const TZ = 'America/Chicago'
const addDays = (ymd: string, n: number) => {
  const d = new Date(`${ymd}T12:00:00Z`); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10)
}

describe('POST /api/enrollments (ui2-enrollment-create)', () => {
  const stamp = Date.now()
  let owner: TestUserWithToken
  let stranger: TestUserWithToken
  let orgId: string
  let otherOrgId: string
  let groupId: string
  let emptyGroupId: string
  let programId: string
  let foreignProgramId: string
  let memberId: string
  const today = todayInTimezone(TZ)

  const body = (extra: Record<string, unknown> = {}) => ({
    groupId, studyProgramId: programId, startDate: new Date().toISOString(),
    enabledDays: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'], timezone: TZ, ...extra,
  })
  const post = (b: Record<string, unknown>) =>
    request(app).post('/api/enrollments').set('Authorization', bearer(owner.token)).send(b)

  beforeAll(async () => {
    owner = await createUserWithApiKey({ email: `ec-owner-${stamp}@cl.test`, name: 'EC Owner' })
    stranger = await createUserWithApiKey({ email: `ec-stranger-${stamp}@cl.test`, name: 'EC Stranger' })
    orgId = (await prisma.organization.create({ data: { name: `EC Org ${stamp}`, ownerId: owner.userId } })).id
    otherOrgId = (await prisma.organization.create({ data: { name: `EC Other ${stamp}`, ownerId: stranger.userId } })).id
    groupId = (await prisma.group.create({ data: { name: `EC Group ${stamp}`, code: `ecg-${stamp}`, creatorId: owner.userId, organizationId: orgId } })).id
    emptyGroupId = (await prisma.group.create({ data: { name: `EC Empty ${stamp}`, code: `ece-${stamp}`, creatorId: owner.userId, organizationId: orgId } })).id
    memberId = (await prisma.member.create({ data: { firstName: 'Ann', lastName: 'Lee', phoneNumber: `+1555${String(stamp).slice(-7)}` } })).id
    await prisma.groupMember.create({ data: { groupId, memberId, isActive: true } })
    const mkProgram = async (org: string, creator: string, name: string) => {
      const p = await prisma.studyProgram.create({
        data: { name, days: 3, creatorId: creator, organizationId: org, isPublished: true, publishedAt: new Date() },
      })
      for (const day of [1, 2, 3]) await prisma.lesson.create({ data: { studyProgramId: p.id, dayNumber: day } })
      return p.id
    }
    programId = await mkProgram(orgId, owner.userId, `EC Program ${stamp}`)
    foreignProgramId = await mkProgram(otherOrgId, stranger.userId, `EC Foreign ${stamp}`)
  })

  // enroll-picker-hide-enrolled D6: every case enrolls the same pair, which may hold one current enrollment.
  beforeEach(async () => {
    await prisma.enrollment.deleteMany({ where: { groupId, studyProgramId: programId } })
  })

  afterAll(async () => {
    const orgs = [orgId, otherOrgId]
    await prisma.enrollment.deleteMany({ where: { group: { organizationId: { in: orgs } } } })
    await prisma.groupMember.deleteMany({ where: { memberId } })
    await prisma.member.deleteMany({ where: { id: memberId } })
    await prisma.lesson.deleteMany({ where: { studyProgram: { organizationId: { in: orgs } } } })
    await prisma.studyProgram.deleteMany({ where: { organizationId: { in: orgs } } })
    await prisma.group.deleteMany({ where: { organizationId: { in: orgs } } })
    await prisma.apiKey.deleteMany({ where: { userId: { in: [owner.userId, stranger.userId] } } })
    await prisma.organization.deleteMany({ where: { id: { in: orgs } } })
    await prisma.user.deleteMany({ where: { id: { in: [owner.userId, stranger.userId] } } })
  })

  it('stores the sent dates verbatim as 00:00 in the request zone; endDate = last; startDate = first', async () => {
    const dates = [addDays(today, 1), addDays(today, 3), addDays(today, 6)]
    const res = await post(body({ scheduleDates: dates, lessonAccess: 'ONE_AT_A_TIME', syncMode: 'OFF' }))
    expect(res.status).toBe(200)
    expect(res.body.enrollment.lessonAccess).toBe('ONE_AT_A_TIME')
    expect(res.body.enrollment.syncMode).toBe('OFF')
    const schedules = await prisma.lessonSchedule.findMany({
      where: { enrollmentId: res.body.enrollment.id }, orderBy: { scheduledDate: 'asc' },
    })
    const local = (d: Date) => new Intl.DateTimeFormat('en-CA', { timeZone: TZ }).format(d)
    const hour = (d: Date) => new Intl.DateTimeFormat('en-US', { timeZone: TZ, hour: '2-digit', hour12: false }).format(d)
    expect(schedules.map((s) => local(s.scheduledDate))).toEqual(dates)
    expect(schedules.every((s) => hour(s.scheduledDate) === '00')).toBe(true)
    const e = await prisma.enrollment.findUniqueOrThrow({ where: { id: res.body.enrollment.id } })
    expect(local(e.startDate)).toBe(dates[0])
    expect(local(e.endDate)).toBe(dates[2])
  })

  it('derives the dates as before when scheduleDates is absent, and defaults lessonAccess to ALL_AT_ONCE', async () => {
    const res = await post(body())
    expect(res.status).toBe(200)
    expect(res.body.enrollment.lessonAccess).toBe('ALL_AT_ONCE')
    expect(await prisma.lessonSchedule.count({ where: { enrollmentId: res.body.enrollment.id } })).toBe(3)
  })

  it('400s a wrong count, naming the expected one (A2)', async () => {
    const res = await post(body({ scheduleDates: [addDays(today, 1)] }))
    expect(res.status).toBe(400)
    expect(res.body.error).toBe("Schedule doesn't match the program: expected 3 dates, got 1")
  })

  it('400s unsorted dates and a past first date', async () => {
    expect((await post(body({ scheduleDates: [addDays(today, 3), addDays(today, 2), addDays(today, 4)] }))).status).toBe(400)
    expect((await post(body({ scheduleDates: [addDays(today, -1), addDays(today, 2), addDays(today, 4)] }))).status).toBe(400)
  })

  it('400s an invalid timezone (D16)', async () => {
    expect((await post(body({ timezone: 'Mars/Olympus' }))).status).toBe(400)
  })

  it('400s a 0-member group with group_has_no_members (D5)', async () => {
    const res = await post(body({ groupId: emptyGroupId }))
    expect(res.status).toBe(400)
    expect(res.body).toEqual({ success: false, error: 'group_has_no_members', message: 'Group has no members' })
  })

  it('404s a program outside the caller\'s read scope (T12)', async () => {
    const res = await post(body({ studyProgramId: foreignProgramId }))
    expect(res.status).toBe(404)
    expect(res.body.error).toBe('Study program not found')
  })
})
