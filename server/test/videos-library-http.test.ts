import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { createUserWithApiKey, bearer, type TestUserWithToken } from './helpers/api-auth.js'

describe('Video Library routes', () => {
  const stamp = Date.now()
  let n = 0
  let owner: TestUserWithToken
  let stranger: TestUserWithToken
  let orgId: string

  const seedVideo = async (userId: string, data: Record<string, unknown> = {}) =>
    (await prisma.video.create({
      data: { cloudflareUid: `vlh-${stamp}-${++n}`, playbackUrl: '', status: 'ready', userId, ...data },
    })).id

  beforeAll(async () => {
    owner = await createUserWithApiKey({ email: `vlh-owner-${stamp}@cl.test`, name: 'VLH Owner' })
    stranger = await createUserWithApiKey({ email: `vlh-stranger-${stamp}@cl.test`, name: 'VLH Stranger' })
    orgId = (await prisma.organization.create({ data: { name: `VLH Org ${stamp}`, ownerId: owner.userId } })).id
  })

  afterAll(async () => {
    const users = [owner.userId, stranger.userId]
    await prisma.media.deleteMany({ where: { organizationId: orgId } })
    await prisma.video.deleteMany({ where: { userId: { in: users } } })
    await prisma.organization.deleteMany({ where: { id: orgId } })
    await prisma.apiKey.deleteMany({ where: { userId: { in: users } } })
    await prisma.user.deleteMany({ where: { id: { in: users } } })
  })

  it('routes /library before /:videoId, and bad cursor or limit is 400', async () => {
    const someId = await seedVideo(owner.userId)
    const ok = await request(app).get('/api/videos/library').set('Authorization', bearer(owner.token))
    expect(ok.status).toBe(200)
    expect(ok.body).toHaveProperty('hasMore')
    expect(ok.body.data.map((v: any) => v.id)).toContain(someId)
    for (const qs of ['cursor=%%%', 'limit=101', 'limit=0', 'limit=1.5', 'limit=abc']) {
      expect((await request(app).get(`/api/videos/library?${qs}`).set('Authorization', bearer(owner.token))).status).toBe(400)
    }
    expect((await request(app).get('/api/videos/library')).status).toBe(401)
    const one = await request(app).get(`/api/videos/${someId}`).set('Authorization', bearer(owner.token))
    expect(one.body.data).toHaveProperty('lessonUseCount', 0)
  })

  it('removes from the Library once, owner only, and /me drops the row', async () => {
    const id = await seedVideo(owner.userId)
    const denied = await request(app).post(`/api/videos/${id}/remove-from-library`).set('Authorization', bearer(stranger.token))
    expect(denied.status).toBe(403)
    expect((await request(app).post('/api/videos/nope/remove-from-library').set('Authorization', bearer(owner.token))).status).toBe(404)
    const a = await request(app).post(`/api/videos/${id}/remove-from-library`).set('Authorization', bearer(owner.token))
    const b = await request(app).post(`/api/videos/${id}/remove-from-library`).set('Authorization', bearer(owner.token))
    expect(a.status).toBe(200)
    expect(b.body.data).toEqual(a.body.data)
    expect(a.body.data.id).toBe(id)
    const me = await request(app).get('/api/videos/me').set('Authorization', bearer(owner.token))
    expect(me.body.data.map((v: any) => v.id)).not.toContain(id)
  })

  it('lessonUseCount agrees with the DELETE guard', async () => {
    const id = await seedVideo(owner.userId)
    const media = await prisma.media.create({
      data: { title: 'v', url: '', type: 'video', mimeType: 'video/mp4', organizationId: orgId, uploadedBy: owner.userId, videoId: id },
    })
    await prisma.mediaUsage.create({ data: { mediaId: media.id, usageType: 'ACTIVITY', resourceId: 'act-1' } })
    const one = await request(app).get(`/api/videos/${id}`).set('Authorization', bearer(owner.token))
    expect(one.body.data.lessonUseCount).toBe(1)
    expect((await request(app).delete(`/api/videos/${id}`).set('Authorization', bearer(owner.token))).status).toBe(409)
  })
})
