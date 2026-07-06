/**
 * Member Version Resolution Tests (study-sync phase 4)
 *
 * Verifies what members see after an enrollment syncs to a new version:
 * - completing a lesson pins the member to the version they finished
 * - pinned members keep rendering their version after a sync
 * - unpinned (partial) members float to the new version with their partial
 *   progress carried forward by lineage
 * - completing the new version pins to the new version
 */

import { describe, it, expect, beforeAll, afterAll, vi } from 'vitest'
import request from 'supertest'
import { app } from '../../index'
import { prisma } from '../../lib/prisma'
import { generateApiKey, hashApiKey, getKeyPrefix } from '../../lib/api-key'
import {
  checkAndUpdateLessonCompletion,
  getMemberLessonDetail,
} from '../../services/member-progress.service'
import { drainStudySyncFanOuts } from '../../services/enrollment-sync'

vi.mock('../../services/claude', async (importOriginal) => {
  const actual = await importOriginal<typeof import('../../services/claude')>()
  return {
    ...actual,
    summarizeProgramChanges: vi.fn(async () => 'AI summary.'),
  }
})

describe('Member version resolution (study-sync)', () => {
  let userId: string
  let organizationId: string
  let groupId: string
  let programId: string
  let lessonId: string
  let enrollmentId: string
  let scheduleId: string
  let memberAId: string
  let memberBId: string
  let apiKey: string
  let v1Id: string

  const authed = () => ({ Authorization: `Bearer ${apiKey}` })

  /** Complete every activity of the given version for a member. */
  const completeActivities = async (memberId: string, activityIds: string[]) => {
    for (const scheduledActivityId of activityIds) {
      await prisma.memberActivityProgress.upsert({
        where: {
          memberId_lessonScheduleId_scheduledActivityId: {
            memberId,
            lessonScheduleId: scheduleId,
            scheduledActivityId,
          },
        },
        create: {
          memberId,
          lessonScheduleId: scheduleId,
          scheduledActivityId,
          completedAt: new Date(),
        },
        update: { completedAt: new Date() },
      })
    }
  }

  beforeAll(async () => {
    const user = await prisma.user.create({
      data: {
        googleId: `resolution-${Date.now()}`,
        email: `resolution-${Date.now()}@makeready.test`,
        name: 'Resolution Leader',
      },
    })
    userId = user.id
    apiKey = generateApiKey()
    await prisma.apiKey.create({
      data: { keyHash: hashApiKey(apiKey), keyPrefix: getKeyPrefix(apiKey), name: 'res key', userId },
    })
    const organization = await prisma.organization.create({
      data: { name: 'Resolution Org', ownerId: userId },
    })
    organizationId = organization.id
    const group = await prisma.group.create({
      data: { name: 'Resolution Group', creatorId: userId, organizationId },
    })
    groupId = group.id

    const program = await prisma.studyProgram.create({
      data: { name: 'Resolution Program', days: 1, creatorId: userId },
    })
    programId = program.id
    const lesson = await prisma.lesson.create({
      data: { studyProgramId: programId, dayNumber: 1, title: 'Only Day' },
    })
    lessonId = lesson.id
    await prisma.lessonActivity.createMany({
      data: [
        { lessonId, activityType: 'USER_INPUT', orderNumber: 1, title: 'First' },
        { lessonId, activityType: 'USER_INPUT', orderNumber: 2, title: 'Second' },
      ],
    })

    const publishResponse = await request(app)
      .patch(`/api/programs/${programId}`)
      .set(authed())
      .send({ isPublished: true })
    expect(publishResponse.status).toBe(200)

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

    const schedule = await prisma.lessonSchedule.findUniqueOrThrow({
      where: { enrollmentId_lessonId: { enrollmentId, lessonId } },
    })
    scheduleId = schedule.id
    v1Id = schedule.currentVersionId!

    const memberA = await prisma.member.create({
      data: { phoneNumber: '+16665550001', firstName: 'Alma', lastName: 'Pinned' },
    })
    memberAId = memberA.id
    const memberB = await prisma.member.create({
      data: { phoneNumber: '+16665550002', firstName: 'Ben', lastName: 'Floating' },
    })
    memberBId = memberB.id
    await prisma.groupMember.createMany({
      data: [
        { groupId, memberId: memberAId },
        { groupId, memberId: memberBId },
      ],
    })
  })

  afterAll(async () => {
    await drainStudySyncFanOuts()
    await prisma.group.deleteMany({ where: { id: groupId } })
    await prisma.studyProgram.deleteMany({ where: { id: programId } })
    await prisma.organization.deleteMany({ where: { id: organizationId } })
    await prisma.member.deleteMany({ where: { id: { in: [memberAId, memberBId] } } })
    await prisma.user.deleteMany({ where: { id: userId } })
  })

  it('pins a member to the version they complete', async () => {
    const v1Activities = await prisma.scheduledLessonActivity.findMany({
      where: { lessonScheduleId: scheduleId, versionId: v1Id },
    })
    expect(v1Activities).toHaveLength(2)

    // Member A completes everything; member B only the first activity
    await completeActivities(memberAId, v1Activities.map((a) => a.id))
    await completeActivities(memberBId, [v1Activities[0].id])

    const resultA = await checkAndUpdateLessonCompletion(memberAId, scheduleId)
    expect(resultA.lessonCompleted).toBe(true)
    const resultB = await checkAndUpdateLessonCompletion(memberBId, scheduleId)
    expect(resultB.lessonCompleted).toBe(false)

    const progressA = await prisma.memberLessonProgress.findUniqueOrThrow({
      where: { memberId_lessonScheduleId: { memberId: memberAId, lessonScheduleId: scheduleId } },
    })
    expect(progressA.pinnedVersionId).toBe(v1Id)

    const progressB = await prisma.memberLessonProgress.findUniqueOrThrow({
      where: { memberId_lessonScheduleId: { memberId: memberBId, lessonScheduleId: scheduleId } },
    })
    expect(progressB.pinnedVersionId).toBeNull()
  })

  it('after a sync, the pinned member keeps their version and the partial member floats with carried progress', async () => {
    // Curriculum change: edit Second + add Third, publish, apply
    await prisma.lessonActivity.updateMany({
      where: { lessonId, orderNumber: 2 },
      data: { title: 'Second (revised)' },
    })
    await prisma.lessonActivity.create({
      data: { lessonId, activityType: 'USER_INPUT', orderNumber: 3, title: 'Third' },
    })
    await request(app).post(`/api/programs/${programId}/publish-updates`).set(authed()).expect(200)
    await request(app)
      .post(`/api/enrollments/${enrollmentId}/sync/apply`)
      .set(authed())
      .expect(200)

    const schedule = await prisma.lessonSchedule.findUniqueOrThrow({ where: { id: scheduleId } })
    expect(schedule.currentVersionId).not.toBe(v1Id)

    // Pinned member A still sees v1: two activities, lesson still complete
    const detailA = await getMemberLessonDetail(memberAId, scheduleId)
    expect(detailA.success).toBe(true)
    expect(detailA.data!.activities).toHaveLength(2)
    expect(detailA.data!.status).toBe('completed')
    expect(detailA.data!.activities.map((a: any) => a.title).sort()).toEqual(['First', 'Second'])

    // Floating member B sees v2: three activities, 'First' carried forward
    const detailB = await getMemberLessonDetail(memberBId, scheduleId)
    expect(detailB.success).toBe(true)
    expect(detailB.data!.activities).toHaveLength(3)
    expect(detailB.data!.status).toBe('in_progress')
    const firstV2 = detailB.data!.activities.find((a: any) => a.title === 'First')!
    expect(firstV2.progress?.completedAt).not.toBeNull()
    expect(firstV2.progress?.completedAt).toBeDefined()

    // Carry-forward copied (not moved): the v1 progress row still exists
    const v1Rows = await prisma.memberActivityProgress.count({
      where: {
        memberId: memberBId,
        lessonScheduleId: scheduleId,
        scheduledActivity: { versionId: v1Id },
      },
    })
    expect(v1Rows).toBe(1)
  })

  it('completing the new version pins to the new version', async () => {
    const schedule = await prisma.lessonSchedule.findUniqueOrThrow({ where: { id: scheduleId } })
    const v2Activities = await prisma.scheduledLessonActivity.findMany({
      where: { lessonScheduleId: scheduleId, versionId: schedule.currentVersionId },
    })
    await completeActivities(memberBId, v2Activities.map((a) => a.id))

    const result = await checkAndUpdateLessonCompletion(memberBId, scheduleId)
    expect(result.lessonCompleted).toBe(true)

    const progressB = await prisma.memberLessonProgress.findUniqueOrThrow({
      where: { memberId_lessonScheduleId: { memberId: memberBId, lessonScheduleId: scheduleId } },
    })
    expect(progressB.pinnedVersionId).toBe(schedule.currentVersionId)
  })
})
