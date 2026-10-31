import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest'
import request from 'supertest'

const saved = (url: string) => ({
  coverImageUrl: url, coverOriginalUrl: null, coverFraming: null,
  renderedBuffer: Buffer.alloc(0), renderedSize: 10, isNewImage: true,
})
vi.mock('../src/services/group-cover.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../src/services/group-cover.js')>()),
  saveGroupCover: vi.fn(async () => saved(`https://images.test/groups/g-${Date.now()}.jpeg`)),
  saveCover: vi.fn(async () => saved(`https://images.test/programs/p-${Date.now()}.jpeg`)),
}))
vi.mock('../src/services/media-metadata.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../src/services/media-metadata.js')>()),
  // The rendered cover carries no EXIF (group-cover-image): the capture date comes from the body only.
  extractImageMetadata: vi.fn(async () => ({ width: 8, height: 8, aspectRatio: '1:1', dominantColor: null, fileHash: 'h', exifData: null })),
}))
vi.mock('../src/services/claude.js', () => ({ analyzeImage: vi.fn(async () => null) }))

const { app } = await import('../src/index.js')
const { prisma } = await import('../src/lib/prisma.js')
const { createUserWithApiKey, bearer } = await import('./helpers/api-auth.js')

describe('cover routes carry takenAt to the captured library row (media-page D3, SC3)', () => {
  const stamp = Date.now()
  let token: string
  let userId: string
  let orgId: string
  let groupId: string
  let programId: string
  const cover = { imageData: Buffer.from('x').toString('base64'), contentType: 'image/jpeg' }

  beforeAll(async () => {
    const owner = await createUserWithApiKey({ email: `ctaken-${stamp}@cl.test`, name: 'Cover Owner' })
    token = owner.token
    userId = owner.userId
    orgId = (await prisma.organization.create({ data: { name: `Cover Org ${stamp}`, ownerId: userId } })).id
    groupId = (await prisma.group.create({ data: { name: `Cover Group ${stamp}`, code: `ct-${stamp}`, creatorId: userId, organizationId: orgId } })).id
    programId = (await prisma.studyProgram.create({ data: { name: `Cover Program ${stamp}`, days: 1, creatorId: userId, organizationId: orgId } })).id
  })

  afterAll(async () => {
    await prisma.media.deleteMany({ where: { organizationId: orgId } })
    await prisma.studyProgram.deleteMany({ where: { id: programId } })
    await prisma.group.deleteMany({ where: { id: groupId } })
    await prisma.apiKey.deleteMany({ where: { userId } })
    await prisma.organization.deleteMany({ where: { id: orgId } })
    await prisma.user.deleteMany({ where: { id: userId } })
  })

  const capturedRow = (title: string) =>
    vi.waitFor(async () => {
      const row = await prisma.media.findFirst({ where: { organizationId: orgId, title } })
      expect(row).not.toBeNull()
      return row!
    }, { timeout: 5000 })

  it('group cover: stores the body takenAt on the captured row', async () => {
    const res = await request(app).post(`/api/groups/${groupId}/cover-image`).set('Authorization', bearer(token))
      .send({ ...cover, takenAt: '2025-06-14T09:30:00-05:00' })
    expect(res.status).toBe(200)
    const row = await capturedRow(`Cover Group ${stamp} - Cover Image`)
    expect(row.takenAt?.toISOString()).toBe('2025-06-14T14:30:00.000Z')
  })

  it('program cover: stores the body takenAt; an invalid one is ignored, not a 400', async () => {
    const res = await request(app).post(`/api/programs/${programId}/cover-image`).set('Authorization', bearer(token))
      .send({ ...cover, takenAt: '2024-01-05T08:00:00Z' })
    expect(res.status).toBe(200)
    const row = await capturedRow(`Cover Program ${stamp} - Cover Image`)
    expect(row.takenAt?.toISOString()).toBe('2024-01-05T08:00:00.000Z')

    const bad = await request(app).post(`/api/programs/${programId}/cover-image`).set('Authorization', bearer(token))
      .send({ ...cover, takenAt: 'not-a-date' })
    expect(bad.status).toBe(200)
  })

  it('the library list returns takenAt on every item (ISO string or null)', async () => {
    await prisma.media.create({ data: { title: `Undated ${stamp}`, url: `https://images.test/u-${stamp}.jpeg`, type: 'photo', organizationId: orgId, uploadedBy: userId } })
    const res = await request(app).get(`/api/organizations/${orgId}/media/library?type=photo&limit=200`).set('Authorization', bearer(token))
    expect(res.status).toBe(200)
    const byTitle = Object.fromEntries(res.body.data.map((i: { title: string; takenAt: string | null }) => [i.title, i.takenAt]))
    expect(byTitle[`Cover Group ${stamp} - Cover Image`]).toBe('2025-06-14T14:30:00.000Z')
    expect(byTitle[`Undated ${stamp}`]).toBeNull()
  })
})
