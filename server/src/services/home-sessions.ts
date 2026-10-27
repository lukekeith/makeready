/**
 * Home dashboard sessions (home-dashboard-data D2): a member's activity moments
 * less than 30 min apart form one session; duration = last − first, floored at
 * 60 s. Derived per request from data already recorded — no stored table.
 * Shared by /api/home/sessions (D8), /days (D6) and engagement's active count (D3).
 */
import type { Prisma } from '../generated/prisma/index.js'
import { prisma } from '../lib/prisma.js'
import type { AnalyticsScope } from './analytics.service.js'

export type Moment = { memberId: string; at: Date }
export type Session = { memberId: string; start: Date; end: Date; seconds: number }

export const SESSION_GAP_MS = 30 * 60 * 1000
export const SESSION_FLOOR_SECONDS = 60
/** Moments load this far either side of the window so edge sessions keep their true start. */
const LOAD_PAD_MS = 6 * 60 * 60 * 1000

export function sessionize(
  moments: Moment[],
  gapMs = SESSION_GAP_MS,
  floorSeconds = SESSION_FLOOR_SECONDS
): Session[] {
  const byMember = new Map<string, number[]>()
  for (const moment of moments) {
    const list = byMember.get(moment.memberId) ?? []
    list.push(moment.at.getTime())
    byMember.set(moment.memberId, list)
  }
  const sessions: Session[] = []
  for (const [memberId, times] of byMember) {
    times.sort((a, b) => a - b)
    let start = times[0]
    let last = times[0]
    const close = () =>
      sessions.push({
        memberId,
        start: new Date(start),
        end: new Date(last),
        seconds: Math.max(floorSeconds, Math.round((last - start) / 1000)),
      })
    for (let i = 1; i < times.length; i++) {
      if (times[i] - last >= gapMs) {
        close()
        start = times[i]
      }
      last = times[i]
    }
    close()
  }
  return sessions.sort((a, b) => a.start.getTime() - b.start.getTime() || a.memberId.localeCompare(b.memberId))
}

export function scopeGroupWhere(scope: AnalyticsScope): Prisma.GroupWhereInput {
  if (scope.all) return {}
  return { OR: [{ organizationId: { in: scope.orgIds } }, { id: { in: scope.groupIds } }] }
}

function clientEventScope(scope: AnalyticsScope): Prisma.ClientEventWhereInput {
  if (scope.all) return {}
  return { OR: [{ organizationId: { in: scope.orgIds } }, { groupId: { in: scope.groupIds } }] }
}

type MemberFilter = { memberId?: string | { in: string[] } }

/** ui2-members-browse D12: one member · ui2-groups-browse D14: the active members of one group. */
async function memberFilter(opts: { memberId?: string; groupId?: string }): Promise<MemberFilter> {
  if (opts.memberId) return { memberId: opts.memberId }
  if (!opts.groupId) return {}
  const rows = await prisma.groupMember.findMany({
    where: { groupId: opts.groupId, isActive: true, memberId: { not: null } },
    select: { memberId: true },
  })
  return { memberId: { in: [...new Set(rows.flatMap((r) => (r.memberId ? [r.memberId] : [])))] } }
}

export async function loadSessions(
  scope: AnalyticsScope,
  window: { from: Date; to: Date },
  opts: { memberId?: string; groupId?: string } = {}
): Promise<Session[]> {
  const from = new Date(window.from.getTime() - LOAD_PAD_MS)
  const to = new Date(window.to.getTime() + LOAD_PAD_MS)
  const range = { gte: from, lt: to }
  const inRange = (d: Date) => d >= from && d < to
  const scheduleWhere = { enrollment: { group: scopeGroupWhere(scope) } }
  // ui2-members-browse D12 (member page rail) / ui2-groups-browse D14 (group page rail).
  const member = await memberFilter(opts)

  const [events, lessons, videos] = await Promise.all([
    prisma.clientEvent.findMany({
      where: { memberId: { not: null }, occurredAt: range, ...clientEventScope(scope), ...member },
      select: { memberId: true, occurredAt: true },
    }),
    prisma.memberLessonProgress.findMany({
      where: { completedAt: range, lessonSchedule: scheduleWhere, ...member },
      select: { memberId: true, completedAt: true },
    }),
    prisma.memberVideoProgress.findMany({
      where: { OR: [{ startedAt: range }, { lastWatchedAt: range }], lessonSchedule: scheduleWhere, ...member },
      select: { memberId: true, startedAt: true, lastWatchedAt: true },
    }),
  ])

  // client_events has no FK: drop events of deleted members, as the ce: view arm does.
  const eventMemberIds = [...new Set(events.flatMap((e) => (e.memberId ? [e.memberId] : [])))]
  const existing =
    eventMemberIds.length > 0
      ? new Set(
          (await prisma.member.findMany({ where: { id: { in: eventMemberIds } }, select: { id: true } })).map((r) => r.id)
        )
      : new Set<string>()

  const moments: Moment[] = []
  for (const e of events) if (e.memberId && existing.has(e.memberId)) moments.push({ memberId: e.memberId, at: e.occurredAt })
  for (const l of lessons) if (l.completedAt) moments.push({ memberId: l.memberId, at: l.completedAt })
  for (const v of videos) {
    if (inRange(v.startedAt)) moments.push({ memberId: v.memberId, at: v.startedAt })
    if (inRange(v.lastWatchedAt)) moments.push({ memberId: v.memberId, at: v.lastWatchedAt })
  }
  return sessionize(moments).filter((s) => s.start >= window.from && s.start < window.to)
}
