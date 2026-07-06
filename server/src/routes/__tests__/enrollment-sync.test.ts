/**
 * Enrollment Versioning Tests (study-sync phase 1)
 *
 * Verifies that enrolling a group in a study program creates the versioning
 * scaffolding the sync feature depends on:
 * - a v1 LessonScheduleVersion per lesson schedule, with a sourceContentHash
 *   that matches an independent re-hash of the curriculum lesson
 * - schedules pointing at their v1 via currentVersionId
 * - copied activities stamped with versionId + lineageKey
 * - enrollment syncMode / syncedProgramVersionNumber persisted
 *
 * Authenticates through the real API-key path (no middleware mocks).
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import request from 'supertest'
import { app } from '../../index'
import { prisma } from '../../lib/prisma'
import { generateApiKey, hashApiKey, getKeyPrefix } from '../../lib/api-key'
import { hashLessonContent, LESSON_CONTENT_INCLUDE } from '../../services/lesson-content-hash'

describe('Enrollment versioning (study-sync)', () => {
  let userId: string
  let organizationId: string
  let groupId: string
  let programId: string
  let lesson1Id: string
  let lesson2Id: string
  let lesson1ActivityIds: string[] = []
  let apiKey: string

  const authed = () => ({ Authorization: `Bearer ${apiKey}` })

  beforeAll(async () => {
    const user = await prisma.user.create({
      data: {
        googleId: `sync-test-${Date.now()}`,
        email: `sync-test-${Date.now()}@makeready.test`,
        name: 'Sync Test Leader',
      },
    })
    userId = user.id

    apiKey = generateApiKey()
    await prisma.apiKey.create({
      data: {
        keyHash: hashApiKey(apiKey),
        keyPrefix: getKeyPrefix(apiKey),
        name: 'enrollment-sync test key',
        userId,
      },
    })

    const organization = await prisma.organization.create({
      data: { name: 'Sync Test Org', ownerId: userId },
    })
    organizationId = organization.id

    const group = await prisma.group.create({
      data: { name: 'Sync Test Group', creatorId: userId, organizationId },
    })
    groupId = group.id

    const program = await prisma.studyProgram.create({
      data: {
        name: 'Sync Test Program',
        days: 2,
        creatorId: userId,
        isPublished: true,
      },
    })
    programId = program.id

    // Lesson 1: USER_INPUT + READ with a source reference and a linked read block
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
        helpDescription: 'Write what you noticed.',
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
    lesson1ActivityIds = [inputActivity.id, readActivity.id]

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

    // Lesson 2: single activity
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
  })

  afterAll(async () => {
    // Scoped cleanup — cascades remove enrollments, schedules, versions,
    // activities, api keys, lessons, etc.
    await prisma.group.deleteMany({ where: { id: groupId } })
    await prisma.studyProgram.deleteMany({ where: { id: programId } })
    await prisma.organization.deleteMany({ where: { id: organizationId } })
    await prisma.user.deleteMany({ where: { id: userId } })
  })

  it('creates v1 lesson schedule versions with stamped activities on enrollment', async () => {
    const response = await request(app)
      .post('/api/enrollments')
      .set(authed())
      .send({
        groupId,
        studyProgramId: programId,
        startDate: new Date().toISOString(),
        enabledDays: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
        syncMode: 'AUTO',
      })

    expect(response.status).toBe(200)
    expect(response.body.success).toBe(true)
    const enrollmentId = response.body.enrollment.id

    const enrollment = await prisma.enrollment.findUniqueOrThrow({
      where: { id: enrollmentId },
    })
    expect(enrollment.syncMode).toBe('AUTO')
    // Program has never been published through the versioned publish flow
    expect(enrollment.syncedProgramVersionNumber).toBeNull()

    const schedules = await prisma.lessonSchedule.findMany({
      where: { enrollmentId },
      include: { versions: true, scheduledActivities: true },
    })
    expect(schedules).toHaveLength(2)

    for (const schedule of schedules) {
      // Exactly one v1 version, and the schedule points at it
      expect(schedule.versions).toHaveLength(1)
      const version = schedule.versions[0]
      expect(version.versionNumber).toBe(1)
      expect(schedule.currentVersionId).toBe(version.id)

      // The stored hash matches an independent re-hash of the curriculum lesson
      const curriculumLesson = await prisma.lesson.findUniqueOrThrow({
        where: { id: schedule.lessonId },
        include: LESSON_CONTENT_INCLUDE,
      })
      expect(version.sourceContentHash).toBe(hashLessonContent(curriculumLesson as any))
      expect(version.sourceContentHash).toMatch(/^v1:[0-9a-f]{64}$/)

      // Every copied activity is stamped with the version and its lineage
      for (const activity of schedule.scheduledActivities) {
        expect(activity.versionId).toBe(version.id)
        expect(activity.lineageKey).toBe(activity.sourceLessonActivityId)
        expect(activity.lineageKey).not.toBeNull()
      }
    }

    const lesson1Schedule = schedules.find((s) => s.lessonId === lesson1Id)!
    expect(lesson1Schedule.scheduledActivities.map((a) => a.lineageKey).sort()).toEqual(
      [...lesson1ActivityIds].sort()
    )
  })

  it('defaults syncMode to OFF when not provided', async () => {
    // Re-enroll in a fresh group to avoid unique/enrollment overlap concerns
    const group2 = await prisma.group.create({
      data: { name: 'Sync Test Group 2', creatorId: userId, organizationId },
    })

    const response = await request(app)
      .post('/api/enrollments')
      .set(authed())
      .send({
        groupId: group2.id,
        studyProgramId: programId,
        startDate: new Date().toISOString(),
        enabledDays: ['Mon', 'Wed', 'Fri'],
      })

    expect(response.status).toBe(200)
    const enrollment = await prisma.enrollment.findUniqueOrThrow({
      where: { id: response.body.enrollment.id },
    })
    expect(enrollment.syncMode).toBe('OFF')

    await prisma.group.deleteMany({ where: { id: group2.id } })
  })

  it('updates syncMode via PATCH /enrollments/:id', async () => {
    const enrollment = await prisma.enrollment.findFirstOrThrow({
      where: { groupId },
    })

    const response = await request(app)
      .patch(`/api/enrollments/${enrollment.id}`)
      .set(authed())
      .send({ syncMode: 'APPROVAL' })

    expect(response.status).toBe(200)
    const updated = await prisma.enrollment.findUniqueOrThrow({
      where: { id: enrollment.id },
    })
    expect(updated.syncMode).toBe('APPROVAL')
  })

  it('creates a v1 version when adding a lesson to an existing enrollment', async () => {
    const enrollment = await prisma.enrollment.findFirstOrThrow({
      where: { groupId },
    })

    // New curriculum lesson added after enrollment
    const lesson3 = await prisma.lesson.create({
      data: { studyProgramId: programId, dayNumber: 3, title: 'Day Three' },
    })
    const lesson3Activity = await prisma.lessonActivity.create({
      data: {
        lessonId: lesson3.id,
        activityType: 'USER_INPUT',
        orderNumber: 1,
        title: 'Prayer',
      },
    })

    const response = await request(app)
      .post(`/api/enrollments/${enrollment.id}/schedules`)
      .set(authed())
      .send({ lessonId: lesson3.id })

    expect(response.status).toBe(200)

    const schedule = await prisma.lessonSchedule.findUniqueOrThrow({
      where: { enrollmentId_lessonId: { enrollmentId: enrollment.id, lessonId: lesson3.id } },
      include: { versions: true, scheduledActivities: true },
    })
    expect(schedule.versions).toHaveLength(1)
    expect(schedule.currentVersionId).toBe(schedule.versions[0].id)
    expect(schedule.versions[0].versionNumber).toBe(1)

    const curriculumLesson = await prisma.lesson.findUniqueOrThrow({
      where: { id: lesson3.id },
      include: LESSON_CONTENT_INCLUDE,
    })
    expect(schedule.versions[0].sourceContentHash).toBe(hashLessonContent(curriculumLesson as any))

    expect(schedule.scheduledActivities).toHaveLength(1)
    expect(schedule.scheduledActivities[0].versionId).toBe(schedule.currentVersionId)
    expect(schedule.scheduledActivities[0].lineageKey).toBe(lesson3Activity.id)
  })

  it('stamps leader-added custom activities with the current version and no lineage', async () => {
    const enrollment = await prisma.enrollment.findFirstOrThrow({
      where: { groupId },
    })
    const schedule = await prisma.lessonSchedule.findFirstOrThrow({
      where: { enrollmentId: enrollment.id, lessonId: lesson2Id },
    })

    const response = await request(app)
      .post(`/api/enrollments/${enrollment.id}/schedules/${schedule.id}/activities`)
      .set(authed())
      .send({ type: 'USER_INPUT', title: 'Custom Reflection' })

    expect(response.status).toBe(200)

    const created = await prisma.scheduledLessonActivity.findFirstOrThrow({
      where: { lessonScheduleId: schedule.id, title: 'Custom Reflection' },
    })
    expect(created.versionId).toBe(schedule.currentVersionId)
    expect(created.lineageKey).toBeNull()
    expect(created.sourceLessonActivityId).toBeNull()
  })
})
