/**
 * ui2-enrollments-browse SC2 (D3–D6, D10, D19): /api/enrollment-drafts — scope through the draft's
 * group (groupManageFilter), program read scope on create/move, 409 draft_exists, strict bodies,
 * absent vs null. Real DB + API-key auth, as enrollment-create.test.ts.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { createUserWithApiKey, bearer, type TestUserWithToken } from './helpers/api-auth.js'

describe('/api/enrollment-drafts (ui2-enrollments-browse SC2)', () => {
  const stamp = Date.now()
  let owner: TestUserWithToken
  let coLeader: TestUserWithToken
  let stranger: TestUserWithToken
  let orgId: string
  let foreignOrgId: string
  let groupId: string
  let inactiveGroupId: string
  let foreignGroupId: string
  let inactiveProgramId: string
  let foreignProgramId: string
  const P: string[] = [] // eight active programs in the owner's org, one per test pair

  const as = (u: TestUserWithToken) => ({
    post: (b: Record<string, unknown>) => request(app).post('/api/enrollment-drafts').set('Authorization', bearer(u.token)).send(b),
    list: (gid?: string) =>
      request(app).get('/api/enrollment-drafts').query(gid ? { groupId: gid } : {}).set('Authorization', bearer(u.token)),
    get: (id: string) => request(app).get(`/api/enrollment-drafts/${id}`).set('Authorization', bearer(u.token)),
    patch: (id: string, b: Record<string, unknown>) =>
      request(app).patch(`/api/enrollment-drafts/${id}`).set('Authorization', bearer(u.token)).send(b),
    del: (id: string) => request(app).delete(`/api/enrollment-drafts/${id}`).set('Authorization', bearer(u.token)),
  })

  beforeAll(async () => {
    owner = await createUserWithApiKey({ email: `ed-owner-${stamp}@cl.test`, name: 'ED Owner' })
    coLeader = await createUserWithApiKey({ email: `ed-co-${stamp}@cl.test`, name: 'ED CoLeader' })
    stranger = await createUserWithApiKey({ email: `ed-stranger-${stamp}@cl.test`, name: 'ED Stranger' })
    orgId = (await prisma.organization.create({ data: { name: `ED Org ${stamp}`, ownerId: owner.userId } })).id
    foreignOrgId = (await prisma.organization.create({ data: { name: `ED Foreign ${stamp}`, ownerId: stranger.userId } })).id
    const role = await prisma.role.create({ data: { name: `ED Leader ${stamp}`, organizationId: orgId, isSystem: false } })
    await prisma.userRole.create({ data: { userId: coLeader.userId, roleId: role.id, organizationId: orgId } })
    const mkGroup = async (org: string, creator: string, name: string, isActive = true) =>
      (await prisma.group.create({ data: { name, code: `ed-${name}-${stamp}`, creatorId: creator, organizationId: org, isActive } })).id
    groupId = await mkGroup(orgId, owner.userId, 'g')
    inactiveGroupId = await mkGroup(orgId, owner.userId, 'gi', false)
    foreignGroupId = await mkGroup(foreignOrgId, stranger.userId, 'gf')
    const mkProgram = async (org: string, creator: string, name: string, isActive = true) =>
      (await prisma.studyProgram.create({ data: { name, days: 3, creatorId: creator, organizationId: org, isActive } })).id
    for (let i = 0; i < 8; i++) P.push(await mkProgram(orgId, owner.userId, `ED P${i} ${stamp}`))
    inactiveProgramId = await mkProgram(orgId, owner.userId, `ED Inactive ${stamp}`, false)
    foreignProgramId = await mkProgram(foreignOrgId, stranger.userId, `ED Foreign ${stamp}`)
  })

  afterAll(async () => {
    const orgs = [orgId, foreignOrgId]
    await prisma.enrollmentDraft.deleteMany({ where: { group: { organizationId: { in: orgs } } } })
    await prisma.studyProgram.deleteMany({ where: { organizationId: { in: orgs } } })
    await prisma.group.deleteMany({ where: { organizationId: { in: orgs } } })
    await prisma.userRole.deleteMany({ where: { organizationId: orgId } })
    await prisma.role.deleteMany({ where: { organizationId: orgId } })
    const users = [owner.userId, coLeader.userId, stranger.userId]
    await prisma.apiKey.deleteMany({ where: { userId: { in: users } } })
    await prisma.organization.deleteMany({ where: { id: { in: orgs } } })
    await prisma.user.deleteMany({ where: { id: { in: users } } })
  })

  it('POST creates a draft from the two ids alone: 201, every other field null, createdBy set (D3)', async () => {
    const res = await as(owner).post({ groupId, studyProgramId: P[0] })
    expect(res.status).toBe(201)
    expect(res.body.success).toBe(true)
    expect(res.body.draft).toMatchObject({
      groupId, studyProgramId: P[0], startDate: null, enabledDays: null, overriddenDates: null, scheduleDates: null,
      smsTime: null, timezone: null, syncMode: null, lessonAccess: null, createdBy: { id: owner.userId, name: 'ED Owner' },
    })
    expect(Object.keys(res.body.draft).sort()).toEqual(
      ['createdAt', 'createdBy', 'enabledDays', 'groupId', 'id', 'lessonAccess', 'overriddenDates', 'scheduleDates',
        'smsTime', 'startDate', 'studyProgramId', 'syncMode', 'timezone', 'updatedAt'].sort(),
    )
  })

  it('POST on a pair that already has a draft → 409 draft_exists with that draftId (D6)', async () => {
    const existing = await prisma.enrollmentDraft.findUniqueOrThrow({ where: { groupId_studyProgramId: { groupId, studyProgramId: P[0] } } })
    const res = await as(owner).post({ groupId, studyProgramId: P[0] })
    expect(res.status).toBe(409)
    expect(res.body).toEqual({ success: false, error: 'draft_exists', draftId: existing.id })
  })

  it('two concurrent POSTs on one pair → one 201, one 409', async () => {
    const [a, b] = await Promise.all([as(owner).post({ groupId, studyProgramId: P[1] }), as(owner).post({ groupId, studyProgramId: P[1] })])
    expect([a.status, b.status].sort()).toEqual([201, 409])
  })

  it('POST 400s: a missing id, an unknown field (.strict), unsorted scheduleDates, an invalid timezone', async () => {
    expect((await as(owner).post({ groupId })).status).toBe(400)
    expect((await as(owner).post({ groupId, studyProgramId: P[2], color: 'red' })).status).toBe(400)
    expect((await as(owner).post({ groupId, studyProgramId: P[2], scheduleDates: ['2030-01-02', '2030-01-01'] })).status).toBe(400)
    expect((await as(owner).post({ groupId, studyProgramId: P[2], timezone: 'Mars/Olympus' })).status).toBe(400)
    expect(await prisma.enrollmentDraft.count({ where: { groupId, studyProgramId: P[2] } })).toBe(0)
  })

  it('POST 404s an inactive or out-of-scope group, and an inactive or unreadable program (D5, D19)', async () => {
    expect((await as(owner).post({ groupId: inactiveGroupId, studyProgramId: P[2] })).status).toBe(404)
    expect((await as(owner).post({ groupId: foreignGroupId, studyProgramId: P[2] })).status).toBe(404)
    expect((await as(owner).post({ groupId, studyProgramId: inactiveProgramId })).status).toBe(404)
    expect((await as(owner).post({ groupId, studyProgramId: foreignProgramId })).status).toBe(404)
  })

  it('PATCH writes every field, then a null clears one and absent keys keep theirs', async () => {
    const id = (await as(owner).post({ groupId, studyProgramId: P[2] })).body.draft.id
    const full = {
      startDate: '2030-03-02', enabledDays: ['Mon', 'Wed'], overriddenDates: ['2030-03-04'],
      scheduleDates: ['2030-03-02', '2030-03-03', '2030-03-05'], smsTime: '07:30', timezone: 'America/Chicago',
      syncMode: 'AUTO', lessonAccess: 'ONE_AT_A_TIME',
    }
    const set = await as(owner).patch(id, full)
    expect(set.status).toBe(200)
    expect(set.body.draft).toMatchObject(full)
    const cleared = await as(owner).patch(id, { smsTime: null, scheduleDates: null })
    expect(cleared.status).toBe(200)
    expect(cleared.body.draft).toMatchObject({ ...full, smsTime: null, scheduleDates: null })
    expect((await as(owner).patch(id, { syncMode: 'APPROVAL' })).status).toBe(400)
    expect((await as(owner).patch(id, { nope: 1 })).status).toBe(400)
  })

  it('PATCH moving onto a pair another draft holds → 409 with that draftId, nothing changed (D6)', async () => {
    const holder = (await as(owner).post({ groupId, studyProgramId: P[3] })).body.draft.id
    const mover = (await prisma.enrollmentDraft.findUniqueOrThrow({ where: { groupId_studyProgramId: { groupId, studyProgramId: P[2] } } })).id
    const res = await as(owner).patch(mover, { studyProgramId: P[3], smsTime: '09:00' })
    expect(res.status).toBe(409)
    expect(res.body).toEqual({ success: false, error: 'draft_exists', draftId: holder })
    const after = await prisma.enrollmentDraft.findUniqueOrThrow({ where: { id: mover } })
    expect(after.studyProgramId).toBe(P[2])
    expect(after.smsTime).toBeNull()
  })

  it('PATCH re-scopes a moved group or program: out of scope / inactive → 404, nothing changed', async () => {
    const id = (await prisma.enrollmentDraft.findUniqueOrThrow({ where: { groupId_studyProgramId: { groupId, studyProgramId: P[2] } } })).id
    expect((await as(owner).patch(id, { groupId: foreignGroupId })).status).toBe(404)
    expect((await as(owner).patch(id, { groupId: inactiveGroupId })).status).toBe(404)
    expect((await as(owner).patch(id, { studyProgramId: foreignProgramId })).status).toBe(404)
    expect((await as(owner).patch(id, { studyProgramId: inactiveProgramId, smsTime: '06:00' })).status).toBe(404)
    const after = await prisma.enrollmentDraft.findUniqueOrThrow({ where: { id } })
    expect([after.groupId, after.studyProgramId, after.smsTime]).toEqual([groupId, P[2], null])
  })

  it('GET reads a draft in scope; a stranger gets 404 (D5)', async () => {
    const id = (await as(owner).post({ groupId, studyProgramId: P[4] })).body.draft.id
    const res = await as(owner).get(id)
    expect(res.status).toBe(200)
    expect(res.body.draft.id).toBe(id)
    expect((await as(stranger).get(id)).status).toBe(404)
    expect((await as(owner).get('not-a-uuid')).status).toBe(404)
    expect((await as(owner).get('00000000-0000-4000-8000-000000000000')).status).toBe(404)
  })

  it('a co-leader (role-held org) can read, patch and delete a draft another leader started (D5)', async () => {
    const id = (await prisma.enrollmentDraft.findUniqueOrThrow({ where: { groupId_studyProgramId: { groupId, studyProgramId: P[4] } } })).id
    expect((await as(coLeader).get(id)).status).toBe(200)
    const patched = await as(coLeader).patch(id, { lessonAccess: 'ALL_AT_ONCE' })
    expect(patched.status).toBe(200)
    expect(patched.body.draft.createdBy).toEqual({ id: owner.userId, name: 'ED Owner' })
    expect((await prisma.enrollmentDraft.findUniqueOrThrow({ where: { id } })).updatedById).toBe(coLeader.userId)
    expect((await as(coLeader).del(id)).body).toEqual({ success: true })
    expect((await as(owner).get(id)).status).toBe(404)
  })

  it('DELETE removes the draft; a second DELETE and a stranger DELETE are 404 (D10)', async () => {
    const id = (await as(owner).post({ groupId, studyProgramId: P[5] })).body.draft.id
    expect((await as(stranger).del(id)).status).toBe(404)
    const res = await as(owner).del(id)
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ success: true })
    expect((await as(owner).del(id)).status).toBe(404)
  })

  it('a draft whose program went inactive is unlisted and 404s on GET and PATCH, and the row stays (D19)', async () => {
    const id = (await as(owner).post({ groupId, studyProgramId: P[6] })).body.draft.id
    await prisma.studyProgram.update({ where: { id: P[6] }, data: { isActive: false } })
    expect((await as(owner).get(id)).status).toBe(404)
    expect((await as(owner).patch(id, { smsTime: '08:00' })).status).toBe(404)
    expect((await as(owner).list(groupId)).body.drafts.map((d: { id: string }) => d.id)).not.toContain(id)
    expect(await prisma.enrollmentDraft.count({ where: { id } })).toBe(1)
  })

  it('createdBy is null once its user is deleted', async () => {
    const temp = await prisma.user.create({ data: { googleId: `gid-ed-temp-${stamp}`, email: `ed-temp-${stamp}@cl.test`, name: 'Temp' } })
    const draft = await prisma.enrollmentDraft.create({ data: { groupId, studyProgramId: P[7], createdById: temp.id } })
    await prisma.user.delete({ where: { id: temp.id } })
    const res = await as(owner).get(draft.id)
    expect(res.status).toBe(200)
    expect(res.body.draft.createdBy).toBeNull()
  })

  it('GET ?groupId lists the group\'s drafts newest updatedAt first; 400 without groupId; 404 out of scope', async () => {
    const res = await as(owner).list(groupId)
    expect(res.status).toBe(200)
    const times = res.body.drafts.map((d: { updatedAt: string }) => Date.parse(d.updatedAt))
    expect(times.length).toBeGreaterThanOrEqual(3)
    expect([...times].sort((a, b) => b - a)).toEqual(times)
    expect((await as(owner).list()).status).toBe(400)
    expect((await as(stranger).list(groupId)).status).toBe(404)
    expect((await as(owner).list(inactiveGroupId)).status).toBe(404)
  })
})
