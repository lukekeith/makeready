/**
 * Home dashboard computations (home-dashboard-data D3, D6, D8, D14, D15, D16):
 * Sessions by range, day-card minutes + 2-hour blocks, and Engagement. Every
 * local-time decision is made in the caller's IANA tz; a schedule's day is its
 * STORED calendar date (UTC date part, D14), never shifted by tz.
 */
import { prisma } from '../lib/prisma.js'
import type { AnalyticsScope } from './analytics.service.js'
import { loadSessions, scopeGroupWhere, type Session } from './home-sessions.js'

export type SessionRange = 'all' | 'year' | 'month' | 'week'
export const RANGE_DAYS: Record<Exclude<SessionRange, 'all'>, number> = { year: 365, month: 30, week: 7 }
export const ALL_TIME_CAP_DAYS = 730
export const STRIP_BINS = 88
/** Readable minute steps for the session-length axis; the axis carries at most 4 ticks. */
export const TICK_STEPS_MINUTES = [1, 2, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240, 360, 480, 720] as const
export const MAX_TICKS = 4
export const DAY_BLOCKS = 12
export const MAX_DAY_SPAN = 62
export const ACTIVE_DAYS = 7

export interface HomeSessions {
  averageSeconds: number
  sessionCount: number
  /** D23: sessions active during each local hour 0–23 (a session counts in every hour it spans). */
  hourly: number[]
  /** D18: sessions per session-length band — STRIP_BINS equal bands over 0 … axisMinutes, max band = 1. */
  bins: number[]
  /** D18: the axis labels in minutes, 0 first and axisMinutes last, at most MAX_TICKS. */
  ticks: number[]
  axisMinutes: number
}
export interface HomeDay {
  day: string
  sessionSeconds: number
  blocks: number[]
  /** ui2-members-browse SC7/D12: ISO end of the day's last session; null on a day with none. */
  lastActivityAt: string | null
}
export interface HomeEngagement {
  currentCount: number
  enrolledCount: number
  groupCount: number
  percent: number
  activeCount: number
}
export interface EngagementGroup {
  id: string
  memberIds: string[]
  /** Non-removed schedules, `date` = the stored calendar date (D14). */
  schedules: { id: string; date: string }[]
}

// ── Time helpers (formatters cached per tz — they are expensive to build) ────

const dateFormats = new Map<string, Intl.DateTimeFormat>()
const hourFormats = new Map<string, Intl.DateTimeFormat>()
const offsetFormats = new Map<string, Intl.DateTimeFormat>()

function cached(map: Map<string, Intl.DateTimeFormat>, tz: string, make: () => Intl.DateTimeFormat): Intl.DateTimeFormat {
  let f = map.get(tz)
  if (!f) {
    f = make()
    map.set(tz, f)
  }
  return f
}

/** Calendar date (YYYY-MM-DD) of an instant in tz. */
export function localDateOf(instant: Date, tz: string): string {
  return cached(dateFormats, tz, () =>
    new Intl.DateTimeFormat('en-CA', { timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit' })
  ).format(instant)
}

/** Wall-clock hour 0–23 of an instant in tz. */
export function localHourOf(instant: Date, tz: string): number {
  const parts = cached(hourFormats, tz, () =>
    new Intl.DateTimeFormat('en-US', { timeZone: tz, hour: 'numeric', hourCycle: 'h23' })
  ).formatToParts(instant)
  return Number(parts.find((p) => p.type === 'hour')?.value ?? '0') % 24
}

/** Date-only arithmetic on YYYY-MM-DD (UTC-noon anchor avoids DST edges). */
export function addDays(date: string, days: number): string {
  const d = new Date(`${date}T12:00:00Z`)
  d.setUTCDate(d.getUTCDate() + days)
  return d.toISOString().slice(0, 10)
}

/** Milliseconds tz is ahead of UTC at `instant` (as fixtures/context.ts tzOffsetMs). */
function tzOffsetMs(instant: Date, tz: string): number {
  const parts = cached(offsetFormats, tz, () =>
    new Intl.DateTimeFormat('en-US', {
      timeZone: tz,
      hour12: false,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    })
  ).formatToParts(instant)
  const get = (type: string) => Number(parts.find((p) => p.type === type)?.value ?? '0')
  const asUtc = Date.UTC(get('year'), get('month') - 1, get('day'), get('hour') % 24, get('minute'), get('second'))
  return asUtc - (instant.getTime() - instant.getUTCMilliseconds())
}

/** The UTC instant of local 00:00 on `date` in tz. */
export function zonedMidnight(date: string, tz: string): Date {
  const [y, m, d] = date.split('-').map(Number)
  const wall = Date.UTC(y, m - 1, d)
  const first = wall - tzOffsetMs(new Date(wall), tz)
  return new Date(wall - tzOffsetMs(new Date(first), tz))
}

/** A schedule's day: the stored calendar date (D14). */
export function storedDate(d: Date): string {
  return d.toISOString().slice(0, 10)
}

export function pairKey(memberId: string, scheduleId: string): string {
  return `${memberId}|${scheduleId}`
}

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/
const isRealDate = (d: string) => DATE_RE.test(d) && !Number.isNaN(Date.parse(`${d}T00:00:00Z`)) && storedDate(new Date(`${d}T00:00:00Z`)) === d

/** null when valid; otherwise the 400 message (§Contract: yyyy-MM-dd, ≤ 62 days). */
export function validateDayRange(from: string, to: string): string | null {
  if (!isRealDate(from) || !isRealDate(to)) return 'from/to must be YYYY-MM-DD'
  if (to < from) return 'to must not be before from'
  const span = Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000) + 1
  if (span > MAX_DAY_SPAN) return `At most ${MAX_DAY_SPAN} days`
  return null
}

// ── Sessions by range (D8, D18) ──────────────────────────────────────────────

/**
 * D18: the session-length axis for a longest session of `longestMinutes` — 0 to a readable end in a
 * readable step, at most MAX_TICKS labels, ending as close to the longest session as the steps
 * allow (40 → 0·20·40; 45 → 0·15·30·45).
 */
export function sessionLengthAxis(longestMinutes: number): { axisMinutes: number; ticks: number[] } {
  const longest = Math.max(1, Math.ceil(longestMinutes))
  let best: { step: number; count: number; axis: number } | null = null
  for (const step of TICK_STEPS_MINUTES) {
    const count = Math.ceil(longest / step)
    if (count + 1 > MAX_TICKS) continue
    const axis = step * count
    if (!best || axis < best.axis || (axis === best.axis && count > best.count)) best = { step, count, axis }
  }
  const pick = best ?? { step: TICK_STEPS_MINUTES[TICK_STEPS_MINUTES.length - 1], count: Math.ceil(longest / 720), axis: 720 * Math.ceil(longest / 720) }
  return { axisMinutes: pick.axis, ticks: Array.from({ length: pick.count + 1 }, (_, i) => i * pick.step) }
}

/** D23: the step the dial walks a session at to find every local hour it overlaps. */
const HOUR_PROBE_MS = 5 * 60_000

/** D23: the local hours (0–23) a session is active in — its start, every probe inside it, its end. */
export function hoursActive(session: Session, tz: string): Set<number> {
  const start = session.start.getTime()
  const end = start + session.seconds * 1000
  const hours = new Set<number>([localHourOf(session.start, tz)])
  for (let t = start + HOUR_PROBE_MS; t < end; t += HOUR_PROBE_MS) hours.add(localHourOf(new Date(t), tz))
  if (end > start) hours.add(localHourOf(new Date(end - 1), tz))
  return hours
}

export function summarizeSessions(sessions: Session[], window: { from: Date; to: Date }, tz: string): HomeSessions {
  const inWindow = sessions.filter((s) => s.start >= window.from && s.start < window.to)
  // D23 (supersedes D8's mean length per start hour): activity concentration — how many
  // sessions are active during each local hour, a session counting once in every hour it spans.
  const hourly: number[] = Array(24).fill(0)
  const binSums: number[] = Array(STRIP_BINS).fill(0)
  let total = 0
  for (const s of inWindow) {
    for (const hour of hoursActive(s, tz)) hourly[hour] += 1
    total += s.seconds
  }
  // D18: a histogram of session LENGTH (end − start): how many sessions fall in each band.
  const longestMinutes = inWindow.reduce((m, s) => Math.max(m, s.seconds / 60), 0)
  const axis = sessionLengthAxis(longestMinutes)
  for (const s of inWindow) {
    const bin = Math.min(STRIP_BINS - 1, Math.floor((s.seconds / 60 / axis.axisMinutes) * STRIP_BINS))
    binSums[bin] += 1
  }
  const maxBin = Math.max(0, ...binSums)
  return {
    averageSeconds: inWindow.length > 0 ? Math.round(total / inWindow.length) : 0,
    sessionCount: inWindow.length,
    hourly,
    bins: binSums.map((v) => (maxBin > 0 ? Math.round((v / maxBin) * 1000) / 1000 : 0)),
    ticks: inWindow.length > 0 ? axis.ticks : [0],
    axisMinutes: inWindow.length > 0 ? axis.axisMinutes : 0,
  }
}

export async function getHomeSessions(
  scope: AnalyticsScope,
  range: SessionRange,
  tz: string,
  now: Date = new Date()
): Promise<HomeSessions> {
  const today = localDateOf(now, tz)
  if (range === 'all') {
    const cap = { from: zonedMidnight(addDays(today, -(ALL_TIME_CAP_DAYS - 1)), tz), to: now }
    const sessions = await loadSessions(scope, cap)
    const first = sessions.reduce<Date | null>((min, s) => (min === null || s.start < min ? s.start : min), null)
    return summarizeSessions(sessions, { from: first ?? cap.from, to: now }, tz)
  }
  const window = { from: zonedMidnight(addDays(today, -(RANGE_DAYS[range] - 1)), tz), to: now }
  return summarizeSessions(await loadSessions(scope, window), window, tz)
}

// ── Day cards (D6) ───────────────────────────────────────────────────────────

export function bucketDays(sessions: Session[], from: string, to: string, tz: string): HomeDay[] {
  const days: HomeDay[] = []
  const byDay = new Map<string, HomeDay>()
  for (let d = from; d <= to; d = addDays(d, 1)) {
    const day: HomeDay = { day: d, sessionSeconds: 0, blocks: Array(DAY_BLOCKS).fill(0), lastActivityAt: null }
    days.push(day)
    byDay.set(d, day)
  }
  const lastEnd = new Map<string, number>()
  for (const s of sessions) {
    const key = localDateOf(s.start, tz)
    const day = byDay.get(key)
    if (!day) continue
    day.blocks[Math.floor(localHourOf(s.start, tz) / 2)] += s.seconds
    day.sessionSeconds += s.seconds
    // A session belongs to the day it STARTS (F8): one crossing local midnight
    // reports the next day's end time here — accepted (SPEC F8).
    const end = s.end.getTime()
    if (end > (lastEnd.get(key) ?? Number.NEGATIVE_INFINITY)) {
      lastEnd.set(key, end)
      day.lastActivityAt = s.end.toISOString()
    }
  }
  return days
}

export async function getHomeDays(
  scope: AnalyticsScope,
  from: string,
  to: string,
  tz: string,
  opts: { memberId?: string; groupId?: string } = {}
): Promise<{ days: HomeDay[] }> {
  const window = { from: zonedMidnight(from, tz), to: zonedMidnight(addDays(to, 1), tz) }
  const sessions = opts.memberId
    ? await loadSessions(scope, window, { memberId: opts.memberId })
    : opts.groupId
      ? await loadSessions(scope, window, { groupId: opts.groupId })
      : await loadSessions(scope, window)
  return { days: bucketDays(sessions, from, to, tz) }
}

// ── Engagement (D3, D14, D15) ────────────────────────────────────────────────

export function computeEngagement(
  groups: EngagementGroup[],
  completed: Set<string>,
  activeMemberIds: Set<string>,
  today: string
): HomeEngagement {
  const dueByMember = new Map<string, Set<string>>()
  const enrolledGroups = new Set<string>()
  for (const group of groups) {
    const due = group.schedules.filter((s) => s.date < today)
    if (due.length === 0) continue
    enrolledGroups.add(group.id)
    for (const memberId of group.memberIds) {
      const set = dueByMember.get(memberId) ?? new Set<string>()
      for (const s of due) set.add(s.id)
      dueByMember.set(memberId, set)
    }
  }
  let current = 0
  for (const [memberId, due] of dueByMember) {
    if ([...due].every((scheduleId) => completed.has(pairKey(memberId, scheduleId)))) current += 1
  }
  const enrolled = dueByMember.size
  return {
    currentCount: current,
    enrolledCount: enrolled,
    groupCount: enrolledGroups.size,
    percent: enrolled > 0 ? Math.round((current / enrolled) * 100) : 0,
    activeCount: activeMemberIds.size,
  }
}

export function activeWindow(now: Date, tz: string): { from: Date; to: Date } {
  return { from: zonedMidnight(addDays(localDateOf(now, tz), -(ACTIVE_DAYS - 1)), tz), to: now }
}

export function activeMembers(sessions: Session[], window: { from: Date; to: Date }): Set<string> {
  return new Set(sessions.filter((s) => s.start >= window.from && s.start < window.to).map((s) => s.memberId))
}

export async function getHomeEngagement(
  scope: AnalyticsScope,
  tz: string,
  now: Date = new Date()
): Promise<HomeEngagement> {
  const today = localDateOf(now, tz)
  const rows = await prisma.group.findMany({
    where: { isActive: true, ...scopeGroupWhere(scope) },
    select: {
      id: true,
      members: { where: { isActive: true, memberId: { not: null } }, select: { memberId: true } },
      enrollments: {
        select: { lessonSchedules: { where: { removedAt: null }, select: { id: true, scheduledDate: true } } },
      },
    },
  })
  const groups: EngagementGroup[] = rows.map((g) => ({
    id: g.id,
    memberIds: g.members.flatMap((m) => (m.memberId ? [m.memberId] : [])),
    schedules: g.enrollments.flatMap((e) =>
      e.lessonSchedules.map((s) => ({ id: s.id, date: storedDate(s.scheduledDate) }))
    ),
  }))
  const dueIds = [...new Set(groups.flatMap((g) => g.schedules.filter((s) => s.date < today).map((s) => s.id)))]
  const memberIds = [...new Set(groups.flatMap((g) => g.memberIds))]
  const progress =
    dueIds.length > 0 && memberIds.length > 0
      ? await prisma.memberLessonProgress.findMany({
          where: { completedAt: { not: null }, lessonScheduleId: { in: dueIds }, memberId: { in: memberIds } },
          select: { memberId: true, lessonScheduleId: true },
        })
      : []
  const completed = new Set(progress.map((p) => pairKey(p.memberId, p.lessonScheduleId)))
  const window = activeWindow(now, tz)
  const active = activeMembers(await loadSessions(scope, window), window)
  return computeEngagement(groups, completed, active, today)
}
