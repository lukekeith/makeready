import { prisma, Prisma } from '../lib/prisma.js'

/** Explicit compatibility projections: shared storage never leaks into released wire shapes. */
export interface LegacyInvitationSource {
  id: string; initiatedBy: string; token: string | null; inviterId: string | null;
  groupId: string | null; memberId: string | null; recipientPhone: string | null;
  recipientName: string | null; status: string; message: string | null;
  respondedById: string | null; respondedAt: Date | null; acceptedAt: Date | null;
  expiresAt: Date | null; createdAt: Date; updatedAt: Date;
}

export function toLegacyInvite(row: LegacyInvitationSource) {
  if (row.initiatedBy !== 'leader' || !row.token || !row.inviterId) throw new Error('Not a legacy leader invitation')
  return {
    id: row.id, token: row.token, groupId: row.groupId, inviterId: row.inviterId,
    recipientPhone: row.recipientPhone, recipientName: row.recipientName, status: row.status,
    expiresAt: row.expiresAt, createdAt: row.createdAt, acceptedAt: row.acceptedAt,
  }
}

export function toLegacyJoinRequest(row: LegacyInvitationSource) {
  if (row.initiatedBy !== 'member' || !row.groupId || !row.memberId) throw new Error('Not a legacy member request')
  return {
    id: row.id, groupId: row.groupId, memberId: row.memberId,
    status: row.status === 'accepted' ? 'approved' : row.status, message: row.message,
    reviewedById: row.respondedById, reviewedAt: row.respondedAt,
    createdAt: row.createdAt, updatedAt: row.updatedAt,
  }
}

export function leaderInvitationWhere(where: Prisma.InvitationWhereInput = {}): Prisma.InvitationWhereInput {
  return { AND: [where, { initiatedBy: 'leader' }] }
}
export function memberInvitationWhere(where: Prisma.InvitationWhereInput = {}): Prisma.InvitationWhereInput {
  return { AND: [where, { initiatedBy: 'member' }] }
}
export function legacyRequestStatusWhere(status: string): Prisma.InvitationWhereInput {
  if (status === 'accepted' || status === 'withdrawn') return { id: { in: [] } }
  return { status: status === 'approved' ? 'accepted' : status }
}
export const legacyRequestStatus = (status: string) => status === 'accepted' ? 'approved' : status

export async function resolveLegacyInvitationOrganization(groupId: string | null | undefined, inviterId: string): Promise<string | null> {
  if (groupId) {
    const group = await prisma.group.findUnique({ where: { id: groupId }, select: { organizationId: true } })
    if (group) return group.organizationId
  }
  const user = await prisma.user.findUnique({ where: { id: inviterId }, select: { organizationId: true } })
  if (user?.organizationId) {
    // organizationId is a deprecated free string, so do not feed an invalid UUID into its FK query.
    const orgs = await prisma.organization.findMany({ where: { OR: [{ ownerId: inviterId }, { userRoles: { some: { userId: inviterId } } }] }, select: { id: true } })
    if (orgs.some(org => org.id === user.organizationId)) return user.organizationId
    const historical = await prisma.$queryRaw<Array<{ id: string }>>`SELECT id::text AS id FROM organizations WHERE id::text = ${user.organizationId}`
    if (historical[0]) return historical[0].id
    return orgs.length === 1 ? orgs[0].id : null
  }
  const orgs = await prisma.organization.findMany({ where: { OR: [{ ownerId: inviterId }, { userRoles: { some: { userId: inviterId } } }] }, select: { id: true } })
  return orgs.length === 1 ? orgs[0].id : null
}

export async function createLeaderInvitation(data: Omit<Prisma.InvitationUncheckedCreateInput, 'initiatedBy'> & { token: string; inviterId: string }) {
  return prisma.invitation.create({ data: {
    ...data, initiatedBy: 'leader',
    organizationId: data.organizationId ?? await resolveLegacyInvitationOrganization(data.groupId, data.inviterId),
  } })
}

export async function createMemberInvitation(data: Omit<Prisma.InvitationUncheckedCreateInput, 'initiatedBy'> & { groupId: string; memberId: string }) {
  const [group, member] = await Promise.all([
    prisma.group.findUniqueOrThrow({ where: { id: data.groupId }, select: { organizationId: true } }),
    prisma.member.findUniqueOrThrow({ where: { id: data.memberId }, select: { phoneNumber: true } }),
  ])
  return prisma.invitation.create({ data: { ...data, initiatedBy: 'member', organizationId: group.organizationId, recipientPhone: member.phoneNumber } })
}

export async function findLatestLegacyJoinRequest(groupId: string, memberId: string) {
  const row = await prisma.invitation.findFirst({
    where: memberInvitationWhere({ groupId, memberId }), orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
  })
  return row ? toLegacyJoinRequest(row) : null
}

export function requiredRelation<T>(value: T | null): T {
  if (value === null) throw new Error('Invitation legacy identity relation is missing')
  return value
}
