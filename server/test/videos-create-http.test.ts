import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { createUserWithApiKey, bearer, type TestUserWithToken } from './helpers/api-auth.js'

describe('POST /api/videos', () => {
  const stamp = Date.now()
  let owner: TestUserWithToken
  let stranger: TestUserWithToken

  beforeAll(async () => {
    owner = await createUserWithApiKey({ email: `vch-owner-${stamp}@cl.test`, name: 'VCH Owner' })
    stranger = await createUserWithApiKey({ email: `vch-stranger-${stamp}@cl.test`, name: 'VCH Stranger' })
  })

  afterAll(async () => {
    const users = [owner.userId, stranger.userId]
    await prisma.media.deleteMany({ where: { uploadedBy: { in: users } } })
    await prisma.video.deleteMany({ where: { userId: { in: users } } })
    await prisma.apiKey.deleteMany({ where: { userId: { in: users } } })
    await prisma.user.deleteMany({ where: { id: { in: users } } })
  })

  it('answers 201, then 200 for the owner, 409 for another, 400 for an unknown key', async () => {
    const cloudflareUid = `vch-${stamp}`
    const first = await request(app).post('/api/videos').set('Authorization', bearer(owner.token)).send({ cloudflareUid, source: 'recording' })
    expect(first.status).toBe(201)
    expect(first.body.data).toMatchObject({ transcriptStatus: 'pending', libraryRemovedAt: null })

    const again = await request(app).post('/api/videos').set('Authorization', bearer(owner.token)).send({ cloudflareUid, source: 'recording' })
    expect(again.status).toBe(200)
    expect(again.body.data.id).toBe(first.body.data.id)

    const other = await request(app).post('/api/videos').set('Authorization', bearer(stranger.token)).send({ cloudflareUid })
    expect(other.status).toBe(409)

    const bad = await request(app).post('/api/videos').set('Authorization', bearer(owner.token)).send({ nope: 1 })
    expect(bad.status).toBe(400)
    expect(bad.body.success).toBe(false)
  })
})
