/** media-library D2/D15/D18: the super-admin MakeReady media API. R2 writes are stubbed. */
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest'
import request from 'supertest'
import sharp from 'sharp'

vi.mock('../src/services/storage.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../src/services/storage.js')>()),
  uploadImageVariants: vi.fn(async (prefix: string, baseName: string) => ({ url: `https://images.test/${prefix}/${baseName}.jpeg` })),
}))

const { app } = await import('../src/index.js')
const { prisma } = await import('../src/lib/prisma.js')
const { createUserWithApiKey, bearer } = await import('./helpers/api-auth.js')
const { MAKEREADY_ORG_ID, MAKEREADY_SYSTEM_USER_ID } = await import('../src/services/makeready-library.js')

describe('/api/makeready/media (media-library D15)', () => {
  const stamp = Date.now()
  const slug = `test-slug-${stamp}`
  let admin: { userId: string; token: string }
  let leader: { userId: string; token: string }
  let id: string
  const image = () => sharp({ create: { width: 16, height: 9, channels: 3, background: '#335577' } }).jpeg().toBuffer().then((b) => b.toString('base64'))

  beforeAll(async () => {
    admin = await createUserWithApiKey({ email: `mrm-s-${stamp}@cl.test`, name: 'Super', isSuperAdmin: true })
    leader = await createUserWithApiKey({ email: `mrm-l-${stamp}@cl.test`, name: 'Leader' })
  })
  afterAll(async () => {
    await prisma.media.deleteMany({ where: { organizationId: MAKEREADY_ORG_ID, title: { startsWith: `MRM ${stamp}` } } })
    await prisma.apiKey.deleteMany({ where: { userId: { in: [admin.userId, leader.userId] } } })
    await prisma.user.deleteMany({ where: { id: { in: [admin.userId, leader.userId] } } })
  })

  it('a super admin adds an image to the MakeReady org as the system user', async () => {
    const res = await request(app).post('/api/makeready/media').set('Authorization', bearer(admin.token))
      .send({ imageData: await image(), title: `MRM ${stamp} cover`, description: 'Alt words', altText: 'Alt words', tags: ['Lesson', ' John '], d2mSlug: slug })
    expect(res.status).toBe(201)
    id = res.body.data.id
    const row = await prisma.media.findUniqueOrThrow({ where: { id }, include: { tags: true } })
    expect(row).toMatchObject({ organizationId: MAKEREADY_ORG_ID, uploadedBy: MAKEREADY_SYSTEM_USER_ID, source: 'import', description: 'Alt words' })
    expect(row.url).toContain('/makeready/')
    expect(row.tags.map((t) => t.tag).sort()).toEqual(['john', 'lesson'])
  })

  it('refuses the same d2m slug twice', async () => {
    const res = await request(app).post('/api/makeready/media').set('Authorization', bearer(admin.token))
      .send({ imageData: await image(), title: `MRM ${stamp} again`, d2mSlug: slug })
    expect(res.status).toBe(409)
  })

  it('refuses a leader', async () => {
    const res = await request(app).post('/api/makeready/media').set('Authorization', bearer(leader.token))
      .send({ imageData: await image(), title: `MRM ${stamp} nope` })
    expect(res.status).toBe(403)
    expect((await request(app).patch(`/api/makeready/media/${id}`).set('Authorization', bearer(leader.token)).send({ title: 'x' })).status).toBe(403)
  })

  it('PATCH replaces tags; DELETE hides the row', async () => {
    const patched = await request(app).patch(`/api/makeready/media/${id}`).set('Authorization', bearer(admin.token)).send({ tags: ['Psalms'] })
    expect(patched.status).toBe(200)
    expect(patched.body.data.tags).toEqual(['psalms'])
    expect((await request(app).delete(`/api/makeready/media/${id}`).set('Authorization', bearer(admin.token))).status).toBe(200)
    expect((await prisma.media.findUniqueOrThrow({ where: { id } })).isActive).toBe(false)
  })

  it('404s a row outside the MakeReady org', async () => {
    const res = await request(app).patch('/api/makeready/media/00000000-0000-4000-8000-000000000000').set('Authorization', bearer(admin.token)).send({ title: 'x' })
    expect(res.status).toBe(404)
  })
})
