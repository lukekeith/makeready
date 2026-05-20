/**
 * Backfill script: Calculate estimatedMinutes for all existing lessons and lesson schedules.
 *
 * Run with: npx tsx src/scripts/backfill-lesson-estimates.ts
 */

import { recalculateLessonEstimate, recalculateScheduledLessonEstimate } from '../services/lesson-estimate.service.js'
import { prisma } from '../lib/prisma.js'

async function main() {
  console.log('Backfilling lesson time estimates...')

  // 1. Backfill all Lessons
  const lessons = await prisma.lesson.findMany({ select: { id: true } })
  console.log(`Found ${lessons.length} lessons to process`)

  let lessonCount = 0
  for (const lesson of lessons) {
    await recalculateLessonEstimate(lesson.id)
    lessonCount++
    if (lessonCount % 50 === 0) {
      console.log(`  Processed ${lessonCount}/${lessons.length} lessons...`)
    }
  }
  console.log(`✓ Processed ${lessonCount} lessons`)

  // 2. Backfill all LessonSchedules
  const schedules = await prisma.lessonSchedule.findMany({ select: { id: true } })
  console.log(`Found ${schedules.length} lesson schedules to process`)

  let scheduleCount = 0
  for (const schedule of schedules) {
    await recalculateScheduledLessonEstimate(schedule.id)
    scheduleCount++
    if (scheduleCount % 100 === 0) {
      console.log(`  Processed ${scheduleCount}/${schedules.length} schedules...`)
    }
  }
  console.log(`✓ Processed ${scheduleCount} lesson schedules`)

  console.log('Done!')
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect())
