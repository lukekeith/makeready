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

  const inState = (state: string) => ({ success: true, video: { uid: 'u', readyToStream: false, status: { state } } })

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

  it('expires stale pending videos Stream still has not processed', async () => {
    getVideo.mockResolvedValue(inState('inprogress'))
    const id = await seedVideo(userId, { status: 'pending', transcriptStatus: 'pending', createdAt: hoursAgo(25) })
    expect(await syncPendingVideos(new Date())).toMatchObject({ expired: 1 })
    expect(getVideo).toHaveBeenCalledTimes(1)
    expect(await prisma.video.findUnique({ where: { id } })).toMatchObject({ status: 'error', transcriptStatus: 'failed' })
  })

  it('makes a stale video ready when Stream has it ready', async () => {
    getVideo.mockResolvedValue(readyAt('old'))
    const id = await seedVideo(userId, { transcriptStatus: 'pending', createdAt: hoursAgo(24 * 90) })
    expect(await syncPendingVideos(new Date())).toMatchObject({ refreshed: 1, expired: 0 })
    expect(await prisma.video.findUnique({ where: { id } })).toMatchObject({ status: 'ready', transcriptStatus: 'pending', duration: 42 })
  })

  it('expires a stale video Stream reports failed or no longer has', async () => {
    const failed = await seedVideo(userId, { cloudflareUid: `failed-${stamp}`, transcriptStatus: 'pending', createdAt: hoursAgo(30) })
    const gone = await seedVideo(userId, { cloudflareUid: `gone-${stamp}`, transcriptStatus: 'pending', createdAt: hoursAgo(30) })
    getVideo.mockImplementation(async (uid: string) =>
      uid === `gone-${stamp}` ? { success: false, error: 'Not found', notFound: true } : inState('error'))
    expect(await syncPendingVideos(new Date())).toMatchObject({ expired: 2 })
    for (const id of [failed, gone]) {
      expect(await prisma.video.findUnique({ where: { id } })).toMatchObject({ status: 'error', transcriptStatus: 'failed' })
    }
  })

  it('leaves a stale video pending while Stream cannot be read', async () => {
    getVideo.mockResolvedValue({ success: false, error: 'boom' })
    const id = await seedVideo(userId, { transcriptStatus: 'pending', createdAt: hoursAgo(30) })
    expect(await syncPendingVideos(new Date())).toMatchObject({ expired: 0 })
    expect(await prisma.video.findUnique({ where: { id } })).toMatchObject({ status: 'pending', transcriptStatus: 'pending' })
  })

  it('refreshes at most 50 stale videos a run', async () => {
    getVideo.mockResolvedValue(inState('inprogress'))
    for (let i = 0; i < 51; i++) await seedVideo(userId, { createdAt: hoursAgo(30 + i) })
    expect(await syncPendingVideos(new Date())).toMatchObject({ expired: 50 })
    expect(await prisma.video.count({ where: { userId, status: 'pending' } })).toBe(1)
  })

  it('keeps a stale video transcript status when it was not pending', async () => {
    getVideo.mockResolvedValue(inState('inprogress'))
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
