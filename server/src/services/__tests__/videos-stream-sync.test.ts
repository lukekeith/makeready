import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'

const getVideo = vi.hoisted(() => vi.fn())
vi.mock('../cloudflare.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../cloudflare.js')>()),
  getVideo,
}))

const { prisma } = await import('../../lib/prisma.js')
const { syncPendingVideos } = await import('../videos.service.js')

const hoursAgo = (h: number) => new Date(Date.now() - h * 3_600_000)

describe('videos.service Stream status sync', () => {
  const stamp = Date.now()
  let n = 0
  let userId: string

  const seedVideo = async (owner: string, data: Record<string, unknown> = {}) =>
    (await prisma.video.create({
      data: { cloudflareUid: `vs-${stamp}-${++n}`, playbackUrl: '', status: 'pending', userId: owner, ...data },
    })).id

  const readyAt = (uid: string) => ({
    success: true,
    video: { uid, readyToStream: true, status: { state: 'ready' }, duration: 42, thumbnail: 't', playback: { hls: 'h' } },
  })

  beforeAll(async () => {
    userId = (await prisma.user.create({ data: { googleId: `gid-vs-${stamp}`, email: `vs-${stamp}@cl.test`, name: 'VS' } })).id
  })

  afterAll(async () => {
    await prisma.video.deleteMany({ where: { userId } })
    await prisma.user.deleteMany({ where: { id: userId } })
  })

  beforeEach(async () => {
    await prisma.video.deleteMany({ where: { userId } })
    getVideo.mockReset()
  })

  it('refreshes pending videos', async () => {
    getVideo.mockResolvedValue(readyAt('u1'))
    const id = await seedVideo(userId, { cloudflareUid: `u1-${stamp}`, status: 'pending', createdAt: hoursAgo(1) })
    expect(await syncPendingVideos(new Date())).toMatchObject({ refreshed: 1 })
    expect(getVideo).toHaveBeenCalledWith(`u1-${stamp}`)
    expect(await prisma.video.findUnique({ where: { id } })).toMatchObject({ status: 'ready', duration: 42 })
  })

  it('expires stale pending videos', async () => {
    const id = await seedVideo(userId, { status: 'pending', transcriptStatus: 'pending', createdAt: hoursAgo(25) })
    expect(await syncPendingVideos(new Date())).toMatchObject({ expired: 1 })
    expect(await prisma.video.findUnique({ where: { id } })).toMatchObject({ status: 'error', transcriptStatus: 'failed' })
    expect(getVideo).not.toHaveBeenCalled()
  })

  it('keeps a stale video transcript status when it was not pending', async () => {
    const id = await seedVideo(userId, { status: 'pending', transcriptStatus: 'ready', createdAt: hoursAgo(25) })
    await syncPendingVideos(new Date())
    expect(await prisma.video.findUnique({ where: { id } })).toMatchObject({ status: 'error', transcriptStatus: 'ready' })
  })

  it('one failing video does not stop the rest', async () => {
    const bad = await seedVideo(userId, { cloudflareUid: `bad-${stamp}`, createdAt: hoursAgo(2) })
    const good = await seedVideo(userId, { cloudflareUid: `good-${stamp}`, createdAt: hoursAgo(1) })
    getVideo.mockImplementation(async (uid: string) =>
      uid === `bad-${stamp}` ? { success: false, error: 'boom' } : readyAt(uid))
    expect(await syncPendingVideos(new Date())).toMatchObject({ refreshed: 1 })
    expect(await prisma.video.findUnique({ where: { id: bad } })).toMatchObject({ status: 'pending' })
    expect(await prisma.video.findUnique({ where: { id: good } })).toMatchObject({ status: 'ready' })
  })
})
