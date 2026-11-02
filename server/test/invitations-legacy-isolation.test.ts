import request from 'supertest'
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'
import { assertInvitationTestDatabase, installLegacyAuthHelpers, legacyAgent, legacyId, seedLegacyInvitationCases } from './helpers/invitations-legacy-fixtures.js'

// The actual app calls dotenv.config() at import; the lease supplies its environment.
vi.mock('dotenv', () => ({ default: { config: vi.fn(() => ({})) } }))

// No invitation repository/service is mocked. Only outbound transports are replaced.
vi.mock('../src/services/sms-campaign.js', () => ({ sendCampaignSms: vi.fn(async () => ({ success: true, messageSid: 'legacy-test-sms' })) }))
vi.mock('../src/services/push-notification.js', () => ({ sendToUser: vi.fn(async () => ({})), sendToDevice: vi.fn(async () => ({})), isPushConfigured: () => false, shutdown: vi.fn() }))
vi.mock('../src/services/twilio.js', async importOriginal => {
  const original = await importOriginal<typeof import('../src/services/twilio.js')>()
  return { ...original, verifyCode: vi.fn(async () => ({ success: true, valid: true })), sendVerificationCode: vi.fn(async () => ({ success: true })) }
})
// Tripwires: even an accidental bypass of a service mock cannot reach a provider.
vi.mock('twilio', () => ({ default: vi.fn(() => { throw new Error('Live Twilio transport attempted') }) }))
vi.mock('@parse/node-apn', () => ({ default: { Provider: vi.fn(() => { throw new Error('Live push transport attempted') }) } }))

const leased = assertInvitationTestDatabase(process.env.TEST_DATABASE_URL)
if (process.env.DATABASE_URL !== leased || process.env.DIRECT_URL !== leased) throw new Error('Database URL mismatch')
const { prisma } = await import('../src/lib/prisma.js')
const { app } = await import('../src/index.js')
installLegacyAuthHelpers(app, prisma)

let fixture: Awaited<ReturnType<typeof seedLegacyInvitationCases>>
async function cleanup() {
  const ids = Array.from({ length: 60 }, (_, n) => legacyId(n))
  // Restrict deletion to this fixture's identities; never truncate shared tables.
  await prisma.$executeRaw`DELETE FROM session WHERE sess->>'memberId' = ANY(${ids}::text[]) OR sess->'passport'->>'user' = ANY(${ids}::text[])`
  await prisma.activityLog.deleteMany({ where: { OR: [{ userId: { in: ids } }, { memberId: { in: ids } }, { groupId: legacyId(4) }] } })
  await prisma.group.deleteMany({ where: { id: legacyId(4) } })
  await prisma.member.deleteMany({ where: { id: { in: ids } } })
  await prisma.organization.deleteMany({ where: { id: legacyId(3) } })
  await prisma.user.deleteMany({ where: { id: { in: ids } } })
}
beforeAll(async () => { await cleanup() })
beforeEach(async () => { await cleanup(); fixture = await seedLegacyInvitationCases(prisma); vi.clearAllMocks() })
afterAll(async () => { await cleanup(); await prisma.$disconnect() })

describe('merged storage preserves legacy endpoint boundaries', () => {
  it('rejects IDs and tokens from the other relationship kind even with misleading identity fields', async () => {
    const { leader, group, members, invites, requests } = fixture
    const user = await legacyAgent(app, { userId: leader.id })
    await prisma.invitation.update({ where: { id: requests.pending.id }, data: { token: 'MEMBER_TOKEN', inviterId: leader.id } })
    await prisma.invitation.update({ where: { id: invites.pending.id }, data: { memberId: members[3].id } })
    for (const method of ['patch', 'delete'] as const) {
      const response = await user[method](`/api/invites/${requests.pending.id}`).send({ status: 'expired' })
      expect(response.status).toBe(404)
      expect(response.body).toEqual({ success: false, error: 'Invite not found' })
    }
    for (const action of ['approve', 'reject']) {
      const response = await user.post(`/api/groups/${group.id}/join-requests/${invites.pending.id}/${action}`).send({})
      expect(response.status).toBe(404)
      expect(response.body).toEqual({ success: false, error: 'Pending request not found' })
    }
    expect((await request(app).get('/api/invites/MEMBER_TOKEN')).status).toBe(404)
    const { acceptInvite } = await import('../src/services/invite.js')
    expect(await acceptInvite(requests.pending.id, leader.id)).toEqual({ success: false, error: 'Invite not found' })
    expect((await prisma.invitation.findUniqueOrThrow({ where: { id: requests.pending.id } })).status).toBe('pending')
    expect((await prisma.invitation.findUniqueOrThrow({ where: { id: invites.pending.id } })).status).toBe('pending')
    expect((await user.get('/api/invites')).body.invites.map((row: { id: string }) => row.id)).not.toContain(requests.pending.id)
    const list = await user.get(`/api/groups/${group.id}/join-requests`)
    expect(list.status).toBe(200)
    expect(list.body.requests.map((row: { id: string }) => row.id)).toEqual([requests.pending.id])
    const member = await legacyAgent(app, { memberId: members[3].id })
    expect((await member.get(`/api/groups/${group.id}/join-requests/me`)).body).toEqual({ success: true, status: 'none' })
    const { createApiKeyForUser } = await import('./helpers/api-auth.js')
    const admin = await createApiKeyForUser(leader.id)
    const adminList = await request(app).get('/api/admin/join-requests').set('Authorization', `Bearer ${admin.token}`)
    expect(adminList.status, JSON.stringify(adminList.body)).toBe(200)
    expect(adminList.body.requests.map((row: { id: string }) => row.id)).toEqual([requests.pending.id])
    for (const status of ['accepted', 'withdrawn']) {
      const response = await user.get(`/api/groups/${group.id}/join-requests`).query({ status })
      expect(response.body.requests).toEqual([])
    }
  })

  it('resolves generic organizations without selecting an arbitrary association', async () => {
    const { resolveLegacyInvitationOrganization } = await import('../src/services/invitation.js')
    const { leader, outsider, org, group } = fixture
    expect(await resolveLegacyInvitationOrganization(null, outsider.id)).toBeNull()
    expect(await resolveLegacyInvitationOrganization(null, leader.id)).toBe(org.id)
    const second = await prisma.organization.create({ data: { name: 'Second org', ownerId: outsider.id } })
    const role = await prisma.role.create({ data: { name: 'Second org role', organizationId: second.id } })
    await prisma.userRole.create({ data: { userId: leader.id, roleId: role.id, organizationId: second.id } })
    try {
      expect(await resolveLegacyInvitationOrganization(null, leader.id)).toBeNull()
      expect(await resolveLegacyInvitationOrganization(group.id, leader.id)).toBe(org.id)
      await prisma.user.update({ where: { id: leader.id }, data: { organizationId: second.id } })
      expect(await resolveLegacyInvitationOrganization(null, leader.id)).toBe(second.id)
      await prisma.user.update({ where: { id: leader.id }, data: { organizationId: 'obsolete-not-a-uuid' } })
      expect(await resolveLegacyInvitationOrganization(null, leader.id)).toBeNull()
    } finally { await prisma.organization.delete({ where: { id: second.id } }) }
  })
})
