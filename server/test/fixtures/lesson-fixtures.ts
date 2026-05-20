/**
 * Lesson Test Fixtures
 *
 * Factory functions for creating test data for lesson-related tests.
 * These fixtures create real database records that can be used in integration tests.
 *
 * Usage:
 *   const { lesson, activities, schedule } = await createLessonWithActivities(prisma, {
 *     activities: ['USER_INPUT', 'VIDEO', 'READ']
 *   })
 */

import { PrismaClient, TemplateActivityType } from '../../src/generated/prisma/index.js'
import { randomUUID } from 'crypto'

// ============================================================================
// Types
// ============================================================================

export interface TestUser {
  id: string
  email: string
  name: string
  googleId: string
}

export interface TestOrganization {
  id: string
  name: string
  ownerId: string
}

export interface TestGroup {
  id: string
  code: string
  name: string
  organizationId: string
  creatorId: string
}

export interface TestMember {
  id: string
  firstName: string
  lastName: string
  phoneNumber: string
}

export interface TestStudyProgram {
  id: string
  name: string
  days: number
  creatorId: string
}

export interface TestLesson {
  id: string
  studyProgramId: string
  dayNumber: number
}

export interface TestLessonActivity {
  id: string
  lessonId: string
  activityType: TemplateActivityType
  orderNumber: number
  title: string
  videoUrl?: string | null
}

export interface TestScheduledActivity {
  id: string
  lessonScheduleId: string
  type: TemplateActivityType
  orderNumber: number
  title: string
  videoUrl?: string | null
  sourceLessonActivityId?: string | null
}

export interface TestEnrollment {
  id: string
  groupId: string
  studyProgramId: string
}

export interface TestLessonSchedule {
  id: string
  enrollmentId: string
  lessonId: string
  code: string
}

// ============================================================================
// Counter for unique IDs
// ============================================================================

let counter = 0
const uniqueId = (prefix: string) => `${prefix}-${Date.now()}-${++counter}`

// ============================================================================
// Base Fixtures
// ============================================================================

export async function createTestUser(
  prisma: PrismaClient,
  overrides: Partial<TestUser> = {}
): Promise<TestUser> {
  const id = overrides.id || uniqueId('user')
  const user = await prisma.user.create({
    data: {
      id,
      email: overrides.email || `test-${id}@makeready.test`,
      name: overrides.name || `Test User ${id}`,
      googleId: overrides.googleId || `google-${id}`,
    },
  })
  return user as TestUser
}

export async function createTestOrganization(
  prisma: PrismaClient,
  ownerId: string,
  overrides: Partial<TestOrganization> = {}
): Promise<TestOrganization> {
  const id = overrides.id || uniqueId('org')
  const org = await prisma.organization.create({
    data: {
      id,
      name: overrides.name || `Test Organization ${id}`,
      ownerId,
    },
  })
  return org as TestOrganization
}

export async function createTestGroup(
  prisma: PrismaClient,
  organizationId: string,
  creatorId: string,
  overrides: Partial<TestGroup> = {}
): Promise<TestGroup> {
  const id = overrides.id || uniqueId('group')
  const group = await prisma.group.create({
    data: {
      id,
      code: overrides.code || id.slice(0, 6).toUpperCase(),
      name: overrides.name || `Test Group ${id}`,
      organizationId,
      creatorId,
    },
  })
  return group as TestGroup
}

export async function createTestMember(
  prisma: PrismaClient,
  groupId: string,
  overrides: Partial<TestMember> = {}
): Promise<TestMember> {
  const id = overrides.id || uniqueId('member')
  const phoneNumber = overrides.phoneNumber || `+1555${Math.floor(Math.random() * 10000000).toString().padStart(7, '0')}`

  const member = await prisma.member.create({
    data: {
      id,
      firstName: overrides.firstName || 'Test',
      lastName: overrides.lastName || `Member ${id.slice(-4)}`,
      phoneNumber,
      phoneVerified: true,
    },
  })

  // Add member to group via GroupMember junction table
  await prisma.groupMember.create({
    data: {
      groupId,
      memberId: member.id,
      role: 'MEMBER',
    },
  })

  return member as TestMember
}

// ============================================================================
// Lesson Fixtures
// ============================================================================

export async function createTestStudyProgram(
  prisma: PrismaClient,
  creatorId: string,
  overrides: Partial<TestStudyProgram> = {}
): Promise<TestStudyProgram> {
  const id = overrides.id || uniqueId('program')
  const program = await prisma.studyProgram.create({
    data: {
      id,
      name: overrides.name || `Test Program ${id}`,
      days: overrides.days || 7,
      creatorId,
    },
  })
  return program as TestStudyProgram
}

export async function createTestLesson(
  prisma: PrismaClient,
  studyProgramId: string,
  dayNumber: number,
  overrides: Partial<TestLesson> = {}
): Promise<TestLesson> {
  const id = overrides.id || uniqueId('lesson')
  const lesson = await prisma.lesson.create({
    data: {
      id,
      studyProgramId,
      dayNumber,
    },
  })
  return lesson as TestLesson
}

export interface CreateActivityOptions {
  activityType: TemplateActivityType
  orderNumber?: number
  title: string
  helpTitle?: string
  helpDescription?: string
  helpIcon?: string
  videoUrl?: string
  sourceReference?: {
    passageReference: string
    bookNumber: number
    bookName: string
    chapterStart: number
    verseStart: number
    verseEnd: number
  }
}

export async function createTestActivity(
  prisma: PrismaClient,
  lessonId: string,
  options: CreateActivityOptions
): Promise<TestLessonActivity> {
  const id = randomUUID()
  const activity = await prisma.lessonActivity.create({
    data: {
      id,
      lessonId,
      activityType: options.activityType,
      orderNumber: options.orderNumber || 1,
      title: options.title,
      helpTitle: options.helpTitle,
      helpDescription: options.helpDescription,
      helpIcon: options.helpIcon,
      videoUrl: options.videoUrl,
    },
  })

  // Create source reference if provided
  if (options.sourceReference) {
    await prisma.activitySourceReference.create({
      data: {
        lessonActivityId: id,
        sourceType: 'SCRIPTURE',
        passageReference: options.sourceReference.passageReference,
        bookNumber: options.sourceReference.bookNumber,
        bookName: options.sourceReference.bookName,
        chapterStart: options.sourceReference.chapterStart,
        verseStart: options.sourceReference.verseStart,
        verseEnd: options.sourceReference.verseEnd,
      },
    })
  }

  return activity as unknown as TestLessonActivity
}

// ============================================================================
// Enrollment & Schedule Fixtures
// ============================================================================

export async function createTestEnrollment(
  prisma: PrismaClient,
  groupId: string,
  studyProgramId: string,
  overrides: Partial<TestEnrollment> = {}
): Promise<TestEnrollment> {
  const id = overrides.id || uniqueId('enrollment')
  const startDate = new Date()
  const endDate = new Date()
  endDate.setDate(endDate.getDate() + 30)

  const enrollment = await prisma.enrollment.create({
    data: {
      id,
      groupId,
      studyProgramId,
      startDate,
      endDate,
      enabledDays: JSON.stringify(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']),
    },
  })
  return enrollment as TestEnrollment
}

export async function createTestLessonSchedule(
  prisma: PrismaClient,
  enrollmentId: string,
  lessonId: string,
  overrides: Partial<TestLessonSchedule> = {}
): Promise<TestLessonSchedule> {
  const id = overrides.id || uniqueId('schedule')
  const schedule = await prisma.lessonSchedule.create({
    data: {
      id,
      enrollmentId,
      lessonId,
      scheduledDate: new Date(),
      code: overrides.code || id.slice(0, 6).toUpperCase(),
    },
  })
  return schedule as TestLessonSchedule
}

// ============================================================================
// Composite Fixtures (Most Useful for Tests)
// ============================================================================

export interface CreateLessonWithActivitiesOptions {
  activities: Array<TemplateActivityType | CreateActivityOptions>
  dayNumber?: number
}

export interface LessonWithActivitiesResult {
  user: TestUser
  organization: TestOrganization
  group: TestGroup
  member: TestMember
  studyProgram: TestStudyProgram
  lesson: TestLesson
  activities: TestLessonActivity[]
  scheduledActivities: TestScheduledActivity[]
  enrollment: TestEnrollment
  schedule: TestLessonSchedule
}

/**
 * Creates a complete lesson setup with all dependencies.
 * Also creates ScheduledLessonActivity records (flat copies) for the schedule.
 *
 * @example
 * const result = await createLessonWithActivities(prisma, {
 *   activities: ['USER_INPUT', 'VIDEO', 'READ']
 * })
 */
export async function createLessonWithActivities(
  prisma: PrismaClient,
  options: CreateLessonWithActivitiesOptions
): Promise<LessonWithActivitiesResult> {
  // Create base entities
  const user = await createTestUser(prisma)
  const organization = await createTestOrganization(prisma, user.id)
  const group = await createTestGroup(prisma, organization.id, user.id)
  const member = await createTestMember(prisma, group.id)
  const studyProgram = await createTestStudyProgram(prisma, user.id)

  // Create lesson
  const lesson = await createTestLesson(prisma, studyProgram.id, options.dayNumber || 1)

  // Create activities
  const activities: TestLessonActivity[] = []
  for (let i = 0; i < options.activities.length; i++) {
    const activitySpec = options.activities[i]
    const activityOptions: CreateActivityOptions =
      typeof activitySpec === 'string'
        ? getDefaultActivityOptions(activitySpec as TemplateActivityType, i + 1)
        : { ...activitySpec, orderNumber: activitySpec.orderNumber || i + 1 }

    const activity = await createTestActivity(prisma, lesson.id, activityOptions)
    activities.push(activity)
  }

  // Create enrollment and schedule
  const enrollment = await createTestEnrollment(prisma, group.id, studyProgram.id)
  const schedule = await createTestLessonSchedule(prisma, enrollment.id, lesson.id)

  // Create scheduled activities (flat copies) for the schedule
  const scheduledActivities: TestScheduledActivity[] = []
  for (const activity of activities) {
    const saId = randomUUID()
    const sa = await prisma.scheduledLessonActivity.create({
      data: {
        id: saId,
        lessonScheduleId: schedule.id,
        type: activity.activityType,
        orderNumber: activity.orderNumber,
        title: activity.title,
        videoUrl: activity.videoUrl,
        sourceLessonActivityId: activity.id,
      },
    })

    // Copy source references
    const sourceRefs = await prisma.activitySourceReference.findMany({
      where: { lessonActivityId: activity.id },
    })
    for (const ref of sourceRefs) {
      await prisma.activitySourceReference.create({
        data: {
          scheduledActivityId: saId,
          sourceType: ref.sourceType,
          passageReference: ref.passageReference,
          bookNumber: ref.bookNumber,
          bookName: ref.bookName,
          chapterStart: ref.chapterStart,
          chapterEnd: ref.chapterEnd,
          verseStart: ref.verseStart,
          verseEnd: ref.verseEnd,
        },
      })
    }

    scheduledActivities.push(sa as unknown as TestScheduledActivity)
  }

  return {
    user,
    organization,
    group,
    member,
    studyProgram,
    lesson,
    activities,
    scheduledActivities,
    enrollment,
    schedule,
  }
}

function getDefaultActivityOptions(type: TemplateActivityType, orderNumber: number): CreateActivityOptions {
  if (type === 'VIDEO') {
    return {
      activityType: type,
      orderNumber,
      title: 'Watch',
      videoUrl: 'https://example.com/video.mp4',
    }
  }

  if (type === 'READ') {
    return {
      activityType: type,
      orderNumber,
      title: 'Scripture',
      sourceReference: {
        passageReference: 'Matthew 5:1-3',
        bookNumber: 40,
        bookName: 'Matthew',
        chapterStart: 5,
        verseStart: 1,
        verseEnd: 3,
      },
    }
  }

  // USER_INPUT
  return {
    activityType: type,
    orderNumber,
    title: 'Reflection',
    helpTitle: 'What stands out?',
    helpDescription: 'Write down your thoughts.',
    helpIcon: 'pen',
  }
}

// ============================================================================
// Cleanup Helper
// ============================================================================

/**
 * Cleans up all test data. Call in afterEach/afterAll.
 */
export async function cleanupTestData(prisma: PrismaClient): Promise<void> {
  await prisma.activitySourceReference.deleteMany({})
  await prisma.memberActivityProgress.deleteMany({})
  await prisma.memberVideoProgress.deleteMany({})
  await prisma.memberLessonProgress.deleteMany({})
  await prisma.scheduledLessonActivity.deleteMany({})
  await prisma.lessonSchedule.deleteMany({})
  await prisma.enrollment.deleteMany({})
  await prisma.lessonActivity.deleteMany({})
  await prisma.lesson.deleteMany({})
  await prisma.studyProgram.deleteMany({})
  await prisma.groupMember.deleteMany({})
  await prisma.member.deleteMany({})
  await prisma.group.deleteMany({})
  await prisma.organization.deleteMany({})
  await prisma.user.deleteMany({})
}
