/**
 * text-activity Task 11 (§Contract enrollment rows, SC10): enrollments schedule `ScheduledLesson`s on the program
 * version's lesson versions, and every "same shape" read keeps today's keys while reading from them.
 * Real DB + API-key auth.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { bearer } from './helpers/api-auth.js'
import {
  createContentWorld, createGroupWithMember, createMedia, destroyContentWorld, seedEnrolledProgram, seedPublishedProgram,
  type ContentWorld,
} from './helpers/content-world.js'

/** Today's top-level keys of GET /api/enrollments/:id/home (enrollment-home.test.ts asserts the whole payload). */
const HOME_KEYS_TODAY = ['home', 'success']
const HOME_BODY_KEYS_TODAY = [
  'days', 'endDate', 'enrolledAt', 'group', 'id', 'lessonAccess', 'lessons', 'memberCount', 'smsTime', 'startDate', 'studyProgram', 'timezone',
]
/** Today's keys of one `lessonSchedules[]` row of GET /api/enrollments/:id (LessonSchedule's columns plus the nested lesson). */
const SCHEDULE_KEYS_TODAY = [
  'code', 'currentVersionId', 'enrollmentId', 'estimatedMinutes', 'id', 'lesson', 'lessonId', 'removedAt', 'scheduledActivities',
  'scheduledDate', 'smsSentAt', 'templateId', 'templateName', 'title',
]

describe('enrollments on scheduled lessons', () => {
  let w: ContentWorld

  beforeAll(async () => {
    w = await createContentWorld()
  })
  afterAll(async () => {
    await destroyContentWorld(w)
  })

  const enroll = async (programId: string, extra: Record<string, unknown> = {}) => {
    const { groupId } = await createGroupWithMember(w)
    return request(app).post('/api/enrollments').set('Authorization', bearer(w.leader.token)).send({
      groupId, studyProgramId: programId, startDate: new Date().toISOString(),
      enabledDays: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'], ...extra,
    })
  }
  const get = (path: string) => request(app).get(path).set('Authorization', bearer(w.leader.token))
  const findFirstActivity = (body: any) => body.home.lessons[0].activities[0]

  it("enroll points scheduled lessons at the program version's lessons", async () => {
    const s = await seedPublishedProgram(w, { lessons: 2 })
    const r = await enroll(s.programId)
    expect(r.status).toBe(200)
    const rows = await prisma.scheduledLesson.findMany({ where: { enrollmentId: r.body.id ?? r.body.enrollment.id }, orderBy: { scheduledDate: 'asc' } })
    expect(rows.map(x => x.currentVersionId)).toEqual(s.versionIds)
    const enrollment = await prisma.enrollment.findUniqueOrThrow({ where: { id: r.body.enrollment.id } })
    expect(enrollment.programVersionId).toBe(s.programVersionId)
    expect(r.body.enrollment._count).toEqual({ lessonSchedules: 2, events: 2 })
    // One calendar event per lesson: enroll does not create them again on top of createScheduledLessons.
    expect(await prisma.event.count({ where: { enrollmentId: enrollment.id, type: 'LESSON' } })).toBe(2)
  })

  it('enroll refuses a program with no published version', async () => {
    const program = await prisma.studyProgram.create({
      data: { name: 'Unpublished', days: 1, creatorId: w.leader.userId, organizationId: w.orgId },
    })
    const r = await enroll(program.id)
    expect(r.status).toBe(400)
    expect(r.body).toMatchObject({ success: false, error: 'Publish this program before enrolling a group', code: 'VALIDATION' })
    await prisma.studyProgram.delete({ where: { id: program.id } })
  })

  it('GET /enrollments/:id keeps the lessonSchedules keys, with title and minutes from the version', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 1 })
    await prisma.lessonVersion.update({ where: { id: s.versionIds[0] }, data: { title: 'Day one', estimatedSeconds: 61 } })
    const r = await get(`/api/enrollments/${s.enrollmentId}`)
    expect(r.status).toBe(200)
    const row = r.body.enrollment.lessonSchedules[0]
    expect(Object.keys(row).sort()).toEqual(SCHEDULE_KEYS_TODAY)
    expect(row).toMatchObject({ id: s.scheduledLessonIds[0], title: 'Day one', estimatedMinutes: 2, currentVersionId: s.versionIds[0], templateName: null })
    const lesson = await prisma.lesson.findUniqueOrThrow({ where: { id: s.lessonIds[0] } })
    expect(row.lesson).toMatchObject({ id: s.lessonIds[0], dayNumber: lesson.position, title: 'Day one', studyProgramId: w.programId })
    expect(row.scheduledActivities.map((a: any) => a.kind)).toEqual(['text'])
    expect(row.lesson.activities).toEqual(row.scheduledActivities)
  })

  it("home keeps today's keys with kind as type and the document's thumbnail", async () => {
    const m = await createMedia(w.orgId)
    const s = await seedEnrolledProgram(w, { lessons: 1, mediaId: m.id })
    const r = await request(app).get(`/api/enrollments/${s.enrollmentId}/home`).set('Authorization', bearer(w.leader.token))
    expect(Object.keys(r.body).sort()).toEqual(HOME_KEYS_TODAY)
    expect(Object.keys(r.body.home).sort()).toEqual(HOME_BODY_KEYS_TODAY)
    const act = findFirstActivity(r.body)
    expect(act).toMatchObject({ type: 'text', thumbnailUrl: m.url })
  })

  it('an SMS-sent lesson does not move when the enrollment is rescheduled', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 2 })
    const before = await prisma.scheduledLesson.findMany({ where: { enrollmentId: s.enrollmentId }, orderBy: { scheduledDate: 'asc' } })
    await prisma.scheduledLesson.update({ where: { id: s.scheduledLessonIds[0] }, data: { smsSentAt: new Date() } })
    const startDate = new Date(Date.now() + 10 * 86_400_000).toISOString()
    const r = await request(app).post(`/api/enrollments/${s.enrollmentId}/edit/preview`).set('Authorization', bearer(w.leader.token)).send({ startDate })
    expect(r.body.preview.reschedule).toEqual({ lessonsShifted: 1, lockedUnchanged: 1 })
    const patched = await request(app).patch(`/api/enrollments/${s.enrollmentId}`).set('Authorization', bearer(w.leader.token)).send({ startDate })
    expect(patched.status).toBe(200)
    const after = await prisma.scheduledLesson.findMany({ where: { enrollmentId: s.enrollmentId }, orderBy: { id: 'asc' } })
    const byId = new Map(after.map((x) => [x.id, x.scheduledDate.getTime()]))
    expect(byId.get(s.scheduledLessonIds[0])).toBe(before.find((x) => x.id === s.scheduledLessonIds[0])!.scheduledDate.getTime())
    expect(byId.get(s.scheduledLessonIds[1])).not.toBe(before.find((x) => x.id === s.scheduledLessonIds[1])!.scheduledDate.getTime())
  })

  it("next-study thumbnail comes from the next lesson's first document", async () => {
    const m = await createMedia(w.orgId)
    const s = await seedEnrolledProgram(w, { lessons: 1, mediaId: m.id })
    const r = await request(app).get(`/api/groups/${s.groupId}/next-study`).set('Authorization', bearer(w.leader.token))
    expect(r.status).toBe(200)
    expect(JSON.stringify(r.body)).toContain(m.url)
    const lesson = await prisma.lesson.findUniqueOrThrow({ where: { id: s.lessonIds[0] } })
    expect(r.body.study).toMatchObject({ id: s.scheduledLessonIds[0], dayNumber: lesson.position })
    expect(r.body.study.activities[0]).toMatchObject({ type: 'text', orderNumber: 1, thumbnailUrl: m.url })
  })

  it('next-study skips a removed lesson', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 2 })
    await prisma.scheduledLesson.update({ where: { id: s.scheduledLessonIds[0] }, data: { removedAt: new Date() } })
    const r = await get(`/api/groups/${s.groupId}/next-study`)
    expect(r.body.study.id).toBe(s.scheduledLessonIds[1])
  })

  it('schedule add schedules a lesson not yet scheduled, on the program version; delete removes it and its event', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 2 })
    const del = await request(app)
      .delete(`/api/enrollments/${s.enrollmentId}/schedules/${s.scheduledLessonIds[1]}`).set('Authorization', bearer(w.leader.token))
    expect(del.status).toBe(200)
    expect(await prisma.scheduledLesson.count({ where: { enrollmentId: s.enrollmentId } })).toBe(1)
    expect(await prisma.event.count({ where: { scheduledLessonId: s.scheduledLessonIds[1] } })).toBe(0)
    // Deleting a day from the enrollment deletes the curriculum lesson, as it always did (D36 closes the program up).
    expect((await prisma.lesson.findUniqueOrThrow({ where: { id: s.lessonIds[1] } })).deletedAt).not.toBeNull()

    const dup = await request(app)
      .post(`/api/enrollments/${s.enrollmentId}/schedules`).set('Authorization', bearer(w.leader.token)).send({ lessonId: s.lessonIds[0] })
    expect(dup.status).toBe(409)
  })

  it('schedule add puts an unscheduled lesson on the version the enrollment is synced to', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 2 })
    await prisma.event.deleteMany({ where: { scheduledLessonId: s.scheduledLessonIds[1] } })
    await prisma.scheduledLesson.delete({ where: { id: s.scheduledLessonIds[1] } })
    const r = await request(app)
      .post(`/api/enrollments/${s.enrollmentId}/schedules`).set('Authorization', bearer(w.leader.token)).send({ lessonId: s.lessonIds[1] })
    expect(r.status).toBe(200)
    expect(r.body.schedule).toMatchObject({ lessonId: s.lessonIds[1], currentVersionId: s.versionIds[1] })
    expect(await prisma.event.count({ where: { enrollmentId: s.enrollmentId, scheduledLessonId: r.body.schedule.id } })).toBe(1)
  })

  it('schedule patch edits the title on a group-owned version, which sync then leaves alone', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 1 })
    const r = await request(app)
      .patch(`/api/enrollments/${s.enrollmentId}/schedules/${s.scheduledLessonIds[0]}`).set('Authorization', bearer(w.leader.token)).send({ title: 'Our title' })
    expect(r.status).toBe(200)
    expect(r.body.schedule).toMatchObject({ id: s.scheduledLessonIds[0], title: 'Our title' })
    const row = await prisma.scheduledLesson.findUniqueOrThrow({
      where: { id: s.scheduledLessonIds[0] }, include: { currentVersion: { include: { activities: true } } },
    })
    expect(row.currentVersionId).not.toBe(s.versionIds[0])
    expect(row.currentVersion).toMatchObject({ enrollmentId: s.enrollmentId, status: 'PUBLISHED', title: 'Our title', basedOnVersionId: s.versionIds[0] })
    const original = await prisma.contentActivity.findMany({ where: { lessonVersionId: s.versionIds[0] } })
    expect(row.currentVersion.activities.map((a) => a.activityKey)).toEqual(original.map((a) => a.activityKey))
    // The program's own version keeps its title.
    expect((await prisma.lessonVersion.findUniqueOrThrow({ where: { id: s.versionIds[0] } })).title).toBe('Published day')
  })

  it('404s a schedule edit outside the leader\'s enrollments', async () => {
    const s = await seedEnrolledProgram(w, { lessons: 1 })
    const r = await request(app)
      .patch(`/api/enrollments/${s.enrollmentId}/schedules/${s.scheduledLessonIds[0]}`).set('Authorization', bearer(w.outsider.token)).send({ title: 'x' })
    expect(r.status).toBe(404)
  })
})
