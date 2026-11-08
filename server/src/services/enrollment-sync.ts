/**
 * Enrollment sync (text-activity D5, D37, 05 s3 "Sync").
 *
 * Moves an enrollment onto a ProgramVersion by POINTER: each ScheduledLesson's `currentVersionId` becomes the
 * version the ProgramVersionLesson row names, and no content is copied. No sync run is written (D37).
 *
 *  - A scheduled lesson whose current version belongs to the enrollment (`enrollmentId` set: the group's own
 *    edit) is skipped and reported (D5).
 *  - A lesson the enrollment never had gets a ScheduledLesson: in a slot freed by a removal in the same sync,
 *    else on the next enabled day after every date the enrollment holds. A full sync re-lays every unlocked lesson
 *    over the slot pool in program order, as the old sync did.
 *  - A lesson absent from the target is deleted when no member started it, else soft-removed (`removedAt`).
 *  - Past-dated or already-sent lessons count as locked: their dates are never reused as free slots.
 */

import { prisma } from '../lib/prisma.js'
import type { Prisma } from '../generated/prisma/index.js'
import { generateStudyCode } from '../lib/study-code.js'
import { computePendingChanges } from './enrollment-sync-changes.js'
import {
  upsertNotificationByDedupeKey,
  resolveNotificationsByDedupeKey,
} from './notification.js'

type Tx = Prisma.TransactionClient

const DAY_NAME_TO_NUMBER: Record<string, number> = {
  Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6,
}

export interface ApplyProgramVersionResult {
  movedLessonIds: string[]
  addedLessonIds: string[]
  removedLessonIds: string[]
  skippedCustomizedLessonIds: string[]
  /** Existing scheduled lessons whose date moved when the unlocked lessons were re-laid in program order. */
  datesShifted: number
}

export interface ApplyProgramVersionOptions {
  /**
   * Selective approval (Review Changes): only these pending changes apply, keyed by lessonId (or `schedule:{id}`
   * for a scheduled lesson whose lesson is gone). The enrollment's `programVersionId` is then left for the caller
   * to move once nothing remains pending.
   */
  only?: ReadonlySet<string>
}

export class SyncNotPossibleError extends Error {}

/** Bring one enrollment onto `programVersionId`. Run inside the caller's transaction. */
export async function applyProgramVersion(
  tx: Tx,
  enrollmentId: string,
  programVersionId: string,
  options: ApplyProgramVersionOptions = {},
): Promise<ApplyProgramVersionResult> {
  const { only } = options
  const enrollment = await tx.enrollment.findUniqueOrThrow({
    where: { id: enrollmentId },
    select: { id: true, enabledDays: true, endDate: true, studyProgram: { select: { name: true } } },
  })
  const targetLessons = await tx.programVersionLesson.findMany({
    where: { programVersionId },
    orderBy: { position: 'asc' },
  })
  const targetByLessonId = new Map(targetLessons.map((l) => [l.lessonId, l]))
  const schedules = await tx.scheduledLesson.findMany({
    where: { enrollmentId },
    include: { currentVersion: { select: { enrollmentId: true } } },
    orderBy: { scheduledDate: 'asc' },
  })
  const selected = (lessonId: string | null, scheduleId: string) =>
    !only || only.has(lessonId ?? `schedule:${scheduleId}`)

  const now = new Date()
  const result: ApplyProgramVersionResult = {
    movedLessonIds: [], addedLessonIds: [], removedLessonIds: [], skippedCustomizedLessonIds: [], datesShifted: 0,
  }

  // Removals
  const freedSlotDates: Date[] = []
  const removedScheduleIds = new Set<string>()
  for (const schedule of schedules) {
    if (schedule.removedAt !== null) continue
    if (schedule.lessonId !== null && targetByLessonId.has(schedule.lessonId)) continue
    if (!selected(schedule.lessonId, schedule.id)) continue

    const locked = schedule.smsSentAt !== null || schedule.scheduledDate <= now
    if (!locked) freedSlotDates.push(schedule.scheduledDate)

    const hasProgress = (await tx.lessonProgress.count({ where: { scheduledLessonId: schedule.id } })) > 0
    if (hasProgress) {
      await tx.event.deleteMany({ where: { scheduledLessonId: schedule.id, date: { gt: now } } })
      await tx.scheduledLesson.update({ where: { id: schedule.id }, data: { removedAt: now } })
    } else {
      await tx.event.deleteMany({ where: { scheduledLessonId: schedule.id } })
      await tx.scheduledLesson.delete({ where: { id: schedule.id } })
    }
    removedScheduleIds.add(schedule.id)
    if (schedule.lessonId !== null) result.removedLessonIds.push(schedule.lessonId)
  }

  // Pointer moves, in program order
  const scheduleByLessonId = new Map(
    schedules.filter((s) => s.lessonId !== null).map((s) => [s.lessonId as string, s]),
  )
  const toAdd = new Set<string>()
  const revivedScheduleIds = new Set<string>()
  for (const target of targetLessons) {
    const schedule = scheduleByLessonId.get(target.lessonId)
    if (!schedule) {
      if (!only || only.has(target.lessonId)) toAdd.add(target.lessonId)
      continue
    }
    if (removedScheduleIds.has(schedule.id) || !selected(target.lessonId, schedule.id)) continue
    if (schedule.currentVersion.enrollmentId !== null) {
      result.skippedCustomizedLessonIds.push(target.lessonId)
      continue
    }
    // A lesson back in the program revives its soft-removed scheduled lesson.
    if (schedule.removedAt !== null) revivedScheduleIds.add(schedule.id)
    await tx.scheduledLesson.update({
      where: { id: schedule.id },
      data: { currentVersionId: target.lessonVersionId, removedAt: null },
    })
    result.movedLessonIds.push(target.lessonId)
  }

  // Dates. Without a selection every unlocked lesson is re-laid, in program order, over the slots the
  // unlocked schedules hold plus the slots freed by removals (overflow goes on the next enabled day after
  // every locked date). A selection never moves an existing schedule: additions take freed slots, then overflow.
  const isLocked = (s: { smsSentAt: Date | null; scheduledDate: Date }) => s.smsSentAt !== null || s.scheduledDate <= now
  const survivors = schedules.filter(
    (s) => !removedScheduleIds.has(s.id) && (s.removedAt === null || revivedScheduleIds.has(s.id)),
  )
  const survivorByLessonId = new Map(survivors.filter((s) => s.lessonId !== null).map((s) => [s.lessonId as string, s]))
  const immovable = only ? survivors : survivors.filter(isLocked)
  const lockedLessonIds = new Set(survivors.filter(isLocked).map((s) => s.lessonId))
  const relaid = only
    ? targetLessons.filter((t) => toAdd.has(t.lessonId))
    : targetLessons.filter((t) => !lockedLessonIds.has(t.lessonId))
  const slots = (only ? [...freedSlotDates] : [...survivors.filter((s) => !isLocked(s)).map((s) => s.scheduledDate), ...freedSlotDates])
    .sort((a, b) => a.getTime() - b.getTime())
  const enabledDays = parseEnabledDays(enrollment.enabledDays)
  let cursor = new Date(Math.max(
    now.getTime(), slots.at(-1)?.getTime() ?? 0, ...immovable.map((s) => s.scheduledDate.getTime()),
  ))
  const nextOverflowDate = (): Date => {
    cursor = new Date(cursor)
    do {
      cursor.setDate(cursor.getDate() + 1)
    } while (!enabledDays.includes(cursor.getDay()))
    return new Date(cursor)
  }

  const addedDates = new Map<string, Date>()
  let latest = 0
  for (const [i, lesson] of relaid.entries()) {
    const date = i < slots.length ? slots[i] : nextOverflowDate()
    latest = Math.max(latest, date.getTime())
    const existing = survivorByLessonId.get(lesson.lessonId)
    if (!existing) {
      addedDates.set(lesson.lessonId, date)
      continue
    }
    if (existing.scheduledDate.getTime() === date.getTime()) continue
    await tx.scheduledLesson.update({ where: { id: existing.id }, data: { scheduledDate: date } })
    await tx.event.updateMany({
      where: { scheduledLessonId: existing.id },
      data: { date, dayNumber: lesson.position, title: `Day ${lesson.position}: ${enrollment.studyProgram.name}` },
    })
    result.datesShifted++
  }
  if (addedDates.size > 0) {
    result.addedLessonIds.push(...(await createScheduledLessons(tx, enrollmentId, programVersionId, addedDates)))
  }
  if (latest > enrollment.endDate.getTime()) {
    await tx.enrollment.update({ where: { id: enrollmentId }, data: { endDate: new Date(latest) } })
  }

  if (!only) {
    await tx.enrollment.update({ where: { id: enrollmentId }, data: { programVersionId } })
  }
  return result
}

/**
 * One ScheduledLesson (and its calendar event) per `dates` entry, on the version `programVersionId` names for
 * that lesson. Used by the sync's additions and by enroll. Returns the lesson ids in program order.
 */
export async function createScheduledLessons(
  tx: Tx,
  enrollmentId: string,
  programVersionId: string,
  dates: ReadonlyMap<string, Date>,
): Promise<string[]> {
  if (dates.size === 0) return []
  const enrollment = await tx.enrollment.findUniqueOrThrow({
    where: { id: enrollmentId },
    select: {
      id: true, groupId: true, smsTime: true,
      studyProgram: { select: { name: true, description: true, templateId: true } },
    },
  })
  const lessons = await tx.programVersionLesson.findMany({
    where: { programVersionId, lessonId: { in: [...dates.keys()] } },
    orderBy: { position: 'asc' },
  })
  const missing = [...dates.keys()].filter((id) => !lessons.some((l) => l.lessonId === id))
  if (missing.length > 0) {
    throw new Error(`createScheduledLessons: lessons not in program version ${programVersionId}: ${missing.join(', ')}`)
  }
  for (const lesson of lessons) {
    const scheduledDate = dates.get(lesson.lessonId) as Date
    const scheduled = await tx.scheduledLesson.create({
      data: {
        code: generateStudyCode(),
        enrollmentId,
        lessonId: lesson.lessonId,
        scheduledDate,
        currentVersionId: lesson.lessonVersionId,
        templateId: enrollment.studyProgram.templateId,
      },
    })
    await tx.event.create({
      data: {
        groupId: enrollment.groupId,
        type: 'LESSON',
        title: `Day ${lesson.position}: ${enrollment.studyProgram.name}`,
        description: enrollment.studyProgram.description,
        date: scheduledDate,
        startTime: enrollment.smsTime,
        scheduledLessonId: scheduled.id,
        enrollmentId,
        dayNumber: lesson.position,
      },
    })
  }
  return lessons.map((l) => l.lessonId)
}

function parseEnabledDays(enabledDays: string): number[] {
  try {
    const parsed = JSON.parse(enabledDays) as string[]
    const numbers = parsed.map((d) => DAY_NAME_TO_NUMBER[d]).filter((n) => n !== undefined)
    if (numbers.length > 0) return numbers
  } catch {
    // fall through to every-day default
  }
  return [0, 1, 2, 3, 4, 5, 6]
}

export interface SyncOutcome {
  alreadySynced: boolean
  targetVersionNumber: number
  lessonsUpdated: number
  lessonsAdded: number
  lessonsRemoved: number
  datesShifted: number
  skippedCustomizedLessonIds: string[]
  /** False after a partial (selective) approval: the enrollment stays behind and the leader can approve more. */
  fullySynced: boolean
}

/**
 * Bring one enrollment to its program's current version, fully or restricted to the leader-approved `lessonKeys`,
 * in one transaction. Pushes go out after it commits (D32): a full sync clears the "updates available" notice, and
 * an AUTO enrollment's leader is told the update was applied.
 */
export async function syncEnrollmentToCurrent(params: {
  enrollmentId: string
  lessonKeys?: string[] | null
}): Promise<SyncOutcome> {
  const { enrollmentId, lessonKeys = null } = params
  const enrollment = await prisma.enrollment.findUniqueOrThrow({
    where: { id: enrollmentId },
    select: {
      createdById: true,
      syncMode: true,
      programVersionId: true,
      studyProgram: { select: { currentVersion: { select: { id: true, programId: true, number: true, changeSummary: true } } } },
    },
  })
  const target = enrollment.studyProgram.currentVersion
  if (!target) throw new SyncNotPossibleError('This study program has no published version to sync to.')

  const noOp: SyncOutcome = {
    alreadySynced: true, targetVersionNumber: target.number, lessonsUpdated: 0, lessonsAdded: 0,
    lessonsRemoved: 0, datesShifted: 0, skippedCustomizedLessonIds: [], fullySynced: true,
  }
  if (enrollment.programVersionId === target.id) return noOp
  if (lessonKeys && lessonKeys.length === 0) return { ...noOp, alreadySynced: false, fullySynced: false }

  const only = lessonKeys ? new Set(lessonKeys) : undefined
  const { result, fullySynced } = await prisma.$transaction(async (tx) => {
    const result = await applyProgramVersion(tx, enrollmentId, target.id, { only })
    const fullySynced = !only || !(await computePendingChanges(enrollmentId, tx)).hasPending
    if (only && fullySynced) {
      await tx.enrollment.update({ where: { id: enrollmentId }, data: { programVersionId: target.id } })
    }
    return { result, fullySynced }
  })

  if (fullySynced && enrollment.createdById) {
    await resolveNotificationsByDedupeKey(enrollment.createdById, `study-sync-updates:${enrollmentId}`)
      .catch(() => undefined)
  }
  if (fullySynced && enrollment.syncMode === 'AUTO') await sendSyncPushes([enrollmentId], target).catch((err) => console.error('Sync apply pushes failed:', err))
  return {
    alreadySynced: false,
    targetVersionNumber: target.number,
    lessonsUpdated: result.movedLessonIds.length,
    lessonsAdded: result.addedLessonIds.length,
    lessonsRemoved: result.removedLessonIds.length,
    datesShifted: result.datesShifted,
    skippedCustomizedLessonIds: result.skippedCustomizedLessonIds,
    fullySynced,
  }
}

/**
 * Tell each enrollment's leader what a published version did: AUTO enrollments were already moved (applied),
 * the rest have updates waiting. Called after the publish transaction commits; a failure for one enrollment
 * never stops the others.
 */
export async function sendSyncPushes(
  enrollmentIds: string[],
  programVersion: { id: string; programId: string; number: number; changeSummary?: string | null },
): Promise<void> {
  if (enrollmentIds.length === 0) return
  const [program, enrollments] = await Promise.all([
    prisma.studyProgram.findUniqueOrThrow({ where: { id: programVersion.programId }, select: { name: true } }),
    prisma.enrollment.findMany({
      where: { id: { in: enrollmentIds } },
      select: {
        id: true, syncMode: true, createdById: true,
        group: { select: { name: true } },
        programVersion: { select: { number: true } },
      },
    }),
  ])
  const versionNumber = programVersion.number
  const programId = programVersion.programId
  const summaryLine = programVersion.changeSummary ? ` ${programVersion.changeSummary}` : ''

  for (const enrollment of enrollments) {
    if (!enrollment.createdById) continue
    try {
      if (enrollment.syncMode === 'AUTO') {
        await upsertNotificationByDedupeKey({
          userId: enrollment.createdById,
          type: 'STUDY_SYNC_APPLIED',
          title: `${program.name} updated`,
          body: `Updates to "${program.name}" were applied to ${enrollment.group.name}'s enrollment (now version ${versionNumber}).${summaryLine}`,
          dedupeKey: `study-sync-applied:${enrollment.id}`,
          data: { enrollmentId: enrollment.id, programId, toVersion: String(versionNumber) },
          actions: [
            { label: 'View enrollment', view: 'enrollment-sync', params: { enrollmentId: enrollment.id } },
          ],
        })
      } else {
        // APPROVAL and OFF: the leader decides. OFF leaders are told too, so an accidental toggle-off is recoverable.
        await upsertNotificationByDedupeKey({
          userId: enrollment.createdById,
          type: 'STUDY_SYNC_UPDATES_AVAILABLE',
          title: `Updates available for ${program.name}`,
          body: `"${program.name}" has published updates (version ${versionNumber}) that ${enrollment.group.name}'s enrollment hasn't received.${summaryLine}`,
          dedupeKey: `study-sync-updates:${enrollment.id}`,
          data: {
            enrollmentId: enrollment.id,
            programId,
            fromVersion: String(enrollment.programVersion?.number ?? 0),
            toVersion: String(versionNumber),
            syncMode: enrollment.syncMode,
            // Not view-dismissable: stays unread until the leader applies the updates or changes the sync mode.
            requiresAction: true,
          },
          actions: [
            {
              label: enrollment.syncMode === 'APPROVAL' ? 'Review updates' : 'Update sync settings',
              view: 'enrollment-sync',
              params: { enrollmentId: enrollment.id },
            },
          ],
        })
      }
    } catch (error) {
      console.error(`Sync push failed for enrollment ${enrollment.id}:`, error)
    }
  }
}
