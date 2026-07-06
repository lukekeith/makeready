/**
 * Enrollment Sync Engine Tests (study-sync phase 3)
 *
 * Verifies applying published program versions to enrollments:
 * - drift reporting (GET /enrollments/:id/sync)
 * - changed lessons get a new immutable LessonScheduleVersion; old version
 *   rows and activities survive untouched
 * - completed members are pinned to the version they finished
 * - added lessons slot into the remaining future schedule in curriculum order
 * - removed lessons: hard-deleted without progress, soft-hidden with progress
 * - idempotent re-apply, EnrollmentSyncRun bookkeeping, AUTO fan-out
 *
 * Claude is mocked; content sync itself never calls it.
 */

import { describe, it, expect, beforeAll, afterAll, vi } from 'vitest'
import request from 'supertest'
import { app } from '../../index'
import { prisma } from '../../lib/prisma'
import { generateApiKey, hashApiKey, getKeyPrefix } from '../../lib/api-key'
import { drainStudySyncFanOuts } from '../../services/enrollment-sync'

vi.mock('../../services/claude', async (importOriginal) => {
  const actual = await importOriginal<typeof import('../../services/claude')>()
  return {
    ...actual,
    summarizeProgramChanges: vi.fn(async () => 'AI summary of curriculum changes.'),
  }
})

describe('Enrollment sync engine (study-sync)', () => {
  let userId: string
  let organizationId: string
  let groupId: string
  let programId: string
  let lesson1Id: string
  let lesson2Id: string
  let enrollmentId: string
  let apiKey: string

  const authed = () => ({ Authorization: `Bearer ${apiKey}` })

  const publishUpdates = async () => {
    const response = await request(app)
      .post(`/api/programs/${programId}/publish-updates`)
      .set(authed())
    expect(response.status).toBe(200)
    return response.body
  }

  const applySync = async () => {
    const response = await request(app)
      .post(`/api/enrollments/${enrollmentId}/sync/apply`)
      .set(authed())
    expect(response.status).toBe(200)
    return response.body
  }

  beforeAll(async () => {
    const user = await prisma.user.create({
      data: {
        googleId: `sync-engine-${Date.now()}`,
        email: `sync-engine-${Date.now()}@makeready.test`,
        name: 'Sync Engine Leader',
      },
    })
    userId = user.id

    apiKey = generateApiKey()
    await prisma.apiKey.create({
      data: {
        keyHash: hashApiKey(apiKey),
        keyPrefix: getKeyPrefix(apiKey),
        name: 'sync-engine test key',
        userId,
      },
    })

    const organization = await prisma.organization.create({
      data: { name: 'Sync Engine Org', ownerId: userId },
    })
    organizationId = organization.id

    const group = await prisma.group.create({
      data: { name: 'Sync Engine Group', creatorId: userId, organizationId },
    })
    groupId = group.id

    const program = await prisma.studyProgram.create({
      data: { name: 'Sync Engine Program', days: 2, creatorId: userId },
    })
    programId = program.id

    const lesson1 = await prisma.lesson.create({
      data: { studyProgramId: programId, dayNumber: 1, title: 'Day One' },
    })
    lesson1Id = lesson1.id
    const inputActivity = await prisma.lessonActivity.create({
      data: {
        lessonId: lesson1.id,
        activityType: 'USER_INPUT',
        orderNumber: 1,
        title: 'Observation',
        helpTitle: 'What stood out?',
      },
    })
    const readActivity = await prisma.lessonActivity.create({
      data: {
        lessonId: lesson1.id,
        activityType: 'READ',
        orderNumber: 2,
        title: 'Scripture',
        referenceTitle: 'Romans 1:1-5',
      },
    })
    const sourceRef = await prisma.activitySourceReference.create({
      data: {
        lessonActivityId: readActivity.id,
        sourceType: 'SCRIPTURE',
        passageReference: 'Romans 1:1-5',
        bookNumber: 45,
        bookName: 'Romans',
        chapterStart: 1,
        chapterEnd: 1,
        verseStart: 1,
        verseEnd: 5,
      },
    })
    await prisma.activityReadBlock.create({
      data: {
        lessonActivityId: readActivity.id,
        orderNumber: 1,
        title: 'Romans 1:1-5',
        content: '1 Paul, a servant of Christ Jesus...',
        isLocked: true,
        sourceReferenceId: sourceRef.id,
      },
    })
    // Silence unused warning — the ref/block wiring is what matters
    void inputActivity

    const lesson2 = await prisma.lesson.create({
      data: { studyProgramId: programId, dayNumber: 2, title: 'Day Two' },
    })
    lesson2Id = lesson2.id
    await prisma.lessonActivity.create({
      data: {
        lessonId: lesson2.id,
        activityType: 'USER_INPUT',
        orderNumber: 1,
        title: 'Application',
      },
    })

    // First publish cuts baseline v1
    const publishResponse = await request(app)
      .patch(`/api/programs/${programId}`)
      .set(authed())
      .send({ isPublished: true })
    expect(publishResponse.status).toBe(200)

    // Enroll with sync OFF (engine driven explicitly via the apply endpoint;
    // AUTO fan-out gets its own test). Start tomorrow: nothing is locked.
    const tomorrow = new Date()
    tomorrow.setDate(tomorrow.getDate() + 1)
    const enrollResponse = await request(app)
      .post('/api/enrollments')
      .set(authed())
      .send({
        groupId,
        studyProgramId: programId,
        startDate: tomorrow.toISOString(),
        enabledDays: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
        syncMode: 'OFF',
      })
    expect(enrollResponse.status).toBe(200)
    enrollmentId = enrollResponse.body.enrollment.id
  })

  afterAll(async () => {
    // Background fan-outs from publishes must settle before rows disappear —
    // one outliving this file races the next file's writes (shared test DB)
    await drainStudySyncFanOuts()
    await prisma.group.deleteMany({ where: { id: groupId } })
    await prisma.studyProgram.deleteMany({ where: { id: programId } })
    await prisma.organization.deleteMany({ where: { id: organizationId } })
    await prisma.member.deleteMany({ where: { phoneNumber: '+15559876543' } })
    await prisma.user.deleteMany({ where: { id: userId } })
  })

  it('reports no drift right after enrolling', async () => {
    const response = await request(app)
      .get(`/api/enrollments/${enrollmentId}/sync`)
      .set(authed())

    expect(response.status).toBe(200)
    expect(response.body.sync.hasDrift).toBe(false)
    expect(response.body.sync.syncedProgramVersionNumber).toBe(1)
    expect(response.body.sync.currentVersionNumber).toBe(1)
  })

  it('applies a changed lesson as a new immutable version', async () => {
    await prisma.lessonActivity.updateMany({
      where: { lessonId: lesson1Id, orderNumber: 1 },
      data: { helpTitle: 'What did you notice about the passage?' },
    })
    const publish = await publishUpdates()
    expect(publish.version.versionNumber).toBe(2)

    // Drift is now visible with the pending version's summary
    const syncStatus = await request(app)
      .get(`/api/enrollments/${enrollmentId}/sync`)
      .set(authed())
    expect(syncStatus.body.sync.hasDrift).toBe(true)
    expect(syncStatus.body.sync.pendingVersions[0].versionNumber).toBe(2)
    expect(syncStatus.body.sync.pendingVersions[0].changeSummary).toBe(
      'AI summary of curriculum changes.'
    )

    const outcome = await applySync()
    expect(outcome.alreadySynced).toBe(false)
    expect(outcome.lessonsUpdated).toBe(1)
    expect(outcome.lessonsAdded).toBe(0)
    expect(outcome.lessonsRemoved).toBe(0)

    const schedule1 = await prisma.lessonSchedule.findUniqueOrThrow({
      where: { enrollmentId_lessonId: { enrollmentId, lessonId: lesson1Id } },
      include: {
        versions: { orderBy: { versionNumber: 'asc' } },
        scheduledActivities: true,
      },
    })

    // Two versions now; current points at v2 which records program v2
    expect(schedule1.versions).toHaveLength(2)
    const [v1, v2] = schedule1.versions
    expect(schedule1.currentVersionId).toBe(v2.id)
    expect(v2.programVersionNumber).toBe(2)

    // Old activity rows survive untouched; the new set is version-stamped
    const v1Activities = schedule1.scheduledActivities.filter((a) => a.versionId === v1.id)
    const v2Activities = schedule1.scheduledActivities.filter((a) => a.versionId === v2.id)
    expect(v1Activities).toHaveLength(2)
    expect(v2Activities).toHaveLength(2)
    expect(v2Activities.find((a) => a.orderNumber === 1)?.helpTitle).toBe(
      'What did you notice about the passage?'
    )
    expect(v1Activities.find((a) => a.orderNumber === 1)?.helpTitle).toBe('What stood out?')

    // Lineage carried from curriculum activity ids
    for (const activity of v2Activities) {
      expect(activity.lineageKey).not.toBeNull()
      expect(activity.lineageKey).toBe(activity.sourceLessonActivityId)
    }

    // The READ activity's blocks and refs were materialized from the snapshot
    const v2Read = v2Activities.find((a) => a.orderNumber === 2)!
    const blocks = await prisma.activityReadBlock.findMany({
      where: { scheduledActivityId: v2Read.id },
    })
    const refs = await prisma.activitySourceReference.findMany({
      where: { scheduledActivityId: v2Read.id },
    })
    expect(blocks).toHaveLength(1)
    expect(refs).toHaveLength(1)
    expect(blocks[0].sourceReferenceId).toBe(refs[0].id)

    // Unchanged lesson untouched
    const schedule2 = await prisma.lessonSchedule.findUniqueOrThrow({
      where: { enrollmentId_lessonId: { enrollmentId, lessonId: lesson2Id } },
      include: { versions: true },
    })
    expect(schedule2.versions).toHaveLength(1)

    const enrollment = await prisma.enrollment.findUniqueOrThrow({ where: { id: enrollmentId } })
    expect(enrollment.syncedProgramVersionNumber).toBe(2)

    const run = await prisma.enrollmentSyncRun.findUniqueOrThrow({
      where: {
        enrollmentId_targetProgramVersionNumber: {
          enrollmentId,
          targetProgramVersionNumber: 2,
        },
      },
    })
    expect(run.status).toBe('COMPLETED')
    expect(run.triggeredById).toBe(userId)
  })

  it('re-applying is a no-op', async () => {
    const outcome = await applySync()
    expect(outcome.alreadySynced).toBe(true)
  })

  it('pins members who completed a lesson to the version they finished', async () => {
    const schedule1 = await prisma.lessonSchedule.findUniqueOrThrow({
      where: { enrollmentId_lessonId: { enrollmentId, lessonId: lesson1Id } },
    })
    const versionAtCompletion = schedule1.currentVersionId!

    const member = await prisma.member.create({
      data: { phoneNumber: '+15559876543', firstName: 'Pinned', lastName: 'Member' },
    })
    await prisma.memberLessonProgress.create({
      data: {
        memberId: member.id,
        lessonScheduleId: schedule1.id,
        completedAt: new Date(),
      },
    })

    // Another curriculum edit + publish + apply
    await prisma.lessonActivity.updateMany({
      where: { lessonId: lesson1Id, orderNumber: 1 },
      data: { title: 'Deeper Observation' },
    })
    const publish = await publishUpdates()
    expect(publish.version.versionNumber).toBe(3)
    const outcome = await applySync()
    expect(outcome.lessonsUpdated).toBe(1)

    const progress = await prisma.memberLessonProgress.findUniqueOrThrow({
      where: { memberId_lessonScheduleId: { memberId: member.id, lessonScheduleId: schedule1.id } },
    })
    expect(progress.pinnedVersionId).toBe(versionAtCompletion)

    // The schedule moved on to a third version
    const updated = await prisma.lessonSchedule.findUniqueOrThrow({
      where: { id: schedule1.id },
      include: { versions: true },
    })
    expect(updated.versions).toHaveLength(3)
    expect(updated.currentVersionId).not.toBe(versionAtCompletion)
  })

  it('slots an inserted lesson into the remaining future schedule in curriculum order', async () => {
    const beforeSchedules = await prisma.lessonSchedule.findMany({
      where: { enrollmentId },
      orderBy: { scheduledDate: 'asc' },
    })
    const lesson2OldDate = beforeSchedules.find((s) => s.lessonId === lesson2Id)!.scheduledDate

    // Curriculum: move Day Two to day 4, insert a new lesson at day 2
    await prisma.lesson.update({ where: { id: lesson2Id }, data: { dayNumber: 4 } })
    const inserted = await prisma.lesson.create({
      data: { studyProgramId: programId, dayNumber: 2, title: 'Inserted Day' },
    })
    await prisma.lessonActivity.create({
      data: {
        lessonId: inserted.id,
        activityType: 'USER_INPUT',
        orderNumber: 1,
        title: 'Reflection',
      },
    })

    const publish = await publishUpdates()
    expect(publish.version.versionNumber).toBe(4)
    const outcome = await applySync()
    expect(outcome.lessonsAdded).toBe(1)
    expect(outcome.datesShifted).toBeGreaterThanOrEqual(1)

    const insertedSchedule = await prisma.lessonSchedule.findUniqueOrThrow({
      where: { enrollmentId_lessonId: { enrollmentId, lessonId: inserted.id } },
      include: { versions: true, scheduledActivities: true },
    })
    // The inserted lesson takes the next undelivered slot (Day Two's old date)
    expect(insertedSchedule.scheduledDate.getTime()).toBe(lesson2OldDate.getTime())
    expect(insertedSchedule.versions).toHaveLength(1)
    expect(insertedSchedule.currentVersionId).toBe(insertedSchedule.versions[0].id)
    expect(insertedSchedule.scheduledActivities).toHaveLength(1)

    // Day Two moved later than the inserted lesson
    const lesson2Schedule = await prisma.lessonSchedule.findUniqueOrThrow({
      where: { enrollmentId_lessonId: { enrollmentId, lessonId: lesson2Id } },
    })
    expect(lesson2Schedule.scheduledDate.getTime()).toBeGreaterThan(
      insertedSchedule.scheduledDate.getTime()
    )

    // Calendar event created for the new lesson
    const event = await prisma.event.findFirst({
      where: { lessonScheduleId: insertedSchedule.id },
    })
    expect(event).not.toBeNull()
    expect(event!.dayNumber).toBe(2)
  })

  it('hard-deletes a removed lesson without progress, soft-hides one with progress', async () => {
    // Simulate two schedules whose lessons are no longer in the published
    // snapshot (a foreign program's lessons stand in for deleted curriculum —
    // deleting a curriculum Lesson row cascades enrolled schedules today,
    // so snapshot-missing lessons are constructed directly).
    const foreignProgram = await prisma.studyProgram.create({
      data: { name: 'Foreign Program', days: 2, creatorId: userId },
    })
    const ghostLesson1 = await prisma.lesson.create({
      data: { studyProgramId: foreignProgram.id, dayNumber: 1, title: 'Ghost 1' },
    })
    const ghostLesson2 = await prisma.lesson.create({
      data: { studyProgramId: foreignProgram.id, dayNumber: 2, title: 'Ghost 2' },
    })

    const future = new Date()
    future.setDate(future.getDate() + 30)
    const ghostSchedule1 = await prisma.lessonSchedule.create({
      data: {
        enrollmentId,
        lessonId: ghostLesson1.id,
        scheduledDate: future,
        title: 'Ghost 1',
      },
    })
    const ghostSchedule2 = await prisma.lessonSchedule.create({
      data: {
        enrollmentId,
        lessonId: ghostLesson2.id,
        scheduledDate: future,
        title: 'Ghost 2',
      },
    })

    // Ghost 2 has member progress; Ghost 1 has none
    const member = await prisma.member.findUniqueOrThrow({
      where: { phoneNumber: '+15559876543' },
    })
    await prisma.memberLessonProgress.create({
      data: { memberId: member.id, lessonScheduleId: ghostSchedule2.id, startedAt: new Date() },
    })

    // Any curriculum change so a new version exists to apply
    await prisma.lessonActivity.updateMany({
      where: { lessonId: lesson1Id, orderNumber: 1 },
      data: { helpDescription: 'Take your time with this one.' },
    })
    await publishUpdates()
    const outcome = await applySync()
    expect(outcome.lessonsRemoved).toBe(2)

    // No progress → gone entirely
    const deleted = await prisma.lessonSchedule.findUnique({ where: { id: ghostSchedule1.id } })
    expect(deleted).toBeNull()

    // Progress → soft-hidden, history intact
    const hidden = await prisma.lessonSchedule.findUniqueOrThrow({
      where: { id: ghostSchedule2.id },
    })
    expect(hidden.removedAt).not.toBeNull()
    const progressCount = await prisma.memberLessonProgress.count({
      where: { lessonScheduleId: ghostSchedule2.id },
    })
    expect(progressCount).toBe(1)

    await prisma.studyProgram.deleteMany({ where: { id: foreignProgram.id } })
  })

  it('deleting a curriculum lesson orphans the enrolled copy instead of destroying it', async () => {
    // Add a lesson, publish, and sync it into the enrollment
    const doomed = await prisma.lesson.create({
      data: { studyProgramId: programId, dayNumber: 5, title: 'Doomed Day' },
    })
    await prisma.lessonActivity.create({
      data: {
        lessonId: doomed.id,
        activityType: 'USER_INPUT',
        orderNumber: 1,
        title: 'Soon Gone',
      },
    })
    await publishUpdates()
    await applySync()

    const schedule = await prisma.lessonSchedule.findUniqueOrThrow({
      where: { enrollmentId_lessonId: { enrollmentId, lessonId: doomed.id } },
    })

    // Creator deletes the lesson from the curriculum (editor delete / days shrink)
    await prisma.lesson.delete({ where: { id: doomed.id } })

    // The enrolled copy SURVIVES, orphaned — content and history intact
    const orphaned = await prisma.lessonSchedule.findUniqueOrThrow({
      where: { id: schedule.id },
    })
    expect(orphaned.lessonId).toBeNull()
    expect(orphaned.removedAt).toBeNull()
    const activityCount = await prisma.scheduledLessonActivity.count({
      where: { lessonScheduleId: schedule.id },
    })
    expect(activityCount).toBeGreaterThan(0)

    // The removal reaches the enrollment only via publish + sync
    await publishUpdates()
    const outcome = await applySync()
    expect(outcome.lessonsRemoved).toBe(1)

    // No member progress → hard-deleted by the sync
    const afterSync = await prisma.lessonSchedule.findUnique({ where: { id: schedule.id } })
    expect(afterSync).toBeNull()
  })

  it('fans out automatically to AUTO enrollments on publish', async () => {
    const autoGroup = await prisma.group.create({
      data: { name: 'Auto Sync Group', creatorId: userId, organizationId },
    })
    const tomorrow = new Date()
    tomorrow.setDate(tomorrow.getDate() + 1)
    const enrollResponse = await request(app)
      .post('/api/enrollments')
      .set(authed())
      .send({
        groupId: autoGroup.id,
        studyProgramId: programId,
        startDate: tomorrow.toISOString(),
        enabledDays: ['Mon', 'Wed', 'Fri'],
        syncMode: 'AUTO',
      })
    expect(enrollResponse.status).toBe(200)
    const autoEnrollmentId = enrollResponse.body.enrollment.id

    await prisma.lessonActivity.updateMany({
      where: { lessonId: lesson2Id, orderNumber: 1 },
      data: { helpTitle: 'How will you live this out?' },
    })
    const publish = await publishUpdates()
    const targetVersion = publish.version.versionNumber

    // Fan-out is fire-and-forget from the publish endpoint — poll for it
    await vi.waitFor(
      async () => {
        const enrollment = await prisma.enrollment.findUniqueOrThrow({
          where: { id: autoEnrollmentId },
        })
        expect(enrollment.syncedProgramVersionNumber).toBe(targetVersion)
      },
      { timeout: 8000, interval: 150 }
    )

    const run = await prisma.enrollmentSyncRun.findUniqueOrThrow({
      where: {
        enrollmentId_targetProgramVersionNumber: {
          enrollmentId: autoEnrollmentId,
          targetProgramVersionNumber: targetVersion,
        },
      },
    })
    expect(run.status).toBe('COMPLETED')
    expect(run.triggeredById).toBeNull() // automatic, not user-triggered

    // The OFF enrollment did NOT auto-sync
    const offEnrollment = await prisma.enrollment.findUniqueOrThrow({
      where: { id: enrollmentId },
    })
    expect(offEnrollment.syncedProgramVersionNumber).toBe(targetVersion - 1)

    await prisma.group.deleteMany({ where: { id: autoGroup.id } })
  })

  it('notifies the leader of pending updates, coalesced across publishes', async () => {
    // The publishes above already fanned out — the OFF enrollment's leader
    // has exactly one unread pending-updates notification
    await drainStudySyncFanOuts()
    const key = `study-sync-updates:${enrollmentId}`
    const before = await prisma.notification.findMany({
      where: { userId, dedupeKey: key, isRead: false },
    })
    expect(before).toHaveLength(1)
    expect(before[0].type).toBe('STUDY_SYNC_UPDATES_AVAILABLE')
    const actions = before[0].actions as Array<{ label: string; view: string; params: any }>
    expect(actions[0].view).toBe('enrollment-sync')
    expect(actions[0].params.enrollmentId).toBe(enrollmentId)

    // Another publish coalesces instead of stacking
    await prisma.lessonActivity.updateMany({
      where: { lessonId: lesson1Id, orderNumber: 1 },
      data: { placeholder: 'Write your thoughts…' },
    })
    const publish = await publishUpdates()
    await drainStudySyncFanOuts()

    const after = await prisma.notification.findMany({
      where: { userId, dedupeKey: key, isRead: false },
    })
    expect(after).toHaveLength(1)
    expect(after[0].id).toBe(before[0].id) // updated in place
    expect(after[0].body).toContain(`version ${publish.version.versionNumber}`)

    // Summary endpoint feeds the dashboard banner
    const summary = await request(app)
      .get('/api/notifications/summary')
      .set(authed())
    expect(summary.status).toBe(200)
    expect(summary.body.summary.unreadCount).toBeGreaterThanOrEqual(1)
    expect(summary.body.summary.latestAt).not.toBeNull()

    // Applying the sync resolves the pending notification
    await applySync()
    const resolved = await prisma.notification.findMany({
      where: { userId, dedupeKey: key, isRead: false },
    })
    expect(resolved).toHaveLength(0)

    // The AUTO enrollment's leader also got an "applied" notification
    const applied = await prisma.notification.findFirst({
      where: { userId, type: 'STUDY_SYNC_APPLIED' },
    })
    expect(applied).not.toBeNull()
  })
})
