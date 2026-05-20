/**
 * Lesson Lookup Endpoint Tests
 *
 * Tests for public lesson lookup endpoints used by study join flow:
 * - GET /api/lessons/code/:code - Lookup by 6-char study code
 * - GET /api/lessons/view/:scheduleId - Lookup by UUID
 *
 * User Stories:
 * 1. User clicks SMS link with study code → lookup returns lesson + group info
 * 2. User clicks link with UUID → lookup returns lesson + group info
 * 3. Invalid code format → returns 400
 * 4. Valid format but not found → returns 404
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import request from 'supertest'
import { app } from '../../index'
import { prisma } from '../../lib/prisma'

describe('Lesson Lookup API', () => {
  // Test data
  let testUser: { id: string }
  let testGroup: { id: string; code: string | null; name: string }
  let testProgram: { id: string; name: string }
  let testLesson: { id: string }
  let testEnrollment: { id: string }
  let testLessonSchedule: { id: string; code: string | null }

  const TEST_STUDY_CODE = 'ABC123'
  const TEST_GROUP_CODE = 'TESTGP'

  beforeEach(async () => {
    // Clean up test data in correct order (respecting foreign keys)
    await prisma.lessonSchedule.deleteMany({
      where: { code: TEST_STUDY_CODE },
    })
    await prisma.enrollment.deleteMany({
      where: { group: { code: TEST_GROUP_CODE } },
    })
    await prisma.lessonActivity.deleteMany({
      where: { lesson: { studyProgram: { name: 'Lesson Lookup Test Program' } } },
    })
    await prisma.lesson.deleteMany({
      where: { studyProgram: { name: 'Lesson Lookup Test Program' } },
    })
    await prisma.studyProgram.deleteMany({
      where: { name: 'Lesson Lookup Test Program' },
    })
    await prisma.group.deleteMany({
      where: { code: TEST_GROUP_CODE },
    })
    await prisma.user.deleteMany({
      where: { googleId: 'lesson-lookup-test-google-id' },
    })

    // Create test user
    testUser = await prisma.user.create({
      data: {
        googleId: 'lesson-lookup-test-google-id',
        email: 'lesson-lookup-test@example.com',
        name: 'Lesson Lookup Test User',
      },
    })

    // Create test group with code
    testGroup = await prisma.group.create({
      data: {
        name: 'Lesson Lookup Test Group',
        code: TEST_GROUP_CODE,
        creatorId: testUser.id,
        isActive: true,
      },
    })

    // Create test study program
    testProgram = await prisma.studyProgram.create({
      data: {
        name: 'Lesson Lookup Test Program',
        description: 'A test program for lesson lookup',
        days: 7,
        creatorId: testUser.id,
        isActive: true,
      },
    })

    // Create test lesson with activity
    testLesson = await prisma.lesson.create({
      data: {
        studyProgramId: testProgram.id,
        dayNumber: 1,
        activities: {
          create: {
            activityType: 'USER_INPUT',
            orderNumber: 1,
            title: 'Scripture',
          },
        },
      },
    })

    // Create enrollment
    const startDate = new Date()
    const endDate = new Date()
    endDate.setDate(endDate.getDate() + 7)

    testEnrollment = await prisma.enrollment.create({
      data: {
        groupId: testGroup.id,
        studyProgramId: testProgram.id,
        startDate,
        endDate,
        enabledDays: JSON.stringify(['Mon', 'Tue', 'Wed', 'Thu', 'Fri']),
        createdById: testUser.id,
      },
    })

    // Create lesson schedule with study code
    testLessonSchedule = await prisma.lessonSchedule.create({
      data: {
        enrollmentId: testEnrollment.id,
        lessonId: testLesson.id,
        scheduledDate: new Date(),
        code: TEST_STUDY_CODE,
      },
    })

    // Create scheduled activity (flat copy for enrolled lesson)
    const lessonActivity = await prisma.lessonActivity.findFirst({
      where: { lessonId: testLesson.id },
    })
    if (lessonActivity) {
      await prisma.scheduledLessonActivity.create({
        data: {
          lessonScheduleId: testLessonSchedule.id,
          type: lessonActivity.activityType,
          orderNumber: lessonActivity.orderNumber,
          title: lessonActivity.title,
          sourceLessonActivityId: lessonActivity.id,
        },
      })
    }
  })

  afterEach(async () => {
    // Clean up in correct order
    await prisma.scheduledLessonActivity.deleteMany({
      where: { lessonSchedule: { code: TEST_STUDY_CODE } },
    })
    await prisma.lessonSchedule.deleteMany({
      where: { code: TEST_STUDY_CODE },
    })
    await prisma.enrollment.deleteMany({
      where: { group: { code: TEST_GROUP_CODE } },
    })
    await prisma.lessonActivity.deleteMany({
      where: { lesson: { studyProgram: { name: 'Lesson Lookup Test Program' } } },
    })
    await prisma.lesson.deleteMany({
      where: { studyProgram: { name: 'Lesson Lookup Test Program' } },
    })
    await prisma.studyProgram.deleteMany({
      where: { name: 'Lesson Lookup Test Program' },
    })
    await prisma.group.deleteMany({
      where: { code: TEST_GROUP_CODE },
    })
    await prisma.user.deleteMany({
      where: { googleId: 'lesson-lookup-test-google-id' },
    })
  })

  describe('GET /api/lessons/code/:code', () => {
    it('returns lesson and group info for valid study code', async () => {
      const response = await request(app).get(`/api/lessons/code/${TEST_STUDY_CODE}`)

      expect(response.status).toBe(200)
      expect(response.body.success).toBe(true)
      expect(response.body.lesson).toBeDefined()
      expect(response.body.lesson.code).toBe(TEST_STUDY_CODE)
      expect(response.body.lesson.dayNumber).toBe(1)
      expect(response.body.lesson.group).toBeDefined()
      expect(response.body.lesson.group.id).toBe(testGroup.id)
      expect(response.body.lesson.group.code).toBe(TEST_GROUP_CODE)
      expect(response.body.lesson.group.name).toBe('Lesson Lookup Test Group')
      expect(response.body.lesson.studyProgram).toBeDefined()
      expect(response.body.lesson.studyProgram.name).toBe('Lesson Lookup Test Program')
    })

    it('returns lesson with activities', async () => {
      const response = await request(app).get(`/api/lessons/code/${TEST_STUDY_CODE}`)

      expect(response.status).toBe(200)
      expect(response.body.lesson.activities).toBeDefined()
      expect(response.body.lesson.activities.length).toBeGreaterThan(0)
      expect(response.body.lesson.activities[0].type).toBe('USER_INPUT')
    })

    it('is case-insensitive for study code', async () => {
      const response = await request(app).get(`/api/lessons/code/${TEST_STUDY_CODE.toLowerCase()}`)

      expect(response.status).toBe(200)
      expect(response.body.success).toBe(true)
      expect(response.body.lesson.code).toBe(TEST_STUDY_CODE)
    })

    it('returns 400 for invalid code format (too short)', async () => {
      const response = await request(app).get('/api/lessons/code/ABC')

      expect(response.status).toBe(400)
      expect(response.body.success).toBe(false)
      expect(response.body.error).toContain('Invalid')
    })

    it('returns 400 for invalid code format (too long)', async () => {
      const response = await request(app).get('/api/lessons/code/ABC12345')

      expect(response.status).toBe(400)
      expect(response.body.success).toBe(false)
    })

    it('returns 400 for invalid code format (special characters)', async () => {
      const response = await request(app).get('/api/lessons/code/ABC-12')

      expect(response.status).toBe(400)
      expect(response.body.success).toBe(false)
    })

    it('returns 404 for valid format but non-existent code', async () => {
      const response = await request(app).get('/api/lessons/code/ZZZZZZ')

      expect(response.status).toBe(404)
      expect(response.body.success).toBe(false)
      expect(response.body.error).toContain('not found')
    })
  })

  describe('GET /api/lessons/view/:scheduleId', () => {
    it('returns lesson and group info for valid UUID', async () => {
      const response = await request(app).get(`/api/lessons/view/${testLessonSchedule.id}`)

      expect(response.status).toBe(200)
      expect(response.body.success).toBe(true)
      expect(response.body.lesson).toBeDefined()
      expect(response.body.lesson.code).toBe(TEST_STUDY_CODE)
      expect(response.body.lesson.dayNumber).toBe(1)
      expect(response.body.lesson.group).toBeDefined()
      expect(response.body.lesson.group.id).toBe(testGroup.id)
      expect(response.body.lesson.group.code).toBe(TEST_GROUP_CODE)
      expect(response.body.lesson.group.name).toBe('Lesson Lookup Test Group')
    })

    it('returns lesson with study program info', async () => {
      const response = await request(app).get(`/api/lessons/view/${testLessonSchedule.id}`)

      expect(response.status).toBe(200)
      expect(response.body.lesson.studyProgram).toBeDefined()
      expect(response.body.lesson.studyProgram.name).toBe('Lesson Lookup Test Program')
      expect(response.body.lesson.studyProgram.days).toBe(7)
    })

    it('returns lesson with activities', async () => {
      const response = await request(app).get(`/api/lessons/view/${testLessonSchedule.id}`)

      expect(response.status).toBe(200)
      expect(response.body.lesson.activities).toBeDefined()
      expect(response.body.lesson.activities.length).toBeGreaterThan(0)
    })

    it('returns 404 for non-existent UUID', async () => {
      const fakeUUID = '00000000-0000-0000-0000-000000000000'
      const response = await request(app).get(`/api/lessons/view/${fakeUUID}`)

      expect(response.status).toBe(404)
      expect(response.body.success).toBe(false)
      expect(response.body.error).toContain('not found')
    })
  })

  describe('Study Join User Stories', () => {
    it('User Story 1: SMS link with study code returns all info needed for join flow', async () => {
      // User clicks: https://app.makeready.org/join/study/ABC123
      const response = await request(app).get(`/api/lessons/code/${TEST_STUDY_CODE}`)

      expect(response.status).toBe(200)

      // Client needs group.code to redirect to /join/group/:code
      expect(response.body.lesson.group.code).toBeDefined()
      expect(response.body.lesson.group.code).toBe(TEST_GROUP_CODE)

      // Client needs group.id to store in sessionStorage
      expect(response.body.lesson.group.id).toBeDefined()

      // Client needs lesson.code to store as pendingStudyCode
      expect(response.body.lesson.code).toBeDefined()
    })

    it('User Story 2: UUID link returns all info needed for join flow', async () => {
      // User clicks: https://app.makeready.org/join/study/765c2f2e-...
      const response = await request(app).get(`/api/lessons/view/${testLessonSchedule.id}`)

      expect(response.status).toBe(200)

      // Client needs group.code to redirect to /join/group/:code
      expect(response.body.lesson.group.code).toBeDefined()

      // Client needs group.id to store in sessionStorage
      expect(response.body.lesson.group.id).toBeDefined()

      // Client needs lesson.code to store as pendingStudyCode
      expect(response.body.lesson.code).toBeDefined()
    })

    it('User Story 3: Non-existent study code shows clear error', async () => {
      // Use a valid 6-char format that doesn't exist
      const response = await request(app).get('/api/lessons/code/XXXXXX')

      expect(response.status).toBe(404)
      expect(response.body.success).toBe(false)
      // Client will show: "Study not found. Please check your link and try again."
    })
  })
})
