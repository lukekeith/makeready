/**
 * Lesson Test Data Seed
 *
 * Creates test data for template-based lesson activities:
 * - A study program (The Beatitudes) using SOAP template
 * - Lessons with activities copied from template
 * - Sample enrollment with scheduled activities
 *
 * Run with: npx tsx prisma/seed-lessons.ts
 */

import { PrismaClient, TemplateActivityType } from '../src/generated/prisma/index.js'
import { randomUUID } from 'crypto'

const prisma = new PrismaClient()

// System template IDs (created in migration)
const SOAP_TEMPLATE_ID = 'a0000000-0000-0000-0000-000000000001'

async function main() {
  console.log('🌱 Starting Lesson seed...\n')

  // Get a user to be the creator (use existing or create test user)
  let user = await prisma.user.findFirst()

  if (!user) {
    console.log('📦 Creating test user...')
    user = await prisma.user.create({
      data: {
        id: 'test-user-id',
        googleId: 'test-google-id',
        email: 'test@makeready.local',
        name: 'Test User',
      },
    })
  }
  console.log(`  ✓ Using user: ${user.email}`)

  // Get or create organization
  let organization = await prisma.organization.findFirst({
    where: { ownerId: user.id },
  })

  if (!organization) {
    console.log('🏢 Creating test organization...')
    organization = await prisma.organization.create({
      data: {
        name: 'Test Church',
        ownerId: user.id,
      },
    })
  }
  console.log(`  ✓ Using organization: ${organization.name}`)

  // Get or create group
  let group = await prisma.group.findFirst({
    where: { organizationId: organization.id },
  })

  if (!group) {
    console.log('👥 Creating test group...')
    group = await prisma.group.create({
      data: {
        code: 'BIBLE1',
        name: 'Bible Study Group',
        description: 'A test group for studying the Bible',
        organizationId: organization.id,
        creatorId: user.id,
      },
    })
  }
  console.log(`  ✓ Using group: ${group.name} (code: ${group.code})`)

  // Get SOAP template
  const soapTemplate = await prisma.lessonTemplate.findUnique({
    where: { id: SOAP_TEMPLATE_ID },
    include: {
      activities: { orderBy: { orderNumber: 'asc' } },
    },
  })

  if (!soapTemplate) {
    throw new Error('SOAP system template not found. Run migrations first.')
  }
  console.log(`  ✓ Using template: ${soapTemplate.name} (${soapTemplate.activities.length} activities)`)

  // Create study program
  console.log('\n📚 Creating study program...')
  const studyProgram = await prisma.studyProgram.upsert({
    where: { id: 'beatitudes-program-id' },
    update: {},
    create: {
      id: 'beatitudes-program-id',
      name: 'The Beatitudes',
      description: 'A 7-day study through the Beatitudes from Matthew 5',
      days: 7,
      templateId: SOAP_TEMPLATE_ID,
      creatorId: user.id,
    },
  })
  console.log(`  ✓ Created study program: ${studyProgram.name}`)

  // Create lessons with template activities
  console.log('\n📖 Creating lessons...')

  const beatitudesData = [
    { day: 1, passage: 'Matthew 5:1-3', bookNum: 40, bookName: 'Matthew', chapter: 5, verseStart: 1, verseEnd: 3, title: 'Blessed are the Poor in Spirit' },
    { day: 2, passage: 'Matthew 5:4', bookNum: 40, bookName: 'Matthew', chapter: 5, verseStart: 4, verseEnd: 4, title: 'Blessed are Those Who Mourn' },
    { day: 3, passage: 'Matthew 5:5', bookNum: 40, bookName: 'Matthew', chapter: 5, verseStart: 5, verseEnd: 5, title: 'Blessed are the Meek' },
    { day: 4, passage: 'Matthew 5:6', bookNum: 40, bookName: 'Matthew', chapter: 5, verseStart: 6, verseEnd: 6, title: 'Blessed are Those Who Hunger' },
    { day: 5, passage: 'Matthew 5:7', bookNum: 40, bookName: 'Matthew', chapter: 5, verseStart: 7, verseEnd: 7, title: 'Blessed are the Merciful' },
    { day: 6, passage: 'Matthew 5:8', bookNum: 40, bookName: 'Matthew', chapter: 5, verseStart: 8, verseEnd: 8, title: 'Blessed are the Pure in Heart' },
    { day: 7, passage: 'Matthew 5:9', bookNum: 40, bookName: 'Matthew', chapter: 5, verseStart: 9, verseEnd: 9, title: 'Blessed are the Peacemakers' },
  ]

  for (const beatitude of beatitudesData) {
    // Create or update lesson
    const lesson = await prisma.lesson.upsert({
      where: {
        studyProgramId_dayNumber: {
          studyProgramId: studyProgram.id,
          dayNumber: beatitude.day,
        },
      },
      update: {},
      create: {
        studyProgramId: studyProgram.id,
        dayNumber: beatitude.day,
      },
    })

    // Check if activities already exist
    const existingActivities = await prisma.lessonActivity.findMany({
      where: { lessonId: lesson.id },
    })

    if (existingActivities.length === 0) {
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
              passageReference: beatitude.passage,
              bookNumber: beatitude.bookNum,
              bookName: beatitude.bookName,
              chapterStart: beatitude.chapter,
              verseStart: beatitude.verseStart,
              verseEnd: beatitude.verseEnd,
            },
          })
        }
      }
    }

    console.log(`  ✓ Day ${beatitude.day}: ${beatitude.title}`)
  }

  // Create enrollment
  console.log('\n📝 Creating enrollment...')
  const startDate = new Date()
  const endDate = new Date()
  endDate.setDate(endDate.getDate() + 30) // 30 day program

  const enrollment = await prisma.enrollment.upsert({
    where: { id: 'test-enrollment-id' },
    update: {},
    create: {
      id: 'test-enrollment-id',
      groupId: group.id,
      studyProgramId: studyProgram.id,
      startDate,
      endDate,
      enabledDays: JSON.stringify(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']),
    },
  })
  console.log(`  ✓ Created enrollment for group: ${group.name}`)

  // Create lesson schedules with scheduled activities
  console.log('\n📅 Creating lesson schedules...')
  const lessons = await prisma.lesson.findMany({
    where: { studyProgramId: studyProgram.id },
    orderBy: { dayNumber: 'asc' },
    include: {
      activities: {
        orderBy: { orderNumber: 'asc' },
        include: { sourceReferences: true },
      },
    },
  })

  const scheduleIds: string[] = []
  for (const lesson of lessons) {
    const scheduleDate = new Date()
    scheduleDate.setDate(scheduleDate.getDate() + lesson.dayNumber - 1)

    const schedule = await prisma.lessonSchedule.upsert({
      where: {
        enrollmentId_lessonId: {
          enrollmentId: enrollment.id,
          lessonId: lesson.id,
        },
      },
      update: {},
      create: {
        enrollmentId: enrollment.id,
        lessonId: lesson.id,
        scheduledDate: scheduleDate,
        code: `LSND${lesson.dayNumber.toString().padStart(2, '0')}`,
        templateId: SOAP_TEMPLATE_ID,
        templateName: soapTemplate.name,
      },
    })
    scheduleIds.push(schedule.id)

    // Create scheduled activities (flat copy)
    const existingScheduledActivities = await prisma.scheduledLessonActivity.findMany({
      where: { lessonScheduleId: schedule.id },
    })

    if (existingScheduledActivities.length === 0) {
      for (const activity of lesson.activities) {
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

    console.log(`  ✓ Day ${lesson.dayNumber} scheduled: ${schedule.code}`)
  }

  // Create a test member
  console.log('\n👤 Creating test member...')
  const member = await prisma.member.upsert({
    where: { id: 'test-member-id' },
    update: {},
    create: {
      id: 'test-member-id',
      firstName: 'Test',
      lastName: 'Member',
      phoneNumber: '+15551234567',
      phoneVerified: true,
    },
  })

  // Add member to group via GroupMember
  await prisma.groupMember.upsert({
    where: {
      groupId_memberId: {
        groupId: group.id,
        memberId: member.id,
      },
    },
    update: {},
    create: {
      groupId: group.id,
      memberId: member.id,
      role: 'MEMBER',
    },
  })
  console.log(`  ✓ Created member: ${member.firstName} ${member.lastName}`)

  // Summary
  console.log('\n═══════════════════════════════════════')
  console.log('🎉 Lesson Seed Complete!')
  console.log('═══════════════════════════════════════')
  console.log(`✅ Study Program: ${studyProgram.name} (${studyProgram.id})`)
  console.log(`✅ Template: ${soapTemplate.name}`)
  console.log(`✅ ${lessons.length} lessons created`)
  console.log(`✅ Group: ${group.name} (code: ${group.code})`)
  console.log(`✅ Member: ${member.firstName} ${member.lastName} (${member.id})`)
  console.log('')
  console.log('📋 Lesson Schedule IDs (use for testing):')
  scheduleIds.forEach((id, i) => {
    console.log(`   Day ${i + 1}: ${id}`)
  })
  console.log('')
  console.log('🔗 Test URL:')
  console.log(`   http://localhost:5173/groups/${group.id}/lessons/${scheduleIds[0]}/1`)
  console.log('═══════════════════════════════════════\n')
}

// Run
main()
  .then(async () => {
    await prisma.$disconnect()
    process.exit(0)
  })
  .catch(async (e) => {
    console.error('❌ Seed failed:', e)
    await prisma.$disconnect()
    process.exit(1)
  })
