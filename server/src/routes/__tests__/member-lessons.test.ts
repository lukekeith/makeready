/**
 * Member Lesson Progress Tests
 *
 * Tests for member lesson progress tracking:
 * - GET /api/member/lessons - List lessons with completion status
 * - GET /api/member/lessons/:lessonScheduleId - Detailed lesson with progress
 * - GET /api/member/enrollments - Enrollment progress summary
 * - GET /api/member/enrollments/:enrollmentId - Detailed enrollment progress
 * - POST /api/member/activities/:id/video-progress - Save video progress
 * - GET /api/member/activities/:id/video-progress - Get video progress
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import request from 'supertest'
import { app } from '../../index'
import { prisma } from '../../lib/prisma'
import * as twilioService from '../../services/twilio'

// Mock Twilio service
vi.mock('../../services/twilio', () => ({
  sendVerificationCode: vi.fn(),
  verifyCode: vi.fn(),
}))

describe('Member Lesson Progress API', () => {
  // Test data
  let testUser: any
  let testOrganization: any
  let testGroup: any
  let testMember: any
  let testProgram: any
  let testLesson: any
  let testActivity: any
  let testVideoActivity: any
  let testScheduledActivity: any
  let testScheduledVideoActivity: any
  let testEnrollment: any
  let testLessonSchedule: any
  let memberCookies: string[]

  const testPhoneNumber = '+15555550001'

  beforeEach(async () => {
    // Clean up test data in correct order
    await prisma.memberVideoProgress.deleteMany({})
    await prisma.memberActivityProgress.deleteMany({})
    await prisma.noteLink.deleteMany({})
    await prisma.studyNote.deleteMany({})
    await prisma.lessonSchedule.deleteMany({})
    await prisma.enrollment.deleteMany({})
    await prisma.lessonActivity.deleteMany({})
    await prisma.lesson.deleteMany({})
    await prisma.studyProgram.deleteMany({
      where: { creator: { googleId: 'test-member-lessons-google-id' } },
    })
    await prisma.groupMember.deleteMany({})
    await prisma.group.deleteMany({
      where: { creator: { googleId: 'test-member-lessons-google-id' } },
    })
    await prisma.memberOrganization.deleteMany({})
    await prisma.member.deleteMany({ where: { phoneNumber: testPhoneNumber } })
    await prisma.organization.deleteMany({
      where: { owner: { googleId: 'test-member-lessons-google-id' } },
    })
    await prisma.user.deleteMany({ where: { googleId: 'test-member-lessons-google-id' } })

    // Create test user
    testUser = await prisma.user.create({
      data: {
        googleId: 'test-member-lessons-google-id',
        email: 'member-lessons-test@example.com',
        name: 'Member Lessons Test User',
      },
    })

    // Create test organization
    testOrganization = await prisma.organization.create({
      data: {
        name: 'Test Organization',
        ownerId: testUser.id,
        isActive: true,
      },
    })

    // Create test group
    testGroup = await prisma.group.create({
      data: {
        name: 'Test Group',
        creatorId: testUser.id,
        isActive: true,
      },
    })

    // Create test member
    testMember = await prisma.member.create({
      data: {
        phoneNumber: testPhoneNumber,
        phoneVerified: true,
        firstName: 'Test',
        lastName: 'Member',
      },
    })

    // Link member to organization
    await prisma.memberOrganization.create({
      data: {
        memberId: testMember.id,
        organizationId: testOrganization.id,
      },
    })

    // Add member to group
    await prisma.groupMember.create({
      data: {
        groupId: testGroup.id,
        memberId: testMember.id,
        role: 'member',
        isActive: true,
      },
    })

    // Create test study program
    testProgram = await prisma.studyProgram.create({
      data: {
        name: 'Test Program',
        description: 'A test study program',
        days: 30,
        creatorId: testUser.id,
        isActive: true,
      },
    })

    // Create test lesson
    testLesson = await prisma.lesson.create({
      data: {
        studyProgramId: testProgram.id,
        dayNumber: 1,
      },
    })

    // Create USER_INPUT activity
    testActivity = await prisma.lessonActivity.create({
      data: {
        lessonId: testLesson.id,
        activityType: 'USER_INPUT',
        orderNumber: 1,
        title: 'Observation',
      },
    })

    // Create VIDEO activity
    testVideoActivity = await prisma.lessonActivity.create({
      data: {
        lessonId: testLesson.id,
        activityType: 'VIDEO',
        orderNumber: 2,
        title: 'Watch',
        videoUrl: 'https://cloudflare.com/video/test',
      },
    })

    // Create enrollment
    const startDate = new Date()
    const endDate = new Date()
    endDate.setDate(endDate.getDate() + 30)

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

    // Create lesson schedule
    testLessonSchedule = await prisma.lessonSchedule.create({
      data: {
        enrollmentId: testEnrollment.id,
        lessonId: testLesson.id,
        scheduledDate: new Date(),
        code: 'TST001',
      },
    })

    // Create scheduled activities (flat copies for enrolled lesson)
    testScheduledActivity = await prisma.scheduledLessonActivity.create({
      data: {
        lessonScheduleId: testLessonSchedule.id,
        type: testActivity.activityType,
        orderNumber: testActivity.orderNumber,
        title: testActivity.title,
        sourceLessonActivityId: testActivity.id,
      },
    })

    testScheduledVideoActivity = await prisma.scheduledLessonActivity.create({
      data: {
        lessonScheduleId: testLessonSchedule.id,
        type: testVideoActivity.activityType,
        orderNumber: testVideoActivity.orderNumber,
        title: testVideoActivity.title,
        videoUrl: testVideoActivity.videoUrl,
        sourceLessonActivityId: testVideoActivity.id,
      },
    })

    // Create member session
    vi.mocked(twilioService.verifyCode).mockResolvedValue({
      success: true,
      valid: true,
    })

    const verifyResponse = await request(app)
      .post('/api/members/confirm-verification')
      .send({
        phoneNumber: testPhoneNumber,
        code: '123456',
        organizationId: testOrganization.id,
      })

    const setCookie = verifyResponse.headers['set-cookie']
    memberCookies = Array.isArray(setCookie) ? setCookie : setCookie ? [setCookie] : []
  })

  afterEach(async () => {
    vi.clearAllMocks()
  })

  // ============================================================================
  // GET /api/member/lessons Tests
  // ============================================================================

  describe('GET /api/member/lessons', () => {
    it('should return 401 when not authenticated', async () => {
      const response = await request(app).get('/api/member/lessons')

      expect(response.status).toBe(401)
      expect(response.body.success).toBe(false)
    })

    it('should return lessons for authenticated member', async () => {
      const response = await request(app)
        .get('/api/member/lessons')
        .set('Cookie', memberCookies)

      expect(response.status).toBe(200)
      expect(response.body.success).toBe(true)
      expect(response.body).toHaveProperty('lessons')
      expect(response.body).toHaveProperty('pagination')
      expect(Array.isArray(response.body.lessons)).toBe(true)
    })

    it('should return lessons with correct structure', async () => {
      const response = await request(app)
        .get('/api/member/lessons')
        .set('Cookie', memberCookies)

      expect(response.status).toBe(200)
      expect(response.body.lessons.length).toBeGreaterThan(0)

      const lesson = response.body.lessons[0]
      expect(lesson).toHaveProperty('lessonScheduleId')
      expect(lesson).toHaveProperty('code')
      expect(lesson).toHaveProperty('dayNumber')
      expect(lesson).toHaveProperty('scheduledDate')
      expect(lesson).toHaveProperty('status')
      expect(lesson).toHaveProperty('completionPercentage')
      expect(lesson).toHaveProperty('activitiesCompleted')
      expect(lesson).toHaveProperty('activitiesTotal')
      expect(lesson).toHaveProperty('studyProgram')
      expect(lesson).toHaveProperty('group')
    })

    it('should filter lessons by status=completed', async () => {
      // Complete an activity first
      await prisma.memberActivityProgress.create({
        data: {
          memberId: testMember.id,
          lessonScheduleId: testLessonSchedule.id,
          scheduledActivityId: testScheduledActivity.id,
          completedAt: new Date(),
        },
      })

      await prisma.memberVideoProgress.create({
        data: {
          memberId: testMember.id,
          lessonScheduleId: testLessonSchedule.id,
          scheduledActivityId: testScheduledVideoActivity.id,
          watchedSeconds: 300,
          totalDuration: 300,
          watchPercentage: 100,
          completedAt: new Date(),
        },
      })

      const response = await request(app)
        .get('/api/member/lessons?status=completed')
        .set('Cookie', memberCookies)

      expect(response.status).toBe(200)
      expect(response.body.lessons.length).toBe(1)
      expect(response.body.lessons[0].status).toBe('completed')
    })

    it('should filter lessons by enrollmentId', async () => {
      const response = await request(app)
        .get(`/api/member/lessons?enrollmentId=${testEnrollment.id}`)
        .set('Cookie', memberCookies)

      expect(response.status).toBe(200)
      expect(response.body.lessons.length).toBeGreaterThan(0)
    })

    it('should paginate results with limit and offset', async () => {
      const response = await request(app)
        .get('/api/member/lessons?limit=1&offset=0')
        .set('Cookie', memberCookies)

      expect(response.status).toBe(200)
      expect(response.body.pagination).toHaveProperty('total')
      expect(response.body.pagination).toHaveProperty('limit', 1)
      expect(response.body.pagination).toHaveProperty('offset', 0)
      expect(response.body.pagination).toHaveProperty('hasMore')
    })

    it('should reject invalid query parameters', async () => {
      const response = await request(app)
        .get('/api/member/lessons?status=invalid')
        .set('Cookie', memberCookies)

      expect(response.status).toBe(400)
      expect(response.body.success).toBe(false)
    })
  })

  // ============================================================================
  // GET /api/member/lessons/:lessonScheduleId Tests
  // ============================================================================

  describe('GET /api/member/lessons/:lessonScheduleId', () => {
    it('should return 401 when not authenticated', async () => {
      const response = await request(app).get(
        `/api/member/lessons/${testLessonSchedule.id}`
      )

      expect(response.status).toBe(401)
      expect(response.body.success).toBe(false)
    })

    it('should return detailed lesson for authenticated member', async () => {
      const response = await request(app)
        .get(`/api/member/lessons/${testLessonSchedule.id}`)
        .set('Cookie', memberCookies)

      expect(response.status).toBe(200)
      expect(response.body.success).toBe(true)
      expect(response.body).toHaveProperty('lesson')
    })

    it('should return lesson with activities and progress', async () => {
      // Add some progress
      await prisma.memberActivityProgress.create({
        data: {
          memberId: testMember.id,
          lessonScheduleId: testLessonSchedule.id,
          scheduledActivityId: testScheduledActivity.id,
          startedAt: new Date(),
        },
      })

      const response = await request(app)
        .get(`/api/member/lessons/${testLessonSchedule.id}`)
        .set('Cookie', memberCookies)

      expect(response.status).toBe(200)
      const lesson = response.body.lesson
      expect(lesson).toHaveProperty('activities')
      expect(lesson.activities.length).toBe(2)

      const userInputActivity = lesson.activities.find((a: any) => a.type === 'USER_INPUT')
      expect(userInputActivity).toHaveProperty('progress')
      expect(userInputActivity.progress.startedAt).toBeTruthy()
    })

    it('should return 404 for non-existent lesson', async () => {
      const response = await request(app)
        .get('/api/member/lessons/00000000-0000-0000-0000-000000000000')
        .set('Cookie', memberCookies)

      expect(response.status).toBe(404)
      expect(response.body.success).toBe(false)
    })

    it('should return 400 for invalid UUID', async () => {
      const response = await request(app)
        .get('/api/member/lessons/invalid-uuid')
        .set('Cookie', memberCookies)

      expect(response.status).toBe(400)
      expect(response.body.success).toBe(false)
    })
  })

  // ============================================================================
  // GET /api/member/enrollments Tests
  // ============================================================================

  describe('GET /api/member/enrollments', () => {
    it('should return 401 when not authenticated', async () => {
      const response = await request(app).get('/api/member/enrollments')

      expect(response.status).toBe(401)
      expect(response.body.success).toBe(false)
    })

    it('should return enrollments for authenticated member', async () => {
      const response = await request(app)
        .get('/api/member/enrollments')
        .set('Cookie', memberCookies)

      expect(response.status).toBe(200)
      expect(response.body.success).toBe(true)
      expect(response.body).toHaveProperty('enrollments')
      expect(Array.isArray(response.body.enrollments)).toBe(true)
    })

    it('should return enrollments with progress summary', async () => {
      const response = await request(app)
        .get('/api/member/enrollments')
        .set('Cookie', memberCookies)

      expect(response.status).toBe(200)
      expect(response.body.enrollments.length).toBeGreaterThan(0)

      const enrollment = response.body.enrollments[0]
      expect(enrollment).toHaveProperty('id')
      expect(enrollment).toHaveProperty('startDate')
      expect(enrollment).toHaveProperty('endDate')
      expect(enrollment).toHaveProperty('studyProgram')
      expect(enrollment).toHaveProperty('group')
      expect(enrollment).toHaveProperty('progress')

      const progress = enrollment.progress
      expect(progress).toHaveProperty('totalDays')
      expect(progress).toHaveProperty('completedDays')
      expect(progress).toHaveProperty('currentDay')
      expect(progress).toHaveProperty('daysAhead')
      expect(progress).toHaveProperty('completionPercentage')
    })
  })

  // ============================================================================
  // GET /api/member/enrollments/:enrollmentId Tests
  // ============================================================================

  describe('GET /api/member/enrollments/:enrollmentId', () => {
    it('should return 401 when not authenticated', async () => {
      const response = await request(app).get(
        `/api/member/enrollments/${testEnrollment.id}`
      )

      expect(response.status).toBe(401)
      expect(response.body.success).toBe(false)
    })

    it('should return detailed enrollment progress', async () => {
      const response = await request(app)
        .get(`/api/member/enrollments/${testEnrollment.id}`)
        .set('Cookie', memberCookies)

      expect(response.status).toBe(200)
      expect(response.body.success).toBe(true)
      expect(response.body).toHaveProperty('enrollment')
      expect(response.body).toHaveProperty('lessons')
    })

    it('should return day-by-day lesson breakdown', async () => {
      const response = await request(app)
        .get(`/api/member/enrollments/${testEnrollment.id}`)
        .set('Cookie', memberCookies)

      expect(response.status).toBe(200)
      expect(Array.isArray(response.body.lessons)).toBe(true)

      if (response.body.lessons.length > 0) {
        const lesson = response.body.lessons[0]
        expect(lesson).toHaveProperty('dayNumber')
        expect(lesson).toHaveProperty('lessonScheduleId')
        expect(lesson).toHaveProperty('scheduledDate')
        expect(lesson).toHaveProperty('status')
        expect(lesson).toHaveProperty('completionPercentage')
      }
    })

    it('should return 404 for non-existent enrollment', async () => {
      const response = await request(app)
        .get('/api/member/enrollments/00000000-0000-0000-0000-000000000000')
        .set('Cookie', memberCookies)

      expect(response.status).toBe(404)
      expect(response.body.success).toBe(false)
    })
  })

  // ============================================================================
  // POST /api/member/activities/:id/video-progress Tests
  // ============================================================================

  describe('POST /api/member/activities/:lessonActivityId/video-progress', () => {
    it('should return 401 when not authenticated', async () => {
      const response = await request(app)
        .post(`/api/member/activities/${testScheduledVideoActivity.id}/video-progress`)
        .send({
          lessonScheduleId: testLessonSchedule.id,
          watchedSeconds: 60,
          totalDuration: 300,
        })

      expect(response.status).toBe(401)
      expect(response.body.success).toBe(false)
    })

    it('should save video progress for authenticated member', async () => {
      const response = await request(app)
        .post(`/api/member/activities/${testScheduledVideoActivity.id}/video-progress`)
        .set('Cookie', memberCookies)
        .send({
          lessonScheduleId: testLessonSchedule.id,
          watchedSeconds: 60,
          totalDuration: 300,
        })

      expect(response.status).toBe(200)
      expect(response.body.success).toBe(true)
      expect(response.body).toHaveProperty('data')
      expect(response.body.data.watchedSeconds).toBe(60)
      expect(response.body.data.watchPercentage).toBe(20)
    })

    it('should auto-complete video at 90% watched', async () => {
      const response = await request(app)
        .post(`/api/member/activities/${testScheduledVideoActivity.id}/video-progress`)
        .set('Cookie', memberCookies)
        .send({
          lessonScheduleId: testLessonSchedule.id,
          watchedSeconds: 270,
          totalDuration: 300,
        })

      expect(response.status).toBe(200)
      expect(response.body.data.watchPercentage).toBe(90)
      expect(response.body.data.completedAt).not.toBeNull()
    })

    it('should not mark complete below 90%', async () => {
      const response = await request(app)
        .post(`/api/member/activities/${testScheduledVideoActivity.id}/video-progress`)
        .set('Cookie', memberCookies)
        .send({
          lessonScheduleId: testLessonSchedule.id,
          watchedSeconds: 260,
          totalDuration: 300,
        })

      expect(response.status).toBe(200)
      expect(response.body.data.watchPercentage).toBeCloseTo(86.67, 1)
      expect(response.body.data.completedAt).toBeNull()
    })

    it('should update existing progress', async () => {
      // First save
      await request(app)
        .post(`/api/member/activities/${testScheduledVideoActivity.id}/video-progress`)
        .set('Cookie', memberCookies)
        .send({
          lessonScheduleId: testLessonSchedule.id,
          watchedSeconds: 60,
          totalDuration: 300,
        })

      // Update
      const response = await request(app)
        .post(`/api/member/activities/${testScheduledVideoActivity.id}/video-progress`)
        .set('Cookie', memberCookies)
        .send({
          lessonScheduleId: testLessonSchedule.id,
          watchedSeconds: 180,
          totalDuration: 300,
        })

      expect(response.status).toBe(200)
      expect(response.body.data.watchedSeconds).toBe(180)
      expect(response.body.data.watchPercentage).toBe(60)
    })

    it('should reject non-VIDEO activity', async () => {
      const response = await request(app)
        .post(`/api/member/activities/${testScheduledActivity.id}/video-progress`)
        .set('Cookie', memberCookies)
        .send({
          lessonScheduleId: testLessonSchedule.id,
          watchedSeconds: 60,
          totalDuration: 300,
        })

      expect(response.status).toBe(400)
      expect(response.body.success).toBe(false)
      expect(response.body.error).toContain('not a video')
    })

    it('should require lessonScheduleId', async () => {
      const response = await request(app)
        .post(`/api/member/activities/${testScheduledVideoActivity.id}/video-progress`)
        .set('Cookie', memberCookies)
        .send({
          watchedSeconds: 60,
          totalDuration: 300,
        })

      expect(response.status).toBe(400)
      expect(response.body.success).toBe(false)
    })

    it('should validate watchedSeconds is non-negative', async () => {
      const response = await request(app)
        .post(`/api/member/activities/${testScheduledVideoActivity.id}/video-progress`)
        .set('Cookie', memberCookies)
        .send({
          lessonScheduleId: testLessonSchedule.id,
          watchedSeconds: -10,
          totalDuration: 300,
        })

      expect(response.status).toBe(400)
      expect(response.body.success).toBe(false)
    })
  })

  // ============================================================================
  // GET /api/member/activities/:id/video-progress Tests
  // ============================================================================

  describe('GET /api/member/activities/:lessonActivityId/video-progress', () => {
    it('should return 401 when not authenticated', async () => {
      const response = await request(app).get(
        `/api/member/activities/${testScheduledVideoActivity.id}/video-progress?lessonScheduleId=${testLessonSchedule.id}`
      )

      expect(response.status).toBe(401)
      expect(response.body.success).toBe(false)
    })

    it('should return null for no progress', async () => {
      const response = await request(app)
        .get(
          `/api/member/activities/${testScheduledVideoActivity.id}/video-progress?lessonScheduleId=${testLessonSchedule.id}`
        )
        .set('Cookie', memberCookies)

      expect(response.status).toBe(200)
      expect(response.body.success).toBe(true)
      expect(response.body.data).toBeNull()
    })

    it('should return existing progress', async () => {
      // Create progress first
      await prisma.memberVideoProgress.create({
        data: {
          memberId: testMember.id,
          lessonScheduleId: testLessonSchedule.id,
          scheduledActivityId: testScheduledVideoActivity.id,
          watchedSeconds: 120,
          totalDuration: 300,
          watchPercentage: 40,
        },
      })

      const response = await request(app)
        .get(
          `/api/member/activities/${testScheduledVideoActivity.id}/video-progress?lessonScheduleId=${testLessonSchedule.id}`
        )
        .set('Cookie', memberCookies)

      expect(response.status).toBe(200)
      expect(response.body.success).toBe(true)
      expect(response.body.data).not.toBeNull()
      expect(response.body.data.watchedSeconds).toBe(120)
      expect(response.body.data.watchPercentage).toBe(40)
    })

    it('should require lessonScheduleId query param', async () => {
      const response = await request(app)
        .get(`/api/member/activities/${testScheduledVideoActivity.id}/video-progress`)
        .set('Cookie', memberCookies)

      expect(response.status).toBe(400)
      expect(response.body.success).toBe(false)
      expect(response.body.error).toContain('lessonScheduleId')
    })
  })

  // ============================================================================
  // Integration: Completion Tracking Tests
  // ============================================================================

  describe('Lesson Completion Tracking', () => {
    it('should calculate correct completion percentage', async () => {
      // Complete one of two activities
      await prisma.memberActivityProgress.create({
        data: {
          memberId: testMember.id,
          lessonScheduleId: testLessonSchedule.id,
          scheduledActivityId: testScheduledActivity.id,
          completedAt: new Date(),
        },
      })

      const response = await request(app)
        .get('/api/member/lessons')
        .set('Cookie', memberCookies)

      expect(response.status).toBe(200)
      const lesson = response.body.lessons[0]
      expect(lesson.activitiesCompleted).toBe(1)
      expect(lesson.activitiesTotal).toBe(2)
      expect(lesson.completionPercentage).toBe(50)
      expect(lesson.status).toBe('in_progress')
    })

    it('should mark lesson as completed when all activities done', async () => {
      // Complete USER_INPUT activity
      await prisma.memberActivityProgress.create({
        data: {
          memberId: testMember.id,
          lessonScheduleId: testLessonSchedule.id,
          scheduledActivityId: testScheduledActivity.id,
          completedAt: new Date(),
        },
      })

      // Complete VIDEO activity
      await prisma.memberVideoProgress.create({
        data: {
          memberId: testMember.id,
          lessonScheduleId: testLessonSchedule.id,
          scheduledActivityId: testScheduledVideoActivity.id,
          watchedSeconds: 300,
          totalDuration: 300,
          watchPercentage: 100,
          completedAt: new Date(),
        },
      })

      const response = await request(app)
        .get('/api/member/lessons')
        .set('Cookie', memberCookies)

      expect(response.status).toBe(200)
      const lesson = response.body.lessons[0]
      expect(lesson.activitiesCompleted).toBe(2)
      expect(lesson.activitiesTotal).toBe(2)
      expect(lesson.completionPercentage).toBe(100)
      expect(lesson.status).toBe('completed')
    })
  })
})
