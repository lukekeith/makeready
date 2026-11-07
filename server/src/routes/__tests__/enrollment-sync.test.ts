/**
 * Enrollment versioning tests (text-activity §Contract, SC3)
 *
 * Enrolling a group in a program schedules the lessons of the program's current ProgramVersion by pointer:
 * - `Enrollment.programVersionId` is that version
 * - each ScheduledLesson points at the lesson version the ProgramVersionLesson row names (no content copied)
 * - syncMode defaults to AUTO and updates through PATCH
 * - a lesson outside the enrollment's version cannot be scheduled
 *
 * Authenticates through the real API-key path (no middleware mocks).
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import request from 'supertest'
import { app } from '../../index'
import { prisma } from '../../lib/prisma'
import { generateApiKey, hashApiKey, getKeyPrefix } from '../../lib/api-key'

describe('Enrollment versioning (study-sync)', () => {
  let userId: string
  let organizationId: string
  let groupId: string
  let programId: string
  let programVersionId: string
  let lessonIds: string[] = []
  let versionIds: string[] = []
  let apiKey: string
  let memberId: string

  const authed = () => ({ Authorization: `Bearer ${apiKey}` })
  const document = {
    schemaVersion: 1, kind: 'text', background: { color: '#000' }, content: { type: 'canvas', objects: [] },
    actions: [], chrome: { topAction: 'none' }, fallback: { title: 'x', body: 'y' },
  }

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

    organizationId = (await prisma.organization.create({ data: { name: 'Sync Test Org', ownerId: userId } })).id
    groupId = (await prisma.group.create({ data: { name: 'Sync Test Group', creatorId: userId, organizationId } })).id
    // ui2-enrollment-create D5: POST refuses a group with no active member.
    memberId = (await prisma.member.create({
      data: { firstName: 'Sync', lastName: 'Member', phoneNumber: `+1558${String(Date.now()).slice(-7)}` },
    })).id
    await prisma.groupMember.create({ data: { groupId, memberId, isActive: true } })

    programId = (await prisma.studyProgram.create({
      data: { name: 'Sync Test Program', days: 2, creatorId: userId, isPublished: true },
    })).id
    for (const [i, title] of ['Day One', 'Day Two'].entries()) {
      const lesson = await prisma.lesson.create({ data: { programId, position: i + 1 } })
      const version = await prisma.lessonVersion.create({
        data: {
          lessonId: lesson.id, number: 1, status: 'PUBLISHED', title, publishedAt: new Date(),
          activities: {
            create: [
              { activityKey: `sync-${lesson.id}-a`, position: 1, kind: 'text', title: 'Observation', document },
              { activityKey: `sync-${lesson.id}-b`, position: 2, kind: 'text', title: 'Scripture', document },
            ],
          },
        },
      })
      lessonIds.push(lesson.id)
      versionIds.push(version.id)
    }
    const programVersion = await prisma.programVersion.create({
      data: {
        programId, number: 1,
        lessons: { create: lessonIds.map((lessonId, i) => ({ lessonId, lessonVersionId: versionIds[i], position: i + 1 })) },
      },
    })
    programVersionId = programVersion.id
    await prisma.studyProgram.update({ where: { id: programId }, data: { currentVersionId: programVersionId } })
  })

  afterAll(async () => {
    // Scheduled lessons hold their versions (RESTRICT): enrollments go first.
    await prisma.enrollment.deleteMany({ where: { groupId } })
    await prisma.group.deleteMany({ where: { id: groupId } })
    await prisma.member.deleteMany({ where: { id: memberId } })
    await prisma.studyProgram.update({ where: { id: programId }, data: { currentVersionId: null } })
    await prisma.programVersionLesson.deleteMany({ where: { programVersionId } })
    await prisma.programVersion.deleteMany({ where: { programId } })
    await prisma.lesson.deleteMany({ where: { programId } })
    await prisma.studyProgram.deleteMany({ where: { id: programId } })
    await prisma.organization.deleteMany({ where: { id: organizationId } })
    await prisma.user.deleteMany({ where: { id: userId } })
  })

  it('points each scheduled lesson at the program version\'s lesson version on enrollment', async () => {
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

    const enrollment = await prisma.enrollment.findUniqueOrThrow({ where: { id: enrollmentId } })
    expect(enrollment.syncMode).toBe('AUTO')
    expect(enrollment.programVersionId).toBe(programVersionId)

    const schedules = await prisma.scheduledLesson.findMany({
      where: { enrollmentId },
      orderBy: { scheduledDate: 'asc' },
      include: { currentVersion: { include: { activities: { orderBy: { position: 'asc' } } } } },
    })
    expect(schedules.map((s) => s.lessonId)).toEqual(lessonIds)
    expect(schedules.map((s) => s.currentVersionId)).toEqual(versionIds)
    // Nothing was copied: the schedule reads the program's own version rows.
    expect(schedules.every((s) => s.currentVersion.enrollmentId === null)).toBe(true)
    expect(schedules[0].currentVersion.activities.map((a) => a.activityKey)).toEqual([`sync-${lessonIds[0]}-a`, `sync-${lessonIds[0]}-b`])
  })

  it('defaults syncMode to AUTO when not provided', async () => {
    // Re-enroll in a fresh group to avoid unique/enrollment overlap concerns
    const group2 = await prisma.group.create({
      data: { name: 'Sync Test Group 2', creatorId: userId, organizationId },
    })
    await prisma.groupMember.create({ data: { groupId: group2.id, memberId, isActive: true } })

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
    // New enrollments track published curriculum updates automatically
    // (monday#12268576962).
    expect(enrollment.syncMode).toBe('AUTO')

    await prisma.enrollment.deleteMany({ where: { groupId: group2.id } })
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

  it('refuses to schedule a lesson that is not in the enrollment\'s program version', async () => {
    const enrollment = await prisma.enrollment.findFirstOrThrow({ where: { groupId } })

    // A curriculum lesson added after the version was published is not in it yet.
    const lesson3 = await prisma.lesson.create({ data: { programId, position: 3 } })

    const response = await request(app)
      .post(`/api/enrollments/${enrollment.id}/schedules`)
      .set(authed())
      .send({ lessonId: lesson3.id })

    expect(response.status).toBe(400)
    expect(await prisma.scheduledLesson.count({ where: { enrollmentId: enrollment.id, lessonId: lesson3.id } })).toBe(0)
  })
})
