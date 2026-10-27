/**
 * Group history feed (ui2-groups-browse D15, F6): the group page's Timeline, merged newest-first from
 * three sources already recorded — MembershipEvent (joins, leaves, requests), the Activity ledger's
 * GROUP rows (created, settings, cover) and the group's past non-lesson Events. Read-only.
 */
import { prisma } from '../lib/prisma.js'

export type GroupHistoryKind =
  | 'member_joined'
  | 'member_left'
  | 'join_requested'
  | 'settings_updated'
  | 'cover_updated'
  | 'group_created'
  | 'event_held'

export type GroupHistoryEvent = {
  id: string
  occurredAt: string
  kind: GroupHistoryKind
  text: string
  highlight: string | null
}

/** D15: INVITED, REJECTED and REMOVED_ORG are never read (REMOVED_ORG carries no groupId). */
const MEMBERSHIP_KIND = {
  APPROVED: 'member_joined',
  ADDED: 'member_joined',
  REJOINED: 'member_joined',
  REMOVED_GROUP: 'member_left',
  REQUESTED: 'join_requested',
} as const satisfies Record<string, GroupHistoryKind>
type ReadAction = keyof typeof MEMBERSHIP_KIND
const READ_ACTIONS = Object.keys(MEMBERSHIP_KIND) as ReadAction[]

const ACTIVITY_TEXT = {
  group_created: 'Created the group',
  cover_updated: 'Updated cover photo',
  settings_updated: 'Updated group settings',
} as const

/** «name» = first + " " + last, trimmed, else "Unknown" (as group-members.ts:221). */
export function memberDisplayName(member: { firstName: string | null; lastName: string | null } | null): string {
  const name = `${member?.firstName ?? ''} ${member?.lastName ?? ''}`.trim()
  return name || 'Unknown'
}

function membershipText(kind: (typeof MEMBERSHIP_KIND)[ReadAction], name: string): string {
  if (kind === 'member_joined') return `${name} joined the group`
  if (kind === 'member_left') return `${name} left the group`
  return `${name} requested to join`
}

function metadataField(metadata: unknown): unknown {
  return metadata !== null && typeof metadata === 'object' && !Array.isArray(metadata)
    ? (metadata as Record<string, unknown>).field
    : undefined
}

export async function getGroupHistory(groupId: string, limit: number, now: Date = new Date()): Promise<GroupHistoryEvent[]> {
  const [memberships, activities, events] = await Promise.all([
    prisma.membershipEvent.findMany({
      where: { groupId, action: { in: READ_ACTIONS } },
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: { id: true, action: true, createdAt: true, member: { select: { firstName: true, lastName: true } } },
    }),
    // F6: Activity.groupId is set for every resource in the group — match the GROUP resource itself.
    prisma.activity.findMany({
      where: { resourceType: 'GROUP', resourceId: groupId, action: { in: ['CREATED', 'UPDATED'] } },
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: { id: true, action: true, metadata: true, createdAt: true },
    }),
    // Enrollments create one LESSON event per day (enrollments.ts:342) — those are not history.
    prisma.event.findMany({
      where: { groupId, isActive: true, type: { not: 'LESSON' }, date: { lt: now } },
      orderBy: { date: 'desc' },
      take: limit,
      select: { id: true, title: true, locationName: true, date: true },
    }),
  ])

  const out: GroupHistoryEvent[] = []
  for (const m of memberships) {
    const kind = MEMBERSHIP_KIND[m.action as ReadAction]
    const name = memberDisplayName(m.member)
    out.push({ id: `membership:${m.id}`, occurredAt: m.createdAt.toISOString(), kind, text: membershipText(kind, name), highlight: name })
  }
  for (const a of activities) {
    const kind: keyof typeof ACTIVITY_TEXT =
      a.action === 'CREATED' ? 'group_created' : metadataField(a.metadata) === 'cover' ? 'cover_updated' : 'settings_updated'
    out.push({ id: `activity:${a.id}`, occurredAt: a.createdAt.toISOString(), kind, text: ACTIVITY_TEXT[kind], highlight: null })
  }
  for (const e of events) {
    const place = e.locationName ?? e.title
    out.push({
      id: `event:${e.id}`,
      occurredAt: e.date.toISOString(),
      kind: 'event_held',
      text: `Held event at ${place}`,
      highlight: `event at ${place}`,
    })
  }
  return out
    .sort((x, y) => y.occurredAt.localeCompare(x.occurredAt) || x.id.localeCompare(y.id))
    .slice(0, limit)
}
