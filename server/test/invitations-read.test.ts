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

const id = (n: number) => `a3300000-0000-4000-8000-${String(n).padStart(12,'0')}`
async function foreignWorld() {
  const owner=await prisma.user.create({data:{id:id(1),name:'Private Owner',email:'private-owner@example.invalid'}})
  const org=await prisma.organization.create({data:{id:id(2),name:'Private Organization',ownerId:owner.id}})
  const group=await prisma.group.create({data:{id:id(3),name:'Private Group',creatorId:owner.id,organizationId:org.id}})
  const row=await prisma.invitation.create({data:{id:id(4),initiatedBy:'leader',inviterId:owner.id,organizationId:org.id,groupId:group.id,token:'PRIVATE_TOKEN',recipientPhone:fixture.invites.pending.recipientPhone}})
  return {owner,org,group,row}
}
async function cleanupForeign() {
  await prisma.group.deleteMany({where:{id:id(3)}})
  await prisma.organization.deleteMany({where:{id:id(2)}})
  await prisma.user.deleteMany({where:{id:{in:[id(1),id(5)]}}})
}
beforeEach(cleanupForeign)
afterAll(cleanupForeign)

describe('managed invitation feed and detail', () => {
  it('emits exact nullable C1 fields, all statuses, deterministic dates and full independent filter options', async () => {
    const user=await legacyAgent(app,{userId:fixture.leader.id})
    const response=await user.get('/api/invitations/feed')
    expect(response.status).toBe(200)
    expect(Object.keys(response.body).sort()).toEqual(['filters','items','total'])
    expect(new Set(response.body.items.map((row:any)=>row.status))).toEqual(new Set(['sent','requested','accepted','rejected','expired']))
    const item=response.body.items.find((row:any)=>row.id===fixture.invites.nullGroup.id)
    expect(item).toEqual({id:fixture.invites.nullGroup.id,kind:'invite',status:'sent',recipientPhone:fixture.invites.nullGroup.recipientPhone,recipientName:fixture.invites.nullGroup.recipientName,memberId:null,groupId:null,groupName:null,organizationId:fixture.org.id,inviterId:fixture.leader.id,inviterName:'Legacy Leader',date:fixture.invites.nullGroup.createdAt.toISOString(),createdAt:fixture.invites.nullGroup.createdAt.toISOString()})
    const filtered=await user.get('/api/invitations/feed').query({status:'rejected',limit:1})
    expect(filtered.body.items).toHaveLength(1)
    expect(filtered.body.filters).toEqual(response.body.filters)
    const keys=Object.keys(item).sort()
    for(const row of response.body.items) expect(Object.keys(row).sort()).toEqual(keys)
  })

  it('scopes rows/options/detail for owners, roles, creators, strangers and super admins', async () => {
    const foreign=await foreignWorld()
    await prisma.group.update({where:{id:foreign.group.id},data:{creatorId:fixture.outsider.id}})
    const owner=await legacyAgent(app,{userId:fixture.leader.id})
    const stranger=await legacyAgent(app,{userId:fixture.outsider.id})
    const own=await owner.get('/api/invitations/feed')
    expect(own.body.items.some((row:any)=>row.id===foreign.row.id)).toBe(false)
    expect(JSON.stringify(own.body.filters)).not.toContain('Private')
    const outOfScope=await owner.get('/api/invitations/feed').query({orgId:foreign.org.id})
    expect(outOfScope.body.items).toEqual([])
    expect(outOfScope.body.total).toBe(0)
    expect(outOfScope.body.filters).toEqual(own.body.filters)
    expect((await stranger.get('/api/invitations/feed')).body).toEqual({items:[],total:0,filters:{orgs:[],groups:[],leaders:[]}})
    expect((await stranger.get(`/api/invitations/${foreign.row.id}`)).status).toBe(403)
    const role=await prisma.role.create({data:{name:'Invite Read Role',organizationId:fixture.org.id}})
    await prisma.userRole.create({data:{userId:fixture.outsider.id,roleId:role.id,organizationId:fixture.org.id}})
    expect((await stranger.get(`/api/invitations/${fixture.invites.pending.id}`)).status).toBe(200)
    await prisma.user.update({where:{id:fixture.outsider.id},data:{isSuperAdmin:true}})
    const all=await stranger.get('/api/invitations/feed')
    expect(all.body.items.some((row:any)=>row.id===foreign.row.id)).toBe(true)
    expect(all.body.items.some((row:any)=>row.id===fixture.invites.unresolvedOrg.id)).toBe(false)
    expect((await stranger.get(`/api/invitations/${fixture.invites.unresolvedOrg.id}`)).status).toBe(403)
  })

  it('filters and sorts display dates before limiting and reports total before the 200 cap', async () => {
    await prisma.invitation.deleteMany({where:{organizationId:fixture.org.id}})
    await prisma.invitation.createMany({data:Array.from({length:201},(_,i)=>({id:id(100+i),initiatedBy:'leader',organizationId:fixture.org.id,inviterId:fixture.leader.id,groupId:fixture.group.id,status:i===0?'accepted':'pending',createdAt:new Date('2020-01-01'),acceptedAt:i===0?new Date('2025-12-01'):null}))})
    const user=await legacyAgent(app,{userId:fixture.leader.id})
    const all=await user.get('/api/invitations/feed')
    expect(all.body.items).toHaveLength(200)
    expect(all.body.total).toBe(201)
    expect(all.body.items[0].id).toBe(id(100))
    expect(all.body.items[1].id).toBe(id(300))
    const filtered=await user.get('/api/invitations/feed').query({status:'sent',limit:1})
    expect(filtered.body.total).toBe(200)
    expect(filtered.body.items.map((row:any)=>row.id)).toEqual([id(300)])
  })

  it('matches sender invites and requests in a leader-managed group and canonicalizes uppercase filters', async () => {
    const user=await legacyAgent(app,{userId:fixture.leader.id})
    const role=await prisma.role.create({data:{name:'Co Leader',organizationId:fixture.org.id}})
    await prisma.userRole.create({data:{userId:fixture.outsider.id,roleId:role.id,organizationId:fixture.org.id}})
    const response=await user.get('/api/invitations/feed').query({orgId:fixture.org.id.toUpperCase(),groupId:fixture.group.id.toUpperCase(),leaderId:fixture.outsider.id.toUpperCase()})
    expect(response.status).toBe(200)
    expect(response.body.items.map((row:any)=>row.id).sort()).toEqual(Object.values(fixture.requests).map(row=>row.id).sort())
    expect(response.body.filters.leaders).toContainEqual({id:fixture.outsider.id,name:'Outsider'})
    expect((await user.get(`/api/invitations/${fixture.invites.pending.id.toUpperCase()}`)).body.id).toBe(fixture.invites.pending.id)
  })

  it('scopes phone history/events/group names and emits exact nullable C2 fields', async () => {
    const foreign=await foreignWorld()
    const selected=fixture.invites.pending
    const sibling=await prisma.invitation.create({data:{initiatedBy:'leader',inviterId:fixture.leader.id,organizationId:fixture.org.id,recipientPhone:selected.recipientPhone,status:'withdrawn',createdAt:new Date('2025-06-01')}})
    await prisma.inviteEvent.createMany({data:[{id:id(50),invitationId:selected.id,type:'sent',at:new Date('2025-01-02'),groupId:fixture.group.id,actorId:fixture.leader.id,metadata:{private:'hidden'}},{id:id(51),invitationId:sibling.id,type:'withdrawn',at:new Date('2025-06-02'),groupId:foreign.group.id},{id:id(52),invitationId:sibling.id,type:'resent',at:new Date('2025-06-03'),groupId:'deleted-history-id'},{id:id(53),invitationId:foreign.row.id,type:'sent',at:new Date('2025-06-04'),groupId:foreign.group.id}]})
    const user=await legacyAgent(app,{userId:fixture.leader.id})
    const response=await user.get(`/api/invitations/${selected.id}`)
    expect(response.status).toBe(200)
    expect(response.body).toEqual({id:selected.id,kind:'invite',status:'sent',recipientPhone:selected.recipientPhone,recipientName:selected.recipientName,inviterName:'Legacy Leader',message:null,createdAt:selected.createdAt.toISOString(),member:null,invitations:[{id:sibling.id,kind:'invite',groupId:null,groupName:null,groupPicture:null,status:'withdrawn',date:sibling.createdAt.toISOString()},{id:selected.id,kind:'invite',groupId:fixture.group.id,groupName:'Legacy Group',groupPicture:null,status:'sent',date:selected.createdAt.toISOString()}],events:[{id:id(52),type:'resent',at:'2025-06-03T00:00:00.000Z',groupId:'deleted-history-id',groupName:null,invitationId:sibling.id},{id:id(51),type:'withdrawn',at:'2025-06-02T00:00:00.000Z',groupId:foreign.group.id,groupName:null,invitationId:sibling.id},{id:id(50),type:'sent',at:'2025-01-02T00:00:00.000Z',groupId:fixture.group.id,groupName:'Legacy Group',invitationId:selected.id}],canResend:true,canWithdraw:true})
    expect(JSON.stringify(response.body)).not.toContain('Private')
    expect((await user.get('/api/invitations/feed')).body.items.some((row:any)=>row.id===sibling.id)).toBe(false)
  })

  it('isolates null phone identities and distinguishes pending-expired capabilities', async () => {
    const user=await legacyAgent(app,{userId:fixture.leader.id})
    const empty=await user.get(`/api/invitations/${fixture.invites.nullPhone.id}`)
    expect(empty.status).toBe(200)
    expect(empty.body).toMatchObject({recipientPhone:null,canResend:false,canWithdraw:false})
    expect(empty.body.invitations.map((row:any)=>row.id)).toEqual([fixture.invites.nullPhone.id])
    const expired=await user.get(`/api/invitations/${fixture.invites.timeExpired.id}`)
    expect(expired.body).toMatchObject({status:'expired',canResend:false,canWithdraw:true})
    await prisma.invitation.update({where:{id:fixture.invites.accepted.id},data:{acceptedAt:null,respondedAt:null}})
    const fallback=await user.get(`/api/invitations/${fixture.invites.accepted.id}`)
    expect(fallback.body.invitations.find((row:any)=>row.id===fixture.invites.accepted.id).date).toBe(fixture.invites.accepted.createdAt.toISOString())
    expect((await prisma.invitation.findUniqueOrThrow({where:{id:fixture.invites.timeExpired.id}})).status).toBe('pending')
  })

  it('requires org membership for normalized phone linking and preserves explicit request member links', async () => {
    const member=fixture.members[4]
    const foreign=await foreignWorld()
    await prisma.memberOrganization.create({data:{memberId:member.id,organizationId:foreign.org.id}})
    await prisma.member.update({where:{id:member.id},data:{birthday:new Date(Date.UTC(new Date().getUTCFullYear()-25,0,1)),profilePicture:'https://example.invalid/avatar.png'}})
    await prisma.invitation.update({where:{id:fixture.invites.pending.id},data:{recipientPhone:member.phoneNumber.replace('+1202','+1 (202) ')}})
    const user=await legacyAgent(app,{userId:fixture.leader.id})
    expect((await user.get(`/api/invitations/${fixture.invites.pending.id}`)).body.member).toBeNull()
    await prisma.memberOrganization.create({data:{memberId:member.id,organizationId:fixture.org.id,joinedAt:new Date('2024-01-01')}})
    await prisma.groupMember.create({data:{groupId:fixture.group.id,memberId:member.id,role:'leader',joinedAt:new Date('2025-01-01')}})
    const linked=await user.get(`/api/invitations/${fixture.invites.pending.id}`)
    expect(linked.body.member).toEqual({id:member.id,name:'Member 4 Legacy',picture:'https://example.invalid/avatar.png',age:25,role:'leader',birthday:new Date(Date.UTC(new Date().getUTCFullYear()-25,0,1)).toISOString(),joinedAt:'2025-01-01T00:00:00.000Z'})
    const pending=await user.get(`/api/invitations/${fixture.requests.pending.id}`)
    expect(pending.body.member).toEqual({id:fixture.members[0].id,name:'Member 0',picture:null,age:null,role:null,birthday:null,joinedAt:null})
  })

  it('validates inputs and preserves authentication and absent/forbidden error distinctions', async () => {
    expect((await request(app).get('/api/invitations/feed')).body).toEqual({success:false,error:'Not authenticated'})
    const user=await legacyAgent(app,{userId:fixture.leader.id})
    for(const query of [{limit:0},{limit:201},{limit:1.5},{limit:'wat'},{orgId:'bad'},{status:'withdrawn'},{q:'query'}]) expect((await user.get('/api/invitations/feed').query(query)).status).toBe(400)
    for(const value of ['malformed',id(999)]) expect((await user.get(`/api/invitations/${value}`)).status).toBe(404)
    expect((await user.get(`/api/invitations/${fixture.invites.unresolvedOrg.id}`)).status).toBe(403)
    const {createApiKeyForUser}=await import('./helpers/api-auth.js')
    const outsiderKey=await createApiKeyForUser(fixture.outsider.id)
    const outsiderFeed=await request(app).get('/api/invitations/feed').set('Authorization',`Bearer ${outsiderKey.token}`)
    expect(outsiderFeed.status).toBe(200)
    expect(outsiderFeed.body.items).toEqual([])
    expect((await request(app).get(`/api/invitations/${fixture.invites.pending.id}`).set('Authorization',`Bearer ${outsiderKey.token}`)).status).toBe(403)
    const apiKey=await createApiKeyForUser(fixture.leader.id)
    await prisma.user.update({where:{id:fixture.leader.id},data:{isActive:false}})
    // Global API-key auth rejects inactive owners before requireAuth; cached sessions retain their existing policy.
    const inactive=await request(app).get('/api/invitations/feed').set('Authorization',`Bearer ${apiKey.token}`)
    expect(inactive.status).toBe(401)
    expect(inactive.body).toEqual({success:false,error:'User account is inactive'})
  })
  it('uses identical SQL and detail status/date mappings at expiry and missing-date boundaries', async () => {
    const {getInvitationFeed,getInvitationDetail}=await import('../src/services/invitation.js')
    const now=new Date('2026-11-02T12:00:00Z')
    const inputs=[
      {id:id(401),initiatedBy:'leader',status:'pending',expiresAt:now},
      {id:id(402),initiatedBy:'member',status:'pending',expiresAt:new Date(now.getTime()-1)},
      {id:id(403),initiatedBy:'leader',status:'expired',expiresAt:null},
      {id:id(404),initiatedBy:'member',status:'accepted',respondedAt:new Date('2025-04-01')},
      {id:id(405),initiatedBy:'member',status:'rejected',respondedAt:null},
    ]
    const createdAt=new Date('2025-01-01')
    await prisma.invitation.createMany({data:inputs.map(row=>({...row,organizationId:fixture.org.id,createdAt}))})
    const expected=[['sent',createdAt],['expired',new Date(now.getTime()-1)],['expired',createdAt],['accepted',new Date('2025-04-01')],['rejected',createdAt]] as const
    for(const [index,input] of inputs.entries()) {
      const [status,date]=expected[index]
      const feed=await getInvitationFeed(fixture.leader.id,{status},now)
      expect(feed.items.find(row=>row.id===input.id)).toMatchObject({status,date:date.toISOString()})
      const detail=await getInvitationDetail(fixture.leader.id,input.id,now)
      expect(detail.status).toBe(status)
      expect(detail.invitations[0].date).toBe(date.toISOString())
    }
  })

})
