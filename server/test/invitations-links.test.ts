import { startInvitationHttpServer, stopInvitationHttpServer, type InvitationHttpServer } from './helpers/invitations-http.js'
import request from 'supertest'
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'
import { assertInvitationTestDatabase, installLegacyAuthHelpers, legacyAgent, legacyId, seedLegacyInvitationCases } from './helpers/invitations-legacy-fixtures.js'

// The actual app calls dotenv.config() at import; the lease supplies its environment.
vi.mock('dotenv', () => ({ default: { config: vi.fn(() => ({})) } }))

// No invitation repository/service is mocked. Only outbound transports are replaced.
vi.mock('../src/services/sms-campaign.js', () => ({ sendCampaignSms: vi.fn(async () => ({ success: true, messageSid: 'legacy-test-sms' })) }))
vi.mock('../src/services/activity.js', () => ({ trackActivity: vi.fn() }))
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
let httpServer: InvitationHttpServer

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
beforeAll(async () => { httpServer = await startInvitationHttpServer(app); await cleanup() })
beforeEach(async () => { await cleanup(); fixture = await seedLegacyInvitationCases(prisma); vi.clearAllMocks() })
afterAll(async () => { try { await cleanup() } finally { await stopInvitationHttpServer(httpServer); await prisma.$disconnect() } })

describe('public invitation history and compatible mutations', () => {
  it('shares click throttle across both routes and leaves expiry state unchanged', async () => {
    const { invites } = fixture
    await Promise.all([request(httpServer).get(`/api/invites/${invites.pending.token}`),request(httpServer).get(`/join/${invites.pending.token}`)])
    const first = await prisma.inviteEvent.findMany({where:{invitationId:invites.pending.id,type:'link_clicked'}})
    expect(first).toHaveLength(1)
    const { recordInvitationLinkClick } = await import('../src/services/invitation.js')
    await recordInvitationLinkClick(invites.pending.id,new Date(first[0].at.getTime()+9*60*1000))
    expect(await prisma.inviteEvent.count({where:{invitationId:invites.pending.id,type:'link_clicked'}})).toBe(1)
    await recordInvitationLinkClick(invites.pending.id,new Date(first[0].at.getTime()+10*60*1000))
    expect(await prisma.inviteEvent.count({where:{invitationId:invites.pending.id,type:'link_clicked'}})).toBe(2)
    const expiredResponse = await request(httpServer).get(`/api/invites/${invites.timeExpired.token}`)
    expect(expiredResponse.status, JSON.stringify(expiredResponse.body)).toBe(404)
    expect((await prisma.invitation.findUniqueOrThrow({where:{id:invites.timeExpired.id}})).status).toBe('pending')
    expect(await prisma.inviteEvent.count({where:{invitationId:invites.timeExpired.id,type:'expired'}})).toBe(0)
    expect((await request(httpServer).get(`/api/invites/${invites.storedExpired.token}`)).status).toBe(200)
    expect((await request(httpServer).get(`/join/${invites.storedExpired.token}`)).text).toContain('Invite Not Found')
  })
  it('records known invalid clicks without leaking fields and does not record unknown or member tokens', async () => {
    const { invites, requests, leader } = fixture
    await prisma.invitation.update({where:{id:invites.pending.id},data:{status:'withdrawn'}})
    const expired = await request(httpServer).get(`/api/invites/${invites.timeExpired.token}`)
    const withdrawn = await request(httpServer).get(`/api/invites/${invites.pending.token}`)
    expect(withdrawn.status).toBe(404)
    expect(withdrawn.body).toEqual(expired.body)
    expect(JSON.stringify(withdrawn.body)).not.toContain('recipient')
    expect((await request(httpServer).get(`/join/${invites.pending.token}`)).text).toContain('Invite Not Found')
    expect(await prisma.inviteEvent.count({where:{invitationId:invites.pending.id,type:'link_clicked'}})).toBe(1)
    await prisma.invitation.update({where:{id:requests.pending.id},data:{token:'MEMBER_PUBLIC_TOKEN',inviterId:leader.id}})
    expect((await request(httpServer).get('/api/invites/MEMBER_PUBLIC_TOKEN')).status).toBe(404)
    expect((await request(httpServer).get('/api/invites/UNKNOWN_TOKEN')).status).toBe(404)
    expect(await prisma.inviteEvent.count({where:{invitationId:requests.pending.id}})).toBe(0)
  })
  it('records only actual terminal PATCH changes, not pending reset or expiry-only edits', async () => {
    const {leader,invites}=fixture
    const user=await legacyAgent(httpServer,{userId:leader.id})
    for(const body of [{status:'expired'},{status:'expired'},{status:'pending'},{expiresAt:null},{status:'accepted'},{status:'accepted'}]) expect((await user.patch(`/api/invites/${invites.pending.id}`).send(body)).status).toBe(200)
    expect((await prisma.inviteEvent.findMany({where:{invitationId:invites.pending.id},orderBy:{at:'asc'}})).map(e=>e.type)).toEqual(['expired','accepted'])
  })
  it('does not record internal token lookups and tolerates deletion racing a public click', async () => {
    const {getInviteByToken}=await import('../src/services/invite.js')
    await getInviteByToken(fixture.invites.pending.token)
    expect(await prisma.inviteEvent.count({where:{invitationId:fixture.invites.pending.id}})).toBe(0)
    const results=await Promise.all([
      request(httpServer).get(`/api/invites/${fixture.invites.pending.token}`),
      prisma.invitation.delete({where:{id:fixture.invites.pending.id}}),
    ])
    expect([200,404]).toContain(results[0].status)
    expect(await prisma.inviteEvent.count({where:{invitationId:fixture.invites.pending.id}})).toBe(0)
  })
  it('records generic creation as sent without changing the phone-less envelope', async () => {
    const user=await legacyAgent(httpServer,{userId:fixture.leader.id})
    const response=await user.post('/api/invites').send({})
    expect(response.status).toBe(200)
    expect(response.body.invite.groupId).toBeNull()
    const row=await prisma.invitation.findUniqueOrThrow({where:{id:response.body.invite.id}})
    expect(row.recipientPhone).toBeNull()
    expect((await prisma.inviteEvent.findMany({where:{invitationId:row.id}})).map(e=>e.type)).toEqual(['sent'])
  })

})
