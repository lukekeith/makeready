/**
 * Development Seed Script
 *
 * Creates realistic test data for local development:
 * - Test user with organization
 * - Sample groups
 * - Study programs with template-based lessons
 * - Enrollments with scheduled activities
 *
 * Run with: npm run db:seed:dev
 */

import { PrismaClient, TemplateActivityType } from '../src/generated/prisma'
import { randomUUID } from 'crypto'

const prisma = new PrismaClient()

// Fixed UUIDs for consistent references
const TEST_USER_ID = '00000000-0000-0000-0000-000000000001'
const TEST_ORG_ID = '00000000-0000-0000-0000-000000000002'
const TEST_GROUP_ID = '00000000-0000-0000-0000-000000000003'
const TEST_PROGRAM_ID = '00000000-0000-0000-0000-000000000004'
const TEST_MEMBER_ID = '00000000-0000-0000-0000-000000000005'

// System template IDs (created in migration)
const SOAP_TEMPLATE_ID = 'a0000000-0000-0000-0000-000000000001'

async function main() {
  console.log('🌱 Starting development seed...')

  // Clear existing test data (order matters for foreign keys)
  console.log('🧹 Clearing existing test data...')
  await prisma.activitySourceReference.deleteMany({})
  await prisma.memberActivityProgress.deleteMany({})
  await prisma.memberVideoProgress.deleteMany({})
  await prisma.memberLessonProgress.deleteMany({})
  await prisma.studyNote.deleteMany({})
  await prisma.noteLink.deleteMany({})
  await prisma.eventAttendee.deleteMany({})
  await prisma.eventAttachment.deleteMany({})
  await prisma.event.deleteMany({})
  await prisma.post.deleteMany({})
  await prisma.scheduledLessonActivity.deleteMany({})
  await prisma.lessonSchedule.deleteMany({})
  await prisma.enrollment.deleteMany({})
  await prisma.lessonActivity.deleteMany({})
  await prisma.lesson.deleteMany({})
  await prisma.studyProgram.deleteMany({})
  await prisma.groupJoinRequest.deleteMany({})
  await prisma.groupMember.deleteMany({})
  await prisma.invite.deleteMany({})
  await prisma.group.deleteMany({})
  await prisma.memberOrganization.deleteMany({})
  await prisma.member.deleteMany({})
  await prisma.userRole.deleteMany({})
  await prisma.rolePermission.deleteMany({})
  await prisma.role.deleteMany({})
  await prisma.permission.deleteMany({})
  await prisma.organization.deleteMany({})
  await prisma.user.deleteMany({})

  // 1. Create test user
  console.log('👤 Creating test user...')
  const testUser = await prisma.user.create({
    data: {
      id: TEST_USER_ID,
      googleId: 'test-google-id-12345',
      email: 'test@makeready.local',
      name: 'Test User',
      phoneNumber: '+15551234567',
      phoneVerified: true,
      isSuperAdmin: true,
    },
  })
  console.log(`   Created user: ${testUser.email}`)

  // 2. Create test organization
  console.log('🏢 Creating test organization...')
  const testOrg = await prisma.organization.create({
    data: {
      id: TEST_ORG_ID,
      name: 'MakeReady Test Church',
      ownerId: TEST_USER_ID,
    },
  })
  console.log(`   Created org: ${testOrg.name}`)

  // 3. Create test member (for phone-auth testing)
  console.log('📱 Creating test member...')
  const testMember = await prisma.member.create({
    data: {
      id: TEST_MEMBER_ID,
      phoneNumber: '+15559876543',
      phoneVerified: true,
      firstName: 'Jane',
      lastName: 'Doe',
      email: 'jane@test.local',
    },
  })
  console.log(`   Created member: ${testMember.firstName} ${testMember.lastName}`)

  // Link member to organization
  await prisma.memberOrganization.create({
    data: {
      memberId: TEST_MEMBER_ID,
      organizationId: TEST_ORG_ID,
    },
  })

  // 4. Create test groups
  console.log('👥 Creating test groups...')
  const groups = await Promise.all([
    prisma.group.create({
      data: {
        id: TEST_GROUP_ID,
        code: 'TSTGRP',
        name: 'Small Group Alpha',
        description: 'A test small group for development',
        creatorId: TEST_USER_ID,
        organizationId: TEST_ORG_ID,
        isPrivate: false,
        allowInvites: true,
        welcomeMessage: 'Welcome to our test group!',
      },
    }),
    prisma.group.create({
      data: {
        code: 'YOUTH1',
        name: 'Youth Group',
        description: 'High school youth group',
        creatorId: TEST_USER_ID,
        organizationId: TEST_ORG_ID,
        isPrivate: true,
        ageRangeMin: 14,
        ageRangeMax: 18,
      },
    }),
    prisma.group.create({
      data: {
        code: 'WOMENS',
        name: "Women's Bible Study",
        description: 'Weekly women\'s study group',
        creatorId: TEST_USER_ID,
        organizationId: TEST_ORG_ID,
      },
    }),
  ])
  console.log(`   Created ${groups.length} groups`)

  // 5. Add members to groups
  console.log('🤝 Adding members to groups...')
  await prisma.groupMember.create({
    data: {
      groupId: TEST_GROUP_ID,
      memberId: TEST_MEMBER_ID,
      role: 'member',
    },
  })

  // 6. Get SOAP template activities for creating lessons
  console.log('📚 Creating study program with SOAP template...')
  const soapTemplate = await prisma.lessonTemplate.findUnique({
    where: { id: SOAP_TEMPLATE_ID },
    include: {
      activities: { orderBy: { orderNumber: 'asc' } },
    },
  })

  if (!soapTemplate) {
    throw new Error('SOAP system template not found. Run migrations first.')
  }

  const soapProgram = await prisma.studyProgram.create({
    data: {
      id: TEST_PROGRAM_ID,
      name: 'Romans: Living by Faith',
      description: 'A 7-day journey through key passages in Romans using the SOAP method.',
      templateId: SOAP_TEMPLATE_ID,
      days: 7,
      creatorId: TEST_USER_ID,
      coverImageUrl: 'https://images.unsplash.com/photo-1504052434569-70ad5836ab65?w=800',
      requireResponse: true,
    },
  })
  console.log(`   Created program: ${soapProgram.name}`)

  // 7. Create lessons for the program (each with template activities + source references)
  console.log('📖 Creating lessons...')
  const passages = [
    { dayNumber: 1, passage: 'Romans 1:1-7', book: 45, bookName: 'Romans', chapter: 1, verseStart: 1, verseEnd: 7 },
    { dayNumber: 2, passage: 'Romans 3:21-26', book: 45, bookName: 'Romans', chapter: 3, verseStart: 21, verseEnd: 26 },
    { dayNumber: 3, passage: 'Romans 5:1-11', book: 45, bookName: 'Romans', chapter: 5, verseStart: 1, verseEnd: 11 },
    { dayNumber: 4, passage: 'Romans 6:1-14', book: 45, bookName: 'Romans', chapter: 6, verseStart: 1, verseEnd: 14 },
    { dayNumber: 5, passage: 'Romans 8:1-17', book: 45, bookName: 'Romans', chapter: 8, verseStart: 1, verseEnd: 17 },
    { dayNumber: 6, passage: 'Romans 8:28-39', book: 45, bookName: 'Romans', chapter: 8, verseStart: 28, verseEnd: 39 },
    { dayNumber: 7, passage: 'Romans 12:1-8', book: 45, bookName: 'Romans', chapter: 12, verseStart: 1, verseEnd: 8 },
  ]

  for (const p of passages) {
    const lesson = await prisma.lesson.create({
      data: {
        studyProgramId: TEST_PROGRAM_ID,
        dayNumber: p.dayNumber,
      },
    })

    // Create activities from template
    for (const tmplActivity of soapTemplate.activities) {
      const activityId = randomUUID()
      await prisma.lessonActivity.create({
        data: {
          id: activityId,
          lessonId: lesson.id,
          activityType: tmplActivity.type,
          orderNumber: tmplActivity.orderNumber,
          title: tmplActivity.title,
          helpTitle: tmplActivity.helpTitle,
          helpDescription: tmplActivity.helpDescription,
          helpAlwaysVisible: tmplActivity.helpAlwaysVisible,
          helpIcon: tmplActivity.helpIcon,
        },
      })

      // Add source reference for READ activities
      if (tmplActivity.type === TemplateActivityType.READ) {
        await prisma.activitySourceReference.create({
          data: {
            lessonActivityId: activityId,
            sourceType: 'SCRIPTURE',
            passageReference: p.passage,
            bookNumber: p.book,
            bookName: p.bookName,
            chapterStart: p.chapter,
            verseStart: p.verseStart,
            verseEnd: p.verseEnd,
          },
        })
      }
    }
  }
  console.log(`   Created ${passages.length} lessons with SOAP template activities`)

  // 8. Create an enrollment
  console.log('📅 Creating enrollment...')
  const startDate = new Date()
  startDate.setHours(0, 0, 0, 0)
  const endDate = new Date(startDate)
  endDate.setDate(endDate.getDate() + 6) // 7 days including start

  const enrollment = await prisma.enrollment.create({
    data: {
      groupId: TEST_GROUP_ID,
      studyProgramId: TEST_PROGRAM_ID,
      startDate,
      endDate,
      enabledDays: JSON.stringify(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']),
      smsTime: '08:00',
      timezone: 'America/Chicago',
      createdById: TEST_USER_ID,
      requireResponse: true,
    },
  })
  console.log(`   Created enrollment for group: ${TEST_GROUP_ID}`)

  // 9. Create lesson schedules with scheduled activities
  console.log('📆 Creating lesson schedules with scheduled activities...')
  const lessons = await prisma.lesson.findMany({
    where: { studyProgramId: TEST_PROGRAM_ID },
    orderBy: { dayNumber: 'asc' },
    include: {
      activities: {
        orderBy: { orderNumber: 'asc' },
        include: { sourceReferences: true },
      },
    },
  })

  for (let i = 0; i < lessons.length; i++) {
    const scheduleDate = new Date(startDate)
    scheduleDate.setDate(scheduleDate.getDate() + i)

    const schedule = await prisma.lessonSchedule.create({
      data: {
        code: `SCHD${String(i + 1).padStart(2, '0')}`,
        enrollmentId: enrollment.id,
        lessonId: lessons[i].id,
        scheduledDate: scheduleDate,
        templateId: SOAP_TEMPLATE_ID,
        templateName: soapTemplate.name,
      },
    })

    // Create scheduled activities (flat copy from lesson activities)
    for (const activity of lessons[i].activities) {
      const saId = randomUUID()
      await prisma.scheduledLessonActivity.create({
        data: {
          id: saId,
          lessonScheduleId: schedule.id,
          type: activity.activityType,
          orderNumber: activity.orderNumber,
          title: activity.title,
          helpTitle: activity.helpTitle,
          helpDescription: activity.helpDescription,
          helpAlwaysVisible: activity.helpAlwaysVisible,
          helpIcon: activity.helpIcon,
          readContent: activity.readContent,
          videoId: activity.videoId,
          videoUrl: activity.videoUrl,
          sourceLessonActivityId: activity.id,
        },
      })

      // Copy source references
      for (const ref of activity.sourceReferences) {
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
    }
  }
  console.log(`   Created ${lessons.length} lesson schedules with scheduled activities`)

  // 10. Create some events
  console.log('🗓️ Creating events...')
  const nextSunday = new Date()
  nextSunday.setDate(nextSunday.getDate() + (7 - nextSunday.getDay()))
  nextSunday.setHours(10, 0, 0, 0)

  await prisma.event.create({
    data: {
      code: 'MTNG01',
      groupId: TEST_GROUP_ID,
      type: 'MEETING',
      title: 'Weekly Group Meeting',
      description: 'Our regular weekly gathering to discuss the study.',
      date: nextSunday,
      startTime: '10:00',
      endTime: '11:30',
      isAllDay: false,
      timezone: 'America/Chicago',
      visibility: 'PRIVATE',
      locationName: 'Room 101',
      locationAddress: '123 Church St, Dallas, TX 75201',
      recurrenceFrequency: 'WEEKLY',
      createdById: TEST_USER_ID,
    },
  })
  console.log('   Created weekly meeting event')

  // 11. Create a welcome post
  console.log('📝 Creating welcome post...')
  await prisma.post.create({
    data: {
      groupId: TEST_GROUP_ID,
      authorId: TEST_USER_ID,
      type: 'WELCOME',
      title: 'Welcome to Romans: Living by Faith!',
      content: 'We are excited to begin this 7-day journey through Romans together. Let\'s grow in our understanding of living by faith!',
      imageUrl: soapProgram.coverImageUrl,
      enrollmentId: enrollment.id,
    },
  })
  console.log('   Created welcome post')

  // Summary
  console.log('')
  console.log('✅ Development seed complete!')
  console.log('')
  console.log('📋 Test Data Summary:')
  console.log(`   User: ${testUser.email} (Google ID: ${testUser.googleId})`)
  console.log(`   Organization: ${testOrg.name}`)
  console.log(`   Member: ${testMember.firstName} ${testMember.lastName} (${testMember.phoneNumber})`)
  console.log(`   Groups: ${groups.length}`)
  console.log(`   Study Program: ${soapProgram.name} (${soapProgram.days} days, template: ${soapTemplate.name})`)
  console.log(`   Enrollment: Active (${enrollment.startDate.toDateString()} - ${enrollment.endDate.toDateString()})`)
  console.log('')
  console.log('🔑 Test Credentials:')
  console.log('   Phone verification code: 123456 (with TEST_VERIFICATION_CODES env var)')
  console.log('')
}

main()
  .catch((e) => {
    console.error('❌ Seed failed:', e)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
