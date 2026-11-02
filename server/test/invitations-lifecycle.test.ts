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

const { sendCampaignSms } = await import('../src/services/sms-campaign.js')
const { trackActivity } = await import('../src/services/activity.js')

function barrier() {
  let release!: () => void
  const wait = new Promise<void>(resolve => { release = resolve })
  return { wait, release }
}

describe('atomic invitation lifecycle', () => {
  it('serializes duplicate requests and records one request history/notification', async () => {
    const { group, members } = fixture
    const agent = await legacyAgent(app, { memberId: members[3].id })
    const responses = await Promise.all([agent.post(`/api/groups/${group.id}/join-requests`).send({ message: 'Hi' }), agent.post(`/api/groups/${group.id}/join-requests`).send({ message: 'Hi' })])
    expect(responses.map(r => r.status).sort()).toEqual([201,400])
    const rows = await prisma.invitation.findMany({ where: { groupId: group.id, memberId: members[3].id, initiatedBy: 'member' } })
    expect(rows).toHaveLength(1)
    expect(await prisma.inviteEvent.count({ where: { invitationId: rows[0].id, type:'requested' } })).toBe(1)
    expect(await prisma.membershipEvent.count({ where: { memberId: members[3].id, action:'REQUESTED' } })).toBe(1)
    expect(trackActivity).toHaveBeenCalledTimes(1)
  })

  it('has one winner when approve and reject compete', async () => {
    const { leader, group, requests } = fixture
    const agent = await legacyAgent(app, { userId: leader.id })
    const responses = await Promise.all(['approve','reject'].map(action => agent.post(`/api/groups/${group.id}/join-requests/${requests.pending.id}/${action}`).send({ reason:'Later' })))
    expect(responses.map(r => r.status).sort()).toEqual([200,404])
    const row = await prisma.invitation.findUniqueOrThrow({ where: { id: requests.pending.id } })
    expect(await prisma.inviteEvent.count({ where: { invitationId: row.id, type:{in:['approved','rejected']} } })).toBe(1)
    expect(await prisma.membershipEvent.count({ where: { memberId: row.memberId!, action:{in:['APPROVED','REJECTED']} } })).toBe(1)
    expect(await prisma.groupMember.count({ where: { memberId:row.memberId!, groupId:group.id, isActive:true } })).toBe(row.status === 'accepted' ? 1 : 0)
  })

  it('D12 sends a group-code URL then approves the existing request with no second row', async () => {
    const { leader, group, requests, members } = fixture
    const agent = await legacyAgent(app, { userId:leader.id })
    const response = await agent.post('/api/invites/send').send({groupId:group.id,recipientPhone:members[0].phoneNumber})
    expect(response.status).toBe(200)
    expect(response.body).toEqual({ success:true,inviteId:requests.pending.id,inviteUrl:`${process.env.CLIENT_URL}/join/group/${group.code}`,message:'Invite sent successfully' })
    expect(sendCampaignSms).toHaveBeenCalledWith(expect.objectContaining({ context:expect.objectContaining({joinUrl:response.body.inviteUrl}) }))
    expect(await prisma.invitation.count({where:{groupId:group.id,recipientPhone:members[0].phoneNumber}})).toBe(1)
    expect(await prisma.groupMember.count({where:{groupId:group.id,memberId:members[0].id,isActive:true}})).toBe(1)
    expect(await prisma.memberOrganization.count({where:{organizationId:fixture.org.id,memberId:members[0].id}})).toBe(1)
    expect(await prisma.inviteEvent.count({where:{invitationId:requests.pending.id,type:'approved'}})).toBe(1)
  })

  it('D12 failure changes no request and a competing rejection wins during delivery', async () => {
    const { leader, group, requests, members } = fixture
    const agent = await legacyAgent(app, { userId:leader.id })
    vi.mocked(sendCampaignSms).mockResolvedValueOnce({success:false,error:'Mock failure'} as never)
    expect((await agent.post('/api/invites/send').send({groupId:group.id,recipientPhone:members[0].phoneNumber})).status).toBe(400)
    expect((await prisma.invitation.findUniqueOrThrow({where:{id:requests.pending.id}})).status).toBe('pending')
    expect(await prisma.groupMember.count({where:{groupId:group.id,memberId:members[0].id}})).toBe(0)
    const entered = barrier(), finish = barrier()
    vi.mocked(sendCampaignSms).mockImplementationOnce(async () => { entered.release(); await finish.wait; return {success:true} as never })
    const sending = agent.post('/api/invites/send').send({groupId:group.id,recipientPhone:members[0].phoneNumber}).then(r => r)
    await entered.wait
    expect((await agent.post(`/api/groups/${group.id}/join-requests/${requests.pending.id}/reject`).send({})).status).toBe(200)
    finish.release()
    expect((await sending).status).toBe(400)
    expect((await prisma.invitation.findUniqueOrThrow({where:{id:requests.pending.id}})).status).toBe('rejected')
    expect(await prisma.invitation.count({where:{groupId:group.id,recipientPhone:members[0].phoneNumber}})).toBe(1)
  })

  it('request accepts the prepared normal send and failed SMS cannot delete the accepted row', async () => {
    const { leader, group, members } = fixture
    const user = await legacyAgent(app,{userId:leader.id}), member = await legacyAgent(app,{memberId:members[3].id})
    const entered = barrier(), finish = barrier()
    vi.mocked(sendCampaignSms).mockImplementationOnce(async () => { entered.release(); await finish.wait; return {success:false,error:'Mock delivery failure'} as never })
    const sending = user.post('/api/invites/send').send({groupId:group.id,recipientPhone:members[3].phoneNumber}).then(r => r)
    await entered.wait
    const joining = await member.post(`/api/groups/${group.id}/join-requests`).send({})
    finish.release()
    expect(joining.status).toBe(201)
    expect(joining.body).toEqual({success:true,status:'joined'})
    expect((await sending).status).toBe(400)
    const rows = await prisma.invitation.findMany({where:{groupId:group.id,recipientPhone:members[3].phoneNumber}})
    expect(rows).toHaveLength(1)
    expect(rows[0]).toMatchObject({initiatedBy:'leader',status:'accepted'})
    expect(await prisma.inviteEvent.count({where:{invitationId:rows[0].id,type:'accepted'}})).toBe(1)
  })

  it('preserves reviewed history for direct and confirmation requests without adding confirmation hooks', async () => {
    const { group, requests, members } = fixture
    const member = await legacyAgent(app,{memberId:members[2].id})
    const created = await member.post(`/api/groups/${group.id}/join-requests`).send({message:'Again'})
    expect(created.status).toBe(201)
    expect(created.body.request.id).not.toBe(requests.rejected.id)
    expect((await prisma.invitation.findUniqueOrThrow({where:{id:requests.rejected.id}})).status).toBe('rejected')
    expect((await member.get(`/api/groups/${group.id}/join-requests/me`)).body.request.id).toBe(created.body.request.id)
    vi.mocked(trackActivity).mockClear()
    const confirmed = await request(app).post('/api/members/confirm-verification').send({phoneNumber:members[1].phoneNumber,code:'123456',groupId:group.id})
    expect(confirmed.status).toBe(200)
    expect(confirmed.body.wasNewRequest).toBe(true)
    expect(confirmed.body.joinRequest.id).not.toBe(requests.approved.id)
    expect(await prisma.membershipEvent.count({where:{memberId:members[1].id,action:'REQUESTED'}})).toBe(0)
    expect(trackActivity).not.toHaveBeenCalled()
    expect(await prisma.inviteEvent.count({where:{invitationId:confirmed.body.joinRequest.id,type:'requested'}})).toBe(1)
  })
  it('uses one relationship when send and request start together, in either lock order', async () => {
    const user = await legacyAgent(app,{userId:fixture.leader.id})
    for (const [i, member] of fixture.members.slice(3,5).entries()) {
      const agent = await legacyAgent(app,{memberId:member.id})
      const send = () => user.post('/api/invites/send').send({groupId:i ? fixture.group.id.toUpperCase() : fixture.group.id,recipientPhone:member.phoneNumber})
      const submit = () => agent.post(`/api/groups/${fixture.group.id}/join-requests`).send({})
      const responses = await Promise.all(i ? [submit(),send()] : [send(),submit()])
      expect(responses.map(r=>r.status).sort()).toEqual([200,201])
      const rows = await prisma.invitation.findMany({where:{groupId:fixture.group.id,recipientPhone:member.phoneNumber}})
      expect(rows).toHaveLength(1)
      expect(rows[0].status).toBe('accepted')
      expect(await prisma.groupMember.count({where:{groupId:fixture.group.id,memberId:member.id,isActive:true}})).toBe(1)
      expect(await prisma.inviteEvent.count({where:{invitationId:rows[0].id,type:{in:['approved','accepted']}}})).toBe(1)
    }
  })

  it('serializes token acceptance against direct auto-join and reactivates membership', async () => {
    const { acceptInvitationByToken, submitInvitationRequest } = await import('../src/services/invitation.js')
    const { invites, members, group, leader } = fixture
    await prisma.groupMember.create({data:{groupId:group.id,memberId:members[6].id,isActive:false}})
    await Promise.all([acceptInvitationByToken(invites.verification.token,leader.id), submitInvitationRequest(members[6].id,group.id)])
    expect(await prisma.groupMember.count({where:{groupId:group.id,memberId:members[6].id,isActive:true}})).toBe(1)
    expect(await prisma.memberOrganization.count({where:{organizationId:fixture.org.id,memberId:members[6].id}})).toBe(1)
    expect(await prisma.inviteEvent.count({where:{invitationId:invites.verification.id,type:'accepted'}})).toBe(1)
    expect(await prisma.invitation.count({where:{groupId:group.id,memberId:members[6].id,initiatedBy:'member'}})).toBe(0)
  })

  it('rolls back a failed attempt and sends/records only once after retry', async () => {
    const user = await legacyAgent(app,{userId:fixture.leader.id})
    const original = prisma.$transaction.bind(prisma)
    const spy = vi.spyOn(prisma,'$transaction').mockImplementation(original)
    spy.mockImplementationOnce(((work: (tx: unknown) => Promise<unknown>, options: unknown) => original(async tx => { await work(tx); throw Object.assign(new Error('forced serialization conflict'),{code:'P2034'}) }, options as never)) as never)
    try {
      const response = await user.post('/api/invites/send').send({groupId:fixture.group.id,recipientPhone:fixture.members[3].phoneNumber})
      expect(response.status).toBe(200)
      expect(sendCampaignSms).toHaveBeenCalledTimes(1)
      expect(await prisma.invitation.count({where:{groupId:fixture.group.id,recipientPhone:fixture.members[3].phoneNumber}})).toBe(1)
      expect(await prisma.inviteEvent.count({where:{invitationId:response.body.inviteId,type:'sent'}})).toBe(1)
      expect(await prisma.membershipEvent.count({where:{memberId:fixture.members[3].id,action:'INVITED'}})).toBe(1)
      expect(spy).toHaveBeenCalledTimes(3) // prepare rollback + prepare commit + finalize
      spy.mockImplementationOnce(((work: (tx: unknown) => Promise<unknown>, options: unknown) => original(async tx => { await work(tx); throw Object.assign(new Error('forced serialization conflict'),{code:'P2034'}) }, options as never)) as never)
      const member = await legacyAgent(app,{memberId:fixture.members[4].id})
      const submitted = await member.post(`/api/groups/${fixture.group.id}/join-requests`).send({})
      expect(submitted.status).toBe(201)
      expect(trackActivity).toHaveBeenCalledTimes(1)
      expect(await prisma.membershipEvent.count({where:{memberId:fixture.members[4].id,action:'REQUESTED'}})).toBe(1)
      expect(await prisma.inviteEvent.count({where:{invitationId:submitted.body.request.id,type:'requested'}})).toBe(1)
      expect(spy).toHaveBeenCalledTimes(5)
    } finally { spy.mockRestore(); prisma.$transaction = original }
  })

  it('retries at most three times and rolls back each attempt history', async () => {
    const { withInvitationTransaction, recordEvent } = await import('../src/services/invitation.js')
    let attempts=0
    await expect(withInvitationTransaction(async tx => {
      attempts++
      await recordEvent(tx,{invitationId:fixture.invites.pending.id,type:'accepted'})
      throw Object.assign(new Error('forced serialization conflict'),{code:'P2034'})
    })).rejects.toThrow('forced serialization conflict')
    expect(attempts).toBe(3)
    expect(await prisma.inviteEvent.count({where:{invitationId:fixture.invites.pending.id}})).toBe(0)
    expect(sendCampaignSms).not.toHaveBeenCalled()
    expect(trackActivity).not.toHaveBeenCalled()
  })

  it('mints a missing code for D12 and keeps same-clock rerequests newer than history', async () => {
    await prisma.group.update({where:{id:fixture.group.id},data:{code:null}})
    const user=await legacyAgent(app,{userId:fixture.leader.id})
    const sent=await user.post('/api/invites/send').send({groupId:fixture.group.id,recipientPhone:fixture.members[0].phoneNumber})
    const group=await prisma.group.findUniqueOrThrow({where:{id:fixture.group.id}})
    expect(sent.status).toBe(200)
    expect(group.code).toMatch(/^[A-Z2-9]{6}$/)
    expect(sent.body.inviteUrl).toBe(`${process.env.CLIENT_URL}/join/group/${group.code}`)
    const future=new Date(Date.now()+60000)
    await prisma.invitation.update({where:{id:fixture.requests.rejected.id},data:{createdAt:future}})
    const {submitInvitationRequest,findLatestLegacyJoinRequest}=await import('../src/services/invitation.js')
    const result=await submitInvitationRequest(fixture.members[2].id,group.id)
    expect(result.kind).toBe('pending-created')
    const latest=await findLatestLegacyJoinRequest(group.id,fixture.members[2].id)
    expect(latest?.id).not.toBe(fixture.requests.rejected.id)
    expect(latest?.createdAt.getTime()).toBe(future.getTime()+1)
  })

})
