/**
 * ui2-enrollment-create D4/D15: whether a member may open a lesson yet. ONE_AT_A_TIME opens each
 * lesson at 00:00 on its scheduled day in the enrollment's timezone (UTC when null); ALL_AT_ONCE
 * is always open. Callers exempt group leaders and managers before asking.
 */
import { formatLongDay, localDate } from '../utils/timezone.js'

export type LessonAvailability =
  | { available: true }
  | { available: false; availableOn: string; message: string }

export function lessonAvailability(
  scheduledDate: Date,
  enrollment: { lessonAccess: 'ONE_AT_A_TIME' | 'ALL_AT_ONCE'; timezone: string | null },
  now: Date,
): LessonAvailability {
  if (enrollment.lessonAccess !== 'ONE_AT_A_TIME') return { available: true }
  const tz = enrollment.timezone || 'UTC'
  const lessonDay = localDate(scheduledDate, tz)
  if (localDate(now, tz) >= lessonDay) return { available: true }
  return {
    available: false,
    availableOn: lessonDay,
    message: `This lesson is available on ${formatLongDay(scheduledDate, tz)}`,
  }
}

/** The 403 body both gated routes send (§Contract row 2). */
export function notYetBody(a: { availableOn: string; message: string }) {
  return { success: false, error: 'not_yet_available', message: a.message, availableOn: a.availableOn }
}
