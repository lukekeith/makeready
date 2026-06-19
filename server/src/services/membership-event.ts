/**
 * Membership Event Service
 *
 * An immutable, append-only audit trail of every membership transition a
 * member goes through (invited, requested, approved, rejected, added,
 * rejoined, removed from a group, removed from an org).
 *
 * Unlike the Activity ledger (fire-and-forget, drives notifications), these
 * events are AWAITED so the audit trail is reliable. Pass a transaction client
 * to make the event atomic with the membership change it records.
 *
 * Removing a member NEVER deletes the Member or their data — only their
 * membership state changes — so a leader can always review past decisions
 * here and reverse them. Nobody is ever lost.
 */

import { prisma } from '../lib/prisma.js'
import { MembershipEventAction, Prisma } from '../generated/prisma/index.js'

/** Either the global client or an in-flight transaction client. */
type Db = Prisma.TransactionClient | typeof prisma

export type MembershipActorType = 'user' | 'member' | 'system'

export interface RecordMembershipEventParams {
  /** The member this event concerns (canonical identity, keyed by phone). */
  memberId: string
  action: MembershipEventAction
  /** Group context; omit for org-level events. */
  groupId?: string | null
  /** Org context, for org-scoped history queries. */
  organizationId?: string | null
  /** Who performed it — a User id (leader) or Member id (self-service). */
  actorId?: string | null
  actorType?: MembershipActorType | null
  /** Optional reason/message (rejection reason, join message, etc.). */
  note?: string | null
  metadata?: Record<string, unknown> | null
}

/**
 * Append a membership event. Awaited (reliable). Pass `db` (a transaction
 * client) to record the event atomically with the membership change.
 */
export async function recordMembershipEvent(
  params: RecordMembershipEventParams,
  db: Db = prisma
) {
  return db.membershipEvent.create({
    data: {
      memberId: params.memberId,
      action: params.action,
      groupId: params.groupId ?? null,
      organizationId: params.organizationId ?? null,
      actorId: params.actorId ?? null,
      actorType: params.actorType ?? null,
      note: params.note ?? null,
      metadata: (params.metadata as Prisma.InputJsonValue) ?? undefined,
    },
  })
}

export interface MembershipHistoryFilter {
  memberId?: string
  groupId?: string
  organizationId?: string
  action?: MembershipEventAction
  /** Free-text search across member name and phone number. */
  search?: string
  limit?: number
}

/**
 * Query the membership audit trail, newest first. Supports scoping by member,
 * group, or org, filtering by action, and free-text search across the
 * member's name and phone number (so a leader can find someone they once
 * rejected and reverse the decision).
 */
export async function getMembershipHistory(filter: MembershipHistoryFilter) {
  const { memberId, groupId, organizationId, action, search } = filter
  const limit = Math.min(filter.limit ?? 100, 500)

  const trimmed = search?.trim()
  const memberFilter: Prisma.MemberWhereInput | undefined = trimmed
    ? {
        OR: [
          { firstName: { contains: trimmed, mode: 'insensitive' } },
          { lastName: { contains: trimmed, mode: 'insensitive' } },
          { phoneNumber: { contains: trimmed } },
        ],
      }
    : undefined

  return prisma.membershipEvent.findMany({
    where: {
      ...(memberId ? { memberId } : {}),
      ...(groupId ? { groupId } : {}),
      ...(organizationId ? { organizationId } : {}),
      ...(action ? { action } : {}),
      ...(memberFilter ? { member: memberFilter } : {}),
    },
    orderBy: { createdAt: 'desc' },
    take: limit,
    include: {
      member: {
        select: {
          id: true,
          firstName: true,
          lastName: true,
          phoneNumber: true,
        },
      },
      group: { select: { id: true, name: true } },
    },
  })
}
