/**
 * One-off repair for enrollments persisted with `startDate > endDate`.
 *
 * Background (monday#12668399336 sub-issue D, monday#12661792842):
 * before commit f8df609 the enrollment date-edit wrote the *requested*
 * startDate while deriving endDate from the resulting schedule set. On a
 * fully-locked enrollment (every lesson already sent or past) no lesson could
 * move, so the requested start could land after the real last lesson — leaving
 * rows like "AUG 3 – JUL 10". f8df609 fixed the write path but repaired
 * nothing already written, so those rows still render impossible ranges.
 *
 * This applies the same rule f8df609 now uses on write: derive BOTH dates from
 * the enrollment's actual active schedules —
 *   startDate = min(scheduledDate), endDate = max(scheduledDate)
 * over `lesson_schedules` with `removedAt IS NULL` (soft-removed schedules are
 * excluded, matching `loadActiveSchedules` in enrollment-edit.ts).
 *
 * Enrollments with no active schedules are reported and skipped: there is
 * nothing to derive from, and inventing dates would be worse than leaving the
 * row visibly wrong for a human to look at.
 *
 * DRY RUN BY DEFAULT — prints what it would change and writes nothing.
 *   npx tsx scripts/repair-enrollment-date-ranges.ts
 * Pass --apply to persist:
 *   npx tsx scripts/repair-enrollment-date-ranges.ts --apply
 */

import { prisma } from '../src/lib/prisma.js'

const APPLY = process.argv.includes('--apply')

function iso(d: Date): string {
  return d.toISOString().slice(0, 10)
}

async function repairEnrollmentDateRanges() {
  console.log(
    APPLY
      ? '🔧 Repairing enrollment date ranges (APPLY — changes will be written)…'
      : '🔍 Repairing enrollment date ranges (DRY RUN — nothing will be written)…'
  )

  // Prisma can't compare two columns in a `where`, so the candidate scan is raw.
  const broken = await prisma.$queryRaw<{ id: string; startDate: Date; endDate: Date }[]>`
    SELECT "id", "startDate", "endDate"
    FROM "enrollments"
    WHERE "startDate" > "endDate"
    ORDER BY "id"
  `

  console.log(`📊 Found ${broken.length} enrollment(s) with startDate > endDate`)
  if (broken.length === 0) {
    console.log('✅ Nothing to repair.')
    return
  }

  let repaired = 0
  let skipped = 0
  let unchanged = 0

  for (const enrollment of broken) {
    const schedules = await prisma.lessonSchedule.findMany({
      where: { enrollmentId: enrollment.id, removedAt: null },
      select: { scheduledDate: true },
    })

    if (schedules.length === 0) {
      console.log(
        `  ⏭️  ${enrollment.id}: ${iso(enrollment.startDate)} → ${iso(enrollment.endDate)} — no active schedules, skipping (nothing to derive from)`
      )
      skipped++
      continue
    }

    const times = schedules.map((s) => s.scheduledDate.getTime())
    const nextStart = new Date(Math.min(...times))
    const nextEnd = new Date(Math.max(...times))

    if (
      nextStart.getTime() === enrollment.startDate.getTime() &&
      nextEnd.getTime() === enrollment.endDate.getTime()
    ) {
      // Would only happen if the schedules themselves are inverted, which this
      // script deliberately does not touch — flag it rather than silently pass.
      console.log(
        `  ⚠️  ${enrollment.id}: derived range equals the stored (broken) range — schedule data itself looks wrong, leaving alone`
      )
      unchanged++
      continue
    }

    console.log(
      `  ✅ ${enrollment.id}: ${iso(enrollment.startDate)} → ${iso(enrollment.endDate)}  ⇒  ${iso(nextStart)} → ${iso(nextEnd)}  (${schedules.length} active schedule${schedules.length === 1 ? '' : 's'})`
    )

    if (APPLY) {
      await prisma.enrollment.update({
        where: { id: enrollment.id },
        data: { startDate: nextStart, endDate: nextEnd },
      })
    }
    repaired++
  }

  console.log('')
  console.log(
    `${APPLY ? '🔧 Repaired' : '🔍 Would repair'}: ${repaired} · skipped (no schedules): ${skipped} · left alone (schedules inverted): ${unchanged}`
  )
  if (!APPLY && repaired > 0) {
    console.log('ℹ️  Re-run with --apply to persist these changes.')
  }
}

repairEnrollmentDateRanges()
  .catch((error) => {
    console.error('❌ Repair failed:', error)
    process.exitCode = 1
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
