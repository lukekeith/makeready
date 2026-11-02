import { prisma, Prisma } from '../lib/prisma.js'
import type { Invitation } from '../generated/prisma/index.js'
import { normalizePhone } from './member-fields.js'
import { recordMembershipEvent } from './membership-event.js'
import { groupManageFilter } from './permission.js'
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
    if (await tx.groupMember.findFirst({ where: { groupId, memberId, isActive: true } })) return { ...context, kind: 'already-member' as const }
    const invite = await tx.invitation.findFirst({ where: leaderInvitationWhere({ groupId, recipientPhone: member.phoneNumber, status: 'pending' }), orderBy: [{ createdAt: 'desc' }, { id: 'desc' }] })
    if (invite) {
      await lockInvitationRow(tx, invite.id)
      await ensureMembership(tx, groupId, memberId, group.organizationId, false)
      const row = await tx.invitation.update({ where: { id: invite.id, initiatedBy: 'leader', status: 'pending' }, data: { status: 'accepted', acceptedAt: new Date() } })
      await recordEvent(tx, { invitationId: row.id, type: 'accepted', at: row.acceptedAt!, actorId: memberId, groupId })
      return { ...context, kind: 'joined' as const, row }
    }
    const latest = await findLatestLegacyJoinRequest(groupId, memberId, tx)
    if (latest?.status === 'pending') return { ...context, kind: 'duplicate-pending' as const, request: latest }
    const now = new Date()
    const createdAt = latest && latest.createdAt >= now ? new Date(latest.createdAt.getTime() + 1) : now
    const row = await createMemberInvitation({ groupId, memberId, message, createdAt }, tx)
    if (origin === 'direct') await recordMembershipEvent({ memberId, action: 'REQUESTED', groupId, organizationId: group.organizationId, actorId: memberId, actorType: 'member', note: message || null, metadata: { requestId: row.id } }, tx)
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
    if (!await tx.group.findFirst({ where: { id: groupId, ...permission, isActive: true } })) return { kind: 'group-not-found' as const }
    const row = await lockExistingInvitation(tx, requestId, 'member')
    if (!row || row.groupId !== groupId || row.status !== 'pending') return { kind: 'not-pending' as const }
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
