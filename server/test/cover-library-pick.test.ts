/** media-library D10/D12: covers framed from the library link to the original; event covers capture. */
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
vi.mock('../src/services/storage.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../src/services/storage.js')>()),
  uploadImageVariants: vi.fn(async (prefix: string, baseName: string) => ({ url: `https://images.test/${prefix}/${baseName}.jpeg` })),
}))
vi.mock('../src/services/media-metadata.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../src/services/media-metadata.js')>()),
  extractImageMetadata: vi.fn(async () => ({ width: 8, height: 8, aspectRatio: '1:1', dominantColor: null, fileHash: 'h', exifData: null })),
}))
vi.mock('../src/services/claude.js', () => ({ analyzeImage: vi.fn(async () => null) }))

const { app } = await import('../src/index.js')
const { prisma } = await import('../src/lib/prisma.js')
const { createUserWithApiKey, bearer } = await import('./helpers/api-auth.js')
const { ensureMakeReadyOrg, MAKEREADY_ORG_ID, MAKEREADY_SYSTEM_USER_ID } = await import('../src/services/makeready-library.js')

describe('library-pick covers and event covers (media-library D10/D12)', () => {
  const stamp = Date.now()
  let token: string
  let userId: string
  let otherId: string
  let orgId: string
  let otherOrg: string
  let groupId: string
  let programId: string
  let eventId: string
  let mrMedia: string
  let foreignMedia: string
  const cover = { imageData: Buffer.from('x').toString('base64'), contentType: 'image/jpeg' }
  const orgMediaCount = () => prisma.media.count({ where: { organizationId: orgId } })

  beforeAll(async () => {
    await ensureMakeReadyOrg()
    const owner = await createUserWithApiKey({ email: `clp-${stamp}@cl.test`, name: 'Pick Owner' })
    token = owner.token
    userId = owner.userId
    otherId = (await prisma.user.create({ data: { email: `clp-o-${stamp}@cl.test`, name: 'Other' } })).id
    orgId = (await prisma.organization.create({ data: { name: `Pick Org ${stamp}`, ownerId: userId } })).id
    otherOrg = (await prisma.organization.create({ data: { name: `Other Org ${stamp}`, ownerId: otherId } })).id
    groupId = (await prisma.group.create({ data: { name: `Pick Group ${stamp}`, code: `cp-${stamp}`, creatorId: userId, organizationId: orgId } })).id
    programId = (await prisma.studyProgram.create({ data: { name: `Pick Program ${stamp}`, days: 1, creatorId: userId, organizationId: orgId } })).id
    eventId = (await prisma.event.create({ data: { groupId, type: 'MEETING' as any, title: `Pick Event ${stamp}`, date: new Date() } })).id
    mrMedia = (await prisma.media.create({ data: { title: `MR ${stamp}`, url: `https://img.test/mr-${stamp}.jpeg`, type: 'photo', organizationId: MAKEREADY_ORG_ID, uploadedBy: MAKEREADY_SYSTEM_USER_ID } })).id
    foreignMedia = (await prisma.media.create({ data: { title: `F ${stamp}`, url: `https://img.test/f-${stamp}.jpeg`, type: 'photo', organizationId: otherOrg, uploadedBy: otherId } })).id
  })

  afterAll(async () => {
    await prisma.media.deleteMany({ where: { id: { in: [mrMedia, foreignMedia] } } })
    await prisma.media.deleteMany({ where: { organizationId: orgId } })
    await prisma.event.deleteMany({ where: { id: eventId } })
    await prisma.studyProgram.deleteMany({ where: { id: programId } })
    await prisma.group.deleteMany({ where: { id: groupId } })
    await prisma.apiKey.deleteMany({ where: { userId } })
    await prisma.organization.deleteMany({ where: { id: { in: [orgId, otherOrg] } } })
    await prisma.user.deleteMany({ where: { id: { in: [userId, otherId] } } })
  })

  it('a group cover picked from MakeReady records a usage and captures nothing', async () => {
    const before = await orgMediaCount()
    const res = await request(app).post(`/api/groups/${groupId}/cover-image`).set('Authorization', bearer(token)).send({ ...cover, sourceMediaId: mrMedia })
    expect(res.status).toBe(200)
    await new Promise((r) => setTimeout(r, 300))
    expect(await orgMediaCount()).toBe(before)
    const usage = await prisma.mediaUsage.findFirst({ where: { mediaId: mrMedia, usageType: 'GROUP_COVER', resourceId: groupId } })
    expect(usage?.resourceName).toBe(`Pick Group ${stamp}`)
  })

  it('a program cover picked from MakeReady records a usage', async () => {
    const res = await request(app).post(`/api/programs/${programId}/cover-image`).set('Authorization', bearer(token)).send({ ...cover, sourceMediaId: mrMedia })
    expect(res.status).toBe(200)
    expect(await prisma.mediaUsage.count({ where: { mediaId: mrMedia, usageType: 'PROGRAM_COVER', resourceId: programId } })).toBe(1)
  })

  it("refuses another org's media (403) and an unknown id (404)", async () => {
    const f = await request(app).post(`/api/groups/${groupId}/cover-image`).set('Authorization', bearer(token)).send({ ...cover, sourceMediaId: foreignMedia })
    expect(f.status).toBe(403)
    const u = await request(app).post(`/api/groups/${groupId}/cover-image`).set('Authorization', bearer(token)).send({ ...cover, sourceMediaId: '00000000-0000-4000-8000-000000000000' })
    expect(u.status).toBe(404)
  })

  it('without sourceMediaId a new cover is still captured', async () => {
    const before = await orgMediaCount()
    await request(app).post(`/api/groups/${groupId}/cover-image`).set('Authorization', bearer(token)).send(cover)
    await vi.waitFor(async () => expect(await orgMediaCount()).toBe(before + 1), { timeout: 5000 })
  })

  it("an event cover lands in its group's org library with an EVENT_COVER usage", async () => {
    const png = await (await import('sharp')).default({ create: { width: 8, height: 8, channels: 3, background: '#123456' } }).jpeg().toBuffer()
    const res = await request(app).post(`/api/events/${eventId}/cover-image`).set('Authorization', bearer(token)).send({ imageData: png.toString('base64') })
    expect(res.status).toBe(200)
    await vi.waitFor(async () => {
      const usage = await prisma.mediaUsage.findFirst({ where: { usageType: 'EVENT_COVER', resourceId: eventId }, include: { media: true } })
      expect(usage?.media.organizationId).toBe(orgId)
    }, { timeout: 5000 })
  })
})
