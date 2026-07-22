/**
 * Editing an existing enrollment: reschedule (startDate / enabledDays),
 * change group, and swap study program — with a dry-run preview so the client
 * can warn about destructive/lesson-impacting changes before committing
 * (monday#12270302158).
 *
 * Structural edits are committed atomically (one transaction) so a leader's
 * "Save" either fully lands or leaves the enrollment untouched — the client's
 * "Cancel = nothing saved" contract depends on this.
 *
 * Scheduling rules (shared with the study-sync engine's semantics):
 *  - A schedule is "locked" once its SMS has been sent (`smsSentAt`) or its
 *    date has passed — locked lessons never move.
 *  - Reschedule re-lays only the unlocked (future, unsent) lessons over dates
 *    generated from the new startDate/enabledDays, after the last locked date.
 *  - Study swap removes the old curriculum's schedules (hard-delete those with
 *    no member progress, soft-remove `removedAt` those with progress to keep
 *    history) and rebuilds from the new program — mirrors enrollment-sync.
 */

import { randomUUID } from 'crypto'
import { prisma } from '../lib/prisma.js'
import { generateStudyCode } from '../lib/study-code.js'
import { hashLessonContent } from './lesson-content-hash.js'
import { buildLessonCopyRows, type LessonCopyRows } from './lesson-copy.js'
import { generateScheduleDates, type EnabledDayName } from './enrollment-schedule.js'

const DAY_NAMES: EnabledDayName[] = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

export interface EnrollmentEditChanges {
  groupId?: string
  studyProgramId?: string
  startDate?: string // ISO8601
  enabledDays?: EnabledDayName[]
}

export interface EnrollmentEditPreview {
  groupChange: { fromName: string; toName: string } | null
  reschedule: { lessonsShifted: number; lockedUnchanged: number } | null
  studySwap: {
    fromName: string
    toName: string
    lessonsRemoved: number // hard-deleted (no progress)
    lessonsArchived: number // soft-removed (had progress, kept for history)
    lessonsAdded: number
  } | null
  destructive: boolean
  summary: string[]
}

export class EnrollmentEditError extends Error {
  constructor(message: string, public status = 400) {
    super(message)
    this.name = 'EnrollmentEditError'
  }
}

type ScheduleRow = {
  id: string
  lessonId: string | null
  scheduledDate: Date
  smsSentAt: Date | null
  removedAt: Date | null
}

const isLocked = (s: { scheduledDate: Date; smsSentAt: Date | null }, now: Date) =>
  s.smsSentAt !== null || s.scheduledDate <= now

/** Parse the stored JSON `enabledDays` (e.g. '["Mon","Wed"]') to day names. */
function parseEnabledDays(raw: string | null | undefined): EnabledDayName[] {
  if (!raw) return []
  try {
    const arr = JSON.parse(raw)
    if (Array.isArray(arr)) return arr.filter((d): d is EnabledDayName => DAY_NAMES.includes(d))
  } catch {
    // fall through
  }
  return []
}

async function loadEnrollment(enrollmentId: string) {
  const enrollment = await prisma.enrollment.findUnique({
    where: { id: enrollmentId },
    include: {
      group: { select: { id: true, name: true } },
      studyProgram: { select: { id: true, name: true } },
    },
  })
  if (!enrollment) throw new EnrollmentEditError('Enrollment not found', 404)
  return enrollment
}

/** Non-removed schedules for the enrollment, ordered by their source lesson's dayNumber. */
async function loadActiveSchedules(enrollmentId: string): Promise<ScheduleRow[]> {
  const schedules = await prisma.lessonSchedule.findMany({
    where: { enrollmentId, removedAt: null },
    select: {
      id: true,
      lessonId: true,
      scheduledDate: true,
      smsSentAt: true,
      removedAt: true,
      lesson: { select: { dayNumber: true } },
    },
    orderBy: { scheduledDate: 'asc' },
  })
  // Order by curriculum dayNumber when available (falls back to date order).
  return schedules
    .slice()
    .sort((a, b) => (a.lesson?.dayNumber ?? 0) - (b.lesson?.dayNumber ?? 0))
    .map(({ id, lessonId, scheduledDate, smsSentAt, removedAt }) => ({
      id,
      lessonId,
      scheduledDate,
      smsSentAt,
      removedAt,
    }))
}

/** True if any member has recorded progress against this schedule. */
async function scheduleHasProgress(scheduleId: string): Promise<boolean> {
  const [activity, video, lesson] = await Promise.all([
    prisma.memberActivityProgress.count({ where: { lessonScheduleId: scheduleId } }),
    prisma.memberVideoProgress.count({ where: { lessonScheduleId: scheduleId } }),
    prisma.memberLessonProgress.count({ where: { lessonScheduleId: scheduleId } }),
  ])
  return activity + video + lesson > 0
}

/**
 * Compute the new date for each unlocked lesson given a target startDate +
 * enabledDays, honoring locked lessons (which never move). Returns a map of
 * scheduleId → new date for the unlocked schedules that actually change.
 */
function computeRescheduledDates(
  schedules: ScheduleRow[],
  startDate: Date,
  enabledDays: EnabledDayName[],
  now: Date
): Map<string, Date> {
  const locked = schedules.filter((s) => isLocked(s, now))
  const unlocked = schedules.filter((s) => !isLocked(s, now))

  // Unlocked lessons start after the latest locked date (can't precede a sent
  // lesson) or the requested startDate, whichever is later.
  const lastLockedTime = locked.reduce((max, s) => Math.max(max, s.scheduledDate.getTime()), 0)
  const floor = lastLockedTime > 0 ? new Date(lastLockedTime + 86_400_000) : startDate
  const walkStart = floor.getTime() > startDate.getTime() ? floor : startDate

  const newDates = generateScheduleDates(walkStart, enabledDays, unlocked.length)

  const changes = new Map<string, Date>()
  unlocked.forEach((s, i) => {
    if (s.scheduledDate.getTime() !== newDates[i].getTime()) {
      changes.set(s.id, newDates[i])
    }
  })
  return changes
}

/**
 * Dry-run: describe what the requested edit would do without mutating anything.
 * Powers the client's warning banner and Save-confirmation copy.
 */
export async function previewEnrollmentEdit(
  enrollmentId: string,
  changes: EnrollmentEditChanges
): Promise<EnrollmentEditPreview> {
  const enrollment = await loadEnrollment(enrollmentId)
  const now = new Date()
  const summary: string[] = []
  let destructive = false

  // ── Group change ──────────────────────────────────────────────────────────
  let groupChange: EnrollmentEditPreview['groupChange'] = null
  if (changes.groupId && changes.groupId !== enrollment.groupId) {
    const target = await prisma.group.findFirst({
      where: { id: changes.groupId, isActive: true },
      select: { name: true },
    })
    if (!target) throw new EnrollmentEditError('Target group not found', 404)
    groupChange = { fromName: enrollment.group.name, toName: target.name }
    summary.push(`Moves this enrollment from "${enrollment.group.name}" to "${target.name}".`)
  }

  const swappingStudy = !!changes.studyProgramId && changes.studyProgramId !== enrollment.studyProgramId
  const targetStartDate = changes.startDate ? new Date(changes.startDate) : enrollment.startDate
  const targetEnabledDays = changes.enabledDays ?? parseEnabledDays(enrollment.enabledDays)

  // ── Study swap ────────────────────────────────────────────────────────────
  let studySwap: EnrollmentEditPreview['studySwap'] = null
  if (swappingStudy) {
    const target = await prisma.studyProgram.findFirst({
      where: { id: changes.studyProgramId!, isActive: true },
      select: { name: true, isPublished: true, _count: { select: { lessons: true } } },
    })
    if (!target) throw new EnrollmentEditError('Target study program not found', 404)
    if (!target.isPublished) throw new EnrollmentEditError('Cannot switch to a draft study program', 400)
    if (target._count.lessons === 0) {
      throw new EnrollmentEditError('Cannot switch to a study program with no lessons', 400)
    }

    const existing = await loadActiveSchedules(enrollmentId)
    let archived = 0
    for (const s of existing) {
      if (await scheduleHasProgress(s.id)) archived++
    }
    const removed = existing.length - archived
    studySwap = {
      fromName: enrollment.studyProgram.name,
      toName: target.name,
      lessonsRemoved: removed,
      lessonsArchived: archived,
      lessonsAdded: target._count.lessons,
    }
    destructive = true
    summary.push(
      `Switches the study from "${enrollment.studyProgram.name}" to "${target.name}". ` +
        `${removed} lesson${removed === 1 ? '' : 's'} with no activity will be removed` +
        (archived > 0
          ? `, ${archived} lesson${archived === 1 ? '' : 's'} with member progress will be archived`
          : '') +
        `, and ${target._count.lessons} new lesson${target._count.lessons === 1 ? '' : 's'} will be scheduled.`
    )
  }

  // ── Reschedule (only meaningful when NOT swapping study — a swap rebuilds) ──
  let reschedule: EnrollmentEditPreview['reschedule'] = null
  if (!swappingStudy && (changes.startDate || changes.enabledDays)) {
    const existing = await loadActiveSchedules(enrollmentId)
    const changed = computeRescheduledDates(existing, targetStartDate, targetEnabledDays, now)
    const lockedCount = existing.filter((s) => isLocked(s, now)).length
    if (changed.size > 0) {
      reschedule = { lessonsShifted: changed.size, lockedUnchanged: lockedCount }
      summary.push(
        `Reschedules ${changed.size} upcoming lesson${changed.size === 1 ? '' : 's'}` +
          (lockedCount > 0 ? ` (${lockedCount} already sent will not move).` : '.')
      )
    }
  }

  if (summary.length === 0) {
    summary.push('This will update the existing enrollment to match your changes.')
  }

  return { groupChange, reschedule, studySwap, destructive, summary }
}

export interface EnrollmentEditResult {
  rescheduled: number
  groupChanged: boolean
  studySwapped: boolean
}

/**
 * Commit a structural enrollment edit (group change and/or reschedule) in one
 * transaction. Study-program swaps are handled separately (see
 * applyStudySwap); this function throws if asked to swap.
 *
 * Scalar fields (smsTime/requireResponse/syncMode) are NOT handled here — the
 * PATCH route patches those alongside calling this.
 */
export async function applyEnrollmentEdit(
  enrollmentId: string,
  changes: EnrollmentEditChanges,
  userId: string
): Promise<EnrollmentEditResult> {
  const enrollment = await loadEnrollment(enrollmentId)
  const now = new Date()

  if (changes.studyProgramId && changes.studyProgramId !== enrollment.studyProgramId) {
    throw new EnrollmentEditError('Study-program swap is handled by applyStudySwap', 400)
  }

  const changingGroup = !!changes.groupId && changes.groupId !== enrollment.groupId
  const rescheduling = !!(changes.startDate || changes.enabledDays)

  // Validate the target group up-front (outside the tx) so a bad request never
  // opens a transaction.
  if (changingGroup) {
    const target = await prisma.group.findFirst({
      where: { id: changes.groupId!, isActive: true },
      select: { id: true },
    })
    if (!target) throw new EnrollmentEditError('Target group not found', 404)
  }

  const targetStartDate = changes.startDate ? new Date(changes.startDate) : enrollment.startDate
  const targetEnabledDays = changes.enabledDays ?? parseEnabledDays(enrollment.enabledDays)
  if (rescheduling && targetEnabledDays.length === 0) {
    throw new EnrollmentEditError('At least one day of the week must be enabled', 400)
  }

  const schedules = rescheduling ? await loadActiveSchedules(enrollmentId) : []
  const dateChanges = rescheduling
    ? computeRescheduledDates(schedules, targetStartDate, targetEnabledDays, now)
    : new Map<string, Date>()

  const result: EnrollmentEditResult = {
    rescheduled: dateChanges.size,
    groupChanged: changingGroup,
    studySwapped: false,
  }

  await prisma.$transaction(
    async (tx) => {
      // ── Group reassignment: re-home the enrollment + its events/welcome post
      if (changingGroup) {
        await tx.event.updateMany({
          where: { enrollmentId },
          data: { groupId: changes.groupId! },
        })
        await tx.post.updateMany({
          where: { enrollmentId },
          data: { groupId: changes.groupId! },
        })
      }

      // ── Reschedule: move each unlocked schedule + its calendar event
      for (const [scheduleId, newDate] of dateChanges) {
        await tx.lessonSchedule.update({
          where: { id: scheduleId },
          data: { scheduledDate: newDate },
        })
        await tx.event.updateMany({
          where: { lessonScheduleId: scheduleId },
          data: { date: newDate },
        })
      }

      // ── Enrollment scalar fields that structural edits imply
      const enrollmentData: Record<string, unknown> = { updatedById: userId }
      if (changingGroup) enrollmentData.groupId = changes.groupId
      if (rescheduling) {
        enrollmentData.startDate = targetStartDate
        enrollmentData.enabledDays = JSON.stringify(targetEnabledDays)
        // Recompute endDate from the resulting schedule set.
        const finalDates = schedules.map((s) => dateChanges.get(s.id) ?? s.scheduledDate)
        if (finalDates.length > 0) {
          enrollmentData.endDate = new Date(Math.max(...finalDates.map((d) => d.getTime())))
        }
      }
      await tx.enrollment.update({ where: { id: enrollmentId }, data: enrollmentData })
    },
    { timeout: 30_000 }
  )

  return result
}

/** Full curriculum include needed to copy a program's lessons into schedules. */
const PROGRAM_COPY_INCLUDE = {
  template: { select: { id: true, name: true } },
  lessons: {
    orderBy: { dayNumber: 'asc' as const },
    include: {
      activities: {
        orderBy: { orderNumber: 'asc' as const },
        include: {
          sourceReferences: true,
          readBlocks: {
            orderBy: { orderNumber: 'asc' as const },
            include: {
              theme: { select: { id: true, slug: true, name: true } },
              exegesisHighlights: { orderBy: { orderNumber: 'asc' as const } },
            },
          },
        },
      },
    },
  },
} as const

/**
 * Swap an enrollment's study program (monday#12270302158). Old schedules are
 * removed (hard-delete if no member progress, soft-remove `removedAt` if
 * progress — keeping history per the product decision), and fresh schedules
 * are built from the new program starting at the edited-or-original start date,
 * reusing the CREATE copy pipeline. A group change bundled into the same edit
 * is applied atomically here too. All in one transaction.
 */
export async function applyStudySwap(
  enrollmentId: string,
  changes: EnrollmentEditChanges,
  userId: string
): Promise<EnrollmentEditResult> {
  const enrollment = await loadEnrollment(enrollmentId)
  const now = new Date()

  if (!changes.studyProgramId || changes.studyProgramId === enrollment.studyProgramId) {
    throw new EnrollmentEditError('applyStudySwap requires a different studyProgramId', 400)
  }

  const target = await prisma.studyProgram.findFirst({
    where: { id: changes.studyProgramId, isActive: true },
    include: PROGRAM_COPY_INCLUDE,
  })
  if (!target) throw new EnrollmentEditError('Target study program not found', 404)
  if (!target.isPublished) throw new EnrollmentEditError('Cannot switch to a draft study program', 400)
  if (target.lessons.length === 0) {
    throw new EnrollmentEditError('Cannot switch to a study program with no lessons', 400)
  }

  const changingGroup = !!changes.groupId && changes.groupId !== enrollment.groupId
  const finalGroupId = changingGroup ? changes.groupId! : enrollment.groupId
  if (changingGroup) {
    const grp = await prisma.group.findFirst({
      where: { id: finalGroupId, isActive: true },
      select: { id: true },
    })
    if (!grp) throw new EnrollmentEditError('Target group not found', 404)
  }

  const targetStartDate = changes.startDate ? new Date(changes.startDate) : enrollment.startDate
  const targetEnabledDays = changes.enabledDays ?? parseEnabledDays(enrollment.enabledDays)
  if (targetEnabledDays.length === 0) {
    throw new EnrollmentEditError('At least one day of the week must be enabled', 400)
  }

  // Decide hard-delete vs soft-remove for every existing (non-removed) schedule
  // BEFORE opening the transaction (read-only progress checks).
  const existing = await loadActiveSchedules(enrollmentId)
  const removalPlan = await Promise.all(
    existing.map(async (s) => ({ id: s.id, keep: await scheduleHasProgress(s.id) }))
  )
  const toSoftRemove = removalPlan.filter((r) => r.keep).map((r) => r.id)
  const toHardDelete = removalPlan.filter((r) => !r.keep).map((r) => r.id)

  // Build the new schedule set (dates + unique codes) from the target program.
  const newDates = generateScheduleDates(targetStartDate, targetEnabledDays, target.lessons.length)
  const usedCodes = new Set<string>()
  const nextCode = (): string => {
    let code = generateStudyCode()
    while (usedCodes.has(code)) code = generateStudyCode()
    usedCodes.add(code)
    return code
  }
  const newSchedules = target.lessons.map((lesson, i) => ({
    id: randomUUID(),
    versionId: randomUUID(),
    code: nextCode(),
    lesson,
    scheduledDate: newDates[i],
  }))
  const endDate = newDates[newDates.length - 1]

  await prisma.$transaction(
    async (tx) => {
      // ── Remove old schedules ────────────────────────────────────────────
      if (toHardDelete.length > 0) {
        await tx.event.deleteMany({ where: { lessonScheduleId: { in: toHardDelete } } })
        await tx.lessonSchedule.deleteMany({ where: { id: { in: toHardDelete } } })
      }
      if (toSoftRemove.length > 0) {
        // Keep the row (history) but drop future calendar events.
        await tx.event.deleteMany({
          where: { lessonScheduleId: { in: toSoftRemove }, date: { gt: now } },
        })
        await tx.lessonSchedule.updateMany({
          where: { id: { in: toSoftRemove } },
          data: { removedAt: now },
        })
      }

      // ── Build new schedules from the target program ─────────────────────
      await tx.lessonSchedule.createMany({
        data: newSchedules.map((s) => ({
          id: s.id,
          code: s.code,
          enrollmentId,
          lessonId: s.lesson.id,
          scheduledDate: s.scheduledDate,
          templateId: target.template?.id ?? null,
          templateName: target.template?.name ?? null,
          title: s.lesson.title ?? null,
        })),
      })

      await tx.lessonScheduleVersion.createMany({
        data: newSchedules.map((s) => ({
          id: s.versionId,
          lessonScheduleId: s.id,
          versionNumber: 1,
          programVersionNumber: target.currentVersionNumber ?? null,
          sourceContentHash: hashLessonContent(s.lesson as any),
        })),
      })
      for (const s of newSchedules) {
        await tx.lessonSchedule.update({
          where: { id: s.id },
          data: { currentVersionId: s.versionId },
        })
      }

      const scheduledActivityData: LessonCopyRows['scheduledActivityData'] = []
      const sourceRefData: LessonCopyRows['sourceRefData'] = []
      const readBlockData: LessonCopyRows['readBlockData'] = []
      const exegesisHighlightData: LessonCopyRows['exegesisHighlightData'] = []
      for (const s of newSchedules) {
        const rows = buildLessonCopyRows({
          lessonScheduleId: s.id,
          versionId: s.versionId,
          activities: s.lesson.activities as any,
        })
        scheduledActivityData.push(...rows.scheduledActivityData)
        sourceRefData.push(...rows.sourceRefData)
        readBlockData.push(...rows.readBlockData)
        exegesisHighlightData.push(...rows.exegesisHighlightData)
      }
      if (scheduledActivityData.length > 0) await tx.scheduledLessonActivity.createMany({ data: scheduledActivityData })
      if (sourceRefData.length > 0) await tx.activitySourceReference.createMany({ data: sourceRefData })
      if (readBlockData.length > 0) await tx.activityReadBlock.createMany({ data: readBlockData })
      if (exegesisHighlightData.length > 0) await tx.exegesisHighlight.createMany({ data: exegesisHighlightData })

      // ── New calendar events for the new schedules ───────────────────────
      await tx.event.createMany({
        data: newSchedules.map((s) => ({
          groupId: finalGroupId,
          type: 'LESSON' as const,
          title: `Day ${s.lesson.dayNumber}: ${target.name}`,
          description: target.description,
          date: s.scheduledDate,
          startTime: enrollment.smsTime,
          lessonScheduleId: s.id,
          enrollmentId,
          dayNumber: s.lesson.dayNumber,
        })),
      })

      // ── Group re-home for any surviving (soft-removed) events + welcome post
      if (changingGroup) {
        await tx.event.updateMany({ where: { enrollmentId }, data: { groupId: finalGroupId } })
        await tx.post.updateMany({ where: { enrollmentId }, data: { groupId: finalGroupId } })
      }

      // ── Point the enrollment at the new program/schedule ────────────────
      await tx.enrollment.update({
        where: { id: enrollmentId },
        data: {
          studyProgramId: target.id,
          groupId: finalGroupId,
          startDate: targetStartDate,
          endDate,
          enabledDays: JSON.stringify(targetEnabledDays),
          // Fresh copy from the target's live curriculum ⇒ drift-free at its
          // current published version.
          syncedProgramVersionNumber: target.currentVersionNumber ?? null,
          updatedById: userId,
        },
      })
    },
    { timeout: 60_000 }
  )

  return { rescheduled: newSchedules.length, groupChanged: changingGroup, studySwapped: true }
}
