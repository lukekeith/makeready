/**
 * text-activity Task 14: the readers that sat on the 1.0 lesson models — notes (D42), the home dashboard, following and sessions,
 * and the share previews (§server "Rewrite on the new model"). Real DB; every reader runs on ScheduledLesson + its current version.
 */
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { bearer } from './helpers/api-auth.js'
import { generateLessonOgMeta, generateStudyOgMeta } from '../src/lib/og-meta.js'
import { generateUniqueStudyCode } from '../src/lib/study-code.js'
import { getNotesWithContext } from '../src/services/notes.service.js'
import { getHomeEngagement } from '../src/services/home-dashboard.js'
import { getHomeFollowing, FOLLOWED_ENROLLMENTS_KEY } from '../src/services/home-following.js'
import { loadSessions } from '../src/services/home-sessions.js'
import { setPreference } from '../src/services/preferences.js'
import {
  createContentWorld, destroyContentWorld, seedEnrolledProgram, type ContentWorld, type EnrolledProgram,
} from './helpers/content-world.js'

const DAY = 24 * 3600 * 1000
const uuid = () => crypto.randomUUID()

describe('notes after the lesson models', () => {
  let w: ContentWorld
  let memberId: string
  const noteIds: string[] = []
  beforeAll(async () => {
    w = await createContentWorld()
    memberId = (await prisma.member.create({ data: { phoneNumber: `+1557${Math.floor(1e7 + Math.random() * 9e7)}` } })).id
  })
  afterAll(async () => {
    await prisma.studyNote.deleteMany({ where: { id: { in: noteIds } } })
    await prisma.member.delete({ where: { id: memberId } })
    await destroyContentWorld(w)
  })

  const createNote = (links: { refType: string; refId: string }[]) =>
    request(app).post('/api/notes').set('Authorization', bearer(w.leader.token)).send({ type: 'JOURNAL', content: 'x', links })

  it('a note can no longer link a lesson activity', async () => {
    const r = await createNote([{ refType: 'LESSON_ACTIVITY', refId: uuid() }])
    expect(r.status).toBe(400)
    expect(r.body).toMatchObject({ success: false, code: 'VALIDATION' })
  })

  it.each(['SCHEDULED_ACTIVITY', 'LESSON_SCHEDULE'])('a note can no longer link a %s', async (refType) => {
    const r = await createNote([{ refType, refId: uuid() }])
    expect(r.status).toBe(400)
    expect(r.body.code).toBe('VALIDATION')
  })

  it('a refused link creates no note', async () => {
    const before = await prisma.studyNote.count({ where: { userId: w.leader.userId } })
    await createNote([{ refType: 'LESSON_SCHEDULE', refId: uuid() }])
    expect(await prisma.studyNote.count({ where: { userId: w.leader.userId } })).toBe(before)
  })

  it('a note still links a lesson, and its context reports the lesson position as dayNumber', async () => {
    const r = await createNote([{ refType: 'LESSON', refId: w.lessonId }])
    expect(r.status).toBe(201)
    noteIds.push(r.body.data.id)
    await prisma.studyNote.update({ where: { id: r.body.data.id }, data: { memberId, userId: null } })
    const ctx = await getNotesWithContext({ memberId })
    expect(ctx.data?.[0].context.lesson).toEqual({ id: w.lessonId, dayNumber: 1 })
  })

  it('an existing note keeps its body and loses only the removed link context', async () => {
    const note = await prisma.studyNote.create({
      data: {
        memberId, type: 'OBSERVATION', content: 'kept body',
        links: { create: [{ refType: 'LESSON_ACTIVITY', refId: uuid() }, { refType: 'LESSON_SCHEDULE', refId: uuid() }] },
      },
    })
    noteIds.push(note.id)
    const ctx = await getNotesWithContext({ memberId })
    const found = ctx.data?.find((n) => n.id === note.id)
    expect(ctx.success).toBe(true)
    expect(found).toMatchObject({ content: 'kept body', context: {} })
  })
})

describe('home dashboard, following and sessions on scheduled lessons', () => {
  let w: ContentWorld
  let s: EnrolledProgram
  const scope = () => ({ all: false as const, orgIds: [w.orgId], groupIds: [] })
  beforeAll(async () => {
    w = await createContentWorld()
    s = await seedEnrolledProgram(w, { lessons: 2 })
    await prisma.groupMember.create({ data: { groupId: s.groupId, memberId: s.memberId, isActive: true } })
    // Both lessons are due: their dates move to the past.
    await prisma.scheduledLesson.update({ where: { id: s.scheduledLessonIds[0] }, data: { scheduledDate: new Date(Date.now() - 3 * DAY) } })
    await prisma.scheduledLesson.update({ where: { id: s.scheduledLessonIds[1] }, data: { scheduledDate: new Date(Date.now() - 2 * DAY) } })
  })
  afterAll(async () => { await destroyContentWorld(w) })
  beforeEach(async () => { await prisma.lessonProgress.deleteMany({ where: { memberId: s.memberId } }) })

  it('engagement counts a member who completed every due scheduled lesson', async () => {
    for (const scheduledLessonId of s.scheduledLessonIds) {
      await prisma.lessonProgress.create({ data: { memberId: s.memberId, scheduledLessonId, completedAt: new Date() } })
    }
    expect(await getHomeEngagement(scope(), 'UTC')).toMatchObject({ currentCount: 1, enrolledCount: 1, groupCount: 1, percent: 100 })
  })

  it('engagement does not count a member who finished only one of two due lessons', async () => {
    await prisma.lessonProgress.create({ data: { memberId: s.memberId, scheduledLessonId: s.scheduledLessonIds[0], completedAt: new Date() } })
    expect(await getHomeEngagement(scope(), 'UTC')).toMatchObject({ currentCount: 0, enrolledCount: 1 })
  })

  it('following reports the share of due scheduled lessons completed', async () => {
    await prisma.lessonProgress.create({ data: { memberId: s.memberId, scheduledLessonId: s.scheduledLessonIds[0], completedAt: new Date() } })
    await setPreference({ userId: w.leader.userId }, FOLLOWED_ENROLLMENTS_KEY, JSON.stringify([s.enrollmentId]))
    const { programs } = await getHomeFollowing(scope(), w.leader.userId)
    expect(programs).toHaveLength(1)
    expect(programs[0].groups[0]).toMatchObject({ enrollmentId: s.enrollmentId, memberCount: 1, percent: 50 })
  })

  it('sessions draw moments from lesson progress and activity progress', async () => {
    const end = new Date()
    await prisma.lessonProgress.create({ data: { memberId: s.memberId, scheduledLessonId: s.scheduledLessonIds[0], startedAt: new Date(end.getTime() - 20 * 60_000), completedAt: end } })
    await prisma.activityProgress.create({
      data: {
        memberId: s.memberId, scheduledLessonId: s.scheduledLessonIds[0], activityKey: 'k-session',
        startedAt: new Date(end.getTime() - 10 * 60_000), completedAt: new Date(end.getTime() - 5 * 60_000),
      },
    })
    const sessions = await loadSessions(scope(), { from: new Date(end.getTime() - DAY), to: new Date(end.getTime() + DAY) }, { memberId: s.memberId })
    expect(sessions).toHaveLength(1)
    expect(sessions[0]).toMatchObject({ memberId: s.memberId, seconds: 600 })
  })

  it('sessions skip another organization’s scheduled lessons', async () => {
    await prisma.lessonProgress.create({ data: { memberId: s.memberId, scheduledLessonId: s.scheduledLessonIds[0], completedAt: new Date() } })
    const sessions = await loadSessions({ all: false, orgIds: [w.otherOrgId], groupIds: [] }, { from: new Date(Date.now() - DAY), to: new Date(Date.now() + DAY) }, { memberId: s.memberId })
    expect(sessions).toEqual([])
  })
})

describe('share previews and study codes on scheduled lessons', () => {
  let w: ContentWorld
  beforeAll(async () => { w = await createContentWorld() })
  afterAll(async () => { await destroyContentWorld(w) })

  it('a scheduled lesson code resolves with document text in the preview', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 1, text: 'quillwort preview' })
    await prisma.scheduledLesson.update({ where: { id: s.scheduledLessonIds[0] }, data: { code: 'AB12CD' } })
    const meta = await generateStudyOgMeta('AB12CD')
    expect(meta.found).toBe(true)
    expect(meta.html).toContain('quillwort preview')
  })

  it('the preview carries the lesson position and the passage of a bible activity', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 1, text: 'plain words' })
    await prisma.scheduledLesson.update({ where: { id: s.scheduledLessonIds[0] }, data: { code: 'EF34GH' } })
    const activity = await prisma.contentActivity.findFirstOrThrow({ where: { lessonVersionId: s.versionIds[0] } })
    const doc = activity.document as any
    doc.kind = 'bible'
    doc.content.passages = [{ bookNumber: 43, chapterStart: 3, verseStart: 16, chapterEnd: 3, verseEnd: 16 }]
    await prisma.contentActivity.update({ where: { id: activity.id }, data: { kind: 'bible', document: doc } })
    const html = (await generateStudyOgMeta('EF34GH')).html
    expect(html).toContain('John 3:16')
    expect(html).toMatch(/Day \d+ of/)
  })

  it('the group-code route finds the same lesson by its code', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 1, text: 'by group route' })
    await prisma.scheduledLesson.update({ where: { id: s.scheduledLessonIds[0] }, data: { code: 'JK56MN' } })
    await prisma.group.update({ where: { id: s.groupId }, data: { code: 'GRPCODE9' } })
    const meta = await generateLessonOgMeta('grpcode9', 'JK56MN')
    expect(meta.found).toBe(true)
    expect(meta.html).toContain('by group route')
  })

  it('an unknown code is not found', async () => {
    expect((await generateStudyOgMeta('ZZ99ZZ')).found).toBe(false)
  })

  it('a generated study code avoids a code a scheduled lesson holds', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 1 })
    await prisma.scheduledLesson.update({ where: { id: s.scheduledLessonIds[0] }, data: { code: 'QR78ST' } })
    const code = await generateUniqueStudyCode()
    expect(code).toMatch(/^[A-Z2-9]{6}$/)
    expect(await prisma.scheduledLesson.count({ where: { code } })).toBe(0)
  })
})
