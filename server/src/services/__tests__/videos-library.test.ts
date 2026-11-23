import { afterAll, beforeAll, describe, expect, it } from 'vitest'

const { prisma } = await import('../../lib/prisma.js')
const { listLibraryVideos, removeFromLibrary, lessonUseCount } = await import('../videos.service.js')
const { videoActivityUseCount, isUsedByActivity } = await import('../content-media.service.js')

describe('videos.service Library', () => {
  const stamp = Date.now()
  let n = 0
  let userId: string
  let otherUserId: string
  let orgOwnerId: string
  let orgId: string

  // Each test lists a fresh user's rows, so seeds never leak between tests.
  const seedVideo = async (owner: string, data: Record<string, unknown> = {}) =>
    (await prisma.video.create({
      data: { cloudflareUid: `vl-${stamp}-${++n}`, playbackUrl: '', status: 'ready', userId: owner, ...data },
    })).id

  const seedMediaFor = async (videoId: string) =>
    (await prisma.media.create({
      data: { title: 'v', url: '', type: 'video', mimeType: 'video/mp4', organizationId: orgId, uploadedBy: orgOwnerId, videoId },
    })).id

  beforeAll(async () => {
    userId = (await prisma.user.create({ data: { googleId: `gid-vl-a-${stamp}`, email: `vl-a-${stamp}@cl.test`, name: 'VL A' } })).id
    otherUserId = (await prisma.user.create({ data: { googleId: `gid-vl-b-${stamp}`, email: `vl-b-${stamp}@cl.test`, name: 'VL B' } })).id
    orgOwnerId = (await prisma.user.create({ data: { googleId: `gid-vl-c-${stamp}`, email: `vl-c-${stamp}@cl.test`, name: 'VL C' } })).id
    orgId = (await prisma.organization.create({ data: { name: `VL Org ${stamp}`, ownerId: orgOwnerId } })).id
  })

  afterAll(async () => {
    const users = [userId, otherUserId, orgOwnerId]
    await prisma.media.deleteMany({ where: { organizationId: orgId } })
    await prisma.video.deleteMany({ where: { userId: { in: users } } })
    await prisma.organization.deleteMany({ where: { id: orgId } })
    await prisma.user.deleteMany({ where: { id: { in: users } } })
  })

  const clear = () => prisma.video.deleteMany({ where: { userId: { in: [userId, otherUserId] } } })

  it('keyset pages without skips', async () => {
    await clear()
    const at = new Date('2026-11-01T00:00:00Z')
    const ids = await Promise.all(Array.from({ length: 5 }, () => seedVideo(userId, { createdAt: at })))
    const p1 = await listLibraryVideos(userId, { limit: 2 })
    const p2 = await listLibraryVideos(userId, { limit: 2, cursor: p1.nextCursor! })
    const p3 = await listLibraryVideos(userId, { limit: 2, cursor: p2.nextCursor! })
    const seen = [...p1.data, ...p2.data, ...p3.data].map((v) => v.id)
    expect(new Set(seen).size).toBe(5)
    expect(seen).toEqual([...ids].sort().reverse())
    expect([p1.hasMore, p2.hasMore, p3.hasMore]).toEqual([true, true, false])
    expect(p3.nextCursor).toBeNull()
  })

  it('rejects an undecodable cursor', async () => {
    await expect(listLibraryVideos(userId, { limit: 2, cursor: '%%%' })).rejects.toMatchObject({ status: 400 })
  })

  it('searches title and transcript', async () => {
    await clear()
    await seedVideo(userId, { title: 'Grace Talk' })
    await seedVideo(userId, { transcript: 'today we read about GRACE' })
    await seedVideo(userId, { title: '100% done' })
    expect((await listLibraryVideos(userId, { limit: 50, q: 'grace' })).data).toHaveLength(2)
    expect((await listLibraryVideos(userId, { limit: 50, q: '%' })).data).toHaveLength(1)
  })

  it('lists only the caller’s live Library videos', async () => {
    await clear()
    await seedVideo(userId, { libraryRemovedAt: new Date() })
    await seedVideo(userId, { isActive: false })
    await seedVideo(otherUserId, {})
    const live = await seedVideo(userId, { transcript: 'x'.repeat(500) })
    const { data } = await listLibraryVideos(userId, { limit: 50 })
    expect(data.map((v) => v.id)).toEqual([live])
    expect(data[0].transcriptPreview).toHaveLength(160)
    expect(data[0]).not.toHaveProperty('transcript')
  })

  it('removes from the Library once, owner only', async () => {
    await clear()
    const id = await seedVideo(userId, {})
    await expect(removeFromLibrary(otherUserId, id)).rejects.toMatchObject({ status: 403 })
    await expect(removeFromLibrary(userId, 'no-such-video')).rejects.toMatchObject({ status: 404 })
    const a = await removeFromLibrary(userId, id)
    const b = await removeFromLibrary(userId, id)
    expect(a.libraryRemovedAt).toBeInstanceOf(Date)
    expect(b.libraryRemovedAt).toEqual(a.libraryRemovedAt)
    expect((await listLibraryVideos(userId, { limit: 50 })).data).toHaveLength(0)
  })

  it('counts distinct activities through the Media rows', async () => {
    await clear()
    const id = await seedVideo(userId, {})
    expect(await lessonUseCount(id)).toBe(0)
    const m1 = await seedMediaFor(id)
    const m2 = await seedMediaFor(id)
    const use = (mediaId: string, resourceId: string) =>
      prisma.mediaUsage.create({ data: { mediaId, usageType: 'ACTIVITY', resourceId } })
    await use(m1, 'act-1'); await use(m2, 'act-1'); await use(m1, 'act-2')
    await prisma.mediaUsage.create({ data: { mediaId: m1, usageType: 'POST', resourceId: 'post-1' } })
    expect(await lessonUseCount(id)).toBe(2)
    expect(await videoActivityUseCount(prisma, id)).toBe(2)
    expect(await isUsedByActivity(prisma, [m1, m2])).toBe(true)
  })
})
