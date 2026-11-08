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
 *    history) and schedules the new program's current version — mirrors enrollment-sync.
 */

import { prisma } from '../lib/prisma.js'
import { generateScheduleDates, type EnabledDayName } from './enrollment-schedule.js'
import { createScheduledLessons } from './enrollment-sync.js'

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

/** Non-removed schedules for the enrollment, ordered by their lesson's position. */
async function loadActiveSchedules(enrollmentId: string): Promise<ScheduleRow[]> {
  const schedules = await prisma.scheduledLesson.findMany({
    where: { enrollmentId, removedAt: null },
    select: {
      id: true,
      lessonId: true,
      scheduledDate: true,
      smsSentAt: true,
      removedAt: true,
      lesson: { select: { position: true } },
    },
    orderBy: { scheduledDate: 'asc' },
  })
  // Order by curriculum position when available (falls back to date order).
  return schedules
    .slice()
    .sort((a, b) => (a.lesson?.position ?? 0) - (b.lesson?.position ?? 0))
    .map(({ id, lessonId, scheduledDate, smsSentAt, removedAt }) => ({
      id,
      lessonId,
      scheduledDate,
      smsSentAt,
      removedAt,
    }))
}

/**
 * The program an enrollment may switch to: active, with a published current version holding lessons. Returns its
 * name and that version's lessons in program order (the schedule the swap creates).
 */
async function loadSwapTarget(studyProgramId: string) {
  const target = await prisma.studyProgram.findFirst({
    where: { id: studyProgramId, isActive: true },
    select: { id: true, name: true, currentVersionId: true },
  })
  if (!target) throw new EnrollmentEditError('Target study program not found', 404)
  if (!target.currentVersionId) {
    throw new EnrollmentEditError('Cannot switch to a draft study program', 400)
  }
  const programVersionId = target.currentVersionId
  const lessons = await prisma.programVersionLesson.findMany({
    where: { programVersionId },
    orderBy: { position: 'asc' },
    select: { lessonId: true },
  })
  if (lessons.length === 0) throw new EnrollmentEditError('Cannot switch to a study program with no lessons', 400)
  return { id: target.id, name: target.name, programVersionId, lessonIds: lessons.map((l) => l.lessonId), lessonCount: lessons.length }
}

/** True if any member has recorded progress against this schedule. */
async function scheduleHasProgress(scheduleId: string): Promise<boolean> {
  const [activity, lesson] = await Promise.all([
    prisma.activityProgress.count({ where: { scheduledLessonId: scheduleId } }),
    prisma.lessonProgress.count({ where: { scheduledLessonId: scheduleId } }),
  ])
  return activity + lesson > 0
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
    const target = await loadSwapTarget(changes.studyProgramId!)

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
      lessonsAdded: target.lessonCount,
    }
    destructive = true
    summary.push(
      `Switches the study from "${enrollment.studyProgram.name}" to "${target.name}". ` +
        `${removed} lesson${removed === 1 ? '' : 's'} with no activity will be removed` +
        (archived > 0
          ? `, ${archived} lesson${archived === 1 ? '' : 's'} with member progress will be archived`
          : '') +
        `, and ${target.lessonCount} new lesson${target.lessonCount === 1 ? '' : 's'} will be scheduled.`
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
    } else if (existing.length > 0 && lockedCount === existing.length) {
      // Every lesson is locked (sent or past) — the requested dates cannot
      // take effect, so say so instead of letting the confirm imply they will
      // (monday#12661792842).
      reschedule = { lessonsShifted: 0, lockedUnchanged: lockedCount }
      summary.push(
        `All ${lockedCount} lesson${lockedCount === 1 ? ' has' : 's have'} already been sent or completed — the schedule and dates will not change.`
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
        await tx.scheduledLesson.update({
          where: { id: scheduleId },
          data: { scheduledDate: newDate },
        })
        await tx.event.updateMany({
          where: { scheduledLessonId: scheduleId },
          data: { date: newDate },
        })
      }

      // ── Enrollment scalar fields that structural edits imply
      const enrollmentData: Record<string, unknown> = { updatedById: userId }
      if (changingGroup) enrollmentData.groupId = changes.groupId
      if (rescheduling) {
        enrollmentData.enabledDays = JSON.stringify(targetEnabledDays)
        // Derive BOTH dates from the resulting schedule set, not the request:
        // locked lessons never move, so the requested startDate may not be
        // where lessons actually begin. Writing it blindly persisted
        // startDate > endDate on a fully-locked enrollment (monday#12661792842).
        const finalDates = schedules.map((s) => dateChanges.get(s.id) ?? s.scheduledDate)
        if (finalDates.length > 0) {
          const times = finalDates.map((d) => d.getTime())
          enrollmentData.startDate = new Date(Math.min(...times))
          enrollmentData.endDate = new Date(Math.max(...times))
        } else {
          enrollmentData.startDate = targetStartDate
        }
      }
      await tx.enrollment.update({ where: { id: enrollmentId }, data: enrollmentData })
    },
    { timeout: 30_000 }
  )

  return result
}

/**
 * Swap an enrollment's study program (monday#12270302158). Old schedules are
 * removed (hard-delete if no member progress, soft-remove `removedAt` if
 * progress — keeping history per the product decision), and fresh scheduled
 * lessons are made from the new program's current version starting at the
 * edited-or-original start date, as enroll does. A group change bundled into
 * the same edit is applied atomically here too. All in one transaction.
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

  const target = await loadSwapTarget(changes.studyProgramId)

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

  // The new schedule: one date per lesson of the target's current version.
  const newDates = generateScheduleDates(targetStartDate, targetEnabledDays, target.lessonCount)
  const endDate = newDates[newDates.length - 1]
  const newScheduleDates = new Map(target.lessonIds.map((lessonId, i) => [lessonId, newDates[i]]))

  await prisma.$transaction(
    async (tx) => {
      // ── Remove old schedules ────────────────────────────────────────────
      if (toHardDelete.length > 0) {
        await tx.event.deleteMany({ where: { scheduledLessonId: { in: toHardDelete } } })
        await tx.scheduledLesson.deleteMany({ where: { id: { in: toHardDelete } } })
      }
      if (toSoftRemove.length > 0) {
        // Keep the row (history) but drop future calendar events.
        await tx.event.deleteMany({
          where: { scheduledLessonId: { in: toSoftRemove }, date: { gt: now } },
        })
        await tx.scheduledLesson.updateMany({
          where: { id: { in: toSoftRemove } },
          data: { removedAt: now },
        })
      }

      // ── Point the enrollment at the new program first: the new scheduled lessons' events take the
      //    program name, group and invite time from it.
      await tx.enrollment.update({
        where: { id: enrollmentId },
        data: {
          studyProgramId: target.id,
          groupId: finalGroupId,
          startDate: targetStartDate,
          endDate,
          enabledDays: JSON.stringify(targetEnabledDays),
          // Scheduled from the target's current version ⇒ drift-free at it.
          programVersionId: target.programVersionId,
          updatedById: userId,
        },
      })

      // ── Scheduled lessons (and their calendar events) from the target's current version ──
      await createScheduledLessons(tx, enrollmentId, target.programVersionId, newScheduleDates)

      // ── Group re-home for any surviving (soft-removed) events + welcome post
      if (changingGroup) {
        await tx.event.updateMany({ where: { enrollmentId }, data: { groupId: finalGroupId } })
        await tx.post.updateMany({ where: { enrollmentId }, data: { groupId: finalGroupId } })
      }
    },
    { timeout: 60_000 }
  )

  return { rescheduled: target.lessonCount, groupChanged: changingGroup, studySwapped: true }
}
