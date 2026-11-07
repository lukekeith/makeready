/**
 * ui2-enrollments-browse SC5 (D16, D20, §Contract Home): GET /api/enrollments/:id/home.
 * Real DB + API-key auth.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import request from 'supertest'
import { randomUUID } from 'node:crypto'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { todayInTimezone, zonedMidnight } from '../src/utils/timezone.js'
import { createUserWithApiKey, bearer, type TestUserWithToken } from './helpers/api-auth.js'
import { destroySimplePrograms } from './helpers/published-program.js'

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
  let mediaIds: string[] = []
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
    // One lesson (with a PUBLISHED version) per schedule; the schedule points at that version.
    let position = 0
    const mkSchedule = async (date: Date, title: string, estimatedSeconds: number | null, removedAt: Date | null = null) => {
      const lesson = await prisma.lesson.create({ data: { programId, position: ++position } })
      const version = await prisma.lessonVersion.create({
        data: { lessonId: lesson.id, number: 1, status: 'PUBLISHED', title, estimatedSeconds, publishedAt: new Date() },
      })
      const sl = await prisma.scheduledLesson.create({
        data: { enrollmentId, lessonId: lesson.id, scheduledDate: date, currentVersionId: version.id, removedAt },
      })
      return { id: sl.id, versionId: version.id }
    }
    const first = await mkSchedule(zonedMidnight(D, CHI), 'Day one', 1200)
    s1 = first.id
    s2 = (await mkSchedule(new Date(zonedMidnight(D, CHI).getTime() + 3_600_000), 'Day one, part two', 600)).id // same local date
    s3 = (await mkSchedule(zonedMidnight(addDays(D, 1), CHI), 'Day two', null)).id
    removed = (await mkSchedule(zonedMidnight(addDays(D, 2), CHI), 'Gone', 5940, new Date())).id

    // s1's version holds four activities, one per thumbnail rule: a background image, a video poster, a youtube page and a write page.
    const media = async (title: string) =>
      (await prisma.media.create({ data: { title, url: `https://img.test/${title}.jpg`, type: 'photo', organizationId: orgId, uploadedBy: owner.userId } })).id
    mediaIds = [await media('bg'), await media('poster')]
    const doc = (kind: string, background: object, content: object) => ({
      schemaVersion: 1, kind, background, content, actions: [], chrome: { topAction: 'none' }, fallback: { title: 'x', body: 'y' },
    })
    const act = async (position: number, kind: string, title: string, document: object) =>
      (await prisma.contentActivity.create({
        data: { lessonVersionId: first.versionId, activityKey: `k-${stamp}-${position}`, position, kind, title, document },
      })).id
    aYoutube = await act(1, 'text', 'Watch', doc('text', { color: '#000', image: { mediaId: mediaIds[0] } }, { type: 'canvas', objects: [] }))
    aVideo = await act(2, 'video', 'Video', doc('video', { color: '#000' }, { type: 'video', videoId: randomUUID(), posterMediaId: mediaIds[1] }))
    aRead = await act(3, 'youtube', 'Read', doc('youtube', { color: '#000' }, { type: 'youtube', youtubeVideoId: 'abc' }))
    aInput = await act(4, 'write', 'Reflect', doc('write', { color: '#000' }, { type: 'write', prompt: { text: 'p' } }))

    const complete = (memberIndex: number, scheduleIds: string[]) =>
      prisma.lessonProgress.createMany({ data: scheduleIds.map((scheduledLessonId) => ({ memberId: memberIds[memberIndex], scheduledLessonId, completedAt: new Date() })) })
    await complete(0, [s1, s2, s3, removed])
    await complete(1, [s1])
    await complete(2, [s1, s2, s3]) // ex-member: never counts

    emptyEnrollmentId = (await prisma.enrollment.create({
      data: { groupId: emptyGroupId, studyProgramId: programId, startDate: zonedMidnight(D, CHI), endDate: zonedMidnight(D, CHI), enabledDays: '["Mon"]', timezone: CHI },
    })).id
    const soloLesson = await prisma.lesson.create({ data: { programId, position: ++position } })
    const soloVersion = await prisma.lessonVersion.create({
      data: { lessonId: soloLesson.id, number: 1, status: 'PUBLISHED', title: 'Solo', estimatedSeconds: 300, publishedAt: new Date() },
    })
    emptyScheduleId = (await prisma.scheduledLesson.create({
      data: { enrollmentId: emptyEnrollmentId, lessonId: soloLesson.id, scheduledDate: zonedMidnight(D, CHI), currentVersionId: soloVersion.id },
    })).id
  })

  afterAll(async () => {
    const orgs = [orgId, strangerOrgId]
    await destroySimplePrograms([programId])
    await prisma.media.deleteMany({ where: { id: { in: mediaIds } } })
    await prisma.groupMember.deleteMany({ where: { memberId: { in: memberIds } } })
    await prisma.member.deleteMany({ where: { id: { in: memberIds } } })
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
      { id: aYoutube, type: 'text', title: 'Watch', thumbnailUrl: 'https://img.test/bg.jpg' },
      { id: aVideo, type: 'video', title: 'Video', thumbnailUrl: 'https://img.test/poster.jpg' },
      { id: aRead, type: 'youtube', title: 'Read', thumbnailUrl: null },
      { id: aInput, type: 'write', title: 'Reflect', thumbnailUrl: null },
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
