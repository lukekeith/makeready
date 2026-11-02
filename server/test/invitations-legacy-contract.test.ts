import request from 'supertest'
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'
import { assertInvitationTestDatabase, captureLegacyResponse, installLegacyAuthHelpers, legacyAgent, legacyId, seedLegacyInvitationCases, type GeneratedScalar } from './helpers/invitations-legacy-fixtures.js'
import { withInvitationMigrationDb } from './helpers/invitations-migration-db.js'

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
const { sendCampaignSms } = await import('../src/services/sms-campaign.js')
const { verifyCode } = await import('../src/services/twilio.js')
const { default: liveTwilio } = await import('twilio')
const { default: livePush } = await import('@parse/node-apn')
installLegacyAuthHelpers(app, prisma)

let fixture: Awaited<ReturnType<typeof seedLegacyInvitationCases>>
let generated: GeneratedScalar[]
function alias(row: Record<string, unknown>, fields: string[], label: string) {
  for (const key of fields) {
    const persisted = row[key]
    if (persisted === null || persisted === undefined) continue
    const kind = persisted instanceof Date ? 'clock' : key === 'token' ? 'token' : 'id'
    const value = persisted instanceof Date ? persisted.toISOString() : String(persisted)
    // The same DB clock can occur in multiple newly generated fields.
    generated.push({ value, persisted, kind, alias: kind === 'clock' ? '<generated clock>' : `<${label}.${key}>` })
  }
}
function snap(response: request.Response, status = 200) {
  expect(response.status).toBe(status)
  expect(captureLegacyResponse(response, generated)).toMatchSnapshot()
}
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
beforeEach(async () => { await cleanup(); fixture = await seedLegacyInvitationCases(prisma); generated = []; vi.clearAllMocks() })
afterAll(async () => { await cleanup(); await prisma.$disconnect() })

describe('old-schema invitation HTTP contracts (immutable baseline)', () => {
  it('legacy contracts capture complete bodies', async () => {
    const { leader, outsider, group, invites, requests, members } = fixture
    const user = await legacyAgent(app, { userId: leader.id })
    const other = await legacyAgent(app, { userId: outsider.id })
    snap(await user.get('/api/invites'))
    for (const status of ['pending', 'accepted', 'expired']) snap(await user.get('/api/invites').query({ groupId: group.id, status }))
    snap(await other.get('/api/invites')) // unresolved organization, null group
    const generic = await user.post('/api/invites').send({})
    const genericRow = await prisma.invite.findUniqueOrThrow({ where: { id: generic.body.invite.id } })
    alias(genericRow, ['id', 'token', 'createdAt'], 'generic')
    snap(generic)
    expect(generic.body.invite.groupId).toBeNull()
    expect(generic.body.invite.expiresAt).toBeNull()
    const scoped = await user.post('/api/invites').send({ groupId: group.id, expiresAt: '2099-01-01T00:00:00.000Z' })
    alias(await prisma.invite.findUniqueOrThrow({ where: { id: scoped.body.invite.id } }), ['id', 'token', 'createdAt'], 'scoped')
    snap(scoped)
    const sent = await user.post('/api/invites/send').send({ groupId: group.id, recipientPhone: '+12025550300', recipientName: '  Sent Person  ' })
    const sentRow = await prisma.invite.findUniqueOrThrow({ where: { id: sent.body.inviteId } })
    alias(sentRow, ['id', 'token', 'createdAt', 'expiresAt'], 'sent')
    // URLs embed a generated token; verify against storage before normalizing that scalar.
    expect(sent.body.inviteUrl).toBe(`${process.env.CLIENT_URL}/join/group/${group.code}?invite=${sentRow.token}`)
    snap(sent)
    expect(sendCampaignSms).toHaveBeenCalledWith(expect.objectContaining({ context: expect.objectContaining({ joinUrl: sent.body.inviteUrl }) }))
    snap(await user.patch(`/api/invites/${invites.pending.id}`).send({ status: 'expired', expiresAt: null }))
    snap(await user.patch(`/api/invites/${invites.pending.id}`).send({ status: 'pending' }))
    snap(await user.delete(`/api/invites/${genericRow.id}`))

    for (const status of ['pending', 'approved', 'rejected']) {
      snap(await user.get(`/api/groups/${group.id}/join-requests`).query({ status }))
      const member = await legacyAgent(app, { memberId: requests[status].memberId })
      snap(await member.get(`/api/groups/${group.id}/join-requests/me`))
      snap(await member.get(`/api/groups/code/${group.code}`))
    }
    // The real inline index.ts admin handler, including raw storage fields.
    const { createApiKeyForUser } = await import('./helpers/api-auth.js')
    const admin = await createApiKeyForUser(leader.id)
    for (const status of ['pending', 'approved', 'rejected']) {
      const response = await request(app).get('/api/admin/join-requests').set('Authorization', `Bearer ${admin.token}`).query({ status })
      snap(response)
      expect(Object.keys(response.body).sort()).toEqual(['count', 'requests', 'success'])
      expect(response.body.requests[0]).toHaveProperty('updatedAt', requests[status].updatedAt.toISOString())
      expect(response.body.requests[0].status).toBe(status)
    }
    const newMember = await legacyAgent(app, { memberId: members[3].id })
    snap(await newMember.get(`/api/groups/${group.id}/join-requests/me`))
    const submitted = await newMember.post(`/api/groups/${group.id}/join-requests`).send({ message: 'Please let me join' })
    alias(await prisma.groupJoinRequest.findUniqueOrThrow({ where: { id: submitted.body.request.id } }), ['id', 'createdAt'], 'submitted')
    snap(submitted, 201)
    snap(await newMember.post(`/api/groups/${group.id}/join-requests`).send({}), 400)
    const approvedResponse = await user.post(`/api/groups/${group.id}/join-requests/${requests.pending.id}/approve`).send({})
    alias(await prisma.groupJoinRequest.findUniqueOrThrow({ where: { id: requests.pending.id } }), ['reviewedAt', 'updatedAt'], 'approved')
    expect(Object.keys(approvedResponse.body).sort()).toEqual(['member', 'request', 'success'])
    snap(approvedResponse)
    const approved = await prisma.groupJoinRequest.findUniqueOrThrow({ where: { id: requests.pending.id } })
    const adminApproved = await request(app).get('/api/admin/join-requests').set('Authorization', `Bearer ${admin.token}`).query({ status: 'approved' })
    snap(adminApproved)
    const rawApproved = adminApproved.body.requests.find((row: { id: string }) => row.id === approved.id)
    expect(rawApproved).toHaveProperty('updatedAt', approved.updatedAt.toISOString())
    expect(rawApproved.reviewedById).toBe(leader.id)
    expect(rawApproved.status).toBe('approved')
    const membership = await prisma.groupMember.findFirstOrThrow({ where: { memberId: members[0].id, groupId: group.id } })
    alias(membership, ['id', 'joinedAt'], 'membership')
    const approvedMember = await legacyAgent(app, { memberId: members[0].id })
    snap(await approvedMember.get(`/api/groups/${group.id}/join-requests/me`))
    snap(await approvedMember.get(`/api/groups/code/${group.code}`))
    snap(await approvedMember.post(`/api/groups/${group.id}/join-requests`).send({}), 400)
    const rejectedResponse = await user.post(`/api/groups/${group.id}/join-requests/${submitted.body.request.id}/reject`).send({ reason: 'Not yet' })
    alias(await prisma.groupJoinRequest.findUniqueOrThrow({ where: { id: submitted.body.request.id } }), ['reviewedAt', 'updatedAt'], 'rejected')
    expect(Object.keys(rejectedResponse.body).sort()).toEqual(['request', 'success'])
    snap(rejectedResponse)
    expect(liveTwilio).not.toHaveBeenCalled()
    expect(livePush.Provider).not.toHaveBeenCalled()
  })

  it('public token data stays whitelisted and landing HTML stays complete', async () => {
    for (const invite of Object.values(fixture.invites)) {
      const lookup = await request(app).get(`/api/invites/${invite.token}`)
      snap(lookup, ['accepted', 'timeExpired'].includes(Object.keys(fixture.invites).find(key => fixture.invites[key].id === invite.id)!) ? 404 : 200)
      if (lookup.body.invite) expect(lookup.body.invite).not.toHaveProperty('recipientName')
      const landing = await request(app).get(`/join/${invite.token}`)
      expect(landing.status).toBe(200)
      expect({ status: landing.status, contentType: landing.type, html: landing.text }).toMatchSnapshot()
    }
    snap(await request(app).get('/api/invites/UNKNOWN'), 404)
    const missing = await request(app).get('/join/UNKNOWN')
    expect({ status: missing.status, html: missing.text }).toMatchSnapshot()
  })

  it('embedded member confirmation and verification acceptance retain complete JSON', async () => {
    const { group, members, requests, invites } = fixture
    for (const member of [members[0], members[4]]) {
      const response = await request(app).post('/api/members/confirm-verification').send({ phoneNumber: member.phoneNumber, code: '123456', groupId: group.id })
      const persisted = await prisma.member.findUniqueOrThrow({ where: { id: member.id } })
      alias(persisted, ['updatedAt', 'lastVerifiedAt'], 'verifiedMember')
      if (member.id === members[4].id) alias(await prisma.groupJoinRequest.findUniqueOrThrow({ where: { id: response.body.joinRequest.id } }), ['id', 'createdAt', 'updatedAt'], 'confirmedRequest')
      else expect(response.body.joinRequest.id).toBe(requests.pending.id)
      snap(response)
    }
    const accepted = await request(app).post('/api/verification/verify').send({ phoneNumber: members[6].phoneNumber, code: '123456', inviteToken: invites.verification.token })
    snap(accepted)
    expect((await prisma.invite.findUniqueOrThrow({ where: { id: invites.verification.id } })).status).toBe('accepted')
    expect(verifyCode).toHaveBeenCalled()
    expect(liveTwilio).not.toHaveBeenCalled()
    expect(livePush.Provider).not.toHaveBeenCalled()
  })

  it('pending invite auto-join and optional send-name envelopes retain complete JSON', async () => {
    const { group, members, invites, leader } = fixture
    const member = await legacyAgent(app, { memberId: members[6].id })
    snap(await member.post(`/api/groups/${group.id}/join-requests`).send({ message: 'Invited' }), 201)
    expect((await prisma.invite.findUniqueOrThrow({ where: { id: invites.verification.id } })).status).toBe('accepted')
    expect(await prisma.groupJoinRequest.count({ where: { groupId: group.id, memberId: members[6].id } })).toBe(0)
    expect(await prisma.groupMember.count({ where: { groupId: group.id, memberId: members[6].id, isActive: true } })).toBe(1)
    const user = await legacyAgent(app, { userId: leader.id })
    const sent = await user.post('/api/invites/send').send({ groupId: group.id, recipientPhone: '+12025550301' })
    const row = await prisma.invite.findUniqueOrThrow({ where: { id: sent.body.inviteId } })
    alias(row, ['id', 'token', 'createdAt', 'expiresAt'], 'unnamedSent')
    expect(row.recipientName).toBeNull()
    expect(sent.body.inviteUrl).toBe(`${process.env.CLIENT_URL}/join/group/${group.code}?invite=${row.token}`)
    snap(sent)
    vi.mocked(sendCampaignSms).mockResolvedValueOnce({ success: false, error: 'Mock campaign rejected' })
    const before = await prisma.invite.count({ where: { inviterId: leader.id } })
    snap(await user.post('/api/invites/send').send({ groupId: group.id, recipientPhone: '+12025550302' }), 400)
    expect(await prisma.invite.count({ where: { inviterId: leader.id } })).toBe(before)
    expect(sendCampaignSms).toHaveBeenCalled()
    expect(liveTwilio).not.toHaveBeenCalled()
    expect(livePush.Provider).not.toHaveBeenCalled()
  })

  it('original unauthorized and forbidden HTTP envelopes remain exact', async () => {
    const { group, invites, requests, outsider } = fixture
    for (const method of ['get', 'post'] as const) snap(await request(app)[method]('/api/invites').send({}), 401)
    snap(await request(app).post('/api/invites/send').send({}), 401)
    for (const method of ['patch', 'delete'] as const) snap(await request(app)[method](`/api/invites/${invites.pending.id}`).send({}), 401)
    snap(await request(app).post(`/api/groups/${group.id}/join-requests`).send({}), 401)
    snap(await request(app).get(`/api/groups/${group.id}/join-requests/me`), 401)
    snap(await request(app).get(`/api/groups/${group.id}/join-requests`), 401)
    for (const decision of ['approve', 'reject']) snap(await request(app).post(`/api/groups/${group.id}/join-requests/${requests.pending.id}/${decision}`).send({}), 401)
    snap(await request(app).get('/api/admin/join-requests'), 401)
    const other = await legacyAgent(app, { userId: outsider.id })
    snap(await other.post('/api/invites').send({ groupId: group.id }), 403)
    snap(await other.post('/api/invites/send').send({ groupId: group.id, recipientPhone: '+12025550300' }), 403)
    for (const method of ['patch', 'delete'] as const) snap(await other[method](`/api/invites/${invites.pending.id}`).send({}), 403)
    snap(await other.get(`/api/groups/${group.id}/join-requests`), 404)
    for (const decision of ['approve', 'reject']) snap(await other.post(`/api/groups/${group.id}/join-requests/${requests.pending.id}/${decision}`).send({}), 404)
    snap(await other.get('/api/admin/join-requests'), 403)
  })
})

describe('separate mutable D14 characterization and migration safety', () => {
  it('old rerequest behavior is characterized separately (no immutable snapshot)', async () => {
    const { group, requests } = fixture
    const member = await legacyAgent(app, { memberId: requests.rejected.memberId })
    const response = await member.post(`/api/groups/${group.id}/join-requests`).send({ message: 'Again' })
    expect(response.status).toBe(201)
    expect(response.body.request.id).toBe(requests.rejected.id)
    expect(response.body.request.createdAt).toBe(requests.rejected.createdAt.toISOString())
    expect(response.body.request.status).toBe('pending')
    const row = await prisma.groupJoinRequest.findUniqueOrThrow({ where: { id: requests.rejected.id } })
    expect(row.reviewedAt).toBeNull()
    expect(row.reviewedById).toBeNull()
    // The confirmation route historically also resets a rejected row. Keep
    // this intentionally changing D14 rule outside the frozen wire snapshots.
    await prisma.groupJoinRequest.update({ where: { id: row.id }, data: { status: 'rejected', reviewedById: fixture.leader.id, reviewedAt: new Date('2025-02-02T00:00:00Z') } })
    const confirmed = await request(app).post('/api/members/confirm-verification').send({ phoneNumber: fixture.members[2].phoneNumber, code: '123456', groupId: group.id })
    expect(confirmed.status).toBe(200)
    expect(confirmed.body.joinRequest.id).toBe(row.id)
    expect(confirmed.body.joinRequest.reviewedById).toBeNull()
    expect(confirmed.body.wasNewRequest).toBe(true)
  })

  it('scratch harness fails closed and replays only the old committed schema', async () => {
    for (const url of [undefined, 'postgresql://postgres:postgres@localhost:5434/makeready_dev', 'postgresql://postgres:postgres@remote:5434/postgres_vt_1_2', 'postgresql://postgres:postgres@localhost:5434/postgres_vt_tpl_abc_b_1', `${leased}?schema=other`]) expect(() => assertInvitationTestDatabase(url)).toThrow()
    expect(() => captureLegacyResponse({ status: 200, body: { id: 'bad' } }, [{ value: 'bad', persisted: 'different', alias: '<id>', kind: 'id' }])).toThrow()
    let ownedUrl = ''
    await withInvitationMigrationDb(async url => {
      ownedUrl = url
      const { Client } = await import('pg')
      const client = new Client({ connectionString: url })
      await client.connect()
      try {
        const result = await client.query("SELECT to_regclass('invites')::text AS invites, to_regclass('group_join_requests')::text AS requests, to_regclass('invitations')::text AS merged")
        expect(result.rows).toEqual([{ invites: 'invites', requests: 'group_join_requests', merged: null }])
      } finally { await client.end() }
    })
    const name = new URL(ownedUrl).pathname.slice(1)
    expect(await prisma.$queryRaw`SELECT datname FROM pg_database WHERE datname = ${name}`).toEqual([])
    await expect(withInvitationMigrationDb(async () => { throw new Error('callback failure') })).rejects.toThrow('callback failure')
  }, 120_000)
})
