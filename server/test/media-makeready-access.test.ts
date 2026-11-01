/**
 * media-library D1/D16: MakeReady media is readable by every signed-in user, writable through no
 * generic route (super admins included), and its usages are narrowed to the caller's own orgs.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import request from 'supertest'

const { app } = await import('../src/index.js')
const { prisma } = await import('../src/lib/prisma.js')
const { createUserWithApiKey, bearer } = await import('./helpers/api-auth.js')
const { ensureMakeReadyOrg, MAKEREADY_ORG_ID, MAKEREADY_SYSTEM_USER_ID } = await import(
  '../src/services/makeready-library.js'
)

describe('MakeReady media access (media-library D16)', () => {
  const stamp = Date.now()
  let leader: { userId: string; token: string }
  let admin: { userId: string; token: string }
  let other: { userId: string; token: string }
  let orgA: string
  let orgB: string
  let mediaId: string

  beforeAll(async () => {
    await ensureMakeReadyOrg()
    leader = await createUserWithApiKey({ email: `mra-l-${stamp}@cl.test`, name: 'Leader A' })
    other = await createUserWithApiKey({ email: `mra-o-${stamp}@cl.test`, name: 'Leader B' })
    admin = await createUserWithApiKey({ email: `mra-s-${stamp}@cl.test`, name: 'Super', isSuperAdmin: true })
    orgA = (await prisma.organization.create({ data: { name: `MRA A ${stamp}`, ownerId: leader.userId } })).id
    orgB = (await prisma.organization.create({ data: { name: `MRA B ${stamp}`, ownerId: other.userId } })).id
    const groupA = await prisma.group.create({ data: { name: `Group A ${stamp}`, code: `A${stamp}`.slice(0, 12), organizationId: orgA, creatorId: leader.userId } })
    const groupB = await prisma.group.create({ data: { name: `Group B ${stamp}`, code: `B${stamp}`.slice(0, 12), organizationId: orgB, creatorId: other.userId } })
    const media = await prisma.media.create({
      data: { title: `MR cover ${stamp}`, url: `https://img.test/mr-${stamp}.jpeg`, type: 'photo', organizationId: MAKEREADY_ORG_ID, uploadedBy: MAKEREADY_SYSTEM_USER_ID, source: 'import' },
    })
    mediaId = media.id
    await prisma.mediaUsage.createMany({
      data: [
        { mediaId, usageType: 'GROUP_COVER', resourceId: groupA.id, resourceName: groupA.name },
        { mediaId, usageType: 'GROUP_COVER', resourceId: groupB.id, resourceName: groupB.name },
      ],
    })
  })

  afterAll(async () => {
    await prisma.media.deleteMany({ where: { id: mediaId } })
    await prisma.group.deleteMany({ where: { organizationId: { in: [orgA, orgB] } } })
    await prisma.apiKey.deleteMany({ where: { userId: { in: [leader.userId, other.userId, admin.userId] } } })
    await prisma.organization.deleteMany({ where: { id: { in: [orgA, orgB] } } })
    await prisma.user.deleteMany({ where: { id: { in: [leader.userId, other.userId, admin.userId] } } })
  })

  it('a leader of another org can read it', async () => {
    const res = await request(app).get(`/api/media/${mediaId}`).set('Authorization', bearer(leader.token))
    expect(res.status).toBe(200)
  })

  it('a leader cannot edit, tag or delete it', async () => {
    const auth = bearer(leader.token)
    expect((await request(app).patch(`/api/media/${mediaId}`).set('Authorization', auth).send({ title: 'x' })).status).toBe(403)
    expect((await request(app).post(`/api/media/${mediaId}/tags`).set('Authorization', auth).send({ tags: ['x'] })).status).toBe(403)
    expect((await request(app).delete(`/api/media/${mediaId}`).set('Authorization', auth)).status).toBe(403)
  })

  it('a super admin cannot use the generic upload, batch or delete on it', async () => {
    const auth = bearer(admin.token)
    expect((await request(app).delete(`/api/media/${mediaId}`).set('Authorization', auth)).status).toBe(403)
    expect((await request(app).post(`/api/organizations/${MAKEREADY_ORG_ID}/media/upload`).set('Authorization', auth).send({ type: 'photo', title: 't', imageData: 'x' })).status).toBe(403)
    expect((await request(app).post(`/api/organizations/${MAKEREADY_ORG_ID}/media/upload/batch`).set('Authorization', auth).send({ items: [] })).status).toBe(403)
    expect(await prisma.media.findUnique({ where: { id: mediaId } })).not.toBeNull()
  })

  it("narrows its usages to the caller's orgs; a super admin sees all", async () => {
    const mine = await request(app).get(`/api/media/${mediaId}/usages`).set('Authorization', bearer(leader.token))
    expect(mine.status).toBe(200)
    expect(mine.body.data.map((u: any) => u.resourceName)).toEqual([`Group A ${stamp}`])
    const detail = await request(app).get(`/api/media/${mediaId}/detail`).set('Authorization', bearer(leader.token))
    expect(detail.body.data.usages.map((u: any) => u.resourceName)).toEqual([`Group A ${stamp}`])
    const all = await request(app).get(`/api/media/${mediaId}/usages`).set('Authorization', bearer(admin.token))
    expect(all.body.data).toHaveLength(2)
  })
})
