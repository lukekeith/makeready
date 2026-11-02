import { prisma, Prisma } from '../lib/prisma.js'
import type { Invitation } from '../generated/prisma/index.js'
import { normalizePhone } from './member-fields.js'
import { recordMembershipEvent } from './membership-event.js'
import { groupManageFilter } from './permission.js'
import { sendCampaignSmsBatch } from './sms-campaign.js'
import { generateUniqueGroupCode } from '../lib/group-code.js'

type Db = Prisma.TransactionClient


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

export async function resolveLegacyInvitationOrganization(groupId: string | null | undefined, inviterId: string, db: Db = prisma): Promise<string | null> {
  if (groupId) {
    const group = await db.group.findUnique({ where: { id: groupId }, select: { organizationId: true } })
    if (group) return group.organizationId
  }
  const user = await db.user.findUnique({ where: { id: inviterId }, select: { organizationId: true } })
  if (user?.organizationId) {
    // organizationId is a deprecated free string, so do not feed an invalid UUID into its FK query.
    const orgs = await db.organization.findMany({ where: { OR: [{ ownerId: inviterId }, { userRoles: { some: { userId: inviterId } } }] }, select: { id: true } })
    if (orgs.some(org => org.id === user.organizationId)) return user.organizationId
    const historical = await db.$queryRaw<Array<{ id: string }>>`SELECT id::text AS id FROM organizations WHERE id::text = ${user.organizationId}`
    if (historical[0]) return historical[0].id
    return orgs.length === 1 ? orgs[0].id : null
  }
  const orgs = await db.organization.findMany({ where: { OR: [{ ownerId: inviterId }, { userRoles: { some: { userId: inviterId } } }] }, select: { id: true } })
  return orgs.length === 1 ? orgs[0].id : null
}

export async function createLeaderInvitation(data: Omit<Prisma.InvitationUncheckedCreateInput, 'initiatedBy'> & { token: string; inviterId: string }, db?: Db): Promise<Invitation> {
  if (!db) return withInvitationTransaction(tx => createLeaderInvitation(data, tx))
  const row = await db.invitation.create({ data: {
    ...data, initiatedBy: 'leader', organizationId: data.organizationId ?? await resolveLegacyInvitationOrganization(data.groupId, data.inviterId, db),
  } })
  await recordEvent(db, { invitationId: row.id, type: 'sent', actorId: data.inviterId, groupId: data.groupId, at: row.createdAt })
  return row
}

export async function createMemberInvitation(data: Omit<Prisma.InvitationUncheckedCreateInput, 'initiatedBy'> & { groupId: string; memberId: string }, db?: Db): Promise<Invitation> {
  if (!db) return withInvitationTransaction(tx => createMemberInvitation(data, tx))
  const [group, member] = await Promise.all([
    db.group.findUniqueOrThrow({ where: { id: data.groupId }, select: { organizationId: true } }),
    db.member.findUniqueOrThrow({ where: { id: data.memberId }, select: { phoneNumber: true } }),
  ])
  const row = await db.invitation.create({ data: { ...data, initiatedBy: 'member', organizationId: group.organizationId, recipientPhone: member.phoneNumber } })
  await recordEvent(db, { invitationId: row.id, type: 'requested', actorId: data.memberId, groupId: data.groupId, at: row.createdAt })
  return row
}

export async function findLatestLegacyJoinRequest(groupId: string, memberId: string, db: Db = prisma) {
  const row = await db.invitation.findFirst({
    where: memberInvitationWhere({ groupId, memberId }), orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
  })
  return row ? toLegacyJoinRequest(row) : null
}

export function requiredRelation<T>(value: T | null): T {
  if (value === null) throw new Error('Invitation legacy identity relation is missing')
  return value
}

export type InvitationEventType = 'sent' | 'resent' | 'link_clicked' | 'accepted' | 'withdrawn' | 'expired' | 'requested' | 'approved' | 'rejected'
export function recordEvent(tx: Db, input: { invitationId: string; type: InvitationEventType; at?: Date; actorId?: string | null; groupId?: string | null; metadata?: Prisma.InputJsonValue }) {
  return tx.inviteEvent.create({ data: input })
}

/** Only DB work may run here: retrying external delivery would send twice. */
export async function withInvitationTransaction<T>(work: (tx: Db) => Promise<T>): Promise<T> {
  for (let attempt = 0; ; attempt++) {
    try { return await prisma.$transaction(work, { isolationLevel: 'Serializable', timeout: 15000 }) }
    catch (error) {
      const failure = error as { code?: string; meta?: { code?: string } }
      if (attempt >= 2 || !(failure.code === 'P2034' || (failure.code === 'P2010' && ['40001','40P01'].includes(failure.meta?.code ?? '')))) throw error
    }
  }
}

export async function lockInvitationPerson(tx: Db, groupId: string | null, phone: string | null) {
  if (!groupId || !phone) return
  const key = JSON.stringify(['invitation-person', groupId.toLowerCase(), normalizePhone(phone) ?? phone])
  await tx.$queryRaw`SELECT 1 AS locked FROM pg_advisory_xact_lock(hashtextextended(${key}, 0))`
}
async function lockInvitationRow(tx: Db, id: string) {
  await tx.$queryRaw`SELECT id FROM invitations WHERE id = ${id}::uuid FOR UPDATE`
}
async function lockExistingInvitation(tx: Db, id: string, kind: 'leader' | 'member') {
  const identity = await tx.invitation.findUnique({ where: { id, initiatedBy: kind }, include: { member: { select: { phoneNumber: true } } } })
  if (!identity) return null
  await lockInvitationPerson(tx, identity.groupId, kind === 'member' ? identity.member?.phoneNumber ?? identity.recipientPhone : identity.recipientPhone)
  await lockInvitationRow(tx, id)
  return tx.invitation.findUnique({ where: { id, initiatedBy: kind } })
}

async function ensureMembership(tx: Db, groupId: string, memberId: string, organizationId: string | null, review: boolean) {
  await tx.groupMember.upsert({
    where: { groupId_memberId: { groupId, memberId } },
    create: { groupId, memberId, role: 'member', isActive: true },
    update: review ? { isActive: true, role: 'member', joinedAt: new Date() } : { isActive: true },
  })
  if (organizationId) await tx.memberOrganization.upsert({
    where: { memberId_organizationId: { memberId, organizationId } }, create: { memberId, organizationId }, update: {},
  })
}

export async function submitInvitationRequest(memberId: string, groupId: string, message?: string, origin: 'direct' | 'confirmation' = 'direct') {
  return withInvitationTransaction(async tx => {
    const member = await tx.member.findUniqueOrThrow({ where: { id: memberId } })
    await lockInvitationPerson(tx, groupId, member.phoneNumber)
    const group = await tx.group.findFirst({ where: { id: groupId, isActive: true } })
    if (!group) return { kind: 'group-not-found' as const }
    const context = { group, member }
    if (await tx.groupMember.findFirst({ where: { groupId: group.id, memberId, isActive: true } })) return { ...context, kind: 'already-member' as const }
    const invite = await tx.invitation.findFirst({ where: leaderInvitationWhere({ groupId: group.id, recipientPhone: member.phoneNumber, status: 'pending' }), orderBy: [{ createdAt: 'desc' }, { id: 'desc' }] })
    if (invite) {
      await lockInvitationRow(tx, invite.id)
      await ensureMembership(tx, group.id, memberId, group.organizationId, false)
      const row = await tx.invitation.update({ where: { id: invite.id, initiatedBy: 'leader', status: 'pending' }, data: { status: 'accepted', acceptedAt: new Date() } })
      await recordEvent(tx, { invitationId: row.id, type: 'accepted', at: row.acceptedAt!, actorId: memberId, groupId: group.id })
      return { ...context, kind: 'joined' as const, row }
    }
    const latest = await findLatestLegacyJoinRequest(group.id, memberId, tx)
    if (latest?.status === 'pending') return { ...context, kind: 'duplicate-pending' as const, request: latest }
    const now = new Date()
    const createdAt = latest && latest.createdAt >= now ? new Date(latest.createdAt.getTime() + 1) : now
    const row = await createMemberInvitation({ groupId: group.id, memberId, message, createdAt }, tx)
    if (origin === 'direct') await recordMembershipEvent({ memberId, action: 'REQUESTED', groupId: group.id, organizationId: group.organizationId, actorId: memberId, actorType: 'member', note: message || null, metadata: { requestId: row.id } }, tx)
    return { ...context, kind: 'pending-created' as const, request: toLegacyJoinRequest(row) }
  })
}

async function applyRequestDecision(tx: Db, row: Invitation, actorId: string, decision: 'approve' | 'reject', reason?: string) {
  const group = await tx.group.findUniqueOrThrow({ where: { id: row.groupId! } })
  const member = await tx.member.findUniqueOrThrow({ where: { id: row.memberId! } })
  const now = new Date()
  if (decision === 'approve') await ensureMembership(tx, group.id, member.id, group.organizationId, true)
  const updated = await tx.invitation.update({ where: { id: row.id, initiatedBy: 'member', status: 'pending' }, data: { status: decision === 'approve' ? 'accepted' : 'rejected', respondedById: actorId, respondedAt: now } })
  await recordEvent(tx, { invitationId: row.id, type: decision === 'approve' ? 'approved' : 'rejected', at: now, actorId, groupId: group.id })
  await recordMembershipEvent({ memberId: member.id, action: decision === 'approve' ? 'APPROVED' : 'REJECTED', groupId: group.id, organizationId: group.organizationId, actorId, actorType: 'user', ...(decision === 'reject' ? { note: reason || null } : {}), metadata: { requestId: row.id } }, tx)
  return { kind: 'decided' as const, row: updated, member }
}

export async function decideInvitationRequest(requestId: string, groupId: string, actorId: string, decision: 'approve' | 'reject', reason?: string) {
  const permission = await groupManageFilter(actorId)
  return withInvitationTransaction(async tx => {
    const group = await tx.group.findFirst({ where: { id: groupId, ...permission, isActive: true } })
    if (!group) return { kind: 'group-not-found' as const }
    const row = await lockExistingInvitation(tx, requestId, 'member')
    if (!row || row.groupId !== group.id || row.status !== 'pending') return { kind: 'not-pending' as const }
    return applyRequestDecision(tx, row, actorId, decision, reason)
  })
}

export async function acceptInvitationById(id: string, actorId: string): Promise<{ success: boolean; error?: string; groupId?: string }> {
  return withInvitationTransaction(async tx => {
    const row = await lockExistingInvitation(tx, id, 'leader')
    if (!row) return { success: false, error: 'Invite not found' }
    if (row.status !== 'pending') return { success: false, error: 'Invite is no longer valid' }
    if (row.expiresAt && row.expiresAt < new Date()) return { success: false, error: 'Invite has expired' }
    if (!row.groupId) return { success: false, error: 'Invalid invite: no group specified' }
    if (!row.recipientPhone) return { success: false, error: 'Invite missing recipient phone number' }
    const member = await tx.member.findUnique({ where: { phoneNumber: row.recipientPhone } })
    if (!member) return { success: false, error: 'Member not found for this phone number' }
    const group = await tx.group.findUniqueOrThrow({ where: { id: row.groupId } })
    await ensureMembership(tx, group.id, member.id, group.organizationId, false)
    const now = new Date()
    await tx.invitation.update({ where: { id, initiatedBy: 'leader', status: 'pending' }, data: { status: 'accepted', acceptedAt: now } })
    await recordEvent(tx, { invitationId: id, type: 'accepted', at: now, actorId, groupId: group.id })
    return { success: true, groupId: group.id }
  })
}
export async function acceptInvitationByToken(token: string, actorId: string): Promise<{ success: boolean; error?: string; groupId?: string }> {
  const row = await prisma.invitation.findUnique({ where: { token, initiatedBy: 'leader' }, select: { id: true } })
  return row ? acceptInvitationById(row.id, actorId) : { success: false, error: 'Invite not found' }
}

export async function recordInvitationLinkClick(invitationId: string, now = new Date()) {
  return withInvitationTransaction(async tx => {
    await lockInvitationRow(tx, invitationId)
    const row = await tx.invitation.findUnique({ where: { id: invitationId, initiatedBy: 'leader' } })
    if (!row) return
    const last = await tx.inviteEvent.findFirst({ where: { invitationId, type: 'link_clicked' }, orderBy: [{ at: 'desc' }, { id: 'desc' }] })
    if (last && now.getTime() - last.at.getTime() < 600000) return
    await recordEvent(tx, { invitationId, type: 'link_clicked', at: now, groupId: row.groupId })
  })
}

export async function patchLegacyInvitation(id: string, actorId: string, data: { status?: 'pending' | 'accepted' | 'expired'; expiresAt?: Date | null }) {
  return withInvitationTransaction(async tx => {
    const row = await lockExistingInvitation(tx, id, 'leader')
    if (!row) return null
    const updated = await tx.invitation.update({ where: { id, initiatedBy: 'leader' }, data })
    if (data.status && data.status !== row.status && data.status !== 'pending') await recordEvent(tx, { invitationId: id, type: data.status, actorId, groupId: row.groupId })
    return updated
  })
}

export async function prepareInvitationSend(data: { groupId: string; inviterId: string; recipientPhone: string; recipientName?: string; token: string; expiresAt: Date }) {
  return withInvitationTransaction(async tx => {
    await lockInvitationPerson(tx, data.groupId, data.recipientPhone)
    const group = await tx.group.findUniqueOrThrow({ where: { id: data.groupId } })
    const member = await tx.member.findUnique({ where: { phoneNumber: normalizePhone(data.recipientPhone) ?? data.recipientPhone } })
    const pending = member ? await tx.invitation.findFirst({ where: memberInvitationWhere({ groupId: data.groupId, memberId: member.id, status: 'pending' }), orderBy: [{ createdAt:'desc' },{ id:'desc' }] }) : null
    if (pending) return { crossRequest: true, row: pending, code: group.code }
    const row = await createLeaderInvitation({ ...data, recipientName: data.recipientName ?? null, organizationId: group.organizationId }, tx)
    return { crossRequest: false, row, code: group.code }
  })
}

export async function ensureInvitationGroupCode(groupId: string) {
  // Mint once outside any retried transaction; conditional update retains a concurrent winner.
  const candidate = await generateUniqueGroupCode()
  await prisma.group.updateMany({ where: { id: groupId, code: null }, data: { code: candidate } })
  return (await prisma.group.findUniqueOrThrow({ where: { id: groupId }, select: { code:true } })).code!
}

export async function finishInvitationSend(id: string, crossRequest: boolean, actorId: string, recipientPhone: string, success: boolean) {
  return withInvitationTransaction(async tx => {
    const row = await lockExistingInvitation(tx, id, crossRequest ? 'member' : 'leader')
    if (!row) return false
    if (!success) {
      if (!crossRequest && row.status === 'pending') await tx.invitation.deleteMany({ where: { id, initiatedBy:'leader', status:'pending' } })
      return false
    }
    if (crossRequest) {
      if (row.status !== 'pending' || !row.groupId || !await tx.group.findFirst({ where: { id: row.groupId, isActive: true } })) return false
      await applyRequestDecision(tx, row, actorId, 'approve')
    }
    const member = await tx.member.findUnique({ where: { phoneNumber: normalizePhone(recipientPhone) ?? recipientPhone } })
    if (member && row.groupId) {
      const group = await tx.group.findUniqueOrThrow({ where: { id: row.groupId } })
      await recordMembershipEvent({ memberId: member.id, action:'INVITED', groupId:group.id, organizationId:group.organizationId, actorId, actorType:'user', metadata:{ inviteId:id,recipientPhone } }, tx)
    }
    return true
  })
}

export type InvitationKind = 'invite' | 'request'
export type InvitationDisplayStatus = 'sent' | 'requested' | 'accepted' | 'rejected' | 'expired'
export interface InvitationFeedItem {
  id: string; kind: InvitationKind; status: InvitationDisplayStatus;
  recipientPhone: string | null; recipientName: string | null; memberId: string | null;
  groupId: string | null; groupName: string | null; organizationId: string;
  inviterId: string | null; inviterName: string | null; date: string; createdAt: string;
}
export interface InvitationFeed {
  items: InvitationFeedItem[]; total: number;
  filters: { orgs: { id: string; name: string }[]; groups: { id: string; name: string; organizationId: string }[]; leaders: { id: string; name: string }[] };
}
export interface InvitationDetail {
  id: string; kind: InvitationKind; status: InvitationDisplayStatus | 'withdrawn';
  recipientPhone: string | null; recipientName: string | null; inviterName: string | null; message: string | null; createdAt: string;
  member: { id: string; name: string; picture: string | null; age: number | null; role: string | null; birthday: string | null; joinedAt: string | null } | null;
  invitations: { id: string; kind: InvitationKind; groupId: string | null; groupName: string | null; groupPicture: string | null; status: InvitationDisplayStatus | 'withdrawn'; date: string }[];
  events: { id: string; type: InvitationEventType; at: string; groupId: string | null; groupName: string | null; invitationId: string }[];
  canResend: boolean; canWithdraw: boolean;
}
export interface InvitationFeedFilters { orgId?: string; groupId?: string; leaderId?: string; status?: InvitationDisplayStatus; limit?: number }
export class InvitationReadError extends Error {
  constructor(public readonly status: 403 | 404 | 409 | 502, message: string) { super(message) }
}

const invitationKind = (row: Pick<Invitation, 'initiatedBy'>): InvitationKind => row.initiatedBy === 'member' ? 'request' : 'invite'
type DisplayRow = Pick<Invitation, 'status' | 'initiatedBy' | 'expiresAt' | 'acceptedAt' | 'respondedAt' | 'createdAt'>
export function invitationDisplayStatus(row: Pick<DisplayRow, 'status' | 'initiatedBy' | 'expiresAt'>, now: Date): InvitationDisplayStatus | 'withdrawn' {
  if (row.status === 'withdrawn' || row.status === 'accepted' || row.status === 'rejected') return row.status
  if (row.status === 'expired' || (row.status === 'pending' && row.expiresAt !== null && row.expiresAt < now)) return 'expired'
  return row.initiatedBy === 'member' ? 'requested' : 'sent'
}
export function invitationDisplayDate(row: DisplayRow, now: Date): Date {
  switch (invitationDisplayStatus(row, now)) {
    case 'accepted': return row.acceptedAt ?? row.respondedAt ?? row.createdAt
    case 'rejected': return row.respondedAt ?? row.createdAt
    case 'expired': return row.expiresAt ?? row.createdAt
    default: return row.createdAt
  }
}

/** Never pass a creator ID: a resource creator alone cannot expand organization access. */
export async function getInvitationOrganizations(userId: string, db: Db = prisma) {
  const user = await db.user.findUnique({ where: { id: userId }, select: { isSuperAdmin: true } })
  return db.organization.findMany({
    where: user?.isSuperAdmin ? {} : { OR: [{ ownerId: userId }, { userRoles: { some: { userId } } }] },
    select: { id: true, name: true }, orderBy: [{ name: 'asc' }, { id: 'asc' }],
  })
}

const projectedRelations = {
  group: { select: { id: true, name: true, coverImageUrl: true, organizationId: true } },
  inviter: { select: { name: true } },
} satisfies Prisma.InvitationInclude

/** Group transfers change access immediately; stored org is authoritative only for generic rows. */
export function effectiveInvitationOrganization(row: Pick<Invitation, 'groupId' | 'organizationId'> & { group: { organizationId: string } | null }): string | null {
  const organizationId = row.groupId === null ? row.organizationId : row.group?.organizationId
  return organizationId && UUID.test(organizationId) ? organizationId.toLowerCase() : null
}

/** Supply authorized, existing organization IDs; use this inside the caller's transaction. */
export function invitationOrganizationScope(orgIds: string[]): Prisma.InvitationWhereInput {
  return { OR: [
    { groupId: null, organizationId: { in: orgIds } },
    { group: { organizationId: { in: orgIds, mode: 'insensitive' } } },
  ] }
}

async function invitationFilterOptions(orgs: { id: string; name: string }[]): Promise<InvitationFeed['filters']> {
  const orgIds = orgs.map(org => org.id)
  if (!orgIds.length) return { orgs: [], groups: [], leaders: [] }
  const [groups, leaders] = await Promise.all([
    prisma.group.findMany({ where: { organizationId: { in: orgIds, mode: 'insensitive' } }, select: { id: true, name: true, organizationId: true }, orderBy: [{ name:'asc' }, { id:'asc' }] }),
    prisma.user.findMany({
      where: { OR: [
        { ownedOrganization: { id: { in: orgIds } } },
        { roles: { some: { organizationId: { in: orgIds } } } },
        { createdGroups: { some: { organizationId: { in: orgIds, mode: 'insensitive' } } } },
        { sentInvitations: { some: { AND: [invitationOrganizationScope(orgIds), { initiatedBy: 'leader' }] } } },
      ] }, select: { id:true, name:true }, orderBy: [{ name:'asc' }, { id:'asc' }],
    }),
  ])
  return { orgs, groups: groups.map(group => ({ ...group, organizationId: group.organizationId.toLowerCase() })), leaders }
}

export async function getInvitationFeed(userId: string, filters: InvitationFeedFilters = {}, now = new Date()): Promise<InvitationFeed> {
  const orgs = await getInvitationOrganizations(userId)
  const orgIds = orgs.map(org => org.id)
  const options = await invitationFilterOptions(orgs)
  if (!orgIds.length) return { items: [], total: 0, filters: options }
  // Group.organizationId is a historical free string: compare text, never cast it to UUID.
  const organization = Prisma.sql`CASE WHEN i."groupId" IS NULL THEN i."organizationId"::text ELSE lower(g."organizationId") END`
  const predicates: Prisma.Sql[] = [Prisma.sql`(${organization}) IN (${Prisma.join(orgIds)})`, Prisma.sql`i.status <> 'withdrawn'`]
  if (filters.orgId) predicates.push(Prisma.sql`(${organization}) = ${filters.orgId}`)
  if (filters.groupId) predicates.push(Prisma.sql`i."groupId" = ${filters.groupId}::uuid`)
  if (filters.leaderId) {
    const groups = await prisma.group.findMany({ where: { AND: [{ organizationId: { in: orgIds, mode: 'insensitive' } }, await groupManageFilter(filters.leaderId)] }, select: { id:true } })
    const requests = groups.length ? Prisma.sql`i."groupId" IN (${Prisma.join(groups.map(group => Prisma.sql`${group.id}::uuid`))})` : Prisma.sql`FALSE`
    predicates.push(Prisma.sql`((i."initiatedBy" = 'leader' AND i."inviterId" = ${filters.leaderId}::uuid) OR (i."initiatedBy" = 'member' AND ${requests}))`)
  }
  // Compute both status and date in SQL before applying the requested status, order and cap.
  // The branches mirror the total mapping helpers used by detail projections.
  const status = Prisma.sql`CASE WHEN i.status IN ('accepted','rejected','expired') THEN i.status WHEN i.status = 'pending' AND i."expiresAt" < ${now} THEN 'expired' WHEN i."initiatedBy" = 'member' THEN 'requested' ELSE 'sent' END`
  const date = Prisma.sql`CASE WHEN i.status = 'accepted' THEN COALESCE(i."acceptedAt",i."respondedAt",i."createdAt") WHEN i.status = 'rejected' THEN COALESCE(i."respondedAt",i."createdAt") WHEN i.status = 'expired' OR (i.status = 'pending' AND i."expiresAt" < ${now}) THEN COALESCE(i."expiresAt",i."createdAt") ELSE i."createdAt" END`
  const cte = Prisma.sql`WITH matching AS (SELECT i.id, ${status} AS "displayStatus", ${date} AS "displayDate" FROM invitations i LEFT JOIN groups g ON g.id = i."groupId" WHERE ${Prisma.join(predicates, ' AND ')})`
  const statusFilter = filters.status ? Prisma.sql`WHERE "displayStatus" = ${filters.status}` : Prisma.empty
  return prisma.$transaction(async tx => {
    const [ids, counts] = await Promise.all([
      tx.$queryRaw<{ id: string }[]>(Prisma.sql`${cte} SELECT id FROM matching ${statusFilter} ORDER BY "displayDate" DESC, id DESC LIMIT ${Math.min(filters.limit ?? 200, 200)}`),
      tx.$queryRaw<{ total: bigint }[]>(Prisma.sql`${cte} SELECT count(*) AS total FROM matching ${statusFilter}`),
    ])
    const rows = await tx.invitation.findMany({ where: { AND: [invitationOrganizationScope(orgIds), { id: { in: ids.map(row => row.id) } }] }, include: projectedRelations })
    const byId = new Map(rows.map(row => [row.id, row]))
    const items: InvitationFeedItem[] = ids.flatMap(({ id }) => {
      const row = byId.get(id)
      if (!row) return []
      const organizationId = effectiveInvitationOrganization(row)
      if (!organizationId || !orgIds.includes(organizationId)) return []
      const group = row.group
      return [{ id: row.id, kind: invitationKind(row), status: invitationDisplayStatus(row, now) as InvitationDisplayStatus,
        recipientPhone: row.recipientPhone, recipientName: row.recipientName, memberId: row.memberId,
        groupId: row.groupId, groupName: group?.name ?? null, organizationId,
        inviterId: row.inviterId, inviterName: row.inviter?.name ?? null, date: invitationDisplayDate(row, now).toISOString(), createdAt: row.createdAt.toISOString() }]
    })
    return { items, total: Number(counts[0].total), filters: options }
  }, { isolationLevel: 'RepeatableRead' })
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const eventTypes: InvitationEventType[] = ['sent','resent','link_clicked','accepted','withdrawn','expired','requested','approved','rejected']
function memberAge(birthday: Date | null, now: Date): number | null {
  if (!birthday || !Number.isFinite(birthday.getTime()) || birthday > now) return null
  const beforeBirthday = now.getUTCMonth() < birthday.getUTCMonth() || (now.getUTCMonth() === birthday.getUTCMonth() && now.getUTCDate() < birthday.getUTCDate())
  return now.getUTCFullYear() - birthday.getUTCFullYear() - (beforeBirthday ? 1 : 0)
}

export async function getInvitationDetail(userId: string, invitationId: string, now = new Date()): Promise<InvitationDetail> {
  if (!UUID.test(invitationId)) throw new InvitationReadError(404, 'Invitation not found')
  const orgIds = (await getInvitationOrganizations(userId)).map(org => org.id)
  return prisma.$transaction(async tx => {
    const selected = await tx.invitation.findUnique({ where: { id: invitationId.toLowerCase() }, include: projectedRelations })
    if (!selected) throw new InvitationReadError(404, 'Invitation not found')
    const organizationId = effectiveInvitationOrganization(selected)
    if (!organizationId || !orgIds.includes(organizationId)) throw new InvitationReadError(403, 'Forbidden')
    const rows = await tx.invitation.findMany({
      where: { AND: [invitationOrganizationScope(orgIds), selected.recipientPhone === null ? { id: selected.id } : { recipientPhone: selected.recipientPhone }] },
      include: projectedRelations,
    })
    rows.sort((a,b) => invitationDisplayDate(b,now).getTime() - invitationDisplayDate(a,now).getTime() || b.id.localeCompare(a.id))
    const events = await tx.inviteEvent.findMany({ where: { invitationId: { in: rows.map(row => row.id) }, type: { in: eventTypes } }, orderBy: [{ at:'desc' }, { id:'desc' }] })
    const historicalGroupIds = [...new Set(events.flatMap(event => event.groupId && UUID.test(event.groupId) ? [event.groupId.toLowerCase()] : []))]
    const historicalGroups = await tx.group.findMany({ where: { id: { in: historicalGroupIds }, organizationId: { in: orgIds, mode: 'insensitive' } }, select: { id:true, name:true } })
    const groupNames = new Map(historicalGroups.map(group => [group.id, group.name]))
    const normalizedPhone = selected.recipientPhone ? normalizePhone(selected.recipientPhone) : null
    const linked = selected.memberId
      ? await tx.member.findUnique({ where: { id: selected.memberId } })
      : normalizedPhone ? await tx.member.findFirst({ where: { phoneNumber: normalizedPhone, organizations: { some: { organizationId } } } }) : null
    let member: InvitationDetail['member'] = null
    if (linked) {
      const [groupMembership, orgMembership] = await Promise.all([
        selected.group ? tx.groupMember.findFirst({ where: { groupId:selected.group.id, memberId:linked.id, isActive:true }, select: { role:true, joinedAt:true } }) : null,
        tx.memberOrganization.findUnique({ where: { memberId_organizationId: { memberId:linked.id, organizationId } }, select: { joinedAt:true } }),
      ])
      member = { id:linked.id, name:[linked.firstName,linked.lastName].filter(Boolean).join(' ').trim() || linked.phoneNumber,
        picture:linked.profilePicture, age:memberAge(linked.birthday,now), role:groupMembership?.role ?? null,
        birthday:linked.birthday?.toISOString() ?? null, joinedAt:(groupMembership?.joinedAt ?? orgMembership?.joinedAt)?.toISOString() ?? null }
    }
    const eligible = rows.filter(row => row.initiatedBy === 'leader' && row.status === 'pending' && row.recipientPhone !== null)
    return {
      id:selected.id, kind:invitationKind(selected), status:invitationDisplayStatus(selected,now), recipientPhone:selected.recipientPhone,
      recipientName:selected.recipientName, inviterName:selected.inviter?.name ?? null, message:selected.message, createdAt:selected.createdAt.toISOString(), member,
      invitations:rows.map(row => {
        const group = row.group
        return { id:row.id, kind:invitationKind(row), groupId:row.groupId, groupName:group?.name ?? null, groupPicture:group?.coverImageUrl ?? null, status:invitationDisplayStatus(row,now), date:invitationDisplayDate(row,now).toISOString() }
      }),
      events:events.map(event => ({ id:event.id, type:event.type as InvitationEventType, at:event.at.toISOString(), groupId:event.groupId, groupName:event.groupId ? groupNames.get(event.groupId.toLowerCase()) ?? null : null, invitationId:event.invitationId })),
      canResend:selected.recipientPhone !== null && eligible.some(row => row.expiresAt === null || row.expiresAt >= now),
      canWithdraw:selected.recipientPhone !== null && eligible.length > 0,
    }
  }, { isolationLevel: 'RepeatableRead' })
}

const actionRelations = {
  group: { select: { id: true, organizationId: true, name: true, code: true } },
  inviter: { select: { name: true } },
  member: { select: { phoneNumber: true } },
} satisfies Prisma.InvitationInclude
type ActionRow = Prisma.InvitationGetPayload<{ include: typeof actionRelations }>

async function actionSelection(tx: Db, userId: string, id: string, now: Date, resend: boolean) {
  if (!UUID.test(id)) throw new InvitationReadError(404, 'Invitation not found')
  const selected = await tx.invitation.findUnique({ where: { id: id.toLowerCase() }, include: actionRelations })
  if (!selected) throw new InvitationReadError(404, 'Invitation not found')
  const orgIds = (await getInvitationOrganizations(userId, tx)).map(org => org.id)
  const orgId = effectiveInvitationOrganization(selected)
  if (!orgId || !orgIds.includes(orgId)) throw new InvitationReadError(403, 'Forbidden')
  if (selected.recipientPhone === null) throw new InvitationReadError(409, 'No eligible invitations')
  const rows = await tx.invitation.findMany({ where: { AND: [invitationOrganizationScope(orgIds), {
    recipientPhone: selected.recipientPhone, initiatedBy: 'leader', status: 'pending',
    ...(resend ? { OR: [{ expiresAt: null }, { expiresAt: { gte: now } }] } : {}),
  }] }, include: actionRelations, orderBy: { id: 'asc' } })
  return { selected, rows }
}

/** Match lifecycle order, then freeze group organization against the existing group PATCH. */
async function lockActionRows(tx: Db, rows: ActionRow[]) {
  const people = new Map<string, { groupId: string; phone: string }>()
  for (const row of rows) {
    const phone = row.initiatedBy === 'member' ? row.member?.phoneNumber ?? row.recipientPhone : row.recipientPhone
    if (row.groupId && phone) people.set(JSON.stringify([row.groupId, normalizePhone(phone) ?? phone]), { groupId: row.groupId, phone })
  }
  for (const [, person] of [...people].sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0)) await lockInvitationPerson(tx, person.groupId, person.phone)
  for (const id of [...new Set(rows.map(row => row.id))].sort()) await lockInvitationRow(tx, id)
  const groupIds = [...new Set(rows.flatMap(row => row.groupId ? [row.groupId] : []))].sort()
  if (groupIds.length) await tx.$queryRaw(Prisma.sql`SELECT id FROM groups WHERE id IN (${Prisma.join(groupIds.map(id => Prisma.sql`${id}::uuid`))}) ORDER BY id FOR SHARE`)
}

export async function withdrawInvitations(userId: string, invitationId: string, now = new Date()): Promise<InvitationDetail> {
  await withInvitationTransaction(async tx => {
    const initial = await actionSelection(tx, userId, invitationId, now, false)
    await lockActionRows(tx, [initial.selected, ...initial.rows])
    const current = await actionSelection(tx, userId, invitationId, now, false)
    if (!current.rows.length) throw new InvitationReadError(409, 'No eligible invitations')
    for (const row of current.rows) {
      await tx.invitation.update({ where: { id: row.id, initiatedBy: 'leader', status: 'pending' }, data: { status: 'withdrawn' } })
      await recordEvent(tx, { invitationId: row.id, type: 'withdrawn', at: now, actorId: userId, groupId: row.groupId })
    }
  })
  return getInvitationDetail(userId, invitationId)
}

export async function resendInvitations(userId: string, invitationId: string, now = new Date(), baseUrl = process.env.CLIENT_URL): Promise<InvitationDetail> {
  const initial = await withInvitationTransaction(tx => actionSelection(tx, userId, invitationId, now, true))
  if (!initial.rows.length) throw new InvitationReadError(409, 'No eligible invitations')
  if (!baseUrl || initial.rows.some(row => !row.token || !row.recipientPhone || !normalizePhone(row.recipientPhone))) throw new InvitationReadError(502, 'Invitation cannot be resent')
  const messages = initial.rows.map(row => ({
    templateSlug: 'group-invite-v1', recipientPhone: normalizePhone(row.recipientPhone!)!, sentById: userId,
    context: { 'inviter.name': row.inviter?.name ?? 'A leader', 'group.name': row.group?.name ?? 'MakeReady',
      joinUrl: row.group?.code ? `${baseUrl}/join/group/${row.group.code}?invite=${row.token}` : `${baseUrl}/join/group?invite=${row.token}` },
    metadata: { inviteId: row.id, groupId: row.groupId },
  }))
  // The whole batch is outside retries: an accepted provider delivery cannot roll back.
  let delivered = false
  try { delivered = (await sendCampaignSmsBatch(messages)).success } catch { /* map campaign/storage failure without leaking provider details */ }
  if (!delivered) throw new InvitationReadError(502, 'Unable to resend invitations')
  await withInvitationTransaction(async tx => {
    await lockActionRows(tx, [initial.selected, ...initial.rows])
    const current = await actionSelection(tx, userId, invitationId, new Date(Math.max(now.getTime(), Date.now())), true)
    const sent = new Map(initial.rows.map(row => [row.id, row]))
    const eligible = current.rows.filter(row => {
      const original = sent.get(row.id)
      return original && original.token === row.token && original.recipientPhone === row.recipientPhone
    })
    if (!eligible.length) throw new InvitationReadError(409, 'No eligible invitations')
    for (const row of eligible) {
      await tx.invitation.update({ where: { id: row.id, initiatedBy: 'leader', status: 'pending' }, data: { expiresAt: new Date(now.getTime() + 7 * 86400000) } })
      await recordEvent(tx, { invitationId: row.id, type: 'resent', at: now, actorId: userId, groupId: row.groupId })
    }
  })
  return getInvitationDetail(userId, invitationId)
}
