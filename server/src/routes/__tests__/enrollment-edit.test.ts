/**
 * Enrollment edit tests (monday#12270302158) — reschedule, group change, and
 * the dry-run preview. Study-program swap is covered in a follow-up.
 *
 * Uses a far-future start date so no schedule is auto-locked by a passed date,
 * letting the tests exercise the reschedule walk deterministically. Auth goes
 * through the real API-key path (no middleware mocks).
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import request from 'supertest'
import { app } from '../../index'
import { prisma } from '../../lib/prisma'
import { generateApiKey, hashApiKey, getKeyPrefix } from '../../lib/api-key'
import { applyEnrollmentEdit, applyStudySwap, EnrollmentEditError } from '../../services/enrollment-edit'
import { buildEnrollmentManageChecker } from '../../services/permission'

// A program written straight to the new model: one Lesson per title, each with a PUBLISHED version holding one
// activity, all in ProgramVersion 1 (the program's current version). `published: false` leaves a draft program.
async function createSimpleProgram(opts: {
  name: string; creatorId: string; templateId?: string; titles: string[]; published?: boolean
}) {
  const published = opts.published ?? true
  const program = await prisma.studyProgram.create({
    data: {
      name: opts.name, days: opts.titles.length, creatorId: opts.creatorId, templateId: opts.templateId,
      isPublished: published, publishedAt: published ? new Date() : null,
    },
  })
  const lessons: { lessonId: string; lessonVersionId: string; position: number }[] = []
  for (const [i, title] of opts.titles.entries()) {
    const lesson = await prisma.lesson.create({ data: { programId: program.id, position: i + 1 } })
    const version = await prisma.lessonVersion.create({
      data: {
        lessonId: lesson.id, number: 1, status: 'PUBLISHED', title, publishedAt: new Date(),
        activities: {
          create: [{
            activityKey: `${program.id}-${i}`, position: 1, kind: 'text', title: `Activity ${i + 1}`,
            document: { schemaVersion: 1, kind: 'text', background: { color: '#000' }, content: { type: 'canvas', objects: [] }, actions: [], chrome: { topAction: 'none' }, fallback: { title: 'x', body: 'y' } },
          }],
        },
      },
    })
    lessons.push({ lessonId: lesson.id, lessonVersionId: version.id, position: i + 1 })
  }
  if (published) {
    const pv = await prisma.programVersion.create({ data: { programId: program.id, number: 1, lessons: { create: lessons } } })
    await prisma.studyProgram.update({ where: { id: program.id }, data: { currentVersionId: pv.id } })
  }
  return { programId: program.id }
}

async function destroySimplePrograms(programIds: string[]) {
  await prisma.enrollment.deleteMany({ where: { studyProgramId: { in: programIds } } })
  await prisma.studyProgram.updateMany({ where: { id: { in: programIds } }, data: { currentVersionId: null } })
  await prisma.programVersionLesson.deleteMany({ where: { programVersion: { programId: { in: programIds } } } })
  await prisma.programVersion.deleteMany({ where: { programId: { in: programIds } } })
  await prisma.lesson.deleteMany({ where: { programId: { in: programIds } } })
  await prisma.studyProgram.deleteMany({ where: { id: { in: programIds } } })
}

// A Monday well into the future — enabledDays: all week ⇒ schedules land on
// consecutive days starting here.
const START = '2035-01-01T12:00:00.000Z' // 2035-01-01 is a Monday
const ALL_DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

describe('Enrollment edit (reschedule / group change / preview)', () => {
  let userId: string
  let organizationId: string
  let groupId: string
  let otherGroupId: string
  let programId: string
  let programBId: string
  let richProgramId: string
  let draftProgramId: string
  let emptyProgramId: string
  let templateId: string
  let memberId: string
  let apiKey: string
  const RANDOM_UUID = '00000000-0000-4000-8000-000000000000'

  const authed = () => ({ Authorization: `Bearer ${apiKey}` })

  async function enroll(overrides: Record<string, unknown> = {}): Promise<string> {
    const res = await request(app)
      .post('/api/enrollments')
      .set(authed())
      .send({ groupId, studyProgramId: programId, startDate: START, enabledDays: ALL_DAYS, ...overrides })
    expect(res.status, JSON.stringify(res.body)).toBe(200)
    return res.body.enrollment.id
  }

  async function schedulesFor(enrollmentId: string) {
    return prisma.scheduledLesson.findMany({
      where: { enrollmentId, removedAt: null },
      include: { lesson: { select: { position: true } }, currentVersion: { select: { title: true } }, event: true },
      orderBy: { scheduledDate: 'asc' },
    })
  }

  beforeAll(async () => {
    const stamp = Date.now()
    const user = await prisma.user.create({
      data: { googleId: `edit-test-${stamp}`, email: `edit-test-${stamp}@makeready.test`, name: 'Edit Test Leader' },
    })
    userId = user.id

    apiKey = generateApiKey()
    await prisma.apiKey.create({
      data: { keyHash: hashApiKey(apiKey), keyPrefix: getKeyPrefix(apiKey), name: 'enrollment-edit test key', userId },
    })

    const organization = await prisma.organization.create({ data: { name: 'Edit Test Org', ownerId: userId } })
    organizationId = organization.id

    const group = await prisma.group.create({ data: { name: 'Edit Test Group', creatorId: userId, organizationId } })
    groupId = group.id
    const other = await prisma.group.create({ data: { name: 'Edit Test Group 2', creatorId: userId, organizationId } })
    otherGroupId = other.id

    programId = (await createSimpleProgram({ name: 'Edit Test Program', creatorId: userId, titles: ['Day 1', 'Day 2', 'Day 3'] })).programId

    // Program B: a DIFFERENT curriculum (2 lessons) to swap to.
    programBId = (await createSimpleProgram({ name: 'Edit Test Program B', creatorId: userId, titles: ['B Day 1', 'B Day 2'] })).programId

    // A swap target with a template: its scheduled lessons carry the template.
    templateId = (await prisma.lessonTemplate.create({ data: { name: 'Rich Template', creatorId: userId } })).id
    richProgramId = (await createSimpleProgram({ name: 'Edit Test Rich', creatorId: userId, templateId, titles: ['Rich Day 1'] })).programId

    // A DRAFT program (unpublished, no current version) and a published-but-empty program — swap targets that must be rejected.
    draftProgramId = (await createSimpleProgram({ name: 'Edit Test Draft', creatorId: userId, titles: ['Draft Day 1'], published: false })).programId
    emptyProgramId = (await createSimpleProgram({ name: 'Edit Test Empty', creatorId: userId, titles: [] })).programId

    const member = await prisma.member.create({
      data: { phoneNumber: `+1555${String(stamp).slice(-7)}`, firstName: 'Prog', lastName: 'Member' },
    })
    memberId = member.id
    // ui2-enrollment-create D5: POST refuses a group with no active member.
    await prisma.groupMember.create({ data: { groupId, memberId, isActive: true } })
  })

  afterAll(async () => {
    await prisma.member.deleteMany({ where: { id: memberId } })
    await prisma.group.deleteMany({ where: { id: { in: [groupId, otherGroupId] } } })
    await destroySimplePrograms([programId, programBId, richProgramId, draftProgramId, emptyProgramId])
    await prisma.lessonTemplate.deleteMany({ where: { creatorId: userId } })
    await prisma.organization.deleteMany({ where: { id: organizationId } })
    await prisma.user.deleteMany({ where: { id: userId } })
  })

  it('reschedules all lessons when the start date changes', async () => {
    const enrollmentId = await enroll()
    const before = await schedulesFor(enrollmentId)
    expect(before).toHaveLength(3)
    // Consecutive days from START (all days enabled)
    expect(before[0].scheduledDate.toISOString().slice(0, 10)).toBe('2035-01-01')

    const newStart = '2035-02-10T12:00:00.000Z'
    const res = await request(app)
      .patch(`/api/enrollments/${enrollmentId}`)
      .set(authed())
      .send({ startDate: newStart })
    expect(res.status).toBe(200)

    const after = await schedulesFor(enrollmentId)
    expect(after.map((s) => s.scheduledDate.toISOString().slice(0, 10))).toEqual([
      '2035-02-10',
      '2035-02-11',
      '2035-02-12',
    ])
    // Calendar events moved with their schedules
    expect(after[0].event?.date.toISOString().slice(0, 10)).toBe('2035-02-10')
    // endDate recomputed
    const enrollment = await prisma.enrollment.findUniqueOrThrow({ where: { id: enrollmentId } })
    expect(enrollment.endDate?.toISOString().slice(0, 10)).toBe('2035-02-12')

    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('re-lays lessons on the new enabled weekdays', async () => {
    const enrollmentId = await enroll()
    // Only Mondays enabled ⇒ 3 lessons on 3 consecutive Mondays from START
    const res = await request(app)
      .patch(`/api/enrollments/${enrollmentId}`)
      .set(authed())
      .send({ enabledDays: ['Mon'] })
    expect(res.status).toBe(200)

    const after = await schedulesFor(enrollmentId)
    const dates = after.map((s) => s.scheduledDate.toISOString().slice(0, 10))
    expect(dates).toEqual(['2035-01-01', '2035-01-08', '2035-01-15']) // Mondays
    const enrollment = await prisma.enrollment.findUniqueOrThrow({ where: { id: enrollmentId } })
    expect(JSON.parse(enrollment.enabledDays!)).toEqual(['Mon'])

    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('does not move a locked (already-sent) lesson', async () => {
    const enrollmentId = await enroll()
    const before = await schedulesFor(enrollmentId)
    // Lock the first lesson as if its SMS already went out.
    await prisma.scheduledLesson.update({ where: { id: before[0].id }, data: { smsSentAt: new Date() } })

    const res = await request(app)
      .patch(`/api/enrollments/${enrollmentId}`)
      .set(authed())
      .send({ startDate: '2035-06-01T12:00:00.000Z' })
    expect(res.status).toBe(200)

    const after = await schedulesFor(enrollmentId)
    const byId = new Map(after.map((s) => [s.id, s]))
    // Locked lesson keeps its original date...
    expect(byId.get(before[0].id)!.scheduledDate.toISOString().slice(0, 10)).toBe('2035-01-01')
    // ...the two unlocked lessons re-lay after the new start date.
    const unlocked = after
      .filter((s) => s.id !== before[0].id)
      .map((s) => s.scheduledDate.toISOString().slice(0, 10))
      .sort()
    expect(unlocked).toEqual(['2035-06-01', '2035-06-02'])

    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('changes the enrollment group and re-homes its events', async () => {
    const enrollmentId = await enroll()
    const res = await request(app)
      .patch(`/api/enrollments/${enrollmentId}`)
      .set(authed())
      .send({ groupId: otherGroupId })
    expect(res.status).toBe(200)

    const enrollment = await prisma.enrollment.findUniqueOrThrow({ where: { id: enrollmentId } })
    expect(enrollment.groupId).toBe(otherGroupId)
    const events = await prisma.event.findMany({ where: { enrollmentId } })
    expect(events.length).toBeGreaterThan(0)
    expect(events.every((e) => e.groupId === otherGroupId)).toBe(true)

    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('applies scalar fields alongside a structural edit', async () => {
    const enrollmentId = await enroll({ requireResponse: false })
    const res = await request(app)
      .patch(`/api/enrollments/${enrollmentId}`)
      .set(authed())
      .send({ startDate: '2035-03-03T12:00:00.000Z', requireResponse: true })
    expect(res.status).toBe(200)

    const enrollment = await prisma.enrollment.findUniqueOrThrow({ where: { id: enrollmentId } })
    expect(enrollment.requireResponse).toBe(true)
    expect(enrollment.startDate.toISOString().slice(0, 10)).toBe('2035-03-03')

    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('previews a reschedule as non-destructive with a shift count', async () => {
    const enrollmentId = await enroll()
    const res = await request(app)
      .post(`/api/enrollments/${enrollmentId}/edit/preview`)
      .set(authed())
      .send({ startDate: '2035-04-04T12:00:00.000Z' })
    expect(res.status).toBe(200)
    expect(res.body.preview.destructive).toBe(false)
    expect(res.body.preview.reschedule.lessonsShifted).toBe(3)
    expect(res.body.preview.studySwap).toBeNull()
    expect(res.body.preview.summary.length).toBeGreaterThan(0)

    // Preview must NOT have mutated anything.
    const after = await schedulesFor(enrollmentId)
    expect(after[0].scheduledDate.toISOString().slice(0, 10)).toBe('2035-01-01')

    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('previews a partial-lock reschedule noting sent lessons will not move', async () => {
    const enrollmentId = await enroll()
    const before = await schedulesFor(enrollmentId)
    // Lock only the first lesson; the other two can still shift.
    await prisma.scheduledLesson.update({ where: { id: before[0].id }, data: { smsSentAt: new Date() } })

    const res = await request(app)
      .post(`/api/enrollments/${enrollmentId}/edit/preview`)
      .set(authed())
      .send({ startDate: '2035-08-08T12:00:00.000Z' })
    expect(res.status).toBe(200)
    expect(res.body.preview.reschedule).toEqual({ lessonsShifted: 2, lockedUnchanged: 1 })
    expect(res.body.preview.summary.join(' ')).toMatch(/1 already sent will not move/i)
    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('previews a group change with from/to names', async () => {
    const enrollmentId = await enroll()
    const res = await request(app)
      .post(`/api/enrollments/${enrollmentId}/edit/preview`)
      .set(authed())
      .send({ groupId: otherGroupId })
    expect(res.status).toBe(200)
    expect(res.body.preview.groupChange).toEqual({ fromName: 'Edit Test Group', toName: 'Edit Test Group 2' })

    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('swaps the study program — removes old lessons, builds new from the target', async () => {
    const enrollmentId = await enroll() // program A: 3 lessons
    const beforeA = await schedulesFor(enrollmentId)
    expect(beforeA).toHaveLength(3)
    const oldScheduleIds = beforeA.map((s) => s.id)

    const res = await request(app)
      .patch(`/api/enrollments/${enrollmentId}`)
      .set(authed())
      .send({ studyProgramId: programBId })
    expect(res.status).toBe(200)

    const enrollment = await prisma.enrollment.findUniqueOrThrow({ where: { id: enrollmentId } })
    expect(enrollment.studyProgramId).toBe(programBId)

    // Old (no-progress) schedules hard-deleted
    const survivingOld = await prisma.scheduledLesson.findMany({ where: { id: { in: oldScheduleIds } } })
    expect(survivingOld).toHaveLength(0)

    // New schedules from program B (2 lessons), titled "B Day N", dates from start
    const after = await schedulesFor(enrollmentId)
    expect(after).toHaveLength(2)
    expect(after.map((s) => s.currentVersion.title)).toEqual(['B Day 1', 'B Day 2'])
    expect(after.map((s) => s.scheduledDate.toISOString().slice(0, 10))).toEqual(['2035-01-01', '2035-01-02'])
    // Each new schedule points at the target's lesson version, with its activity and a calendar event
    for (const s of after) {
      expect(s.event).not.toBeNull()
      expect(s.currentVersionId).not.toBeNull()
    }
    const activities = await prisma.contentActivity.count({
      where: { lessonVersionId: { in: after.map((s) => s.currentVersionId) } },
    })
    expect(activities).toBe(2)
    const targetProgram = await prisma.studyProgram.findUniqueOrThrow({ where: { id: programBId } })
    expect(enrollment.programVersionId).toBe(targetProgram.currentVersionId)

    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('soft-removes an old lesson that has member progress (keeps history)', async () => {
    const enrollmentId = await enroll() // program A: 3 lessons
    const beforeA = await schedulesFor(enrollmentId)
    // Give lesson 1 member progress so it must be preserved.
    const progressedId = beforeA[0].id
    await prisma.lessonProgress.create({
      data: { memberId, scheduledLessonId: progressedId, completedAt: new Date() },
    })

    const res = await request(app)
      .patch(`/api/enrollments/${enrollmentId}`)
      .set(authed())
      .send({ studyProgramId: programBId })
    expect(res.status).toBe(200)

    // Progressed schedule kept but soft-removed (removedAt set)
    const progressed = await prisma.scheduledLesson.findUnique({ where: { id: progressedId } })
    expect(progressed).not.toBeNull()
    expect(progressed!.removedAt).not.toBeNull()
    // The other two (no progress) were hard-deleted
    const otherOld = await prisma.scheduledLesson.findMany({
      where: { id: { in: [beforeA[1].id, beforeA[2].id] } },
    })
    expect(otherOld).toHaveLength(0)
    // New B schedules present (active)
    const active = await schedulesFor(enrollmentId)
    expect(active.map((s) => s.currentVersion.title)).toEqual(['B Day 1', 'B Day 2'])

    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('previews a study swap as destructive with removed/archived/added counts', async () => {
    const enrollmentId = await enroll()
    const beforeA = await schedulesFor(enrollmentId)
    // One progressed lesson ⇒ 1 archived, 2 removed, 2 added.
    await prisma.lessonProgress.create({
      data: { memberId, scheduledLessonId: beforeA[1].id, completedAt: new Date() },
    })

    const res = await request(app)
      .post(`/api/enrollments/${enrollmentId}/edit/preview`)
      .set(authed())
      .send({ studyProgramId: programBId })
    expect(res.status).toBe(200)
    expect(res.body.preview.destructive).toBe(true)
    expect(res.body.preview.studySwap).toMatchObject({
      lessonsRemoved: 2,
      lessonsArchived: 1,
      lessonsAdded: 2,
    })
    // Preview did not mutate
    expect(await schedulesFor(enrollmentId)).toHaveLength(3)

    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  // ── Validation / error branches ───────────────────────────────────────────

  it('rejects a study swap to a DRAFT program (400) via patch and preview', async () => {
    const enrollmentId = await enroll()
    for (const path of [`/api/enrollments/${enrollmentId}`, `/api/enrollments/${enrollmentId}/edit/preview`]) {
      const method = path.endsWith('preview') ? 'post' : 'patch'
      const res = await (request(app) as any)[method](path).set(authed()).send({ studyProgramId: draftProgramId })
      expect(res.status).toBe(400)
      expect(res.body.error).toMatch(/draft/i)
    }
    // Unchanged
    const enrollment = await prisma.enrollment.findUniqueOrThrow({ where: { id: enrollmentId } })
    expect(enrollment.studyProgramId).toBe(programId)
    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('rejects a study swap to a program with no lessons (400)', async () => {
    const enrollmentId = await enroll()
    const res = await request(app)
      .patch(`/api/enrollments/${enrollmentId}`)
      .set(authed())
      .send({ studyProgramId: emptyProgramId })
    expect(res.status).toBe(400)
    expect(res.body.error).toMatch(/no lessons/i)
    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('rejects a study swap to a nonexistent program (404)', async () => {
    const enrollmentId = await enroll()
    const res = await request(app)
      .patch(`/api/enrollments/${enrollmentId}`)
      .set(authed())
      .send({ studyProgramId: RANDOM_UUID })
    expect(res.status).toBe(404)
    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('rejects a group change to a nonexistent group (404)', async () => {
    const enrollmentId = await enroll()
    const res = await request(app)
      .patch(`/api/enrollments/${enrollmentId}`)
      .set(authed())
      .send({ groupId: RANDOM_UUID })
    expect(res.status).toBe(404)
    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('rejects a study swap bundled with a nonexistent group (404)', async () => {
    const enrollmentId = await enroll()
    const res = await request(app)
      .patch(`/api/enrollments/${enrollmentId}`)
      .set(authed())
      .send({ studyProgramId: programBId, groupId: RANDOM_UUID })
    expect(res.status).toBe(404)
    // Study must NOT have swapped (validation happens before mutation)
    const enrollment = await prisma.enrollment.findUniqueOrThrow({ where: { id: enrollmentId } })
    expect(enrollment.studyProgramId).toBe(programId)
    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('rejects a reschedule when stored enabledDays is malformed and none provided (400)', async () => {
    const enrollmentId = await enroll()
    // Corrupt the stored value so parseEnabledDays yields [].
    await prisma.enrollment.update({ where: { id: enrollmentId }, data: { enabledDays: 'not-json' } })
    const res = await request(app)
      .patch(`/api/enrollments/${enrollmentId}`)
      .set(authed())
      .send({ startDate: '2035-05-05T12:00:00.000Z' })
    expect(res.status).toBe(400)
    expect(res.body.error).toMatch(/day of the week/i)
    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('previews an empty edit with the default (non-destructive) summary', async () => {
    const enrollmentId = await enroll()
    const res = await request(app)
      .post(`/api/enrollments/${enrollmentId}/edit/preview`)
      .set(authed())
      .send({})
    expect(res.status).toBe(200)
    expect(res.body.preview.destructive).toBe(false)
    expect(res.body.preview.summary).toEqual(['This will update the existing enrollment to match your changes.'])
    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('previews a study swap with NO progress as all-removed (0 archived)', async () => {
    const enrollmentId = await enroll()
    const res = await request(app)
      .post(`/api/enrollments/${enrollmentId}/edit/preview`)
      .set(authed())
      .send({ studyProgramId: programBId })
    expect(res.status).toBe(200)
    expect(res.body.preview.studySwap).toMatchObject({ lessonsRemoved: 3, lessonsArchived: 0, lessonsAdded: 2 })
    expect(res.body.preview.summary.join(' ')).not.toMatch(/archived/i)
    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('swaps study AND changes group in one edit (events re-homed to new group)', async () => {
    const enrollmentId = await enroll()
    const res = await request(app)
      .patch(`/api/enrollments/${enrollmentId}`)
      .set(authed())
      .send({ studyProgramId: programBId, groupId: otherGroupId, startDate: '2035-07-07T12:00:00.000Z' })
    expect(res.status).toBe(200)

    const enrollment = await prisma.enrollment.findUniqueOrThrow({ where: { id: enrollmentId } })
    expect(enrollment.studyProgramId).toBe(programBId)
    expect(enrollment.groupId).toBe(otherGroupId)
    // New B lessons start at the EDITED start date, not the original.
    const after = await schedulesFor(enrollmentId)
    expect(after.map((s) => s.scheduledDate.toISOString().slice(0, 10))).toEqual(['2035-07-07', '2035-07-08'])
    const events = await prisma.event.findMany({ where: { enrollmentId } })
    expect(events.every((e) => e.groupId === otherGroupId)).toBe(true)
    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('treats an all-locked reschedule as a no-op', async () => {
    const enrollmentId = await enroll()
    const before = await schedulesFor(enrollmentId)
    await prisma.scheduledLesson.updateMany({
      where: { id: { in: before.map((s) => s.id) } },
      data: { smsSentAt: new Date() },
    })
    const res = await request(app)
      .post(`/api/enrollments/${enrollmentId}/edit/preview`)
      .set(authed())
      .send({ startDate: '2035-09-09T12:00:00.000Z' })
    expect(res.status).toBe(200)
    // Still a no-op — nothing shifts — but the preview now SAYS so rather than
    // staying null, so the confirm dialog can't imply the dates will change
    // (monday#12661792842, f8df609). Asserting the shape, not just non-null,
    // keeps this test honest about which half is the no-op.
    expect(res.body.preview.reschedule).toEqual({
      lessonsShifted: 0,
      lockedUnchanged: before.length,
    })
    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('returns 404 for a nonexistent enrollment', async () => {
    const res = await request(app)
      .patch(`/api/enrollments/${RANDOM_UUID}`)
      .set(authed())
      .send({ startDate: '2035-01-01T12:00:00.000Z' })
    expect(res.status).toBe(404)
  })

  // ── Defensive service guards (reached only by direct call) ─────────────────

  it('applyEnrollmentEdit refuses a study swap (delegated to applyStudySwap)', async () => {
    const enrollmentId = await enroll()
    await expect(
      applyEnrollmentEdit(enrollmentId, { studyProgramId: programBId }, userId)
    ).rejects.toBeInstanceOf(EnrollmentEditError)
    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('applyStudySwap requires a different study program', async () => {
    const enrollmentId = await enroll()
    await expect(
      applyStudySwap(enrollmentId, { studyProgramId: programId }, userId)
    ).rejects.toBeInstanceOf(EnrollmentEditError)
    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('previews a swap to an empty program as an error (400)', async () => {
    const enrollmentId = await enroll()
    const res = await request(app)
      .post(`/api/enrollments/${enrollmentId}/edit/preview`)
      .set(authed())
      .send({ studyProgramId: emptyProgramId })
    expect(res.status).toBe(400)
    expect(res.body.error).toMatch(/no lessons/i)
    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('carries the target program\'s template onto the new scheduled lessons on a swap', async () => {
    const enrollmentId = await enroll()
    const res = await request(app)
      .patch(`/api/enrollments/${enrollmentId}`)
      .set(authed())
      .send({ studyProgramId: richProgramId })
    expect(res.status).toBe(200)

    const after = await schedulesFor(enrollmentId)
    expect(after).toHaveLength(1)
    expect(after[0].templateId).toBe(templateId)
    const activities = await prisma.contentActivity.count({ where: { lessonVersionId: after[0].currentVersionId } })
    expect(activities).toBe(1)
    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('rejects a study swap when resolved enabledDays is empty (400)', async () => {
    const enrollmentId = await enroll()
    await prisma.enrollment.update({ where: { id: enrollmentId }, data: { enabledDays: 'not-json' } })
    const res = await request(app)
      .patch(`/api/enrollments/${enrollmentId}`)
      .set(authed())
      .send({ studyProgramId: programBId }) // no enabledDays ⇒ parse stored ⇒ []
    expect(res.status).toBe(400)
    expect(res.body.error).toMatch(/day of the week/i)
    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  // ── canManage flag (drives the client's disabled "Edit enrollment") ────────

  it('stamps canManage=true on the group enrollments list for the owner', async () => {
    const enrollmentId = await enroll()
    const res = await request(app).get(`/api/groups/${groupId}/enrollments`).set(authed())
    expect(res.status).toBe(200)
    const found = res.body.enrollments.find((e: any) => e.id === enrollmentId)
    expect(found?.canManage).toBe(true)
    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })

  it('buildEnrollmentManageChecker mirrors enrollmentManageFilter', async () => {
    // Org owner: manages anything in their org, even others' enrollments.
    const ownerCheck = await buildEnrollmentManageChecker(userId)
    expect(ownerCheck({ createdById: 'someone-else', group: { creatorId: 'x', organizationId } })).toBe(true)

    // Outsider with no roles/orgs: only what they created.
    const outsider = await prisma.user.create({
      data: { googleId: `outsider-${Date.now()}`, email: `outsider-${Date.now()}@makeready.test`, name: 'Outsider' },
    })
    const outsiderCheck = await buildEnrollmentManageChecker(outsider.id)
    expect(outsiderCheck({ createdById: outsider.id, group: null })).toBe(true) // creator
    expect(outsiderCheck({ createdById: 'x', group: { creatorId: 'y', organizationId } })).toBe(false)
    await prisma.user.deleteMany({ where: { id: outsider.id } })
  })

  it('applyStudySwap rejects a bundled nonexistent group before mutating', async () => {
    const enrollmentId = await enroll()
    await expect(
      applyStudySwap(enrollmentId, { studyProgramId: programBId, groupId: RANDOM_UUID }, userId)
    ).rejects.toMatchObject({ status: 404 })
    // Nothing changed
    const enrollment = await prisma.enrollment.findUniqueOrThrow({ where: { id: enrollmentId } })
    expect(enrollment.studyProgramId).toBe(programId)
    await prisma.enrollment.delete({ where: { id: enrollmentId } })
  })
})
