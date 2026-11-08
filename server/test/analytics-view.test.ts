/**
 * text-activity Task 15 (SC11, SC12, D8): the `analytics_events` view on ScheduledLesson + LessonProgress + ActivityProgress,
 * its readers, and client event ingestion. Real DB (a verifier lease); the view is refreshed through the service.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { refreshAnalytics } from '../src/services/analytics.service.js'
import { getEnrollmentCompletionStats } from '../src/services/enrollment-analytics.service.js'
import { getMemberEngagement } from '../src/services/member-engagement.js'
import { bearer } from './helpers/api-auth.js'
import {
  createContentWorld, destroyContentWorld, seedEnrolledProgram, type ContentWorld, type EnrolledProgram,
} from './helpers/content-world.js'

// The (name, type) list read off `analytics_events` as 20261025200000.sql built it (pg_attribute order).
const VIEW_COLUMNS_20261025200000 = [
  ['event_id', 'text'],
  ['event_type', 'text'],
  ['occurred_at', 'timestamp with time zone'],
  ['entity_id', 'text'],
  ['member_id', 'text'],
  ['user_id', 'text'],
  ['organization_id', 'text'],
  ['group_id', 'text'],
  ['enrollment_id', 'text'],
  ['study_program_id', 'text'],
  ['lesson_schedule_id', 'text'],
  ['lesson_id', 'text'],
  ['day_number', 'integer'],
  ['scheduled_activity_id', 'text'],
  ['activity_type', 'text'],
  ['scheduled_date', 'date'],
  ['value', 'numeric'],
  ['percent', 'numeric'],
  ['is_current_version', 'boolean'],
  ['is_removed', 'boolean'],
]

async function viewColumns(view: string): Promise<string[][]> {
  const rows = await prisma.$queryRawUnsafe<{ name: string; type: string }[]>(
    `SELECT a.attname AS name, format_type(a.atttypid, a.atttypmod) AS type
       FROM pg_attribute a
      WHERE a.attrelid = $1::regclass AND a.attnum > 0 AND NOT a.attisdropped
      ORDER BY a.attnum`,
    view,
  )
  return rows.map((r) => [r.name, r.type])
}

async function viewRows(where: string, ...params: unknown[]) {
  const rows = await prisma.$queryRawUnsafe<Record<string, any>[]>(`SELECT * FROM analytics_events WHERE ${where}`, ...params)
  // numeric columns arrive as Decimal; compare them as strings
  return rows.map((r) => ({ ...r, value: r.value === null ? null : String(r.value), percent: r.percent === null ? null : String(r.percent) }))
}

const postClientEvent = (w: ContentWorld, event: Record<string, unknown>) =>
  request(app).post('/api/analytics/events').set('Authorization', bearer(w.leader.token)).send({
    events: [{ id: crypto.randomUUID(), eventType: 'LESSON_OPENED', occurredAt: new Date().toISOString(), ...event }],
  })

describe('the analytics_events view on the new model', () => {
  let w: ContentWorld
  let s: EnrolledProgram
  let activityKey: string
  const eventIds: string[] = []

  beforeAll(async () => {
    w = await createContentWorld()
    s = await seedEnrolledProgram(w, { lessons: 2 })
    activityKey = (await prisma.contentActivity.findFirstOrThrow({ where: { lessonVersionId: s.versionIds[0] } })).activityKey
  })
  afterAll(async () => {
    await prisma.clientEvent.deleteMany({ where: { id: { in: eventIds } } })
    await destroyContentWorld(w)
    await refreshAnalytics()
  })

  it('the rewritten view keeps every output column', async () => {
    const cols = await viewColumns('analytics_events')
    expect(cols).toEqual(VIEW_COLUMNS_20261025200000)
  })

  it('metrics compute to zero with empty progress tables', async () => {
    await refreshAnalytics()
    const r = await request(app).get(`/api/programs/${s.programId}/analytics`).set('Authorization', bearer(w.leader.token))
    expect(r.status).toBe(200)
    expect(r.body.kpis).toMatchObject({ lessonCompletions: 0, videoCompletions: 0, watchSeconds: 0, completionRate: 0 })
  })

  it('a client event stores the new keys', async () => {
    const r = await postClientEvent(w, { enrollmentId: s.enrollmentId, scheduledLessonId: s.scheduledLessonIds[0], activityKey, kind: 'text' })
    expect(r.body).toMatchObject({ success: true, accepted: 1, rejected: 0 })
    const row = await prisma.clientEvent.findFirst({ orderBy: { receivedAt: 'desc' } })
    eventIds.push(row!.id)
    expect(row).toMatchObject({
      scheduledLessonId: s.scheduledLessonIds[0], activityKey, kind: 'text', enrollmentId: s.enrollmentId,
      studyProgramId: s.programId, lessonId: s.lessonIds[0], dayNumber: 2,
    })
    // The 1.0 key columns were dropped at the cutover (SC11/D42): the row holds the new keys only.
    for (const old of ['lessonScheduleId', 'scheduledActivityId', 'activityType']) expect(row).not.toHaveProperty(old)
  })

  it('a client event names the kind the activity really has, whatever the client sent', async () => {
    const r = await postClientEvent(w, { scheduledLessonId: s.scheduledLessonIds[1], activityKey: (await prisma.contentActivity.findFirstOrThrow({ where: { lessonVersionId: s.versionIds[1] } })).activityKey, kind: 'video' })
    expect(r.body.accepted).toBe(1)
    const row = await prisma.clientEvent.findFirst({ orderBy: { receivedAt: 'desc' } })
    eventIds.push(row!.id)
    expect(row?.kind).toBe('text')
  })

  it('a client event on an unknown scheduled lesson is rejected', async () => {
    const r = await postClientEvent(w, { scheduledLessonId: crypto.randomUUID() })
    expect(r.body).toMatchObject({ success: true, accepted: 0, rejected: 1 })
  })

  it('a client event whose enrollment disagrees with its scheduled lesson is rejected', async () => {
    const other = await seedEnrolledProgram(w, { lessons: 1 })
    const r = await postClientEvent(w, { enrollmentId: other.enrollmentId, scheduledLessonId: s.scheduledLessonIds[0] })
    expect(r.body).toMatchObject({ accepted: 0, rejected: 1 })
  })

  it('the ce arm exposes the new keys under the old column names', async () => {
    await refreshAnalytics()
    const rows = await viewRows(`event_id = $1`, `ce:${eventIds[0]}`)
    expect(rows).toHaveLength(1)
    expect(rows[0]).toMatchObject({
      event_type: 'LESSON_OPENED', lesson_schedule_id: s.scheduledLessonIds[0], scheduled_activity_id: activityKey,
      activity_type: 'text', lesson_id: s.lessonIds[0], day_number: 2, study_program_id: s.programId,
    })
  })

  it('lesson progress and activity progress become LESSON_COMPLETED and ACTIVITY_COMPLETED rows', async () => {
    const [sl] = s.scheduledLessonIds
    await prisma.lessonProgress.create({ data: { memberId: s.memberId, scheduledLessonId: sl, completedAt: new Date() } })
    await prisma.activityProgress.create({ data: { memberId: s.memberId, scheduledLessonId: sl, activityKey, completedAt: new Date() } })
    await refreshAnalytics()
    const lc = await viewRows(`event_type = 'LESSON_COMPLETED' AND member_id = $1`, s.memberId)
    expect(lc).toHaveLength(1)
    expect(lc[0]).toMatchObject({
      lesson_schedule_id: sl, lesson_id: s.lessonIds[0], day_number: 2, enrollment_id: s.enrollmentId, group_id: s.groupId,
      organization_id: w.orgId, study_program_id: s.programId, is_current_version: true, is_removed: false, value: '1',
    })
    const ap = await viewRows(`event_type = 'ACTIVITY_COMPLETED' AND member_id = $1`, s.memberId)
    expect(ap).toHaveLength(1)
    expect(ap[0]).toMatchObject({ lesson_schedule_id: sl, scheduled_activity_id: activityKey, activity_type: 'text', is_current_version: true })
  })

  it('a video activity completes and is watched through activity progress state', async () => {
    const versionId = s.versionIds[1]
    const video = await prisma.contentActivity.create({
      data: { lessonVersionId: versionId, activityKey: 'video-key', position: 9, kind: 'video', title: 'Video', document: { schemaVersion: 1, kind: 'video' } },
    })
    await prisma.activityProgress.create({
      data: {
        memberId: s.memberId, scheduledLessonId: s.scheduledLessonIds[1], activityKey: video.activityKey, completedAt: new Date(),
        state: { watchedSeconds: 42, watchPercentage: 91 },
      },
    })
    await refreshAnalytics()
    const vc = await viewRows(`event_type = 'VIDEO_COMPLETED' AND member_id = $1`, s.memberId)
    expect(vc).toHaveLength(1)
    expect(vc[0]).toMatchObject({ activity_type: 'video', scheduled_activity_id: 'video-key' })
    const vw = await viewRows(`event_type = 'VIDEO_WATCH' AND member_id = $1`, s.memberId)
    expect(vw).toHaveLength(1)
    expect(vw[0]).toMatchObject({ value: '42', percent: '91' })
    // A video never doubles as a plain activity completion.
    expect(await viewRows(`event_type = 'ACTIVITY_COMPLETED' AND scheduled_activity_id = 'video-key'`)).toHaveLength(0)
  })

  it('a scheduled lesson expects one row per active member of its group', async () => {
    await prisma.groupMember.create({ data: { groupId: s.groupId, memberId: s.memberId, isActive: true } })
    await prisma.scheduledLesson.update({ where: { id: s.scheduledLessonIds[1] }, data: { removedAt: new Date() } })
    await refreshAnalytics()
    const rows = await viewRows(`event_type = 'LESSON_SCHEDULED' AND enrollment_id = $1 ORDER BY lesson_schedule_id`, s.enrollmentId)
    expect(rows).toHaveLength(2)
    const removed = rows.find((r) => r.lesson_schedule_id === s.scheduledLessonIds[1])
    expect(removed).toMatchObject({ is_removed: true, member_id: s.memberId, day_number: 3 })
  })

  it('enrollment completion stats count progress per scheduled lesson and activity key', async () => {
    const stats = await getEnrollmentCompletionStats(s.enrollmentId)
    expect(stats.memberCount).toBe(1)
    const lesson = stats.lessons.find((l) => l.lessonScheduleId === s.scheduledLessonIds[0])
    expect(lesson).toMatchObject({ completedCount: 1 })
    expect(lesson?.activities).toEqual([{ scheduledActivityId: activityKey, completedCount: 1 }])
    // The lesson removed above is not reported.
    expect(stats.lessons.find((l) => l.lessonScheduleId === s.scheduledLessonIds[1])).toBeUndefined()
  })

  it('member engagement reads lesson progress and activity progress', async () => {
    const out = await getMemberEngagement(s.memberId, { kind: 'self' }, 'UTC')
    expect(out?.programs).toHaveLength(1)
    expect(out?.programs[0]).toMatchObject({ enrollmentId: s.enrollmentId, completedCount: 1, totalCount: 1 })
  })
})
