/**
 * Lesson Activities Integration Tests
 *
 * Tests the lesson activity API with the template-based activity model.
 * Uses real PostgreSQL database (same as CI).
 *
 * Run locally:
 *   1. Start PostgreSQL: docker compose -f ../client/docker-compose.test.yml up -d postgres
 *   2. Set DATABASE_URL: export DATABASE_URL="postgresql://test:test@localhost:5433/makeready_test"
 *   3. Run tests: npm test -- test/lesson-activities.test.ts
 */

import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest'
import { PrismaClient } from '../src/generated/prisma/index.js'
import {
  createLessonWithActivities,
  createTestMember,
  cleanupTestData,
  type LessonWithActivitiesResult,
} from './fixtures/lesson-fixtures.js'
import { getMemberLessonDetail } from '../src/services/member-progress.service.js'

// ============================================================================
// Test Setup
// ============================================================================

const prisma = new PrismaClient()

beforeAll(async () => {
  await prisma.$connect()
})

afterAll(async () => {
  await prisma.$disconnect()
})

beforeEach(async () => {
  await cleanupTestData(prisma)
})

// ============================================================================
// Lesson Structure Tests
// ============================================================================

describe('Lesson Activities', () => {
  describe('getMemberLessonDetail', () => {
    it('should return lesson with single USER_INPUT activity', async () => {
      const { member, schedule } = await createLessonWithActivities(prisma, {
        activities: ['USER_INPUT'],
      })

      const result = await getMemberLessonDetail(member.id, schedule.id)

      expect(result.success).toBe(true)
      expect(result.data).toBeDefined()
      expect(result.data?.activities).toHaveLength(1)
      expect(result.data?.activities[0].type).toBe('USER_INPUT')
    })

    it('should return lesson with VIDEO activity', async () => {
      const { member, schedule } = await createLessonWithActivities(prisma, {
        activities: ['VIDEO'],
      })

      const result = await getMemberLessonDetail(member.id, schedule.id)

      expect(result.success).toBe(true)
      expect(result.data?.activities).toHaveLength(1)
      expect(result.data?.activities[0].type).toBe('VIDEO')
    })

    it('should return lesson with mixed activities', async () => {
      const { member, schedule } = await createLessonWithActivities(prisma, {
        activities: ['READ', 'USER_INPUT', 'VIDEO'],
      })

      const result = await getMemberLessonDetail(member.id, schedule.id)

      expect(result.success).toBe(true)
      expect(result.data?.activities).toHaveLength(3)
      expect(result.data?.activities[0].type).toBe('READ')
      expect(result.data?.activities[1].type).toBe('USER_INPUT')
      expect(result.data?.activities[2].type).toBe('VIDEO')
    })

    it('should return activities in correct order', async () => {
      const { member, schedule } = await createLessonWithActivities(prisma, {
        activities: ['VIDEO', 'USER_INPUT', 'READ', 'USER_INPUT'],
      })

      const result = await getMemberLessonDetail(member.id, schedule.id)

      expect(result.success).toBe(true)
      const types = result.data?.activities.map(a => a.type)
      expect(types).toEqual(['VIDEO', 'USER_INPUT', 'READ', 'USER_INPUT'])
    })

    it('should include source references for READ activities', async () => {
      const { member, schedule } = await createLessonWithActivities(prisma, {
        activities: [
          {
            activityType: 'READ',
            title: 'Scripture',
            sourceReference: {
              passageReference: 'Romans 8:28',
              bookNumber: 45,
              bookName: 'Romans',
              chapterStart: 8,
              verseStart: 28,
              verseEnd: 28,
            },
          },
        ],
      })

      const result = await getMemberLessonDetail(member.id, schedule.id)

      expect(result.success).toBe(true)
      const activity = result.data?.activities[0]
      expect(activity?.sourceReferences).toBeDefined()
      expect(activity?.sourceReferences?.length).toBeGreaterThan(0)
      expect(activity?.sourceReferences?.[0]?.passageReference).toBe('Romans 8:28')
    })

    it('should return 404 for non-existent lesson schedule', async () => {
      const { member } = await createLessonWithActivities(prisma, {
        activities: ['USER_INPUT'],
      })

      const result = await getMemberLessonDetail(member.id, 'non-existent-id')

      expect(result.success).toBe(false)
      expect(result.error).toContain('not found')
    })

    it('should return 403 for member not in group', async () => {
      const { schedule, organization, user } = await createLessonWithActivities(prisma, {
        activities: ['USER_INPUT'],
      })

      const otherGroup = await prisma.group.create({
        data: {
          code: 'OTHER1',
          name: 'Other Group',
          organizationId: organization.id,
          creatorId: user.id,
        },
      })
      const otherMember = await createTestMember(prisma, otherGroup.id)

      const result = await getMemberLessonDetail(otherMember.id, schedule.id)

      expect(result.success).toBe(false)
    })
  })
})

// ============================================================================
// Activity Count Tests (each activity = one step in the new model)
// ============================================================================

describe('Activity Counts', () => {
  it('should count activities correctly for single activity', async () => {
    const { activities } = await createLessonWithActivities(prisma, {
      activities: ['USER_INPUT'],
    })

    expect(activities.length).toBe(1)
  })

  it('should count activities correctly for mixed types', async () => {
    const { activities } = await createLessonWithActivities(prisma, {
      activities: ['READ', 'USER_INPUT', 'USER_INPUT', 'USER_INPUT'],
    })

    // SOAP-like pattern: READ + 3 USER_INPUT = 4 activities
    expect(activities.length).toBe(4)
  })

  it('should count activities correctly for various combinations', async () => {
    const testCases = [
      { activities: ['USER_INPUT'] as const, expected: 1 },
      { activities: ['VIDEO'] as const, expected: 1 },
      { activities: ['READ', 'USER_INPUT'] as const, expected: 2 },
      { activities: ['VIDEO', 'USER_INPUT'] as const, expected: 2 },
      { activities: ['READ', 'USER_INPUT', 'USER_INPUT', 'USER_INPUT'] as const, expected: 4 },
    ]

    for (const testCase of testCases) {
      await cleanupTestData(prisma)
      const { activities } = await createLessonWithActivities(prisma, {
        activities: testCase.activities as unknown as ('USER_INPUT' | 'VIDEO' | 'READ')[],
      })
      expect(activities.length).toBe(testCase.expected)
    }
  })
})

// ============================================================================
// Activity Progress Tests
// ============================================================================

describe('Activity Progress', () => {
  it('should start with no progress', async () => {
    const { member, schedule } = await createLessonWithActivities(prisma, {
      activities: ['USER_INPUT'],
    })

    const result = await getMemberLessonDetail(member.id, schedule.id)

    expect(result.success).toBe(true)
    expect(result.data?.activities[0].progress).toBeNull()
    expect(result.data?.activities[0].notes).toEqual([])
  })
})
