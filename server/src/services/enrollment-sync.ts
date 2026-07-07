/**
 * Enrollment Sync Engine (study-sync phase 3)
 *
 * Applies a published StudyProgramVersion to an enrollment: "bring enrollment
 * E to program version N". Content comes from the version SNAPSHOT, never from
 * live curriculum — unpublished edits must not reach members.
 *
 * Invariants:
 *  - Sync NEVER mutates or deletes activity rows of existing versions. A
 *    changed lesson gets a new LessonScheduleVersion; old versions stay for
 *    pinned members (member progress cascades from activity deletes, so
 *    deletion is forbidden here by design).
 *  - Members who completed a lesson are pinned to the version they completed
 *    (belt-and-suspenders: completion-time pinning also happens at write time,
 *    but any unpinned completed member is pinned before the switch).
 *  - Scheduling: past-dated or already-sent lessons never move ("locked").
 *    Remaining curriculum lessons are laid over the surviving future dates in
 *    curriculum order; overflow walks forward through the enrollment's
 *    enabled days. Removed lessons free their future slots.
 *  - Removed lessons are hard-deleted when no member ever touched them,
 *    soft-hidden (removedAt) when progress exists.
 *  - Idempotent + resumable: per-lesson changes are hash-guarded and applied
 *    in their own transactions; EnrollmentSyncRun records the attempt. A
 *    failed run can be retried and picks up where it left off.
 */

import { randomUUID } from 'crypto'
import { prisma } from '../lib/prisma.js'
import { generateStudyCode } from '../lib/study-code.js'
import { buildLessonRowsFromSnapshot, type LiveActivityDerivedFields } from './lesson-copy.js'
import { recalculateScheduledLessonEstimate } from './lesson-estimate.service.js'
import type { SnapshotLesson } from './study-program-publish.js'
import {
  upsertNotificationByDedupeKey,
  resolveNotificationsByDedupeKey,
} from './notification.js'

const DAY_NAME_TO_NUMBER: Record<string, number> = {
  Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6,
}

export interface SyncOutcome {
  alreadySynced: boolean
  targetVersionNumber: number
  lessonsUpdated: number
  lessonsAdded: number
  lessonsRemoved: number
  datesShifted: number
  /** True when the enrollment fully matches the target version after this
   *  run. False after a partial (selective) approval — the enrollment stays
   *  drifted and the leader can approve more later. */
  fullySynced: boolean
}

export class SyncNotPossibleError extends Error {}

/**
 * Bring one enrollment to the latest published version of its program —
 * fully, or restricted to the leader-approved lessons.
 *
 * @param lessonKeys selective approval (Review Changes screen): only these
 *   pending changes apply (curriculum lessonId, or `schedule:{id}` for
 *   orphans). The enrollment's syncedProgramVersionNumber bumps ONLY when
 *   nothing pending remains afterwards, so partial approvals keep the
 *   enrollment drifted (and its action-required notification alive).
 *
 * Safe to call repeatedly; concurrent calls are serialized by the
 * (enrollmentId, targetProgramVersionNumber) unique on EnrollmentSyncRun.
 */
export async function syncEnrollmentToLatest(params: {
  enrollmentId: string
  triggeredById?: string | null
  lessonKeys?: string[] | null
}): Promise<SyncOutcome> {
  const { enrollmentId, triggeredById = null, lessonKeys = null } = params
  const selection = lessonKeys ? new Set(lessonKeys) : null

  const enrollment = await loadEnrollment(enrollmentId)

  const targetVersionNumber = enrollment.studyProgram.currentVersionNumber
  if (targetVersionNumber == null) {
    throw new SyncNotPossibleError('This study program has no published version to sync to.')
  }

  const noOp: SyncOutcome = {
    alreadySynced: true,
    targetVersionNumber,
    lessonsUpdated: 0,
    lessonsAdded: 0,
    lessonsRemoved: 0,
    datesShifted: 0,
    fullySynced: true,
  }

  if (enrollment.syncedProgramVersionNumber === targetVersionNumber) return noOp
  if (selection && selection.size === 0) {
    return { ...noOp, alreadySynced: false, fullySynced: false }
  }

  const run = await prisma.enrollmentSyncRun.upsert({
    where: {
      enrollmentId_targetProgramVersionNumber: {
        enrollmentId,
        targetProgramVersionNumber: targetVersionNumber,
      },
    },
    create: {
      enrollmentId,
      targetProgramVersionNumber: targetVersionNumber,
      status: 'RUNNING',
      startedAt: new Date(),
      triggeredById,
    },
    update: {
      status: 'RUNNING',
      startedAt: new Date(),
      error: null,
      triggeredById,
    },
  })

  try {
    const outcome = await applyVersion(enrollment, targetVersionNumber, selection)

    // Selective approvals only "complete" the sync when nothing pending
    // remains — otherwise the enrollment stays drifted for a later visit.
    const fullySynced = selection === null || !(await hasPendingLessons(enrollmentId, targetVersionNumber))

    await prisma.$transaction([
      prisma.enrollmentSyncRun.update({
        where: { id: run.id },
        data: { status: 'COMPLETED', completedAt: new Date() },
      }),
      ...(fullySynced
        ? [
            prisma.enrollment.update({
              where: { id: enrollmentId },
              data: { syncedProgramVersionNumber: targetVersionNumber },
            }),
          ]
        : []),
    ])

    // The pending-updates notification resolves only when everything is dealt
    // with (action-required contract).
    if (fullySynced && enrollment.createdById) {
      await resolveNotificationsByDedupeKey(
        enrollment.createdById,
        `study-sync-updates:${enrollmentId}`
      ).catch(() => undefined)
    }

    return { ...outcome, fullySynced }
  } catch (error) {
    await prisma.enrollmentSyncRun
      .update({
        where: { id: run.id },
        data: {
          status: 'FAILED',
          completedAt: new Date(),
          error: error instanceof Error ? error.message : String(error),
        },
      })
      .catch(() => undefined) // never mask the original failure
    throw error
  }
}

/** Cheap post-apply check: does anything still differ from the target
 *  version? (Hash mismatches, missing lessons, or stale schedules.) */
async function hasPendingLessons(
  enrollmentId: string,
  targetVersionNumber: number
): Promise<boolean> {
  const enrollment = await prisma.enrollment.findUniqueOrThrow({
    where: { id: enrollmentId },
    select: { studyProgramId: true },
  })
  const version = await prisma.studyProgramVersion.findUniqueOrThrow({
    where: {
      studyProgramId_versionNumber: {
        studyProgramId: enrollment.studyProgramId,
        versionNumber: targetVersionNumber,
      },
    },
    select: { lessonHashes: true },
  })
  const hashes = (version.lessonHashes ?? {}) as Record<string, string>

  const schedules = await prisma.lessonSchedule.findMany({
    where: { enrollmentId, removedAt: null },
    select: {
      lessonId: true,
      currentVersion: { select: { sourceContentHash: true } },
    },
  })
  const byLessonId = new Map(schedules.map((s) => [s.lessonId, s]))

  for (const [lessonId, hash] of Object.entries(hashes)) {
    const schedule = byLessonId.get(lessonId)
    if (!schedule || schedule.currentVersion?.sourceContentHash !== hash) return true
  }
  return schedules.some((s) => s.lessonId === null || hashes[s.lessonId] === undefined)
}

type LoadedEnrollment = Awaited<ReturnType<typeof loadEnrollment>>
async function loadEnrollment(enrollmentId: string) {
  return prisma.enrollment.findUniqueOrThrow({
    where: { id: enrollmentId },
    include: {
      studyProgram: {
        select: {
          id: true,
          name: true,
          description: true,
          currentVersionNumber: true,
          template: { select: { id: true, name: true } },
        },
      },
    },
  })
}

async function applyVersion(
  enrollment: LoadedEnrollment,
  targetVersionNumber: number,
  selection: Set<string> | null = null
): Promise<SyncOutcome> {
  const programVersion = await prisma.studyProgramVersion.findUniqueOrThrow({
    where: {
      studyProgramId_versionNumber: {
        studyProgramId: enrollment.studyProgramId,
        versionNumber: targetVersionNumber,
      },
    },
  })

  const snapshotLessons = (((programVersion.snapshot as any)?.lessons ?? []) as SnapshotLesson[])
    .slice()
    .sort((a, b) => a.dayNumber - b.dayNumber)
  const snapshotByLessonId = new Map(snapshotLessons.map((l) => [l.id, l]))

  const schedules = await prisma.lessonSchedule.findMany({
    where: { enrollmentId: enrollment.id },
    include: { currentVersion: { select: { id: true, sourceContentHash: true } } },
  })
  const scheduleByLessonId = new Map(schedules.map((s) => [s.lessonId, s]))

  // Derived-field sources: live curriculum activities for all snapshot lessons
  const liveActivities = await prisma.lessonActivity.findMany({
    where: { lessonId: { in: snapshotLessons.map((l) => l.id) } },
    select: {
      id: true,
      videoId: true,
      videoUrl: true,
      youtubeUrl: true,
      youtubeVideoId: true,
      youtubeThumbnailUrl: true,
      estimatedSeconds: true,
    },
  })
  const liveById = new Map<string, LiveActivityDerivedFields>(
    liveActivities.map((a) => [a.id, a])
  )
  const existingSourceActivityIds = new Set(liveActivities.map((a) => a.id))

  const now = new Date()
  const isLocked = (s: { scheduledDate: Date; smsSentAt: Date | null }) =>
    s.smsSentAt !== null || s.scheduledDate <= now

  // ── Removals ──────────────────────────────────────────────────────────────
  let lessonsRemoved = 0
  const freedSlotDates: Date[] = []
  for (const schedule of schedules) {
    // A null lessonId means the curriculum lesson was deleted outright — the
    // schedule is orphaned and follows the same removal rules as a lesson
    // missing from the published snapshot
    if (schedule.lessonId !== null && snapshotByLessonId.has(schedule.lessonId)) continue
    if (schedule.removedAt !== null) continue // removed by an earlier sync
    // Selective approval: unapproved removals stay untouched (and keep their slot)
    if (selection && !selection.has(schedule.lessonId ?? `schedule:${schedule.id}`)) continue

    if (!isLocked(schedule)) freedSlotDates.push(schedule.scheduledDate)

    const [activityCount, videoCount, lessonCount] = await Promise.all([
      prisma.memberActivityProgress.count({ where: { lessonScheduleId: schedule.id } }),
      prisma.memberVideoProgress.count({ where: { lessonScheduleId: schedule.id } }),
      prisma.memberLessonProgress.count({ where: { lessonScheduleId: schedule.id } }),
    ])
    const hasProgress = activityCount + videoCount + lessonCount > 0

    if (hasProgress) {
      await prisma.$transaction([
        prisma.lessonSchedule.update({
          where: { id: schedule.id },
          data: { removedAt: now },
        }),
        // The lesson is no longer happening — drop its future calendar event
        prisma.event.deleteMany({
          where: { lessonScheduleId: schedule.id, date: { gt: now } },
        }),
      ])
    } else {
      await prisma.$transaction([
        prisma.event.deleteMany({ where: { lessonScheduleId: schedule.id } }),
        prisma.lessonSchedule.delete({ where: { id: schedule.id } }),
      ])
    }
    scheduleByLessonId.delete(schedule.lessonId)
    lessonsRemoved++
  }

  // ── Content updates for existing schedules ────────────────────────────────
  let lessonsUpdated = 0
  for (const lesson of snapshotLessons) {
    const schedule = scheduleByLessonId.get(lesson.id)
    if (!schedule) continue
    // Selective approval: unapproved content updates stay on their version
    if (selection && !selection.has(lesson.id)) continue

    const upToDate =
      schedule.currentVersion?.sourceContentHash === lesson.contentHash &&
      schedule.removedAt === null
    if (upToDate) continue

    const latestVersion = await prisma.lessonScheduleVersion.findFirst({
      where: { lessonScheduleId: schedule.id },
      orderBy: { versionNumber: 'desc' },
      select: { versionNumber: true },
    })

    const versionId = randomUUID()
    const rows = buildLessonRowsFromSnapshot({
      lessonScheduleId: schedule.id,
      versionId,
      content: lesson.content as any,
      activityIds: lesson.activityIds,
      existingSourceActivityIds,
      liveActivities: liveById,
    })

    await prisma.$transaction(async (tx) => {
      // Pin completed members to the version they actually finished
      if (schedule.currentVersionId) {
        await tx.memberLessonProgress.updateMany({
          where: {
            lessonScheduleId: schedule.id,
            completedAt: { not: null },
            pinnedVersionId: null,
          },
          data: { pinnedVersionId: schedule.currentVersionId },
        })
      }

      await tx.lessonScheduleVersion.create({
        data: {
          id: versionId,
          lessonScheduleId: schedule.id,
          versionNumber: (latestVersion?.versionNumber ?? 0) + 1,
          programVersionNumber: targetVersionNumber,
          sourceContentHash: lesson.contentHash,
        },
      })

      if (rows.scheduledActivityData.length > 0) {
        await tx.scheduledLessonActivity.createMany({ data: rows.scheduledActivityData })
      }
      if (rows.sourceRefData.length > 0) {
        await tx.activitySourceReference.createMany({ data: rows.sourceRefData })
      }
      if (rows.readBlockData.length > 0) {
        await tx.activityReadBlock.createMany({ data: rows.readBlockData })
      }
      if (rows.exegesisHighlightData.length > 0) {
        await tx.exegesisHighlight.createMany({ data: rows.exegesisHighlightData })
      }

      await tx.lessonSchedule.update({
        where: { id: schedule.id },
        data: {
          currentVersionId: versionId,
          title: lesson.title,
          removedAt: null, // lesson re-added to the curriculum revives its schedule
        },
      })
    })

    await recalculateScheduledLessonEstimate(schedule.id)
    lessonsUpdated++
  }

  // ── Scheduling: lay remaining lessons over the surviving future slots ────
  const survivors = await prisma.lessonSchedule.findMany({
    where: { enrollmentId: enrollment.id, removedAt: null },
    select: { id: true, lessonId: true, scheduledDate: true, smsSentAt: true },
  })
  const survivorByLessonId = new Map(survivors.map((s) => [s.lessonId, s]))

  const lockedLessonIds = new Set(survivors.filter(isLocked).map((s) => s.lessonId))

  // Selective approval: existing schedules NEVER move (a partial approval
  // must not reshuffle lessons the leader didn't approve) — every surviving
  // schedule is treated as locked, only approved additions are placed, and
  // the slot pool is just the dates freed by approved removals. Curriculum
  // reorders take effect when the enrollment fully catches up.
  const remainingLessons = selection
    ? snapshotLessons.filter((l) => !survivorByLessonId.has(l.id) && selection.has(l.id))
    : snapshotLessons.filter((l) => !lockedLessonIds.has(l.id))

  // Slot pool: dates already held by future unsent schedules + slots freed by
  // removed lessons, in date order
  const slotDates = (
    selection
      ? [...freedSlotDates]
      : [...survivors.filter((s) => !isLocked(s)).map((s) => s.scheduledDate), ...freedSlotDates]
  ).sort((a, b) => a.getTime() - b.getTime())

  const enabledDayNumbers = parseEnabledDays(enrollment.enabledDays)
  // Overflow starts after every immovable date — in selective mode ALL
  // surviving schedules hold their dates, so additions append after them.
  const immovable = selection ? survivors : survivors.filter(isLocked)
  const lastLockedTime = Math.max(
    now.getTime(),
    ...immovable.map((s) => s.scheduledDate.getTime())
  )

  let cursor = new Date(Math.max(lastLockedTime, slotDates.at(-1)?.getTime() ?? 0))
  const nextOverflowDate = (): Date => {
    cursor = new Date(cursor)
    do {
      cursor.setDate(cursor.getDate() + 1)
    } while (!enabledDayNumbers.includes(cursor.getDay()))
    return new Date(cursor)
  }

  let datesShifted = 0
  let lessonsAdded = 0
  let latestDate: Date | null = null

  for (let index = 0; index < remainingLessons.length; index++) {
    const lesson = remainingLessons[index]
    const assignedDate = index < slotDates.length ? slotDates[index] : nextOverflowDate()
    if (latestDate === null || assignedDate > latestDate) latestDate = assignedDate

    const existing = survivorByLessonId.get(lesson.id)
    if (existing) {
      if (existing.scheduledDate.getTime() !== assignedDate.getTime()) {
        await prisma.$transaction([
          prisma.lessonSchedule.update({
            where: { id: existing.id },
            data: { scheduledDate: assignedDate },
          }),
          prisma.event.updateMany({
            where: { lessonScheduleId: existing.id },
            data: {
              date: assignedDate,
              dayNumber: lesson.dayNumber,
              title: `Day ${lesson.dayNumber}: ${enrollment.studyProgram.name}`,
            },
          }),
        ])
        datesShifted++
      }
      continue
    }

    // New lesson: schedule + v1 version + activities + calendar event
    const scheduleId = randomUUID()
    const versionId = randomUUID()
    const rows = buildLessonRowsFromSnapshot({
      lessonScheduleId: scheduleId,
      versionId,
      content: lesson.content as any,
      activityIds: lesson.activityIds,
      existingSourceActivityIds,
      liveActivities: liveById,
    })

    await prisma.$transaction(async (tx) => {
      await tx.lessonSchedule.create({
        data: {
          id: scheduleId,
          code: generateStudyCode(),
          enrollmentId: enrollment.id,
          lessonId: lesson.id,
          scheduledDate: assignedDate,
          templateId: enrollment.studyProgram.template?.id ?? null,
          templateName: enrollment.studyProgram.template?.name ?? null,
          title: lesson.title,
        },
      })
      await tx.lessonScheduleVersion.create({
        data: {
          id: versionId,
          lessonScheduleId: scheduleId,
          versionNumber: 1,
          programVersionNumber: targetVersionNumber,
          sourceContentHash: lesson.contentHash,
        },
      })
      await tx.lessonSchedule.update({
        where: { id: scheduleId },
        data: { currentVersionId: versionId },
      })
      if (rows.scheduledActivityData.length > 0) {
        await tx.scheduledLessonActivity.createMany({ data: rows.scheduledActivityData })
      }
      if (rows.sourceRefData.length > 0) {
        await tx.activitySourceReference.createMany({ data: rows.sourceRefData })
      }
      if (rows.readBlockData.length > 0) {
        await tx.activityReadBlock.createMany({ data: rows.readBlockData })
      }
      if (rows.exegesisHighlightData.length > 0) {
        await tx.exegesisHighlight.createMany({ data: rows.exegesisHighlightData })
      }
      await tx.event.create({
        data: {
          groupId: enrollment.groupId,
          type: 'LESSON',
          title: `Day ${lesson.dayNumber}: ${enrollment.studyProgram.name}`,
          description: enrollment.studyProgram.description,
          date: assignedDate,
          startTime: enrollment.smsTime,
          lessonScheduleId: scheduleId,
          enrollmentId: enrollment.id,
          dayNumber: lesson.dayNumber,
        },
      })
    })

    await recalculateScheduledLessonEstimate(scheduleId)
    lessonsAdded++
  }

  if (latestDate !== null && latestDate > enrollment.endDate) {
    await prisma.enrollment.update({
      where: { id: enrollment.id },
      data: { endDate: latestDate },
    })
  }

  return {
    alreadySynced: false,
    targetVersionNumber,
    lessonsUpdated,
    lessonsAdded,
    lessonsRemoved,
    datesShifted,
    // Provisional; the caller overwrites after the post-apply pending check.
    fullySynced: selection === null,
  }
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

// In-flight background fan-outs. Production never waits on these; tests must
// drain them before tearing data down (a fan-out outliving its test file
// races the next file's writes — the suite shares one database).
const inFlightFanOuts = new Set<Promise<unknown>>()

/** Fire a fan-out in the background (used by the publish flow). */
export function launchProgramVersionFanOut(programId: string, versionNumber: number): void {
  const promise = fanOutProgramVersionSync(programId, versionNumber)
    .catch((error) => {
      console.error(`Study-sync fan-out crashed for program ${programId}:`, error)
    })
    .finally(() => {
      inFlightFanOuts.delete(promise)
    })
  inFlightFanOuts.add(promise)
}

/** Wait for all background fan-outs to settle (test teardown helper). */
export async function drainStudySyncFanOuts(): Promise<void> {
  while (inFlightFanOuts.size > 0) {
    await Promise.allSettled([...inFlightFanOuts])
  }
}

/**
 * Fan a freshly published version out to every AUTO-sync enrollment of the
 * program. Runs enrollments sequentially (steady DB load; a publish with
 * thousands of enrollments trickles rather than spikes) and isolates failures
 * per enrollment — the EnrollmentSyncRun rows record what needs retrying.
 */
export async function fanOutProgramVersionSync(
  programId: string,
  versionNumber: number
): Promise<{ synced: number; skipped: number; failed: number }> {
  const [program, version] = await Promise.all([
    prisma.studyProgram.findUniqueOrThrow({
      where: { id: programId },
      select: { name: true },
    }),
    prisma.studyProgramVersion.findUnique({
      where: { studyProgramId_versionNumber: { studyProgramId: programId, versionNumber } },
      select: { changeSummary: true },
    }),
  ])

  const enrollments = await prisma.enrollment.findMany({
    where: {
      studyProgramId: programId,
      OR: [
        { syncedProgramVersionNumber: null },
        { syncedProgramVersionNumber: { lt: versionNumber } },
      ],
    },
    select: {
      id: true,
      syncMode: true,
      createdById: true,
      syncedProgramVersionNumber: true,
      group: { select: { name: true } },
    },
  })

  const summaryLine = version?.changeSummary ? ` ${version.changeSummary}` : ''

  let synced = 0
  let skipped = 0
  let failed = 0
  for (const enrollment of enrollments) {
    try {
      if (enrollment.syncMode === 'AUTO') {
        const outcome = await syncEnrollmentToLatest({ enrollmentId: enrollment.id })
        if (outcome.alreadySynced) {
          skipped++
        } else {
          synced++
          if (enrollment.createdById) {
            await upsertNotificationByDedupeKey({
              userId: enrollment.createdById,
              type: 'STUDY_SYNC_APPLIED',
              title: `${program.name} updated`,
              body: `Updates to "${program.name}" were applied to ${enrollment.group.name}'s enrollment (now version ${versionNumber}).${summaryLine}`,
              dedupeKey: `study-sync-applied:${enrollment.id}`,
              data: {
                enrollmentId: enrollment.id,
                programId,
                toVersion: String(versionNumber),
              },
              actions: [
                {
                  label: 'View enrollment',
                  view: 'enrollment-sync',
                  params: { enrollmentId: enrollment.id },
                },
              ],
            })
          }
        }
      } else if (enrollment.createdById) {
        // APPROVAL and OFF: the leader decides — tell them what's waiting.
        // (OFF leaders are notified too so an accidental toggle-off is
        // recoverable; the notification carries the sync-settings action.)
        await upsertNotificationByDedupeKey({
          userId: enrollment.createdById,
          type: 'STUDY_SYNC_UPDATES_AVAILABLE',
          title: `Updates available for ${program.name}`,
          body: `"${program.name}" has published updates (version ${versionNumber}) that ${enrollment.group.name}'s enrollment hasn't received.${summaryLine}`,
          dedupeKey: `study-sync-updates:${enrollment.id}`,
          data: {
            enrollmentId: enrollment.id,
            programId,
            fromVersion: String(enrollment.syncedProgramVersionNumber ?? 0),
            toVersion: String(versionNumber),
            syncMode: enrollment.syncMode,
            // Not view-dismissable: stays unread until the leader applies the
            // updates or changes the sync mode (mark-read skips it).
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
      failed++
      console.error(`Study-sync fan-out failed for enrollment ${enrollment.id}:`, error)
    }
  }

  if (enrollments.length > 0) {
    console.log(
      `Study-sync fan-out for program ${programId} v${versionNumber}: ${synced} synced, ${skipped} already current, ${failed} failed`
    )
  }
  return { synced, skipped, failed }
}
