import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest'
import request from 'supertest'
import sharp from 'sharp'

vi.mock('../src/services/storage.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../src/services/storage.js')>()),
  uploadImageVariants: vi.fn(async (_prefix: string, baseName: string) => ({ url: `https://images.test/library/${baseName}.jpeg` })),
}))
vi.mock('../src/services/claude.js', () => ({ analyzeImage: vi.fn(async () => null) }))

const { app } = await import('../src/index.js')
const { prisma } = await import('../src/lib/prisma.js')
const { createUserWithApiKey, bearer } = await import('./helpers/api-auth.js')

describe('POST /media/upload stores takenAt (media-page D4, SC2)', () => {
  const stamp = Date.now()
  let token: string
  let userId: string
  let orgId: string

  const jpeg = (exif?: Record<string, Record<string, string>>) => {
    const img = sharp({ create: { width: 8, height: 8, channels: 3, background: '#888888' } })
    return (exif ? img.withExif(exif) : img).jpeg().toBuffer().then((b) => b.toString('base64'))
  }
  const upload = async (body: Record<string, unknown>) =>
    request(app).post(`/api/organizations/${orgId}/media/upload`).set('Authorization', bearer(token))
      .send({ type: 'photo', title: `T ${stamp}`, ...body })

  beforeAll(async () => {
    const owner = await createUserWithApiKey({ email: `mtaken-${stamp}@cl.test`, name: 'Taken Owner' })
    token = owner.token
    userId = owner.userId
    orgId = (await prisma.organization.create({ data: { name: `Taken Org ${stamp}`, ownerId: userId } })).id
  })

  afterAll(async () => {
    await prisma.media.deleteMany({ where: { organizationId: orgId } })
    await prisma.apiKey.deleteMany({ where: { userId } })
    await prisma.organization.deleteMany({ where: { id: orgId } })
    await prisma.user.deleteMany({ where: { id: userId } })
  })

  it('stores the body takenAt', async () => {
    const res = await upload({ imageData: await jpeg(), takenAt: '2025-06-14T09:30:00-05:00' })
    expect(res.status).toBe(201)
    const row = await prisma.media.findUniqueOrThrow({ where: { id: res.body.data.id } })
    expect(row.takenAt?.toISOString()).toBe('2025-06-14T14:30:00.000Z')
  })

  it('falls back to the EXIF DateTimeOriginal of the posted bytes', async () => {
    const res = await upload({ imageData: await jpeg({ IFD2: { DateTimeOriginal: '2024:03:02 10:11:12' } }) })
    expect(res.status).toBe(201)
    const row = await prisma.media.findUniqueOrThrow({ where: { id: res.body.data.id } })
    expect(row.takenAt?.toISOString()).toBe('2024-03-02T10:11:12.000Z')
  })

  it('ignores an invalid takenAt (never a 400) and stores null without EXIF', async () => {
    const res = await upload({ imageData: await jpeg(), takenAt: '2025-06-14' })
    expect(res.status).toBe(201)
    const row = await prisma.media.findUniqueOrThrow({ where: { id: res.body.data.id } })
    expect(row.takenAt).toBeNull()
  })
})
