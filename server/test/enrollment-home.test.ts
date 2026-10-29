/**
 * ui2-enrollments-browse SC5 (D16, D20, §Contract Home): GET /api/enrollments/:id/home.
 * Real DB + API-key auth.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { todayInTimezone, zonedMidnight } from '../src/utils/timezone.js'
import { createUserWithApiKey, bearer, type TestUserWithToken } from './helpers/api-auth.js'

const CHI = 'America/Chicago'
const addDays = (ymd: string, n: number) => {
  const d = new Date(`${ymd}T12:00:00Z`); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10)
}

describe('GET /api/enrollments/:id/home', () => {
  const stamp = Date.now()
  const D = addDays(todayInTimezone(CHI), -2)
  let owner: TestUserWithToken, stranger: TestUserWithToken
  let orgId: string, strangerOrgId: string
  let groupId: string, emptyGroupId: string, programId: string
  let enrollmentId: string, emptyEnrollmentId: string, emptyScheduleId: string
  const memberIds: string[] = []
  let s1: string, s2: string, s3: string, removed: string
  let aYoutube: string, aVideo: string, aRead: string, aInput: string
  let enrolledAt: Date

  const home = (u: TestUserWithToken, id: string, query: Record<string, string> = {}) =>
    request(app).get(`/api/enrollments/${id}/home`).query(query).set('Authorization', bearer(u.token))

  beforeAll(async () => {
    owner = await createUserWithApiKey({ email: `eh-owner-${stamp}@cl.test`, name: 'Hana Author' })
    stranger = await createUserWithApiKey({ email: `eh-str-${stamp}@cl.test`, name: 'Stranger' })
    orgId = (await prisma.organization.create({ data: { name: `EH Org ${stamp}`, ownerId: owner.userId } })).id
    strangerOrgId = (await prisma.organization.create({ data: { name: `EH Other ${stamp}`, ownerId: stranger.userId } })).id
    groupId = (await prisma.group.create({ data: { name: 'Home Group', code: `eh-${stamp}`, creatorId: owner.userId, organizationId: orgId } })).id
    emptyGroupId = (await prisma.group.create({ data: { name: 'Empty', code: `ehe-${stamp}`, creatorId: owner.userId, organizationId: orgId } })).id
    programId = (await prisma.studyProgram.create({
      data: { name: 'Romans', description: 'Twelve readings', coverImageUrl: 'https://img.test/cover.jpg', days: 3, creatorId: owner.userId, organizationId: orgId },
    })).id
    for (let i = 0; i < 3; i++) {
      const m = await prisma.member.create({ data: { firstName: `H${i}`, lastName: 'Home', phoneNumber: `+1559${String(stamp).slice(-6)}${i}` } })
      memberIds.push(m.id)
      await prisma.groupMember.create({ data: { groupId, memberId: m.id, isActive: i < 2 } }) // member 2 left
    }
    enrolledAt = new Date(Date.now() - 5 * 86_400_000)
    enrollmentId = (await prisma.enrollment.create({
      data: {
        groupId, studyProgramId: programId, startDate: zonedMidnight(D, CHI), endDate: zonedMidnight(addDays(D, 1), CHI),
        enabledDays: '["Mon"]', smsTime: '07:30', timezone: CHI, lessonAccess: 'ONE_AT_A_TIME', createdAt: enrolledAt,
      },
    })).id
    const mkSchedule = async (date: Date, title: string, estimatedMinutes: number | null, removedAt: Date | null = null) =>
      (await prisma.lessonSchedule.create({ data: { enrollmentId, scheduledDate: date, title, estimatedMinutes, removedAt } })).id
    s1 = await mkSchedule(zonedMidnight(D, CHI), 'Day one', 20)
    s2 = await mkSchedule(new Date(zonedMidnight(D, CHI).getTime() + 3_600_000), 'Day one, part two', 10) // same local date
    s3 = await mkSchedule(zonedMidnight(addDays(D, 1), CHI), 'Day two', null)
    removed = await mkSchedule(zonedMidnight(addDays(D, 2), CHI), 'Gone', 99, new Date())

    // s1's activities: an old version's row (never shown) and the current version's four, one per thumbnail rule.
    const v1 = await prisma.lessonScheduleVersion.create({ data: { lessonScheduleId: s1, versionNumber: 1 } })
    const v2 = await prisma.lessonScheduleVersion.create({ data: { lessonScheduleId: s1, versionNumber: 2 } })
    await prisma.lessonSchedule.update({ where: { id: s1 }, data: { currentVersionId: v2.id } })
    const video = await prisma.video.create({
      data: { cloudflareUid: `eh-${stamp}`, playbackUrl: 'https://video.test/v.m3u8', userId: owner.userId, thumbnailUrl: 'https://img.test/vid.jpg' },
    })
    const act = async (data: Record<string, unknown>) =>
      (await prisma.scheduledLessonActivity.create({ data: { lessonScheduleId: s1, ...data } as never })).id
    await act({ type: 'YOUTUBE', orderNumber: 1, title: 'Old', versionId: v1.id, youtubeThumbnailUrl: 'https://img.test/old.jpg' })
    aYoutube = await act({ type: 'YOUTUBE', orderNumber: 1, title: 'Watch', versionId: v2.id, youtubeThumbnailUrl: 'https://img.test/yt.jpg' })
    aVideo = await act({ type: 'VIDEO', orderNumber: 2, title: 'Video', versionId: v2.id, videoId: video.id })
    aRead = await act({ type: 'READ', orderNumber: 3, title: 'Read', versionId: v2.id })
    aInput = await act({ type: 'USER_INPUT', orderNumber: 4, title: 'Reflect', versionId: v2.id })
    await prisma.activityReadBlock.create({ data: { scheduledActivityId: aRead, orderNumber: 1, content: 'no image' } })
    await prisma.activityReadBlock.create({ data: { scheduledActivityId: aRead, orderNumber: 2, content: 'image', backgroundImageUrl: 'https://img.test/read.jpg' } })

    const complete = (memberIndex: number, scheduleIds: string[]) =>
      prisma.memberLessonProgress.createMany({ data: scheduleIds.map((lessonScheduleId) => ({ memberId: memberIds[memberIndex], lessonScheduleId, completedAt: new Date() })) })
    await complete(0, [s1, s2, s3, removed])
    await complete(1, [s1])
    await complete(2, [s1, s2, s3]) // ex-member: never counts

    emptyEnrollmentId = (await prisma.enrollment.create({
      data: { groupId: emptyGroupId, studyProgramId: programId, startDate: zonedMidnight(D, CHI), endDate: zonedMidnight(D, CHI), enabledDays: '["Mon"]', timezone: CHI },
    })).id
    emptyScheduleId = (await prisma.lessonSchedule.create({ data: { enrollmentId: emptyEnrollmentId, scheduledDate: zonedMidnight(D, CHI), title: 'Solo', estimatedMinutes: 5 } })).id
  })

  afterAll(async () => {
    const orgs = [orgId, strangerOrgId]
    await prisma.enrollment.deleteMany({ where: { group: { organizationId: { in: orgs } } } })
    await prisma.video.deleteMany({ where: { userId: owner.userId } })
    await prisma.groupMember.deleteMany({ where: { memberId: { in: memberIds } } })
    await prisma.member.deleteMany({ where: { id: { in: memberIds } } })
    await prisma.studyProgram.deleteMany({ where: { organizationId: { in: orgs } } })
    await prisma.group.deleteMany({ where: { organizationId: { in: orgs } } })
    const users = [owner.userId, stranger.userId]
    await prisma.apiKey.deleteMany({ where: { userId: { in: users } } })
    await prisma.organization.deleteMany({ where: { id: { in: orgs } } })
    await prisma.user.deleteMany({ where: { id: { in: users } } })
  })

  it('assembles the header: program + author, group + leader, active members, span, invite time (D20)', async () => {
    const res = await home(owner, enrollmentId)
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
    expect(res.body.home).toMatchObject({
      id: enrollmentId,
      studyProgram: { id: programId, name: 'Romans', description: 'Twelve readings', coverImageUrl: 'https://img.test/cover.jpg', authorName: 'Hana Author' },
      group: { id: groupId, name: 'Home Group', leader: { id: owner.userId, name: 'Hana Author' } },
      memberCount: 2,
      enrolledAt: enrolledAt.toISOString(),
      startDate: D,
      endDate: addDays(D, 1),
      lessonAccess: 'ONE_AT_A_TIME',
      smsTime: '07:30',
      timezone: CHI,
    })
  })

  it('days: one per local date, first schedule\'s id, everyone-on-that-date percent, removed excluded (D20)', async () => {
    const { days } = (await home(owner, enrollmentId)).body.home
    expect(days).toEqual([
      { scheduleId: s1, date: D, percent: 50, lessonCount: 2, plannedMinutes: 30 }, // member 0 did both; member 1 only s1
      { scheduleId: s3, date: addDays(D, 1), percent: 50, lessonCount: 1, plannedMinutes: 0 },
    ])
  })

  it('lessons: dayNumber by position, progress over active members, current-version activities with thumbnails', async () => {
    const { lessons } = (await home(owner, enrollmentId)).body.home
    expect(lessons.map((l: { scheduleId: string; dayNumber: number; title: string; date: string; progress: number }) =>
      [l.scheduleId, l.dayNumber, l.title, l.date, l.progress])).toEqual([
      [s1, 1, 'Day one', D, 1],
      [s2, 2, 'Day one, part two', D, 0.5],
      [s3, 3, 'Day two', addDays(D, 1), 0.5],
    ])
    expect(lessons[0].activities).toEqual([
      { id: aYoutube, type: 'YOUTUBE', title: 'Watch', thumbnailUrl: 'https://img.test/yt.jpg' },
      { id: aVideo, type: 'VIDEO', title: 'Video', thumbnailUrl: 'https://img.test/vid.jpg' },
      { id: aRead, type: 'READ', title: 'Read', thumbnailUrl: 'https://img.test/read.jpg' },
      { id: aInput, type: 'USER_INPUT', title: 'Reflect', thumbnailUrl: null },
    ])
    expect(lessons[1].activities).toEqual([])
  })

  it('no active members: progress null and day percent 0', async () => {
    const body = (await home(owner, emptyEnrollmentId)).body.home
    expect(body.memberCount).toBe(0)
    expect(body.days).toEqual([{ scheduleId: emptyScheduleId, date: D, percent: 0, lessonCount: 1, plannedMinutes: 5 }])
    expect(body.lessons[0].progress).toBeNull()
  })

  it('404 outside enrollmentManageFilter, for an unknown id and a malformed one; 400 on a bad tz', async () => {
    expect((await home(stranger, enrollmentId)).status).toBe(404)
    expect((await home(owner, '00000000-0000-4000-8000-000000000000')).status).toBe(404)
    expect((await home(owner, 'nope')).status).toBe(404)
    expect((await home(owner, enrollmentId, { tz: 'Mars/Olympus' })).status).toBe(400)
    expect((await home(owner, enrollmentId, { tz: 'Asia/Tokyo' })).body.home.startDate).toBe(D) // enrollment's own zone
  })
})
