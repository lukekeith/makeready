/**
 * Study Program Publish Tests (study-sync phase 2)
 *
 * Verifies the "Publish updates" versioning flow:
 * - transitioning a program to published cuts the baseline v1 (no summary)
 * - publish-updates with no changes is a no-op (alreadyUpToDate)
 * - real changes cut a new version with correct changedLessonIds diff,
 *   lesson hashes, and the (mocked) Claude change summary
 * - moved lessons (same content, new day) are detected as moved, not changed
 * - GET /programs/:id/versions returns the history
 * - enrollments created after publishing record syncedProgramVersionNumber
 *
 * Claude is mocked — publishing must never depend on the API in tests.
 */

import { describe, it, expect, beforeAll, afterAll, vi } from 'vitest'
import request from 'supertest'
import { app } from '../../index'
import { prisma } from '../../lib/prisma'
import { generateApiKey, hashApiKey, getKeyPrefix } from '../../lib/api-key'
import { hashLessonContent, LESSON_CONTENT_INCLUDE } from '../../services/lesson-content-hash'
import { drainStudySyncFanOuts } from '../../services/enrollment-sync'

vi.mock('../../services/claude', async (importOriginal) => {
  const actual = await importOriginal<typeof import('../../services/claude')>()
  return {
    ...actual,
    summarizeProgramChanges: vi.fn(async () => 'AI summary: lesson prompts were updated.'),
  }
})

describe('Study program publish (study-sync)', () => {
  let userId: string
  let organizationId: string
  let programId: string
  let lesson1Id: string
  let lesson2Id: string
  let apiKey: string

  const authed = () => ({ Authorization: `Bearer ${apiKey}` })

  beforeAll(async () => {
    const user = await prisma.user.create({
      data: {
        googleId: `publish-test-${Date.now()}`,
        email: `publish-test-${Date.now()}@makeready.test`,
        name: 'Publish Test Creator',
      },
    })
    userId = user.id

    apiKey = generateApiKey()
    await prisma.apiKey.create({
      data: {
        keyHash: hashApiKey(apiKey),
        keyPrefix: getKeyPrefix(apiKey),
        name: 'program-publish test key',
        userId,
      },
    })

    const organization = await prisma.organization.create({
      data: { name: 'Publish Test Org', ownerId: userId },
    })
    organizationId = organization.id

    const program = await prisma.studyProgram.create({
      data: {
        name: 'Publish Test Program',
        days: 2,
        creatorId: userId,
        isPublished: false,
      },
    })
    programId = program.id

    const lesson1 = await prisma.lesson.create({
      data: { studyProgramId: programId, dayNumber: 1, title: 'Day One' },
    })
    lesson1Id = lesson1.id
    await prisma.lessonActivity.create({
      data: {
        lessonId: lesson1.id,
        activityType: 'USER_INPUT',
        orderNumber: 1,
        title: 'Observation',
        helpTitle: 'What stood out?',
      },
    })

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
    // Publishes fire background fan-outs; drain them before rows disappear
    // so nothing outlives this file into the next one (shared test DB)
    await drainStudySyncFanOuts()
    await prisma.studyProgram.deleteMany({ where: { id: programId } })
    await prisma.organization.deleteMany({ where: { id: organizationId } })
    await prisma.user.deleteMany({ where: { id: userId } })
  })

  it('cuts the baseline version when the program is first published', async () => {
    const response = await request(app)
      .patch(`/api/programs/${programId}`)
      .set(authed())
      .send({ isPublished: true })

    expect(response.status).toBe(200)

    const program = await prisma.studyProgram.findUniqueOrThrow({ where: { id: programId } })
    expect(program.isPublished).toBe(true)
    expect(program.currentVersionNumber).toBe(1)

    const version = await prisma.studyProgramVersion.findUniqueOrThrow({
      where: { studyProgramId_versionNumber: { studyProgramId: programId, versionNumber: 1 } },
    })
    expect(version.changedLessonIds).toBeNull() // baseline has nothing to diff
    expect(version.changeSummary).toBeNull()

    // Lesson hashes match an independent re-hash of the curriculum
    const hashes = version.lessonHashes as Record<string, string>
    for (const lessonId of [lesson1Id, lesson2Id]) {
      const lesson = await prisma.lesson.findUniqueOrThrow({
        where: { id: lessonId },
        include: LESSON_CONTENT_INCLUDE,
      })
      expect(hashes[lessonId]).toBe(hashLessonContent(lesson as any))
    }

    const snapshot = version.snapshot as { lessons: Array<{ id: string; dayNumber: number }> }
    expect(snapshot.lessons.map((l) => l.id)).toEqual([lesson1Id, lesson2Id])
  })

  it('is a no-op when nothing changed since the last version', async () => {
    const response = await request(app)
      .post(`/api/programs/${programId}/publish-updates`)
      .set(authed())

    expect(response.status).toBe(200)
    expect(response.body.alreadyUpToDate).toBe(true)
    expect(response.body.version.versionNumber).toBe(1)

    const count = await prisma.studyProgramVersion.count({ where: { studyProgramId: programId } })
    expect(count).toBe(1)
  })

  it('cuts v2 with a correct diff and AI summary after curriculum edits', async () => {
    // Edit lesson 1 (changed) and add lesson 3 (added)
    await prisma.lessonActivity.updateMany({
      where: { lessonId: lesson1Id, orderNumber: 1 },
      data: { helpTitle: 'What did you notice about the passage?' },
    })
    const lesson3 = await prisma.lesson.create({
      data: { studyProgramId: programId, dayNumber: 3, title: 'Day Three' },
    })
    await prisma.lessonActivity.create({
      data: {
        lessonId: lesson3.id,
        activityType: 'USER_INPUT',
        orderNumber: 1,
        title: 'Prayer',
      },
    })

    const response = await request(app)
      .post(`/api/programs/${programId}/publish-updates`)
      .set(authed())

    expect(response.status).toBe(200)
    expect(response.body.alreadyUpToDate).toBe(false)
    expect(response.body.version.versionNumber).toBe(2)
    expect(response.body.version.changeSummary).toBe('AI summary: lesson prompts were updated.')
    expect(response.body.version.changedLessonIds).toEqual({
      added: [lesson3.id],
      changed: [lesson1Id],
      removed: [],
      moved: [],
    })

    const program = await prisma.studyProgram.findUniqueOrThrow({ where: { id: programId } })
    expect(program.currentVersionNumber).toBe(2)
  })

  it('detects a lesson moved to a different day without content changes', async () => {
    const lesson3 = await prisma.lesson.findFirstOrThrow({
      where: { studyProgramId: programId, dayNumber: 3 },
    })
    await prisma.lesson.update({ where: { id: lesson3.id }, data: { dayNumber: 4 } })

    const response = await request(app)
      .post(`/api/programs/${programId}/publish-updates`)
      .set(authed())

    expect(response.status).toBe(200)
    expect(response.body.version.versionNumber).toBe(3)
    expect(response.body.version.changedLessonIds).toEqual({
      added: [],
      changed: [],
      removed: [],
      moved: [lesson3.id],
    })
  })

  it('lists version history newest-first', async () => {
    const response = await request(app)
      .get(`/api/programs/${programId}/versions`)
      .set(authed())

    expect(response.status).toBe(200)
    expect(response.body.currentVersionNumber).toBe(3)
    expect(response.body.versions.map((v: any) => v.versionNumber)).toEqual([3, 2, 1])
    expect(response.body.versions[1].changeSummary).toBe('AI summary: lesson prompts were updated.')
    expect(response.body.versions[0].publishedBy.id).toBe(userId)
  })

  it('stamps new enrollments with the current program version', async () => {
    const group = await prisma.group.create({
      data: { name: 'Publish Test Group', creatorId: userId, organizationId },
    })

    const response = await request(app)
      .post('/api/enrollments')
      .set(authed())
      .send({
        groupId: group.id,
        studyProgramId: programId,
        startDate: new Date().toISOString(),
        enabledDays: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
        syncMode: 'AUTO',
      })

    expect(response.status).toBe(200)
    const enrollment = await prisma.enrollment.findUniqueOrThrow({
      where: { id: response.body.enrollment.id },
    })
    expect(enrollment.syncedProgramVersionNumber).toBe(3)

    // Each schedule's v1 records which program version it was copied under
    const versions = await prisma.lessonScheduleVersion.findMany({
      where: { lessonSchedule: { enrollmentId: enrollment.id } },
    })
    expect(versions).toHaveLength(3)
    for (const v of versions) {
      expect(v.programVersionNumber).toBe(3)
    }

    await prisma.group.deleteMany({ where: { id: group.id } })
  })
})
