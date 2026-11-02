import { startInvitationHttpServer, stopInvitationHttpServer, type InvitationHttpServer } from './helpers/invitations-http.js'
import request from 'supertest'
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'
import { assertInvitationTestDatabase, installLegacyAuthHelpers, legacyAgent, legacyId, seedLegacyInvitationCases } from './helpers/invitations-legacy-fixtures.js'

// The actual app calls dotenv.config() at import; the lease supplies its environment.
vi.mock('dotenv', () => ({ default: { config: vi.fn(() => ({})) } }))

// No invitation repository/service is mocked. Only outbound transports are replaced.
vi.mock('../src/services/activity.js', () => ({ trackActivity: vi.fn() }))
vi.mock('../src/services/push-notification.js', () => ({ sendToUser: vi.fn(async () => ({})), sendToDevice: vi.fn(async () => ({})), isPushConfigured: () => false, shutdown: vi.fn() }))
vi.mock('../src/services/twilio.js', async importOriginal => {
  const original = await importOriginal<typeof import('../src/services/twilio.js')>()
  return { ...original, sendSMS: vi.fn(async () => ({ success: true, messageSid: 'mock-sid' })), verifyCode: vi.fn(async () => ({ success: true, valid: true })), sendVerificationCode: vi.fn(async () => ({ success: true })) }
})
// Tripwires: even an accidental bypass of a service mock cannot reach a provider.
vi.mock('twilio', () => ({ default: vi.fn(() => { throw new Error('Live Twilio transport attempted') }) }))
vi.mock('@parse/node-apn', () => ({ default: { Provider: vi.fn(() => { throw new Error('Live push transport attempted') }) } }))

vi.stubEnv('CLIENT_URL', 'https://example.invalid')
const leased = assertInvitationTestDatabase(process.env.TEST_DATABASE_URL)
if (process.env.DATABASE_URL !== leased || process.env.DIRECT_URL !== leased) throw new Error('Database URL mismatch')
const { prisma } = await import('../src/lib/prisma.js')
const { app } = await import('../src/index.js')
installLegacyAuthHelpers(app, prisma)
let httpServer: InvitationHttpServer

const { sendSMS } = await import('../src/services/twilio.js')
const { seedSmsCampaigns } = await import('../src/services/sms-campaign-seed.js')
let fixture: Awaited<ReturnType<typeof seedLegacyInvitationCases>>
async function cleanup() {
  const ids = Array.from({ length: 60 }, (_, n) => legacyId(n))
  await prisma.smsLog.deleteMany({ where: { recipientPhone: { startsWith: '+12025550' } } })
  // Restrict deletion to this fixture's identities; never truncate shared tables.
  await prisma.$executeRaw`DELETE FROM session WHERE sess->>'memberId' = ANY(${ids}::text[]) OR sess->'passport'->>'user' = ANY(${ids}::text[])`
  await prisma.activityLog.deleteMany({ where: { OR: [{ userId: { in: ids } }, { memberId: { in: ids } }, { groupId: legacyId(4) }] } })
  // Some nullable mapping fixtures have no cascading group/member/inviter relation.
  // Delete our org's rows before its SetNull relation can orphan them across suites.
  await prisma.invitation.deleteMany({ where: { organizationId: legacyId(3) } })
  await prisma.group.deleteMany({ where: { id: legacyId(4) } })
  await prisma.member.deleteMany({ where: { id: { in: ids } } })
  await prisma.organization.deleteMany({ where: { id: legacyId(3) } })
  await prisma.user.deleteMany({ where: { id: { in: ids } } })
}
beforeAll(async () => { httpServer = await startInvitationHttpServer(app); await cleanup() })
beforeEach(async () => { await cleanup(); fixture = await seedLegacyInvitationCases(prisma); vi.mocked(sendSMS).mockReset().mockResolvedValue({ success: true, messageSid: 'mock-sid' }); await seedSmsCampaigns(prisma) })
afterAll(async () => { try { await cleanup() } finally { vi.unstubAllEnvs(); await stopInvitationHttpServer(httpServer); await prisma.$disconnect() } })


const id = (n: number) => `a5500000-0000-4000-8000-${String(n).padStart(12, '0')}`
async function sibling() {
  return prisma.invitation.create({ data: { id: id(1), initiatedBy: 'leader', organizationId: fixture.org.id,
    groupId: fixture.group.id, inviterId: fixture.leader.id, token: 'SIBLING_TOKEN', recipientPhone: fixture.invites.pending.recipientPhone,
    expiresAt: new Date('2099-01-01'), status: 'pending' } })
}
const barrier = () => { let release!: () => void; const wait = new Promise<void>(resolve => { release = resolve }); return { wait, release } }

describe('managed invitation mutations', () => {
  it('resends same-phone eligible invitations with their original tokens and seven-day expiry', async () => {
    const other = await sibling()
    const user = await legacyAgent(httpServer, { userId: fixture.leader.id })
    const started = Date.now()
    const response = await user.post(`/api/invitations/${fixture.invites.pending.id}/resend`).send({})
    expect(response.status, JSON.stringify(response.body)).toBe(200)
    expect(response.body.id).toBe(fixture.invites.pending.id)
    expect(sendSMS).toHaveBeenCalledTimes(2)
    const bodies = vi.mocked(sendSMS).mock.calls.map(call => call[1])
    for (const token of [fixture.invites.pending.token, other.token]) expect(bodies.some(body => body.includes(`https://example.invalid/join/group/LGACY1?invite=${token}`))).toBe(true)
    const rows = await prisma.invitation.findMany({ where: { id: { in: [fixture.invites.pending.id, other.id] } } })
    expect(new Set(rows.map(row => row.expiresAt!.getTime())).size).toBe(1)
    for (const row of rows) expect(row.expiresAt!.getTime()).toBeGreaterThanOrEqual(started + 7 * 86400000)
    const events = await prisma.inviteEvent.findMany({ where: { invitationId: { in: rows.map(row => row.id) } } })
    expect(events.map(row => row.type)).toEqual(['resent', 'resent'])
    expect(events.every(row => row.actorId === fixture.leader.id)).toBe(true)
    expect(response.body.events.map((row: any) => row.type)).toEqual(['resent', 'resent'])
    expect((await user.post(`/api/invitations/${fixture.invites.pending.id}/resend`).send({})).status).toBe(502)
    expect(sendSMS).toHaveBeenCalledTimes(2)
  })
  it('returns502 on second-send failure with all invitation fields/events unchanged and factual logs', async () => {
    const other = await sibling()
    const ids = [fixture.invites.pending.id, other.id]
    const before = await prisma.invitation.findMany({ where: { id: { in: ids } }, orderBy: { id: 'asc' } })
    vi.mocked(sendSMS).mockResolvedValueOnce({ success: true, messageSid: 'first-sent' }).mockResolvedValueOnce({ success: false, error: 'Injected second failure' })
    const user = await legacyAgent(httpServer, { userId: fixture.leader.id })
    const response = await user.post(`/api/invitations/${ids[0]}/resend`).send({})
    expect(response.status).toBe(502)
    expect(response.body).toEqual({ error: 'Unable to resend invitations' })
    expect(await prisma.invitation.findMany({ where: { id: { in: ids } }, orderBy: { id: 'asc' } })).toEqual(before)
    expect(await prisma.inviteEvent.count({ where: { invitationId: { in: ids } } })).toBe(0)
    expect((await prisma.smsLog.findMany({ where: { recipientPhone: before[0].recipientPhone! }, orderBy: { createdAt: 'asc' } })).map(row => row.status)).toEqual(['SENT', 'FAILED'])
  })

  it('withdraws expired pending siblings atomically but never accepted/member/foreign-org rows', async () => {
    const other = await sibling()
    const phone = fixture.invites.pending.recipientPhone!
    await prisma.invitation.updateMany({ where: { id: { in: [fixture.invites.timeExpired.id, fixture.invites.accepted.id, fixture.requests.pending.id] } }, data: { recipientPhone: phone } })
    const foreignOrg = await prisma.organization.create({ data: { id: id(2), name: 'Other Org', ownerId: fixture.outsider.id } })
    const foreignGroup = await prisma.group.create({ data: { id: id(3), name: 'Other Group', organizationId: foreignOrg.id, creatorId: fixture.outsider.id } })
    const foreign = await prisma.invitation.create({ data: { id: id(4), initiatedBy: 'leader', groupId: foreignGroup.id, organizationId: foreignOrg.id, inviterId: fixture.outsider.id, token: 'FOREIGN_TOKEN', recipientPhone: phone } })
    const untouchedIds = [fixture.invites.accepted.id, fixture.requests.pending.id, foreign.id]
    const untouched = await prisma.invitation.findMany({ where: { id: { in: untouchedIds } }, orderBy: { id: 'asc' } })
    const user = await legacyAgent(httpServer, { userId: fixture.leader.id })
    const response = await user.post(`/api/invitations/${fixture.invites.pending.id.toUpperCase()}/withdraw`).send({})
    expect(response.status, JSON.stringify(response.body)).toBe(200)
    expect(response.body).toMatchObject({ status: 'withdrawn', canWithdraw: false, canResend: false })
    const changedIds = [fixture.invites.pending.id, fixture.invites.timeExpired.id, other.id]
    expect(await prisma.invitation.count({ where: { id: { in: changedIds }, status: 'withdrawn' } })).toBe(3)
    expect(await prisma.inviteEvent.count({ where: { invitationId: { in: changedIds }, type: 'withdrawn', actorId: fixture.leader.id } })).toBe(3)
    expect(await prisma.invitation.findMany({ where: { id: { in: untouchedIds } }, orderBy: { id: 'asc' } })).toEqual(untouched)
    expect((await request(httpServer).get(`/api/invites/${fixture.invites.pending.token}`)).status).toBe(404)
    expect((await user.post(`/api/invitations/${fixture.invites.pending.id}/withdraw`).send({})).status).toBe(409)
  })

  it('authenticates selected identity before expansion and rejects null phone or absent eligibility', async () => {
    const user = await legacyAgent(httpServer, { userId: fixture.leader.id })
    const outsider = await legacyAgent(httpServer, { userId: fixture.outsider.id })
    const member = await legacyAgent(httpServer, { memberId: fixture.members[0].id })
    const { createApiKeyForUser } = await import('./helpers/api-auth.js')
    const apiKey = await createApiKeyForUser(fixture.outsider.id)
    for (const action of ['resend', 'withdraw']) {
      const unauthenticated = await request(httpServer).post(`/api/invitations/${fixture.invites.pending.id}/${action}`).send({})
      expect(unauthenticated.status, `${action}: ${unauthenticated.text}`).toBe(401)
      expect((await outsider.post(`/api/invitations/${fixture.invites.pending.id}/${action}`)).status).toBe(403)
      expect((await member.post(`/api/invitations/${fixture.invites.pending.id}/${action}`)).status).toBe(401)
      expect((await request(httpServer).post(`/api/invitations/${fixture.invites.pending.id}/${action}`).set('Authorization', `Bearer ${apiKey.token}`)).status).toBe(403)
      expect((await user.post(`/api/invitations/malformed/${action}`)).status).toBe(404)
      expect((await user.post(`/api/invitations/${id(999)}/${action}`)).status).toBe(404)
      expect((await user.post(`/api/invitations/${fixture.invites.nullPhone.id}/${action}`)).status).toBe(409)
      expect((await user.post(`/api/invitations/${fixture.invites.accepted.id}/${action}`)).status).toBe(409)
      expect((await user.post(`/api/invitations/${fixture.invites.unresolvedOrg.id}/${action}`)).status).toBe(403)
    }
    expect((await user.post(`/api/invitations/${fixture.invites.timeExpired.id}/resend`)).status).toBe(409)
    expect(sendSMS).not.toHaveBeenCalled()
    expect(await prisma.inviteEvent.count({ where: { invitationId: fixture.invites.nullPhone.id } })).toBe(0)
  })

  it('leaves invitation state unchanged when recipient consent denies resend', async () => {
    await prisma.invitation.update({ where: { id: fixture.invites.pending.id }, data: { recipientPhone: fixture.members[0].phoneNumber } })
    await prisma.member.update({ where: { id: fixture.members[0].id }, data: { smsConsent: false } })
    const before = await prisma.invitation.findUniqueOrThrow({ where: { id: fixture.invites.pending.id } })
    const user = await legacyAgent(httpServer, { userId: fixture.leader.id })
    expect((await user.post(`/api/invitations/${before.id}/resend`)).status).toBe(502)
    expect(await prisma.invitation.findUniqueOrThrow({ where: { id: before.id } })).toEqual(before)
    expect(await prisma.inviteEvent.count({ where: { invitationId: before.id } })).toBe(0)
    expect(sendSMS).not.toHaveBeenCalled()
  })

  it('never overwrites withdrawal while resend is delivering', async () => {
    const entered = barrier(), finish = barrier()
    vi.mocked(sendSMS).mockImplementationOnce(async () => { entered.release(); await finish.wait; return { success: true, messageSid: 'raced-sent' } })
    const user = await legacyAgent(httpServer, { userId: fixture.leader.id })
    const sending = user.post(`/api/invitations/${fixture.invites.pending.id}/resend`).send({}).then(response => response)
    await Promise.race([entered.wait, sending.then(response => { throw new Error(`Resend ended before transport barrier: ${response.status} ${JSON.stringify(response.body)}`) })])
    try { expect((await user.post(`/api/invitations/${fixture.invites.pending.id}/withdraw`).send({})).status).toBe(200) }
    finally { finish.release() }
    expect((await sending).status).toBe(409)
    expect((await prisma.invitation.findUniqueOrThrow({ where: { id: fixture.invites.pending.id } })).status).toBe('withdrawn')
    expect((await prisma.inviteEvent.findMany({ where: { invitationId: fixture.invites.pending.id } })).map(row => row.type)).toEqual(['withdrawn'])
    expect((await prisma.smsLog.findFirstOrThrow({ where: { recipientPhone: fixture.invites.pending.recipientPhone! } })).status).toBe('SENT')
  })

  it('skips accepted rows after delivery while committing other eligible siblings', async () => {
    const other = await sibling()
    await prisma.invitation.updateMany({ where: { id: { in: [other.id, fixture.invites.pending.id] } }, data: { recipientPhone: fixture.members[3].phoneNumber } })
    await prisma.member.update({ where: { id: fixture.members[3].id }, data: { smsConsent: true } })
    const entered = barrier(), finish = barrier()
    vi.mocked(sendSMS).mockImplementationOnce(async () => { entered.release(); await finish.wait; return { success: true, messageSid: 'raced-sent' } })
    const user = await legacyAgent(httpServer, { userId: fixture.leader.id })
    const sending = user.post(`/api/invitations/${fixture.invites.pending.id}/resend`).send({}).then(response => response)
    await Promise.race([entered.wait, sending.then(response => { throw new Error(`Resend ended before transport barrier: ${response.status} ${JSON.stringify(response.body)}`) })])
    try {
      const { acceptInvite } = await import('../src/services/invite.js')
      expect(await acceptInvite(fixture.invites.pending.id, fixture.leader.id)).toMatchObject({ success: true })
    } finally { finish.release() }
    expect((await sending).status).toBe(200)
    expect((await prisma.invitation.findUniqueOrThrow({ where: { id: fixture.invites.pending.id } })).status).toBe('accepted')
    expect((await prisma.inviteEvent.findMany({ where: { invitationId: fixture.invites.pending.id } })).map(row => row.type)).toEqual(['accepted'])
    expect((await prisma.inviteEvent.findMany({ where: { invitationId: other.id } })).map(row => row.type)).toEqual(['resent'])
  })

  it('rechecks current org after delivery and refuses the former org after a real group transfer', async () => {
    const foreignOrg = await prisma.organization.create({ data: { id: id(2), name: 'Destination', ownerId: fixture.outsider.id } })
    const role = await prisma.role.create({ data: { name: 'Mover', organizationId: foreignOrg.id } })
    const mover = await prisma.user.create({ data: { id: id(5), name: 'Mover', email: 'invite-mover@example.invalid' } })
    const oldRole = await prisma.role.create({ data: { name: 'Source mover', organizationId: fixture.org.id } })
    await prisma.userRole.createMany({ data: [{ userId: mover.id, roleId: role.id, organizationId: foreignOrg.id }, { userId: mover.id, roleId: oldRole.id, organizationId: fixture.org.id }] })
    const entered = barrier(), finish = barrier()
    vi.mocked(sendSMS).mockImplementationOnce(async () => { entered.release(); await finish.wait; return { success: true, messageSid: 'transferred-sent' } })
    const before = await prisma.invitation.findUniqueOrThrow({ where: { id: fixture.invites.pending.id } })
    const oldOwner = await legacyAgent(httpServer, { userId: fixture.leader.id })
    const movingUser = await legacyAgent(httpServer, { userId: mover.id })
    const sending = oldOwner.post(`/api/invitations/${before.id}/resend`).send({}).then(response => response)
    await Promise.race([entered.wait, sending.then(response => { throw new Error(`Resend ended before transport barrier: ${response.status} ${JSON.stringify(response.body)}`) })])
    try {
      const transfer = await movingUser.patch(`/api/groups/${fixture.group.id}`).send({ organizationId: foreignOrg.id })
      expect(transfer.status, JSON.stringify(transfer.body)).toBe(200)
    }
    finally { finish.release() }
    expect((await sending).status).toBe(403)
    expect(await prisma.invitation.findUniqueOrThrow({ where: { id: before.id } })).toEqual(before)
    expect(await prisma.inviteEvent.count({ where: { invitationId: before.id } })).toBe(0)
    expect((await oldOwner.post(`/api/invitations/${before.id}/withdraw`)).status).toBe(403)
    const newOwner = await legacyAgent(httpServer, { userId: fixture.outsider.id })
    expect((await newOwner.post(`/api/invitations/${before.id}/withdraw`)).status).toBe(200)
    await prisma.user.delete({ where: { id: mover.id } })
  })

  it('retries the domain snapshot after a group update wins the final shared-lock boundary', async () => {
    const foreignOrg = await prisma.organization.create({ data: { id: id(2), name: 'Destination', ownerId: fixture.outsider.id } })
    const entered = barrier(), finish = barrier()
    const moving = prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM groups WHERE id::text = ${fixture.group.id} FOR UPDATE`
      entered.release()
      await finish.wait
      await tx.group.update({ where: { id: fixture.group.id }, data: { organizationId: foreignOrg.id } })
    }, { timeout: 10000 })
    await entered.wait
    const user = await legacyAgent(httpServer, { userId: fixture.leader.id })
    const withdrawing = user.post(`/api/invitations/${fixture.invites.pending.id}/withdraw`).send({}).then(response => response)
    try {
      let waiting = false
      for (let attempt = 0; attempt < 100 && !waiting; attempt++) {
        const rows = await prisma.$queryRaw<{ waiting: boolean }[]>`SELECT EXISTS (SELECT 1 FROM pg_stat_activity WHERE datname = current_database() AND wait_event_type = 'Lock' AND query LIKE '%FOR SHARE%') AS waiting`
        waiting = rows[0].waiting
        if (!waiting) await new Promise(resolve => setTimeout(resolve, 10))
      }
      expect(waiting, 'Withdrawal must wait for the group organization lock, not commit using its stale scope').toBe(true)
    } finally { finish.release(); await moving }
    expect((await withdrawing).status).toBe(403)
    expect((await prisma.invitation.findUniqueOrThrow({ where: { id: fixture.invites.pending.id } })).status).toBe('pending')
    expect(await prisma.inviteEvent.count({ where: { invitationId: fixture.invites.pending.id } })).toBe(0)
    expect(sendSMS).not.toHaveBeenCalled()
  })

  it('keeps generic phone-bearing legacy invitations actionable without inventing a group', async () => {
    const user = await legacyAgent(httpServer, { userId: fixture.leader.id })
    const generic = fixture.invites.nullGroup
    const response = await user.post(`/api/invitations/${generic.id}/resend`).send({})
    expect(response.status, JSON.stringify(response.body)).toBe(200)
    expect(vi.mocked(sendSMS).mock.calls[0][1]).toContain(`https://example.invalid/join/group?invite=${generic.token}`)
    expect(response.body.invitations).toEqual([expect.objectContaining({ id: generic.id, groupId: null, groupName: null })])
    expect((await user.post(`/api/invitations/${generic.id}/withdraw`).send({})).status).toBe(200)
  })

  it('resends only eligible leader rows in permitted orgs even when selected through a request', async () => {
    const phone = fixture.invites.pending.recipientPhone!
    const excludedIds = [fixture.invites.timeExpired.id, fixture.invites.accepted.id, fixture.requests.pending.id]
    await prisma.invitation.updateMany({ where: { id: { in: excludedIds } }, data: { recipientPhone: phone } })
    const org = await prisma.organization.create({ data: { id: id(2), name: 'Other Org', ownerId: fixture.outsider.id } })
    const group = await prisma.group.create({ data: { id: id(3), name: 'Other Group', organizationId: org.id, creatorId: fixture.outsider.id } })
    const foreign = await prisma.invitation.create({ data: { id: id(4), initiatedBy: 'leader', groupId: group.id, organizationId: org.id, inviterId: fixture.outsider.id, token: 'FOREIGN_TOKEN', recipientPhone: phone } })
    excludedIds.push(foreign.id)
    const before = await prisma.invitation.findMany({ where: { id: { in: excludedIds } }, orderBy: { id: 'asc' } })
    const user = await legacyAgent(httpServer, { userId: fixture.leader.id })
    expect((await user.post(`/api/invitations/${foreign.id}/resend`).send({})).status).toBe(403)
    expect((await user.post(`/api/invitations/${fixture.requests.pending.id}/resend`).send({})).status).toBe(200)
    expect(sendSMS).toHaveBeenCalledTimes(1)
    expect(await prisma.invitation.findMany({ where: { id: { in: excludedIds } }, orderBy: { id: 'asc' } })).toEqual(before)
    expect(await prisma.inviteEvent.count({ where: { invitationId: { in: excludedIds } } })).toBe(0)
    expect(await prisma.inviteEvent.count({ where: { invitationId: fixture.invites.pending.id, type: 'resent' } })).toBe(1)
  })

})
