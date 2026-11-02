import { toLegacyInvite, toLegacyJoinRequest } from '../../src/services/invitation.js'
import type { PrismaClient } from '../../src/generated/prisma/index.js'
import type { Express } from 'express'
import type { Server } from 'node:http'
import request from 'supertest'
export { assertInvitationTestDatabase } from './invitations-migration-db.js'

export const legacyId = (n: number) => `a1100000-0000-4000-8000-${String(n).padStart(12, '0')}`
export const LEGACY_DATE = new Date('2025-01-02T03:04:05.000Z')

export async function seedLegacyInvitationCases(prisma: PrismaClient) {
  const leader = await prisma.user.create({ data: { id: legacyId(1), email: 'legacy-leader@example.invalid', name: 'Legacy Leader', createdAt: LEGACY_DATE, updatedAt: LEGACY_DATE } })
  const outsider = await prisma.user.create({ data: { id: legacyId(2), email: 'legacy-outsider@example.invalid', name: 'Outsider', createdAt: LEGACY_DATE, updatedAt: LEGACY_DATE } })
  const org = await prisma.organization.create({ data: { id: legacyId(3), name: 'Legacy Organization', ownerId: leader.id, createdAt: LEGACY_DATE, updatedAt: LEGACY_DATE } })
  const group = await prisma.group.create({ data: { id: legacyId(4), name: 'Legacy Group', code: 'LGACY1', description: 'A legacy group', creatorId: leader.id, organizationId: org.id, createdAt: LEGACY_DATE, updatedAt: LEGACY_DATE } })
  const members = []
  for (let n = 0; n < 7; n++) members.push(await prisma.member.create({ data: { id: legacyId(10 + n), phoneNumber: `+1202555010${n}`, firstName: `Member ${n}`, lastName: n ? 'Legacy' : null, createdAt: LEGACY_DATE, updatedAt: LEGACY_DATE } }))
  // Legacy activity writes use the member ID as a User actor FK. Supply those
  // identities so the genuine activity path can reach the mocked push boundary.
  for (const member of members) await prisma.user.create({ data: { id: member.id, email: `${member.id}@example.invalid`, name: member.firstName!, createdAt: LEGACY_DATE, updatedAt: LEGACY_DATE } })
  // Existing phone-user keeps verification acceptance deterministic, without mocking its storage.
  await prisma.user.create({ data: { id: legacyId(5), email: 'legacy-phone@example.invalid', name: 'Phone User', phoneNumber: members[6].phoneNumber, phoneVerified: true, createdAt: LEGACY_DATE, updatedAt: LEGACY_DATE } })
  const invites: Record<string, ReturnType<typeof toLegacyInvite>> = {}
  for (const [n, kind] of ['pending', 'accepted', 'storedExpired', 'timeExpired', 'nullGroup', 'nullPhone', 'unresolvedOrg', 'verification'].entries()) {
    invites[kind] = toLegacyInvite(await prisma.invitation.create({ data: {
      initiatedBy: 'leader', organizationId: kind === 'unresolvedOrg' ? null : org.id,
      id: legacyId(30 + n), token: `LEGACY000${n}`, inviterId: kind === 'unresolvedOrg' ? outsider.id : leader.id,
      groupId: ['nullGroup', 'unresolvedOrg'].includes(kind) ? null : group.id,
      recipientPhone: kind === 'nullPhone' ? null : kind === 'verification' ? members[6].phoneNumber : `+1202555020${n}`,
      recipientName: n % 2 ? null : `Recipient ${n}`,
      status: kind === 'accepted' ? 'accepted' : kind === 'storedExpired' ? 'expired' : 'pending',
      createdAt: new Date(LEGACY_DATE.getTime() + n * 1000),
      expiresAt: kind === 'timeExpired' ? new Date('2020-01-01T00:00:00Z') : ['nullGroup', 'nullPhone', 'unresolvedOrg', 'storedExpired'].includes(kind) ? null : new Date('2099-01-01T00:00:00Z'),
      acceptedAt: kind === 'accepted' ? new Date('2025-02-01T00:00:00Z') : null,
    } }))
  }
  const requests: Record<string, ReturnType<typeof toLegacyJoinRequest>> = {}
  for (const [n, status] of ['pending', 'approved', 'rejected'].entries()) requests[status] = toLegacyJoinRequest(await prisma.invitation.create({ data: {
    initiatedBy: 'member', organizationId: org.id, recipientPhone: members[n].phoneNumber,
    id: legacyId(50 + n), groupId: group.id, memberId: members[n].id, status: status === 'approved' ? 'accepted' : status,
    message: n === 0 ? null : `${status} message`, createdAt: new Date(LEGACY_DATE.getTime() + n * 1000),
    updatedAt: new Date('2025-03-01T00:00:00Z'), respondedById: n ? leader.id : null, respondedAt: n ? new Date('2025-02-02T00:00:00Z') : null,
  } }))
  return { leader, outsider, org, group, members, invites, requests }
}

/** Test-only session creation; all subsequent HTTP calls use real Passport/member auth. */
export function installLegacyAuthHelpers(app: Express, prisma: PrismaClient) {
  app.post('/__legacy-test/session', async (req, res, next) => {
    if (req.body.memberId) { req.session.memberId = req.body.memberId; return res.json({ success: true }) }
    const user = await prisma.user.findUniqueOrThrow({ where: { id: req.body.userId } })
    req.login(user, error => error ? next(error) : res.json({ success: true }))
  })
}

export async function legacyAgent(app: Express | Server, identity: { userId: string } | { memberId: string }) {
  const agent = request.agent(app)
  const response = await agent.post('/__legacy-test/session').send(identity)
  if (response.status !== 200) throw new Error(`Session helper failed: ${response.status}`)
  return agent
}

export interface GeneratedScalar { value: string; persisted: unknown; alias: string; kind: 'id' | 'token' | 'clock' }
export function captureLegacyResponse(response: { status: number; body: unknown }, generated: GeneratedScalar[] = []) {
  const aliases = new Map<string, string>()
  for (const scalar of generated) {
    const actual = scalar.persisted instanceof Date ? scalar.persisted.toISOString() : scalar.persisted
    if (scalar.value !== actual || !scalar.value || !/^<[^>]+>$/.test(scalar.alias)) throw new Error('Generated scalar must match its persisted row')
    if (scalar.kind === 'id' && !/^[a-f\d-]{36}$/i.test(scalar.value)) throw new Error('Invalid generated UUID')
    if (scalar.kind === 'token' && !/^(?:[A-Z\d]{10}|[a-f\d]{32})$/.test(scalar.value)) throw new Error('Invalid generated token')
    if (scalar.kind === 'clock' && (!Number.isFinite(Date.parse(scalar.value)) || Date.parse(scalar.value) < Date.parse('2026-01-01'))) throw new Error('Invalid generated clock')
    if (aliases.has(scalar.value) && aliases.get(scalar.value) !== scalar.alias) throw new Error('Ambiguous scalar alias')
    aliases.set(scalar.value, scalar.alias)
  }
  const walk = (value: unknown): unknown => {
    if (typeof value === 'string') {
      if (aliases.has(value)) return aliases.get(value)
      // The only embedded generated scalar is the persisted invite token in a URL.
      for (const scalar of generated.filter(s => s.kind === 'token')) {
        if (value.endsWith(`?invite=${scalar.value}`) && /^https?:\/\//.test(value)) return value.slice(0, -scalar.value.length) + scalar.alias
      }
      return value
    }
    return Array.isArray(value) ? value.map(walk) : value && typeof value === 'object' ? Object.fromEntries(Object.entries(value).map(([key, v]) => [key, walk(v)])) : value
  }
  return { status: response.status, body: walk(response.body) }
}

export async function readLegacyInvite(prisma: PrismaClient, id: string) {
  return toLegacyInvite(await prisma.invitation.findUniqueOrThrow({ where: { id, initiatedBy: 'leader' } }))
}
export async function readLegacyRequest(prisma: PrismaClient, id: string) {
  return toLegacyJoinRequest(await prisma.invitation.findUniqueOrThrow({ where: { id, initiatedBy: 'member' } }))
}
